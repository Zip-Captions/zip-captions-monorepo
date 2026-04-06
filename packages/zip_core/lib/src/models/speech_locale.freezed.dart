// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'speech_locale.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SpeechLocale {
  /// Locale identifier as reported by the STT engine. May be language-only
  /// (e.g., `en`), language-region (e.g., `en-US`), or engine-specific.
  String get localeId => throw _privateConstructorUsedError;

  /// Human-readable name in the user's current display locale.
  String get displayName => throw _privateConstructorUsedError;

  /// Create a copy of SpeechLocale
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SpeechLocaleCopyWith<SpeechLocale> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SpeechLocaleCopyWith<$Res> {
  factory $SpeechLocaleCopyWith(
    SpeechLocale value,
    $Res Function(SpeechLocale) then,
  ) = _$SpeechLocaleCopyWithImpl<$Res, SpeechLocale>;
  @useResult
  $Res call({String localeId, String displayName});
}

/// @nodoc
class _$SpeechLocaleCopyWithImpl<$Res, $Val extends SpeechLocale>
    implements $SpeechLocaleCopyWith<$Res> {
  _$SpeechLocaleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SpeechLocale
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? localeId = null, Object? displayName = null}) {
    return _then(
      _value.copyWith(
            localeId: null == localeId
                ? _value.localeId
                : localeId // ignore: cast_nullable_to_non_nullable
                      as String,
            displayName: null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SpeechLocaleImplCopyWith<$Res>
    implements $SpeechLocaleCopyWith<$Res> {
  factory _$$SpeechLocaleImplCopyWith(
    _$SpeechLocaleImpl value,
    $Res Function(_$SpeechLocaleImpl) then,
  ) = __$$SpeechLocaleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String localeId, String displayName});
}

/// @nodoc
class __$$SpeechLocaleImplCopyWithImpl<$Res>
    extends _$SpeechLocaleCopyWithImpl<$Res, _$SpeechLocaleImpl>
    implements _$$SpeechLocaleImplCopyWith<$Res> {
  __$$SpeechLocaleImplCopyWithImpl(
    _$SpeechLocaleImpl _value,
    $Res Function(_$SpeechLocaleImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SpeechLocale
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? localeId = null, Object? displayName = null}) {
    return _then(
      _$SpeechLocaleImpl(
        localeId: null == localeId
            ? _value.localeId
            : localeId // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$SpeechLocaleImpl extends _SpeechLocale {
  const _$SpeechLocaleImpl({required this.localeId, required this.displayName})
    : super._();

  /// Locale identifier as reported by the STT engine. May be language-only
  /// (e.g., `en`), language-region (e.g., `en-US`), or engine-specific.
  @override
  final String localeId;

  /// Human-readable name in the user's current display locale.
  @override
  final String displayName;

  @override
  String toString() {
    return 'SpeechLocale(localeId: $localeId, displayName: $displayName)';
  }

  /// Create a copy of SpeechLocale
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SpeechLocaleImplCopyWith<_$SpeechLocaleImpl> get copyWith =>
      __$$SpeechLocaleImplCopyWithImpl<_$SpeechLocaleImpl>(this, _$identity);
}

abstract class _SpeechLocale extends SpeechLocale {
  const factory _SpeechLocale({
    required final String localeId,
    required final String displayName,
  }) = _$SpeechLocaleImpl;
  const _SpeechLocale._() : super._();

  /// Locale identifier as reported by the STT engine. May be language-only
  /// (e.g., `en`), language-region (e.g., `en-US`), or engine-specific.
  @override
  String get localeId;

  /// Human-readable name in the user's current display locale.
  @override
  String get displayName;

  /// Create a copy of SpeechLocale
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SpeechLocaleImplCopyWith<_$SpeechLocaleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
