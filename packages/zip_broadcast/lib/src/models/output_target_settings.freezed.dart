// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'output_target_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$OutputTargetSettings {
  /// Whether on-screen caption rendering is active.
  bool get onScreenEnabled => throw _privateConstructorUsedError;

  /// Whether OBS WebSocket output is active.
  bool get obsEnabled => throw _privateConstructorUsedError;

  /// Whether the browser source server is active.
  bool get browserSourceEnabled => throw _privateConstructorUsedError;

  /// Whether the caption overlay window is active.
  bool get overlayEnabled => throw _privateConstructorUsedError;

  /// HTTP port for the browser source server. Valid range: 1024–65535.
  int get browserSourcePort => throw _privateConstructorUsedError;

  /// Create a copy of OutputTargetSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OutputTargetSettingsCopyWith<OutputTargetSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OutputTargetSettingsCopyWith<$Res> {
  factory $OutputTargetSettingsCopyWith(
    OutputTargetSettings value,
    $Res Function(OutputTargetSettings) then,
  ) = _$OutputTargetSettingsCopyWithImpl<$Res, OutputTargetSettings>;
  @useResult
  $Res call({
    bool onScreenEnabled,
    bool obsEnabled,
    bool browserSourceEnabled,
    bool overlayEnabled,
    int browserSourcePort,
  });
}

/// @nodoc
class _$OutputTargetSettingsCopyWithImpl<
  $Res,
  $Val extends OutputTargetSettings
>
    implements $OutputTargetSettingsCopyWith<$Res> {
  _$OutputTargetSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OutputTargetSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? onScreenEnabled = null,
    Object? obsEnabled = null,
    Object? browserSourceEnabled = null,
    Object? overlayEnabled = null,
    Object? browserSourcePort = null,
  }) {
    return _then(
      _value.copyWith(
            onScreenEnabled: null == onScreenEnabled
                ? _value.onScreenEnabled
                : onScreenEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            obsEnabled: null == obsEnabled
                ? _value.obsEnabled
                : obsEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            browserSourceEnabled: null == browserSourceEnabled
                ? _value.browserSourceEnabled
                : browserSourceEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            overlayEnabled: null == overlayEnabled
                ? _value.overlayEnabled
                : overlayEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            browserSourcePort: null == browserSourcePort
                ? _value.browserSourcePort
                : browserSourcePort // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OutputTargetSettingsImplCopyWith<$Res>
    implements $OutputTargetSettingsCopyWith<$Res> {
  factory _$$OutputTargetSettingsImplCopyWith(
    _$OutputTargetSettingsImpl value,
    $Res Function(_$OutputTargetSettingsImpl) then,
  ) = __$$OutputTargetSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool onScreenEnabled,
    bool obsEnabled,
    bool browserSourceEnabled,
    bool overlayEnabled,
    int browserSourcePort,
  });
}

/// @nodoc
class __$$OutputTargetSettingsImplCopyWithImpl<$Res>
    extends _$OutputTargetSettingsCopyWithImpl<$Res, _$OutputTargetSettingsImpl>
    implements _$$OutputTargetSettingsImplCopyWith<$Res> {
  __$$OutputTargetSettingsImplCopyWithImpl(
    _$OutputTargetSettingsImpl _value,
    $Res Function(_$OutputTargetSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OutputTargetSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? onScreenEnabled = null,
    Object? obsEnabled = null,
    Object? browserSourceEnabled = null,
    Object? overlayEnabled = null,
    Object? browserSourcePort = null,
  }) {
    return _then(
      _$OutputTargetSettingsImpl(
        onScreenEnabled: null == onScreenEnabled
            ? _value.onScreenEnabled
            : onScreenEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        obsEnabled: null == obsEnabled
            ? _value.obsEnabled
            : obsEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        browserSourceEnabled: null == browserSourceEnabled
            ? _value.browserSourceEnabled
            : browserSourceEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        overlayEnabled: null == overlayEnabled
            ? _value.overlayEnabled
            : overlayEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        browserSourcePort: null == browserSourcePort
            ? _value.browserSourcePort
            : browserSourcePort // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$OutputTargetSettingsImpl implements _OutputTargetSettings {
  const _$OutputTargetSettingsImpl({
    this.onScreenEnabled = true,
    this.obsEnabled = false,
    this.browserSourceEnabled = false,
    this.overlayEnabled = false,
    this.browserSourcePort = 8080,
  });

  /// Whether on-screen caption rendering is active.
  @override
  @JsonKey()
  final bool onScreenEnabled;

  /// Whether OBS WebSocket output is active.
  @override
  @JsonKey()
  final bool obsEnabled;

  /// Whether the browser source server is active.
  @override
  @JsonKey()
  final bool browserSourceEnabled;

  /// Whether the caption overlay window is active.
  @override
  @JsonKey()
  final bool overlayEnabled;

  /// HTTP port for the browser source server. Valid range: 1024–65535.
  @override
  @JsonKey()
  final int browserSourcePort;

  @override
  String toString() {
    return 'OutputTargetSettings(onScreenEnabled: $onScreenEnabled, obsEnabled: $obsEnabled, browserSourceEnabled: $browserSourceEnabled, overlayEnabled: $overlayEnabled, browserSourcePort: $browserSourcePort)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OutputTargetSettingsImpl &&
            (identical(other.onScreenEnabled, onScreenEnabled) ||
                other.onScreenEnabled == onScreenEnabled) &&
            (identical(other.obsEnabled, obsEnabled) ||
                other.obsEnabled == obsEnabled) &&
            (identical(other.browserSourceEnabled, browserSourceEnabled) ||
                other.browserSourceEnabled == browserSourceEnabled) &&
            (identical(other.overlayEnabled, overlayEnabled) ||
                other.overlayEnabled == overlayEnabled) &&
            (identical(other.browserSourcePort, browserSourcePort) ||
                other.browserSourcePort == browserSourcePort));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    onScreenEnabled,
    obsEnabled,
    browserSourceEnabled,
    overlayEnabled,
    browserSourcePort,
  );

  /// Create a copy of OutputTargetSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OutputTargetSettingsImplCopyWith<_$OutputTargetSettingsImpl>
  get copyWith =>
      __$$OutputTargetSettingsImplCopyWithImpl<_$OutputTargetSettingsImpl>(
        this,
        _$identity,
      );
}

abstract class _OutputTargetSettings implements OutputTargetSettings {
  const factory _OutputTargetSettings({
    final bool onScreenEnabled,
    final bool obsEnabled,
    final bool browserSourceEnabled,
    final bool overlayEnabled,
    final int browserSourcePort,
  }) = _$OutputTargetSettingsImpl;

  /// Whether on-screen caption rendering is active.
  @override
  bool get onScreenEnabled;

  /// Whether OBS WebSocket output is active.
  @override
  bool get obsEnabled;

  /// Whether the browser source server is active.
  @override
  bool get browserSourceEnabled;

  /// Whether the caption overlay window is active.
  @override
  bool get overlayEnabled;

  /// HTTP port for the browser source server. Valid range: 1024–65535.
  @override
  int get browserSourcePort;

  /// Create a copy of OutputTargetSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OutputTargetSettingsImplCopyWith<_$OutputTargetSettingsImpl>
  get copyWith => throw _privateConstructorUsedError;
}
