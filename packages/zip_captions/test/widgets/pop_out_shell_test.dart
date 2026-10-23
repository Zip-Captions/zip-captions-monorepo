// Z24: the pop-out wiring in this app's shell (FD frontend-components §1,
// §8.8 items 1, 2, 7, 11, 14 asserted per app).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/providers/pop_out_providers.dart';
import 'package:zip_captions/src/screens/recording_screen.dart';
import 'package:zip_captions/src/shell/zc_app_shell.dart';
import 'package:zip_captions/src/shell/zc_nav_drawer.dart';
import 'package:zip_captions/src/widgets/pop_out_controls.dart';
import 'package:zip_captions/src/widgets/pop_out_scope.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/fake_display_enumerator.dart';
import '../helpers/fake_pop_out_controller.dart';
import '../helpers/fake_recording_state_notifier.dart';

const _strings = ZcStrings.fromMap({
  'popOutEnter': 'enter',
  'popOutExit': 'exit',
  'popOutHint': 'hint',
  'popOutReturn': 'return',
  'popOutUnavailableNoSession': 'no-session',
  'popOutUnavailableNoEngine': 'no-engine',
  'popOutOpenFailed': 'open-failed',
  'navJoinBroadcast': 'Join Broadcast',
});

GoRouter _router() => GoRouter(
      initialLocation: '/recording',
      routes: [
        ShellRoute(
          builder: (context, state, child) => ZcAppShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const SizedBox(key: Key('home')),
            ),
            GoRoute(
              path: '/recording',
              builder: (_, _) => const RecordingScreen(),
            ),
          ],
        ),
      ],
    );

/// Pumps the shell around [RecordingScreen] at [width] logical pixels.
Future<FakeRecordingStateNotifier> _pump(
  WidgetTester tester, {
  double width = 375,
  bool engine = true,
  RecordingState state =
      const RecordingState.recording(sessionId: 'test-session'),
  OverlayWindowController? controller,
  List<DisplayInfo> displays = const <DisplayInfo>[],
  Stream<ExternalDisplayStatus>? statuses,
}) async {
  tester.view.physicalSize = Size(width, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final notifier = FakeRecordingStateNotifier(state);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        transcriptWriterTargetProvider.overrideWith((_) {}),
        recordingStateNotifierProvider.overrideWith(() => notifier),
        onScreenCaptionTargetProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
        zcStringsProvider.overrideWith((ref) async => _strings),
        sttEngineProvider.overrideWithValue(engine ? FakeSttEngine() : null),
        popOutWindowControllerProvider.overrideWithValue(
          controller ?? fakePopOutController(),
        ),
        displayListProvider.overrideWith(
          (ref) => Stream<List<DisplayInfo>>.value(displays),
        ),
        if (statuses != null)
          popOutStatusProvider.overrideWith((ref) => statuses),
      ],
      child: MaterialApp.router(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        routerConfig: _router(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  group('pop-out shell wiring (Z24)', () {
    testWidgets('the in-surface toggle turns the pop-out on and off',
        (tester) async {
      final notifier = await _pump(tester);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('popOutBanner')), findsOneWidget);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('popOutBanner')), findsNothing);

      // BR-PIP-04: the recording never restarted across either toggle.
      expect(notifier.calls, isNot(contains('start')));
    });

    testWidgets('a second activation while opening changes nothing',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('popOutBanner')), findsNothing);
    });

    testWidgets('the banner return closes the pop-out', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('popOutReturn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('popOutBanner')), findsNothing);
    });

    testWidgets('the drawer closes when a destination is chosen',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byType(ZcNavDrawer), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      // §8.8 item 11: the drawer is gone, and the pop-out flag it was
      // rendered beside did not change.
      expect(find.byType(ZcNavDrawer), findsNothing);
      expect(find.byKey(const Key('popOutBanner')), findsNothing);
    });

    testWidgets('the desktop rail carries the same chrome control',
        (tester) async {
      await _pump(tester, width: 1024);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(PopOutChrome), findsOneWidget);
    });

    testWidgets('the mobile AppBar carries the same chrome control',
        (tester) async {
      await _pump(tester);

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(PopOutChrome), findsOneWidget);
    });

    testWidgets('no recognition engine disables the chrome control',
        (tester) async {
      await _pump(tester, engine: false);

      final toggle = tester.widget<PopOutControls>(
        find.byType(PopOutControls),
      );
      expect(
        popOutAvailability(
          status: const Off(),
          recording: const RecordingState.recording(sessionId: 's'),
          engineAvailable: false,
        ).enabled,
        isFalse,
      );
      expect(toggle.hint, 'no-engine');
    });

    testWidgets('the scope gives the screens the flag and the toggle',
        (tester) async {
      await _pump(tester);

      final scope = tester.widget<PopOutScope>(find.byType(PopOutScope));
      expect(scope.enabled, isFalse);
      expect(scope.strings, same(_strings));
    });

    // Finding n6 (review round 4): the integrated path, not the pure function.
    // The shell computes `popOutAvailability` once and passes `.enabled` into
    // `PopOutScope`; the screen reads it back and hands it to the in-surface
    // toggle. Broadcast asserted this end to end; this app did not.
    testWidgets('the scope availability disables the in-surface toggle',
        (tester) async {
      await _pump(tester, engine: false);

      final scope = tester.widget<PopOutScope>(find.byType(PopOutScope));
      expect(scope.available, isFalse);

      final surface = tester.widget<PopOutInSurfaceToggle>(
        find.byType(PopOutInSurfaceToggle),
      );
      expect(surface.enabled, isFalse);
      expect(find.byKey(const Key('popOutToggleReason')), findsOneWidget);
    });

    testWidgets('the scope availability enables the in-surface toggle',
        (tester) async {
      await _pump(tester);

      final scope = tester.widget<PopOutScope>(find.byType(PopOutScope));
      expect(scope.available, isTrue);

      final surface = tester.widget<PopOutInSurfaceToggle>(
        find.byType(PopOutInSurfaceToggle),
      );
      expect(surface.enabled, isTrue);
      expect(find.byKey(const Key('popOutToggleReason')), findsNothing);
    });
  });

  group('pop-out shell geometry (review round 3)', () {
    // Finding 2: the frame must come from the controller's live display list,
    // not from the auto-dispose `displayListProvider` the shell never watches.
    // The provider is deliberately fed an empty list here: the enumerator the
    // controller was built over holds the one display.
    testWidgets('the toggle computes a frame from the controller displays',
        (tester) async {
      final ready = _Ready();
      final enumerator = FakeDisplayEnumerator(initial: const [_display]);
      final window = _FrameWindow();
      final controller = _controllerOver(window, enumerator, ready.install);
      addTearDown(controller.dispose);
      window.onCreated = (id) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(ready.handler!('overlayReady', id)),
        );
      };
      await _pump(tester, controller: controller);

      await tester.pumpAndSettle();
      expect(controller.displays, const [_display]);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();

      // A non-null frame with a non-null display id reached the platform.
      expect(window.calls, contains('setFrame'));
      final frame = window.frames.single;
      // Same computation as the shell's, from the shell's own context.
      expect(
        frame,
        popOutFrameFor(
          context: tester.element(find.byType(PopOutScope)),
          displays: controller.displays,
          settings: DisplaySettings.defaults(),
        ).frame,
      );
      expect(frame.height, greaterThan(0));
      expect(frame.width, greaterThan(0));
    });

    // Finding 3: the chrome reads the controller's status once at build, so a
    // status that changes afterwards never reaches the toggle. The provider
    // carries the change instead.
    testWidgets('a status change to Unsupported hides the toggle',
        (tester) async {
      final statuses = StreamController<ExternalDisplayStatus>.broadcast();
      addTearDown(statuses.close);
      await _pump(tester, statuses: statuses.stream);

      expect(find.byKey(const Key('popOutToggle')), findsOneWidget);

      statuses.add(const Unsupported());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('popOutToggle')), findsNothing);
    });

    // Finding 4: the external display's unregister path and the pop-out's must
    // not diverge; a window the OS closed is no longer fed captions.
    testWidgets('a window closed on its own leaves the caption fan-out',
        (tester) async {
      final ready = _Ready();
      final enumerator = FakeDisplayEnumerator(initial: const [_display]);
      final window = _FrameWindow();
      final controller = _controllerOver(window, enumerator, ready.install);
      addTearDown(controller.dispose);
      window.onCreated = (id) {
        // The sub-engine reports ready one frame after creation.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(ready.handler!('overlayReady', id)),
        );
      };
      await _pump(tester, controller: controller);

      await tester.pumpAndSettle();
      final registry = ProviderScope.containerOf(
        tester.element(find.byType(PopOutScope)),
      ).read(captionOutputTargetRegistryProvider);
      final before = registry.activeTargets.length;

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();
      expect(registry.activeTargets, hasLength(before + 1));

      controller.onNativeWindowClosed(7);
      await tester.pumpAndSettle();

      expect(registry.activeTargets, hasLength(before));
    });
  });
}

const _display = DisplayInfo(
  id: 'primary',
  label: 'Primary',
  bounds: Rect.fromLTWH(0, 0, 1920, 1080),
  scaleFactor: 1,
  isPrimary: true,
);

OverlayWindowController _controllerOver(
  _FrameWindow window,
  DisplayEnumerator enumerator, [
  OverlayMethodHandlerInstaller? installer,
]) =>
    OverlayWindowController(
      windowService: window,
      enumerator: enumerator,
      handlerInstaller: installer ?? (_) {},
      log: Logger('test.popOutShell.frame'),
      mode: const PopOutMode(),
    );

/// Holds the method handler the controller installs, so the test can deliver
/// the sub-engine's `overlayReady` the way the router does.
class _Ready {
  OverlayMethodHandler? handler;

  // Named as a method, matching this project's `_FakeAuthNotifier.setState`
  // precedent, not a setter.
  // ignore: use_setters_to_change_properties
  void install(OverlayMethodHandler? next) => handler = next;
}

/// A window service that records the frame it was given.
class _FrameWindow implements DesktopWindowService {
  /// The id every created window reports.
  static const _id = 7;

  /// Completes the ready handshake for the id about to be returned, as the
  /// sub-engine's entry point does one frame after creation.
  void Function(int windowId)? onCreated;
  final List<String> calls = <String>[];
  final List<Rect> frames = <Rect>[];

  @override
  bool get isSupported => true;

  @override
  Future<int> createWindow(String arguments) async {
    calls.add('createWindow');
    onCreated?.call(_id);
    return _id;
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

  @override
  Future<void> show(int windowId) async => calls.add('show');
}
