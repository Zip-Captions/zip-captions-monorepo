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
import 'package:zip_core/zip_core.dart' hide Failed;

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

/// [_router] plus `/history`, where a stopped session lands (BR-U5-01).
GoRouter _sessionRouter() => GoRouter(
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
            GoRoute(
              path: '/history',
              builder: (_, _) => const SizedBox(key: Key('history')),
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
  GoRouter? router,
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
        routerConfig: router ?? _router(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  group('pop-out shell wiring (Z24)', () {
    // While popped out the in-surface toggle goes with the caption surface
    // (UX-PIP-05 as v1 ships it), so the chrome toggle is the way back here.
    testWidgets('the in-surface toggle turns the pop-out on, the chrome off',
        (tester) async {
      final notifier = await _pump(tester);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('popOutBanner')), findsOneWidget);

      await tester.tap(find.byKey(const Key('popOutToggle')));
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
      // The in-surface toggle left with the captions; the chrome toggle is
      // the second activation the main window still offers.
      await tester.tap(find.byKey(const Key('popOutToggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('popOutBanner')), findsNothing);
    });

    // UX-PIP-05 as v1 ships it (owner direction, fix round 6): the captions
    // move to the pop-out, so the main window shows the hint and the return
    // action in place of the caption surface, not above it.
    testWidgets('popped out, the main window shows the hint, not captions',
        (tester) async {
      await _pump(tester);
      expect(find.byType(CaptionDisplayWidget), findsOneWidget);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();

      expect(find.byType(CaptionDisplayWidget), findsNothing);
      expect(find.text('hint'), findsOneWidget);
      expect(find.byKey(const Key('popOutReturn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('popOutReturn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('popOutBanner')), findsNothing);
      expect(find.byType(CaptionDisplayWidget), findsOneWidget);
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

    // Fix round 6 (owner direction): the pop-out control is not in the left
    // sidebar at all; the in-surface toggle is the wide layout's entry point.
    testWidgets('the desktop rail carries no pop-out control', (tester) async {
      await _pump(tester, width: 1024);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(PopOutChrome), findsNothing);
      expect(find.byKey(const Key('popOutToggle')), findsNothing);
      expect(find.byKey(const Key('popOutInSurfaceToggle')), findsOneWidget);
    });

    testWidgets('no engine shows the reason under the in-surface toggle',
        (tester) async {
      await _pump(tester, width: 1024, engine: false);

      expect(
        find.descendant(
          of: find.byType(PopOutInSurfaceToggle),
          matching: find.byKey(const Key('popOutInSurfaceReason')),
        ),
        findsOneWidget,
      );
      expect(find.text('no-engine'), findsOneWidget);
    });

    // Fix round 6 (owner direction): a session that stops closes the pop-out
    // and resets the control, as a stop does when nothing is popped out, so a
    // fresh session does not start popped out.
    testWidgets('stopping the session closes the pop-out and resets it',
        (tester) async {
      final window = _FrameWindow();
      final ready = _Ready();
      final controller = _controllerOver(
        window,
        FakeDisplayEnumerator(initial: const [_display]),
        ready.install,
      );
      addTearDown(controller.dispose);
      window.onCreated = (id) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(ready.handler!('overlayReady', id)),
        );
      };
      final router = _sessionRouter();
      final notifier = await _pump(
        tester,
        width: 1024,
        controller: controller,
        router: router,
      );

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();
      expect(controller.status, isA<Open>());

      await notifier.stop();
      await tester.pumpAndSettle();

      expect(window.calls, contains('closeWindow'));
      expect(controller.status, isA<Off>());
      expect(tester.widget<PopOutScope>(find.byType(PopOutScope)).enabled,
          isFalse);

      // A fresh session starts with the captions in the main window.
      router.go('/recording');
      await tester.pumpAndSettle();
      expect(notifier.calls.where((c) => c == 'start'), isNotEmpty);
      expect(find.byKey(const Key('popOutBanner')), findsNothing);
      expect(find.byType(CaptionDisplayWidget), findsOneWidget);
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

  // Review round 5, finding 3: on a platform that cannot host a sub-window the
  // in-surface toggle must not render at all (UX-PIP-04, BR-U8.1-11), and the
  // chrome must not flash for one frame while the status provider loads.
  group('pop-out on an unsupported platform (review round 5)', () {
    testWidgets('the in-surface toggle does not render', (tester) async {
      await _pump(
        tester,
        statuses: Stream<ExternalDisplayStatus>.value(const Unsupported()),
      );

      expect(find.byKey(const Key('popOutInSurfaceToggle')), findsNothing);
      expect(find.byKey(const Key('popOutToggle')), findsNothing);
    });

    // The fallback used to be `const Off()`, which is visible, so an
    // unsupported platform rendered the chrome until the provider's first
    // value arrived a frame later.
    testWidgets('the chrome does not flash on the first frame',
        (tester) async {
      // Narrow: the `AppBar` is the one layout that carries a chrome control
      // (the rail has none since fix round 6).
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            transcriptWriterTargetProvider.overrideWith((_) {}),
            recordingStateNotifierProvider.overrideWith(
              () => FakeRecordingStateNotifier(
                const RecordingState.recording(sessionId: 'test-session'),
              ),
            ),
            onScreenCaptionTargetProvider.overrideWith(
              (ref) => const Stream.empty(),
            ),
            // Synchronous, so the shell builds its chrome on the very first
            // frame: that is the frame the old `?? const Off()` fallback made
            // visible on an unsupported platform.
            zcStringsProvider.overrideWith((ref) => _strings),
            sttEngineProvider.overrideWithValue(FakeSttEngine()),
            // The controller is synchronous `Unsupported` (an unsupported
            // platform), and the status stream never emits, so the shell has
            // only the synchronous status to render on the first frame.
            popOutWindowControllerProvider.overrideWithValue(
              fakeUnsupportedPopOutController(),
            ),
            // A never-emitting stream, so the provider has no value.
            popOutStatusProvider.overrideWith(
              (ref) => const Stream<ExternalDisplayStatus>.empty(),
            ),
          ],
          child: MaterialApp.router(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            routerConfig: _router(),
          ),
        ),
      );
      // The first built frame, without settling: this is the paint the old
      // `?? const Off()` fallback made visible on an unsupported platform.
      await tester.pump();

      final chrome = tester.widget<PopOutChrome>(find.byType(PopOutChrome));
      expect(chrome.status, isA<Unsupported>());
      expect(find.byKey(const Key('popOutToggle')), findsNothing);
    });
  });

  // Fix round 6, R6-2: two reads of Home after a stopped session disagreed in
  // the runtime review. The rule is pure, so this pins that the shell feeds it
  // the same inputs on every read, including after the status provider is
  // rebuilt, and that "no session" is disabled with its reason.
  group('pop-out availability after a session (R6-2)', () {
    ({bool enabled, bool reason}) readChrome(WidgetTester tester) {
      final button = tester.widget<TextButton>(
        find.byKey(const Key('popOutToggle')),
      );
      return (
        enabled: button.onPressed != null,
        reason: find
            .byKey(const Key('popOutToggleReason'))
            .evaluate()
            .isNotEmpty,
      );
    }

    testWidgets('start, stop, Home reads disabled with its reason, twice',
        (tester) async {
      // Narrow: the `AppBar` carries the chrome control on every screen.
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle());
      final router = _sessionRouter();

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
            sttEngineProvider.overrideWithValue(FakeSttEngine()),
            popOutWindowControllerProvider.overrideWithValue(
              fakePopOutController(),
            ),
          ],
          child: MaterialApp.router(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The recording screen started the session (`initState` from idle).
      expect(notifier.calls, contains('start'));
      expect(readChrome(tester), (enabled: true, reason: false));

      await notifier.stop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history')), findsOneWidget);

      router.go('/');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home')), findsOneWidget);
      final first = readChrome(tester);

      // Rebuild the status provider the shell watches, as Riverpod does when
      // it disposes and recreates an auto-dispose provider.
      ProviderScope.containerOf(tester.element(find.byType(PopOutScope)))
          .invalidate(popOutStatusProvider);
      await tester.pumpAndSettle();
      final second = readChrome(tester);

      expect(first, (enabled: false, reason: true));
      expect(second, first);
      expect(find.text('no-session'), findsOneWidget);
    });
  });

  // Fix round 6, R6-3: an open that fails reverted the chrome with no reason.
  // FD frontend-components §5 (R-M8, as amended): `popOutOpenFailed` renders
  // under the in-surface toggle, and the narrow chrome control carries its own
  // line, while the status is `Failed`; both clear when it leaves.
  group('pop-out open failure (R6-3)', () {
    testWidgets('a failed open shows the reason and the next open clears it',
        (tester) async {
      final window = _FlakyWindow();
      final controller = OverlayWindowController(
        windowService: window,
        enumerator: FakeDisplayEnumerator(initial: const [_display]),
        handlerInstaller: (_) {},
        log: Logger('test.popOutShell.flaky'),
        mode: const PopOutMode(),
      );
      addTearDown(controller.dispose);
      // The wide layout has no chrome control (owner direction), so the line
      // sits under the in-surface toggle, where the open was asked for.
      await _pump(tester, controller: controller, width: 1024);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();

      expect(controller.status, isA<Failed>());
      expect(find.byKey(const Key('popOutBanner')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PopOutInSurfaceToggle),
          matching: find.byKey(const Key('popOutOpenFailed')),
        ),
        findsOneWidget,
      );
      expect(find.text('open-failed'), findsOneWidget);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();
      expect(controller.status, isA<Opening>());

      // The return panel has replaced the caption surface, so the line's
      // absence proves nothing yet (review round 7, m1). Return to the window
      // and read the in-surface toggle again.
      await tester.tap(find.byKey(const Key('popOutReturn')));
      await tester.pumpAndSettle();

      expect(controller.status, isA<Off>());
      expect(find.byType(PopOutInSurfaceToggle), findsOneWidget);
      expect(find.byKey(const Key('popOutOpenFailed')), findsNothing);
    });

    // Review round 7, m2: on the narrow layout the `AppBar` control works from
    // any screen, including one with no caption surface, so its own failure
    // line is the only place the reason can be seen there.
    testWidgets('a failed open from a screen with no caption surface shows '
        'the reason by the chrome control', (tester) async {
      final controller = OverlayWindowController(
        windowService: _FlakyWindow(),
        enumerator: FakeDisplayEnumerator(initial: const [_display]),
        handlerInstaller: (_) {},
        log: Logger('test.popOutShell.flakyHome'),
        mode: const PopOutMode(),
      );
      addTearDown(controller.dispose);
      final router = _router();
      await _pump(tester, controller: controller, router: router);
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home')), findsOneWidget);

      await tester.tap(find.byKey(const Key('popOutToggle')));
      await tester.pumpAndSettle();

      expect(controller.status, isA<Failed>());
      expect(find.byKey(const Key('popOutToggleOpenFailed')), findsOneWidget);
      expect(find.text('open-failed'), findsOneWidget);

      // The chrome stays on screen through the next open, so this read is a
      // real one: the line clears as soon as the status leaves `Failed`.
      await tester.tap(find.byKey(const Key('popOutToggle')));
      await tester.pumpAndSettle();
      expect(controller.status, isA<Opening>());
      expect(find.byKey(const Key('popOutToggleOpenFailed')), findsNothing);

      await tester.tap(find.byKey(const Key('popOutToggle')));
      await tester.pumpAndSettle();
      expect(controller.status, isA<Off>());
    });
  });

  // Fix round 6, R6-4: the runtime review saw a control flash on iOS at session
  // start. Per-frame scans on the iOS simulator and the Android emulator found
  // no pop-out widget on any frame; this pins the transition the review named,
  // frame by frame, on an unsupported controller whose status stream never
  // emits.
  group('pop-out on an unsupported platform at session start (R6-4)', () {
    testWidgets('no pop-out widget is built on any frame of the start',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle());
      final router = _router()..go('/');

      final popOutWidgets = find.byWidgetPredicate(
        (w) =>
            w is PopOutInSurfaceToggle ||
            w is PopOutBanner ||
            w.key == const Key('popOutToggle') ||
            w.key == const Key('popOutToggleReason') ||
            w.key == const Key('popOutOpenFailed'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            transcriptWriterTargetProvider.overrideWith((_) {}),
            recordingStateNotifierProvider.overrideWith(() => notifier),
            onScreenCaptionTargetProvider.overrideWith(
              (ref) => const Stream.empty(),
            ),
            zcStringsProvider.overrideWith((ref) => _strings),
            sttEngineProvider.overrideWithValue(FakeSttEngine()),
            popOutWindowControllerProvider.overrideWithValue(
              fakeUnsupportedPopOutController(),
            ),
            popOutStatusProvider.overrideWith(
              (ref) => const Stream<ExternalDisplayStatus>.empty(),
            ),
          ],
          child: MaterialApp.router(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      expect(popOutWidgets, findsNothing);

      router.go('/recording');
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(popOutWidgets, findsNothing, reason: 'frame $frame');
      }
      expect(notifier.calls, contains('start'));
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

/// A window service whose first `createWindow` fails and later ones succeed.
class _FlakyWindow implements DesktopWindowService {
  int _creates = 0;

  @override
  bool get isSupported => true;

  @override
  Future<int> createWindow(String arguments) async {
    _creates++;
    if (_creates == 1) throw StateError('no window');
    return 9;
  }

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
