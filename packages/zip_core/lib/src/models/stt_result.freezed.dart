// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stt_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SttResult {
  /// Recognized speech text.
  String get text => throw _privateConstructorUsedError;

  /// Whether this is a final (committed) result or interim/partial.
  bool get isFinal => throw _privateConstructorUsedError;

  /// Recognition confidence (0.0-1.0).
  /// Engines that don't report confidence should use 1.0.
  double get confidence => throw _privateConstructorUsedError;

  /// When the utterance was recognized (UTC).
  DateTime get timestamp => throw _privateConstructorUsedError;

  /// Optional speaker tag for future diarization.
  String? get speakerTag => throw _privateConstructorUsedError;

  /// Identifies the input source for multi-input disambiguation.
  /// Single-input apps use 'default'.
  String get sourceId => throw _privateConstructorUsedError;

  /// Create a copy of SttResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SttResultCopyWith<SttResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SttResultCopyWith<$Res> {
  factory $SttResultCopyWith(SttResult value, $Res Function(SttResult) then) =
      _$SttResultCopyWithImpl<$Res, SttResult>;
  @useResult
  $Res call({
    String text,
    bool isFinal,
    double confidence,
    DateTime timestamp,
    String? speakerTag,
    String sourceId,
  });
}

/// @nodoc
class _$SttResultCopyWithImpl<$Res, $Val extends SttResult>
    implements $SttResultCopyWith<$Res> {
  _$SttResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SttResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? isFinal = null,
    Object? confidence = null,
    Object? timestamp = null,
    Object? speakerTag = freezed,
    Object? sourceId = null,
  }) {
    return _then(
      _value.copyWith(
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            isFinal: null == isFinal
                ? _value.isFinal
                : isFinal // ignore: cast_nullable_to_non_nullable
                      as bool,
            confidence: null == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                      as double,
            timestamp: null == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            speakerTag: freezed == speakerTag
                ? _value.speakerTag
                : speakerTag // ignore: cast_nullable_to_non_nullable
                      as String?,
            sourceId: null == sourceId
                ? _value.sourceId
                : sourceId // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SttResultImplCopyWith<$Res>
    implements $SttResultCopyWith<$Res> {
  factory _$$SttResultImplCopyWith(
    _$SttResultImpl value,
    $Res Function(_$SttResultImpl) then,
  ) = __$$SttResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String text,
    bool isFinal,
    double confidence,
    DateTime timestamp,
    String? speakerTag,
    String sourceId,
  });
}

/// @nodoc
class __$$SttResultImplCopyWithImpl<$Res>
    extends _$SttResultCopyWithImpl<$Res, _$SttResultImpl>
    implements _$$SttResultImplCopyWith<$Res> {
  __$$SttResultImplCopyWithImpl(
    _$SttResultImpl _value,
    $Res Function(_$SttResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SttResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? isFinal = null,
    Object? confidence = null,
    Object? timestamp = null,
    Object? speakerTag = freezed,
    Object? sourceId = null,
  }) {
    return _then(
      _$SttResultImpl(
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        isFinal: null == isFinal
            ? _value.isFinal
            : isFinal // ignore: cast_nullable_to_non_nullable
                  as bool,
        confidence: null == confidence
            ? _value.confidence
            : confidence // ignore: cast_nullable_to_non_nullable
                  as double,
        timestamp: null == timestamp
            ? _value.timestamp
            : timestamp // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        speakerTag: freezed == speakerTag
            ? _value.speakerTag
            : speakerTag // ignore: cast_nullable_to_non_nullable
                  as String?,
        sourceId: null == sourceId
            ? _value.sourceId
            : sourceId // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$SttResultImpl implements _SttResult {
  const _$SttResultImpl({
    required this.text,
    required this.isFinal,
    required this.confidence,
    required this.timestamp,
    this.speakerTag,
    required this.sourceId,
  });

  /// Recognized speech text.
  @override
  final String text;

  /// Whether this is a final (committed) result or interim/partial.
  @override
  final bool isFinal;

  /// Recognition confidence (0.0-1.0).
  /// Engines that don't report confidence should use 1.0.
  @override
  final double confidence;

  /// When the utterance was recognized (UTC).
  @override
  final DateTime timestamp;

  /// Optional speaker tag for future diarization.
  @override
  final String? speakerTag;

  /// Identifies the input source for multi-input disambiguation.
  /// Single-input apps use 'default'.
  @override
  final String sourceId;

  @override
  String toString() {
    return 'SttResult(text: $text, isFinal: $isFinal, confidence: $confidence, timestamp: $timestamp, speakerTag: $speakerTag, sourceId: $sourceId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SttResultImpl &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.isFinal, isFinal) || other.isFinal == isFinal) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.speakerTag, speakerTag) ||
                other.speakerTag == speakerTag) &&
            (identical(other.sourceId, sourceId) ||
                other.sourceId == sourceId));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    text,
    isFinal,
    confidence,
    timestamp,
    speakerTag,
    sourceId,
  );

  /// Create a copy of SttResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SttResultImplCopyWith<_$SttResultImpl> get copyWith =>
      __$$SttResultImplCopyWithImpl<_$SttResultImpl>(this, _$identity);
}

abstract class _SttResult implements SttResult {
  const factory _SttResult({
    required final String text,
    required final bool isFinal,
    required final double confidence,
    required final DateTime timestamp,
    final String? speakerTag,
    required final String sourceId,
  }) = _$SttResultImpl;

  /// Recognized speech text.
  @override
  String get text;

  /// Whether this is a final (committed) result or interim/partial.
  @override
  bool get isFinal;

  /// Recognition confidence (0.0-1.0).
  /// Engines that don't report confidence should use 1.0.
  @override
  double get confidence;

  /// When the utterance was recognized (UTC).
  @override
  DateTime get timestamp;

  /// Optional speaker tag for future diarization.
  @override
  String? get speakerTag;

  /// Identifies the input source for multi-input disambiguation.
  /// Single-input apps use 'default'.
  @override
  String get sourceId;

  /// Create a copy of SttResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SttResultImplCopyWith<_$SttResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
