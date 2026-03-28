// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pause_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$PauseEvent {
  /// When the user paused recording.
  DateTime get pausedAt => throw _privateConstructorUsedError;

  /// When the user resumed recording; null if session was stopped while
  /// paused.
  DateTime? get resumedAt => throw _privateConstructorUsedError;

  /// Create a copy of PauseEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PauseEventCopyWith<PauseEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PauseEventCopyWith<$Res> {
  factory $PauseEventCopyWith(
    PauseEvent value,
    $Res Function(PauseEvent) then,
  ) = _$PauseEventCopyWithImpl<$Res, PauseEvent>;
  @useResult
  $Res call({DateTime pausedAt, DateTime? resumedAt});
}

/// @nodoc
class _$PauseEventCopyWithImpl<$Res, $Val extends PauseEvent>
    implements $PauseEventCopyWith<$Res> {
  _$PauseEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PauseEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? pausedAt = null, Object? resumedAt = freezed}) {
    return _then(
      _value.copyWith(
            pausedAt: null == pausedAt
                ? _value.pausedAt
                : pausedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            resumedAt: freezed == resumedAt
                ? _value.resumedAt
                : resumedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PauseEventImplCopyWith<$Res>
    implements $PauseEventCopyWith<$Res> {
  factory _$$PauseEventImplCopyWith(
    _$PauseEventImpl value,
    $Res Function(_$PauseEventImpl) then,
  ) = __$$PauseEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime pausedAt, DateTime? resumedAt});
}

/// @nodoc
class __$$PauseEventImplCopyWithImpl<$Res>
    extends _$PauseEventCopyWithImpl<$Res, _$PauseEventImpl>
    implements _$$PauseEventImplCopyWith<$Res> {
  __$$PauseEventImplCopyWithImpl(
    _$PauseEventImpl _value,
    $Res Function(_$PauseEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PauseEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? pausedAt = null, Object? resumedAt = freezed}) {
    return _then(
      _$PauseEventImpl(
        pausedAt: null == pausedAt
            ? _value.pausedAt
            : pausedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        resumedAt: freezed == resumedAt
            ? _value.resumedAt
            : resumedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$PauseEventImpl implements _PauseEvent {
  const _$PauseEventImpl({required this.pausedAt, this.resumedAt});

  /// When the user paused recording.
  @override
  final DateTime pausedAt;

  /// When the user resumed recording; null if session was stopped while
  /// paused.
  @override
  final DateTime? resumedAt;

  @override
  String toString() {
    return 'PauseEvent(pausedAt: $pausedAt, resumedAt: $resumedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PauseEventImpl &&
            (identical(other.pausedAt, pausedAt) ||
                other.pausedAt == pausedAt) &&
            (identical(other.resumedAt, resumedAt) ||
                other.resumedAt == resumedAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, pausedAt, resumedAt);

  /// Create a copy of PauseEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PauseEventImplCopyWith<_$PauseEventImpl> get copyWith =>
      __$$PauseEventImplCopyWithImpl<_$PauseEventImpl>(this, _$identity);
}

abstract class _PauseEvent implements PauseEvent {
  const factory _PauseEvent({
    required final DateTime pausedAt,
    final DateTime? resumedAt,
  }) = _$PauseEventImpl;

  /// When the user paused recording.
  @override
  DateTime get pausedAt;

  /// When the user resumed recording; null if session was stopped while
  /// paused.
  @override
  DateTime? get resumedAt;

  /// Create a copy of PauseEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PauseEventImplCopyWith<_$PauseEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
