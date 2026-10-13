// Tests for `DefaultCaptioningStarter` (Unit 6, Functional Design Q1):
// confirms its `currentActivity` mapping matches
// `RemoteBroadcastTarget._mapActivity` exactly for every `RecordingState`
// variant, and that `start()` genuinely delegates to the real
// `RecordingStateNotifier` it wraps (not a separate, divergent mechanism).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/providers/captioning_starter_provider.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';
import 'package:zip_core/src/providers/stt_engine_provider.dart';
import 'package:zip_core/src/providers/stt_session_manager_provider.dart';
import 'package:zip_core/src/providers/wake_lock_service_provider.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';
import 'package:zip_core/src/services/caption/captioning_starter.dart';

import '../../helpers/mock_stt_engine.dart';
import '../../helpers/mock_stt_session_manager.dart';
import '../../helpers/mock_wake_lock_service.dart';

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

    when(
      () => mockSessionManager.initialize(
        engineId: any(named: 'engineId'),
        localeId: any(named: 'localeId'),
        onResult: any(named: 'onResult'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockSessionManager.startListening(),
    ).thenAnswer((_) async => true);
    when(() => mockSessionManager.pause()).thenAnswer((_) async => true);
    when(() => mockSessionManager.resume()).thenAnswer((_) async => true);
    when(() => mockSessionManager.stop()).thenAnswer((_) async {});
    when(() => mockWakeLockService.acquire()).thenAnswer((_) async {});
    when(() => mockWakeLockService.release()).thenAnswer((_) async {});
    when(() => mockWakeLockService.onPause()).thenAnswer((_) async {});
    when(
      () => mockWakeLockService.settings,
    ).thenReturn(const WakeLockSettings());

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

  CaptioningStarter starter() => container.read(captioningStarterProvider);
  RecordingStateNotifier recordingNotifier() =>
      container.read(recordingStateNotifierProvider.notifier);

  group('DefaultCaptioningStarter.currentActivity mapping', () {
    test('defaults to inactive (RecordingStateNotifier starts idle)', () {
      expect(starter().currentActivity, CaptionActivity.inactive);
    });

    test('active once RecordingStateNotifier is recording', () async {
      await recordingNotifier().start();
      expect(starter().currentActivity, CaptionActivity.active);
    });

    test('paused once RecordingStateNotifier is paused', () async {
      await recordingNotifier().start();
      await recordingNotifier().pause();
      expect(starter().currentActivity, CaptionActivity.paused);
    });

    test('inactive once RecordingStateNotifier is stopped', () async {
      await recordingNotifier().start();
      await recordingNotifier().stop();
      expect(starter().currentActivity, CaptionActivity.inactive);
    });
  });

  group('DefaultCaptioningStarter.start()', () {
    test('delegates to the real RecordingStateNotifier.start()', () async {
      await starter().start();
      expect(
        container.read(recordingStateNotifierProvider),
        isA<RecordingActiveState>(),
      );
      expect(starter().currentActivity, CaptionActivity.active);
    });

    test('is a no-op when already recording (the wrapped notifier guards '
        'itself)', () async {
      await recordingNotifier().start();
      await starter().start();
      verify(
        () => mockSessionManager.initialize(
          engineId: any(named: 'engineId'),
          localeId: any(named: 'localeId'),
          onResult: any(named: 'onResult'),
          onError: any(named: 'onError'),
        ),
      ).called(1);
    });
  });
}
