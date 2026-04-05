// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sherpa_model_download_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SherpaModelDownloadProgress _$SherpaModelDownloadProgressFromJson(
  Map<String, dynamic> json,
) {
  return _SherpaModelDownloadProgress.fromJson(json);
}

/// @nodoc
mixin _$SherpaModelDownloadProgress {
  /// The model being downloaded.
  String get modelId => throw _privateConstructorUsedError;

  /// Bytes downloaded so far (including any resumed bytes).
  int get downloadedBytes => throw _privateConstructorUsedError;

  /// Total bytes expected for the complete download.
  int get totalBytes => throw _privateConstructorUsedError;

  /// Serializes this SherpaModelDownloadProgress to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SherpaModelDownloadProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SherpaModelDownloadProgressCopyWith<SherpaModelDownloadProgress>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SherpaModelDownloadProgressCopyWith<$Res> {
  factory $SherpaModelDownloadProgressCopyWith(
    SherpaModelDownloadProgress value,
    $Res Function(SherpaModelDownloadProgress) then,
  ) =
      _$SherpaModelDownloadProgressCopyWithImpl<
        $Res,
        SherpaModelDownloadProgress
      >;
  @useResult
  $Res call({String modelId, int downloadedBytes, int totalBytes});
}

/// @nodoc
class _$SherpaModelDownloadProgressCopyWithImpl<
  $Res,
  $Val extends SherpaModelDownloadProgress
>
    implements $SherpaModelDownloadProgressCopyWith<$Res> {
  _$SherpaModelDownloadProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SherpaModelDownloadProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? modelId = null,
    Object? downloadedBytes = null,
    Object? totalBytes = null,
  }) {
    return _then(
      _value.copyWith(
            modelId: null == modelId
                ? _value.modelId
                : modelId // ignore: cast_nullable_to_non_nullable
                      as String,
            downloadedBytes: null == downloadedBytes
                ? _value.downloadedBytes
                : downloadedBytes // ignore: cast_nullable_to_non_nullable
                      as int,
            totalBytes: null == totalBytes
                ? _value.totalBytes
                : totalBytes // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SherpaModelDownloadProgressImplCopyWith<$Res>
    implements $SherpaModelDownloadProgressCopyWith<$Res> {
  factory _$$SherpaModelDownloadProgressImplCopyWith(
    _$SherpaModelDownloadProgressImpl value,
    $Res Function(_$SherpaModelDownloadProgressImpl) then,
  ) = __$$SherpaModelDownloadProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String modelId, int downloadedBytes, int totalBytes});
}

/// @nodoc
class __$$SherpaModelDownloadProgressImplCopyWithImpl<$Res>
    extends
        _$SherpaModelDownloadProgressCopyWithImpl<
          $Res,
          _$SherpaModelDownloadProgressImpl
        >
    implements _$$SherpaModelDownloadProgressImplCopyWith<$Res> {
  __$$SherpaModelDownloadProgressImplCopyWithImpl(
    _$SherpaModelDownloadProgressImpl _value,
    $Res Function(_$SherpaModelDownloadProgressImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SherpaModelDownloadProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? modelId = null,
    Object? downloadedBytes = null,
    Object? totalBytes = null,
  }) {
    return _then(
      _$SherpaModelDownloadProgressImpl(
        modelId: null == modelId
            ? _value.modelId
            : modelId // ignore: cast_nullable_to_non_nullable
                  as String,
        downloadedBytes: null == downloadedBytes
            ? _value.downloadedBytes
            : downloadedBytes // ignore: cast_nullable_to_non_nullable
                  as int,
        totalBytes: null == totalBytes
            ? _value.totalBytes
            : totalBytes // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SherpaModelDownloadProgressImpl
    implements _SherpaModelDownloadProgress {
  const _$SherpaModelDownloadProgressImpl({
    required this.modelId,
    required this.downloadedBytes,
    required this.totalBytes,
  });

  factory _$SherpaModelDownloadProgressImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$SherpaModelDownloadProgressImplFromJson(json);

  /// The model being downloaded.
  @override
  final String modelId;

  /// Bytes downloaded so far (including any resumed bytes).
  @override
  final int downloadedBytes;

  /// Total bytes expected for the complete download.
  @override
  final int totalBytes;

  @override
  String toString() {
    return 'SherpaModelDownloadProgress(modelId: $modelId, downloadedBytes: $downloadedBytes, totalBytes: $totalBytes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SherpaModelDownloadProgressImpl &&
            (identical(other.modelId, modelId) || other.modelId == modelId) &&
            (identical(other.downloadedBytes, downloadedBytes) ||
                other.downloadedBytes == downloadedBytes) &&
            (identical(other.totalBytes, totalBytes) ||
                other.totalBytes == totalBytes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, modelId, downloadedBytes, totalBytes);

  /// Create a copy of SherpaModelDownloadProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SherpaModelDownloadProgressImplCopyWith<_$SherpaModelDownloadProgressImpl>
  get copyWith =>
      __$$SherpaModelDownloadProgressImplCopyWithImpl<
        _$SherpaModelDownloadProgressImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SherpaModelDownloadProgressImplToJson(this);
  }
}

abstract class _SherpaModelDownloadProgress
    implements SherpaModelDownloadProgress {
  const factory _SherpaModelDownloadProgress({
    required final String modelId,
    required final int downloadedBytes,
    required final int totalBytes,
  }) = _$SherpaModelDownloadProgressImpl;

  factory _SherpaModelDownloadProgress.fromJson(Map<String, dynamic> json) =
      _$SherpaModelDownloadProgressImpl.fromJson;

  /// The model being downloaded.
  @override
  String get modelId;

  /// Bytes downloaded so far (including any resumed bytes).
  @override
  int get downloadedBytes;

  /// Total bytes expected for the complete download.
  @override
  int get totalBytes;

  /// Create a copy of SherpaModelDownloadProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SherpaModelDownloadProgressImplCopyWith<_$SherpaModelDownloadProgressImpl>
  get copyWith => throw _privateConstructorUsedError;
}
