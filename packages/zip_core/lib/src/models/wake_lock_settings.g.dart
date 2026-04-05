// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wake_lock_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WakeLockSettingsImpl _$$WakeLockSettingsImplFromJson(
  Map<String, dynamic> json,
) => _$WakeLockSettingsImpl(
  enabled: json['enabled'] as bool? ?? true,
  releaseOnPause: json['releaseOnPause'] as bool? ?? true,
);

Map<String, dynamic> _$$WakeLockSettingsImplToJson(
  _$WakeLockSettingsImpl instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'releaseOnPause': instance.releaseOnPause,
};
