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

/// @nodoc
mixin _$AudioInputVisualStyle {
  /// Caption text color for this source (ARGB int).
  int get colorValue => throw _privateConstructorUsedError;

  /// Optional display label shown alongside captions.
  String? get label => throw _privateConstructorUsedError;

  /// Create a copy of AudioInputVisualStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AudioInputVisualStyleCopyWith<AudioInputVisualStyle> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioInputVisualStyleCopyWith<$Res> {
  factory $AudioInputVisualStyleCopyWith(
    AudioInputVisualStyle value,
    $Res Function(AudioInputVisualStyle) then,
  ) = _$AudioInputVisualStyleCopyWithImpl<$Res, AudioInputVisualStyle>;
  @useResult
  $Res call({int colorValue, String? label});
}

/// @nodoc
class _$AudioInputVisualStyleCopyWithImpl<
  $Res,
  $Val extends AudioInputVisualStyle
>
    implements $AudioInputVisualStyleCopyWith<$Res> {
  _$AudioInputVisualStyleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AudioInputVisualStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? colorValue = null, Object? label = freezed}) {
    return _then(
      _value.copyWith(
            colorValue: null == colorValue
                ? _value.colorValue
                : colorValue // ignore: cast_nullable_to_non_nullable
                      as int,
            label: freezed == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AudioInputVisualStyleImplCopyWith<$Res>
    implements $AudioInputVisualStyleCopyWith<$Res> {
  factory _$$AudioInputVisualStyleImplCopyWith(
    _$AudioInputVisualStyleImpl value,
    $Res Function(_$AudioInputVisualStyleImpl) then,
  ) = __$$AudioInputVisualStyleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int colorValue, String? label});
}

/// @nodoc
class __$$AudioInputVisualStyleImplCopyWithImpl<$Res>
    extends
        _$AudioInputVisualStyleCopyWithImpl<$Res, _$AudioInputVisualStyleImpl>
    implements _$$AudioInputVisualStyleImplCopyWith<$Res> {
  __$$AudioInputVisualStyleImplCopyWithImpl(
    _$AudioInputVisualStyleImpl _value,
    $Res Function(_$AudioInputVisualStyleImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AudioInputVisualStyle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? colorValue = null, Object? label = freezed}) {
    return _then(
      _$AudioInputVisualStyleImpl(
        colorValue: null == colorValue
            ? _value.colorValue
            : colorValue // ignore: cast_nullable_to_non_nullable
                  as int,
        label: freezed == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$AudioInputVisualStyleImpl implements _AudioInputVisualStyle {
  const _$AudioInputVisualStyleImpl({required this.colorValue, this.label});

  /// Caption text color for this source (ARGB int).
  @override
  final int colorValue;

  /// Optional display label shown alongside captions.
  @override
  final String? label;

  @override
  String toString() {
    return 'AudioInputVisualStyle(colorValue: $colorValue, label: $label)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioInputVisualStyleImpl &&
            (identical(other.colorValue, colorValue) ||
                other.colorValue == colorValue) &&
            (identical(other.label, label) || other.label == label));
  }

  @override
  int get hashCode => Object.hash(runtimeType, colorValue, label);

  /// Create a copy of AudioInputVisualStyle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AudioInputVisualStyleImplCopyWith<_$AudioInputVisualStyleImpl>
  get copyWith =>
      __$$AudioInputVisualStyleImplCopyWithImpl<_$AudioInputVisualStyleImpl>(
        this,
        _$identity,
      );
}

abstract class _AudioInputVisualStyle implements AudioInputVisualStyle {
  const factory _AudioInputVisualStyle({
    required final int colorValue,
    final String? label,
  }) = _$AudioInputVisualStyleImpl;

  /// Caption text color for this source (ARGB int).
  @override
  int get colorValue;

  /// Optional display label shown alongside captions.
  @override
  String? get label;

  /// Create a copy of AudioInputVisualStyle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AudioInputVisualStyleImplCopyWith<_$AudioInputVisualStyleImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AudioInputConfig {
  /// Unique identifier for this input.
  String get inputId => throw _privateConstructorUsedError;

  /// Platform audio device identifier (null = default mic).
  String? get sourceDeviceId => throw _privateConstructorUsedError;

  /// User-assigned label (e.g., "Teacher", "Student Mic").
  String get speakerLabel => throw _privateConstructorUsedError;

  /// Color/indicator for rendering this source's captions.
  AudioInputVisualStyle get visualStyle => throw _privateConstructorUsedError;

  /// Whether this input is currently capturing.
  bool get isActive => throw _privateConstructorUsedError;

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
  $Res call({
    String inputId,
    String? sourceDeviceId,
    String speakerLabel,
    AudioInputVisualStyle visualStyle,
    bool isActive,
  });

  $AudioInputVisualStyleCopyWith<$Res> get visualStyle;
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
    Object? inputId = null,
    Object? sourceDeviceId = freezed,
    Object? speakerLabel = null,
    Object? visualStyle = null,
    Object? isActive = null,
  }) {
    return _then(
      _value.copyWith(
            inputId: null == inputId
                ? _value.inputId
                : inputId // ignore: cast_nullable_to_non_nullable
                      as String,
            sourceDeviceId: freezed == sourceDeviceId
                ? _value.sourceDeviceId
                : sourceDeviceId // ignore: cast_nullable_to_non_nullable
                      as String?,
            speakerLabel: null == speakerLabel
                ? _value.speakerLabel
                : speakerLabel // ignore: cast_nullable_to_non_nullable
                      as String,
            visualStyle: null == visualStyle
                ? _value.visualStyle
                : visualStyle // ignore: cast_nullable_to_non_nullable
                      as AudioInputVisualStyle,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of AudioInputConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AudioInputVisualStyleCopyWith<$Res> get visualStyle {
    return $AudioInputVisualStyleCopyWith<$Res>(_value.visualStyle, (value) {
      return _then(_value.copyWith(visualStyle: value) as $Val);
    });
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
  $Res call({
    String inputId,
    String? sourceDeviceId,
    String speakerLabel,
    AudioInputVisualStyle visualStyle,
    bool isActive,
  });

  @override
  $AudioInputVisualStyleCopyWith<$Res> get visualStyle;
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
    Object? inputId = null,
    Object? sourceDeviceId = freezed,
    Object? speakerLabel = null,
    Object? visualStyle = null,
    Object? isActive = null,
  }) {
    return _then(
      _$AudioInputConfigImpl(
        inputId: null == inputId
            ? _value.inputId
            : inputId // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceDeviceId: freezed == sourceDeviceId
            ? _value.sourceDeviceId
            : sourceDeviceId // ignore: cast_nullable_to_non_nullable
                  as String?,
        speakerLabel: null == speakerLabel
            ? _value.speakerLabel
            : speakerLabel // ignore: cast_nullable_to_non_nullable
                  as String,
        visualStyle: null == visualStyle
            ? _value.visualStyle
            : visualStyle // ignore: cast_nullable_to_non_nullable
                  as AudioInputVisualStyle,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$AudioInputConfigImpl implements _AudioInputConfig {
  const _$AudioInputConfigImpl({
    required this.inputId,
    this.sourceDeviceId,
    required this.speakerLabel,
    required this.visualStyle,
    this.isActive = true,
  });

  /// Unique identifier for this input.
  @override
  final String inputId;

  /// Platform audio device identifier (null = default mic).
  @override
  final String? sourceDeviceId;

  /// User-assigned label (e.g., "Teacher", "Student Mic").
  @override
  final String speakerLabel;

  /// Color/indicator for rendering this source's captions.
  @override
  final AudioInputVisualStyle visualStyle;

  /// Whether this input is currently capturing.
  @override
  @JsonKey()
  final bool isActive;

  @override
  String toString() {
    return 'AudioInputConfig(inputId: $inputId, sourceDeviceId: $sourceDeviceId, speakerLabel: $speakerLabel, visualStyle: $visualStyle, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioInputConfigImpl &&
            (identical(other.inputId, inputId) || other.inputId == inputId) &&
            (identical(other.sourceDeviceId, sourceDeviceId) ||
                other.sourceDeviceId == sourceDeviceId) &&
            (identical(other.speakerLabel, speakerLabel) ||
                other.speakerLabel == speakerLabel) &&
            (identical(other.visualStyle, visualStyle) ||
                other.visualStyle == visualStyle) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    inputId,
    sourceDeviceId,
    speakerLabel,
    visualStyle,
    isActive,
  );

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
}

abstract class _AudioInputConfig implements AudioInputConfig {
  const factory _AudioInputConfig({
    required final String inputId,
    final String? sourceDeviceId,
    required final String speakerLabel,
    required final AudioInputVisualStyle visualStyle,
    final bool isActive,
  }) = _$AudioInputConfigImpl;

  /// Unique identifier for this input.
  @override
  String get inputId;

  /// Platform audio device identifier (null = default mic).
  @override
  String? get sourceDeviceId;

  /// User-assigned label (e.g., "Teacher", "Student Mic").
  @override
  String get speakerLabel;

  /// Color/indicator for rendering this source's captions.
  @override
  AudioInputVisualStyle get visualStyle;

  /// Whether this input is currently capturing.
  @override
  bool get isActive;

  /// Create a copy of AudioInputConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AudioInputConfigImplCopyWith<_$AudioInputConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
