import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zip_core/src/models/enums.dart';

part 'app_settings.freezed.dart';

/// Immutable value object for shared display settings.
///
/// All fields have defaults via [AppSettings.defaults]. This represents the
/// shared settings managed by `BaseSettingsNotifier`; app-specific settings
/// are added by subclasses in later phases.
@freezed

/// User-configurable display and behavior settings.
abstract class AppSettings with _$AppSettings {
  /// Creates an [AppSettings] instance with the given preferences.
  const factory AppSettings({
    required ScrollDirection scrollDirection,
    required CaptionTextSize captionTextSize,
    required CaptionFont captionFont,
    required ThemeModeSetting themeModeSetting,
    required int maxVisibleLines,
  }) = _AppSettings;

  /// Returns the canonical default settings (BR-04).
  factory AppSettings.defaults() => const AppSettings(
        scrollDirection: ScrollDirection.bottomToTop,
        captionTextSize: CaptionTextSize.md,
        captionFont: CaptionFont.atkinsonHyperlegible,
        themeModeSetting: ThemeModeSetting.system,
        maxVisibleLines: 0,
      );
}
