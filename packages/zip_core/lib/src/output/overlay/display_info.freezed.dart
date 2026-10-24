// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'display_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$DisplayInfo {
  /// Opaque, non-empty id. The only display fact persisted across launches.
  String get id => throw _privateConstructorUsedError;

  /// Human-readable name; may be empty. Never used as a key.
  String get label => throw _privateConstructorUsedError;

  /// Work-area rectangle in logical pixels, top-left origin.
  Rect get bounds => throw _privateConstructorUsedError;

  /// The display's scale factor. `0` or a missing value is treated as `1`
  /// by the Windows frame conversion.
  double get scaleFactor => throw _privateConstructorUsedError;

  /// Whether this is the primary display. Exactly one entry of a non-empty
  /// list is primary.
  bool get isPrimary => throw _privateConstructorUsedError;

  /// Create a copy of DisplayInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DisplayInfoCopyWith<DisplayInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DisplayInfoCopyWith<$Res> {
  factory $DisplayInfoCopyWith(
    DisplayInfo value,
    $Res Function(DisplayInfo) then,
  ) = _$DisplayInfoCopyWithImpl<$Res, DisplayInfo>;
  @useResult
  $Res call({
    String id,
    String label,
    Rect bounds,
    double scaleFactor,
    bool isPrimary,
  });
}

/// @nodoc
class _$DisplayInfoCopyWithImpl<$Res, $Val extends DisplayInfo>
    implements $DisplayInfoCopyWith<$Res> {
  _$DisplayInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DisplayInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? bounds = null,
    Object? scaleFactor = null,
    Object? isPrimary = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
            bounds: null == bounds
                ? _value.bounds
                : bounds // ignore: cast_nullable_to_non_nullable
                      as Rect,
            scaleFactor: null == scaleFactor
                ? _value.scaleFactor
                : scaleFactor // ignore: cast_nullable_to_non_nullable
                      as double,
            isPrimary: null == isPrimary
                ? _value.isPrimary
                : isPrimary // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DisplayInfoImplCopyWith<$Res>
    implements $DisplayInfoCopyWith<$Res> {
  factory _$$DisplayInfoImplCopyWith(
    _$DisplayInfoImpl value,
    $Res Function(_$DisplayInfoImpl) then,
  ) = __$$DisplayInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String label,
    Rect bounds,
    double scaleFactor,
    bool isPrimary,
  });
}

/// @nodoc
class __$$DisplayInfoImplCopyWithImpl<$Res>
    extends _$DisplayInfoCopyWithImpl<$Res, _$DisplayInfoImpl>
    implements _$$DisplayInfoImplCopyWith<$Res> {
  __$$DisplayInfoImplCopyWithImpl(
    _$DisplayInfoImpl _value,
    $Res Function(_$DisplayInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DisplayInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? bounds = null,
    Object? scaleFactor = null,
    Object? isPrimary = null,
  }) {
    return _then(
      _$DisplayInfoImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
        bounds: null == bounds
            ? _value.bounds
            : bounds // ignore: cast_nullable_to_non_nullable
                  as Rect,
        scaleFactor: null == scaleFactor
            ? _value.scaleFactor
            : scaleFactor // ignore: cast_nullable_to_non_nullable
                  as double,
        isPrimary: null == isPrimary
            ? _value.isPrimary
            : isPrimary // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$DisplayInfoImpl implements _DisplayInfo {
  const _$DisplayInfoImpl({
    required this.id,
    required this.label,
    required this.bounds,
    required this.scaleFactor,
    required this.isPrimary,
  });

  /// Opaque, non-empty id. The only display fact persisted across launches.
  @override
  final String id;

  /// Human-readable name; may be empty. Never used as a key.
  @override
  final String label;

  /// Work-area rectangle in logical pixels, top-left origin.
  @override
  final Rect bounds;

  /// The display's scale factor. `0` or a missing value is treated as `1`
  /// by the Windows frame conversion.
  @override
  final double scaleFactor;

  /// Whether this is the primary display. Exactly one entry of a non-empty
  /// list is primary.
  @override
  final bool isPrimary;

  @override
  String toString() {
    return 'DisplayInfo(id: $id, label: $label, bounds: $bounds, scaleFactor: $scaleFactor, isPrimary: $isPrimary)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DisplayInfoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.bounds, bounds) || other.bounds == bounds) &&
            (identical(other.scaleFactor, scaleFactor) ||
                other.scaleFactor == scaleFactor) &&
            (identical(other.isPrimary, isPrimary) ||
                other.isPrimary == isPrimary));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, label, bounds, scaleFactor, isPrimary);

  /// Create a copy of DisplayInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DisplayInfoImplCopyWith<_$DisplayInfoImpl> get copyWith =>
      __$$DisplayInfoImplCopyWithImpl<_$DisplayInfoImpl>(this, _$identity);
}

abstract class _DisplayInfo implements DisplayInfo {
  const factory _DisplayInfo({
    required final String id,
    required final String label,
    required final Rect bounds,
    required final double scaleFactor,
    required final bool isPrimary,
  }) = _$DisplayInfoImpl;

  /// Opaque, non-empty id. The only display fact persisted across launches.
  @override
  String get id;

  /// Human-readable name; may be empty. Never used as a key.
  @override
  String get label;

  /// Work-area rectangle in logical pixels, top-left origin.
  @override
  Rect get bounds;

  /// The display's scale factor. `0` or a missing value is treated as `1`
  /// by the Windows frame conversion.
  @override
  double get scaleFactor;

  /// Whether this is the primary display. Exactly one entry of a non-empty
  /// list is primary.
  @override
  bool get isPrimary;

  /// Create a copy of DisplayInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DisplayInfoImplCopyWith<_$DisplayInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
