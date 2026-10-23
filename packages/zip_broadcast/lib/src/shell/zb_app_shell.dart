import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart';
import 'package:zip_broadcast/src/models/browser_source_start_exception.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/output/browser_source/browser_source_server.dart';
import 'package:zip_broadcast/src/output/browser_source/browser_source_target.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_target.dart';
import 'package:zip_broadcast/src/output/overlay/pop_out_caption_target.dart';
import 'package:zip_broadcast/src/providers/broadcast_engine_available_provider.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/providers/overlay_window_controller_provider.dart';
import 'package:zip_broadcast/src/providers/pop_out_providers.dart';
import 'package:zip_broadcast/src/providers/settings_notifier.dart';
import 'package:zip_broadcast/src/shell/zb_nav_drawer.dart';
import 'package:zip_broadcast/src/shell/zb_nav_rail.dart';
import 'package:zip_broadcast/src/widgets/pop_out_controls.dart';
import 'package:zip_broadcast/src/widgets/pop_out_scope.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart';

/// Platform-adaptive shell for Zip Broadcast.
///
/// - Width > 768 px: persistent [ZbNavRail] on the left.
/// - Width ≤ 768 px: [AppBar] with hamburger + [ZbNavDrawer].
///
/// Owns [BrowserSourceTarget] and [CaptionOverlayTarget] as fields and
/// registers/deregisters them with [CaptionOutputTargetRegistry] as the
/// user toggles output targets (H1). OBS lifecycle is self-managed by
/// `ObsConnectionNotifier` (H2).
class ZbAppShell extends ConsumerStatefulWidget {
  /// Creates a [ZbAppShell].
  const ZbAppShell({required this.child, super.key});

  /// The current route's page widget.
  final Widget child;

  @override
  ConsumerState<ZbAppShell> createState() => _ZbAppShellState();
}

class _ZbAppShellState extends ConsumerState<ZbAppShell> {
  static const _desktopBreakpoint = 768.0;

  late final BrowserSourceTarget _browserSourceTarget;
  late final CaptionOverlayTarget _overlayTarget;
  late final PopOutCaptionTarget _popOutTarget;
  late final CaptionOutputTargetRegistry _registry;

  bool _browserSourceRegistered = false;
  bool _browserSourceStarting = false;
  bool _browserSourceDesiredEnabled = false;
  bool _overlayRegistered = false;
  String? _overlayDisplayId;
  StreamSubscription<OverlayEvent>? _overlayEvents;

  // The pop-out's state is in-memory (Q10 B): there is no persisted key and
  // no settings write on any pop-out path, so `popOutEnabled` is a pure
  // function of this flag and the controller's status.
  bool _popOutEnabled = false;
  StreamSubscription<OverlayEvent>? _popOutEvents;

  @override
  void initState() {
    super.initState();
    _browserSourceTarget = BrowserSourceTarget(
      server: BrowserSourceServer(),
    );
    _overlayTarget = CaptionOverlayTarget(
      controller: ref.read(overlayWindowControllerProvider),
      registry: ref.read(captionOutputTargetRegistryProvider),
      displaySettings: () => ref.read(displaySettingsProvider),
    );
    _popOutTarget = PopOutCaptionTarget(
      controller: ref.read(popOutWindowControllerProvider),
      registry: ref.read(captionOutputTargetRegistryProvider),
      displaySettings: () => ref.read(displaySettingsProvider),
      // Read at show time and mapped through this app's own session state:
      // its `SessionStateEvent` may have been published before the target
      // existed (finding 2).
      recordingState: () => _popOutRecordingState(
        ref.read(broadcastRecordingNotifierProvider),
      ),
    );
    _registry = ref.read(captionOutputTargetRegistryProvider);

    // BR-U8-15: the shell is what switches the output off when the window
    // goes away on its own. Display loss keeps the output on (D-4): the
    // controller waits for the saved display to come back.
    _overlayEvents = _overlayTarget.events.listen(_onOverlayEvent);
    _popOutEvents = _popOutTarget.events.listen(_onPopOutEvent);

    // Register transcript target (always active).
    ref.read(transcriptWriterTargetProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTargets(ref.read(outputTargetSettingsNotifierProvider));
    });
  }

  /// Reacts to the controller's lifecycle events (BR-U8-15).
  void _onOverlayEvent(OverlayEvent event) {
    switch (event) {
      case WindowClosed():
      case OpenFailed():
        // Unregister and switch the output off, but do not send a toggle-off
        // close back to the controller: after `OpenFailed` the controller is
        // already `Failed` with no window, and that state is what the failure
        // banner renders (BR-U8-03).
        _unregisterOverlay();
        unawaited(_switchOverlayOff());
      case DisplayLost():
        // Bookkeeping only: the target stays registered, `overlayEnabled`
        // stays true, and the controller reopens on the saved display when
        // it returns (T11).
        // No state change: the target stays registered.
      case PopOutToggled():
        // A toggle request from the external display's window would arrive
        // here; that window has no toggle, so it never does. The pop-out's own
        // toggle is handled in `_onPopOutEvent`.
        break;
    }
  }

  /// Reacts to the pop-out's lifecycle events (BR-PIP-03).
  ///
  /// Every one of them ends the popped-out state: the window is gone or it
  /// never opened. Turning the flag off in the same callback is what makes the
  /// banner and the toggle label change in the frame the state does.
  void _onPopOutEvent(OverlayEvent event) {
    switch (event) {
      case WindowClosed():
      case OpenFailed():
        // Both end the target: the registry disposes it with the window, so
        // leaving it registered would keep a dead target in the caption fan-out
        // while the external display's own path (`_unregisterOverlay`) does
        // not (review round 3, finding 4).
        _unregisterPopOut();
        _setPoppedOut(false);
      case DisplayLost():
        // A pop-out is never framed to a display, so it cannot lose one.
        break;
      case PopOutToggled():
        // The pop-out's in-surface toggle (FD BLM §3.3) asks to leave. The
        // shell owns the flag, so it closes through the same path the chrome
        // toggle and the banner use. Closing needs no geometry.
        _closePopOut();
    }
  }

  /// Maps the broadcast session onto the availability rule's recording state.
  ///
  /// The rule is `zip_core`'s and speaks `RecordingState`; this app's state
  /// machine is its own five-variant type. Reconnecting counts as active (the
  /// recognition session is still the reason the captions flow), mirroring
  /// `CaptionOverlayTarget._activityFor`.
  static RecordingState _popOutRecordingState(BroadcastSessionState state) =>
      switch (state) {
        BroadcastActiveState() => const RecordingState.recording(sessionId: ''),
        BroadcastPausedState() => const RecordingState.paused(sessionId: ''),
        BroadcastReconnectingState() =>
          const RecordingState.reconnecting(sessionId: ''),
        BroadcastIdleState() => const RecordingState.idle(),
        BroadcastStoppedState() => const RecordingState.stopped(sessionId: ''),
      };

  /// Ends the popped-out state and the window behind it: the close half of
  /// `_togglePopOut`, for callers with no live context.
  void _closePopOut() {
    _setPoppedOut(false);
    _unregisterPopOut();
    unawaited(_popOutTarget.hide());
  }

  /// Removes the target from the caption fan-out, if it is registered.
  ///
  /// The registry's `remove` disposes the target; that is what makes the
  /// unregister on a closed window safe (the controller is already `Off`, so
  /// the dispose's close is a no-op).
  void _unregisterPopOut() => _registry.remove(_popOutTarget);

  /// The one writer of `_popOutEnabled`.
  void _setPoppedOut(bool value) {
    if (_popOutEnabled == value) return;
    if (!mounted) return;
    setState(() => _popOutEnabled = value);
  }

  /// The chrome toggle, the in-surface toggle and the banner's return all end
  /// up here (UX-PIP-01, UX-PIP-02, UX-PIP-05).
  ///
  /// One method for both directions: closing is context-free, and opening
  /// takes its geometry from the element's own context, which Flutter
  /// re-attaches on every build.
  void _togglePopOut() {
    if (_popOutEnabled) {
      _closePopOut();
      return;
    }
    final controller = ref.read(popOutWindowControllerProvider);
    if (controller.status is Opening || controller.status is Open) return;
    final context = _shellContext;
    if (context == null) return;
    // The controller's own list, kept current by the enumerator, is the one
    // the geometry must read: `displayListProvider` is auto-dispose and only
    // `ExternalDisplayControls` watches it, which is not mounted on
    // `/recording`, so reading it here always yields null (review round 3,
    // finding 2).
    final geometry = popOutFrameFor(
      context: context,
      displays: controller.displays,
      settings: ref.read(displaySettingsProvider),
    );
    _setPoppedOut(true);
    _registry.add(_popOutTarget);
    unawaited(
      _popOutTarget.show(
        _popOutConfig,
        frame: geometry.displayId == null ? null : geometry.frame,
      ),
    );
  }

  /// The shell's own element context, captured in [build].
  ///
  /// Capturing it once is what lets the toggle be a plain `VoidCallback`: the
  /// geometry needs a context, and the controls are built by this widget, so
  /// their closures already have one.
  BuildContext? _shellContext;

  /// The launch configuration for the pop-out, with the shell's frame.
  /// The pop-out's open config, carrying this app's localized toggle label.
  OverlayConfig get _popOutConfig => OverlayConfig(
        mode: const PopOutMode(),
        popOutToggleLabel: ZipBroadcastLocalizations.of(context)?.popOutExit,
      );

  void _unregisterOverlay() {
    if (!_overlayRegistered) return;
    _registry.remove(_overlayTarget);
    _overlayRegistered = false;
    _overlayDisplayId = null;
  }

  Future<void> _switchOverlayOff() async {
    if (!mounted) return;
    final notifier = ref.read(outputTargetSettingsNotifierProvider.notifier);
    final current = ref.read(outputTargetSettingsNotifierProvider);
    await notifier.update(current.copyWith(overlayEnabled: false));
  }

  @override
  void dispose() {
    unawaited(_overlayEvents?.cancel());
    _overlayEvents = null;
    unawaited(_popOutEvents?.cancel());
    _popOutEvents = null;
    _browserSourceDesiredEnabled = false;
    if (_browserSourceRegistered) {
      _registry.remove(_browserSourceTarget);
      unawaited(_browserSourceTarget.stop());
    } else if (_browserSourceStarting) {
      unawaited(_browserSourceTarget.stop());
    }
    if (_overlayRegistered) {
      _registry.remove(_overlayTarget);
      unawaited(_overlayTarget.hide());
    }
    if (_popOutEnabled) {
      _registry.remove(_popOutTarget);
      unawaited(_popOutTarget.hide());
    }
    super.dispose();
  }

  void _syncTargets(OutputTargetSettings settings) {
    _syncBrowserSource(
      settings.browserSourceEnabled,
      settings.browserSourcePort,
    );
    _syncOverlay(settings);
  }

  void _syncBrowserSource(bool enabled, int port) {
    _browserSourceDesiredEnabled = enabled;
    if (enabled && !_browserSourceRegistered && !_browserSourceStarting) {
      unawaited(_startBrowserSource(port));
    } else if (!enabled && _browserSourceRegistered) {
      _registry.remove(_browserSourceTarget);
      _browserSourceRegistered = false;
      unawaited(_browserSourceTarget.stop());
    }
  }

  void _syncOverlay(OutputTargetSettings settings) {
    final enabled = settings.overlayEnabled;
    final config = OverlayConfig(
      position: settings.externalDisplayCaptionPosition == CaptionPosition.top
          ? const OverlayPositionTop()
          : const OverlayPositionBottom(),
    );
    if (enabled && !_overlayRegistered) {
      _registry.add(_overlayTarget);
      _overlayRegistered = true;
      _overlayDisplayId = settings.externalDisplayId;
      // After the registry add, so the first snapshot already reads the
      // on-screen buffer. The launch carries the persisted caption position
      // and display selection (BR-U8-07, BR-U8-26); the controller resolves
      // the selection and never writes it back.
      unawaited(
        _overlayTarget.show(
          config,
          persistedDisplayId: settings.externalDisplayId,
        ),
      );
    } else if (enabled && settings.externalDisplayId != _overlayDisplayId) {
      // The broadcaster picked a different display while the output is on.
      // Closing first is what lets the controller accept the re-open (its
      // open guard refuses a second window); the window then opens on the new
      // display with the current position.
      _overlayDisplayId = settings.externalDisplayId;
      unawaited(
        _retarget(
          () => _overlayTarget.show(
            config,
            persistedDisplayId: settings.externalDisplayId,
          ),
        ),
      );
    } else if (!enabled) {
      // Only a window that still exists needs closing. After an open failure
      // the event handler has already unregistered and released it, and the
      // controller stays `Failed` so the banner can explain why (BR-U8-03).
      _unregisterOverlay();
      if (_overlayTarget.isVisible) unawaited(_overlayTarget.hide());
    }
  }

  /// Closes the open window, then applies [reopen].
  ///
  /// The close is skipped when there is no window: an open that failed leaves
  /// the controller `Failed` with nothing to close, and a toggle-off close
  /// would replace that state with `Off` (BR-U8-03).
  Future<void> _retarget(Future<void> Function() reopen) async {
    if (_overlayTarget.isVisible) await _overlayTarget.hide();
    if (!mounted || !_overlayRegistered) return;
    await reopen();
  }

  Future<void> _startBrowserSource(int port) async {
    _browserSourceStarting = true;
    try {
      await _browserSourceTarget.start(port: port);
      if (!_browserSourceDesiredEnabled || !mounted) {
        unawaited(_browserSourceTarget.stop());
        return;
      }
      _registry.add(_browserSourceTarget);
      _browserSourceRegistered = true;
    } on BrowserSourceStartException catch (e) {
      if (!mounted) return;
      final l10n = ZipBroadcastLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.browserSourceFailedToStart(e.reason)),
        ),
      );
    } finally {
      _browserSourceStarting = false;
    }
  }

  String _screenTitle(BuildContext context, String location) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    if (location == '/') return l10n.appTitleDefault;
    if (location == '/recording') return l10n.appTitleBroadcast;
    if (location == '/settings') return l10n.appTitleSettings;
    if (location == '/history') return l10n.appTitleHistory;
    if (location == '/audio-inputs') return l10n.appTitleAudioInputs;
    if (location == '/broadcast') return l10n.appTitleGoLive;
    return l10n.appTitleDefault;
  }

  /// Rule 9's sign-out guard (F-6.9): the sole call path to
  /// `authNotifierProvider.notifier.signOut()` within `zip_broadcast`.
  /// Refuses outright — the call is not made, not merely a disabled
  /// button — while `BroadcasterSessionState` is `StartingState`,
  /// `LiveState`, or `EndingState`.
  ///
  /// NFR Design Q2: the state read and the subsequent act (the `signOut()`
  /// call, or the refusal) happen in the same synchronous span — no
  /// `await` of any kind between them — so no concurrent `goLive()` can
  /// be interleaved between the check and the decision it makes.
  Future<void> _requestSignOut() async {
    final sessionState = ref.read(broadcastSessionNotifierProvider);
    if (sessionState is StartingState ||
        sessionState is LiveState ||
        sessionState is EndingState) {
      if (!mounted) return;
      final l10n = ZipBroadcastLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.broadcastSignOutRefused)),
      );
      return;
    }
    await ref.read(authNotifierProvider.notifier).signOut();
  }

  static int _railIndex(String location) {
    if (location == '/') return 0;
    if (location == '/recording') return 1;
    if (location == '/history') return 2;
    if (location == '/broadcast') return 3;
    return -1;
  }

  static String _railDestination(int index) {
    switch (index) {
      case 0:
        return '/';
      case 1:
        return '/recording';
      case 2:
        return '/history';
      case 3:
        return '/broadcast';
      default:
        return '/';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OutputTargetSettings>(
      outputTargetSettingsNotifierProvider,
      (prev, next) => _syncTargets(next),
    );

    // The toggle's geometry needs a context; this is the one the shell owns.
    _shellContext = context;

    final location = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.of(context).size.width;
    final broadcastState = ref.watch(broadcastRecordingNotifierProvider);
    final isBroadcastActive = broadcastState is BroadcastActiveState ||
        broadcastState is BroadcastPausedState ||
        broadcastState is BroadcastReconnectingState;
    // Watched, not read: the controller's status changes after build (a
    // failed display probe leaves it `Unsupported`) and the chrome must
    // follow (review round 3, finding 3).
    final popOutState =
        ref.watch(popOutStatusProvider).valueOrNull ?? const Off();
    // The launch flag changes in `_togglePopOut`, not in this watch; the
    // rebuild comes from `setState`.
    final popOutRecording = _popOutRecordingState(broadcastState);
    final popOutEngineAvailable = ref.watch(broadcastEngineAvailableProvider);
    // FD frontend-components §4: the in-surface toggle obeys the same rule as
    // the chrome toggle, so the two can never disagree.
    final popOutAvailabilityResult = popOutAvailability(
      status: popOutState,
      recording: popOutRecording,
      engineAvailable: popOutEngineAvailable,
    );
    final popOutAvailable = popOutAvailabilityResult.enabled;

    final Widget content;
    if (width > _desktopBreakpoint) {
      content = Row(
        children: [
          ZbNavRail(
            selectedIndex: _railIndex(location),
            onDestinationSelected: (i) {
              final destination = _railDestination(i);
              if (destination == location) return;
              context.go(destination);
            },
            onSettingsTap: () {
              if (location == '/settings') return;
              context.go('/settings');
            },
            isBroadcastActive: isBroadcastActive,
            headerAction: PopOutChrome(
              status: popOutState,
              recording: popOutRecording,
              engineAvailable: popOutEngineAvailable,
              isPoppedOut: _popOutEnabled,
              reason: popOutAvailabilityResult.reason,
              onToggle: _togglePopOut,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ],
      );
    } else {
      content = BackButtonListener(
        onBackButtonPressed: () async {
          if (location == '/') return false;
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          } else {
            context.go('/');
          }
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_screenTitle(context, location)),
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            actions: [
              PopOutChrome(
                status: popOutState,
                recording: popOutRecording,
                engineAvailable: popOutEngineAvailable,
                isPoppedOut: _popOutEnabled,
                reason: popOutAvailabilityResult.reason,
                onToggle: _togglePopOut,
              ),
            ],
          ),
          body: widget.child,
          drawer: ZbNavDrawer(
            currentLocation: location,
            onTap: (route) {
              context.go(route);
              Navigator.of(context).pop();
            },
            isBroadcastActive: isBroadcastActive,
          ),
        ),
      );
    }

    return ZbSignOutScope(
      requestSignOut: _requestSignOut,
      child: PopOutScope(
        enabled: _popOutEnabled,
        onToggle: _togglePopOut,
        available: popOutAvailable,
        child: content,
      ),
    );
  }
}

/// Exposes [ZbAppShell]'s Rule 9 sign-out guard to descendants —
/// `AccountSection`'s sign-out button reaches it via [ZbSignOutScope.of]
/// instead of calling `authNotifierProvider.notifier.signOut()` directly
/// (Functional Design Q6).
class ZbSignOutScope extends InheritedWidget {
  /// Creates a [ZbSignOutScope] wrapping [child].
  const ZbSignOutScope({
    required this.requestSignOut,
    required super.child,
    super.key,
  });

  /// `_ZbAppShellState._requestSignOut`, bound to the current shell
  /// instance.
  final Future<void> Function() requestSignOut;

  /// Requests sign-out. Refuses (shows feedback, never calls `signOut()`)
  /// while the broadcast session is non-idle (`business-rules.md` Rule 9).
  static Future<void> of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ZbSignOutScope>();
    assert(scope != null, 'No ZbSignOutScope found in context');
    return scope!.requestSignOut();
  }

  @override
  bool updateShouldNotify(ZbSignOutScope oldWidget) =>
      oldWidget.requestSignOut != requestSignOut;
}
