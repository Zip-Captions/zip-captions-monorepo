import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';
import 'package:zip_broadcast/src/providers/overlay_window_controller_provider.dart';
import 'package:zip_broadcast/src/providers/pop_out_providers.dart';
import 'package:zip_broadcast/src/widgets/pop_out_controls.dart';
import 'package:zip_broadcast/src/widgets/pop_out_scope.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart'
    show CaptionDisplayWidget, DisplaySettings;

import '../helpers/fake_display_enumerator.dart';
import '../helpers/fake_notifiers.dart';
import '../helpers/zb_test_harness.dart';

/// A window service that records instead of creating.
class _Window implements DesktopWindowService {
  final List<String> calls = <String>[];
  int _next = 41;

  @override
  bool get isSupported => true;

  /// Completes the ready handshake for the id about to be returned.
  void Function(int windowId)? onCreated;

  /// When true, the next `createWindow` throws (and the flag resets).
  bool failNextCreate = false;

  @override
  Future<int> createWindow(String arguments) async {
    calls.add('createWindow');
    if (failNextCreate) {
      failNextCreate = false;
      throw StateError('no window');
    }
    final id = _next++;
    onCreated?.call(id);
    return id;
  }

  @override
  Future<void> closeWindow(int windowId) async => calls.add('closeWindow');

  @override
  Future<void> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) async =>
      calls.add('invokeMethod:$method');

  @override
  Future<void> setFrame(int windowId, Rect frame) async {
    calls.add('setFrame');
    frames.add(frame);
  }

  /// Every frame handed to [setFrame], in order (review round 3, finding 2).
  final List<Rect> frames = <Rect>[];

  @override
  Future<void> show(int windowId) async => calls.add('show');
}

class _Handler {
  OverlayMethodHandler? handler;

  // Named as a method, matching this project's `_FakeAuthNotifier.setState`
  // precedent, not a setter.
  // ignore: use_setters_to_change_properties
  void install(OverlayMethodHandler? next) => handler = next;
}

const _display = DisplayInfo(
  id: 'primary',
  label: 'Primary',
  bounds: Rect.fromLTWH(0, 0, 1920, 1080),
  scaleFactor: 1,
  isPrimary: true,
);

/// Holds the controller so the test can close the window the way the
/// platform does — through the router's `windowClosed` handler.
class _Graph {
  _Graph({this.display = true})
      : window = _Window(),
        enumerator = FakeDisplayEnumerator(
          initial: display ? [_display] : const <DisplayInfo>[],
        ) {
    controller = OverlayWindowController(
      windowService: window,
      enumerator: enumerator,
      handlerInstaller: handler.install,
      log: Logger('test.popOutShell'),
      mode: const PopOutMode(),
    );
    // The open only leaves `Opening` when the window reports ready; the
    // service's creation hook stands in for the sub-window's entry point.
    // `overlayReady` is a post-frame message: the controller's bootstrap
    // records the window id when `createWindow`'s future completes, so the
    // stub defers one frame, as the real sub-engine does.
    window.onCreated = (id) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(handler.handler!('overlayReady', id)),
      );
      WidgetsBinding.instance.ensureVisualUpdate();
    };
  }

  final _Window window;
  final FakeDisplayEnumerator enumerator;

  /// The display list the shell's geometry reads, seeded from the same fake.
  List<DisplayInfo> get displayList =>
      display ? const [_display] : const <DisplayInfo>[];

  /// Whether the fake was seeded with a display.
  final bool display;
  final _Handler handler = _Handler();
  late final OverlayWindowController controller;

  /// The platform's own close notification, as the runner raises it: the
  /// main-engine close channel, delivered to the controller's native-close
  /// seam (`closeChannel`), not through the method router.
  void windowGone() => controller.onNativeWindowClosed(controller.windowId!);
}

/// An active session whose `stop` publishes the stopped state, as the real
/// notifier does once the engines have stopped.
class _StoppableRecordingNotifier extends FakeActiveBroadcastRecordingNotifier {
  @override
  Future<void> stop() async {
    state = const BroadcastStoppedState(sessionId: 'test-session');
  }
}

Future<_Graph> _pumpRecording(
  WidgetTester tester, {
  bool display = true,
  bool engine = true,
  BroadcastRecordingNotifier? notifier,
}) async {
  final graph = _Graph(display: display);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    buildZbApp(
      prefs: prefs,
      initialLocation: '/recording',
      popOutController: graph.controller,
      overrides: [
        externalDisplayStatusProvider.overrideWith(
          (ref) => Stream<ExternalDisplayStatus>.value(const Off()),
        ),
        displayListProvider.overrideWith(
          (ref) => Stream<List<DisplayInfo>>.value(graph.displayList),
        ),
        broadcastRecordingNotifierProvider.overrideWith(
          notifier == null
              ? FakeActiveBroadcastRecordingNotifier.new
              : () => notifier,
        ),
        obsConnectionNotifierProvider
            .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
        audioInputConfigNotifierProvider.overrideWith(
          engine
              ? FakeOneInputAudioInputConfigNotifier.new
              : FakeEmptyAudioInputConfigNotifier.new,
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return graph;
}

/// A pop-out controller on a platform without multi-window support.
OverlayWindowController _unsupportedController() => OverlayWindowController(
      windowService: _UnsupportedWindow(),
      enumerator: FakeDisplayEnumerator(),
      handlerInstaller: (_) {},
      log: Logger('test.unsupportedPopOut'),
      mode: const PopOutMode(),
    );

/// A window service for a platform that cannot create windows.
class _UnsupportedWindow implements DesktopWindowService {
  @override
  bool get isSupported => false;

  @override
  Future<int> createWindow(String arguments) async =>
      throw UnsupportedError('no windows');

  @override
  Future<void> closeWindow(int windowId) async {}

  @override
  Future<void> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) async {}

  @override
  Future<void> setFrame(int windowId, Rect frame) async {}

  @override
  Future<void> show(int windowId) async {}
}

/// Pumps `/recording` on a platform without sub-windows, settled.
Future<void> _pumpUnsupported(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    buildZbApp(
      prefs: prefs,
      initialLocation: '/recording',
      popOutController: _unsupportedController(),
      overrides: [
        externalDisplayStatusProvider.overrideWith(
          (ref) => Stream<ExternalDisplayStatus>.value(const Unsupported()),
        ),
        displayListProvider.overrideWith(
          (ref) => const Stream<List<DisplayInfo>>.empty(),
        ),
        broadcastRecordingNotifierProvider.overrideWith(
          FakeActiveBroadcastRecordingNotifier.new,
        ),
        obsConnectionNotifierProvider
            .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
        audioInputConfigNotifierProvider
            .overrideWith(FakeOneInputAudioInputConfigNotifier.new),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

/// The same, on the first built frame only, with a status stream that never
/// emits: the shell has only the controller's synchronous status to render.
Future<void> _pumpFirstFrameUnsupported(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    buildZbApp(
      prefs: prefs,
      initialLocation: '/recording',
      popOutController: _unsupportedController(),
      overrides: [
        popOutStatusProvider.overrideWith(
          (ref) => const Stream<ExternalDisplayStatus>.empty(),
        ),
        displayListProvider.overrideWith(
          (ref) => const Stream<List<DisplayInfo>>.empty(),
        ),
        broadcastRecordingNotifierProvider.overrideWith(
          FakeActiveBroadcastRecordingNotifier.new,
        ),
        obsConnectionNotifierProvider
            .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
        audioInputConfigNotifierProvider
            .overrideWith(FakeOneInputAudioInputConfigNotifier.new),
      ],
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('pop-out shell wiring (B30)', () {
    testWidgets('the chrome toggle opens one window and flips the label',
        (tester) async {
      final graph = await _pumpRecording(tester);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();

      expect(graph.window.calls.where((c) => c == 'createWindow'), hasLength(1));
      expect(find.byKey(const Key('popOutBanner')), findsOneWidget);
    });

    testWidgets('a second toggle while opening creates no second window',
        (tester) async {
      final graph = await _pumpRecording(tester);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pump();
      // The in-surface toggle left with the captions (UX-PIP-05 as v1 ships
      // it), and the wide layout has no chrome control (fix round 6), so the
      // return action is the second activation the window offers.
      await tester.tap(find.byKey(const Key('popOutReturn')));
      await tester.pumpAndSettle();

      expect(graph.window.calls.where((c) => c == 'createWindow'), hasLength(1));
    });

    testWidgets('the banner return closes the window and clears the banner',
        (tester) async {
      final graph = await _pumpRecording(tester);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('popOutBanner')), findsOneWidget);

      await tester.tap(find.byKey(const Key('popOutReturn')));
      await tester.pumpAndSettle();

      expect(graph.window.calls, contains('closeWindow'));
      expect(find.byKey(const Key('popOutBanner')), findsNothing);
    });

    // UX-PIP-05 as v1 ships it (owner direction, fix round 6): the captions
    // move to the pop-out, so the main window shows the hint and the return
    // action in place of the caption surface, not above it.
    testWidgets('popped out, the main window shows the hint, not captions',
        (tester) async {
      await _pumpRecording(tester);
      expect(find.byType(CaptionDisplayWidget), findsOneWidget);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();

      expect(find.byType(CaptionDisplayWidget), findsNothing);
      expect(find.byKey(const Key('popOutBanner')), findsOneWidget);
      expect(find.byKey(const Key('popOutReturn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('popOutReturn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('popOutBanner')), findsNothing);
      expect(find.byType(CaptionDisplayWidget), findsOneWidget);
    });

    testWidgets('a window that goes away on its own clears the banner',
        (tester) async {
      final graph = await _pumpRecording(tester);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('popOutBanner')), findsOneWidget);

      graph.windowGone();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('popOutBanner')), findsNothing);
    });

    // Fix round 6 (owner direction): the wide layout has no chrome control, so
    // the in-surface toggle carries the disabled reason as visible text.
    testWidgets('no engine disables the in-surface toggle with its reason',
        (tester) async {
      await _pumpRecording(tester, engine: false);

      final surface = tester.widget<PopOutInSurfaceToggle>(
        find.byType(PopOutInSurfaceToggle),
      );
      expect(surface.enabled, isFalse);
      expect(find.byKey(const Key('popOutInSurfaceReason')), findsOneWidget);
    });

    // Fix round 6 (owner direction): the pop-out control is not in the left
    // sidebar at all.
    testWidgets('the desktop rail carries no pop-out control', (tester) async {
      await _pumpRecording(tester);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(PopOutChrome), findsNothing);
      expect(find.byKey(const Key('popOutToggle')), findsNothing);
    });

    // Fix round 6 (owner direction): a session that stops closes the pop-out
    // and resets the control, as a stop does when nothing is popped out.
    testWidgets('stopping the session closes the pop-out and resets it',
        (tester) async {
      final notifier = _StoppableRecordingNotifier();
      final graph = await _pumpRecording(tester, notifier: notifier);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();
      expect(graph.controller.status, isA<Open>());

      await notifier.stop();
      await tester.pumpAndSettle();

      expect(graph.window.calls, contains('closeWindow'));
      expect(graph.controller.status, isA<Off>());
      final scope = tester.widget<PopOutScope>(find.byType(PopOutScope));
      expect(scope.enabled, isFalse);
    });

    // R6-3 moved: the open-failure line sits under the in-surface toggle.
    testWidgets('a failed open shows the reason under the in-surface toggle',
        (tester) async {
      final graph = await _pumpRecording(tester);
      graph.window.failNextCreate = true;

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();

      expect(graph.controller.status, isA<Failed>());
      expect(
        find.descendant(
          of: find.byType(PopOutInSurfaceToggle),
          matching: find.byKey(const Key('popOutOpenFailed')),
        ),
        findsOneWidget,
      );

      // Review round 7, m1: the next open replaces the caption surface with
      // the return panel, so the line is read again only after returning.
      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();
      expect(graph.controller.status, isA<Open>());
      await tester.tap(find.byKey(const Key('popOutReturn')));
      await tester.pumpAndSettle();

      expect(graph.controller.status, isA<Off>());
      expect(find.byType(PopOutInSurfaceToggle), findsOneWidget);
      expect(find.byKey(const Key('popOutOpenFailed')), findsNothing);
    });

    // Review round 7, m2: the chrome's status lines are full sentences in the
    // shipped copy, and the narrow `AppBar` is 375 px wide; neither line may
    // push the toolbar's actions past its edge.
    testWidgets('the narrow chrome reason line fits the AppBar',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await _pumpRecording(tester, engine: false);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('popOutToggleReason')), findsOneWidget);
    });

    // Review round 7, m2: the narrow `AppBar` control carries its own failure
    // line, because it also works from screens with no caption surface.
    testWidgets('a failed open shows the reason by the narrow chrome control',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final graph = await _pumpRecording(tester);
      graph.window.failNextCreate = true;

      await tester.tap(find.byKey(const Key('popOutToggle')));
      await tester.pumpAndSettle();

      expect(graph.controller.status, isA<Failed>());
      expect(find.byKey(const Key('popOutToggleOpenFailed')), findsOneWidget);

      // The chrome stays on screen through the next open, so the line's
      // absence here is a real read.
      await tester.tap(find.byKey(const Key('popOutToggle')));
      await tester.pumpAndSettle();
      expect(graph.controller.status, isA<Open>());
      expect(find.byKey(const Key('popOutToggleOpenFailed')), findsNothing);
    });

    testWidgets('the in-surface toggle is enabled while a session runs',
        (tester) async {
      await _pumpRecording(tester);

      final surface = tester.widget<PopOutInSurfaceToggle>(
        find.byType(PopOutInSurfaceToggle),
      );
      expect(surface.enabled, isTrue);
    });

    // Finding 2: the pop-out's frame is computed from the controller's live
    // display list, not from the auto-dispose `displayListProvider`, which
    // only `ExternalDisplayControls` watches and which is not mounted on
    // `/recording`.
    testWidgets('the toggle hands the computed frame to setFrame',
        (tester) async {
      final graph = await _pumpRecording(tester);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();

      expect(graph.window.calls, contains('setFrame'));
      final frame = graph.window.frames.single;
      // Only the controller's list can produce a frame. The provider this
      // test overrides with the same list is auto-dispose and unmounted on
      // `/recording`, and `computePopOutFrame` answers `Rect.zero` with a null
      // display id for an empty list — exactly what the old read handed on.
      final fromController = computePopOutFrame(
        displays: graph.controller.displays,
        mainWindowCentre: null,
        settings: DisplaySettings.defaults(),
        textTheme: Theme.of(
          tester.element(find.byType(PopOutScope)),
        ).textTheme,
        textScaler: 1,
        platform: ThemeData().platform,
      );
      expect(fromController.displayId, _display.id);
      expect(frame, fromController.frame);
      expect(frame.width, greaterThan(0));
      expect(frame.height, greaterThan(0));
      expect(frame.bottom, _display.bounds.bottom);
    });

    testWidgets('the scope carries the flag and the toggle to the screen',
        (tester) async {
      await _pumpRecording(tester);

      final scope = tester.widget<PopOutScope>(find.byType(PopOutScope));
      expect(scope.enabled, isFalse);
      expect(find.byKey(const Key('popOutBanner')), findsNothing);
    });
  });

  // Review round 5, finding 3: on a platform that cannot host a sub-window the
  // in-surface toggle must not render at all (UX-PIP-04, BR-U8.1-11), and the
  // chrome must not flash for one frame while the status provider loads.
  group('pop-out on an unsupported platform (review round 5)', () {
    testWidgets('the in-surface toggle does not render', (tester) async {
      await _pumpUnsupported(tester);

      expect(find.byKey(const Key('popOutInSurfaceToggle')), findsNothing);
      expect(find.byKey(const Key('popOutToggle')), findsNothing);
    });

    // The fallback used to be `const Off()`, which is visible; the shell must
    // fall back to the controller's synchronous status instead.
    testWidgets('the chrome does not flash on the first frame',
        (tester) async {
      // Narrow: the `AppBar` is the one layout that carries a chrome control
      // (the rail has none since fix round 6).
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await _pumpFirstFrameUnsupported(tester);

      final chrome = tester.widget<PopOutChrome>(find.byType(PopOutChrome));
      expect(chrome.status, isA<Unsupported>());
      expect(find.byKey(const Key('popOutToggle')), findsNothing);
    });
  });
}
