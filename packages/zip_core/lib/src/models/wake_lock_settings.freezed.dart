// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wake_lock_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WakeLockSettings _$WakeLockSettingsFromJson(Map<String, dynamic> json) {
  return _WakeLockSettings.fromJson(json);
}

/// @nodoc
mixin _$WakeLockSettings {
  /// Whether the screen should stay on during captioning.
  bool get enabled => throw _privateConstructorUsedError;

  /// Whether to release the wake lock when the session is paused.
  bool get releaseOnPause => throw _privateConstructorUsedError;

  /// Serializes this WakeLockSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WakeLockSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WakeLockSettingsCopyWith<WakeLockSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WakeLockSettingsCopyWith<$Res> {
  factory $WakeLockSettingsCopyWith(
    WakeLockSettings value,
    $Res Function(WakeLockSettings) then,
  ) = _$WakeLockSettingsCopyWithImpl<$Res, WakeLockSettings>;
  @useResult
  $Res call({bool enabled, bool releaseOnPause});
}

/// @nodoc
class _$WakeLockSettingsCopyWithImpl<$Res, $Val extends WakeLockSettings>
    implements $WakeLockSettingsCopyWith<$Res> {
  _$WakeLockSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WakeLockSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? enabled = null, Object? releaseOnPause = null}) {
    return _then(
      _value.copyWith(
            enabled: null == enabled
                ? _value.enabled
                : enabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            releaseOnPause: null == releaseOnPause
                ? _value.releaseOnPause
                : releaseOnPause // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WakeLockSettingsImplCopyWith<$Res>
    implements $WakeLockSettingsCopyWith<$Res> {
  factory _$$WakeLockSettingsImplCopyWith(
    _$WakeLockSettingsImpl value,
    $Res Function(_$WakeLockSettingsImpl) then,
  ) = __$$WakeLockSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool enabled, bool releaseOnPause});
}

/// @nodoc
class __$$WakeLockSettingsImplCopyWithImpl<$Res>
    extends _$WakeLockSettingsCopyWithImpl<$Res, _$WakeLockSettingsImpl>
    implements _$$WakeLockSettingsImplCopyWith<$Res> {
  __$$WakeLockSettingsImplCopyWithImpl(
    _$WakeLockSettingsImpl _value,
    $Res Function(_$WakeLockSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WakeLockSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? enabled = null, Object? releaseOnPause = null}) {
    return _then(
      _$WakeLockSettingsImpl(
        enabled: null == enabled
            ? _value.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        releaseOnPause: null == releaseOnPause
            ? _value.releaseOnPause
            : releaseOnPause // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WakeLockSettingsImpl implements _WakeLockSettings {
  const _$WakeLockSettingsImpl({
    this.enabled = true,
    this.releaseOnPause = true,
  });

  factory _$WakeLockSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$WakeLockSettingsImplFromJson(json);

  /// Whether the screen should stay on during captioning.
  @override
  @JsonKey()
  final bool enabled;

  /// Whether to release the wake lock when the session is paused.
  @override
  @JsonKey()
  final bool releaseOnPause;

  @override
  String toString() {
    return 'WakeLockSettings(enabled: $enabled, releaseOnPause: $releaseOnPause)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WakeLockSettingsImpl &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.releaseOnPause, releaseOnPause) ||
                other.releaseOnPause == releaseOnPause));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, enabled, releaseOnPause);

  /// Create a copy of WakeLockSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WakeLockSettingsImplCopyWith<_$WakeLockSettingsImpl> get copyWith =>
      __$$WakeLockSettingsImplCopyWithImpl<_$WakeLockSettingsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WakeLockSettingsImplToJson(this);
  }
}

abstract class _WakeLockSettings implements WakeLockSettings {
  const factory _WakeLockSettings({
    final bool enabled,
    final bool releaseOnPause,
  }) = _$WakeLockSettingsImpl;

  factory _WakeLockSettings.fromJson(Map<String, dynamic> json) =
      _$WakeLockSettingsImpl.fromJson;

  /// Whether the screen should stay on during captioning.
  @override
  bool get enabled;

  /// Whether to release the wake lock when the session is paused.
  @override
  bool get releaseOnPause;

  /// Create a copy of WakeLockSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WakeLockSettingsImplCopyWith<_$WakeLockSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
