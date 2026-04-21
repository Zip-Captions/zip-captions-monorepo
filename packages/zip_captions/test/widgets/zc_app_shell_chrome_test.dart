/// Widget tests for ZcAppShell navigation chrome.
///
/// Regression coverage for the R1 bug where a BottomNavigationBar appeared on
/// mobile screens instead of the hamburger + ZcNavDrawer layout.
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
              path: '/recording',
              builder: (ctx, s) => const SizedBox(key: Key('recording')),
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

Future<void> _pump(
  WidgetTester tester,
  String initialLocation, {
  Size physicalSize = const Size(375, 812),
}) async {
  tester.view.physicalSize = physicalSize;
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
      child: MaterialApp.router(
        // NoSplash prevents the ink_sparkle.frag shader from being loaded
        // in the test environment, where the shader binary is unavailable.
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        routerConfig: _router(initialLocation),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ZcAppShell — mobile chrome (≤ 768px)', () {
    testWidgets('shows AppBar and hamburger icon', (tester) async {
      await _pump(tester, '/');

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('no BottomNavigationBar on any route', (tester) async {
      for (final route in ['/', '/history', '/settings', '/recording']) {
        await _pump(tester, route);
        expect(
          find.byType(BottomNavigationBar),
          findsNothing,
          reason: 'BottomNavigationBar must not appear on $route',
        );
      }
    });

    testWidgets('no NavigationRail on mobile width', (tester) async {
      await _pump(tester, '/');

      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('tapping hamburger opens drawer with 4 destinations',
        (tester) async {
      await _pump(tester, '/');

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Caption'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('AppBar title reflects current route', (tester) async {
      await _pump(tester, '/history');
      expect(find.text('History'), findsOneWidget);

      await _pump(tester, '/settings');
      expect(find.text('Settings'), findsOneWidget);

      await _pump(tester, '/');
      expect(find.text('Zip Captions'), findsOneWidget);
    });
  });

  group('ZcAppShell — desktop chrome (> 768px)', () {
    testWidgets('shows NavigationRail instead of AppBar hamburger',
        (tester) async {
      await _pump(tester, '/', physicalSize: const Size(1200, 800));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsNothing);
    });

    testWidgets('no BottomNavigationBar on desktop', (tester) async {
      await _pump(tester, '/', physicalSize: const Size(1200, 800));

      expect(find.byType(BottomNavigationBar), findsNothing);
    });
  });
}
