// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'turn_credentials.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$TurnCredentials {
  /// TURN REST username — the credential's unix-timestamp expiry, per
  /// the TURN REST API shared-secret scheme.
  String get username => throw _privateConstructorUsedError;

  /// base64(HMAC-SHA1(sharedSecret, username)), computed server-side.
  String get credential => throw _privateConstructorUsedError;

  /// When this credential stops being valid (NFR Requirements Q5: 1
  /// hour TTL). Proactive renewal before this is a hard Unit 5
  /// requirement.
  DateTime get expiresAt => throw _privateConstructorUsedError;

  /// STUN/TURN server URLs this credential is valid for.
  List<String> get urls => throw _privateConstructorUsedError;

  /// Create a copy of TurnCredentials
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TurnCredentialsCopyWith<TurnCredentials> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TurnCredentialsCopyWith<$Res> {
  factory $TurnCredentialsCopyWith(
    TurnCredentials value,
    $Res Function(TurnCredentials) then,
  ) = _$TurnCredentialsCopyWithImpl<$Res, TurnCredentials>;
  @useResult
  $Res call({
    String username,
    String credential,
    DateTime expiresAt,
    List<String> urls,
  });
}

/// @nodoc
class _$TurnCredentialsCopyWithImpl<$Res, $Val extends TurnCredentials>
    implements $TurnCredentialsCopyWith<$Res> {
  _$TurnCredentialsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TurnCredentials
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? username = null,
    Object? credential = null,
    Object? expiresAt = null,
    Object? urls = null,
  }) {
    return _then(
      _value.copyWith(
            username: null == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String,
            credential: null == credential
                ? _value.credential
                : credential // ignore: cast_nullable_to_non_nullable
                      as String,
            expiresAt: null == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            urls: null == urls
                ? _value.urls
                : urls // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TurnCredentialsImplCopyWith<$Res>
    implements $TurnCredentialsCopyWith<$Res> {
  factory _$$TurnCredentialsImplCopyWith(
    _$TurnCredentialsImpl value,
    $Res Function(_$TurnCredentialsImpl) then,
  ) = __$$TurnCredentialsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String username,
    String credential,
    DateTime expiresAt,
    List<String> urls,
  });
}

/// @nodoc
class __$$TurnCredentialsImplCopyWithImpl<$Res>
    extends _$TurnCredentialsCopyWithImpl<$Res, _$TurnCredentialsImpl>
    implements _$$TurnCredentialsImplCopyWith<$Res> {
  __$$TurnCredentialsImplCopyWithImpl(
    _$TurnCredentialsImpl _value,
    $Res Function(_$TurnCredentialsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TurnCredentials
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? username = null,
    Object? credential = null,
    Object? expiresAt = null,
    Object? urls = null,
  }) {
    return _then(
      _$TurnCredentialsImpl(
        username: null == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String,
        credential: null == credential
            ? _value.credential
            : credential // ignore: cast_nullable_to_non_nullable
                  as String,
        expiresAt: null == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        urls: null == urls
            ? _value._urls
            : urls // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$TurnCredentialsImpl implements _TurnCredentials {
  const _$TurnCredentialsImpl({
    required this.username,
    required this.credential,
    required this.expiresAt,
    required final List<String> urls,
  }) : _urls = urls;

  /// TURN REST username — the credential's unix-timestamp expiry, per
  /// the TURN REST API shared-secret scheme.
  @override
  final String username;

  /// base64(HMAC-SHA1(sharedSecret, username)), computed server-side.
  @override
  final String credential;

  /// When this credential stops being valid (NFR Requirements Q5: 1
  /// hour TTL). Proactive renewal before this is a hard Unit 5
  /// requirement.
  @override
  final DateTime expiresAt;

  /// STUN/TURN server URLs this credential is valid for.
  final List<String> _urls;

  /// STUN/TURN server URLs this credential is valid for.
  @override
  List<String> get urls {
    if (_urls is EqualUnmodifiableListView) return _urls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_urls);
  }

  @override
  String toString() {
    return 'TurnCredentials(username: $username, credential: $credential, expiresAt: $expiresAt, urls: $urls)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TurnCredentialsImpl &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.credential, credential) ||
                other.credential == credential) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            const DeepCollectionEquality().equals(other._urls, _urls));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    username,
    credential,
    expiresAt,
    const DeepCollectionEquality().hash(_urls),
  );

  /// Create a copy of TurnCredentials
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TurnCredentialsImplCopyWith<_$TurnCredentialsImpl> get copyWith =>
      __$$TurnCredentialsImplCopyWithImpl<_$TurnCredentialsImpl>(
        this,
        _$identity,
      );
}

abstract class _TurnCredentials implements TurnCredentials {
  const factory _TurnCredentials({
    required final String username,
    required final String credential,
    required final DateTime expiresAt,
    required final List<String> urls,
  }) = _$TurnCredentialsImpl;

  /// TURN REST username — the credential's unix-timestamp expiry, per
  /// the TURN REST API shared-secret scheme.
  @override
  String get username;

  /// base64(HMAC-SHA1(sharedSecret, username)), computed server-side.
  @override
  String get credential;

  /// When this credential stops being valid (NFR Requirements Q5: 1
  /// hour TTL). Proactive renewal before this is a hard Unit 5
  /// requirement.
  @override
  DateTime get expiresAt;

  /// STUN/TURN server URLs this credential is valid for.
  @override
  List<String> get urls;

  /// Create a copy of TurnCredentials
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TurnCredentialsImplCopyWith<_$TurnCredentialsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
