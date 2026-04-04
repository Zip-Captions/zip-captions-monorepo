// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sherpa_model_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SherpaModelInfo _$SherpaModelInfoFromJson(Map<String, dynamic> json) {
  return _SherpaModelInfo.fromJson(json);
}

/// @nodoc
mixin _$SherpaModelInfo {
  /// The catalog entry for this model.
  SherpaModelCatalogEntry get catalogEntry =>
      throw _privateConstructorUsedError;

  /// Whether the model archive has been downloaded and extracted.
  bool get isDownloaded => throw _privateConstructorUsedError;

  /// Local filesystem path to the extracted model directory.
  /// Non-null only when [isDownloaded] is true.
  String? get localPath => throw _privateConstructorUsedError;

  /// Serializes this SherpaModelInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SherpaModelInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SherpaModelInfoCopyWith<SherpaModelInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SherpaModelInfoCopyWith<$Res> {
  factory $SherpaModelInfoCopyWith(
    SherpaModelInfo value,
    $Res Function(SherpaModelInfo) then,
  ) = _$SherpaModelInfoCopyWithImpl<$Res, SherpaModelInfo>;
  @useResult
  $Res call({
    SherpaModelCatalogEntry catalogEntry,
    bool isDownloaded,
    String? localPath,
  });

  $SherpaModelCatalogEntryCopyWith<$Res> get catalogEntry;
}

/// @nodoc
class _$SherpaModelInfoCopyWithImpl<$Res, $Val extends SherpaModelInfo>
    implements $SherpaModelInfoCopyWith<$Res> {
  _$SherpaModelInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SherpaModelInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? catalogEntry = null,
    Object? isDownloaded = null,
    Object? localPath = freezed,
  }) {
    return _then(
      _value.copyWith(
            catalogEntry: null == catalogEntry
                ? _value.catalogEntry
                : catalogEntry // ignore: cast_nullable_to_non_nullable
                      as SherpaModelCatalogEntry,
            isDownloaded: null == isDownloaded
                ? _value.isDownloaded
                : isDownloaded // ignore: cast_nullable_to_non_nullable
                      as bool,
            localPath: freezed == localPath
                ? _value.localPath
                : localPath // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of SherpaModelInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SherpaModelCatalogEntryCopyWith<$Res> get catalogEntry {
    return $SherpaModelCatalogEntryCopyWith<$Res>(_value.catalogEntry, (value) {
      return _then(_value.copyWith(catalogEntry: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SherpaModelInfoImplCopyWith<$Res>
    implements $SherpaModelInfoCopyWith<$Res> {
  factory _$$SherpaModelInfoImplCopyWith(
    _$SherpaModelInfoImpl value,
    $Res Function(_$SherpaModelInfoImpl) then,
  ) = __$$SherpaModelInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    SherpaModelCatalogEntry catalogEntry,
    bool isDownloaded,
    String? localPath,
  });

  @override
  $SherpaModelCatalogEntryCopyWith<$Res> get catalogEntry;
}

/// @nodoc
class __$$SherpaModelInfoImplCopyWithImpl<$Res>
    extends _$SherpaModelInfoCopyWithImpl<$Res, _$SherpaModelInfoImpl>
    implements _$$SherpaModelInfoImplCopyWith<$Res> {
  __$$SherpaModelInfoImplCopyWithImpl(
    _$SherpaModelInfoImpl _value,
    $Res Function(_$SherpaModelInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SherpaModelInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? catalogEntry = null,
    Object? isDownloaded = null,
    Object? localPath = freezed,
  }) {
    return _then(
      _$SherpaModelInfoImpl(
        catalogEntry: null == catalogEntry
            ? _value.catalogEntry
            : catalogEntry // ignore: cast_nullable_to_non_nullable
                  as SherpaModelCatalogEntry,
        isDownloaded: null == isDownloaded
            ? _value.isDownloaded
            : isDownloaded // ignore: cast_nullable_to_non_nullable
                  as bool,
        localPath: freezed == localPath
            ? _value.localPath
            : localPath // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SherpaModelInfoImpl implements _SherpaModelInfo {
  const _$SherpaModelInfoImpl({
    required this.catalogEntry,
    this.isDownloaded = false,
    this.localPath,
  });

  factory _$SherpaModelInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$SherpaModelInfoImplFromJson(json);

  /// The catalog entry for this model.
  @override
  final SherpaModelCatalogEntry catalogEntry;

  /// Whether the model archive has been downloaded and extracted.
  @override
  @JsonKey()
  final bool isDownloaded;

  /// Local filesystem path to the extracted model directory.
  /// Non-null only when [isDownloaded] is true.
  @override
  final String? localPath;

  @override
  String toString() {
    return 'SherpaModelInfo(catalogEntry: $catalogEntry, isDownloaded: $isDownloaded, localPath: $localPath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SherpaModelInfoImpl &&
            (identical(other.catalogEntry, catalogEntry) ||
                other.catalogEntry == catalogEntry) &&
            (identical(other.isDownloaded, isDownloaded) ||
                other.isDownloaded == isDownloaded) &&
            (identical(other.localPath, localPath) ||
                other.localPath == localPath));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, catalogEntry, isDownloaded, localPath);

  /// Create a copy of SherpaModelInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SherpaModelInfoImplCopyWith<_$SherpaModelInfoImpl> get copyWith =>
      __$$SherpaModelInfoImplCopyWithImpl<_$SherpaModelInfoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SherpaModelInfoImplToJson(this);
  }
}

abstract class _SherpaModelInfo implements SherpaModelInfo {
  const factory _SherpaModelInfo({
    required final SherpaModelCatalogEntry catalogEntry,
    final bool isDownloaded,
    final String? localPath,
  }) = _$SherpaModelInfoImpl;

  factory _SherpaModelInfo.fromJson(Map<String, dynamic> json) =
      _$SherpaModelInfoImpl.fromJson;

  /// The catalog entry for this model.
  @override
  SherpaModelCatalogEntry get catalogEntry;

  /// Whether the model archive has been downloaded and extracted.
  @override
  bool get isDownloaded;

  /// Local filesystem path to the extracted model directory.
  /// Non-null only when [isDownloaded] is true.
  @override
  String? get localPath;

  /// Create a copy of SherpaModelInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SherpaModelInfoImplCopyWith<_$SherpaModelInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
