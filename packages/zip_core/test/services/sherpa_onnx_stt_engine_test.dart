import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/sherpa_model_catalog.dart';
import 'package:zip_core/src/models/sherpa_model_info.dart';
import 'package:zip_core/src/services/catalog/sherpa_model_manager.dart';
import 'package:zip_core/src/stt/engines/sherpa_onnx_stt_engine.dart';

import '../helpers/mock_audio_device_service.dart';
import '../helpers/mock_online_recognizer_adapter.dart';

class MockSherpaModelManager extends Mock implements SherpaModelManager {}

void main() {
  late MockSherpaModelManager mockManager;
  late MockAudioDeviceService mockAudioService;
  late MockOnlineRecognizerAdapter mockAdapter;
  late SherpaOnnxSttEngine engine;

  setUp(() {
    mockManager = MockSherpaModelManager();
    mockAudioService = MockAudioDeviceService();
    mockAdapter = MockOnlineRecognizerAdapter();
    engine = SherpaOnnxSttEngine(
      modelManager: mockManager,
      deviceService: mockAudioService,
      recognizerAdapter: mockAdapter,
    );
  });

  group('SherpaOnnxSttEngine', () {
    test('engineId is "sherpa-onnx"', () {
      expect(engine.engineId, 'sherpa-onnx');
    });

    test('displayName is human-readable', () {
      expect(engine.displayName, isNotEmpty);
    });

    test('requiresNetwork is false', () {
      expect(engine.requiresNetwork, isFalse);
    });

    test('requiresDownload is true', () {
      expect(engine.requiresDownload, isTrue);
    });

    group('isAvailable', () {
      test('returns true when downloaded models exist', () async {
        when(() => mockManager.downloadedModels).thenReturn([
          const SherpaModelInfo(
            catalogEntry: SherpaModelCatalogEntry(
              modelId: 'm1',
              displayName: 'Model 1',
              primaryLocaleId: 'en-US',
              downloadSizeBytes: 1000,
              downloadUrl: 'https://example.com/m.tar.bz2',
              sha256Checksum: 'sha',
            ),
            isDownloaded: true,
            localPath: '/models/m1',
          ),
        ]);

        final available = await engine.isAvailable();
        expect(available, isTrue);
      });

      test('returns false when no models downloaded', () async {
        when(() => mockManager.downloadedModels).thenReturn([]);

        final available = await engine.isAvailable();
        expect(available, isFalse);
      });
    });

    group('dispose', () {
      test('disposes the adapter', () {
        when(() => mockAdapter.dispose()).thenReturn(null);

        engine.dispose();
        verify(() => mockAdapter.dispose()).called(1);
      });
    });
  });
}
