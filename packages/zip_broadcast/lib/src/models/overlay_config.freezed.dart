// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'overlay_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$OverlayConfig {
  /// Which display to open the overlay on. `null` = primary display.
  String? get targetDisplayId => throw _privateConstructorUsedError;

  /// Where to position the overlay window.
  OverlayPosition get position => throw _privateConstructorUsedError;

  /// Window opacity from 0.0 (transparent) to 1.0 (opaque).
  double get opacity => throw _privateConstructorUsedError;

  /// Create a copy of OverlayConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OverlayConfigCopyWith<OverlayConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OverlayConfigCopyWith<$Res> {
  factory $OverlayConfigCopyWith(
    OverlayConfig value,
    $Res Function(OverlayConfig) then,
  ) = _$OverlayConfigCopyWithImpl<$Res, OverlayConfig>;
  @useResult
  $Res call({
    String? targetDisplayId,
    OverlayPosition position,
    double opacity,
  });
}

/// @nodoc
class _$OverlayConfigCopyWithImpl<$Res, $Val extends OverlayConfig>
    implements $OverlayConfigCopyWith<$Res> {
  _$OverlayConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OverlayConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? targetDisplayId = freezed,
    Object? position = null,
    Object? opacity = null,
  }) {
    return _then(
      _value.copyWith(
            targetDisplayId: freezed == targetDisplayId
                ? _value.targetDisplayId
                : targetDisplayId // ignore: cast_nullable_to_non_nullable
                      as String?,
            position: null == position
                ? _value.position
                : position // ignore: cast_nullable_to_non_nullable
                      as OverlayPosition,
            opacity: null == opacity
                ? _value.opacity
                : opacity // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OverlayConfigImplCopyWith<$Res>
    implements $OverlayConfigCopyWith<$Res> {
  factory _$$OverlayConfigImplCopyWith(
    _$OverlayConfigImpl value,
    $Res Function(_$OverlayConfigImpl) then,
  ) = __$$OverlayConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? targetDisplayId,
    OverlayPosition position,
    double opacity,
  });
}

/// @nodoc
class __$$OverlayConfigImplCopyWithImpl<$Res>
    extends _$OverlayConfigCopyWithImpl<$Res, _$OverlayConfigImpl>
    implements _$$OverlayConfigImplCopyWith<$Res> {
  __$$OverlayConfigImplCopyWithImpl(
    _$OverlayConfigImpl _value,
    $Res Function(_$OverlayConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OverlayConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? targetDisplayId = freezed,
    Object? position = null,
    Object? opacity = null,
  }) {
    return _then(
      _$OverlayConfigImpl(
        targetDisplayId: freezed == targetDisplayId
            ? _value.targetDisplayId
            : targetDisplayId // ignore: cast_nullable_to_non_nullable
                  as String?,
        position: null == position
            ? _value.position
            : position // ignore: cast_nullable_to_non_nullable
                  as OverlayPosition,
        opacity: null == opacity
            ? _value.opacity
            : opacity // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$OverlayConfigImpl implements _OverlayConfig {
  const _$OverlayConfigImpl({
    this.targetDisplayId,
    this.position = const OverlayPositionBottom(),
    this.opacity = 0.9,
  });

  /// Which display to open the overlay on. `null` = primary display.
  @override
  final String? targetDisplayId;

  /// Where to position the overlay window.
  @override
  @JsonKey()
  final OverlayPosition position;

  /// Window opacity from 0.0 (transparent) to 1.0 (opaque).
  @override
  @JsonKey()
  final double opacity;

  @override
  String toString() {
    return 'OverlayConfig(targetDisplayId: $targetDisplayId, position: $position, opacity: $opacity)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OverlayConfigImpl &&
            (identical(other.targetDisplayId, targetDisplayId) ||
                other.targetDisplayId == targetDisplayId) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.opacity, opacity) || other.opacity == opacity));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, targetDisplayId, position, opacity);

  /// Create a copy of OverlayConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OverlayConfigImplCopyWith<_$OverlayConfigImpl> get copyWith =>
      __$$OverlayConfigImplCopyWithImpl<_$OverlayConfigImpl>(this, _$identity);
}

abstract class _OverlayConfig implements OverlayConfig {
  const factory _OverlayConfig({
    final String? targetDisplayId,
    final OverlayPosition position,
    final double opacity,
  }) = _$OverlayConfigImpl;

  /// Which display to open the overlay on. `null` = primary display.
  @override
  String? get targetDisplayId;

  /// Where to position the overlay window.
  @override
  OverlayPosition get position;

  /// Window opacity from 0.0 (transparent) to 1.0 (opaque).
  @override
  double get opacity;

  /// Create a copy of OverlayConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OverlayConfigImplCopyWith<_$OverlayConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
