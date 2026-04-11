// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'repository_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$RepositoryEvent {
  String get corruptFilePath => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String corruptFilePath) corruption,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String corruptFilePath)? corruption,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String corruptFilePath)? corruption,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CorruptionEvent value) corruption,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CorruptionEvent value)? corruption,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CorruptionEvent value)? corruption,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Create a copy of RepositoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RepositoryEventCopyWith<RepositoryEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RepositoryEventCopyWith<$Res> {
  factory $RepositoryEventCopyWith(
    RepositoryEvent value,
    $Res Function(RepositoryEvent) then,
  ) = _$RepositoryEventCopyWithImpl<$Res, RepositoryEvent>;
  @useResult
  $Res call({String corruptFilePath});
}

/// @nodoc
class _$RepositoryEventCopyWithImpl<$Res, $Val extends RepositoryEvent>
    implements $RepositoryEventCopyWith<$Res> {
  _$RepositoryEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RepositoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? corruptFilePath = null}) {
    return _then(
      _value.copyWith(
            corruptFilePath: null == corruptFilePath
                ? _value.corruptFilePath
                : corruptFilePath // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CorruptionEventImplCopyWith<$Res>
    implements $RepositoryEventCopyWith<$Res> {
  factory _$$CorruptionEventImplCopyWith(
    _$CorruptionEventImpl value,
    $Res Function(_$CorruptionEventImpl) then,
  ) = __$$CorruptionEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String corruptFilePath});
}

/// @nodoc
class __$$CorruptionEventImplCopyWithImpl<$Res>
    extends _$RepositoryEventCopyWithImpl<$Res, _$CorruptionEventImpl>
    implements _$$CorruptionEventImplCopyWith<$Res> {
  __$$CorruptionEventImplCopyWithImpl(
    _$CorruptionEventImpl _value,
    $Res Function(_$CorruptionEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RepositoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? corruptFilePath = null}) {
    return _then(
      _$CorruptionEventImpl(
        corruptFilePath: null == corruptFilePath
            ? _value.corruptFilePath
            : corruptFilePath // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$CorruptionEventImpl implements CorruptionEvent {
  const _$CorruptionEventImpl({required this.corruptFilePath});

  @override
  final String corruptFilePath;

  @override
  String toString() {
    return 'RepositoryEvent.corruption(corruptFilePath: $corruptFilePath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CorruptionEventImpl &&
            (identical(other.corruptFilePath, corruptFilePath) ||
                other.corruptFilePath == corruptFilePath));
  }

  @override
  int get hashCode => Object.hash(runtimeType, corruptFilePath);

  /// Create a copy of RepositoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CorruptionEventImplCopyWith<_$CorruptionEventImpl> get copyWith =>
      __$$CorruptionEventImplCopyWithImpl<_$CorruptionEventImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String corruptFilePath) corruption,
  }) {
    return corruption(corruptFilePath);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String corruptFilePath)? corruption,
  }) {
    return corruption?.call(corruptFilePath);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String corruptFilePath)? corruption,
    required TResult orElse(),
  }) {
    if (corruption != null) {
      return corruption(corruptFilePath);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CorruptionEvent value) corruption,
  }) {
    return corruption(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CorruptionEvent value)? corruption,
  }) {
    return corruption?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CorruptionEvent value)? corruption,
    required TResult orElse(),
  }) {
    if (corruption != null) {
      return corruption(this);
    }
    return orElse();
  }
}

abstract class CorruptionEvent implements RepositoryEvent {
  const factory CorruptionEvent({required final String corruptFilePath}) =
      _$CorruptionEventImpl;

  @override
  String get corruptFilePath;

  /// Create a copy of RepositoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CorruptionEventImplCopyWith<_$CorruptionEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
