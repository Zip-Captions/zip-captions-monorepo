// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'overlay_window_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$OverlayWindowConfig {
  /// Whether the window floats above other applications.
  bool get floating => throw _privateConstructorUsedError;

  /// Whether the window has a title bar, a close button and resize handles.
  bool get decorated => throw _privateConstructorUsedError;

  /// Minimum content width in logical pixels. `0` means "no minimum".
  double get minWidth => throw _privateConstructorUsedError;

  /// Minimum content height in logical pixels. `0` means "no minimum".
  double get minHeight => throw _privateConstructorUsedError;

  /// Create a copy of OverlayWindowConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OverlayWindowConfigCopyWith<OverlayWindowConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OverlayWindowConfigCopyWith<$Res> {
  factory $OverlayWindowConfigCopyWith(
    OverlayWindowConfig value,
    $Res Function(OverlayWindowConfig) then,
  ) = _$OverlayWindowConfigCopyWithImpl<$Res, OverlayWindowConfig>;
  @useResult
  $Res call({bool floating, bool decorated, double minWidth, double minHeight});
}

/// @nodoc
class _$OverlayWindowConfigCopyWithImpl<$Res, $Val extends OverlayWindowConfig>
    implements $OverlayWindowConfigCopyWith<$Res> {
  _$OverlayWindowConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OverlayWindowConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? floating = null,
    Object? decorated = null,
    Object? minWidth = null,
    Object? minHeight = null,
  }) {
    return _then(
      _value.copyWith(
            floating: null == floating
                ? _value.floating
                : floating // ignore: cast_nullable_to_non_nullable
                      as bool,
            decorated: null == decorated
                ? _value.decorated
                : decorated // ignore: cast_nullable_to_non_nullable
                      as bool,
            minWidth: null == minWidth
                ? _value.minWidth
                : minWidth // ignore: cast_nullable_to_non_nullable
                      as double,
            minHeight: null == minHeight
                ? _value.minHeight
                : minHeight // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OverlayWindowConfigImplCopyWith<$Res>
    implements $OverlayWindowConfigCopyWith<$Res> {
  factory _$$OverlayWindowConfigImplCopyWith(
    _$OverlayWindowConfigImpl value,
    $Res Function(_$OverlayWindowConfigImpl) then,
  ) = __$$OverlayWindowConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool floating, bool decorated, double minWidth, double minHeight});
}

/// @nodoc
class __$$OverlayWindowConfigImplCopyWithImpl<$Res>
    extends _$OverlayWindowConfigCopyWithImpl<$Res, _$OverlayWindowConfigImpl>
    implements _$$OverlayWindowConfigImplCopyWith<$Res> {
  __$$OverlayWindowConfigImplCopyWithImpl(
    _$OverlayWindowConfigImpl _value,
    $Res Function(_$OverlayWindowConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OverlayWindowConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? floating = null,
    Object? decorated = null,
    Object? minWidth = null,
    Object? minHeight = null,
  }) {
    return _then(
      _$OverlayWindowConfigImpl(
        floating: null == floating
            ? _value.floating
            : floating // ignore: cast_nullable_to_non_nullable
                  as bool,
        decorated: null == decorated
            ? _value.decorated
            : decorated // ignore: cast_nullable_to_non_nullable
                  as bool,
        minWidth: null == minWidth
            ? _value.minWidth
            : minWidth // ignore: cast_nullable_to_non_nullable
                  as double,
        minHeight: null == minHeight
            ? _value.minHeight
            : minHeight // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$OverlayWindowConfigImpl implements _OverlayWindowConfig {
  const _$OverlayWindowConfigImpl({
    this.floating = false,
    this.decorated = false,
    this.minWidth = 0,
    this.minHeight = 0,
  });

  /// Whether the window floats above other applications.
  @override
  @JsonKey()
  final bool floating;

  /// Whether the window has a title bar, a close button and resize handles.
  @override
  @JsonKey()
  final bool decorated;

  /// Minimum content width in logical pixels. `0` means "no minimum".
  @override
  @JsonKey()
  final double minWidth;

  /// Minimum content height in logical pixels. `0` means "no minimum".
  @override
  @JsonKey()
  final double minHeight;

  @override
  String toString() {
    return 'OverlayWindowConfig(floating: $floating, decorated: $decorated, minWidth: $minWidth, minHeight: $minHeight)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OverlayWindowConfigImpl &&
            (identical(other.floating, floating) ||
                other.floating == floating) &&
            (identical(other.decorated, decorated) ||
                other.decorated == decorated) &&
            (identical(other.minWidth, minWidth) ||
                other.minWidth == minWidth) &&
            (identical(other.minHeight, minHeight) ||
                other.minHeight == minHeight));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, floating, decorated, minWidth, minHeight);

  /// Create a copy of OverlayWindowConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OverlayWindowConfigImplCopyWith<_$OverlayWindowConfigImpl> get copyWith =>
      __$$OverlayWindowConfigImplCopyWithImpl<_$OverlayWindowConfigImpl>(
        this,
        _$identity,
      );
}

abstract class _OverlayWindowConfig implements OverlayWindowConfig {
  const factory _OverlayWindowConfig({
    final bool floating,
    final bool decorated,
    final double minWidth,
    final double minHeight,
  }) = _$OverlayWindowConfigImpl;

  /// Whether the window floats above other applications.
  @override
  bool get floating;

  /// Whether the window has a title bar, a close button and resize handles.
  @override
  bool get decorated;

  /// Minimum content width in logical pixels. `0` means "no minimum".
  @override
  double get minWidth;

  /// Minimum content height in logical pixels. `0` means "no minimum".
  @override
  double get minHeight;

  /// Create a copy of OverlayWindowConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OverlayWindowConfigImplCopyWith<_$OverlayWindowConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
