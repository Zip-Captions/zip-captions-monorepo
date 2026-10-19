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

class _Harness {
  _Harness(
    this.router,
    this.resolver,
    this.signaling,
    this.factory,
    this.announcements,
  );

  final GoRouter router;
  final FakeViewerResolver resolver;
  final FakeViewerSignalingService signaling;
  final RecordingViewerTransportFactory factory;
  final List<String> announcements;

  FakeViewerTransport get transport => factory.latest;
}

Future<_Harness> _pumpViewer(
  WidgetTester tester, {
  /// Scripted resolutions; the last one repeats. Defaults to one live
  /// resolution.
  List<BroadcastResolution>? resolutions,
  String routeId = _id,
}) async {
  final announcements = <String>[];
  final resolver = FakeViewerResolver(
    resolutions ??
        const [
          BroadcastResolution.live(
            sessionId: 'session-1',
            sessionName: 'Community Meeting',
          ),
        ],
  );
  final signaling = FakeViewerSignalingService();
  final factory = RecordingViewerTransportFactory();
  final router = GoRouter(
    initialLocation: '/b/$routeId',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: ViewerScreen.routePath,
        name: ViewerScreen.routeName,
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
        broadcastResolverProvider.overrideWithValue(resolver),
        signalingServiceProvider.overrideWithValue(signaling),
        iceServerProviderProvider.overrideWithValue(
          FakeViewerIceServerProvider(),
        ),
        viewerTransportFactoryProvider.overrideWithValue(factory.call),
        viewerAnnouncerProvider.overrideWithValue(
          (view, message) => announcements.add(message),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return _Harness(router, resolver, signaling, factory, announcements);
}

ViewerSessionNotifier _notifierOf(WidgetTester tester) => ProviderScope
    .containerOf(tester.element(find.byType(ViewerScreen)))
    .read(viewerSessionNotifierProvider.notifier);

CaptionWireMessage _caption(String text) => Caption(
  result: SttResult(
    text: text,
    isFinal: true,
    confidence: 1,
    timestamp: DateTime.utc(2026),
    sourceId: 'default',
  ),
);

void main() {
  group('ViewerScreen', () {
    testWidgets('joins the route broadcast on entry', (tester) async {
      final harness = await _pumpViewer(tester);

      expect(harness.resolver.resolvedIds.single.value, _id);
      expect(harness.transport.connectCalls, 1);
    });

    testWidgets('renders the connecting copy while the handshake is pending', (
      tester,
    ) async {
      final factory = RecordingViewerTransportFactory();
      final router = GoRouter(
        initialLocation: '/b/$_id',
        routes: [
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
              FakeViewerResolver([
                const BroadcastResolution.live(
                  sessionId: 'session-1',
                  sessionName: 'Community Meeting',
                ),
              ]),
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
      await tester.pump();
      await tester.pump();

      expect(find.text('viewerStateJoining'), findsOneWidget);
    });

    testWidgets('the app bar names the viewer, not the join screen', (
      tester,
    ) async {
      await _pumpViewer(tester);

      expect(find.widgetWithText(AppBar, 'viewerTitle'), findsOneWidget);
      expect(
        find.widgetWithText(AppBar, 'joinBroadcastTitle'),
        findsNothing,
      );
    });

    testWidgets(
      'a live session shows the live title and pauses-of-activity copy',
      (
        tester,
      ) async {
        final harness = await _pumpViewer(tester);
        harness.transport.emitStatus(const Connected(ConnectionType.p2pDirect));
        await tester.pumpAndSettle();

        expect(find.text('viewerStateTitleLive'), findsOneWidget);
        expect(find.text('viewerCaptionsPausedNotice'), findsOneWidget);

        harness.transport.emitMessage(
          const CaptionActivityChanged(activity: CaptionActivity.active),
        );
        await tester.pumpAndSettle();

        expect(find.text('viewerCaptionsPausedNotice'), findsNothing);
      },
    );

    testWidgets('remote captions render in the caption display', (
      tester,
    ) async {
      final harness = await _pumpViewer(tester);
      harness.transport.emitStatus(const Connected(ConnectionType.p2pDirect));
      await tester.pumpAndSettle();

      harness.transport.emitMessage(
        _caption('Hello from the studio'),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hello from the studio'), findsOneWidget);
    });

    testWidgets('reconnecting keeps the last captions on screen', (
      tester,
    ) async {
      final harness = await _pumpViewer(tester);
      harness.transport.emitStatus(const Connected(ConnectionType.p2pDirect));
      await tester.pumpAndSettle();
      harness.transport.emitMessage(
        _caption('Still here'),
      );
      await tester.pump(const Duration(milliseconds: 100));

      harness.transport.emitStatus(const Interrupted());
      await tester.pumpAndSettle();

      expect(find.text('viewerStateTitleReconnecting'), findsOneWidget);
      expect(find.text('Still here'), findsOneWidget);
    });

    testWidgets('leaving asks for confirmation and returns home', (
      tester,
    ) async {
      final harness = await _pumpViewer(tester);

      await tester.tap(find.text('viewerLeave'));
      await tester.pumpAndSettle();
      expect(find.text('viewerConfirmLeaveTitle'), findsOneWidget);

      await tester.tap(find.text('viewerConfirmLeaveConfirm'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(harness.transport.disconnectCalls, 1);
    });

    testWidgets('declining the leave dialog keeps the session', (
      tester,
    ) async {
      final harness = await _pumpViewer(tester);

      await tester.tap(find.text('viewerLeave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('viewerConfirmLeaveCancel'));
      await tester.pumpAndSettle();

      expect(find.text('viewerStateJoining'), findsOneWidget);
      expect(harness.transport.disconnectCalls, 0);
    });

    testWidgets('a cannot-connect state offers retry when the reason allows', (
      tester,
    ) async {
      final harness = await _pumpViewer(
        tester,
        resolutions: const [BroadcastResolution.resolutionFailed()],
      );

      expect(find.text('viewerStateTitleCannotConnect'), findsOneWidget);
      expect(
        find.text('viewerCannotConnectResolutionFailedBody'),
        findsOneWidget,
      );
      expect(find.text('viewerTryAgain'), findsOneWidget);

      // The retry is a fresh rejoin, driven by the user tap only.
      expect(harness.resolver.resolvedIds.length, 1);
      await tester.tap(find.text('viewerTryAgain'));
      await tester.pumpAndSettle();

      expect(harness.resolver.resolvedIds.length, greaterThan(1));
      expect(
        harness.resolver.resolvedIds.every((id) => id.value == _id),
        isTrue,
      );

      expect(harness.resolver.resolvedIds.length, greaterThan(1));
    });

    testWidgets('not-found shows no retry action', (tester) async {
      await _pumpViewer(
        tester,
        resolutions: const [BroadcastResolution.notFound()],
      );

      expect(find.text('viewerCannotConnectNotFoundBody'), findsOneWidget);
      expect(find.text('viewerTryAgain'), findsNothing);
    });

    testWidgets('rate-limited shows no retry action', (tester) async {
      await _pumpViewer(
        tester,
        resolutions: const [BroadcastResolution.rateLimited()],
      );

      expect(find.text('viewerCannotConnectRateLimitedBody'), findsOneWidget);
      expect(find.text('viewerTryAgain'), findsNothing);
    });

    testWidgets('an offline broadcast shows the auto-join notice', (
      tester,
    ) async {
      final harness = await _pumpViewer(
        tester,
        resolutions: const [BroadcastResolution.offline()],
      );

      expect(find.text('viewerStateTitleNotBroadcasting'), findsOneWidget);
      expect(find.text('viewerNotBroadcastingBodyNameless'), findsOneWidget);
      expect(harness.transport.connectCalls, 0);
    });

    testWidgets('an invalid deep link never touches the network', (
      tester,
    ) async {
      final harness = await _pumpViewer(tester, routeId: 'nope');

      expect(find.text('viewerStateTitleInvalidInput'), findsOneWidget);
      expect(find.text('viewerInvalidInputBody'), findsOneWidget);
      expect(harness.resolver.resolvedIds, isEmpty);
      expect(harness.factory.transports, isEmpty);
    });

    testWidgets('a broadcast end settles on the ended copy', (tester) async {
      final harness = await _pumpViewer(tester);
      harness.transport.emitStatus(const Connected(ConnectionType.p2pDirect));
      await tester.pumpAndSettle();

      harness.transport.emitMessage(const Ended());
      await tester.pumpAndSettle();

      expect(find.text('viewerStateTitleEnded'), findsOneWidget);
      expect(find.text('viewerEndedBodyNamed'), findsOneWidget);
    });

    testWidgets('retry after the broadcast ended shows the new captions', (
      tester,
    ) async {
      final harness = await _pumpViewer(
        tester,
        resolutions: const [
          BroadcastResolution.live(
            sessionId: 'session-1',
            sessionName: 'Community Meeting',
          ),
          BroadcastResolution.live(
            sessionId: 'session-2',
            sessionName: 'Community Meeting',
          ),
        ],
      );
      harness.transport.emitStatus(const Connected(ConnectionType.p2pDirect));
      await tester.pumpAndSettle();
      harness.transport.emitMessage(
        _caption('Before the end'),
      );
      await tester.pump(const Duration(milliseconds: 100));

      harness.transport.emitMessage(const Ended());
      await tester.pumpAndSettle();
      expect(find.text('viewerStateTitleEnded'), findsOneWidget);

      // Rule 6: `Ended` has no automatic rejoin; the user starts the next
      // session by joining again, which leaves first and allocates a fresh
      // bus (Q7).
      unawaited(_notifierOf(tester).join(_id));
      await tester.pumpAndSettle();
      expect(harness.factory.transports, hasLength(2));
      final rejoined = harness.factory.transports.last;
      expect(identical(rejoined, harness.factory.transports.first), isFalse);

      rejoined.emitStatus(const Connected(ConnectionType.p2pDirect));
      await tester.pumpAndSettle();
      rejoined.emitMessage(
        _caption('After the retry'),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('After the retry'), findsOneWidget);

      // The subscription moved with the session: the ended session's bus
      // must no longer drive the pane, and the old captions are gone with
      // that session's target.
      harness.factory.transports.first.emitMessage(
        _caption('From the ended session'),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('From the ended session'), findsNothing);
      expect(find.text('Before the end'), findsNothing);
    });

    testWidgets('status changes are announced once per transition', (
      tester,
    ) async {
      final harness = await _pumpViewer(tester);

      expect(harness.announcements, ['viewerStateJoining']);

      harness.transport.emitStatus(const Connected(ConnectionType.p2pDirect));
      await tester.pumpAndSettle();
      expect(harness.announcements, [
        'viewerStateJoining',
        'viewerStateTitleLive',
      ]);

      // A rebuild without a state change must not re-announce.
      harness.transport.emitMessage(
        _caption('Any caption'),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(harness.announcements.length, 2);
    });
  });
}
