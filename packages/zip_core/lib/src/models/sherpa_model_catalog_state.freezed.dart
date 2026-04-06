// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sherpa_model_catalog_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SherpaModelCatalogState {
  /// Full catalog: downloaded + available to download.
  List<SherpaModelInfo> get models => throw _privateConstructorUsedError;

  /// In-progress downloads keyed by modelId.
  Map<String, SherpaModelDownloadProgress> get activeDownloads =>
      throw _privateConstructorUsedError;

  /// Model ID of the last download that failed, if any.
  String? get lastFailedDownloadId => throw _privateConstructorUsedError;

  /// Model ID awaiting user confirmation before download (> 100MB).
  String? get pendingConfirmationModelId => throw _privateConstructorUsedError;

  /// Create a copy of SherpaModelCatalogState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SherpaModelCatalogStateCopyWith<SherpaModelCatalogState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SherpaModelCatalogStateCopyWith<$Res> {
  factory $SherpaModelCatalogStateCopyWith(
    SherpaModelCatalogState value,
    $Res Function(SherpaModelCatalogState) then,
  ) = _$SherpaModelCatalogStateCopyWithImpl<$Res, SherpaModelCatalogState>;
  @useResult
  $Res call({
    List<SherpaModelInfo> models,
    Map<String, SherpaModelDownloadProgress> activeDownloads,
    String? lastFailedDownloadId,
    String? pendingConfirmationModelId,
  });
}

/// @nodoc
class _$SherpaModelCatalogStateCopyWithImpl<
  $Res,
  $Val extends SherpaModelCatalogState
>
    implements $SherpaModelCatalogStateCopyWith<$Res> {
  _$SherpaModelCatalogStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SherpaModelCatalogState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? models = null,
    Object? activeDownloads = null,
    Object? lastFailedDownloadId = freezed,
    Object? pendingConfirmationModelId = freezed,
  }) {
    return _then(
      _value.copyWith(
            models: null == models
                ? _value.models
                : models // ignore: cast_nullable_to_non_nullable
                      as List<SherpaModelInfo>,
            activeDownloads: null == activeDownloads
                ? _value.activeDownloads
                : activeDownloads // ignore: cast_nullable_to_non_nullable
                      as Map<String, SherpaModelDownloadProgress>,
            lastFailedDownloadId: freezed == lastFailedDownloadId
                ? _value.lastFailedDownloadId
                : lastFailedDownloadId // ignore: cast_nullable_to_non_nullable
                      as String?,
            pendingConfirmationModelId: freezed == pendingConfirmationModelId
                ? _value.pendingConfirmationModelId
                : pendingConfirmationModelId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SherpaModelCatalogStateImplCopyWith<$Res>
    implements $SherpaModelCatalogStateCopyWith<$Res> {
  factory _$$SherpaModelCatalogStateImplCopyWith(
    _$SherpaModelCatalogStateImpl value,
    $Res Function(_$SherpaModelCatalogStateImpl) then,
  ) = __$$SherpaModelCatalogStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<SherpaModelInfo> models,
    Map<String, SherpaModelDownloadProgress> activeDownloads,
    String? lastFailedDownloadId,
    String? pendingConfirmationModelId,
  });
}

/// @nodoc
class __$$SherpaModelCatalogStateImplCopyWithImpl<$Res>
    extends
        _$SherpaModelCatalogStateCopyWithImpl<
          $Res,
          _$SherpaModelCatalogStateImpl
        >
    implements _$$SherpaModelCatalogStateImplCopyWith<$Res> {
  __$$SherpaModelCatalogStateImplCopyWithImpl(
    _$SherpaModelCatalogStateImpl _value,
    $Res Function(_$SherpaModelCatalogStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SherpaModelCatalogState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? models = null,
    Object? activeDownloads = null,
    Object? lastFailedDownloadId = freezed,
    Object? pendingConfirmationModelId = freezed,
  }) {
    return _then(
      _$SherpaModelCatalogStateImpl(
        models: null == models
            ? _value._models
            : models // ignore: cast_nullable_to_non_nullable
                  as List<SherpaModelInfo>,
        activeDownloads: null == activeDownloads
            ? _value._activeDownloads
            : activeDownloads // ignore: cast_nullable_to_non_nullable
                  as Map<String, SherpaModelDownloadProgress>,
        lastFailedDownloadId: freezed == lastFailedDownloadId
            ? _value.lastFailedDownloadId
            : lastFailedDownloadId // ignore: cast_nullable_to_non_nullable
                  as String?,
        pendingConfirmationModelId: freezed == pendingConfirmationModelId
            ? _value.pendingConfirmationModelId
            : pendingConfirmationModelId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$SherpaModelCatalogStateImpl implements _SherpaModelCatalogState {
  const _$SherpaModelCatalogStateImpl({
    final List<SherpaModelInfo> models = const [],
    final Map<String, SherpaModelDownloadProgress> activeDownloads = const {},
    this.lastFailedDownloadId,
    this.pendingConfirmationModelId,
  }) : _models = models,
       _activeDownloads = activeDownloads;

  /// Full catalog: downloaded + available to download.
  final List<SherpaModelInfo> _models;

  /// Full catalog: downloaded + available to download.
  @override
  @JsonKey()
  List<SherpaModelInfo> get models {
    if (_models is EqualUnmodifiableListView) return _models;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_models);
  }

  /// In-progress downloads keyed by modelId.
  final Map<String, SherpaModelDownloadProgress> _activeDownloads;

  /// In-progress downloads keyed by modelId.
  @override
  @JsonKey()
  Map<String, SherpaModelDownloadProgress> get activeDownloads {
    if (_activeDownloads is EqualUnmodifiableMapView) return _activeDownloads;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_activeDownloads);
  }

  /// Model ID of the last download that failed, if any.
  @override
  final String? lastFailedDownloadId;

  /// Model ID awaiting user confirmation before download (> 100MB).
  @override
  final String? pendingConfirmationModelId;

  @override
  String toString() {
    return 'SherpaModelCatalogState(models: $models, activeDownloads: $activeDownloads, lastFailedDownloadId: $lastFailedDownloadId, pendingConfirmationModelId: $pendingConfirmationModelId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SherpaModelCatalogStateImpl &&
            const DeepCollectionEquality().equals(other._models, _models) &&
            const DeepCollectionEquality().equals(
              other._activeDownloads,
              _activeDownloads,
            ) &&
            (identical(other.lastFailedDownloadId, lastFailedDownloadId) ||
                other.lastFailedDownloadId == lastFailedDownloadId) &&
            (identical(
                  other.pendingConfirmationModelId,
                  pendingConfirmationModelId,
                ) ||
                other.pendingConfirmationModelId ==
                    pendingConfirmationModelId));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_models),
    const DeepCollectionEquality().hash(_activeDownloads),
    lastFailedDownloadId,
    pendingConfirmationModelId,
  );

  /// Create a copy of SherpaModelCatalogState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SherpaModelCatalogStateImplCopyWith<_$SherpaModelCatalogStateImpl>
  get copyWith =>
      __$$SherpaModelCatalogStateImplCopyWithImpl<
        _$SherpaModelCatalogStateImpl
      >(this, _$identity);
}

abstract class _SherpaModelCatalogState implements SherpaModelCatalogState {
  const factory _SherpaModelCatalogState({
    final List<SherpaModelInfo> models,
    final Map<String, SherpaModelDownloadProgress> activeDownloads,
    final String? lastFailedDownloadId,
    final String? pendingConfirmationModelId,
  }) = _$SherpaModelCatalogStateImpl;

  /// Full catalog: downloaded + available to download.
  @override
  List<SherpaModelInfo> get models;

  /// In-progress downloads keyed by modelId.
  @override
  Map<String, SherpaModelDownloadProgress> get activeDownloads;

  /// Model ID of the last download that failed, if any.
  @override
  String? get lastFailedDownloadId;

  /// Model ID awaiting user confirmation before download (> 100MB).
  @override
  String? get pendingConfirmationModelId;

  /// Create a copy of SherpaModelCatalogState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SherpaModelCatalogStateImplCopyWith<_$SherpaModelCatalogStateImpl>
  get copyWith => throw _privateConstructorUsedError;
}
