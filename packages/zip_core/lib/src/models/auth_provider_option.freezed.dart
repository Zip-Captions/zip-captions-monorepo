// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_provider_option.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AuthProviderOption {
  /// Stable identifier passed to `AuthNotifier.signIn`/`AuthService.signIn`.
  String get id => throw _privateConstructorUsedError;

  /// Label rendered on the provider's sign-in button (not localized in
  /// Phase 2 — provider brand names are shown as-is).
  String get displayLabel => throw _privateConstructorUsedError;

  /// The GoTrue provider this option resolves to.
  OAuthProvider get provider => throw _privateConstructorUsedError;

  /// Create a copy of AuthProviderOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AuthProviderOptionCopyWith<AuthProviderOption> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuthProviderOptionCopyWith<$Res> {
  factory $AuthProviderOptionCopyWith(
    AuthProviderOption value,
    $Res Function(AuthProviderOption) then,
  ) = _$AuthProviderOptionCopyWithImpl<$Res, AuthProviderOption>;
  @useResult
  $Res call({String id, String displayLabel, OAuthProvider provider});
}

/// @nodoc
class _$AuthProviderOptionCopyWithImpl<$Res, $Val extends AuthProviderOption>
    implements $AuthProviderOptionCopyWith<$Res> {
  _$AuthProviderOptionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AuthProviderOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayLabel = null,
    Object? provider = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            displayLabel: null == displayLabel
                ? _value.displayLabel
                : displayLabel // ignore: cast_nullable_to_non_nullable
                      as String,
            provider: null == provider
                ? _value.provider
                : provider // ignore: cast_nullable_to_non_nullable
                      as OAuthProvider,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AuthProviderOptionImplCopyWith<$Res>
    implements $AuthProviderOptionCopyWith<$Res> {
  factory _$$AuthProviderOptionImplCopyWith(
    _$AuthProviderOptionImpl value,
    $Res Function(_$AuthProviderOptionImpl) then,
  ) = __$$AuthProviderOptionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String displayLabel, OAuthProvider provider});
}

/// @nodoc
class __$$AuthProviderOptionImplCopyWithImpl<$Res>
    extends _$AuthProviderOptionCopyWithImpl<$Res, _$AuthProviderOptionImpl>
    implements _$$AuthProviderOptionImplCopyWith<$Res> {
  __$$AuthProviderOptionImplCopyWithImpl(
    _$AuthProviderOptionImpl _value,
    $Res Function(_$AuthProviderOptionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthProviderOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayLabel = null,
    Object? provider = null,
  }) {
    return _then(
      _$AuthProviderOptionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        displayLabel: null == displayLabel
            ? _value.displayLabel
            : displayLabel // ignore: cast_nullable_to_non_nullable
                  as String,
        provider: null == provider
            ? _value.provider
            : provider // ignore: cast_nullable_to_non_nullable
                  as OAuthProvider,
      ),
    );
  }
}

/// @nodoc

class _$AuthProviderOptionImpl implements _AuthProviderOption {
  const _$AuthProviderOptionImpl({
    required this.id,
    required this.displayLabel,
    required this.provider,
  });

  /// Stable identifier passed to `AuthNotifier.signIn`/`AuthService.signIn`.
  @override
  final String id;

  /// Label rendered on the provider's sign-in button (not localized in
  /// Phase 2 — provider brand names are shown as-is).
  @override
  final String displayLabel;

  /// The GoTrue provider this option resolves to.
  @override
  final OAuthProvider provider;

  @override
  String toString() {
    return 'AuthProviderOption(id: $id, displayLabel: $displayLabel, provider: $provider)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AuthProviderOptionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayLabel, displayLabel) ||
                other.displayLabel == displayLabel) &&
            (identical(other.provider, provider) ||
                other.provider == provider));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, displayLabel, provider);

  /// Create a copy of AuthProviderOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AuthProviderOptionImplCopyWith<_$AuthProviderOptionImpl> get copyWith =>
      __$$AuthProviderOptionImplCopyWithImpl<_$AuthProviderOptionImpl>(
        this,
        _$identity,
      );
}

abstract class _AuthProviderOption implements AuthProviderOption {
  const factory _AuthProviderOption({
    required final String id,
    required final String displayLabel,
    required final OAuthProvider provider,
  }) = _$AuthProviderOptionImpl;

  /// Stable identifier passed to `AuthNotifier.signIn`/`AuthService.signIn`.
  @override
  String get id;

  /// Label rendered on the provider's sign-in button (not localized in
  /// Phase 2 — provider brand names are shown as-is).
  @override
  String get displayLabel;

  /// The GoTrue provider this option resolves to.
  @override
  OAuthProvider get provider;

  /// Create a copy of AuthProviderOption
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AuthProviderOptionImplCopyWith<_$AuthProviderOptionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AuthProviderConfig {
  /// The enabled providers, in display order.
  List<AuthProviderOption> get providers => throw _privateConstructorUsedError;

  /// Create a copy of AuthProviderConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AuthProviderConfigCopyWith<AuthProviderConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuthProviderConfigCopyWith<$Res> {
  factory $AuthProviderConfigCopyWith(
    AuthProviderConfig value,
    $Res Function(AuthProviderConfig) then,
  ) = _$AuthProviderConfigCopyWithImpl<$Res, AuthProviderConfig>;
  @useResult
  $Res call({List<AuthProviderOption> providers});
}

/// @nodoc
class _$AuthProviderConfigCopyWithImpl<$Res, $Val extends AuthProviderConfig>
    implements $AuthProviderConfigCopyWith<$Res> {
  _$AuthProviderConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AuthProviderConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? providers = null}) {
    return _then(
      _value.copyWith(
            providers: null == providers
                ? _value.providers
                : providers // ignore: cast_nullable_to_non_nullable
                      as List<AuthProviderOption>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AuthProviderConfigImplCopyWith<$Res>
    implements $AuthProviderConfigCopyWith<$Res> {
  factory _$$AuthProviderConfigImplCopyWith(
    _$AuthProviderConfigImpl value,
    $Res Function(_$AuthProviderConfigImpl) then,
  ) = __$$AuthProviderConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<AuthProviderOption> providers});
}

/// @nodoc
class __$$AuthProviderConfigImplCopyWithImpl<$Res>
    extends _$AuthProviderConfigCopyWithImpl<$Res, _$AuthProviderConfigImpl>
    implements _$$AuthProviderConfigImplCopyWith<$Res> {
  __$$AuthProviderConfigImplCopyWithImpl(
    _$AuthProviderConfigImpl _value,
    $Res Function(_$AuthProviderConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthProviderConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? providers = null}) {
    return _then(
      _$AuthProviderConfigImpl(
        providers: null == providers
            ? _value._providers
            : providers // ignore: cast_nullable_to_non_nullable
                  as List<AuthProviderOption>,
      ),
    );
  }
}

/// @nodoc

class _$AuthProviderConfigImpl implements _AuthProviderConfig {
  const _$AuthProviderConfigImpl({
    required final List<AuthProviderOption> providers,
  }) : _providers = providers;

  /// The enabled providers, in display order.
  final List<AuthProviderOption> _providers;

  /// The enabled providers, in display order.
  @override
  List<AuthProviderOption> get providers {
    if (_providers is EqualUnmodifiableListView) return _providers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_providers);
  }

  @override
  String toString() {
    return 'AuthProviderConfig(providers: $providers)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AuthProviderConfigImpl &&
            const DeepCollectionEquality().equals(
              other._providers,
              _providers,
            ));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_providers));

  /// Create a copy of AuthProviderConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AuthProviderConfigImplCopyWith<_$AuthProviderConfigImpl> get copyWith =>
      __$$AuthProviderConfigImplCopyWithImpl<_$AuthProviderConfigImpl>(
        this,
        _$identity,
      );
}

abstract class _AuthProviderConfig implements AuthProviderConfig {
  const factory _AuthProviderConfig({
    required final List<AuthProviderOption> providers,
  }) = _$AuthProviderConfigImpl;

  /// The enabled providers, in display order.
  @override
  List<AuthProviderOption> get providers;

  /// Create a copy of AuthProviderConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AuthProviderConfigImplCopyWith<_$AuthProviderConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
