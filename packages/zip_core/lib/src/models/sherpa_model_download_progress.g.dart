// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sherpa_model_download_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SherpaModelDownloadProgressImpl _$$SherpaModelDownloadProgressImplFromJson(
  Map<String, dynamic> json,
) => _$SherpaModelDownloadProgressImpl(
  modelId: json['modelId'] as String,
  downloadedBytes: (json['downloadedBytes'] as num).toInt(),
  totalBytes: (json['totalBytes'] as num).toInt(),
);

Map<String, dynamic> _$$SherpaModelDownloadProgressImplToJson(
  _$SherpaModelDownloadProgressImpl instance,
) => <String, dynamic>{
  'modelId': instance.modelId,
  'downloadedBytes': instance.downloadedBytes,
  'totalBytes': instance.totalBytes,
};
