import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/sherpa_model_catalog.dart';
import 'package:zip_core/src/models/sherpa_model_info.dart';

void main() {
  const entry = SherpaModelCatalogEntry(
    modelId: 'model-1',
    displayName: 'Model 1',
    primaryLocaleId: 'en-US',
    downloadSizeBytes: 1000,
    downloadUrl: 'https://example.com/m.tar.bz2',
    sha256Checksum: 'sha',
  );

  group('SherpaModelInfo', () {
    test('creates with downloaded=false and null localPath', () {
      const info = SherpaModelInfo(catalogEntry: entry);
      expect(info.isDownloaded, isFalse);
      expect(info.localPath, isNull);
    });

    test('creates with downloaded=true and a localPath', () {
      const info = SherpaModelInfo(
        catalogEntry: entry,
        isDownloaded: true,
        localPath: '/models/model-1',
      );
      expect(info.isDownloaded, isTrue);
      expect(info.localPath, '/models/model-1');
    });

    test('equality compares all fields', () {
      const a = SherpaModelInfo(catalogEntry: entry);
      const b = SherpaModelInfo(catalogEntry: entry);
      const c = SherpaModelInfo(catalogEntry: entry, isDownloaded: true);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates updated instance', () {
      const info = SherpaModelInfo(catalogEntry: entry);
      final updated = info.copyWith(
        isDownloaded: true,
        localPath: '/new/path',
      );

      expect(updated.isDownloaded, isTrue);
      expect(updated.localPath, '/new/path');
      expect(updated.catalogEntry, equals(entry));
    });
  });
}
