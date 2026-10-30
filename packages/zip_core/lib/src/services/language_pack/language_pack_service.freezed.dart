// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'language_pack_service.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$LanguagePackInfo {
  /// The model's state.
  LanguagePackStatus get status => throw _privateConstructorUsedError;

  /// The language's name in the app's language, from the platform (Flutter
  /// has no locale display names). The locale tag when the platform gave
  /// none.
  String get displayName => throw _privateConstructorUsedError;

  /// Create a copy of LanguagePackInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LanguagePackInfoCopyWith<LanguagePackInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LanguagePackInfoCopyWith<$Res> {
  factory $LanguagePackInfoCopyWith(
    LanguagePackInfo value,
    $Res Function(LanguagePackInfo) then,
  ) = _$LanguagePackInfoCopyWithImpl<$Res, LanguagePackInfo>;
  @useResult
  $Res call({LanguagePackStatus status, String displayName});
}

/// @nodoc
class _$LanguagePackInfoCopyWithImpl<$Res, $Val extends LanguagePackInfo>
    implements $LanguagePackInfoCopyWith<$Res> {
  _$LanguagePackInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LanguagePackInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? status = null, Object? displayName = null}) {
    return _then(
      _value.copyWith(
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as LanguagePackStatus,
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
abstract class _$$LanguagePackInfoImplCopyWith<$Res>
    implements $LanguagePackInfoCopyWith<$Res> {
  factory _$$LanguagePackInfoImplCopyWith(
    _$LanguagePackInfoImpl value,
    $Res Function(_$LanguagePackInfoImpl) then,
  ) = __$$LanguagePackInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({LanguagePackStatus status, String displayName});
}

/// @nodoc
class __$$LanguagePackInfoImplCopyWithImpl<$Res>
    extends _$LanguagePackInfoCopyWithImpl<$Res, _$LanguagePackInfoImpl>
    implements _$$LanguagePackInfoImplCopyWith<$Res> {
  __$$LanguagePackInfoImplCopyWithImpl(
    _$LanguagePackInfoImpl _value,
    $Res Function(_$LanguagePackInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LanguagePackInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? status = null, Object? displayName = null}) {
    return _then(
      _$LanguagePackInfoImpl(
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as LanguagePackStatus,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$LanguagePackInfoImpl implements _LanguagePackInfo {
  const _$LanguagePackInfoImpl({
    required this.status,
    required this.displayName,
  });

  /// The model's state.
  @override
  final LanguagePackStatus status;

  /// The language's name in the app's language, from the platform (Flutter
  /// has no locale display names). The locale tag when the platform gave
  /// none.
  @override
  final String displayName;

  @override
  String toString() {
    return 'LanguagePackInfo(status: $status, displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LanguagePackInfoImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, displayName);

  /// Create a copy of LanguagePackInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LanguagePackInfoImplCopyWith<_$LanguagePackInfoImpl> get copyWith =>
      __$$LanguagePackInfoImplCopyWithImpl<_$LanguagePackInfoImpl>(
        this,
        _$identity,
      );
}

abstract class _LanguagePackInfo implements LanguagePackInfo {
  const factory _LanguagePackInfo({
    required final LanguagePackStatus status,
    required final String displayName,
  }) = _$LanguagePackInfoImpl;

  /// The model's state.
  @override
  LanguagePackStatus get status;

  /// The language's name in the app's language, from the platform (Flutter
  /// has no locale display names). The locale tag when the platform gave
  /// none.
  @override
  String get displayName;

  /// Create a copy of LanguagePackInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LanguagePackInfoImplCopyWith<_$LanguagePackInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
