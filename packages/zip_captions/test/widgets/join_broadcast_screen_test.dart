import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/providers/viewer_announcer_provider.dart';
import 'package:zip_captions/src/routing/zc_router.dart';
import 'package:zip_captions/src/screens/join_broadcast_screen.dart';
import 'package:zip_captions/src/screens/viewer_screen.dart';
import 'package:zip_captions/src/widgets/viewer_route_args.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/viewer_test_harness.dart';

GoRouter _router() => GoRouter(
  initialLocation: JoinBroadcastScreen.routePath,
  routes: [
    GoRoute(
      path: JoinBroadcastScreen.routePath,
      builder: (context, state) => const JoinBroadcastScreen(),
    ),
    GoRoute(
      path: ViewerScreen.routePath,
      name: ViewerScreen.routeName,
      builder: (context, state) => Scaffold(
        body: Text(
          'viewer:${state.pathParameters['broadcastId']}',
          key: const Key('viewer-route'),
        ),
      ),
    ),
  ],
);

Future<GoRouter> _pumpJoin(WidgetTester tester) async {
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sentinelStringsOverride()],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Opens `/join` through the home affordance on the real router table, so
/// the production route graph decides push vs go.
Future<void> _pumpShellJoin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sentinelStringsOverride(),
        sharedPreferencesProvider.overrideWithValue(prefs),
        transcriptWriterTargetProvider.overrideWith((_) {}),
        broadcastResolverProvider.overrideWithValue(
          FakeViewerResolver([const BroadcastResolution.notFound()]),
        ),
        signalingServiceProvider.overrideWithValue(
          FakeViewerSignalingService(),
        ),
        iceServerProviderProvider.overrideWithValue(
          FakeViewerIceServerProvider(),
        ),
        viewerAnnouncerProvider.overrideWithValue((view, message) {}),
      ],
      child: MaterialApp.router(routerConfig: zcRouter),
    ),
  );
  zcRouter.go('/');
  await tester.pumpAndSettle();
  await tester.tap(find.text('joinBroadcastTitle'));
  await tester.pumpAndSettle();
  expect(
    zcRouter.routerDelegate.currentConfiguration.uri.path,
    JoinBroadcastScreen.routePath,
  );
}

void main() {
  group('JoinBroadcastScreen', () {
    testWidgets('renders the ARB title, field label and submit label', (
      tester,
    ) async {
      await _pumpJoin(tester);

      expect(find.text('joinBroadcastTitle'), findsOneWidget);
      expect(find.text('joinBroadcastFieldLabel'), findsOneWidget);
      expect(find.text('joinBroadcastSubmit'), findsOneWidget);
    });

    testWidgets('a bare code navigates to the viewer route', (tester) async {
      final router = await _pumpJoin(tester);

      await tester.enterText(find.byType(TextField), 'k7m9x2');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('viewer:K7M9X2'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/b/K7M9X2',
      );
    });

    testWidgets('a configured URL navigates to the viewer route', (
      tester,
    ) async {
      await _pumpJoin(tester);

      await tester.enterText(
        find.byType(TextField),
        'https://zipcaptions.app/b/M9K2X7',
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('viewer:M9K2X7'), findsOneWidget);
    });

    testWidgets('surrounding whitespace is trimmed', (tester) async {
      await _pumpJoin(tester);

      await tester.enterText(find.byType(TextField), ' k7m9x2 ');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('viewer:K7M9X2'), findsOneWidget);
    });

    testWidgets('invalid input shows the inline error and does not navigate', (
      tester,
    ) async {
      final router = await _pumpJoin(tester);

      await tester.enterText(find.byType(TextField), 'not a broadcast');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('joinBroadcastInvalidInput'), findsOneWidget);
      expect(find.byKey(const Key('viewer-route')), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/join');
    });

    testWidgets('empty input is invalid', (tester) async {
      await _pumpJoin(tester);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('joinBroadcastInvalidInput'), findsOneWidget);
    });

    testWidgets('a later valid submit clears the error', (tester) async {
      await _pumpJoin(tester);

      await tester.enterText(find.byType(TextField), 'nope');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('joinBroadcastInvalidInput'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'k7m9x2');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('joinBroadcastInvalidInput'), findsNothing);
      expect(find.text('viewer:K7M9X2'), findsOneWidget);
    });

    testWidgets('submitting from the keyboard also navigates', (tester) async {
      await _pumpJoin(tester);

      await tester.enterText(find.byType(TextField), 'k7m9x2');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      expect(find.text('viewer:K7M9X2'), findsOneWidget);
    });

    testWidgets('the route receives the parsed ID as extra', (tester) async {
      ViewerRouteArgs? received;
      final router = GoRouter(
        initialLocation: JoinBroadcastScreen.routePath,
        routes: [
          GoRoute(
            path: JoinBroadcastScreen.routePath,
            builder: (context, state) => const JoinBroadcastScreen(),
          ),
          GoRoute(
            path: ViewerScreen.routePath,
            name: ViewerScreen.routeName,
            builder: (context, state) {
              received = state.extra! as ViewerRouteArgs;
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sentinelStringsOverride()],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'https://x/b/K7M9X2');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(received?.broadcastId?.value, 'K7M9X2');
    });

    testWidgets('system back returns to home from /join', (
      tester,
    ) async {
      await _pumpShellJoin(tester);
      await tester.enterText(find.byType(TextField), 'k7m9x2');
      await tester.pump();

      unawaited(tester.binding.handlePopRoute());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(
        zcRouter.routerDelegate.currentConfiguration.uri.path,
        '/',
      );
      // Back is a single step, never an exit: the shell owns the home route.
      expect(find.text('home'), findsNothing);
    });
  });
}
