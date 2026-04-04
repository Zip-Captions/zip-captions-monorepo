import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';
import 'package:zip_core/src/providers/stt_engine_provider.dart';
import 'package:zip_core/src/providers/stt_session_manager_provider.dart';
import 'package:zip_core/src/providers/wake_lock_service_provider.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';

import '../helpers/mock_stt_engine.dart';
import '../helpers/mock_stt_session_manager.dart';
import '../helpers/mock_wake_lock_service.dart';

void main() {
  late ProviderContainer container;
  late CaptionBus captionBus;
  late MockSttSessionManager mockSessionManager;
  late MockWakeLockService mockWakeLockService;
  late MockSttEngine mockEngine;

  setUp(() {
    captionBus = CaptionBus();
    mockSessionManager = MockSttSessionManager();
    mockWakeLockService = MockWakeLockService();
    mockEngine = MockSttEngine();

    // Default stubs.
    when(() => mockSessionManager.initialize(
          engineId: any(named: 'engineId'),
          localeId: any(named: 'localeId'),
          onResult: any(named: 'onResult'),
          onError: any(named: 'onError'),
        )).thenAnswer((_) async => true);
    when(() => mockSessionManager.startListening())
        .thenAnswer((_) async => true);
    when(() => mockSessionManager.pause()).thenAnswer((_) async => true);
    when(() => mockSessionManager.resume()).thenAnswer((_) async => true);
    when(() => mockSessionManager.stop()).thenAnswer((_) async {});
    when(() => mockWakeLockService.acquire()).thenAnswer((_) async {});
    when(() => mockWakeLockService.release()).thenAnswer((_) async {});
    when(() => mockWakeLockService.onPause()).thenAnswer((_) async {});
    when(() => mockWakeLockService.settings)
        .thenReturn(const WakeLockSettings());

    container = ProviderContainer(
      overrides: [
        captionBusProvider.overrideWithValue(captionBus),
        sttSessionManagerProvider.overrideWithValue(mockSessionManager),
        wakeLockServiceProvider.overrideWithValue(mockWakeLockService),
        sttEngineProvider.overrideWithValue(mockEngine),
        resolvedLocaleIdProvider.overrideWithValue('en-US'),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    captionBus.dispose();
  });

  RecordingStateNotifier notifier() =>
      container.read(recordingStateNotifierProvider.notifier);

  RecordingState state() =>
      container.read(recordingStateNotifierProvider);

  group('RecordingStateNotifier', () {
    test('initial state is idle', () {
      expect(state(), isA<IdleState>());
    });

    group('valid transitions', () {
      test('idle -> recording via start', () async {
        await notifier().start();
        expect(state(), isA<RecordingActiveState>());
      });

      test('recording -> paused via pause', () async {
        await notifier().start();
        await notifier().pause();
        expect(state(), isA<PausedState>());
      });

      test('paused -> recording via resume', () async {
        await notifier().start();
        await notifier().pause();
        await notifier().resume();
        expect(state(), isA<RecordingActiveState>());
      });

      test('recording -> stopped via stop', () async {
        await notifier().start();
        await notifier().stop();
        expect(state(), isA<StoppedState>());
      });

      test('paused -> stopped via stop', () async {
        await notifier().start();
        await notifier().pause();
        await notifier().stop();
        expect(state(), isA<StoppedState>());
      });

      test('stopped -> idle via clearSession', () async {
        await notifier().start();
        await notifier().stop();
        notifier().clearSession();
        expect(state(), isA<IdleState>());
      });
    });

    group('invalid transitions (no-op)', () {
      test('pause from idle is no-op', () async {
        await notifier().pause();
        expect(state(), isA<IdleState>());
      });

      test('resume from idle is no-op', () async {
        await notifier().resume();
        expect(state(), isA<IdleState>());
      });

      test('stop from idle is no-op', () async {
        await notifier().stop();
        expect(state(), isA<IdleState>());
      });

      test('clearSession from idle is no-op', () {
        notifier().clearSession();
        expect(state(), isA<IdleState>());
      });

      test('start from recording is no-op', () async {
        await notifier().start();
        final sessionId = (state() as RecordingActiveState).sessionId;
        await notifier().start();
        expect((state() as RecordingActiveState).sessionId, sessionId);
      });
    });

    group('sessionId', () {
      test('generated on start', () async {
        await notifier().start();
        final s = state() as RecordingActiveState;
        expect(s.sessionId, isNotEmpty);
      });

      test('preserved through pause/resume', () async {
        await notifier().start();
        final sessionId = (state() as RecordingActiveState).sessionId;
        await notifier().pause();
        expect((state() as PausedState).sessionId, sessionId);
        await notifier().resume();
        expect((state() as RecordingActiveState).sessionId, sessionId);
      });

      test('new sessionId on fresh start after clearSession', () async {
        await notifier().start();
        final first = (state() as RecordingActiveState).sessionId;
        await notifier().stop();
        notifier().clearSession();
        await notifier().start();
        final second = (state() as RecordingActiveState).sessionId;
        expect(second, isNot(equals(first)));
      });
    });

    group('SttSessionManager integration', () {
      test('start calls initialize + startListening', () async {
        await notifier().start();
        verify(() => mockSessionManager.initialize(
              engineId: any(named: 'engineId'),
              localeId: any(named: 'localeId'),
              onResult: any(named: 'onResult'),
              onError: any(named: 'onError'),
            )).called(1);
        verify(() => mockSessionManager.startListening()).called(1);
      });

      test('pause calls sessionManager.pause', () async {
        await notifier().start();
        await notifier().pause();
        verify(() => mockSessionManager.pause()).called(1);
      });

      test('resume calls sessionManager.resume', () async {
        await notifier().start();
        await notifier().pause();
        await notifier().resume();
        verify(() => mockSessionManager.resume()).called(1);
      });

      test('stop calls sessionManager.stop', () async {
        await notifier().start();
        await notifier().stop();
        verify(() => mockSessionManager.stop()).called(1);
      });
    });

    group('WakeLockService integration', () {
      test('start acquires wake lock', () async {
        await notifier().start();
        verify(() => mockWakeLockService.acquire()).called(1);
      });

      test('pause calls onPause', () async {
        await notifier().start();
        await notifier().pause();
        verify(() => mockWakeLockService.onPause()).called(1);
      });

      test('resume re-acquires wake lock', () async {
        await notifier().start();
        await notifier().pause();
        await notifier().resume();
        verify(() => mockWakeLockService.acquire()).called(2);
      });

      test('stop releases wake lock', () async {
        await notifier().start();
        await notifier().stop();
        verify(() => mockWakeLockService.release()).called(1);
      });
    });

    group('no engine available', () {
      test('start with null engine sets error and stays idle', () async {
        final noEngineContainer = ProviderContainer(
          overrides: [
            captionBusProvider.overrideWithValue(captionBus),
            sttSessionManagerProvider.overrideWithValue(mockSessionManager),
            wakeLockServiceProvider.overrideWithValue(mockWakeLockService),
            sttEngineProvider.overrideWithValue(null),
            resolvedLocaleIdProvider.overrideWithValue('en-US'),
          ],
        );
        addTearDown(noEngineContainer.dispose);

        final n = noEngineContainer.read(
          recordingStateNotifierProvider.notifier,
        );
        await n.start();

        final s = noEngineContainer.read(recordingStateNotifierProvider);
        expect(s, isA<IdleState>());
        expect(n.lastError, isNotNull);
      });
    });

    group('CaptionBus events', () {
      test('start publishes SessionStateEvent', () async {
        final events = <CaptionEvent>[];
        captionBus.stream.listen(events.add);

        await notifier().start();
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(
          (events.first as SessionStateEvent).state,
          isA<RecordingActiveState>(),
        );
      });

      test('stop publishes SessionStateEvent with StoppedState', () async {
        await notifier().start();

        final events = <CaptionEvent>[];
        captionBus.stream.listen(events.add);

        await notifier().stop();
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(
          (events.first as SessionStateEvent).state,
          isA<StoppedState>(),
        );
      });
    });
  });
}
