// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transcript_segment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TranscriptSegment _$TranscriptSegmentFromJson(Map<String, dynamic> json) {
  return _TranscriptSegment.fromJson(json);
}

/// @nodoc
mixin _$TranscriptSegment {
  /// Primary key (UUID).
  String get segmentId => throw _privateConstructorUsedError;

  /// Foreign key → [TranscriptSession.sessionId].
  String get sessionId => throw _privateConstructorUsedError;

  /// Committed speech text (never interim).
  String get text => throw _privateConstructorUsedError;

  /// Input source identifier.
  String get sourceId => throw _privateConstructorUsedError;

  /// Segment start offset from session start in milliseconds.
  int get startTimeMs => throw _privateConstructorUsedError;

  /// Segment end offset from session start in milliseconds.
  int get endTimeMs => throw _privateConstructorUsedError;

  /// Serializes this TranscriptSegment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TranscriptSegment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TranscriptSegmentCopyWith<TranscriptSegment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TranscriptSegmentCopyWith<$Res> {
  factory $TranscriptSegmentCopyWith(
    TranscriptSegment value,
    $Res Function(TranscriptSegment) then,
  ) = _$TranscriptSegmentCopyWithImpl<$Res, TranscriptSegment>;
  @useResult
  $Res call({
    String segmentId,
    String sessionId,
    String text,
    String sourceId,
    int startTimeMs,
    int endTimeMs,
  });
}

/// @nodoc
class _$TranscriptSegmentCopyWithImpl<$Res, $Val extends TranscriptSegment>
    implements $TranscriptSegmentCopyWith<$Res> {
  _$TranscriptSegmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TranscriptSegment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? segmentId = null,
    Object? sessionId = null,
    Object? text = null,
    Object? sourceId = null,
    Object? startTimeMs = null,
    Object? endTimeMs = null,
  }) {
    return _then(
      _value.copyWith(
            segmentId: null == segmentId
                ? _value.segmentId
                : segmentId // ignore: cast_nullable_to_non_nullable
                      as String,
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            sourceId: null == sourceId
                ? _value.sourceId
                : sourceId // ignore: cast_nullable_to_non_nullable
                      as String,
            startTimeMs: null == startTimeMs
                ? _value.startTimeMs
                : startTimeMs // ignore: cast_nullable_to_non_nullable
                      as int,
            endTimeMs: null == endTimeMs
                ? _value.endTimeMs
                : endTimeMs // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TranscriptSegmentImplCopyWith<$Res>
    implements $TranscriptSegmentCopyWith<$Res> {
  factory _$$TranscriptSegmentImplCopyWith(
    _$TranscriptSegmentImpl value,
    $Res Function(_$TranscriptSegmentImpl) then,
  ) = __$$TranscriptSegmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String segmentId,
    String sessionId,
    String text,
    String sourceId,
    int startTimeMs,
    int endTimeMs,
  });
}

/// @nodoc
class __$$TranscriptSegmentImplCopyWithImpl<$Res>
    extends _$TranscriptSegmentCopyWithImpl<$Res, _$TranscriptSegmentImpl>
    implements _$$TranscriptSegmentImplCopyWith<$Res> {
  __$$TranscriptSegmentImplCopyWithImpl(
    _$TranscriptSegmentImpl _value,
    $Res Function(_$TranscriptSegmentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TranscriptSegment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? segmentId = null,
    Object? sessionId = null,
    Object? text = null,
    Object? sourceId = null,
    Object? startTimeMs = null,
    Object? endTimeMs = null,
  }) {
    return _then(
      _$TranscriptSegmentImpl(
        segmentId: null == segmentId
            ? _value.segmentId
            : segmentId // ignore: cast_nullable_to_non_nullable
                  as String,
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceId: null == sourceId
            ? _value.sourceId
            : sourceId // ignore: cast_nullable_to_non_nullable
                  as String,
        startTimeMs: null == startTimeMs
            ? _value.startTimeMs
            : startTimeMs // ignore: cast_nullable_to_non_nullable
                  as int,
        endTimeMs: null == endTimeMs
            ? _value.endTimeMs
            : endTimeMs // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TranscriptSegmentImpl implements _TranscriptSegment {
  const _$TranscriptSegmentImpl({
    required this.segmentId,
    required this.sessionId,
    required this.text,
    required this.sourceId,
    required this.startTimeMs,
    required this.endTimeMs,
  });

  factory _$TranscriptSegmentImpl.fromJson(Map<String, dynamic> json) =>
      _$$TranscriptSegmentImplFromJson(json);

  /// Primary key (UUID).
  @override
  final String segmentId;

  /// Foreign key → [TranscriptSession.sessionId].
  @override
  final String sessionId;

  /// Committed speech text (never interim).
  @override
  final String text;

  /// Input source identifier.
  @override
  final String sourceId;

  /// Segment start offset from session start in milliseconds.
  @override
  final int startTimeMs;

  /// Segment end offset from session start in milliseconds.
  @override
  final int endTimeMs;

  @override
  String toString() {
    return 'TranscriptSegment(segmentId: $segmentId, sessionId: $sessionId, text: $text, sourceId: $sourceId, startTimeMs: $startTimeMs, endTimeMs: $endTimeMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TranscriptSegmentImpl &&
            (identical(other.segmentId, segmentId) ||
                other.segmentId == segmentId) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.sourceId, sourceId) ||
                other.sourceId == sourceId) &&
            (identical(other.startTimeMs, startTimeMs) ||
                other.startTimeMs == startTimeMs) &&
            (identical(other.endTimeMs, endTimeMs) ||
                other.endTimeMs == endTimeMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    segmentId,
    sessionId,
    text,
    sourceId,
    startTimeMs,
    endTimeMs,
  );

  /// Create a copy of TranscriptSegment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TranscriptSegmentImplCopyWith<_$TranscriptSegmentImpl> get copyWith =>
      __$$TranscriptSegmentImplCopyWithImpl<_$TranscriptSegmentImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TranscriptSegmentImplToJson(this);
  }
}

abstract class _TranscriptSegment implements TranscriptSegment {
  const factory _TranscriptSegment({
    required final String segmentId,
    required final String sessionId,
    required final String text,
    required final String sourceId,
    required final int startTimeMs,
    required final int endTimeMs,
  }) = _$TranscriptSegmentImpl;

  factory _TranscriptSegment.fromJson(Map<String, dynamic> json) =
      _$TranscriptSegmentImpl.fromJson;

  /// Primary key (UUID).
  @override
  String get segmentId;

  /// Foreign key → [TranscriptSession.sessionId].
  @override
  String get sessionId;

  /// Committed speech text (never interim).
  @override
  String get text;

  /// Input source identifier.
  @override
  String get sourceId;

  /// Segment start offset from session start in milliseconds.
  @override
  int get startTimeMs;

  /// Segment end offset from session start in milliseconds.
  @override
  int get endTimeMs;

  /// Create a copy of TranscriptSegment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TranscriptSegmentImplCopyWith<_$TranscriptSegmentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
