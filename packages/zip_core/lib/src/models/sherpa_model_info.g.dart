// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sherpa_model_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SherpaModelInfoImpl _$$SherpaModelInfoImplFromJson(
  Map<String, dynamic> json,
) => _$SherpaModelInfoImpl(
  catalogEntry: SherpaModelCatalogEntry.fromJson(
    json['catalogEntry'] as Map<String, dynamic>,
  ),
  isDownloaded: json['isDownloaded'] as bool? ?? false,
  localPath: json['localPath'] as String?,
);

Map<String, dynamic> _$$SherpaModelInfoImplToJson(
  _$SherpaModelInfoImpl instance,
) => <String, dynamic>{
  'catalogEntry': instance.catalogEntry,
  'isDownloaded': instance.isDownloaded,
  'localPath': instance.localPath,
};
