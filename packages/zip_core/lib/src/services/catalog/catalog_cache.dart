import 'dart:convert';
import 'dart:io';

import 'package:zip_core/src/constants/catalog_constants.dart';
import 'package:zip_core/src/models/sherpa_model_catalog.dart';

/// File-based stale-while-revalidate cache for the model catalog (Q3=B).
///
/// Stores the raw JSON response and metadata (cachedAt, etag, lastModified)
/// in `_storageDir/catalog_cache.json` and `_storageDir/catalog_cache_meta.json`.
class CatalogCache {
  /// Creates a `CatalogCache` backed by files in `storageDir`.
  CatalogCache(this._storageDir);

  final Directory _storageDir;

  static const _cacheFileName = 'catalog_cache.json';
  static const _metaFileName = 'catalog_cache_meta.json';

  File get _cacheFile => File('${_storageDir.path}/$_cacheFileName');
  File get _metaFile => File('${_storageDir.path}/$_metaFileName');

  /// Whether a cached catalog file exists.
  bool get exists => _cacheFile.existsSync();

  /// Whether the cached catalog is within the freshness window.
  bool get isFresh {
    if (!_metaFile.existsSync()) return false;
    final meta =
        jsonDecode(_metaFile.readAsStringSync()) as Map<String, dynamic>;
    final cachedAt = DateTime.parse(meta['cachedAt'] as String);
    return DateTime.now().difference(cachedAt) <
        CatalogConstants.catalogFreshnessDuration;
  }

  /// The ETag from the last successful fetch, if available.
  String? get etag {
    if (!_metaFile.existsSync()) return null;
    final meta =
        jsonDecode(_metaFile.readAsStringSync()) as Map<String, dynamic>;
    return meta['etag'] as String?;
  }

  /// The Last-Modified header from the last successful fetch, if available.
  String? get lastModified {
    if (!_metaFile.existsSync()) return null;
    final meta =
        jsonDecode(_metaFile.readAsStringSync()) as Map<String, dynamic>;
    return meta['lastModified'] as String?;
  }

  /// Reads and deserializes the cached catalog entries.
  ///
  /// Returns an empty list if no cache file exists.
  List<SherpaModelCatalogEntry> read() {
    if (!_cacheFile.existsSync()) return [];
    final json =
        jsonDecode(_cacheFile.readAsStringSync()) as Map<String, dynamic>;
    return SherpaModelCatalogResponse.fromJson(json).models;
  }

  /// Writes catalog entries and metadata to disk.
  Future<void> write(
    List<SherpaModelCatalogEntry> entries, {
    String? etag,
    String? lastModified,
  }) async {
    await _cacheFile.writeAsString(
      jsonEncode(
        SherpaModelCatalogResponse(models: entries).toJson(),
      ),
    );
    await _metaFile.writeAsString(jsonEncode({
      'cachedAt': DateTime.now().toIso8601String(),
      'etag': ?etag,
      'lastModified': ?lastModified,
    }));
  }

  /// Updates only the `cachedAt` timestamp without changing cached data.
  ///
  /// Used after a 304 Not Modified response to refresh the freshness window.
  Future<void> touch() async {
    if (!_metaFile.existsSync()) return;
    final meta =
        jsonDecode(_metaFile.readAsStringSync()) as Map<String, dynamic>;
    meta['cachedAt'] = DateTime.now().toIso8601String();
    await _metaFile.writeAsString(jsonEncode(meta));
  }
}
