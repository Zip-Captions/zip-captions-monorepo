// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'broadcaster_session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$BroadcasterSessionState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() offline,
    required TResult Function() starting,
    required TResult Function(LiveBroadcast broadcast) live,
    required TResult Function() ending,
    required TResult Function(BroadcastFailure reason) failed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? offline,
    TResult? Function()? starting,
    TResult? Function(LiveBroadcast broadcast)? live,
    TResult? Function()? ending,
    TResult? Function(BroadcastFailure reason)? failed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? offline,
    TResult Function()? starting,
    TResult Function(LiveBroadcast broadcast)? live,
    TResult Function()? ending,
    TResult Function(BroadcastFailure reason)? failed,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OfflineState value) offline,
    required TResult Function(StartingState value) starting,
    required TResult Function(LiveState value) live,
    required TResult Function(EndingState value) ending,
    required TResult Function(BroadcastFailedState value) failed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OfflineState value)? offline,
    TResult? Function(StartingState value)? starting,
    TResult? Function(LiveState value)? live,
    TResult? Function(EndingState value)? ending,
    TResult? Function(BroadcastFailedState value)? failed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OfflineState value)? offline,
    TResult Function(StartingState value)? starting,
    TResult Function(LiveState value)? live,
    TResult Function(EndingState value)? ending,
    TResult Function(BroadcastFailedState value)? failed,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BroadcasterSessionStateCopyWith<$Res> {
  factory $BroadcasterSessionStateCopyWith(
    BroadcasterSessionState value,
    $Res Function(BroadcasterSessionState) then,
  ) = _$BroadcasterSessionStateCopyWithImpl<$Res, BroadcasterSessionState>;
}

/// @nodoc
class _$BroadcasterSessionStateCopyWithImpl<
  $Res,
  $Val extends BroadcasterSessionState
>
    implements $BroadcasterSessionStateCopyWith<$Res> {
  _$BroadcasterSessionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BroadcasterSessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$OfflineStateImplCopyWith<$Res> {
  factory _$$OfflineStateImplCopyWith(
    _$OfflineStateImpl value,
    $Res Function(_$OfflineStateImpl) then,
  ) = __$$OfflineStateImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$OfflineStateImplCopyWithImpl<$Res>
    extends _$BroadcasterSessionStateCopyWithImpl<$Res, _$OfflineStateImpl>
    implements _$$OfflineStateImplCopyWith<$Res> {
  __$$OfflineStateImplCopyWithImpl(
    _$OfflineStateImpl _value,
    $Res Function(_$OfflineStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BroadcasterSessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$OfflineStateImpl implements OfflineState {
  const _$OfflineStateImpl();

  @override
  String toString() {
    return 'BroadcasterSessionState.offline()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$OfflineStateImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() offline,
    required TResult Function() starting,
    required TResult Function(LiveBroadcast broadcast) live,
    required TResult Function() ending,
    required TResult Function(BroadcastFailure reason) failed,
  }) {
    return offline();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? offline,
    TResult? Function()? starting,
    TResult? Function(LiveBroadcast broadcast)? live,
    TResult? Function()? ending,
    TResult? Function(BroadcastFailure reason)? failed,
  }) {
    return offline?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? offline,
    TResult Function()? starting,
    TResult Function(LiveBroadcast broadcast)? live,
    TResult Function()? ending,
    TResult Function(BroadcastFailure reason)? failed,
    required TResult orElse(),
  }) {
    if (offline != null) {
      return offline();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OfflineState value) offline,
    required TResult Function(StartingState value) starting,
    required TResult Function(LiveState value) live,
    required TResult Function(EndingState value) ending,
    required TResult Function(BroadcastFailedState value) failed,
  }) {
    return offline(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OfflineState value)? offline,
    TResult? Function(StartingState value)? starting,
    TResult? Function(LiveState value)? live,
    TResult? Function(EndingState value)? ending,
    TResult? Function(BroadcastFailedState value)? failed,
  }) {
    return offline?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OfflineState value)? offline,
    TResult Function(StartingState value)? starting,
    TResult Function(LiveState value)? live,
    TResult Function(EndingState value)? ending,
    TResult Function(BroadcastFailedState value)? failed,
    required TResult orElse(),
  }) {
    if (offline != null) {
      return offline(this);
    }
    return orElse();
  }
}

abstract class OfflineState implements BroadcasterSessionState {
  const factory OfflineState() = _$OfflineStateImpl;
}

/// @nodoc
abstract class _$$StartingStateImplCopyWith<$Res> {
  factory _$$StartingStateImplCopyWith(
    _$StartingStateImpl value,
    $Res Function(_$StartingStateImpl) then,
  ) = __$$StartingStateImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$StartingStateImplCopyWithImpl<$Res>
    extends _$BroadcasterSessionStateCopyWithImpl<$Res, _$StartingStateImpl>
    implements _$$StartingStateImplCopyWith<$Res> {
  __$$StartingStateImplCopyWithImpl(
    _$StartingStateImpl _value,
    $Res Function(_$StartingStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BroadcasterSessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$StartingStateImpl implements StartingState {
  const _$StartingStateImpl();

  @override
  String toString() {
    return 'BroadcasterSessionState.starting()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$StartingStateImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() offline,
    required TResult Function() starting,
    required TResult Function(LiveBroadcast broadcast) live,
    required TResult Function() ending,
    required TResult Function(BroadcastFailure reason) failed,
  }) {
    return starting();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? offline,
    TResult? Function()? starting,
    TResult? Function(LiveBroadcast broadcast)? live,
    TResult? Function()? ending,
    TResult? Function(BroadcastFailure reason)? failed,
  }) {
    return starting?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? offline,
    TResult Function()? starting,
    TResult Function(LiveBroadcast broadcast)? live,
    TResult Function()? ending,
    TResult Function(BroadcastFailure reason)? failed,
    required TResult orElse(),
  }) {
    if (starting != null) {
      return starting();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OfflineState value) offline,
    required TResult Function(StartingState value) starting,
    required TResult Function(LiveState value) live,
    required TResult Function(EndingState value) ending,
    required TResult Function(BroadcastFailedState value) failed,
  }) {
    return starting(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OfflineState value)? offline,
    TResult? Function(StartingState value)? starting,
    TResult? Function(LiveState value)? live,
    TResult? Function(EndingState value)? ending,
    TResult? Function(BroadcastFailedState value)? failed,
  }) {
    return starting?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OfflineState value)? offline,
    TResult Function(StartingState value)? starting,
    TResult Function(LiveState value)? live,
    TResult Function(EndingState value)? ending,
    TResult Function(BroadcastFailedState value)? failed,
    required TResult orElse(),
  }) {
    if (starting != null) {
      return starting(this);
    }
    return orElse();
  }
}

abstract class StartingState implements BroadcasterSessionState {
  const factory StartingState() = _$StartingStateImpl;
}

/// @nodoc
abstract class _$$LiveStateImplCopyWith<$Res> {
  factory _$$LiveStateImplCopyWith(
    _$LiveStateImpl value,
    $Res Function(_$LiveStateImpl) then,
  ) = __$$LiveStateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({LiveBroadcast broadcast});

  $LiveBroadcastCopyWith<$Res> get broadcast;
}

/// @nodoc
class __$$LiveStateImplCopyWithImpl<$Res>
    extends _$BroadcasterSessionStateCopyWithImpl<$Res, _$LiveStateImpl>
    implements _$$LiveStateImplCopyWith<$Res> {
  __$$LiveStateImplCopyWithImpl(
    _$LiveStateImpl _value,
    $Res Function(_$LiveStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BroadcasterSessionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? broadcast = null}) {
    return _then(
      _$LiveStateImpl(
        null == broadcast
            ? _value.broadcast
            : broadcast // ignore: cast_nullable_to_non_nullable
                  as LiveBroadcast,
      ),
    );
  }

  /// Create a copy of BroadcasterSessionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LiveBroadcastCopyWith<$Res> get broadcast {
    return $LiveBroadcastCopyWith<$Res>(_value.broadcast, (value) {
      return _then(_value.copyWith(broadcast: value));
    });
  }
}

/// @nodoc

class _$LiveStateImpl implements LiveState {
  const _$LiveStateImpl(this.broadcast);

  @override
  final LiveBroadcast broadcast;

  @override
  String toString() {
    return 'BroadcasterSessionState.live(broadcast: $broadcast)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveStateImpl &&
            (identical(other.broadcast, broadcast) ||
                other.broadcast == broadcast));
  }

  @override
  int get hashCode => Object.hash(runtimeType, broadcast);

  /// Create a copy of BroadcasterSessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveStateImplCopyWith<_$LiveStateImpl> get copyWith =>
      __$$LiveStateImplCopyWithImpl<_$LiveStateImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() offline,
    required TResult Function() starting,
    required TResult Function(LiveBroadcast broadcast) live,
    required TResult Function() ending,
    required TResult Function(BroadcastFailure reason) failed,
  }) {
    return live(broadcast);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? offline,
    TResult? Function()? starting,
    TResult? Function(LiveBroadcast broadcast)? live,
    TResult? Function()? ending,
    TResult? Function(BroadcastFailure reason)? failed,
  }) {
    return live?.call(broadcast);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? offline,
    TResult Function()? starting,
    TResult Function(LiveBroadcast broadcast)? live,
    TResult Function()? ending,
    TResult Function(BroadcastFailure reason)? failed,
    required TResult orElse(),
  }) {
    if (live != null) {
      return live(broadcast);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OfflineState value) offline,
    required TResult Function(StartingState value) starting,
    required TResult Function(LiveState value) live,
    required TResult Function(EndingState value) ending,
    required TResult Function(BroadcastFailedState value) failed,
  }) {
    return live(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OfflineState value)? offline,
    TResult? Function(StartingState value)? starting,
    TResult? Function(LiveState value)? live,
    TResult? Function(EndingState value)? ending,
    TResult? Function(BroadcastFailedState value)? failed,
  }) {
    return live?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OfflineState value)? offline,
    TResult Function(StartingState value)? starting,
    TResult Function(LiveState value)? live,
    TResult Function(EndingState value)? ending,
    TResult Function(BroadcastFailedState value)? failed,
    required TResult orElse(),
  }) {
    if (live != null) {
      return live(this);
    }
    return orElse();
  }
}

abstract class LiveState implements BroadcasterSessionState {
  const factory LiveState(final LiveBroadcast broadcast) = _$LiveStateImpl;

  LiveBroadcast get broadcast;

  /// Create a copy of BroadcasterSessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveStateImplCopyWith<_$LiveStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$EndingStateImplCopyWith<$Res> {
  factory _$$EndingStateImplCopyWith(
    _$EndingStateImpl value,
    $Res Function(_$EndingStateImpl) then,
  ) = __$$EndingStateImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$EndingStateImplCopyWithImpl<$Res>
    extends _$BroadcasterSessionStateCopyWithImpl<$Res, _$EndingStateImpl>
    implements _$$EndingStateImplCopyWith<$Res> {
  __$$EndingStateImplCopyWithImpl(
    _$EndingStateImpl _value,
    $Res Function(_$EndingStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BroadcasterSessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$EndingStateImpl implements EndingState {
  const _$EndingStateImpl();

  @override
  String toString() {
    return 'BroadcasterSessionState.ending()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$EndingStateImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() offline,
    required TResult Function() starting,
    required TResult Function(LiveBroadcast broadcast) live,
    required TResult Function() ending,
    required TResult Function(BroadcastFailure reason) failed,
  }) {
    return ending();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? offline,
    TResult? Function()? starting,
    TResult? Function(LiveBroadcast broadcast)? live,
    TResult? Function()? ending,
    TResult? Function(BroadcastFailure reason)? failed,
  }) {
    return ending?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? offline,
    TResult Function()? starting,
    TResult Function(LiveBroadcast broadcast)? live,
    TResult Function()? ending,
    TResult Function(BroadcastFailure reason)? failed,
    required TResult orElse(),
  }) {
    if (ending != null) {
      return ending();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OfflineState value) offline,
    required TResult Function(StartingState value) starting,
    required TResult Function(LiveState value) live,
    required TResult Function(EndingState value) ending,
    required TResult Function(BroadcastFailedState value) failed,
  }) {
    return ending(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OfflineState value)? offline,
    TResult? Function(StartingState value)? starting,
    TResult? Function(LiveState value)? live,
    TResult? Function(EndingState value)? ending,
    TResult? Function(BroadcastFailedState value)? failed,
  }) {
    return ending?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OfflineState value)? offline,
    TResult Function(StartingState value)? starting,
    TResult Function(LiveState value)? live,
    TResult Function(EndingState value)? ending,
    TResult Function(BroadcastFailedState value)? failed,
    required TResult orElse(),
  }) {
    if (ending != null) {
      return ending(this);
    }
    return orElse();
  }
}

abstract class EndingState implements BroadcasterSessionState {
  const factory EndingState() = _$EndingStateImpl;
}

/// @nodoc
abstract class _$$BroadcastFailedStateImplCopyWith<$Res> {
  factory _$$BroadcastFailedStateImplCopyWith(
    _$BroadcastFailedStateImpl value,
    $Res Function(_$BroadcastFailedStateImpl) then,
  ) = __$$BroadcastFailedStateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({BroadcastFailure reason});
}

/// @nodoc
class __$$BroadcastFailedStateImplCopyWithImpl<$Res>
    extends
        _$BroadcasterSessionStateCopyWithImpl<$Res, _$BroadcastFailedStateImpl>
    implements _$$BroadcastFailedStateImplCopyWith<$Res> {
  __$$BroadcastFailedStateImplCopyWithImpl(
    _$BroadcastFailedStateImpl _value,
    $Res Function(_$BroadcastFailedStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BroadcasterSessionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? reason = null}) {
    return _then(
      _$BroadcastFailedStateImpl(
        null == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as BroadcastFailure,
      ),
    );
  }
}

/// @nodoc

class _$BroadcastFailedStateImpl implements BroadcastFailedState {
  const _$BroadcastFailedStateImpl(this.reason);

  @override
  final BroadcastFailure reason;

  @override
  String toString() {
    return 'BroadcasterSessionState.failed(reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BroadcastFailedStateImpl &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @override
  int get hashCode => Object.hash(runtimeType, reason);

  /// Create a copy of BroadcasterSessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BroadcastFailedStateImplCopyWith<_$BroadcastFailedStateImpl>
  get copyWith =>
      __$$BroadcastFailedStateImplCopyWithImpl<_$BroadcastFailedStateImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() offline,
    required TResult Function() starting,
    required TResult Function(LiveBroadcast broadcast) live,
    required TResult Function() ending,
    required TResult Function(BroadcastFailure reason) failed,
  }) {
    return failed(reason);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? offline,
    TResult? Function()? starting,
    TResult? Function(LiveBroadcast broadcast)? live,
    TResult? Function()? ending,
    TResult? Function(BroadcastFailure reason)? failed,
  }) {
    return failed?.call(reason);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? offline,
    TResult Function()? starting,
    TResult Function(LiveBroadcast broadcast)? live,
    TResult Function()? ending,
    TResult Function(BroadcastFailure reason)? failed,
    required TResult orElse(),
  }) {
    if (failed != null) {
      return failed(reason);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OfflineState value) offline,
    required TResult Function(StartingState value) starting,
    required TResult Function(LiveState value) live,
    required TResult Function(EndingState value) ending,
    required TResult Function(BroadcastFailedState value) failed,
  }) {
    return failed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OfflineState value)? offline,
    TResult? Function(StartingState value)? starting,
    TResult? Function(LiveState value)? live,
    TResult? Function(EndingState value)? ending,
    TResult? Function(BroadcastFailedState value)? failed,
  }) {
    return failed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OfflineState value)? offline,
    TResult Function(StartingState value)? starting,
    TResult Function(LiveState value)? live,
    TResult Function(EndingState value)? ending,
    TResult Function(BroadcastFailedState value)? failed,
    required TResult orElse(),
  }) {
    if (failed != null) {
      return failed(this);
    }
    return orElse();
  }
}

abstract class BroadcastFailedState implements BroadcasterSessionState {
  const factory BroadcastFailedState(final BroadcastFailure reason) =
      _$BroadcastFailedStateImpl;

  BroadcastFailure get reason;

  /// Create a copy of BroadcasterSessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BroadcastFailedStateImplCopyWith<_$BroadcastFailedStateImpl>
  get copyWith => throw _privateConstructorUsedError;
}
