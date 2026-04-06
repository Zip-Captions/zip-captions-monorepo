// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sherpa_model_catalog.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SherpaModelCatalogResponse _$SherpaModelCatalogResponseFromJson(
  Map<String, dynamic> json,
) {
  return _SherpaModelCatalogResponse.fromJson(json);
}

/// @nodoc
mixin _$SherpaModelCatalogResponse {
  /// Schema version for forward compatibility.
  int get schemaVersion => throw _privateConstructorUsedError;

  /// Available models in the catalog.
  List<SherpaModelCatalogEntry> get models =>
      throw _privateConstructorUsedError;

  /// Serializes this SherpaModelCatalogResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SherpaModelCatalogResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SherpaModelCatalogResponseCopyWith<SherpaModelCatalogResponse>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SherpaModelCatalogResponseCopyWith<$Res> {
  factory $SherpaModelCatalogResponseCopyWith(
    SherpaModelCatalogResponse value,
    $Res Function(SherpaModelCatalogResponse) then,
  ) =
      _$SherpaModelCatalogResponseCopyWithImpl<
        $Res,
        SherpaModelCatalogResponse
      >;
  @useResult
  $Res call({int schemaVersion, List<SherpaModelCatalogEntry> models});
}

/// @nodoc
class _$SherpaModelCatalogResponseCopyWithImpl<
  $Res,
  $Val extends SherpaModelCatalogResponse
>
    implements $SherpaModelCatalogResponseCopyWith<$Res> {
  _$SherpaModelCatalogResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SherpaModelCatalogResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? schemaVersion = null, Object? models = null}) {
    return _then(
      _value.copyWith(
            schemaVersion: null == schemaVersion
                ? _value.schemaVersion
                : schemaVersion // ignore: cast_nullable_to_non_nullable
                      as int,
            models: null == models
                ? _value.models
                : models // ignore: cast_nullable_to_non_nullable
                      as List<SherpaModelCatalogEntry>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SherpaModelCatalogResponseImplCopyWith<$Res>
    implements $SherpaModelCatalogResponseCopyWith<$Res> {
  factory _$$SherpaModelCatalogResponseImplCopyWith(
    _$SherpaModelCatalogResponseImpl value,
    $Res Function(_$SherpaModelCatalogResponseImpl) then,
  ) = __$$SherpaModelCatalogResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int schemaVersion, List<SherpaModelCatalogEntry> models});
}

/// @nodoc
class __$$SherpaModelCatalogResponseImplCopyWithImpl<$Res>
    extends
        _$SherpaModelCatalogResponseCopyWithImpl<
          $Res,
          _$SherpaModelCatalogResponseImpl
        >
    implements _$$SherpaModelCatalogResponseImplCopyWith<$Res> {
  __$$SherpaModelCatalogResponseImplCopyWithImpl(
    _$SherpaModelCatalogResponseImpl _value,
    $Res Function(_$SherpaModelCatalogResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SherpaModelCatalogResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? schemaVersion = null, Object? models = null}) {
    return _then(
      _$SherpaModelCatalogResponseImpl(
        schemaVersion: null == schemaVersion
            ? _value.schemaVersion
            : schemaVersion // ignore: cast_nullable_to_non_nullable
                  as int,
        models: null == models
            ? _value._models
            : models // ignore: cast_nullable_to_non_nullable
                  as List<SherpaModelCatalogEntry>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SherpaModelCatalogResponseImpl implements _SherpaModelCatalogResponse {
  const _$SherpaModelCatalogResponseImpl({
    this.schemaVersion = 1,
    final List<SherpaModelCatalogEntry> models = const [],
  }) : _models = models;

  factory _$SherpaModelCatalogResponseImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$SherpaModelCatalogResponseImplFromJson(json);

  /// Schema version for forward compatibility.
  @override
  @JsonKey()
  final int schemaVersion;

  /// Available models in the catalog.
  final List<SherpaModelCatalogEntry> _models;

  /// Available models in the catalog.
  @override
  @JsonKey()
  List<SherpaModelCatalogEntry> get models {
    if (_models is EqualUnmodifiableListView) return _models;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_models);
  }

  @override
  String toString() {
    return 'SherpaModelCatalogResponse(schemaVersion: $schemaVersion, models: $models)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SherpaModelCatalogResponseImpl &&
            (identical(other.schemaVersion, schemaVersion) ||
                other.schemaVersion == schemaVersion) &&
            const DeepCollectionEquality().equals(other._models, _models));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    schemaVersion,
    const DeepCollectionEquality().hash(_models),
  );

  /// Create a copy of SherpaModelCatalogResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SherpaModelCatalogResponseImplCopyWith<_$SherpaModelCatalogResponseImpl>
  get copyWith =>
      __$$SherpaModelCatalogResponseImplCopyWithImpl<
        _$SherpaModelCatalogResponseImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SherpaModelCatalogResponseImplToJson(this);
  }
}

abstract class _SherpaModelCatalogResponse
    implements SherpaModelCatalogResponse {
  const factory _SherpaModelCatalogResponse({
    final int schemaVersion,
    final List<SherpaModelCatalogEntry> models,
  }) = _$SherpaModelCatalogResponseImpl;

  factory _SherpaModelCatalogResponse.fromJson(Map<String, dynamic> json) =
      _$SherpaModelCatalogResponseImpl.fromJson;

  /// Schema version for forward compatibility.
  @override
  int get schemaVersion;

  /// Available models in the catalog.
  @override
  List<SherpaModelCatalogEntry> get models;

  /// Create a copy of SherpaModelCatalogResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SherpaModelCatalogResponseImplCopyWith<_$SherpaModelCatalogResponseImpl>
  get copyWith => throw _privateConstructorUsedError;
}

SherpaModelCatalogEntry _$SherpaModelCatalogEntryFromJson(
  Map<String, dynamic> json,
) {
  return _SherpaModelCatalogEntry.fromJson(json);
}

/// @nodoc
mixin _$SherpaModelCatalogEntry {
  /// Unique model identifier.
  String get modelId => throw _privateConstructorUsedError;

  /// Human-readable model name for UI display.
  String get displayName => throw _privateConstructorUsedError;

  /// BCP-47 locale that this model primarily supports.
  String get primaryLocaleId => throw _privateConstructorUsedError;

  /// Size of the model archive in bytes.
  int get downloadSizeBytes => throw _privateConstructorUsedError;

  /// HTTPS URL for the model archive download.
  String get downloadUrl => throw _privateConstructorUsedError;

  /// Expected SHA-256 hex digest of the downloaded archive.
  String get sha256Checksum => throw _privateConstructorUsedError;

  /// Serializes this SherpaModelCatalogEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SherpaModelCatalogEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SherpaModelCatalogEntryCopyWith<SherpaModelCatalogEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SherpaModelCatalogEntryCopyWith<$Res> {
  factory $SherpaModelCatalogEntryCopyWith(
    SherpaModelCatalogEntry value,
    $Res Function(SherpaModelCatalogEntry) then,
  ) = _$SherpaModelCatalogEntryCopyWithImpl<$Res, SherpaModelCatalogEntry>;
  @useResult
  $Res call({
    String modelId,
    String displayName,
    String primaryLocaleId,
    int downloadSizeBytes,
    String downloadUrl,
    String sha256Checksum,
  });
}

/// @nodoc
class _$SherpaModelCatalogEntryCopyWithImpl<
  $Res,
  $Val extends SherpaModelCatalogEntry
>
    implements $SherpaModelCatalogEntryCopyWith<$Res> {
  _$SherpaModelCatalogEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SherpaModelCatalogEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? modelId = null,
    Object? displayName = null,
    Object? primaryLocaleId = null,
    Object? downloadSizeBytes = null,
    Object? downloadUrl = null,
    Object? sha256Checksum = null,
  }) {
    return _then(
      _value.copyWith(
            modelId: null == modelId
                ? _value.modelId
                : modelId // ignore: cast_nullable_to_non_nullable
                      as String,
            displayName: null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String,
            primaryLocaleId: null == primaryLocaleId
                ? _value.primaryLocaleId
                : primaryLocaleId // ignore: cast_nullable_to_non_nullable
                      as String,
            downloadSizeBytes: null == downloadSizeBytes
                ? _value.downloadSizeBytes
                : downloadSizeBytes // ignore: cast_nullable_to_non_nullable
                      as int,
            downloadUrl: null == downloadUrl
                ? _value.downloadUrl
                : downloadUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            sha256Checksum: null == sha256Checksum
                ? _value.sha256Checksum
                : sha256Checksum // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SherpaModelCatalogEntryImplCopyWith<$Res>
    implements $SherpaModelCatalogEntryCopyWith<$Res> {
  factory _$$SherpaModelCatalogEntryImplCopyWith(
    _$SherpaModelCatalogEntryImpl value,
    $Res Function(_$SherpaModelCatalogEntryImpl) then,
  ) = __$$SherpaModelCatalogEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String modelId,
    String displayName,
    String primaryLocaleId,
    int downloadSizeBytes,
    String downloadUrl,
    String sha256Checksum,
  });
}

/// @nodoc
class __$$SherpaModelCatalogEntryImplCopyWithImpl<$Res>
    extends
        _$SherpaModelCatalogEntryCopyWithImpl<
          $Res,
          _$SherpaModelCatalogEntryImpl
        >
    implements _$$SherpaModelCatalogEntryImplCopyWith<$Res> {
  __$$SherpaModelCatalogEntryImplCopyWithImpl(
    _$SherpaModelCatalogEntryImpl _value,
    $Res Function(_$SherpaModelCatalogEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SherpaModelCatalogEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? modelId = null,
    Object? displayName = null,
    Object? primaryLocaleId = null,
    Object? downloadSizeBytes = null,
    Object? downloadUrl = null,
    Object? sha256Checksum = null,
  }) {
    return _then(
      _$SherpaModelCatalogEntryImpl(
        modelId: null == modelId
            ? _value.modelId
            : modelId // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        primaryLocaleId: null == primaryLocaleId
            ? _value.primaryLocaleId
            : primaryLocaleId // ignore: cast_nullable_to_non_nullable
                  as String,
        downloadSizeBytes: null == downloadSizeBytes
            ? _value.downloadSizeBytes
            : downloadSizeBytes // ignore: cast_nullable_to_non_nullable
                  as int,
        downloadUrl: null == downloadUrl
            ? _value.downloadUrl
            : downloadUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        sha256Checksum: null == sha256Checksum
            ? _value.sha256Checksum
            : sha256Checksum // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SherpaModelCatalogEntryImpl implements _SherpaModelCatalogEntry {
  const _$SherpaModelCatalogEntryImpl({
    required this.modelId,
    required this.displayName,
    required this.primaryLocaleId,
    required this.downloadSizeBytes,
    required this.downloadUrl,
    required this.sha256Checksum,
  });

  factory _$SherpaModelCatalogEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$SherpaModelCatalogEntryImplFromJson(json);

  /// Unique model identifier.
  @override
  final String modelId;

  /// Human-readable model name for UI display.
  @override
  final String displayName;

  /// BCP-47 locale that this model primarily supports.
  @override
  final String primaryLocaleId;

  /// Size of the model archive in bytes.
  @override
  final int downloadSizeBytes;

  /// HTTPS URL for the model archive download.
  @override
  final String downloadUrl;

  /// Expected SHA-256 hex digest of the downloaded archive.
  @override
  final String sha256Checksum;

  @override
  String toString() {
    return 'SherpaModelCatalogEntry(modelId: $modelId, displayName: $displayName, primaryLocaleId: $primaryLocaleId, downloadSizeBytes: $downloadSizeBytes, downloadUrl: $downloadUrl, sha256Checksum: $sha256Checksum)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SherpaModelCatalogEntryImpl &&
            (identical(other.modelId, modelId) || other.modelId == modelId) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.primaryLocaleId, primaryLocaleId) ||
                other.primaryLocaleId == primaryLocaleId) &&
            (identical(other.downloadSizeBytes, downloadSizeBytes) ||
                other.downloadSizeBytes == downloadSizeBytes) &&
            (identical(other.downloadUrl, downloadUrl) ||
                other.downloadUrl == downloadUrl) &&
            (identical(other.sha256Checksum, sha256Checksum) ||
                other.sha256Checksum == sha256Checksum));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    modelId,
    displayName,
    primaryLocaleId,
    downloadSizeBytes,
    downloadUrl,
    sha256Checksum,
  );

  /// Create a copy of SherpaModelCatalogEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SherpaModelCatalogEntryImplCopyWith<_$SherpaModelCatalogEntryImpl>
  get copyWith =>
      __$$SherpaModelCatalogEntryImplCopyWithImpl<
        _$SherpaModelCatalogEntryImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SherpaModelCatalogEntryImplToJson(this);
  }
}

abstract class _SherpaModelCatalogEntry implements SherpaModelCatalogEntry {
  const factory _SherpaModelCatalogEntry({
    required final String modelId,
    required final String displayName,
    required final String primaryLocaleId,
    required final int downloadSizeBytes,
    required final String downloadUrl,
    required final String sha256Checksum,
  }) = _$SherpaModelCatalogEntryImpl;

  factory _SherpaModelCatalogEntry.fromJson(Map<String, dynamic> json) =
      _$SherpaModelCatalogEntryImpl.fromJson;

  /// Unique model identifier.
  @override
  String get modelId;

  /// Human-readable model name for UI display.
  @override
  String get displayName;

  /// BCP-47 locale that this model primarily supports.
  @override
  String get primaryLocaleId;

  /// Size of the model archive in bytes.
  @override
  int get downloadSizeBytes;

  /// HTTPS URL for the model archive download.
  @override
  String get downloadUrl;

  /// Expected SHA-256 hex digest of the downloaded archive.
  @override
  String get sha256Checksum;

  /// Create a copy of SherpaModelCatalogEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SherpaModelCatalogEntryImplCopyWith<_$SherpaModelCatalogEntryImpl>
  get copyWith => throw _privateConstructorUsedError;
}
