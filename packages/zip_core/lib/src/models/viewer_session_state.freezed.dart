// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'viewer_session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ViewerSessionState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() resolving,
    required TResult Function() connecting,
    required TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )
    liveView,
    required TResult Function() reconnecting,
    required TResult Function() notBroadcasting,
    required TResult Function() ended,
    required TResult Function() full,
    required TResult Function(ConnectFailure reason) cannotConnect,
    required TResult Function() invalidInput,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? resolving,
    TResult? Function()? connecting,
    TResult? Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult? Function()? reconnecting,
    TResult? Function()? notBroadcasting,
    TResult? Function()? ended,
    TResult? Function()? full,
    TResult? Function(ConnectFailure reason)? cannotConnect,
    TResult? Function()? invalidInput,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? resolving,
    TResult Function()? connecting,
    TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult Function()? reconnecting,
    TResult Function()? notBroadcasting,
    TResult Function()? ended,
    TResult Function()? full,
    TResult Function(ConnectFailure reason)? cannotConnect,
    TResult Function()? invalidInput,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ViewerIdleState value) idle,
    required TResult Function(ResolvingState value) resolving,
    required TResult Function(ConnectingState value) connecting,
    required TResult Function(LiveViewState value) liveView,
    required TResult Function(ViewerReconnectingState value) reconnecting,
    required TResult Function(NotBroadcastingState value) notBroadcasting,
    required TResult Function(EndedState value) ended,
    required TResult Function(FullState value) full,
    required TResult Function(CannotConnectState value) cannotConnect,
    required TResult Function(InvalidInputState value) invalidInput,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ViewerIdleState value)? idle,
    TResult? Function(ResolvingState value)? resolving,
    TResult? Function(ConnectingState value)? connecting,
    TResult? Function(LiveViewState value)? liveView,
    TResult? Function(ViewerReconnectingState value)? reconnecting,
    TResult? Function(NotBroadcastingState value)? notBroadcasting,
    TResult? Function(EndedState value)? ended,
    TResult? Function(FullState value)? full,
    TResult? Function(CannotConnectState value)? cannotConnect,
    TResult? Function(InvalidInputState value)? invalidInput,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ViewerIdleState value)? idle,
    TResult Function(ResolvingState value)? resolving,
    TResult Function(ConnectingState value)? connecting,
    TResult Function(LiveViewState value)? liveView,
    TResult Function(ViewerReconnectingState value)? reconnecting,
    TResult Function(NotBroadcastingState value)? notBroadcasting,
    TResult Function(EndedState value)? ended,
    TResult Function(FullState value)? full,
    TResult Function(CannotConnectState value)? cannotConnect,
    TResult Function(InvalidInputState value)? invalidInput,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ViewerSessionStateCopyWith<$Res> {
  factory $ViewerSessionStateCopyWith(
    ViewerSessionState value,
    $Res Function(ViewerSessionState) then,
  ) = _$ViewerSessionStateCopyWithImpl<$Res, ViewerSessionState>;
}

/// @nodoc
class _$ViewerSessionStateCopyWithImpl<$Res, $Val extends ViewerSessionState>
    implements $ViewerSessionStateCopyWith<$Res> {
  _$ViewerSessionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$ViewerIdleStateImplCopyWith<$Res> {
  factory _$$ViewerIdleStateImplCopyWith(
    _$ViewerIdleStateImpl value,
    $Res Function(_$ViewerIdleStateImpl) then,
  ) = __$$ViewerIdleStateImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ViewerIdleStateImplCopyWithImpl<$Res>
    extends _$ViewerSessionStateCopyWithImpl<$Res, _$ViewerIdleStateImpl>
    implements _$$ViewerIdleStateImplCopyWith<$Res> {
  __$$ViewerIdleStateImplCopyWithImpl(
    _$ViewerIdleStateImpl _value,
    $Res Function(_$ViewerIdleStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ViewerIdleStateImpl implements ViewerIdleState {
  const _$ViewerIdleStateImpl();

  @override
  String toString() {
    return 'ViewerSessionState.idle()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$ViewerIdleStateImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() resolving,
    required TResult Function() connecting,
    required TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )
    liveView,
    required TResult Function() reconnecting,
    required TResult Function() notBroadcasting,
    required TResult Function() ended,
    required TResult Function() full,
    required TResult Function(ConnectFailure reason) cannotConnect,
    required TResult Function() invalidInput,
  }) {
    return idle();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? resolving,
    TResult? Function()? connecting,
    TResult? Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult? Function()? reconnecting,
    TResult? Function()? notBroadcasting,
    TResult? Function()? ended,
    TResult? Function()? full,
    TResult? Function(ConnectFailure reason)? cannotConnect,
    TResult? Function()? invalidInput,
  }) {
    return idle?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? resolving,
    TResult Function()? connecting,
    TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult Function()? reconnecting,
    TResult Function()? notBroadcasting,
    TResult Function()? ended,
    TResult Function()? full,
    TResult Function(ConnectFailure reason)? cannotConnect,
    TResult Function()? invalidInput,
    required TResult orElse(),
  }) {
    if (idle != null) {
      return idle();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ViewerIdleState value) idle,
    required TResult Function(ResolvingState value) resolving,
    required TResult Function(ConnectingState value) connecting,
    required TResult Function(LiveViewState value) liveView,
    required TResult Function(ViewerReconnectingState value) reconnecting,
    required TResult Function(NotBroadcastingState value) notBroadcasting,
    required TResult Function(EndedState value) ended,
    required TResult Function(FullState value) full,
    required TResult Function(CannotConnectState value) cannotConnect,
    required TResult Function(InvalidInputState value) invalidInput,
  }) {
    return idle(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ViewerIdleState value)? idle,
    TResult? Function(ResolvingState value)? resolving,
    TResult? Function(ConnectingState value)? connecting,
    TResult? Function(LiveViewState value)? liveView,
    TResult? Function(ViewerReconnectingState value)? reconnecting,
    TResult? Function(NotBroadcastingState value)? notBroadcasting,
    TResult? Function(EndedState value)? ended,
    TResult? Function(FullState value)? full,
    TResult? Function(CannotConnectState value)? cannotConnect,
    TResult? Function(InvalidInputState value)? invalidInput,
  }) {
    return idle?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ViewerIdleState value)? idle,
    TResult Function(ResolvingState value)? resolving,
    TResult Function(ConnectingState value)? connecting,
    TResult Function(LiveViewState value)? liveView,
    TResult Function(ViewerReconnectingState value)? reconnecting,
    TResult Function(NotBroadcastingState value)? notBroadcasting,
    TResult Function(EndedState value)? ended,
    TResult Function(FullState value)? full,
    TResult Function(CannotConnectState value)? cannotConnect,
    TResult Function(InvalidInputState value)? invalidInput,
    required TResult orElse(),
  }) {
    if (idle != null) {
      return idle(this);
    }
    return orElse();
  }
}

abstract class ViewerIdleState implements ViewerSessionState {
  const factory ViewerIdleState() = _$ViewerIdleStateImpl;
}

/// @nodoc
abstract class _$$ResolvingStateImplCopyWith<$Res> {
  factory _$$ResolvingStateImplCopyWith(
    _$ResolvingStateImpl value,
    $Res Function(_$ResolvingStateImpl) then,
  ) = __$$ResolvingStateImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ResolvingStateImplCopyWithImpl<$Res>
    extends _$ViewerSessionStateCopyWithImpl<$Res, _$ResolvingStateImpl>
    implements _$$ResolvingStateImplCopyWith<$Res> {
  __$$ResolvingStateImplCopyWithImpl(
    _$ResolvingStateImpl _value,
    $Res Function(_$ResolvingStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ResolvingStateImpl implements ResolvingState {
  const _$ResolvingStateImpl();

  @override
  String toString() {
    return 'ViewerSessionState.resolving()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$ResolvingStateImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() resolving,
    required TResult Function() connecting,
    required TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )
    liveView,
    required TResult Function() reconnecting,
    required TResult Function() notBroadcasting,
    required TResult Function() ended,
    required TResult Function() full,
    required TResult Function(ConnectFailure reason) cannotConnect,
    required TResult Function() invalidInput,
  }) {
    return resolving();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? resolving,
    TResult? Function()? connecting,
    TResult? Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult? Function()? reconnecting,
    TResult? Function()? notBroadcasting,
    TResult? Function()? ended,
    TResult? Function()? full,
    TResult? Function(ConnectFailure reason)? cannotConnect,
    TResult? Function()? invalidInput,
  }) {
    return resolving?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? resolving,
    TResult Function()? connecting,
    TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult Function()? reconnecting,
    TResult Function()? notBroadcasting,
    TResult Function()? ended,
    TResult Function()? full,
    TResult Function(ConnectFailure reason)? cannotConnect,
    TResult Function()? invalidInput,
    required TResult orElse(),
  }) {
    if (resolving != null) {
      return resolving();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ViewerIdleState value) idle,
    required TResult Function(ResolvingState value) resolving,
    required TResult Function(ConnectingState value) connecting,
    required TResult Function(LiveViewState value) liveView,
    required TResult Function(ViewerReconnectingState value) reconnecting,
    required TResult Function(NotBroadcastingState value) notBroadcasting,
    required TResult Function(EndedState value) ended,
    required TResult Function(FullState value) full,
    required TResult Function(CannotConnectState value) cannotConnect,
    required TResult Function(InvalidInputState value) invalidInput,
  }) {
    return resolving(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ViewerIdleState value)? idle,
    TResult? Function(ResolvingState value)? resolving,
    TResult? Function(ConnectingState value)? connecting,
    TResult? Function(LiveViewState value)? liveView,
    TResult? Function(ViewerReconnectingState value)? reconnecting,
    TResult? Function(NotBroadcastingState value)? notBroadcasting,
    TResult? Function(EndedState value)? ended,
    TResult? Function(FullState value)? full,
    TResult? Function(CannotConnectState value)? cannotConnect,
    TResult? Function(InvalidInputState value)? invalidInput,
  }) {
    return resolving?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ViewerIdleState value)? idle,
    TResult Function(ResolvingState value)? resolving,
    TResult Function(ConnectingState value)? connecting,
    TResult Function(LiveViewState value)? liveView,
    TResult Function(ViewerReconnectingState value)? reconnecting,
    TResult Function(NotBroadcastingState value)? notBroadcasting,
    TResult Function(EndedState value)? ended,
    TResult Function(FullState value)? full,
    TResult Function(CannotConnectState value)? cannotConnect,
    TResult Function(InvalidInputState value)? invalidInput,
    required TResult orElse(),
  }) {
    if (resolving != null) {
      return resolving(this);
    }
    return orElse();
  }
}

abstract class ResolvingState implements ViewerSessionState {
  const factory ResolvingState() = _$ResolvingStateImpl;
}

/// @nodoc
abstract class _$$ConnectingStateImplCopyWith<$Res> {
  factory _$$ConnectingStateImplCopyWith(
    _$ConnectingStateImpl value,
    $Res Function(_$ConnectingStateImpl) then,
  ) = __$$ConnectingStateImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ConnectingStateImplCopyWithImpl<$Res>
    extends _$ViewerSessionStateCopyWithImpl<$Res, _$ConnectingStateImpl>
    implements _$$ConnectingStateImplCopyWith<$Res> {
  __$$ConnectingStateImplCopyWithImpl(
    _$ConnectingStateImpl _value,
    $Res Function(_$ConnectingStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ConnectingStateImpl implements ConnectingState {
  const _$ConnectingStateImpl();

  @override
  String toString() {
    return 'ViewerSessionState.connecting()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$ConnectingStateImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() resolving,
    required TResult Function() connecting,
    required TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )
    liveView,
    required TResult Function() reconnecting,
    required TResult Function() notBroadcasting,
    required TResult Function() ended,
    required TResult Function() full,
    required TResult Function(ConnectFailure reason) cannotConnect,
    required TResult Function() invalidInput,
  }) {
    return connecting();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? resolving,
    TResult? Function()? connecting,
    TResult? Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult? Function()? reconnecting,
    TResult? Function()? notBroadcasting,
    TResult? Function()? ended,
    TResult? Function()? full,
    TResult? Function(ConnectFailure reason)? cannotConnect,
    TResult? Function()? invalidInput,
  }) {
    return connecting?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? resolving,
    TResult Function()? connecting,
    TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult Function()? reconnecting,
    TResult Function()? notBroadcasting,
    TResult Function()? ended,
    TResult Function()? full,
    TResult Function(ConnectFailure reason)? cannotConnect,
    TResult Function()? invalidInput,
    required TResult orElse(),
  }) {
    if (connecting != null) {
      return connecting();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ViewerIdleState value) idle,
    required TResult Function(ResolvingState value) resolving,
    required TResult Function(ConnectingState value) connecting,
    required TResult Function(LiveViewState value) liveView,
    required TResult Function(ViewerReconnectingState value) reconnecting,
    required TResult Function(NotBroadcastingState value) notBroadcasting,
    required TResult Function(EndedState value) ended,
    required TResult Function(FullState value) full,
    required TResult Function(CannotConnectState value) cannotConnect,
    required TResult Function(InvalidInputState value) invalidInput,
  }) {
    return connecting(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ViewerIdleState value)? idle,
    TResult? Function(ResolvingState value)? resolving,
    TResult? Function(ConnectingState value)? connecting,
    TResult? Function(LiveViewState value)? liveView,
    TResult? Function(ViewerReconnectingState value)? reconnecting,
    TResult? Function(NotBroadcastingState value)? notBroadcasting,
    TResult? Function(EndedState value)? ended,
    TResult? Function(FullState value)? full,
    TResult? Function(CannotConnectState value)? cannotConnect,
    TResult? Function(InvalidInputState value)? invalidInput,
  }) {
    return connecting?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ViewerIdleState value)? idle,
    TResult Function(ResolvingState value)? resolving,
    TResult Function(ConnectingState value)? connecting,
    TResult Function(LiveViewState value)? liveView,
    TResult Function(ViewerReconnectingState value)? reconnecting,
    TResult Function(NotBroadcastingState value)? notBroadcasting,
    TResult Function(EndedState value)? ended,
    TResult Function(FullState value)? full,
    TResult Function(CannotConnectState value)? cannotConnect,
    TResult Function(InvalidInputState value)? invalidInput,
    required TResult orElse(),
  }) {
    if (connecting != null) {
      return connecting(this);
    }
    return orElse();
  }
}

abstract class ConnectingState implements ViewerSessionState {
  const factory ConnectingState() = _$ConnectingStateImpl;
}

/// @nodoc
abstract class _$$LiveViewStateImplCopyWith<$Res> {
  factory _$$LiveViewStateImplCopyWith(
    _$LiveViewStateImpl value,
    $Res Function(_$LiveViewStateImpl) then,
  ) = __$$LiveViewStateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({CaptionActivity captionActivity, ConnectionType connectionType});
}

/// @nodoc
class __$$LiveViewStateImplCopyWithImpl<$Res>
    extends _$ViewerSessionStateCopyWithImpl<$Res, _$LiveViewStateImpl>
    implements _$$LiveViewStateImplCopyWith<$Res> {
  __$$LiveViewStateImplCopyWithImpl(
    _$LiveViewStateImpl _value,
    $Res Function(_$LiveViewStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? captionActivity = null, Object? connectionType = null}) {
    return _then(
      _$LiveViewStateImpl(
        captionActivity: null == captionActivity
            ? _value.captionActivity
            : captionActivity // ignore: cast_nullable_to_non_nullable
                  as CaptionActivity,
        connectionType: null == connectionType
            ? _value.connectionType
            : connectionType // ignore: cast_nullable_to_non_nullable
                  as ConnectionType,
      ),
    );
  }
}

/// @nodoc

class _$LiveViewStateImpl implements LiveViewState {
  const _$LiveViewStateImpl({
    required this.captionActivity,
    required this.connectionType,
  });

  @override
  final CaptionActivity captionActivity;
  @override
  final ConnectionType connectionType;

  @override
  String toString() {
    return 'ViewerSessionState.liveView(captionActivity: $captionActivity, connectionType: $connectionType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveViewStateImpl &&
            (identical(other.captionActivity, captionActivity) ||
                other.captionActivity == captionActivity) &&
            (identical(other.connectionType, connectionType) ||
                other.connectionType == connectionType));
  }

  @override
  int get hashCode => Object.hash(runtimeType, captionActivity, connectionType);

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveViewStateImplCopyWith<_$LiveViewStateImpl> get copyWith =>
      __$$LiveViewStateImplCopyWithImpl<_$LiveViewStateImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() resolving,
    required TResult Function() connecting,
    required TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )
    liveView,
    required TResult Function() reconnecting,
    required TResult Function() notBroadcasting,
    required TResult Function() ended,
    required TResult Function() full,
    required TResult Function(ConnectFailure reason) cannotConnect,
    required TResult Function() invalidInput,
  }) {
    return liveView(captionActivity, connectionType);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? resolving,
    TResult? Function()? connecting,
    TResult? Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult? Function()? reconnecting,
    TResult? Function()? notBroadcasting,
    TResult? Function()? ended,
    TResult? Function()? full,
    TResult? Function(ConnectFailure reason)? cannotConnect,
    TResult? Function()? invalidInput,
  }) {
    return liveView?.call(captionActivity, connectionType);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? resolving,
    TResult Function()? connecting,
    TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult Function()? reconnecting,
    TResult Function()? notBroadcasting,
    TResult Function()? ended,
    TResult Function()? full,
    TResult Function(ConnectFailure reason)? cannotConnect,
    TResult Function()? invalidInput,
    required TResult orElse(),
  }) {
    if (liveView != null) {
      return liveView(captionActivity, connectionType);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ViewerIdleState value) idle,
    required TResult Function(ResolvingState value) resolving,
    required TResult Function(ConnectingState value) connecting,
    required TResult Function(LiveViewState value) liveView,
    required TResult Function(ViewerReconnectingState value) reconnecting,
    required TResult Function(NotBroadcastingState value) notBroadcasting,
    required TResult Function(EndedState value) ended,
    required TResult Function(FullState value) full,
    required TResult Function(CannotConnectState value) cannotConnect,
    required TResult Function(InvalidInputState value) invalidInput,
  }) {
    return liveView(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ViewerIdleState value)? idle,
    TResult? Function(ResolvingState value)? resolving,
    TResult? Function(ConnectingState value)? connecting,
    TResult? Function(LiveViewState value)? liveView,
    TResult? Function(ViewerReconnectingState value)? reconnecting,
    TResult? Function(NotBroadcastingState value)? notBroadcasting,
    TResult? Function(EndedState value)? ended,
    TResult? Function(FullState value)? full,
    TResult? Function(CannotConnectState value)? cannotConnect,
    TResult? Function(InvalidInputState value)? invalidInput,
  }) {
    return liveView?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ViewerIdleState value)? idle,
    TResult Function(ResolvingState value)? resolving,
    TResult Function(ConnectingState value)? connecting,
    TResult Function(LiveViewState value)? liveView,
    TResult Function(ViewerReconnectingState value)? reconnecting,
    TResult Function(NotBroadcastingState value)? notBroadcasting,
    TResult Function(EndedState value)? ended,
    TResult Function(FullState value)? full,
    TResult Function(CannotConnectState value)? cannotConnect,
    TResult Function(InvalidInputState value)? invalidInput,
    required TResult orElse(),
  }) {
    if (liveView != null) {
      return liveView(this);
    }
    return orElse();
  }
}

abstract class LiveViewState implements ViewerSessionState {
  const factory LiveViewState({
    required final CaptionActivity captionActivity,
    required final ConnectionType connectionType,
  }) = _$LiveViewStateImpl;

  CaptionActivity get captionActivity;
  ConnectionType get connectionType;

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveViewStateImplCopyWith<_$LiveViewStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ViewerReconnectingStateImplCopyWith<$Res> {
  factory _$$ViewerReconnectingStateImplCopyWith(
    _$ViewerReconnectingStateImpl value,
    $Res Function(_$ViewerReconnectingStateImpl) then,
  ) = __$$ViewerReconnectingStateImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ViewerReconnectingStateImplCopyWithImpl<$Res>
    extends
        _$ViewerSessionStateCopyWithImpl<$Res, _$ViewerReconnectingStateImpl>
    implements _$$ViewerReconnectingStateImplCopyWith<$Res> {
  __$$ViewerReconnectingStateImplCopyWithImpl(
    _$ViewerReconnectingStateImpl _value,
    $Res Function(_$ViewerReconnectingStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ViewerReconnectingStateImpl implements ViewerReconnectingState {
  const _$ViewerReconnectingStateImpl();

  @override
  String toString() {
    return 'ViewerSessionState.reconnecting()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ViewerReconnectingStateImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() resolving,
    required TResult Function() connecting,
    required TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )
    liveView,
    required TResult Function() reconnecting,
    required TResult Function() notBroadcasting,
    required TResult Function() ended,
    required TResult Function() full,
    required TResult Function(ConnectFailure reason) cannotConnect,
    required TResult Function() invalidInput,
  }) {
    return reconnecting();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? resolving,
    TResult? Function()? connecting,
    TResult? Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult? Function()? reconnecting,
    TResult? Function()? notBroadcasting,
    TResult? Function()? ended,
    TResult? Function()? full,
    TResult? Function(ConnectFailure reason)? cannotConnect,
    TResult? Function()? invalidInput,
  }) {
    return reconnecting?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? resolving,
    TResult Function()? connecting,
    TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult Function()? reconnecting,
    TResult Function()? notBroadcasting,
    TResult Function()? ended,
    TResult Function()? full,
    TResult Function(ConnectFailure reason)? cannotConnect,
    TResult Function()? invalidInput,
    required TResult orElse(),
  }) {
    if (reconnecting != null) {
      return reconnecting();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ViewerIdleState value) idle,
    required TResult Function(ResolvingState value) resolving,
    required TResult Function(ConnectingState value) connecting,
    required TResult Function(LiveViewState value) liveView,
    required TResult Function(ViewerReconnectingState value) reconnecting,
    required TResult Function(NotBroadcastingState value) notBroadcasting,
    required TResult Function(EndedState value) ended,
    required TResult Function(FullState value) full,
    required TResult Function(CannotConnectState value) cannotConnect,
    required TResult Function(InvalidInputState value) invalidInput,
  }) {
    return reconnecting(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ViewerIdleState value)? idle,
    TResult? Function(ResolvingState value)? resolving,
    TResult? Function(ConnectingState value)? connecting,
    TResult? Function(LiveViewState value)? liveView,
    TResult? Function(ViewerReconnectingState value)? reconnecting,
    TResult? Function(NotBroadcastingState value)? notBroadcasting,
    TResult? Function(EndedState value)? ended,
    TResult? Function(FullState value)? full,
    TResult? Function(CannotConnectState value)? cannotConnect,
    TResult? Function(InvalidInputState value)? invalidInput,
  }) {
    return reconnecting?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ViewerIdleState value)? idle,
    TResult Function(ResolvingState value)? resolving,
    TResult Function(ConnectingState value)? connecting,
    TResult Function(LiveViewState value)? liveView,
    TResult Function(ViewerReconnectingState value)? reconnecting,
    TResult Function(NotBroadcastingState value)? notBroadcasting,
    TResult Function(EndedState value)? ended,
    TResult Function(FullState value)? full,
    TResult Function(CannotConnectState value)? cannotConnect,
    TResult Function(InvalidInputState value)? invalidInput,
    required TResult orElse(),
  }) {
    if (reconnecting != null) {
      return reconnecting(this);
    }
    return orElse();
  }
}

abstract class ViewerReconnectingState implements ViewerSessionState {
  const factory ViewerReconnectingState() = _$ViewerReconnectingStateImpl;
}

/// @nodoc
abstract class _$$NotBroadcastingStateImplCopyWith<$Res> {
  factory _$$NotBroadcastingStateImplCopyWith(
    _$NotBroadcastingStateImpl value,
    $Res Function(_$NotBroadcastingStateImpl) then,
  ) = __$$NotBroadcastingStateImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$NotBroadcastingStateImplCopyWithImpl<$Res>
    extends _$ViewerSessionStateCopyWithImpl<$Res, _$NotBroadcastingStateImpl>
    implements _$$NotBroadcastingStateImplCopyWith<$Res> {
  __$$NotBroadcastingStateImplCopyWithImpl(
    _$NotBroadcastingStateImpl _value,
    $Res Function(_$NotBroadcastingStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$NotBroadcastingStateImpl implements NotBroadcastingState {
  const _$NotBroadcastingStateImpl();

  @override
  String toString() {
    return 'ViewerSessionState.notBroadcasting()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotBroadcastingStateImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() resolving,
    required TResult Function() connecting,
    required TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )
    liveView,
    required TResult Function() reconnecting,
    required TResult Function() notBroadcasting,
    required TResult Function() ended,
    required TResult Function() full,
    required TResult Function(ConnectFailure reason) cannotConnect,
    required TResult Function() invalidInput,
  }) {
    return notBroadcasting();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? resolving,
    TResult? Function()? connecting,
    TResult? Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult? Function()? reconnecting,
    TResult? Function()? notBroadcasting,
    TResult? Function()? ended,
    TResult? Function()? full,
    TResult? Function(ConnectFailure reason)? cannotConnect,
    TResult? Function()? invalidInput,
  }) {
    return notBroadcasting?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? resolving,
    TResult Function()? connecting,
    TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult Function()? reconnecting,
    TResult Function()? notBroadcasting,
    TResult Function()? ended,
    TResult Function()? full,
    TResult Function(ConnectFailure reason)? cannotConnect,
    TResult Function()? invalidInput,
    required TResult orElse(),
  }) {
    if (notBroadcasting != null) {
      return notBroadcasting();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ViewerIdleState value) idle,
    required TResult Function(ResolvingState value) resolving,
    required TResult Function(ConnectingState value) connecting,
    required TResult Function(LiveViewState value) liveView,
    required TResult Function(ViewerReconnectingState value) reconnecting,
    required TResult Function(NotBroadcastingState value) notBroadcasting,
    required TResult Function(EndedState value) ended,
    required TResult Function(FullState value) full,
    required TResult Function(CannotConnectState value) cannotConnect,
    required TResult Function(InvalidInputState value) invalidInput,
  }) {
    return notBroadcasting(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ViewerIdleState value)? idle,
    TResult? Function(ResolvingState value)? resolving,
    TResult? Function(ConnectingState value)? connecting,
    TResult? Function(LiveViewState value)? liveView,
    TResult? Function(ViewerReconnectingState value)? reconnecting,
    TResult? Function(NotBroadcastingState value)? notBroadcasting,
    TResult? Function(EndedState value)? ended,
    TResult? Function(FullState value)? full,
    TResult? Function(CannotConnectState value)? cannotConnect,
    TResult? Function(InvalidInputState value)? invalidInput,
  }) {
    return notBroadcasting?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ViewerIdleState value)? idle,
    TResult Function(ResolvingState value)? resolving,
    TResult Function(ConnectingState value)? connecting,
    TResult Function(LiveViewState value)? liveView,
    TResult Function(ViewerReconnectingState value)? reconnecting,
    TResult Function(NotBroadcastingState value)? notBroadcasting,
    TResult Function(EndedState value)? ended,
    TResult Function(FullState value)? full,
    TResult Function(CannotConnectState value)? cannotConnect,
    TResult Function(InvalidInputState value)? invalidInput,
    required TResult orElse(),
  }) {
    if (notBroadcasting != null) {
      return notBroadcasting(this);
    }
    return orElse();
  }
}

abstract class NotBroadcastingState implements ViewerSessionState {
  const factory NotBroadcastingState() = _$NotBroadcastingStateImpl;
}

/// @nodoc
abstract class _$$EndedStateImplCopyWith<$Res> {
  factory _$$EndedStateImplCopyWith(
    _$EndedStateImpl value,
    $Res Function(_$EndedStateImpl) then,
  ) = __$$EndedStateImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$EndedStateImplCopyWithImpl<$Res>
    extends _$ViewerSessionStateCopyWithImpl<$Res, _$EndedStateImpl>
    implements _$$EndedStateImplCopyWith<$Res> {
  __$$EndedStateImplCopyWithImpl(
    _$EndedStateImpl _value,
    $Res Function(_$EndedStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$EndedStateImpl implements EndedState {
  const _$EndedStateImpl();

  @override
  String toString() {
    return 'ViewerSessionState.ended()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$EndedStateImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() resolving,
    required TResult Function() connecting,
    required TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )
    liveView,
    required TResult Function() reconnecting,
    required TResult Function() notBroadcasting,
    required TResult Function() ended,
    required TResult Function() full,
    required TResult Function(ConnectFailure reason) cannotConnect,
    required TResult Function() invalidInput,
  }) {
    return ended();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? resolving,
    TResult? Function()? connecting,
    TResult? Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult? Function()? reconnecting,
    TResult? Function()? notBroadcasting,
    TResult? Function()? ended,
    TResult? Function()? full,
    TResult? Function(ConnectFailure reason)? cannotConnect,
    TResult? Function()? invalidInput,
  }) {
    return ended?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? resolving,
    TResult Function()? connecting,
    TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult Function()? reconnecting,
    TResult Function()? notBroadcasting,
    TResult Function()? ended,
    TResult Function()? full,
    TResult Function(ConnectFailure reason)? cannotConnect,
    TResult Function()? invalidInput,
    required TResult orElse(),
  }) {
    if (ended != null) {
      return ended();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ViewerIdleState value) idle,
    required TResult Function(ResolvingState value) resolving,
    required TResult Function(ConnectingState value) connecting,
    required TResult Function(LiveViewState value) liveView,
    required TResult Function(ViewerReconnectingState value) reconnecting,
    required TResult Function(NotBroadcastingState value) notBroadcasting,
    required TResult Function(EndedState value) ended,
    required TResult Function(FullState value) full,
    required TResult Function(CannotConnectState value) cannotConnect,
    required TResult Function(InvalidInputState value) invalidInput,
  }) {
    return ended(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ViewerIdleState value)? idle,
    TResult? Function(ResolvingState value)? resolving,
    TResult? Function(ConnectingState value)? connecting,
    TResult? Function(LiveViewState value)? liveView,
    TResult? Function(ViewerReconnectingState value)? reconnecting,
    TResult? Function(NotBroadcastingState value)? notBroadcasting,
    TResult? Function(EndedState value)? ended,
    TResult? Function(FullState value)? full,
    TResult? Function(CannotConnectState value)? cannotConnect,
    TResult? Function(InvalidInputState value)? invalidInput,
  }) {
    return ended?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ViewerIdleState value)? idle,
    TResult Function(ResolvingState value)? resolving,
    TResult Function(ConnectingState value)? connecting,
    TResult Function(LiveViewState value)? liveView,
    TResult Function(ViewerReconnectingState value)? reconnecting,
    TResult Function(NotBroadcastingState value)? notBroadcasting,
    TResult Function(EndedState value)? ended,
    TResult Function(FullState value)? full,
    TResult Function(CannotConnectState value)? cannotConnect,
    TResult Function(InvalidInputState value)? invalidInput,
    required TResult orElse(),
  }) {
    if (ended != null) {
      return ended(this);
    }
    return orElse();
  }
}

abstract class EndedState implements ViewerSessionState {
  const factory EndedState() = _$EndedStateImpl;
}

/// @nodoc
abstract class _$$FullStateImplCopyWith<$Res> {
  factory _$$FullStateImplCopyWith(
    _$FullStateImpl value,
    $Res Function(_$FullStateImpl) then,
  ) = __$$FullStateImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$FullStateImplCopyWithImpl<$Res>
    extends _$ViewerSessionStateCopyWithImpl<$Res, _$FullStateImpl>
    implements _$$FullStateImplCopyWith<$Res> {
  __$$FullStateImplCopyWithImpl(
    _$FullStateImpl _value,
    $Res Function(_$FullStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$FullStateImpl implements FullState {
  const _$FullStateImpl();

  @override
  String toString() {
    return 'ViewerSessionState.full()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$FullStateImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() resolving,
    required TResult Function() connecting,
    required TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )
    liveView,
    required TResult Function() reconnecting,
    required TResult Function() notBroadcasting,
    required TResult Function() ended,
    required TResult Function() full,
    required TResult Function(ConnectFailure reason) cannotConnect,
    required TResult Function() invalidInput,
  }) {
    return full();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? resolving,
    TResult? Function()? connecting,
    TResult? Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult? Function()? reconnecting,
    TResult? Function()? notBroadcasting,
    TResult? Function()? ended,
    TResult? Function()? full,
    TResult? Function(ConnectFailure reason)? cannotConnect,
    TResult? Function()? invalidInput,
  }) {
    return full?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? resolving,
    TResult Function()? connecting,
    TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult Function()? reconnecting,
    TResult Function()? notBroadcasting,
    TResult Function()? ended,
    TResult Function()? full,
    TResult Function(ConnectFailure reason)? cannotConnect,
    TResult Function()? invalidInput,
    required TResult orElse(),
  }) {
    if (full != null) {
      return full();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ViewerIdleState value) idle,
    required TResult Function(ResolvingState value) resolving,
    required TResult Function(ConnectingState value) connecting,
    required TResult Function(LiveViewState value) liveView,
    required TResult Function(ViewerReconnectingState value) reconnecting,
    required TResult Function(NotBroadcastingState value) notBroadcasting,
    required TResult Function(EndedState value) ended,
    required TResult Function(FullState value) full,
    required TResult Function(CannotConnectState value) cannotConnect,
    required TResult Function(InvalidInputState value) invalidInput,
  }) {
    return full(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ViewerIdleState value)? idle,
    TResult? Function(ResolvingState value)? resolving,
    TResult? Function(ConnectingState value)? connecting,
    TResult? Function(LiveViewState value)? liveView,
    TResult? Function(ViewerReconnectingState value)? reconnecting,
    TResult? Function(NotBroadcastingState value)? notBroadcasting,
    TResult? Function(EndedState value)? ended,
    TResult? Function(FullState value)? full,
    TResult? Function(CannotConnectState value)? cannotConnect,
    TResult? Function(InvalidInputState value)? invalidInput,
  }) {
    return full?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ViewerIdleState value)? idle,
    TResult Function(ResolvingState value)? resolving,
    TResult Function(ConnectingState value)? connecting,
    TResult Function(LiveViewState value)? liveView,
    TResult Function(ViewerReconnectingState value)? reconnecting,
    TResult Function(NotBroadcastingState value)? notBroadcasting,
    TResult Function(EndedState value)? ended,
    TResult Function(FullState value)? full,
    TResult Function(CannotConnectState value)? cannotConnect,
    TResult Function(InvalidInputState value)? invalidInput,
    required TResult orElse(),
  }) {
    if (full != null) {
      return full(this);
    }
    return orElse();
  }
}

abstract class FullState implements ViewerSessionState {
  const factory FullState() = _$FullStateImpl;
}

/// @nodoc
abstract class _$$CannotConnectStateImplCopyWith<$Res> {
  factory _$$CannotConnectStateImplCopyWith(
    _$CannotConnectStateImpl value,
    $Res Function(_$CannotConnectStateImpl) then,
  ) = __$$CannotConnectStateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({ConnectFailure reason});
}

/// @nodoc
class __$$CannotConnectStateImplCopyWithImpl<$Res>
    extends _$ViewerSessionStateCopyWithImpl<$Res, _$CannotConnectStateImpl>
    implements _$$CannotConnectStateImplCopyWith<$Res> {
  __$$CannotConnectStateImplCopyWithImpl(
    _$CannotConnectStateImpl _value,
    $Res Function(_$CannotConnectStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? reason = null}) {
    return _then(
      _$CannotConnectStateImpl(
        null == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as ConnectFailure,
      ),
    );
  }
}

/// @nodoc

class _$CannotConnectStateImpl implements CannotConnectState {
  const _$CannotConnectStateImpl(this.reason);

  @override
  final ConnectFailure reason;

  @override
  String toString() {
    return 'ViewerSessionState.cannotConnect(reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CannotConnectStateImpl &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @override
  int get hashCode => Object.hash(runtimeType, reason);

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CannotConnectStateImplCopyWith<_$CannotConnectStateImpl> get copyWith =>
      __$$CannotConnectStateImplCopyWithImpl<_$CannotConnectStateImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() resolving,
    required TResult Function() connecting,
    required TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )
    liveView,
    required TResult Function() reconnecting,
    required TResult Function() notBroadcasting,
    required TResult Function() ended,
    required TResult Function() full,
    required TResult Function(ConnectFailure reason) cannotConnect,
    required TResult Function() invalidInput,
  }) {
    return cannotConnect(reason);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? resolving,
    TResult? Function()? connecting,
    TResult? Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult? Function()? reconnecting,
    TResult? Function()? notBroadcasting,
    TResult? Function()? ended,
    TResult? Function()? full,
    TResult? Function(ConnectFailure reason)? cannotConnect,
    TResult? Function()? invalidInput,
  }) {
    return cannotConnect?.call(reason);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? resolving,
    TResult Function()? connecting,
    TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult Function()? reconnecting,
    TResult Function()? notBroadcasting,
    TResult Function()? ended,
    TResult Function()? full,
    TResult Function(ConnectFailure reason)? cannotConnect,
    TResult Function()? invalidInput,
    required TResult orElse(),
  }) {
    if (cannotConnect != null) {
      return cannotConnect(reason);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ViewerIdleState value) idle,
    required TResult Function(ResolvingState value) resolving,
    required TResult Function(ConnectingState value) connecting,
    required TResult Function(LiveViewState value) liveView,
    required TResult Function(ViewerReconnectingState value) reconnecting,
    required TResult Function(NotBroadcastingState value) notBroadcasting,
    required TResult Function(EndedState value) ended,
    required TResult Function(FullState value) full,
    required TResult Function(CannotConnectState value) cannotConnect,
    required TResult Function(InvalidInputState value) invalidInput,
  }) {
    return cannotConnect(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ViewerIdleState value)? idle,
    TResult? Function(ResolvingState value)? resolving,
    TResult? Function(ConnectingState value)? connecting,
    TResult? Function(LiveViewState value)? liveView,
    TResult? Function(ViewerReconnectingState value)? reconnecting,
    TResult? Function(NotBroadcastingState value)? notBroadcasting,
    TResult? Function(EndedState value)? ended,
    TResult? Function(FullState value)? full,
    TResult? Function(CannotConnectState value)? cannotConnect,
    TResult? Function(InvalidInputState value)? invalidInput,
  }) {
    return cannotConnect?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ViewerIdleState value)? idle,
    TResult Function(ResolvingState value)? resolving,
    TResult Function(ConnectingState value)? connecting,
    TResult Function(LiveViewState value)? liveView,
    TResult Function(ViewerReconnectingState value)? reconnecting,
    TResult Function(NotBroadcastingState value)? notBroadcasting,
    TResult Function(EndedState value)? ended,
    TResult Function(FullState value)? full,
    TResult Function(CannotConnectState value)? cannotConnect,
    TResult Function(InvalidInputState value)? invalidInput,
    required TResult orElse(),
  }) {
    if (cannotConnect != null) {
      return cannotConnect(this);
    }
    return orElse();
  }
}

abstract class CannotConnectState implements ViewerSessionState {
  const factory CannotConnectState(final ConnectFailure reason) =
      _$CannotConnectStateImpl;

  ConnectFailure get reason;

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CannotConnectStateImplCopyWith<_$CannotConnectStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$InvalidInputStateImplCopyWith<$Res> {
  factory _$$InvalidInputStateImplCopyWith(
    _$InvalidInputStateImpl value,
    $Res Function(_$InvalidInputStateImpl) then,
  ) = __$$InvalidInputStateImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$InvalidInputStateImplCopyWithImpl<$Res>
    extends _$ViewerSessionStateCopyWithImpl<$Res, _$InvalidInputStateImpl>
    implements _$$InvalidInputStateImplCopyWith<$Res> {
  __$$InvalidInputStateImplCopyWithImpl(
    _$InvalidInputStateImpl _value,
    $Res Function(_$InvalidInputStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ViewerSessionState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$InvalidInputStateImpl implements InvalidInputState {
  const _$InvalidInputStateImpl();

  @override
  String toString() {
    return 'ViewerSessionState.invalidInput()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$InvalidInputStateImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() resolving,
    required TResult Function() connecting,
    required TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )
    liveView,
    required TResult Function() reconnecting,
    required TResult Function() notBroadcasting,
    required TResult Function() ended,
    required TResult Function() full,
    required TResult Function(ConnectFailure reason) cannotConnect,
    required TResult Function() invalidInput,
  }) {
    return invalidInput();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? resolving,
    TResult? Function()? connecting,
    TResult? Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult? Function()? reconnecting,
    TResult? Function()? notBroadcasting,
    TResult? Function()? ended,
    TResult? Function()? full,
    TResult? Function(ConnectFailure reason)? cannotConnect,
    TResult? Function()? invalidInput,
  }) {
    return invalidInput?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? resolving,
    TResult Function()? connecting,
    TResult Function(
      CaptionActivity captionActivity,
      ConnectionType connectionType,
    )?
    liveView,
    TResult Function()? reconnecting,
    TResult Function()? notBroadcasting,
    TResult Function()? ended,
    TResult Function()? full,
    TResult Function(ConnectFailure reason)? cannotConnect,
    TResult Function()? invalidInput,
    required TResult orElse(),
  }) {
    if (invalidInput != null) {
      return invalidInput();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ViewerIdleState value) idle,
    required TResult Function(ResolvingState value) resolving,
    required TResult Function(ConnectingState value) connecting,
    required TResult Function(LiveViewState value) liveView,
    required TResult Function(ViewerReconnectingState value) reconnecting,
    required TResult Function(NotBroadcastingState value) notBroadcasting,
    required TResult Function(EndedState value) ended,
    required TResult Function(FullState value) full,
    required TResult Function(CannotConnectState value) cannotConnect,
    required TResult Function(InvalidInputState value) invalidInput,
  }) {
    return invalidInput(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ViewerIdleState value)? idle,
    TResult? Function(ResolvingState value)? resolving,
    TResult? Function(ConnectingState value)? connecting,
    TResult? Function(LiveViewState value)? liveView,
    TResult? Function(ViewerReconnectingState value)? reconnecting,
    TResult? Function(NotBroadcastingState value)? notBroadcasting,
    TResult? Function(EndedState value)? ended,
    TResult? Function(FullState value)? full,
    TResult? Function(CannotConnectState value)? cannotConnect,
    TResult? Function(InvalidInputState value)? invalidInput,
  }) {
    return invalidInput?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ViewerIdleState value)? idle,
    TResult Function(ResolvingState value)? resolving,
    TResult Function(ConnectingState value)? connecting,
    TResult Function(LiveViewState value)? liveView,
    TResult Function(ViewerReconnectingState value)? reconnecting,
    TResult Function(NotBroadcastingState value)? notBroadcasting,
    TResult Function(EndedState value)? ended,
    TResult Function(FullState value)? full,
    TResult Function(CannotConnectState value)? cannotConnect,
    TResult Function(InvalidInputState value)? invalidInput,
    required TResult orElse(),
  }) {
    if (invalidInput != null) {
      return invalidInput(this);
    }
    return orElse();
  }
}

abstract class InvalidInputState implements ViewerSessionState {
  const factory InvalidInputState() = _$InvalidInputStateImpl;
}
