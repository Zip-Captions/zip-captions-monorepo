/// Widget tests for HistoryScreen data flow.
///
/// Covers: empty state, session tiles appearing after a recording stops,
/// search/filter with 300ms debounce, swipe-to-delete with confirmation.
/// All tests use a real in-memory SQLite repository — no provider stubs for
/// the data layer.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/screens/history_screen.dart';
import 'package:zip_core/src/database/transcript_database.dart';
import 'package:zip_core/src/models/transcript_segment.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/fake_recording_state_notifier.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<TranscriptRepository> _buildRepo() async {
  final db = TranscriptDatabase(
    NativeDatabase.memory(
      setup: (rawDb) {
        rawDb
          ..execute('PRAGMA journal_mode=WAL')
          ..execute('PRAGMA foreign_keys=ON');
      },
    ),
  );
  await db.customSelect('SELECT 1').get();
  return TranscriptRepository(db);
}

GoRouter _router() => GoRouter(
      initialLocation: '/history',
      routes: [
        GoRoute(
          path: '/history',
          builder: (ctx, s) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/history/:sessionId',
          builder: (ctx, s) => const SizedBox(key: Key('viewer')),
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  TranscriptRepository repo,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        transcriptRepositoryProvider.overrideWith((_) async => repo),
        recordingStateNotifierProvider.overrideWith(
          () => FakeRecordingStateNotifier(const RecordingState.idle()),
        ),
      ],
      child: MaterialApp.router(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        routerConfig: _router(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late TranscriptRepository repo;

  setUp(() async {
    repo = await _buildRepo();
  });

  tearDown(() => repo.dispose());

  tearDown(() => repo.dispose());

  group('HistoryScreen — empty state', () {
    testWidgets('shows placeholder when no sessions exist', (tester) async {
      await _pump(tester, repo);

      expect(
        find.text(
          'No transcripts yet. Start captioning to save your first session.',
        ),
        findsOneWidget,
      );
    });
  });

  group('HistoryScreen — sessions list', () {
    testWidgets('shows a tile for each saved session', (tester) async {
      await repo.createSession('ses-1', DateTime.utc(2026, 1, 1));
      await repo.finalizeSession('ses-1', durationMs: 60000, segmentCount: 2);
      await repo.createSession('ses-2', DateTime.utc(2026, 1, 2));
      await repo.finalizeSession('ses-2', durationMs: 30000, segmentCount: 1);

      await _pump(tester, repo);

      expect(find.text('2026-01-01'), findsOneWidget);
      expect(find.text('2026-01-02'), findsOneWidget);
    });

    testWidgets('tile shows segment count', (tester) async {
      await repo.createSession('ses-1', DateTime.utc(2026, 1, 1));
      await repo.finalizeSession('ses-1', durationMs: 5000, segmentCount: 3);

      await _pump(tester, repo);

      expect(find.textContaining('3 segments'), findsOneWidget);
    });

    testWidgets('tapping a tile navigates to the viewer', (tester) async {
      await repo.createSession('ses-1', DateTime.utc(2026, 1, 1));
      await repo.finalizeSession('ses-1', durationMs: 5000, segmentCount: 1);

      await _pump(tester, repo);

      await tester.tap(find.text('2026-01-01'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('viewer')), findsOneWidget);
    });
  });

  group('HistoryScreen — search', () {
    setUp(() async {
      await repo.createSession('ses-alpha', DateTime.utc(2026, 1, 1));
      await repo.finalizeSession(
        'ses-alpha',
        durationMs: 5000,
        segmentCount: 1,
      );
      await repo.saveSegment(
        'ses-alpha',
        const TranscriptSegment(
          segmentId: 'seg-1',
          sessionId: 'ses-alpha',
          text: 'hello world',
          sourceId: 'default',
          startTimeMs: 0,
          endTimeMs: 500,
        ),
      );

      await repo.createSession('ses-beta', DateTime.utc(2026, 1, 2));
      await repo.finalizeSession(
        'ses-beta',
        durationMs: 5000,
        segmentCount: 1,
      );
      await repo.saveSegment(
        'ses-beta',
        const TranscriptSegment(
          segmentId: 'seg-2',
          sessionId: 'ses-beta',
          text: 'goodbye cruel world',
          sourceId: 'default',
          startTimeMs: 0,
          endTimeMs: 500,
        ),
      );
    });

    testWidgets('typing a query shows only matching sessions after debounce',
        (tester) async {
      await _pump(tester, repo);

      await tester.enterText(find.byType(SearchBar), 'hello');
      // Advance past the 300ms debounce.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('2026-01-01'), findsOneWidget);
      expect(find.text('2026-01-02'), findsNothing);
    });

    testWidgets('clearing the query restores the full list', (tester) async {
      await _pump(tester, repo);

      await tester.enterText(find.byType(SearchBar), 'hello');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(SearchBar), '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('2026-01-01'), findsOneWidget);
      expect(find.text('2026-01-02'), findsOneWidget);
    });

    testWidgets('query with no matches shows no-results placeholder',
        (tester) async {
      await _pump(tester, repo);

      await tester.enterText(find.byType(SearchBar), 'xyzzy');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('No results for this search.'), findsOneWidget);
    });
  });

  group('HistoryScreen — swipe to delete', () {
    testWidgets('confirming delete removes the tile and persists the deletion',
        (tester) async {
      await repo.createSession('ses-1', DateTime.utc(2026, 1, 1));
      await repo.finalizeSession('ses-1', durationMs: 5000, segmentCount: 1);
      await repo.createSession('ses-2', DateTime.utc(2026, 1, 2));
      await repo.finalizeSession('ses-2', durationMs: 5000, segmentCount: 1);

      await _pump(tester, repo);
      expect(find.text('2026-01-01'), findsOneWidget);

      await tester.drag(
        find.text('2026-01-01'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('2026-01-01'), findsNothing);
      expect(find.text('2026-01-02'), findsOneWidget);

      // Verify deletion persisted to the repo.
      final sessions = await repo.getSessions();
      expect(sessions, hasLength(1));
      expect(sessions.first.sessionId, equals('ses-2'));
    });

    testWidgets('cancelling delete keeps the tile', (tester) async {
      await repo.createSession('ses-1', DateTime.utc(2026, 1, 1));
      await repo.finalizeSession('ses-1', durationMs: 5000, segmentCount: 1);

      await _pump(tester, repo);

      await tester.drag(
        find.text('2026-01-01'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('2026-01-01'), findsOneWidget);
    });
  });
}
