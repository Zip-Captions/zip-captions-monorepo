import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_captions/src/screens/join_broadcast_screen.dart';
import 'package:zip_captions/src/screens/viewer_screen.dart';
import 'package:zip_captions/src/widgets/viewer_route_args.dart';

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
  });
}
