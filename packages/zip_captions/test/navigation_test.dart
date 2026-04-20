/// Widget tests for back-navigation behaviour in [ZcAppShell].
///
/// Verifies that [BackButtonListener] correctly handles the system back button
/// for all mobile routes, guarding against regressions in the R2/R3 fix.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/shell/zc_app_shell.dart';
import 'package:zip_core/zip_core.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GoRouter _router(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (ctx, state, child) => ZcAppShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (ctx, s) => const SizedBox(key: Key('home')),
            ),
            GoRoute(
              path: '/settings',
              builder: (ctx, s) => const SizedBox(key: Key('settings')),
            ),
            GoRoute(
              path: '/history',
              builder: (ctx, s) => const SizedBox(key: Key('history')),
              routes: [
                GoRoute(
                  path: ':sessionId',
                  builder: (ctx, s) =>
                      const SizedBox(key: Key('transcript')),
                ),
              ],
            ),
          ],
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  // Force mobile width so ZcAppShell uses the BackButtonListener branch.
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
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ZcAppShell back navigation — mobile', () {
    testWidgets('/history back → /', (tester) async {
      await _pump(tester, _router('/history'));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home')), findsOneWidget);
    });

    testWidgets('/history/:id back → /history', (tester) async {
      await _pump(tester, _router('/history/test-session'));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history')), findsOneWidget);
    });

    testWidgets('/settings back → /', (tester) async {
      await _pump(tester, _router('/settings'));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home')), findsOneWidget);
    });

    testWidgets('/ back → stays at / (handler returns false)', (tester) async {
      await _pump(tester, _router('/'));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home')), findsOneWidget);
    });
  });
}
