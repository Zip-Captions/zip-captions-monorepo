import 'package:freezed_annotation/freezed_annotation.dart';

part 'sherpa_model_download_progress.freezed.dart';
part 'sherpa_model_download_progress.g.dart';

/// In-progress download state for a Sherpa-ONNX model archive.
///
/// Emitted by `SherpaModelManager.downloadModel` as a stream of progress
/// events.
@freezed
abstract class SherpaModelDownloadProgress
    with _$SherpaModelDownloadProgress {
  /// Creates a [SherpaModelDownloadProgress].
  const factory SherpaModelDownloadProgress({
    /// The model being downloaded.
    required String modelId,

    /// Bytes downloaded so far (including any resumed bytes).
    required int downloadedBytes,

    /// Total bytes expected for the complete download.
    required int totalBytes,
  }) = _SherpaModelDownloadProgress;

  /// Creates a [SherpaModelDownloadProgress] from JSON.
  factory SherpaModelDownloadProgress.fromJson(Map<String, dynamic> json) =>
      _$SherpaModelDownloadProgressFromJson(json);
}
