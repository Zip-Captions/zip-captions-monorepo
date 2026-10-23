import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/src/models/overlay_config.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_core/src/output/overlay/desktop_window_service.dart';
import 'package:zip_core/src/output/overlay/display_enumerator.dart';
// `Failed` (the status variant) collides with `zip_core`'s connection status
// of the same name, so it is imported under a local name.
import 'package:zip_core/src/output/overlay/external_display_status.dart'
    as display_status show Failed;
import 'package:zip_core/src/output/overlay/external_display_status.dart'
    show
        ExternalDisplayStatus,
        NoDisplays,
        Off,
        Open,
        Opening,
        Unsupported,
        WaitingForDisplay;

import 'package:zip_core/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/src/output/overlay/overlay_event.dart';
import 'package:zip_core/src/output/overlay/overlay_window_mode.dart';
import 'package:zip_core/src/output/overlay/sub_window_closed_channel.dart';
import 'package:zip_core/zip_core.dart' show DisplaySettings;

/// A method call from a caption overlay window.
///
/// [fromWindowId] identifies which window sent it, so a stale window's message
/// can be ignored rather than applied to the current one.
typedef OverlayMethodHandler = Future<void> Function(
  String method,
  int fromWindowId,
);

/// Installs (or, with `null`, uninstalls) the overlay [OverlayMethodHandler].
///
/// Production installs `DesktopMultiWindow.setMethodHandler`; the stub and
/// tests install nothing. The controller installs its handler once before the
/// first `createWindow` and uninstalls it only in `dispose()`.
typedef OverlayMethodHandlerInstaller = void Function(
  OverlayMethodHandler? handler,
);

/// How long the ready handshake may take before the open fails (BR-U8-23).
const Duration overlayReadyTimeout = Duration(seconds: 10);

/// The caption delivery cadence: at most one `captionUpdate` per 60 Hz frame
/// (P1).
const Duration captionUpdateInterval = Duration(milliseconds: 16);

/// Why the window is being closed.
enum CloseReason {
  /// The broadcaster switched the output off.
  toggleOff,

  /// The broadcaster cancelled waiting for a disconnected display.
  cancel,

  /// The window closed itself; the OS reported it gone.
  windowClosed,

  /// The open failed.
  openFailed,

  /// The selected display disconnected.
  displayLost,

  /// The controller is being disposed.
  dispose,
}

/// The display BR-U8-07 opens the window on, and whether the persisted id
/// still names a connected display.
typedef OpenDisplayResolution = ({
  DisplayInfo? target,
  bool persistedIdPresent,
});

/// Resolves which display the external display window opens on (BR-U8-07).
///
/// The persisted selection wins when it still names a connected display;
/// otherwise the primary display, otherwise the first display in platform
/// order. The result reports whether the persisted id was found so the caller
/// can keep it — an absent id is what `WaitingForDisplay` waits for (D-4) and
/// is cleared only by an explicit user selection, never here. This function
/// has no write path for that reason.
OpenDisplayResolution resolveOpenDisplay(
  List<DisplayInfo> displays,
  String? persistedId,
) {
  if (persistedId != null && persistedId.isNotEmpty) {
    for (final display in displays) {
      if (display.id == persistedId) {
        return (target: display, persistedIdPresent: true);
      }
    }
  }

  for (final display in displays) {
    if (display.isPrimary) {
      return (target: display, persistedIdPresent: false);
    }
  }

  return (
    target: displays.isEmpty ? null : displays.first,
    persistedIdPresent: false,
  );
}

/// Owns the one external display window: its lifecycle, handshake, display
/// watching, caption delivery and frame.
///
/// The state machine is the functional design's T1-T17 table. Every event is
/// processed in one synchronous span; the only awaits are the plugin calls in
/// the open sequence and the release steps, both serialised on
/// [_lifecycleLock] (R2), so a second window cannot exist.
///
/// Caption text never appears in a log line: logs carry fixed strings and an
/// error's `runtimeType` at most (BR-U8-18).
class OverlayWindowController {
  /// Creates a controller.
  ///
  /// [handlerInstaller] installs the window-to-controller method handler;
  /// `null` on a supported platform fails every open as `create_failed`
  /// before a window is created (R6/D7).
  OverlayWindowController({
    required DesktopWindowService windowService,
    required DisplayEnumerator enumerator,
    required OverlayMethodHandlerInstaller? handlerInstaller,
    required Logger log,
    OverlayWindowMode mode = const ExternalDisplayMode(),
    SubWindowClosedChannel? closeChannel,
  })  : _windowService = windowService,
        _enumerator = enumerator,
        _handlerInstaller = handlerInstaller,
        _log = log,
        _mode = mode,
        _closeChannel = closeChannel {
    _bootstrap();
  }

  final DesktopWindowService _windowService;
  final DisplayEnumerator _enumerator;
  final OverlayMethodHandlerInstaller? _handlerInstaller;
  final Logger _log;

  /// The mode this controller serves, fixed at construction (deviation 4).
  final OverlayWindowMode _mode;

  /// The main engine's native close channel, or `null` when the host has none.
  final SubWindowClosedChannel? _closeChannel;

  StreamSubscription<int>? _closeSubscription;

  final StreamController<ExternalDisplayStatus> _statusController =
      StreamController<ExternalDisplayStatus>.broadcast();
  final StreamController<OverlayEvent> _eventController =
      StreamController<OverlayEvent>.broadcast();

  ExternalDisplayStatus _status = const Off();
  StreamSubscription<List<DisplayInfo>>? _displaySubscription;
  Future<void> _lifecycleLock = Future<void>.value();
  Timer? _readyTimer;
  Timer? _updateTimer;
  int? _windowId;
  String? _modeDisplayId;
  Rect? _openBounds;
  CaptionOverlaySnapshot? _heldSnapshot;
  List<DisplayInfo> _displays = const <DisplayInfo>[];
  final _Selection _selection = _Selection();
  bool _disposed = false;

  /// The current state.
  ExternalDisplayStatus get status => _status;

  /// State transitions, starting with the bootstrap state.
  Stream<ExternalDisplayStatus> get statusChanges =>
      _statusController.stream;

  /// Lifecycle events for the shell.
  Stream<OverlayEvent> get events => _eventController.stream;

  /// Whether a window currently exists.
  bool get isWindowOpen => _windowId != null;

  /// The open window's id, or `null` when there is none (deviation 6).
  ///
  /// The router registers `windowIdOf: () => controller.windowId`, so a
  /// controller with no window receives nothing (null never matches).
  int? get windowId => _windowId;

  /// The mode this controller serves (deviation 4).
  OverlayWindowMode get mode => _mode;

  /// Whether this controller serves the pop-out.
  bool get _isPopOut => _mode is PopOutMode;

  /// The display enumerator this controller watches.
  DisplayEnumerator get enumerator => _enumerator;

  /// The displays currently known, in platform order.
  List<DisplayInfo> get displays => List<DisplayInfo>.unmodifiable(_displays);

  void _bootstrap() {
    if (!_windowService.isSupported) {
      // T1: the platform cannot host a second window; nothing else runs.
      _setState(const Unsupported());
      return;
    }

    _handlerInstaller?.call(_handleWindowCall);

    _closeSubscription = _closeChannel?.closed.listen(onNativeWindowClosed);

    _displaySubscription = _enumerator.changes.listen(
      _onDisplaysChanged,
      onError: (Object error) => _log.warning(
        'display watch failed: ${error.runtimeType}',
      ),
    );

    unawaited(
      _enumerator.displays().then(
        _onDisplaysChanged,
        onError: (Object error) {
          _log.warning('display probe failed: ${error.runtimeType}');
          _setState(const Unsupported());
        },
      ),
    );
  }

  void _onDisplaysChanged(List<DisplayInfo> displays) {
    if (_disposed || _status is Unsupported) return;
    _displays = displays;
    for (final display in displays) {
      if (display.label.isNotEmpty) _lastLabels[display.id] = display.label;
    }

    if (_isPopOut) {
      // Deviation 1 (FD BLM §2): a pop-out is not framed to a display and
      // never follows one. The list is kept for the shell; the transitions
      // below are skipped, so a pop-out never fails because no display is
      // attached.
      if (_status is NoDisplays && _displays.isNotEmpty) {
        _setState(const Off());
      }
      return;
    }

    switch (_status) {
      case NoDisplays():
        // T4: a display came back, or was never found until now.
        if (displays.isNotEmpty) _setState(const Off());
      case Off():
        // T3: the capability check found no displays.
        if (displays.isEmpty) _setState(const NoDisplays());
      case Open(:final displayId):
        final selected = _find(displayId);
        if (selected == null) {
          // T10: the selected display vanished.
          _handleDisplayLost();
        } else if (selected.bounds != _openBounds) {
          // T15: same display, new work area. No re-handshake.
          _openBounds = selected.bounds;
          unawaited(
            _windowCall(
              () => _windowService.setFrame(_windowId!, selected.bounds),
            ),
          );
        }
      case Opening():
        if (_find(_modeDisplayId) == null) {
          // The target vanished mid-open: fail rather than open on nothing.
          _failOpen(_displayLostCode);
        }
      case WaitingForDisplay(:final displayId):
        if (_find(displayId) != null) {
          // T11: the saved display is back. Leave the waiting state first, or
          // the open guard refuses it.
          _reopenOn(displayId);
        }
      case Unsupported():
        break;
      default:
        // Failed: no display change affects it; the next toggle retries.
        break;
    }
  }

  void _reopenOn(String displayId) {
    _setState(const Off());
    unawaited(_startOpen(_configFor(displayId), displayId));
  }

  /// The last known label for [id], or `null` if it was never seen.
  String? _labelFor(String id) {
    for (final display in _displays) {
      if (display.id == id) return display.label.isEmpty ? null : display.label;
    }
    return _lastLabels[id];
  }

  /// Labels of the displays seen so far, so a disconnected display can still
  /// be named. Bounded by the number of displays ever connected.
  final Map<String, String> _lastLabels = <String, String>{};

  DisplayInfo? _find(String? id) {
    if (id == null) {
      for (final display in _displays) {
        if (display.isPrimary) return display;
      }
      return _displays.isEmpty ? null : _displays.first;
    }
    for (final display in _displays) {
      if (display.id == id) return display;
    }
    return null;
  }

  OverlayConfig _configFor(String? displayId, {OverlayConfig? base}) =>
      (base ?? const OverlayConfig()).copyWith(
        mode: ExternalDisplayMode(displayId: displayId),
      );

  /// Opens the window on the display BR-U8-07 resolves.
  ///
  /// [persistedDisplayId] is the broadcaster's saved selection; it is never
  /// written here.
  Future<void> open(
    OverlayConfig config, {
    String? persistedDisplayId,
    Rect? frame,
  }) async {
    if (_disposed || _status is Unsupported) return;
    // BR-U8-01: a toggle on issued mid-open is a no-op, not a queued open, and
    // an already-open window is never re-created — one window at a time.
    if (_status is Opening || _status is Open) return;
    if (_status is WaitingForDisplay) return;

    if (_isPopOut) {
      // Deviation 4: the mode is fixed at construction. A config naming the
      // other mode is a caller bug, and the documented result is an open
      // failure rather than a silently different window.
      if (config.mode is! PopOutMode) {
        await _runFail(_createFailed);
        return;
      }
      // Deviation 3: the shell computed the frame; the pop-out has no display
      // to resolve and no persisted selection to honour.
      _popOutFrame = frame;
      await _startPopOut(config);
      return;
    }

    _selection.value = persistedDisplayId;

    final resolution = resolveOpenDisplay(_displays, persistedDisplayId);
    final target = resolution.target;
    if (target == null) {
      _setState(const NoDisplays());
      return;
    }
    final savedId = persistedDisplayId;
    if (!resolution.persistedIdPresent &&
        savedId != null &&
        savedId.isNotEmpty) {
      // The saved display is gone: wait for it rather than silently moving the
      // broadcast to another screen (D-4, BR-U8-07). The id is kept.
      _setState(WaitingForDisplay(displayId: savedId));
      return;
    }

    // The resolved target is what the window is on, so it is what the waiting
    // state and `DisplayLost` must name if that display goes away. Without this
    // a null persisted id would leave the selection empty and a lost display
    // would fall through to `Off` with no event.
    _selection.value = target.id;
    await _startOpen(_configFor(target.id, base: config), target.id);
  }

  Future<void> _startOpen(OverlayConfig config, String? displayId) {
    final result = _lifecycleLock.then((_) => _runOpen(config, displayId));
    _lifecycleLock = result.catchError((Object _) {});
    return result;
  }

  Future<void> _startPopOut(OverlayConfig config) {
    final result = _lifecycleLock.then((_) => _runOpen(config, null));
    _lifecycleLock = result.catchError((Object _) {});
    return result;
  }

  Future<void> _runOpen(OverlayConfig config, String? displayId) async {
    if (_disposed || _status is Unsupported) return;
    if (_status is Opening || _status is Open || _status is WaitingForDisplay) {
      return;
    }

    if (_isPopOut) {
      await _runOpenPopOut(config);
      return;
    }

    final target = _find(displayId);
    if (target == null) {
      if (displayId != null) {
        _setState(WaitingForDisplay(displayId: displayId));
      } else {
        _setState(const NoDisplays());
      }
      return;
    }

    if (_handlerInstaller == null) {
      // R6: the handler is a precondition of the open.
      await _runFail(_createFailed);
      return;
    }

    // R3: started before createWindow, so the timeout bounds the whole open.
    _readyTimer = Timer(overlayReadyTimeout, _onReadyTimeout);
    _openBounds = target.bounds;
    _modeDisplayId = displayId;
    _setState(const Opening());

    final int windowId;
    try {
      windowId = await _windowService.createWindow(
        encodeLaunch(
          OverlayWindowLaunch(
            config: config,
            snapshot: _heldSnapshot ?? _emptySnapshot(),
          ),
        ),
      );
    } on Object catch (error) {
      _log.warning('createWindow failed: ${error.runtimeType}');
      await _runFail(_createFailed);
      return;
    }

    _windowId = windowId;
  }

  /// The pop-out's open sequence: no display, no persisted id, no frame
  /// resolution (FD BLM §2, §3.4).
  Future<void> _runOpenPopOut(OverlayConfig config) async {
    if (_handlerInstaller == null) {
      // R6: the handler is a precondition of the open, both modes.
      await _runFail(_createFailed);
      return;
    }

    _readyTimer = Timer(overlayReadyTimeout, _onReadyTimeout);
    _openBounds = null;
    _modeDisplayId = null;
    _setState(const Opening());

    final int windowId;
    try {
      windowId = await _windowService.createWindow(
        encodeLaunch(
          OverlayWindowLaunch(
            config: config,
            snapshot: _heldSnapshot ?? _emptySnapshot(),
          ),
        ),
      );
    } on Object catch (error) {
      _log.warning('createWindow failed: ${error.runtimeType}');
      await _runFail(_createFailed);
      return;
    }

    _windowId = windowId;
  }

  /// The frame the shell computed for the pop-out, if any.
  Rect? _popOutFrame;

  /// Handles a method call from a caption overlay window.
  Future<void> _handleWindowCall(String method, int fromWindowId) async {
    if (_disposed) return;
    // A stale window's message is ignored rather than applied.
    if (_windowId != null && fromWindowId != _windowId) return;

    switch (method) {
      case 'overlayReady':
        // Late ready after expiry is inert (R3).
        if (_status is! Opening) return;
        await _runReady();
      case 'popOutToggle':
        // Deviation 2: the in-surface toggle routes here and the shell
        // decides; the controller only reports the intent.
        if (_isPopOut) _emit(const PopOutToggled());
      default:
        _log.warning('unknown window method');
    }
  }

  /// The native close entry (deviation 7).
  ///
  /// A close for the window this controller owns ends it exactly as the
  /// `'-1'` fallback would; any other id is dropped. A window the controller
  /// already released has a null id (via `_takeWindow`), so a late native
  /// event for it matches nothing.
  void onNativeWindowClosed(int windowId) {
    if (_disposed) return;
    if (_status is! Open || _windowId != windowId) return;
    unawaited(close(reason: CloseReason.windowClosed));
  }

  Future<void> _runReady() async {
    final windowId = _windowId;
    final displayId = _modeDisplayId;
    if (windowId == null) return;

    if (_isPopOut) {
      final frame = _popOutFrame;
      if (frame == null) {
        // P1: no frame means "keep the plugin's placement". The window is
        // still usable, so this is a FINE note rather than a failure.
        _log.fine('pop-out opened without a computed frame');
      } else {
        await _windowCall(() => _windowService.setFrame(windowId, frame));
      }
      await _windowCall(() => _windowService.show(windowId));
      _setState(Open(activity: _heldActivity, displayId: null));

      final held = _heldSnapshot;
      if (held != null) await _sendSnapshot(held);
      return;
    }

    final target = _find(displayId);
    final frame = target?.bounds ?? Rect.zero;

    await _windowCall(() => _windowService.setFrame(windowId, frame));
    await _windowCall(() => _windowService.show(windowId));

    _setState(Open(activity: _heldActivity, displayId: displayId));

    final held = _heldSnapshot;
    if (held != null) {
      // T7: the held snapshot is sent immediately on ready.
      await _sendSnapshot(held);
    }
  }

  OverlayActivity _heldActivity = OverlayActivity.standby;

  /// Pushes the latest caption state to the window.
  ///
  /// Stores the snapshot as the held one — while closed, that is what T7 sends
  /// on ready — and, while open, arms one 16 ms coalescing timer (P1).
  void push(CaptionOverlaySnapshot snapshot) {
    if (_disposed) return;
    _heldSnapshot = snapshot;
    _heldActivity = snapshot.activity;

    if (_status case Open(:final displayId, :final activity)) {
      if (activity != snapshot.activity) {
        // T9: recognition events move within Open, never across it.
        _setState(Open(activity: snapshot.activity, displayId: displayId));
      }
      _updateTimer ??= Timer(captionUpdateInterval, _flushSnapshot);
    }
  }

  void _flushSnapshot() {
    _updateTimer = null;
    final snapshot = _heldSnapshot;
    if (snapshot == null || _status is! Open) return;
    unawaited(_sendSnapshot(snapshot));
  }

  Future<void> _sendSnapshot(CaptionOverlaySnapshot snapshot) async {
    final windowId = _windowId;
    if (windowId == null) return;
    await _windowCall(
      () => _windowService.invokeMethod(
        windowId,
        'captionUpdate',
        encodeSnapshot(snapshot),
      ),
    );
  }

  /// Re-applies the current display's work area to the open window.
  Future<void> reframe() async {
    if (_status case Open(:final displayId)) {
      final target = _find(displayId);
      if (target == null) return;
      _openBounds = target.bounds;
      await _windowCall(
        () => _windowService.setFrame(_windowId!, target.bounds),
      );
    }
  }

  /// Records an explicit user selection without opening anything.
  ///
  /// This is the **only** path that writes the selection. The authoritative
  /// value lives in the settings notifier; this copy exists so
  /// `WaitingForDisplay` can keep waiting for a saved display that is not
  /// connected.
  ///
  /// Documented as a method in the design; expressed as an accessor pair
  /// because recording is all it does. The write path is the same single one.
  set selectDisplay(String? id) => _selection.update(id);

  /// The selection this controller last recorded.
  String? get selectDisplay => _selection.value;

  /// Closes the window and moves to the state [reason] implies.
  Future<void> close({required CloseReason reason}) {
    final result = _lifecycleLock.then((_) => _runClose(reason));
    _lifecycleLock = result.catchError((Object _) {});
    return result;
  }

  Future<void> _runClose(CloseReason reason) async {
    if (_disposed) return;
    // T2: an unsupported platform never has a window and never leaves its
    // state, whatever the UI sends.
    if (_status is Unsupported) return;

    // The window id is captured and nulled synchronously before the first
    // await, so a re-entrant close cannot double-release (Unit 6 discipline).
    final windowId = _takeWindow();

    switch (reason) {
      case CloseReason.toggleOff:
      case CloseReason.cancel:
        await _release(windowId);
        _setState(const Off());
      case CloseReason.dispose:
        await _release(windowId);
        // Unregistering the target disposes it, and the shell unregisters on
        // `OpenFailed`. Overwriting `Failed` here would erase the only record
        // of why the open ended (BR-U8-03); the controller is going away, so
        // leaving the state is harmless.
        if (_status is! display_status.Failed) _setState(const Off());
      case CloseReason.windowClosed:
        await _release(windowId);
        _setState(const Off());
        _emit(const WindowClosed());
      case CloseReason.displayLost:
        await _release(windowId);
        _runDisplayLost();
      case CloseReason.openFailed:
        await _release(windowId);
        await _runFail(_createFailed);
    }
  }

  int? _takeWindow() {
    final windowId = _windowId;
    _windowId = null;
    _modeDisplayId = null;
    _openBounds = null;
    _popOutFrame = null;
    return windowId;
  }

  void _runDisplayLost() {
    final displayId = _selection.value;
    if (displayId == null || displayId.isEmpty) {
      _setState(const Off());
      return;
    }
    // The display has left the connected list by the time this runs, so its
    // label is captured from the list as last seen (`_displays` still holds
    // the pre-change list on this path only when the change is what removed
    // it; `_labelFor` tolerates both).
    _setState(
      WaitingForDisplay(displayId: displayId, label: _labelFor(displayId)),
    );
    _emit(DisplayLost(displayId: displayId));
  }

  void _handleDisplayLost() {
    final result = _lifecycleLock.then((_) async {
      await _release(_takeWindow());
      _runDisplayLost();
    });
    _lifecycleLock = result.catchError((Object _) {});
  }

  /// Fails the current open with [code], releasing any window.
  Future<void> _runFail(String code) async {
    await _release(_takeWindow());
    _setState(display_status.Failed(reason: code));
    // Every fail path reports the failure exactly once (BR-U8-03).
    _emit(OpenFailed(code));
  }

  String get _createFailed => _createFailedCode;

  void _failOpen(String code) {
    final result = _lifecycleLock.then((_) => _runFail(code));
    _lifecycleLock = result.catchError((Object _) {});
  }

  void _onReadyTimeout() {
    _readyTimer = null;
    if (_status is! Opening) return;
    _log.warning('overlay ready timeout');
    _failOpen(_readyTimeoutCode);
  }

  /// Cancels the timers and closes the window without throwing (R1).
  ///
  /// Each step is independent: one failure does not skip the rest. The
  /// subscription to [DisplayEnumerator.changes] is controller-lifetime and is
  /// not touched here — keeping it alive is what makes T11's re-open, T4's
  /// repopulation and T16's retry possible (R1).
  Future<void> _release(int? windowId) async {
    try {
      _readyTimer?.cancel();
    } on Object catch (error) {
      _log.warning('ready timer cancel failed: ${error.runtimeType}');
    }
    _readyTimer = null;

    try {
      _updateTimer?.cancel();
    } on Object catch (error) {
      _log.warning('update timer cancel failed: ${error.runtimeType}');
    }
    _updateTimer = null;

    if (windowId != null) {
      try {
        await _windowService.closeWindow(windowId);
      } on Object catch (error) {
        // A close on an already-gone window reports `'-1'`; that is the
        // expected case here, not a failure.
        if (error is! PlatformException || error.code != '-1') {
          _log.warning('closeWindow failed: ${error.runtimeType}');
        }
      }
    }
  }

  /// The one seam every post-ready window call goes through (R4).
  ///
  /// A `PlatformException` with code `'-1'` while open means the window is
  /// gone (D-9); anything else is logged with a fixed string and ignored.
  /// Pre-ready `'-1'` is ignored: the ready timeout resolves the open (B-5).
  Future<void> _windowCall(Future<void> Function() call) async {
    try {
      await call();
    } on PlatformException catch (error) {
      if (error.code == '-1') {
        if (_status is Open) {
          _log.warning('window gone');
          await close(reason: CloseReason.windowClosed);
        } else {
          _log.warning('window gone before ready');
        }
        return;
      }
      _log.warning('window call failed: ${error.runtimeType}');
    } on Object catch (error) {
      _log.warning('window call failed: ${error.runtimeType}');
    }
  }

  /// Assigns the state, cancelling the ready timer structurally on any exit
  /// from [Opening] (R3).
  void _setState(ExternalDisplayStatus next) {
    if (_disposed) return;
    if (next is! Opening) {
      _readyTimer?.cancel();
      _readyTimer = null;
    }
    if (_sameStatus(_status, next)) return;
    _status = next;
    _statusController.add(next);
  }

  static bool _sameStatus(
    ExternalDisplayStatus a,
    ExternalDisplayStatus b,
  ) {
    if (a is Open && b is Open) {
      return a.displayId == b.displayId && a.activity == b.activity;
    }
    if (a is WaitingForDisplay && b is WaitingForDisplay) {
      return a.displayId == b.displayId;
    }
    if (a is display_status.Failed && b is display_status.Failed) {
      return a.reason == b.reason;
    }
    return a.runtimeType == b.runtimeType;
  }

  void _emit(OverlayEvent event) {
    if (_disposed) return;
    _eventController.add(event);
  }

  static CaptionOverlaySnapshot _emptySnapshot() => CaptionOverlaySnapshot(
        activity: OverlayActivity.standby,
        entries: const [],
        settings: DisplaySettings.defaults(),
      );

  /// Releases the display watch, the method handler, any window and the
  /// streams. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;

    final windowId = _takeWindow();
    _disposed = true;

    _readyTimer?.cancel();
    _readyTimer = null;
    _updateTimer?.cancel();
    _updateTimer = null;

    // Not awaited: the subscription is the platform listener's handle, and a
    // `cancel()` that resolves a microtask later must not delay the release
    // steps below.
    try {
      unawaited(_displaySubscription?.cancel() ?? Future<void>.value());
    } on Object catch (error) {
      _log.warning('display watch cancel failed: ${error.runtimeType}');
    }
    _displaySubscription = null;

    try {
      unawaited(_closeSubscription?.cancel() ?? Future<void>.value());
    } on Object catch (error) {
      _log.info('close watch cancel failed: ${error.runtimeType}');
    }
    _closeSubscription = null;

    try {
      await _enumerator.dispose();
    } on Object catch (error) {
      _log.info('enumerator dispose failed: ${error.runtimeType}');
    }

    try {
      _handlerInstaller?.call(null);
    } on Object catch (error) {
      _log.info('handler uninstall failed: ${error.runtimeType}');
    }

    if (windowId != null) {
      try {
        await _windowService.closeWindow(windowId);
      } on Object catch (error) {
        _log.info('closeWindow on dispose failed: ${error.runtimeType}');
      }
    }

    await _statusController.close();
    await _eventController.close();
  }
}

/// The broadcaster's saved display selection, as this controller last heard
/// it.
///
/// A tiny wrapper rather than a plain field so `selectDisplay` mutates a value
/// object the controller owns instead of being a one-line property setter,
/// which is how the simplified logic is expressed without an accessor pair.
class _Selection {
  String? value;

  void update(String? id) {
    final previous = value;
    if (previous == id) return;
    value = id;
  }
}

const String _createFailedCode = 'create_failed';
const String _readyTimeoutCode = 'ready_timeout';
const String _displayLostCode = 'display_lost';
