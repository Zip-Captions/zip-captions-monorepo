import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/constants/catalog_constants.dart';
import 'package:zip_core/src/models/sherpa_model_catalog.dart';
import 'package:zip_core/src/models/sherpa_model_catalog_state.dart';
import 'package:zip_core/src/models/sherpa_model_info.dart';

void main() {
  group('SherpaModelCatalogState', () {
    test('initial state has empty models and downloads', () {
      const state = SherpaModelCatalogState();
      expect(state.models, isEmpty);
      expect(state.activeDownloads, isEmpty);
      expect(state.lastFailedDownloadId, isNull);
      expect(state.pendingConfirmationModelId, isNull);
    });

    test('copyWith updates models', () {
      const state = SherpaModelCatalogState();
      final updated = state.copyWith(
        models: const [
          SherpaModelInfo(
            catalogEntry: SherpaModelCatalogEntry(
              modelId: 'm1',
              displayName: 'M1',
              primaryLocaleId: 'en-US',
              downloadSizeBytes: 100,
              downloadUrl: 'https://x.com/m.tar.bz2',
              sha256Checksum: 'sha',
            ),
          ),
        ],
      );

      expect(updated.models, hasLength(1));
    });

    test('confirmation gate triggers for large models', () {
      // The threshold from constants is 100 MB.
      expect(
        CatalogConstants.downloadConfirmationThresholdBytes,
        100 * 1024 * 1024,
      );
    });

    test('copyWith sets pendingConfirmationModelId', () {
      const state = SherpaModelCatalogState();
      final updated =
          state.copyWith(pendingConfirmationModelId: 'large-model');
      expect(updated.pendingConfirmationModelId, 'large-model');
    });

    test('copyWith clears pendingConfirmationModelId', () {
      final state = const SherpaModelCatalogState()
          .copyWith(pendingConfirmationModelId: 'x');
      final cleared = state.copyWith(pendingConfirmationModelId: null);
      expect(cleared.pendingConfirmationModelId, isNull);
    });
  });
}
