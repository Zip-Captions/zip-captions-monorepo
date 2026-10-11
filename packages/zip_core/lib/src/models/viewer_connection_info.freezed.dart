// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'viewer_connection_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ViewerConnectionInfo {
  /// The viewer's ephemeral signaling-layer peer id.
  String get peerId => throw _privateConstructorUsedError;

  /// How this viewer's connection is currently routed.
  ConnectionType get connectionType => throw _privateConstructorUsedError;

  /// When this viewer was confirmed joined (ack-timer success).
  DateTime get connectedAt => throw _privateConstructorUsedError;

  /// Create a copy of ViewerConnectionInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ViewerConnectionInfoCopyWith<ViewerConnectionInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ViewerConnectionInfoCopyWith<$Res> {
  factory $ViewerConnectionInfoCopyWith(
    ViewerConnectionInfo value,
    $Res Function(ViewerConnectionInfo) then,
  ) = _$ViewerConnectionInfoCopyWithImpl<$Res, ViewerConnectionInfo>;
  @useResult
  $Res call({
    String peerId,
    ConnectionType connectionType,
    DateTime connectedAt,
  });
}

/// @nodoc
class _$ViewerConnectionInfoCopyWithImpl<
  $Res,
  $Val extends ViewerConnectionInfo
>
    implements $ViewerConnectionInfoCopyWith<$Res> {
  _$ViewerConnectionInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ViewerConnectionInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? peerId = null,
    Object? connectionType = null,
    Object? connectedAt = null,
  }) {
    return _then(
      _value.copyWith(
            peerId: null == peerId
                ? _value.peerId
                : peerId // ignore: cast_nullable_to_non_nullable
                      as String,
            connectionType: null == connectionType
                ? _value.connectionType
                : connectionType // ignore: cast_nullable_to_non_nullable
                      as ConnectionType,
            connectedAt: null == connectedAt
                ? _value.connectedAt
                : connectedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ViewerConnectionInfoImplCopyWith<$Res>
    implements $ViewerConnectionInfoCopyWith<$Res> {
  factory _$$ViewerConnectionInfoImplCopyWith(
    _$ViewerConnectionInfoImpl value,
    $Res Function(_$ViewerConnectionInfoImpl) then,
  ) = __$$ViewerConnectionInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String peerId,
    ConnectionType connectionType,
    DateTime connectedAt,
  });
}

/// @nodoc
class __$$ViewerConnectionInfoImplCopyWithImpl<$Res>
    extends _$ViewerConnectionInfoCopyWithImpl<$Res, _$ViewerConnectionInfoImpl>
    implements _$$ViewerConnectionInfoImplCopyWith<$Res> {
  __$$ViewerConnectionInfoImplCopyWithImpl(
    _$ViewerConnectionInfoImpl _value,
    $Res Function(_$ViewerConnectionInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ViewerConnectionInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? peerId = null,
    Object? connectionType = null,
    Object? connectedAt = null,
  }) {
    return _then(
      _$ViewerConnectionInfoImpl(
        peerId: null == peerId
            ? _value.peerId
            : peerId // ignore: cast_nullable_to_non_nullable
                  as String,
        connectionType: null == connectionType
            ? _value.connectionType
            : connectionType // ignore: cast_nullable_to_non_nullable
                  as ConnectionType,
        connectedAt: null == connectedAt
            ? _value.connectedAt
            : connectedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$ViewerConnectionInfoImpl implements _ViewerConnectionInfo {
  const _$ViewerConnectionInfoImpl({
    required this.peerId,
    required this.connectionType,
    required this.connectedAt,
  });

  /// The viewer's ephemeral signaling-layer peer id.
  @override
  final String peerId;

  /// How this viewer's connection is currently routed.
  @override
  final ConnectionType connectionType;

  /// When this viewer was confirmed joined (ack-timer success).
  @override
  final DateTime connectedAt;

  @override
  String toString() {
    return 'ViewerConnectionInfo(peerId: $peerId, connectionType: $connectionType, connectedAt: $connectedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ViewerConnectionInfoImpl &&
            (identical(other.peerId, peerId) || other.peerId == peerId) &&
            (identical(other.connectionType, connectionType) ||
                other.connectionType == connectionType) &&
            (identical(other.connectedAt, connectedAt) ||
                other.connectedAt == connectedAt));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, peerId, connectionType, connectedAt);

  /// Create a copy of ViewerConnectionInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ViewerConnectionInfoImplCopyWith<_$ViewerConnectionInfoImpl>
  get copyWith =>
      __$$ViewerConnectionInfoImplCopyWithImpl<_$ViewerConnectionInfoImpl>(
        this,
        _$identity,
      );
}

abstract class _ViewerConnectionInfo implements ViewerConnectionInfo {
  const factory _ViewerConnectionInfo({
    required final String peerId,
    required final ConnectionType connectionType,
    required final DateTime connectedAt,
  }) = _$ViewerConnectionInfoImpl;

  /// The viewer's ephemeral signaling-layer peer id.
  @override
  String get peerId;

  /// How this viewer's connection is currently routed.
  @override
  ConnectionType get connectionType;

  /// When this viewer was confirmed joined (ack-timer success).
  @override
  DateTime get connectedAt;

  /// Create a copy of ViewerConnectionInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ViewerConnectionInfoImplCopyWith<_$ViewerConnectionInfoImpl>
  get copyWith => throw _privateConstructorUsedError;
}
