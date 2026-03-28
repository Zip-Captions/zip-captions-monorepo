// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AppSettings {
  ScrollDirection get scrollDirection => throw _privateConstructorUsedError;
  CaptionTextSize get captionTextSize => throw _privateConstructorUsedError;
  CaptionFont get captionFont => throw _privateConstructorUsedError;
  ThemeModeSetting get themeModeSetting => throw _privateConstructorUsedError;
  int get maxVisibleLines => throw _privateConstructorUsedError;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppSettingsCopyWith<AppSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppSettingsCopyWith<$Res> {
  factory $AppSettingsCopyWith(
    AppSettings value,
    $Res Function(AppSettings) then,
  ) = _$AppSettingsCopyWithImpl<$Res, AppSettings>;
  @useResult
  $Res call({
    ScrollDirection scrollDirection,
    CaptionTextSize captionTextSize,
    CaptionFont captionFont,
    ThemeModeSetting themeModeSetting,
    int maxVisibleLines,
  });
}

/// @nodoc
class _$AppSettingsCopyWithImpl<$Res, $Val extends AppSettings>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? scrollDirection = null,
    Object? captionTextSize = null,
    Object? captionFont = null,
    Object? themeModeSetting = null,
    Object? maxVisibleLines = null,
  }) {
    return _then(
      _value.copyWith(
            scrollDirection: null == scrollDirection
                ? _value.scrollDirection
                : scrollDirection // ignore: cast_nullable_to_non_nullable
                      as ScrollDirection,
            captionTextSize: null == captionTextSize
                ? _value.captionTextSize
                : captionTextSize // ignore: cast_nullable_to_non_nullable
                      as CaptionTextSize,
            captionFont: null == captionFont
                ? _value.captionFont
                : captionFont // ignore: cast_nullable_to_non_nullable
                      as CaptionFont,
            themeModeSetting: null == themeModeSetting
                ? _value.themeModeSetting
                : themeModeSetting // ignore: cast_nullable_to_non_nullable
                      as ThemeModeSetting,
            maxVisibleLines: null == maxVisibleLines
                ? _value.maxVisibleLines
                : maxVisibleLines // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppSettingsImplCopyWith<$Res>
    implements $AppSettingsCopyWith<$Res> {
  factory _$$AppSettingsImplCopyWith(
    _$AppSettingsImpl value,
    $Res Function(_$AppSettingsImpl) then,
  ) = __$$AppSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    ScrollDirection scrollDirection,
    CaptionTextSize captionTextSize,
    CaptionFont captionFont,
    ThemeModeSetting themeModeSetting,
    int maxVisibleLines,
  });
}

/// @nodoc
class __$$AppSettingsImplCopyWithImpl<$Res>
    extends _$AppSettingsCopyWithImpl<$Res, _$AppSettingsImpl>
    implements _$$AppSettingsImplCopyWith<$Res> {
  __$$AppSettingsImplCopyWithImpl(
    _$AppSettingsImpl _value,
    $Res Function(_$AppSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? scrollDirection = null,
    Object? captionTextSize = null,
    Object? captionFont = null,
    Object? themeModeSetting = null,
    Object? maxVisibleLines = null,
  }) {
    return _then(
      _$AppSettingsImpl(
        scrollDirection: null == scrollDirection
            ? _value.scrollDirection
            : scrollDirection // ignore: cast_nullable_to_non_nullable
                  as ScrollDirection,
        captionTextSize: null == captionTextSize
            ? _value.captionTextSize
            : captionTextSize // ignore: cast_nullable_to_non_nullable
                  as CaptionTextSize,
        captionFont: null == captionFont
            ? _value.captionFont
            : captionFont // ignore: cast_nullable_to_non_nullable
                  as CaptionFont,
        themeModeSetting: null == themeModeSetting
            ? _value.themeModeSetting
            : themeModeSetting // ignore: cast_nullable_to_non_nullable
                  as ThemeModeSetting,
        maxVisibleLines: null == maxVisibleLines
            ? _value.maxVisibleLines
            : maxVisibleLines // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$AppSettingsImpl implements _AppSettings {
  const _$AppSettingsImpl({
    required this.scrollDirection,
    required this.captionTextSize,
    required this.captionFont,
    required this.themeModeSetting,
    required this.maxVisibleLines,
  });

  @override
  final ScrollDirection scrollDirection;
  @override
  final CaptionTextSize captionTextSize;
  @override
  final CaptionFont captionFont;
  @override
  final ThemeModeSetting themeModeSetting;
  @override
  final int maxVisibleLines;

  @override
  String toString() {
    return 'AppSettings(scrollDirection: $scrollDirection, captionTextSize: $captionTextSize, captionFont: $captionFont, themeModeSetting: $themeModeSetting, maxVisibleLines: $maxVisibleLines)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppSettingsImpl &&
            (identical(other.scrollDirection, scrollDirection) ||
                other.scrollDirection == scrollDirection) &&
            (identical(other.captionTextSize, captionTextSize) ||
                other.captionTextSize == captionTextSize) &&
            (identical(other.captionFont, captionFont) ||
                other.captionFont == captionFont) &&
            (identical(other.themeModeSetting, themeModeSetting) ||
                other.themeModeSetting == themeModeSetting) &&
            (identical(other.maxVisibleLines, maxVisibleLines) ||
                other.maxVisibleLines == maxVisibleLines));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    scrollDirection,
    captionTextSize,
    captionFont,
    themeModeSetting,
    maxVisibleLines,
  );

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppSettingsImplCopyWith<_$AppSettingsImpl> get copyWith =>
      __$$AppSettingsImplCopyWithImpl<_$AppSettingsImpl>(this, _$identity);
}

abstract class _AppSettings implements AppSettings {
  const factory _AppSettings({
    required final ScrollDirection scrollDirection,
    required final CaptionTextSize captionTextSize,
    required final CaptionFont captionFont,
    required final ThemeModeSetting themeModeSetting,
    required final int maxVisibleLines,
  }) = _$AppSettingsImpl;

  @override
  ScrollDirection get scrollDirection;
  @override
  CaptionTextSize get captionTextSize;
  @override
  CaptionFont get captionFont;
  @override
  ThemeModeSetting get themeModeSetting;
  @override
  int get maxVisibleLines;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppSettingsImplCopyWith<_$AppSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
