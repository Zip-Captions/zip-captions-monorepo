import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/providers/viewer_announcer_provider.dart';
import 'package:zip_captions/src/screens/viewer_screen.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/viewer_test_harness.dart';

const _id = 'K7M9X2';

Future<RecordingViewerTransportFactory> _pumpWith(
  WidgetTester tester, {
  required Override stringsOverride,
  required BroadcastResolution resolution,
}) async {
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
        stringsOverride,
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
  return factory;
}

void main() {
  group('ViewerScreen localization wiring', () {
    testWidgets('a sentinel map proves the screen reads the ARB keys', (
      tester,
    ) async {
      final factory = await _pumpWith(
        tester,
        stringsOverride: zcStringsProvider.overrideWith(
          (ref) async => const ZcStrings.fromMap({
            'viewerStateTitleLive': 'SENTINEL-LIVE',
            'viewerLeave': 'SENTINEL-LEAVE',
          }),
        ),
        resolution: const BroadcastResolution.live(
          sessionId: 'session-1',
          sessionName: 'Community Meeting',
        ),
      );

      expect(find.text('SENTINEL-JOINING'), findsNothing);
      factory.latest.emitStatus(const Connected(ConnectionType.p2pDirect));
      await tester.pumpAndSettle();

      expect(find.text('SENTINEL-LIVE'), findsOneWidget);
      expect(find.text('SENTINEL-LEAVE'), findsOneWidget);
    });

    testWidgets('the real ARB values render with the default provider', (
      tester,
    ) async {
      final factory = await _pumpWith(
        tester,
        stringsOverride: zcStringsProvider.overrideWith(
          (ref) async => ZcStrings.load(),
        ),
        resolution: const BroadcastResolution.live(
          sessionId: 'session-1',
          sessionName: 'Community Meeting',
        ),
      );

      factory.latest.emitStatus(const Connected(ConnectionType.p2pDirect));
      await tester.pumpAndSettle();

      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
    });

    testWidgets('the paused notice clears in place when activity resumes', (
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
      await tester.pumpAndSettle();

      factory.latest.emitStatus(const Connected(ConnectionType.p2pDirect));
      await tester.pumpAndSettle();
      expect(find.text('viewerCaptionsPausedNotice'), findsOneWidget);

      factory.latest.emitMessage(
        const CaptionActivityChanged(activity: CaptionActivity.active),
      );
      await tester.pumpAndSettle();

      expect(find.text('viewerCaptionsPausedNotice'), findsNothing);
    });
  });
}
