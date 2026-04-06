import 'package:freezed_annotation/freezed_annotation.dart';

part 'sherpa_model_catalog.freezed.dart';
part 'sherpa_model_catalog.g.dart';

/// Response envelope from the model catalog endpoint.
@freezed
abstract class SherpaModelCatalogResponse with _$SherpaModelCatalogResponse {
  /// Creates a [SherpaModelCatalogResponse].
  const factory SherpaModelCatalogResponse({
    /// Schema version for forward compatibility.
    @Default(1) int schemaVersion,

    /// Available models in the catalog.
    @Default([]) List<SherpaModelCatalogEntry> models,
  }) = _SherpaModelCatalogResponse;

  /// Creates a [SherpaModelCatalogResponse] from JSON.
  factory SherpaModelCatalogResponse.fromJson(Map<String, dynamic> json) =>
      _$SherpaModelCatalogResponseFromJson(json);
}

/// Individual model entry from the catalog endpoint.
@freezed
abstract class SherpaModelCatalogEntry with _$SherpaModelCatalogEntry {
  /// Creates a [SherpaModelCatalogEntry].
  const factory SherpaModelCatalogEntry({
    /// Unique model identifier.
    required String modelId,

    /// Human-readable model name for UI display.
    required String displayName,

    /// BCP-47 locale that this model primarily supports.
    required String primaryLocaleId,

    /// Size of the model archive in bytes.
    required int downloadSizeBytes,

    /// HTTPS URL for the model archive download.
    required String downloadUrl,

    /// Expected SHA-256 hex digest of the downloaded archive.
    required String sha256Checksum,
  }) = _SherpaModelCatalogEntry;

  /// Creates a [SherpaModelCatalogEntry] from JSON.
  factory SherpaModelCatalogEntry.fromJson(Map<String, dynamic> json) =>
      _$SherpaModelCatalogEntryFromJson(json);
}
