// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ice_server.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$IceServer {
  /// STUN/TURN URLs, e.g. `stun:localhost:3478`, `turn:localhost:3478`.
  List<String> get urls => throw _privateConstructorUsedError;

  /// TURN credential username. `null` for a STUN-only entry.
  String? get username => throw _privateConstructorUsedError;

  /// TURN credential. `null` for a STUN-only entry.
  String? get credential => throw _privateConstructorUsedError;

  /// Create a copy of IceServer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $IceServerCopyWith<IceServer> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $IceServerCopyWith<$Res> {
  factory $IceServerCopyWith(IceServer value, $Res Function(IceServer) then) =
      _$IceServerCopyWithImpl<$Res, IceServer>;
  @useResult
  $Res call({List<String> urls, String? username, String? credential});
}

/// @nodoc
class _$IceServerCopyWithImpl<$Res, $Val extends IceServer>
    implements $IceServerCopyWith<$Res> {
  _$IceServerCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of IceServer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? urls = null,
    Object? username = freezed,
    Object? credential = freezed,
  }) {
    return _then(
      _value.copyWith(
            urls: null == urls
                ? _value.urls
                : urls // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            username: freezed == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String?,
            credential: freezed == credential
                ? _value.credential
                : credential // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$IceServerImplCopyWith<$Res>
    implements $IceServerCopyWith<$Res> {
  factory _$$IceServerImplCopyWith(
    _$IceServerImpl value,
    $Res Function(_$IceServerImpl) then,
  ) = __$$IceServerImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<String> urls, String? username, String? credential});
}

/// @nodoc
class __$$IceServerImplCopyWithImpl<$Res>
    extends _$IceServerCopyWithImpl<$Res, _$IceServerImpl>
    implements _$$IceServerImplCopyWith<$Res> {
  __$$IceServerImplCopyWithImpl(
    _$IceServerImpl _value,
    $Res Function(_$IceServerImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of IceServer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? urls = null,
    Object? username = freezed,
    Object? credential = freezed,
  }) {
    return _then(
      _$IceServerImpl(
        urls: null == urls
            ? _value._urls
            : urls // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        username: freezed == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String?,
        credential: freezed == credential
            ? _value.credential
            : credential // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$IceServerImpl implements _IceServer {
  const _$IceServerImpl({
    required final List<String> urls,
    this.username,
    this.credential,
  }) : _urls = urls;

  /// STUN/TURN URLs, e.g. `stun:localhost:3478`, `turn:localhost:3478`.
  final List<String> _urls;

  /// STUN/TURN URLs, e.g. `stun:localhost:3478`, `turn:localhost:3478`.
  @override
  List<String> get urls {
    if (_urls is EqualUnmodifiableListView) return _urls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_urls);
  }

  /// TURN credential username. `null` for a STUN-only entry.
  @override
  final String? username;

  /// TURN credential. `null` for a STUN-only entry.
  @override
  final String? credential;

  @override
  String toString() {
    return 'IceServer(urls: $urls, username: $username, credential: $credential)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$IceServerImpl &&
            const DeepCollectionEquality().equals(other._urls, _urls) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.credential, credential) ||
                other.credential == credential));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_urls),
    username,
    credential,
  );

  /// Create a copy of IceServer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$IceServerImplCopyWith<_$IceServerImpl> get copyWith =>
      __$$IceServerImplCopyWithImpl<_$IceServerImpl>(this, _$identity);
}

abstract class _IceServer implements IceServer {
  const factory _IceServer({
    required final List<String> urls,
    final String? username,
    final String? credential,
  }) = _$IceServerImpl;

  /// STUN/TURN URLs, e.g. `stun:localhost:3478`, `turn:localhost:3478`.
  @override
  List<String> get urls;

  /// TURN credential username. `null` for a STUN-only entry.
  @override
  String? get username;

  /// TURN credential. `null` for a STUN-only entry.
  @override
  String? get credential;

  /// Create a copy of IceServer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$IceServerImplCopyWith<_$IceServerImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
