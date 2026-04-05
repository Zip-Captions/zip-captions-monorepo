import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/src/constants/catalog_constants.dart';
import 'package:zip_core/src/models/sherpa_model_catalog.dart';
import 'package:zip_core/src/models/sherpa_model_download_progress.dart';
import 'package:zip_core/src/models/sherpa_model_info.dart';
import 'package:zip_core/src/services/catalog/catalog_cache.dart';
import 'package:zip_core/src/services/catalog/model_integrity_exception.dart';

/// Manages the full lifecycle of Sherpa-ONNX models: catalog, download,
/// storage, and locale mapping.
///
/// Accepts a [Dio] instance and a [Directory] for storage.
/// Uses [CatalogCache] for stale-while-revalidate caching (REL-U2.3).
class SherpaModelManager {
  /// Creates a [SherpaModelManager].
  SherpaModelManager({
    required Dio dio,
    required Directory storageDir,
  })  : _dio = dio,
        _storageDir = storageDir,
        _cache = CatalogCache(storageDir);

  static final _log = Logger('zip_core.SherpaModelManager');

  final Dio _dio;
  final Directory _storageDir;
  final CatalogCache _cache;

  List<SherpaModelCatalogEntry> _catalog = [];
  final Map<String, CancelToken> _cancelTokens = {};

  /// Returns the cached catalog immediately if fresh. If stale, returns
  /// the stale cache and triggers background revalidation (REL-U2.3).
  ///
  /// Returns `[]` only when no cache exists and the network is unavailable.
  Future<List<SherpaModelInfo>> catalogModels() async {
    if (_cache.isFresh) {
      _catalog = _cache.read();
      return _buildModelInfoList();
    }

    // Return stale cache immediately if it exists.
    if (_cache.exists) {
      _catalog = _cache.read();
      // Trigger background revalidation — fire and forget.
      unawaited(_revalidate());
      return _buildModelInfoList();
    }

    // No cache at all — must fetch.
    try {
      await _fetchCatalog();
    } on Object catch (e) {
      _log.warning('Catalog fetch failed: ${e.runtimeType}');
      return [];
    }
    return _buildModelInfoList();
  }

  /// Synchronous — returns catalog entries where a local model exists.
  List<SherpaModelInfo> get downloadedModels =>
      _buildModelInfoList().where((m) => m.isDownloaded).toList();

  /// Downloads the model archive, yields progress, verifies integrity,
  /// and extracts to `_storageDir/{modelId}/`.
  ///
  /// Supports resume via HTTP Range requests (REL-U2.2, Q6=C).
  Stream<SherpaModelDownloadProgress> downloadModel(
    String modelId,
  ) async* {
    final entry = _catalog.firstWhere((e) => e.modelId == modelId);

    // SEC-U2.2: reject non-HTTPS URLs.
    if (!entry.downloadUrl.startsWith('https://')) {
      _log.warning(
        'Rejected non-HTTPS download URL for model ${entry.modelId}',
      );
      return;
    }

    final partialFile = File('${_storageDir.path}/$modelId.partial');
    final existingBytes =
        partialFile.existsSync() ? partialFile.lengthSync() : 0;

    final cancelToken = CancelToken();
    _cancelTokens[modelId] = cancelToken;

    try {
      final response = await _dio.get<ResponseBody>(
        entry.downloadUrl,
        options: Options(
          responseType: ResponseType.stream,
          headers: existingBytes > 0
              ? {'Range': 'bytes=$existingBytes-'}
              : null,
        ),
        cancelToken: cancelToken,
      );

      final isResume = response.statusCode == 206;
      if (!isResume && existingBytes > 0) {
        await partialFile.delete();
      }

      final contentLength = int.tryParse(
            response.headers.value('content-length') ?? '',
          ) ??
          0;
      final totalBytes =
          isResume ? existingBytes + contentLength : contentLength;

      final sink = partialFile.openWrite(
        mode: isResume ? FileMode.append : FileMode.write,
      );
      var receivedBytes = isResume ? existingBytes : 0;

      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        yield SherpaModelDownloadProgress(
          modelId: modelId,
          downloadedBytes: receivedBytes,
          totalBytes: totalBytes,
        );
      }
      await sink.close();

      // Verify integrity and extract (REL-U2.4).
      await _verifyAndExtract(modelId, partialFile, entry.sha256Checksum);
    } finally {
      _cancelTokens.remove(modelId);
    }
  }

  /// Cancels an in-progress download for [modelId].
  void cancelDownload(String modelId) {
    _cancelTokens[modelId]?.cancel('User cancelled download');
    _cancelTokens.remove(modelId);
  }

  /// Deletes the extracted model directory for [modelId].
  Future<void> deleteModel(String modelId) async {
    final modelDir = Directory('${_storageDir.path}/$modelId');
    if (modelDir.existsSync()) {
      await modelDir.delete(recursive: true);
    }
    // Also clean up any partial file.
    final partialFile = File('${_storageDir.path}/$modelId.partial');
    if (partialFile.existsSync()) {
      await partialFile.delete();
    }
  }

  /// Selects the best downloaded model for a BCP-47 locale.
  ///
  /// Exact locale match > language-only match > null.
  SherpaModelInfo? bestModelForLocale(String localeId) {
    final downloaded = downloadedModels;
    if (downloaded.isEmpty) return null;

    // Exact match.
    final exact = downloaded.where(
      (m) => m.catalogEntry.primaryLocaleId == localeId,
    );
    if (exact.isNotEmpty) return exact.first;

    // Language-only match (e.g., 'en' matches 'en-US').
    final lang = localeId.split('-').first.split('_').first.toLowerCase();
    final langMatch = downloaded.where(
      (m) =>
          m.catalogEntry.primaryLocaleId
              .split('-')
              .first
              .split('_')
              .first
              .toLowerCase() ==
          lang,
    );
    if (langMatch.isNotEmpty) return langMatch.first;

    return null;
  }

  /// Returns the local filesystem path for [modelId] if downloaded.
  String? modelLocalPath(String modelId) {
    final dir = Directory('${_storageDir.path}/$modelId');
    return dir.existsSync() ? dir.path : null;
  }

  // --- Private helpers ---

  List<SherpaModelInfo> _buildModelInfoList() {
    return _catalog.map((entry) {
      final localPath = modelLocalPath(entry.modelId);
      return SherpaModelInfo(
        catalogEntry: entry,
        isDownloaded: localPath != null,
        localPath: localPath,
      );
    }).toList();
  }

  Future<void> _fetchCatalog() async {
    final response = await _dio.get<String>(
      CatalogConstants.catalogUrl,
      options: Options(
        headers: {
          if (_cache.etag != null) 'If-None-Match': _cache.etag,
          if (_cache.lastModified != null)
            'If-Modified-Since': _cache.lastModified,
        },
      ),
    );

    if (response.statusCode == 304) {
      await _cache.touch();
      _catalog = _cache.read();
      return;
    }

    final json =
        jsonDecode(response.data!) as Map<String, dynamic>;
    final catalogResponse = SherpaModelCatalogResponse.fromJson(json);
    _catalog = catalogResponse.models;

    await _cache.write(
      _catalog,
      etag: response.headers.value('etag'),
      lastModified: response.headers.value('last-modified'),
    );
  }

  Future<void> _revalidate() async {
    try {
      await _fetchCatalog();
    } on Object catch (e) {
      _log.warning('Background revalidation failed: ${e.runtimeType}');
    }
  }

  Future<void> _verifyAndExtract(
    String modelId,
    File archiveFile,
    String expectedSha256,
  ) async {
    final bytes = await archiveFile.readAsBytes();
    final digest = sha256.convert(bytes);

    if (digest.toString() != expectedSha256) {
      await archiveFile.delete();
      throw ModelIntegrityException(
        modelId: modelId,
        expected: expectedSha256,
        actual: digest.toString(),
      );
    }

    // Extract .tar.bz2 to _storageDir/{modelId}/.
    final modelDir = Directory('${_storageDir.path}/$modelId');
    await modelDir.create(recursive: true);

    final decompressed = BZip2Decoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(decompressed);
    for (final file in archive) {
      if (file.isFile) {
        // SEC-U2.3: Sanitize entry paths to prevent path traversal.
        // Strip leading slashes and reject any path component that is '..'.
        final parts = file.name
            .replaceAll(r'\', '/')
            .split('/')
            .where((p) => p.isNotEmpty && p != '..')
            .toList();
        if (parts.isEmpty) continue;
        final safePath = '${modelDir.path}/${parts.join('/')}';
        // Verify the resolved path is still within modelDir.
        if (!safePath.startsWith('${modelDir.path}/')) continue;
        final outFile = File(safePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }

    // Clean up the archive file.
    await archiveFile.delete();
  }
}
