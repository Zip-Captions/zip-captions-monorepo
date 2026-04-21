// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transcript_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TranscriptSession _$TranscriptSessionFromJson(Map<String, dynamic> json) {
  return _TranscriptSession.fromJson(json);
}

/// @nodoc
mixin _$TranscriptSession {
  /// Primary key (UUID).
  String get sessionId => throw _privateConstructorUsedError;

  /// Session start time (UTC).
  DateTime get date => throw _privateConstructorUsedError;

  /// Session duration in milliseconds.
  int get durationMs => throw _privateConstructorUsedError;

  /// Number of committed final segments.
  int get segmentCount => throw _privateConstructorUsedError;

  /// Auto-derived display title; null until the first final segment arrives.
  String? get title => throw _privateConstructorUsedError;

  /// Serializes this TranscriptSession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TranscriptSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TranscriptSessionCopyWith<TranscriptSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TranscriptSessionCopyWith<$Res> {
  factory $TranscriptSessionCopyWith(
    TranscriptSession value,
    $Res Function(TranscriptSession) then,
  ) = _$TranscriptSessionCopyWithImpl<$Res, TranscriptSession>;
  @useResult
  $Res call({
    String sessionId,
    DateTime date,
    int durationMs,
    int segmentCount,
    String? title,
  });
}

/// @nodoc
class _$TranscriptSessionCopyWithImpl<$Res, $Val extends TranscriptSession>
    implements $TranscriptSessionCopyWith<$Res> {
  _$TranscriptSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TranscriptSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? date = null,
    Object? durationMs = null,
    Object? segmentCount = null,
    Object? title = freezed,
  }) {
    return _then(
      _value.copyWith(
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            durationMs: null == durationMs
                ? _value.durationMs
                : durationMs // ignore: cast_nullable_to_non_nullable
                      as int,
            segmentCount: null == segmentCount
                ? _value.segmentCount
                : segmentCount // ignore: cast_nullable_to_non_nullable
                      as int,
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TranscriptSessionImplCopyWith<$Res>
    implements $TranscriptSessionCopyWith<$Res> {
  factory _$$TranscriptSessionImplCopyWith(
    _$TranscriptSessionImpl value,
    $Res Function(_$TranscriptSessionImpl) then,
  ) = __$$TranscriptSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String sessionId,
    DateTime date,
    int durationMs,
    int segmentCount,
    String? title,
  });
}

/// @nodoc
class __$$TranscriptSessionImplCopyWithImpl<$Res>
    extends _$TranscriptSessionCopyWithImpl<$Res, _$TranscriptSessionImpl>
    implements _$$TranscriptSessionImplCopyWith<$Res> {
  __$$TranscriptSessionImplCopyWithImpl(
    _$TranscriptSessionImpl _value,
    $Res Function(_$TranscriptSessionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TranscriptSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? date = null,
    Object? durationMs = null,
    Object? segmentCount = null,
    Object? title = freezed,
  }) {
    return _then(
      _$TranscriptSessionImpl(
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        durationMs: null == durationMs
            ? _value.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int,
        segmentCount: null == segmentCount
            ? _value.segmentCount
            : segmentCount // ignore: cast_nullable_to_non_nullable
                  as int,
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TranscriptSessionImpl implements _TranscriptSession {
  const _$TranscriptSessionImpl({
    required this.sessionId,
    required this.date,
    required this.durationMs,
    required this.segmentCount,
    this.title,
  });

  factory _$TranscriptSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$TranscriptSessionImplFromJson(json);

  /// Primary key (UUID).
  @override
  final String sessionId;

  /// Session start time (UTC).
  @override
  final DateTime date;

  /// Session duration in milliseconds.
  @override
  final int durationMs;

  /// Number of committed final segments.
  @override
  final int segmentCount;

  /// Auto-derived display title; null until the first final segment arrives.
  @override
  final String? title;

  @override
  String toString() {
    return 'TranscriptSession(sessionId: $sessionId, date: $date, durationMs: $durationMs, segmentCount: $segmentCount, title: $title)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TranscriptSessionImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.segmentCount, segmentCount) ||
                other.segmentCount == segmentCount) &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    sessionId,
    date,
    durationMs,
    segmentCount,
    title,
  );

  /// Create a copy of TranscriptSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TranscriptSessionImplCopyWith<_$TranscriptSessionImpl> get copyWith =>
      __$$TranscriptSessionImplCopyWithImpl<_$TranscriptSessionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TranscriptSessionImplToJson(this);
  }
}

abstract class _TranscriptSession implements TranscriptSession {
  const factory _TranscriptSession({
    required final String sessionId,
    required final DateTime date,
    required final int durationMs,
    required final int segmentCount,
    final String? title,
  }) = _$TranscriptSessionImpl;

  factory _TranscriptSession.fromJson(Map<String, dynamic> json) =
      _$TranscriptSessionImpl.fromJson;

  /// Primary key (UUID).
  @override
  String get sessionId;

  /// Session start time (UTC).
  @override
  DateTime get date;

  /// Session duration in milliseconds.
  @override
  int get durationMs;

  /// Number of committed final segments.
  @override
  int get segmentCount;

  /// Auto-derived display title; null until the first final segment arrives.
  @override
  String? get title;

  /// Create a copy of TranscriptSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TranscriptSessionImplCopyWith<_$TranscriptSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
