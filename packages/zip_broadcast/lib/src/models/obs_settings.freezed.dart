// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'obs_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ObsSettings {
  /// OBS WebSocket host. Persisted to `SharedPreferences` key `obs.host`.
  String get host => throw _privateConstructorUsedError;

  /// OBS WebSocket port. Persisted to `SharedPreferences` key `obs.port`.
  int get port => throw _privateConstructorUsedError;

  /// OBS WebSocket password. Persisted to `flutter_secure_storage` key
  /// `obs.password`. Never logged.
  String get password => throw _privateConstructorUsedError;

  /// Create a copy of ObsSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ObsSettingsCopyWith<ObsSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ObsSettingsCopyWith<$Res> {
  factory $ObsSettingsCopyWith(
    ObsSettings value,
    $Res Function(ObsSettings) then,
  ) = _$ObsSettingsCopyWithImpl<$Res, ObsSettings>;
  @useResult
  $Res call({String host, int port, String password});
}

/// @nodoc
class _$ObsSettingsCopyWithImpl<$Res, $Val extends ObsSettings>
    implements $ObsSettingsCopyWith<$Res> {
  _$ObsSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ObsSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? port = null,
    Object? password = null,
  }) {
    return _then(
      _value.copyWith(
            host: null == host
                ? _value.host
                : host // ignore: cast_nullable_to_non_nullable
                      as String,
            port: null == port
                ? _value.port
                : port // ignore: cast_nullable_to_non_nullable
                      as int,
            password: null == password
                ? _value.password
                : password // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ObsSettingsImplCopyWith<$Res>
    implements $ObsSettingsCopyWith<$Res> {
  factory _$$ObsSettingsImplCopyWith(
    _$ObsSettingsImpl value,
    $Res Function(_$ObsSettingsImpl) then,
  ) = __$$ObsSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String host, int port, String password});
}

/// @nodoc
class __$$ObsSettingsImplCopyWithImpl<$Res>
    extends _$ObsSettingsCopyWithImpl<$Res, _$ObsSettingsImpl>
    implements _$$ObsSettingsImplCopyWith<$Res> {
  __$$ObsSettingsImplCopyWithImpl(
    _$ObsSettingsImpl _value,
    $Res Function(_$ObsSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ObsSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? port = null,
    Object? password = null,
  }) {
    return _then(
      _$ObsSettingsImpl(
        host: null == host
            ? _value.host
            : host // ignore: cast_nullable_to_non_nullable
                  as String,
        port: null == port
            ? _value.port
            : port // ignore: cast_nullable_to_non_nullable
                  as int,
        password: null == password
            ? _value.password
            : password // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ObsSettingsImpl implements _ObsSettings {
  const _$ObsSettingsImpl({
    this.host = 'localhost',
    this.port = 4455,
    this.password = '',
  });

  /// OBS WebSocket host. Persisted to `SharedPreferences` key `obs.host`.
  @override
  @JsonKey()
  final String host;

  /// OBS WebSocket port. Persisted to `SharedPreferences` key `obs.port`.
  @override
  @JsonKey()
  final int port;

  /// OBS WebSocket password. Persisted to `flutter_secure_storage` key
  /// `obs.password`. Never logged.
  @override
  @JsonKey()
  final String password;

  @override
  String toString() {
    return 'ObsSettings(host: $host, port: $port, password: $password)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ObsSettingsImpl &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.port, port) || other.port == port) &&
            (identical(other.password, password) ||
                other.password == password));
  }

  @override
  int get hashCode => Object.hash(runtimeType, host, port, password);

  /// Create a copy of ObsSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ObsSettingsImplCopyWith<_$ObsSettingsImpl> get copyWith =>
      __$$ObsSettingsImplCopyWithImpl<_$ObsSettingsImpl>(this, _$identity);
}

abstract class _ObsSettings implements ObsSettings {
  const factory _ObsSettings({
    final String host,
    final int port,
    final String password,
  }) = _$ObsSettingsImpl;

  /// OBS WebSocket host. Persisted to `SharedPreferences` key `obs.host`.
  @override
  String get host;

  /// OBS WebSocket port. Persisted to `SharedPreferences` key `obs.port`.
  @override
  int get port;

  /// OBS WebSocket password. Persisted to `flutter_secure_storage` key
  /// `obs.password`. Never logged.
  @override
  String get password;

  /// Create a copy of ObsSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ObsSettingsImplCopyWith<_$ObsSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
