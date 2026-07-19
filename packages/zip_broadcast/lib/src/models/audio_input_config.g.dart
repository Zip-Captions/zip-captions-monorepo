// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_input_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AudioInputConfigImpl _$$AudioInputConfigImplFromJson(
  Map<String, dynamic> json,
) => _$AudioInputConfigImpl(
  deviceId: json['deviceId'] as String,
  name: json['name'] as String,
  label: json['label'] as String? ?? '',
  colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$AudioInputConfigImplToJson(
  _$AudioInputConfigImpl instance,
) => <String, dynamic>{
  'deviceId': instance.deviceId,
  'name': instance.name,
  'label': instance.label,
  'colorIndex': instance.colorIndex,
};
