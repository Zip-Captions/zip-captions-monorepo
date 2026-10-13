// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'broadcast_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$BroadcastSettings {
  /// The session name shown to viewers; validated by
  /// [validateSessionName] before `goLive()` ever reads it.
  String get sessionName => throw _privateConstructorUsedError;

  /// Whether `goLive()` should start captioning automatically if it is
  /// currently idle (`business-rules.md` Rule 3). Independent-by-default
  /// (Application Design Q3).
  bool get autoStartCaptioning => throw _privateConstructorUsedError;

  /// Create a copy of BroadcastSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BroadcastSettingsCopyWith<BroadcastSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BroadcastSettingsCopyWith<$Res> {
  factory $BroadcastSettingsCopyWith(
    BroadcastSettings value,
    $Res Function(BroadcastSettings) then,
  ) = _$BroadcastSettingsCopyWithImpl<$Res, BroadcastSettings>;
  @useResult
  $Res call({String sessionName, bool autoStartCaptioning});
}

/// @nodoc
class _$BroadcastSettingsCopyWithImpl<$Res, $Val extends BroadcastSettings>
    implements $BroadcastSettingsCopyWith<$Res> {
  _$BroadcastSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BroadcastSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? sessionName = null, Object? autoStartCaptioning = null}) {
    return _then(
      _value.copyWith(
            sessionName: null == sessionName
                ? _value.sessionName
                : sessionName // ignore: cast_nullable_to_non_nullable
                      as String,
            autoStartCaptioning: null == autoStartCaptioning
                ? _value.autoStartCaptioning
                : autoStartCaptioning // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BroadcastSettingsImplCopyWith<$Res>
    implements $BroadcastSettingsCopyWith<$Res> {
  factory _$$BroadcastSettingsImplCopyWith(
    _$BroadcastSettingsImpl value,
    $Res Function(_$BroadcastSettingsImpl) then,
  ) = __$$BroadcastSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String sessionName, bool autoStartCaptioning});
}

/// @nodoc
class __$$BroadcastSettingsImplCopyWithImpl<$Res>
    extends _$BroadcastSettingsCopyWithImpl<$Res, _$BroadcastSettingsImpl>
    implements _$$BroadcastSettingsImplCopyWith<$Res> {
  __$$BroadcastSettingsImplCopyWithImpl(
    _$BroadcastSettingsImpl _value,
    $Res Function(_$BroadcastSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BroadcastSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? sessionName = null, Object? autoStartCaptioning = null}) {
    return _then(
      _$BroadcastSettingsImpl(
        sessionName: null == sessionName
            ? _value.sessionName
            : sessionName // ignore: cast_nullable_to_non_nullable
                  as String,
        autoStartCaptioning: null == autoStartCaptioning
            ? _value.autoStartCaptioning
            : autoStartCaptioning // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$BroadcastSettingsImpl extends _BroadcastSettings {
  const _$BroadcastSettingsImpl({
    this.sessionName = '',
    this.autoStartCaptioning = false,
  }) : super._();

  /// The session name shown to viewers; validated by
  /// [validateSessionName] before `goLive()` ever reads it.
  @override
  @JsonKey()
  final String sessionName;

  /// Whether `goLive()` should start captioning automatically if it is
  /// currently idle (`business-rules.md` Rule 3). Independent-by-default
  /// (Application Design Q3).
  @override
  @JsonKey()
  final bool autoStartCaptioning;

  @override
  String toString() {
    return 'BroadcastSettings(sessionName: $sessionName, autoStartCaptioning: $autoStartCaptioning)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BroadcastSettingsImpl &&
            (identical(other.sessionName, sessionName) ||
                other.sessionName == sessionName) &&
            (identical(other.autoStartCaptioning, autoStartCaptioning) ||
                other.autoStartCaptioning == autoStartCaptioning));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, sessionName, autoStartCaptioning);

  /// Create a copy of BroadcastSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BroadcastSettingsImplCopyWith<_$BroadcastSettingsImpl> get copyWith =>
      __$$BroadcastSettingsImplCopyWithImpl<_$BroadcastSettingsImpl>(
        this,
        _$identity,
      );
}

abstract class _BroadcastSettings extends BroadcastSettings {
  const factory _BroadcastSettings({
    final String sessionName,
    final bool autoStartCaptioning,
  }) = _$BroadcastSettingsImpl;
  const _BroadcastSettings._() : super._();

  /// The session name shown to viewers; validated by
  /// [validateSessionName] before `goLive()` ever reads it.
  @override
  String get sessionName;

  /// Whether `goLive()` should start captioning automatically if it is
  /// currently idle (`business-rules.md` Rule 3). Independent-by-default
  /// (Application Design Q3).
  @override
  bool get autoStartCaptioning;

  /// Create a copy of BroadcastSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BroadcastSettingsImplCopyWith<_$BroadcastSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
