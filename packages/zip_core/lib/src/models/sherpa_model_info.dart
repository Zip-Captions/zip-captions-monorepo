import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zip_core/src/models/sherpa_model_catalog.dart';

part 'sherpa_model_info.freezed.dart';
part 'sherpa_model_info.g.dart';

/// Merged view of catalog data and local filesystem state for a model.
///
/// Produced by [SherpaModelManager] by combining a [SherpaModelCatalogEntry]
/// with the local download state.
@freezed
abstract class SherpaModelInfo with _$SherpaModelInfo {
  /// Creates a [SherpaModelInfo].
  const factory SherpaModelInfo({
    /// The catalog entry for this model.
    required SherpaModelCatalogEntry catalogEntry,

    /// Whether the model archive has been downloaded and extracted.
    @Default(false) bool isDownloaded,

    /// Local filesystem path to the extracted model directory.
    /// Non-null only when [isDownloaded] is true.
    String? localPath,
  }) = _SherpaModelInfo;

  /// Creates a [SherpaModelInfo] from JSON.
  factory SherpaModelInfo.fromJson(Map<String, dynamic> json) =>
      _$SherpaModelInfoFromJson(json);
}
