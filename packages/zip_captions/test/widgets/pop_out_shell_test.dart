// Z24: the pop-out wiring in this app's shell (FD frontend-components §1,
// §8.8 items 1, 2, 7, 11, 14 asserted per app).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
          (ref) => Stream<List<DisplayInfo>>.value(const <DisplayInfo>[]),
        ),
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
  });
}
