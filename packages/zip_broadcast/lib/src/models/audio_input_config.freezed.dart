// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_input_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AudioInputConfig _$AudioInputConfigFromJson(Map<String, dynamic> json) {
  return _AudioInputConfig.fromJson(json);
}

/// @nodoc
mixin _$AudioInputConfig {
  /// Platform device identifier, used as the STT sourceId.
  String get deviceId => throw _privateConstructorUsedError;

  /// Human-readable device name from the OS.
  String get name => throw _privateConstructorUsedError;

  /// Display label assigned by the user (e.g. "Presenter").
  String get label => throw _privateConstructorUsedError;

  /// Colour index (0–3) selecting from AudioInputVisualStyle.
  int get colorIndex => throw _privateConstructorUsedError;

  /// Serializes this AudioInputConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AudioInputConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AudioInputConfigCopyWith<AudioInputConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioInputConfigCopyWith<$Res> {
  factory $AudioInputConfigCopyWith(
    AudioInputConfig value,
    $Res Function(AudioInputConfig) then,
  ) = _$AudioInputConfigCopyWithImpl<$Res, AudioInputConfig>;
  @useResult
  $Res call({String deviceId, String name, String label, int colorIndex});
}

/// @nodoc
class _$AudioInputConfigCopyWithImpl<$Res, $Val extends AudioInputConfig>
    implements $AudioInputConfigCopyWith<$Res> {
  _$AudioInputConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AudioInputConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviceId = null,
    Object? name = null,
    Object? label = null,
    Object? colorIndex = null,
  }) {
    return _then(
      _value.copyWith(
            deviceId: null == deviceId
                ? _value.deviceId
                : deviceId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
            colorIndex: null == colorIndex
                ? _value.colorIndex
                : colorIndex // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AudioInputConfigImplCopyWith<$Res>
    implements $AudioInputConfigCopyWith<$Res> {
  factory _$$AudioInputConfigImplCopyWith(
    _$AudioInputConfigImpl value,
    $Res Function(_$AudioInputConfigImpl) then,
  ) = __$$AudioInputConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String deviceId, String name, String label, int colorIndex});
}

/// @nodoc
class __$$AudioInputConfigImplCopyWithImpl<$Res>
    extends _$AudioInputConfigCopyWithImpl<$Res, _$AudioInputConfigImpl>
    implements _$$AudioInputConfigImplCopyWith<$Res> {
  __$$AudioInputConfigImplCopyWithImpl(
    _$AudioInputConfigImpl _value,
    $Res Function(_$AudioInputConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AudioInputConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviceId = null,
    Object? name = null,
    Object? label = null,
    Object? colorIndex = null,
  }) {
    return _then(
      _$AudioInputConfigImpl(
        deviceId: null == deviceId
            ? _value.deviceId
            : deviceId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
        colorIndex: null == colorIndex
            ? _value.colorIndex
            : colorIndex // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AudioInputConfigImpl implements _AudioInputConfig {
  const _$AudioInputConfigImpl({
    required this.deviceId,
    required this.name,
    this.label = '',
    this.colorIndex = 0,
  });

  factory _$AudioInputConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$AudioInputConfigImplFromJson(json);

  /// Platform device identifier, used as the STT sourceId.
  @override
  final String deviceId;

  /// Human-readable device name from the OS.
  @override
  final String name;

  /// Display label assigned by the user (e.g. "Presenter").
  @override
  @JsonKey()
  final String label;

  /// Colour index (0–3) selecting from AudioInputVisualStyle.
  @override
  @JsonKey()
  final int colorIndex;

  @override
  String toString() {
    return 'AudioInputConfig(deviceId: $deviceId, name: $name, label: $label, colorIndex: $colorIndex)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioInputConfigImpl &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.colorIndex, colorIndex) ||
                other.colorIndex == colorIndex));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, deviceId, name, label, colorIndex);

  /// Create a copy of AudioInputConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AudioInputConfigImplCopyWith<_$AudioInputConfigImpl> get copyWith =>
      __$$AudioInputConfigImplCopyWithImpl<_$AudioInputConfigImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AudioInputConfigImplToJson(this);
  }
}

abstract class _AudioInputConfig implements AudioInputConfig {
  const factory _AudioInputConfig({
    required final String deviceId,
    required final String name,
    final String label,
    final int colorIndex,
  }) = _$AudioInputConfigImpl;

  factory _AudioInputConfig.fromJson(Map<String, dynamic> json) =
      _$AudioInputConfigImpl.fromJson;

  /// Platform device identifier, used as the STT sourceId.
  @override
  String get deviceId;

  /// Human-readable device name from the OS.
  @override
  String get name;

  /// Display label assigned by the user (e.g. "Presenter").
  @override
  String get label;

  /// Colour index (0–3) selecting from AudioInputVisualStyle.
  @override
  int get colorIndex;

  /// Create a copy of AudioInputConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AudioInputConfigImplCopyWith<_$AudioInputConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
