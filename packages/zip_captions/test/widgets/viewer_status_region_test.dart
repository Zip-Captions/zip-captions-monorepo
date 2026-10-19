import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_captions/src/providers/viewer_announcer_provider.dart';
import 'package:zip_captions/src/widgets/viewer_status_region.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/viewer_test_harness.dart';

Future<List<String>> _pumpRegion(
  WidgetTester tester,
  String text, {
  ViewerSessionState state = const ViewerSessionState.idle(),
  String? body,
  bool supportsAnnounce = true,
}) async {
  final announcements = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sentinelStringsOverride(),
        viewerAnnouncerProvider.overrideWithValue(
          (view, message) => announcements.add(message),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(supportsAnnounce: supportsAnnounce),
          child: child!,
        ),
        home: Scaffold(
          body: ViewerStatusRegion(state: state, text: text, body: body),
        ),
      ),
    ),
  );
  await tester.pump();
  return announcements;
}

void main() {
  group('ViewerStatusRegion', () {
    testWidgets('renders exactly one status line and an optional body', (
      tester,
    ) async {
      await _pumpRegion(tester, 'Live', body: 'Supporting copy');

      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Supporting copy'), findsOneWidget);
    });

    testWidgets('exposes a single live region label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpRegion(tester, 'Live', body: 'Supporting copy');

      expect(
        tester.getSemantics(find.byType(ViewerStatusRegion)),
        matchesSemantics(
          isLiveRegion: true,
          label: 'Live. Supporting copy',
          textDirection: TextDirection.ltr,
        ),
      );
      handle.dispose();
    });

    testWidgets('announces once on first mount', (tester) async {
      final announcements = await _pumpRegion(tester, 'Live');

      expect(announcements, ['Live']);
    });

    testWidgets('announces a copy change once', (tester) async {
      final announcements = await _pumpRegion(tester, 'Live');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sentinelStringsOverride(),
            viewerAnnouncerProvider.overrideWithValue(
              (view, message) => announcements.add(message),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ViewerStatusRegion(
                state: ViewerSessionState.reconnecting(),
                text: 'Reconnecting',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(announcements, ['Live', 'Reconnecting']);
    });

    testWidgets('does not announce when the platform opt-out is set', (
      tester,
    ) async {
      final announcements = await _pumpRegion(
        tester,
        'Live',
        supportsAnnounce: false,
      );

      expect(announcements, isEmpty);
      // The live region itself still carries the status for the reader that
      // consumes it in document order.
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('an empty title announces nothing', (tester) async {
      final announcements = await _pumpRegion(tester, '');

      expect(announcements, isEmpty);
    });

    testWidgets('an empty first frame does not spoil the first real '
        'announcement', (tester) async {
      final announcements = await _pumpRegion(tester, '');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sentinelStringsOverride(),
            viewerAnnouncerProvider.overrideWithValue(
              (view, message) => announcements.add(message),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ViewerStatusRegion(
                state: ViewerSessionState.resolving(),
                text: 'Connecting',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(announcements, ['Connecting']);
    });

    testWidgets('announces again after an opt-out toggle mid-session', (
      tester,
    ) async {
      final announcements = <String>[];
      Widget region({required bool supportsAnnounce, required String text}) =>
          ProviderScope(
            overrides: [
              sentinelStringsOverride(),
              viewerAnnouncerProvider.overrideWithValue(
                (view, message) => announcements.add(message),
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(supportsAnnounce: supportsAnnounce),
                child: child!,
              ),
              home: Scaffold(
                body: ViewerStatusRegion(
                  state: const ViewerSessionState.liveView(
                    captionActivity: CaptionActivity.active,
                    connectionType: ConnectionType.p2pDirect,
                  ),
                  text: text,
                ),
              ),
            ),
          );

      await tester.pumpWidget(region(supportsAnnounce: true, text: 'Live'));
      await tester.pump();
      expect(announcements, ['Live']);

      await tester.pumpWidget(region(supportsAnnounce: false, text: 'Live'));
      await tester.pumpWidget(
        region(supportsAnnounce: false, text: 'Reconnecting'),
      );
      await tester.pump();
      expect(announcements, ['Live']);

      await tester.pumpWidget(region(supportsAnnounce: true, text: 'Ended'));
      await tester.pump();

      expect(announcements, ['Live', 'Ended']);
    });

    testWidgets('does not re-announce identical copy on rebuild', (
      tester,
    ) async {
      final announcements = await _pumpRegion(tester, 'Live');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sentinelStringsOverride(),
            viewerAnnouncerProvider.overrideWithValue(
              (view, message) => announcements.add(message),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ViewerStatusRegion(
                state: ViewerSessionState.liveView(
                  captionActivity: CaptionActivity.active,
                  connectionType: ConnectionType.p2pDirect,
                ),
                text: 'Live',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(announcements, ['Live']);
    });
  });
}
