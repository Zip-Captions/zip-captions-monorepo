import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/sherpa_model_catalog.dart';
import 'package:zip_core/src/services/catalog/catalog_cache.dart';

void main() {
  late Directory tempDir;
  late CatalogCache cache;

  const testEntries = [
    SherpaModelCatalogEntry(
      modelId: 'test-model',
      displayName: 'Test',
      primaryLocaleId: 'en-US',
      downloadSizeBytes: 1000,
      downloadUrl: 'https://example.com/m.tar.bz2',
      sha256Checksum: 'sha',
    ),
  ];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cache_test_');
    cache = CatalogCache(tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CatalogCache', () {
    test('write then read returns same entries', () async {
      await cache.write(
        testEntries,
        etag: 'etag-1',
        lastModified: 'Thu, 01 Jan 2026 00:00:00 GMT',
      );

      final data = cache.read();
      expect(data, hasLength(1));
      expect(data.first.modelId, 'test-model');
    });

    test('read returns empty list when cache is empty', () {
      final data = cache.read();
      expect(data, isEmpty);
    });

    test('exists is false when no cache file', () {
      expect(cache.exists, isFalse);
    });

    test('exists is true after write', () async {
      await cache.write(testEntries);
      expect(cache.exists, isTrue);
    });

    test('isFresh returns true for recent write', () async {
      await cache.write(testEntries);
      expect(cache.isFresh, isTrue);
    });

    test('etag is returned after write', () async {
      await cache.write(testEntries, etag: 'my-etag');
      expect(cache.etag, 'my-etag');
    });

    test('lastModified is returned after write', () async {
      await cache.write(testEntries, lastModified: 'some-date');
      expect(cache.lastModified, 'some-date');
    });

    test('etag is null when no meta exists', () {
      expect(cache.etag, isNull);
    });

    test('touch updates freshness without changing data', () async {
      await cache.write(testEntries, etag: 'e1');
      await cache.touch();
      expect(cache.isFresh, isTrue);
      expect(cache.etag, 'e1');
    });
  });
}
