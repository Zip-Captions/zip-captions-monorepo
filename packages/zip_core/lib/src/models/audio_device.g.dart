// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AudioDeviceImpl _$$AudioDeviceImplFromJson(Map<String, dynamic> json) =>
    _$AudioDeviceImpl(
      deviceId: json['deviceId'] as String,
      name: json['name'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$$AudioDeviceImplToJson(_$AudioDeviceImpl instance) =>
    <String, dynamic>{
      'deviceId': instance.deviceId,
      'name': instance.name,
      'isDefault': instance.isDefault,
    };
