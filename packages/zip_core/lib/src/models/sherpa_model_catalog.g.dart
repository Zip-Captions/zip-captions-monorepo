// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sherpa_model_catalog.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SherpaModelCatalogResponseImpl _$$SherpaModelCatalogResponseImplFromJson(
  Map<String, dynamic> json,
) => _$SherpaModelCatalogResponseImpl(
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
  models:
      (json['models'] as List<dynamic>?)
          ?.map(
            (e) => SherpaModelCatalogEntry.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$$SherpaModelCatalogResponseImplToJson(
  _$SherpaModelCatalogResponseImpl instance,
) => <String, dynamic>{
  'schemaVersion': instance.schemaVersion,
  'models': instance.models,
};

_$SherpaModelCatalogEntryImpl _$$SherpaModelCatalogEntryImplFromJson(
  Map<String, dynamic> json,
) => _$SherpaModelCatalogEntryImpl(
  modelId: json['modelId'] as String,
  displayName: json['displayName'] as String,
  primaryLocaleId: json['primaryLocaleId'] as String,
  downloadSizeBytes: (json['downloadSizeBytes'] as num).toInt(),
  downloadUrl: json['downloadUrl'] as String,
  sha256Checksum: json['sha256Checksum'] as String,
);

Map<String, dynamic> _$$SherpaModelCatalogEntryImplToJson(
  _$SherpaModelCatalogEntryImpl instance,
) => <String, dynamic>{
  'modelId': instance.modelId,
  'displayName': instance.displayName,
  'primaryLocaleId': instance.primaryLocaleId,
  'downloadSizeBytes': instance.downloadSizeBytes,
  'downloadUrl': instance.downloadUrl,
  'sha256Checksum': instance.sha256Checksum,
};
