import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zip_core/src/models/sherpa_model_download_progress.dart';
import 'package:zip_core/src/models/sherpa_model_info.dart';

part 'sherpa_model_catalog_state.freezed.dart';

/// State for [SherpaModelCatalogNotifier].
///
/// Holds the full model catalog, active download progress, and error/
/// confirmation tracking.
@freezed
abstract class SherpaModelCatalogState with _$SherpaModelCatalogState {
  /// Creates a [SherpaModelCatalogState].
  const factory SherpaModelCatalogState({
    /// Full catalog: downloaded + available to download.
    @Default([]) List<SherpaModelInfo> models,

    /// In-progress downloads keyed by modelId.
    @Default({})
    Map<String, SherpaModelDownloadProgress> activeDownloads,

    /// Model ID of the last download that failed, if any.
    String? lastFailedDownloadId,

    /// Model ID awaiting user confirmation before download (> 100MB).
    String? pendingConfirmationModelId,
  }) = _SherpaModelCatalogState;
}
