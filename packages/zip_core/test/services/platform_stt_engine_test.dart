import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/stt/engines/platform_stt_engine.dart';

import '../helpers/mock_audio_device_service.dart';
import '../helpers/mock_speech_to_text.dart';

void main() {
  late MockSpeechToText mockStt;
  late MockAudioDeviceService mockAudioService;
  late PlatformSttEngine engine;

  setUp(() {
    mockStt = MockSpeechToText();
    mockAudioService = MockAudioDeviceService();
    engine = PlatformSttEngine(
      stt: mockStt,
      deviceService: mockAudioService,
    );
  });

  group('PlatformSttEngine', () {
    test('engineId is "platform"', () {
      expect(engine.engineId, 'platform');
    });

    test('displayName is human-readable', () {
      expect(engine.displayName, isNotEmpty);
    });

    test('requiresNetwork is false', () {
      expect(engine.requiresNetwork, isFalse);
    });

    test('requiresDownload is false', () {
      expect(engine.requiresDownload, isFalse);
    });

    group('initialize', () {
      test('returns true when SpeechToText initializes', () async {
        when(() => mockStt.initialize()).thenAnswer((_) async => true);

        final ok = await engine.initialize();
        expect(ok, isTrue);
        verify(() => mockStt.initialize()).called(1);
      });

      test('returns false when SpeechToText fails', () async {
        when(() => mockStt.initialize()).thenAnswer((_) async => false);

        final ok = await engine.initialize();
        expect(ok, isFalse);
      });
    });

    group('isAvailable', () {
      test('delegates to SpeechToText', () async {
        when(() => mockStt.initialize()).thenAnswer((_) async => true);
        when(() => mockStt.isAvailable).thenReturn(true);
        await engine.initialize();

        expect(await engine.isAvailable(), isTrue);
        verify(() => mockStt.isAvailable).called(1);
      });
    });

    group('supportedLocales', () {
      test('returns locales from SpeechToText', () async {
        when(() => mockStt.initialize()).thenAnswer((_) async => true);
        when(() => mockStt.locales()).thenAnswer(
          (_) async => [
            LocaleName('en_US', 'English (US)'),
            LocaleName('fr_FR', 'French'),
          ],
        );
        await engine.initialize();

        final locales = await engine.supportedLocales();
        expect(locales, hasLength(2));
        expect(locales.first.localeId, 'en_US');
      });
    });

    group('startListening', () {
      test('sets preferred device before starting', () async {
        when(() => mockStt.initialize()).thenAnswer((_) async => true);
        when(
          () => mockStt.listen(
            onResult: any(named: 'onResult'),
            localeId: any(named: 'localeId'),
          ),
        ).thenAnswer((_) async {});
        when(() => mockAudioService.currentPreferredDeviceId).thenReturn(null);

        await engine.initialize();
        final results = <SttResult>[];
        final ok = await engine.startListening(
          localeId: 'en-US',
          onResult: results.add,
        );

        expect(ok, isTrue);
      });
    });

    group('dispose', () {
      test('cancels SpeechToText', () async {
        when(() => mockStt.initialize()).thenAnswer((_) async => true);
        when(() => mockStt.cancel()).thenAnswer((_) async {});

        await engine.initialize();
        engine.dispose();

        verify(() => mockStt.cancel()).called(1);
      });
    });
  });
}
