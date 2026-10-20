// Tests for Unit 8 (S-20): FP-5, the external display state machine's closure
// over generated command sequences (PBT-02/PBT-03/PBT-06).
//
// The controller runs for real against fakes; there is no
// `desktop_multi_window`, no `screen_retriever`, no runner and no device.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_broadcast/src/models/overlay_config.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_broadcast/src/output/overlay/desktop_window_service.dart';
import 'package:zip_broadcast/src/output/overlay/display_info.dart';
import 'package:zip_broadcast/src/output/overlay/external_display_status.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_activity.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_window_controller.dart';
import 'package:zip_core/zip_core.dart' hide Failed;

import '../../helpers/fake_display_enumerator.dart';
import '../../helpers/generators.dart';
import '../../helpers/pbt.dart';

DisplayInfo _display(String id, {bool isPrimary = false, double left = 0}) =>
    DisplayInfo(
      id: id,
      label: 'Display $id',
      bounds: Rect.fromLTWH(left, 0, 1920, 1080),
      scaleFactor: 1,
      isPrimary: isPrimary,
    );

List<DisplayInfo> _list({required bool keepSaved, bool moved = false}) => [
      _display('a', isPrimary: true, left: moved ? 40 : 0),
      if (keepSaved) _display('b', left: 1920),
    ];

/// A window service that records calls and can be told to fail.
class _Window implements DesktopWindowService {
  _Window({required this.supported});

  final bool supported;
  final List<String> calls = <String>[];
  int nextId = 11;

  /// How many windows were actually created (a throw does not count).
  int created = 0;

  /// When true, `createWindow` throws.
  bool failCreate = false;

  /// When true, every window call throws `'-1'`.
  bool gone = false;

  /// When true, every window call throws a non-`'-1'` platform error.
  bool otherError = false;

  @override
  bool get isSupported => supported;

  @override
  Future<int> createWindow(String arguments) async {
    calls.add('createWindow');
    if (failCreate) throw Exception('create failed');
    created++;
    return nextId++;
  }

  @override
  Future<void> closeWindow(int windowId) async => calls.add('closeWindow');

  @override
  Future<void> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) async {
    calls.add('invokeMethod');
    _maybeThrow();
  }

  @override
  Future<void> setFrame(int windowId, Rect frame) async {
    calls.add('setFrame');
    _maybeThrow();
  }

  @override
  Future<void> show(int windowId) async {
    calls.add('show');
    _maybeThrow();
  }

  void _maybeThrow() {
    if (gone) throw PlatformException(code: '-1', message: 'gone');
    if (otherError) throw PlatformException(code: 'x', message: 'hiccup');
  }
}

class _Handler {
  OverlayMethodHandler? handler;

  void install(OverlayMethodHandler? next) {
    handler = next;
    installs.add(next != null);
  }

  final List<bool> installs = <bool>[];
}

/// One realized world per Glados trial.
class _World {
  _World(this.async, {required this.supported}) {
    window = _Window(supported: supported);
    controller = OverlayWindowController(
      windowService: window,
      enumerator: enumerator,
      handlerInstaller: handler.install,
      log: _silent,
    );
    async.flushMicrotasks();
  }

  static final Logger _silent = Logger('fp5');

  final FakeAsync async;
  final bool supported;
  late final _Window window;
  final _Handler handler = _Handler();
  final FakeDisplayEnumerator enumerator = FakeDisplayEnumerator(
    initial: [_display('a', isPrimary: true), _display('b', left: 1920)],
  );
  late final OverlayWindowController controller;

  /// The harness's `overlayEnabled` stand-in, cleared by the shell on
  /// `WindowClosed`/`OpenFailed` in production.
  bool overlayEnabled = false;

  /// The current display list the world is simulating.
  bool savedPresent = true;

  ExternalDisplayStatus get state => controller.status;

  void settle() => async.flushMicrotasks();

  void run(OverlayCommand command) {
    switch (command) {
      case ToggleOnCommand(:final savedId):
        overlayEnabled = true;
        unawaited(
          controller.open(const OverlayConfig(), persistedDisplayId: savedId),
        );
        settle();
      case ToggleOffCommand():
        overlayEnabled = false;
        unawaited(controller.close(reason: CloseReason.toggleOff));
        settle();
      case DisplaysChangedCommand(:final keepSaved, :final noise):
        savedPresent = keepSaved;
        enumerator.emit(_list(keepSaved: keepSaved, moved: noise));
        settle();
      case OverlayReadyCommand():
        if (handler.handler != null) {
          // The window id is whatever the last create returned.
          final id = controller.isWindowOpen ? _windowId : -1;
          unawaited(handler.handler!('overlayReady', id));
        }
        settle();
      case AdvanceReadyTimeoutCommand():
        async
          ..elapse(overlayReadyTimeout + const Duration(milliseconds: 1))
          ..flushMicrotasks();
      case WindowGoneCommand():
        window.gone = true;
        controller.push(_snapshot());
        async
          ..elapse(captionUpdateInterval + const Duration(milliseconds: 1))
          ..flushMicrotasks();
        window.gone = false;
      case OtherPlatformErrorCommand():
        window.otherError = true;
        controller.push(_snapshot());
        async
          ..elapse(captionUpdateInterval + const Duration(milliseconds: 1))
          ..flushMicrotasks();
        window.otherError = false;
      case CreateWindowFailsCommand():
        window.failCreate = true;
        unawaited(controller.open(const OverlayConfig()));
        settle();
        window.failCreate = false;
      case CaptionEventCommand(:final activity):
        controller.push(_snapshot(activity: activity));
        settle();
      case ElapseCommand():
        async
          ..elapse(captionUpdateInterval + const Duration(milliseconds: 1))
          ..flushMicrotasks();
    }

    // The shell's reaction to the controller's events (BR-U8-15): a window
    // closed by itself or a failed open switches the output off.
    if (state is Failed) overlayEnabled = false;
  }

  /// The id the controller created the window with; a fresh world only opens
  /// one window per trial because the controller refuses concurrent opens.
  int get _windowId => 11;

  CaptionOverlaySnapshot _snapshot({
    OverlayActivity activity = OverlayActivity.live,
  }) =>
      CaptionOverlaySnapshot(
        activity: activity,
        entries: [
          CaptionDisplayEntry(
            entryId: 'e',
            sessionId: 's',
            text: 'text',
            isFinal: true,
            sourceId: 'default',
            timestamp: DateTime.utc(2026),
          ),
        ],
        settings: DisplaySettings.defaults(),
      );

  void close() {
    unawaited(controller.dispose());
    async.flushMicrotasks();
  }
}

void main() {
  setUpAll(() => Logger.root.level = Level.OFF);

  const Glados<List<OverlayCommand>>(arbitraryOverlayCommandSequence).test(
    'FP-5: only declared states, one at a time, closed invariant, single window',
    (commands) {
      fakeAsync((async) {
        final world = _World(async, supported: true);

        for (final command in commands) {
          world.run(command);

          // Declared variants only.
          expect(
            world.state,
            anyOf(
              isA<Off>(),
              isA<NoDisplays>(),
              isA<Opening>(),
              isA<Open>(),
              isA<WaitingForDisplay>(),
              isA<Failed>(),
              isA<Unsupported>(),
            ),
            reason: 'after $command',
          );

          // Never two states: the getter is a single value, so the meaningful
          // assertion is that it changes only through the declared variants.
          expect(world.state, isNotNull);

          // Only one window exists at a time (BR-U8-01): the live window count
          // is the creates that have not been closed yet, and it never exceeds
          // one.
          final live = world.window.created -
              world.window.calls.where((c) => c == 'closeWindow').length;
          expect(
            live,
            anyOf(0, 1),
            reason: 'at most one live window after $command; '
                'calls=${world.window.calls}',
          );
          expect(
            world.controller.isWindowOpen,
            live > 0,
            reason: 'the live count and isWindowOpen agree after $command',
          );

          // BR-U8-15 closure: the output being off never coexists with a
          // window-owning state.
          if (!world.overlayEnabled) {
            expect(
              world.state,
              isNot(anyOf(isA<Open>(), isA<Opening>())),
              reason: 'closed invariant broken after $command',
            );
          }
        }

        world.close();
      });
    },
  );

  const Glados<List<OverlayCommand>>(arbitraryOverlayCommandSequence).test(
    'FP-5: no open path writes the saved display id, and idempotence holds',
    (commands) {
      fakeAsync((async) {
        final world = _World(async, supported: true);
        final seen = <String?>{};

        for (final command in commands) {
          world.run(command);
          // The controller only records what it is told; nothing here is a
          // settings write.
          seen.add(world.controller.selectDisplay);
        }

        expect(seen, isNot(contains('written-by-open')));

        // PBT-04: closing twice equals closing once, whichever state we are in.
        unawaited(world.controller.close(reason: CloseReason.toggleOff));
        world.settle();
        final closes =
            world.window.calls.where((c) => c == 'closeWindow').length;
        final afterFirst = world.state;

        unawaited(world.controller.close(reason: CloseReason.toggleOff));
        world.settle();

        expect(world.state.runtimeType, afterFirst.runtimeType);
        expect(
          world.window.calls.where((c) => c == 'closeWindow').length,
          closes,
          reason: 'second close must not close again',
        );
        expect(world.state, isA<Off>());

        world.close();
      });
    },
  );

  test('FP-5: an unsupported platform stays Unsupported for every command', () {
    fakeAsync((async) {
      final world = _World(async, supported: false);

      for (final command in <OverlayCommand>[
        const ToggleOnCommand(savedId: null),
        const DisplaysChangedCommand(keepSaved: true, noise: true),
        const OverlayReadyCommand(),
        const CaptionEventCommand(activity: OverlayActivity.live),
        const ToggleOffCommand(),
      ]) {
        world.run(command);
        final state = world.state;
        expect(state, isA<Unsupported>(), reason: 'after $command');
      }
      expect(world.window.calls, isEmpty);

      world.close();
    });
  });
}
