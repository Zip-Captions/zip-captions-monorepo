import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/sherpa_model_catalog.dart';

void main() {
  group('SherpaModelCatalogEntry', () {
    const entry = SherpaModelCatalogEntry(
      modelId: 'sherpa-en-us-v1',
      displayName: 'English (US) v1',
      primaryLocaleId: 'en-US',
      downloadSizeBytes: 52428800,
      downloadUrl: 'https://example.com/model.tar.bz2',
      sha256Checksum: 'abc123def456',
    );

    test('creates with all required fields', () {
      expect(entry.modelId, 'sherpa-en-us-v1');
      expect(entry.displayName, 'English (US) v1');
      expect(entry.primaryLocaleId, 'en-US');
      expect(entry.downloadSizeBytes, 52428800);
      expect(entry.downloadUrl, 'https://example.com/model.tar.bz2');
      expect(entry.sha256Checksum, 'abc123def456');
    });

    test('equality compares all fields', () {
      const same = SherpaModelCatalogEntry(
        modelId: 'sherpa-en-us-v1',
        displayName: 'English (US) v1',
        primaryLocaleId: 'en-US',
        downloadSizeBytes: 52428800,
        downloadUrl: 'https://example.com/model.tar.bz2',
        sha256Checksum: 'abc123def456',
      );
      expect(entry, equals(same));
    });

    test('JSON round-trip preserves all fields', () {
      final json = entry.toJson();
      final restored = SherpaModelCatalogEntry.fromJson(json);
      expect(restored, equals(entry));
    });
  });

  group('SherpaModelCatalogResponse', () {
    test('JSON round-trip preserves schema version and models', () {
      final json = <String, dynamic>{
        'schemaVersion': 1,
        'models': [
          {
            'modelId': 'model-1',
            'displayName': 'Model 1',
            'primaryLocaleId': 'en-US',
            'downloadSizeBytes': 1000,
            'downloadUrl': 'https://example.com/m1.tar.bz2',
            'sha256Checksum': 'sha1',
          },
        ],
      };

      final response = SherpaModelCatalogResponse.fromJson(json);
      expect(response.schemaVersion, 1);
      expect(response.models, hasLength(1));
      expect(response.models.first.modelId, 'model-1');
      expect(response.models.first.displayName, 'Model 1');
    });

    test('deserializes from raw JSON string', () {
      const raw = '''
      {
        "schemaVersion": 2,
        "models": [
          {
            "modelId": "test",
            "displayName": "Test",
            "primaryLocaleId": "fr-FR",
            "downloadSizeBytes": 500,
            "downloadUrl": "https://x.com/t.tar.bz2",
            "sha256Checksum": "check"
          }
        ]
      }
      ''';

      final response = SherpaModelCatalogResponse.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      expect(response.schemaVersion, 2);
      expect(response.models.first.modelId, 'test');
      expect(response.models.first.primaryLocaleId, 'fr-FR');
    });
  });
}
