// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recording_error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$RecordingError {
  /// Human-readable error description (never contains transcript text).
  String get message => throw _privateConstructorUsedError;

  /// Whether this error halts recording or is transient.
  RecordingErrorSeverity get severity => throw _privateConstructorUsedError;

  /// When the error occurred.
  DateTime get timestamp => throw _privateConstructorUsedError;

  /// Create a copy of RecordingError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecordingErrorCopyWith<RecordingError> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecordingErrorCopyWith<$Res> {
  factory $RecordingErrorCopyWith(
    RecordingError value,
    $Res Function(RecordingError) then,
  ) = _$RecordingErrorCopyWithImpl<$Res, RecordingError>;
  @useResult
  $Res call({
    String message,
    RecordingErrorSeverity severity,
    DateTime timestamp,
  });
}

/// @nodoc
class _$RecordingErrorCopyWithImpl<$Res, $Val extends RecordingError>
    implements $RecordingErrorCopyWith<$Res> {
  _$RecordingErrorCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecordingError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? severity = null,
    Object? timestamp = null,
  }) {
    return _then(
      _value.copyWith(
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            severity: null == severity
                ? _value.severity
                : severity // ignore: cast_nullable_to_non_nullable
                      as RecordingErrorSeverity,
            timestamp: null == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecordingErrorImplCopyWith<$Res>
    implements $RecordingErrorCopyWith<$Res> {
  factory _$$RecordingErrorImplCopyWith(
    _$RecordingErrorImpl value,
    $Res Function(_$RecordingErrorImpl) then,
  ) = __$$RecordingErrorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String message,
    RecordingErrorSeverity severity,
    DateTime timestamp,
  });
}

/// @nodoc
class __$$RecordingErrorImplCopyWithImpl<$Res>
    extends _$RecordingErrorCopyWithImpl<$Res, _$RecordingErrorImpl>
    implements _$$RecordingErrorImplCopyWith<$Res> {
  __$$RecordingErrorImplCopyWithImpl(
    _$RecordingErrorImpl _value,
    $Res Function(_$RecordingErrorImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecordingError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? severity = null,
    Object? timestamp = null,
  }) {
    return _then(
      _$RecordingErrorImpl(
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        severity: null == severity
            ? _value.severity
            : severity // ignore: cast_nullable_to_non_nullable
                  as RecordingErrorSeverity,
        timestamp: null == timestamp
            ? _value.timestamp
            : timestamp // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$RecordingErrorImpl implements _RecordingError {
  const _$RecordingErrorImpl({
    required this.message,
    required this.severity,
    required this.timestamp,
  });

  /// Human-readable error description (never contains transcript text).
  @override
  final String message;

  /// Whether this error halts recording or is transient.
  @override
  final RecordingErrorSeverity severity;

  /// When the error occurred.
  @override
  final DateTime timestamp;

  @override
  String toString() {
    return 'RecordingError(message: $message, severity: $severity, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecordingErrorImpl &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.severity, severity) ||
                other.severity == severity) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message, severity, timestamp);

  /// Create a copy of RecordingError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecordingErrorImplCopyWith<_$RecordingErrorImpl> get copyWith =>
      __$$RecordingErrorImplCopyWithImpl<_$RecordingErrorImpl>(
        this,
        _$identity,
      );
}

abstract class _RecordingError implements RecordingError {
  const factory _RecordingError({
    required final String message,
    required final RecordingErrorSeverity severity,
    required final DateTime timestamp,
  }) = _$RecordingErrorImpl;

  /// Human-readable error description (never contains transcript text).
  @override
  String get message;

  /// Whether this error halts recording or is transient.
  @override
  RecordingErrorSeverity get severity;

  /// When the error occurred.
  @override
  DateTime get timestamp;

  /// Create a copy of RecordingError
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecordingErrorImplCopyWith<_$RecordingErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
