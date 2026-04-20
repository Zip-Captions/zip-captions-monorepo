/// End-to-end integration test for transcript capture.
///
/// Wires the real provider graph (CaptionBus → CaptionOutputTargetRegistry →
/// TranscriptWriterTarget → in-memory SQLite) against a controllable
/// [MockSttEngine] to verify that:
///   start() → STT final results → stop() → DB has correct sessions/segments.
///
/// Uses an in-memory database and mocks only platform boundary services
/// (WakeLockService). All business-logic providers are real.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';
import 'package:zip_core/src/output/transcript_repository.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';
import 'package:zip_core/src/providers/stt_engine_registry_provider.dart';
import 'package:zip_core/src/providers/transcript_providers.dart';
import 'package:zip_core/src/providers/transcript_writer_target_provider.dart';
import 'package:zip_core/src/providers/wake_lock_service_provider.dart';

import '../helpers/db_helpers.dart';
import '../helpers/mock_stt_engine.dart';
import '../helpers/mock_wake_lock_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SttResult _finalResult({String text = 'hello', String sourceId = 'default'}) =>
    SttResult(
      text: text,
      isFinal: true,
      confidence: 1,
      timestamp: DateTime.now(),
      sourceId: sourceId,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late ProviderContainer container;
  late MockSttEngine mockEngine;
  late TranscriptRepository repo;
  late MockWakeLockService mockWakeLock;

  setUp(() async {
    final db = await buildTestDatabase();
    repo = TranscriptRepository(db);

    mockEngine = MockSttEngine(
      requiresMicrophone: false,
      asyncDelay: Duration.zero,
    );

    mockWakeLock = MockWakeLockService();
    when(() => mockWakeLock.acquire()).thenAnswer((_) async {});
    when(() => mockWakeLock.release()).thenAnswer((_) async {});
    when(() => mockWakeLock.onPause()).thenAnswer((_) async {});
    when(() => mockWakeLock.settings).thenReturn(const WakeLockSettings());

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        wakeLockServiceProvider.overrideWithValue(mockWakeLock),
        resolvedLocaleIdProvider.overrideWithValue('en-US'),
        transcriptRepositoryProvider.overrideWith((_) async => repo),
      ],
    );

    container.read(sttEngineRegistryProvider).register(mockEngine);
    await container.read(transcriptRepositoryProvider.future);
    container.read(transcriptWriterTargetProvider);
  });

  tearDown(() async {
    container.dispose();
    await repo.dispose();
  });

  group('transcript capture — full session lifecycle', () {
    test('single final result is persisted as one segment', () async {
      final notifier =
          container.read(recordingStateNotifierProvider.notifier);

      await notifier.start();
      expect(
        container.read(recordingStateNotifierProvider),
        isA<RecordingActiveState>(),
      );

      mockEngine.emitResult(_finalResult(text: 'hello'));
      await Future<void>.delayed(Duration.zero);

      await notifier.stop();
      await Future<void>.delayed(Duration.zero);

      final sessions = await repo.getSessions();
      expect(sessions, hasLength(1));
      expect(sessions.first.segmentCount, equals(1));

      final segments = await repo.getSegments(sessions.first.sessionId);
      expect(segments, hasLength(1));
      expect(segments.first.text, equals('hello'));
    });

    test('multiple finals >2s apart each become a distinct segment', () async {
      final notifier =
          container.read(recordingStateNotifierProvider.notifier);
      await notifier.start();

      mockEngine.emitResult(_finalResult(text: 'first'));
      await Future<void>.delayed(Duration.zero);

      // Wait past the 2s merge window.
      await Future<void>.delayed(const Duration(milliseconds: 2100));

      mockEngine.emitResult(_finalResult(text: 'second'));
      await Future<void>.delayed(Duration.zero);

      await notifier.stop();
      await Future<void>.delayed(Duration.zero);

      final sessions = await repo.getSessions();
      expect(sessions, hasLength(1));
      expect(sessions.first.segmentCount, equals(2));

      final segments = await repo.getSegments(sessions.first.sessionId);
      expect(segments.map((s) => s.text).toList(), equals(['first', 'second']));
    });

    test('finals within 2s are merged into one segment', () async {
      final notifier =
          container.read(recordingStateNotifierProvider.notifier);
      await notifier.start();

      mockEngine.emitResult(_finalResult(text: 'hello'));
      await Future<void>.delayed(Duration.zero);
      mockEngine.emitResult(_finalResult(text: 'world'));
      await Future<void>.delayed(Duration.zero);

      await notifier.stop();
      await Future<void>.delayed(Duration.zero);

      final sessions = await repo.getSessions();
      expect(sessions, hasLength(1));
      expect(sessions.first.segmentCount, equals(1));

      final segments = await repo.getSegments(sessions.first.sessionId);
      expect(segments, hasLength(1));
      expect(segments.first.text, equals('hello world'));
    });

    test('stop with no results creates a session with zero segments', () async {
      final notifier =
          container.read(recordingStateNotifierProvider.notifier);
      await notifier.start();
      await notifier.stop();
      await Future<void>.delayed(Duration.zero);

      final sessions = await repo.getSessions();
      expect(sessions, hasLength(1));
      expect(sessions.first.segmentCount, equals(0));
    });

    test('capture disabled: no session or segments written', () async {
      final transcriptNotifier =
          container.read(transcriptSettingsNotifierProvider.notifier);
      await transcriptNotifier.setCaptureEnabled(value: false);

      final notifier =
          container.read(recordingStateNotifierProvider.notifier);
      await notifier.start();
      mockEngine.emitResult(_finalResult(text: 'should not save'));
      await Future<void>.delayed(Duration.zero);
      await notifier.stop();
      await Future<void>.delayed(Duration.zero);

      final sessions = await repo.getSessions();
      expect(sessions, isEmpty);
    });
  });
}
