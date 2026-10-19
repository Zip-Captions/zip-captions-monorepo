import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/providers/viewer_announcer_provider.dart';
import 'package:zip_captions/src/screens/viewer_screen.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/viewer_test_harness.dart';

const _id = 'K7M9X2';

Future<void> _pump(
  WidgetTester tester, {
  required BroadcastResolution resolution,
}) async {
  final factory = RecordingViewerTransportFactory();
  final router = GoRouter(
    initialLocation: '/b/$_id',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: ViewerScreen.routePath,
        builder: (context, state) => ViewerScreen(
          broadcastId: state.pathParameters['broadcastId']!,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sentinelStringsOverride(),
        sharedPreferencesProvider.overrideWithValue(prefs),
        broadcastResolverProvider.overrideWithValue(
          FakeViewerResolver([resolution]),
        ),
        signalingServiceProvider.overrideWithValue(
          FakeViewerSignalingService(),
        ),
        iceServerProviderProvider.overrideWithValue(
          FakeViewerIceServerProvider(),
        ),
        viewerTransportFactoryProvider.overrideWithValue(factory.call),
        viewerAnnouncerProvider.overrideWithValue((view, message) {}),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// A live session: resolution succeeds and the holder has allocated the
/// viewer's caption pipeline.
Future<void> _pumpLive(WidgetTester tester) async {
  await _pump(
    tester,
    resolution: const BroadcastResolution.live(
      sessionId: 'session-1',
      sessionName: 'Community Meeting',
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ViewerScreen)),
  );
  expect(
    container.read(viewerSessionNotifierProvider.notifier).viewerBus,
    isNotNull,
  );
}

void main() {
  group('ViewerScreen leave (Rule 9)', () {
    testWidgets('an active session confirms, and Stay keeps it', (
      tester,
    ) async {
      await _pumpLive(tester);

      await tester.tap(find.text('viewerLeave'));
      await tester.pumpAndSettle();
      expect(find.text('viewerConfirmLeaveTitle'), findsOneWidget);

      await tester.tap(find.text('viewerConfirmLeaveCancel'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsNothing);
      expect(find.text('viewerConfirmLeaveTitle'), findsNothing);
    });

    testWidgets('an active session leaves on confirm', (tester) async {
      await _pumpLive(tester);

      await tester.tap(find.text('viewerLeave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('viewerConfirmLeaveConfirm'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('system back shows the dialog even from a direct route', (
      tester,
    ) async {
      await _pumpLive(tester);

      unawaited(tester.binding.handlePopRoute());
      await tester.pumpAndSettle();

      expect(find.text('viewerConfirmLeaveTitle'), findsOneWidget);
      expect(find.text('home'), findsNothing);
    });

    testWidgets('dismissing the dialog leaves the back event unhandled', (
      tester,
    ) async {
      await _pumpLive(tester);

      // No result: the barrier/dismiss path of the dialog, not a button.
      final pop = tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('viewerConfirmLeaveTitle'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('viewerConfirmLeaveTitle'), findsNothing);
      expect(find.text('home'), findsNothing);
      expect(find.text('viewerStateJoining'), findsOneWidget);
      expect(await pop, isFalse);
    });

    testWidgets('the system back button follows the same confirmation', (
      tester,
    ) async {
      await _pumpLive(tester);

      // `handlePopRoute` completes only when the listener returns, and the
      // listener waits on the dialog — so it must not be awaited here.
      final pop = tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('viewerConfirmLeaveTitle'), findsOneWidget);

      await tester.tap(find.text('viewerConfirmLeaveConfirm'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      await pop;
    });

    testWidgets('a terminal state leaves without a dialog', (tester) async {
      await _pump(
        tester,
        resolution: const BroadcastResolution.notFound(),
      );

      await tester.tap(find.text('viewerLeave'));
      await tester.pumpAndSettle();

      expect(find.text('viewerConfirmLeaveTitle'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('back from a terminal state leaves without a dialog', (
      tester,
    ) async {
      await _pump(
        tester,
        resolution: const BroadcastResolution.offline(),
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('viewerConfirmLeaveTitle'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });
  });
}
