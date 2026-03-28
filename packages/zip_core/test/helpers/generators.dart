// PBT generator library for glados (LC-01).
//
// Centralized Arbitrary<T> instances for all domain types.
// Imported by PBT test files.

import 'package:glados/glados.dart';
import 'package:zip_core/src/models/app_settings.dart';
import 'package:zip_core/src/models/enums.dart';

import 'prefs_helpers.dart';
import 'recording_state_model.dart';

// --- Enum generators ---

final Generator<ScrollDirection> arbitraryScrollDirection =
    any.choose(ScrollDirection.values);

final Generator<CaptionTextSize> arbitraryCaptionTextSize =
    any.choose(CaptionTextSize.values);

final Generator<CaptionFont> arbitraryCaptionFont =
    any.choose(CaptionFont.values);

final Generator<ThemeModeSetting> arbitraryThemeModeSetting =
    any.choose(ThemeModeSetting.values);

// --- Composed AppSettings generator ---

final Generator<AppSettings> arbitraryAppSettings =
    any.combine5(
  arbitraryScrollDirection,
  arbitraryCaptionTextSize,
  arbitraryCaptionFont,
  arbitraryThemeModeSetting,
  any.intInRange(0, 101),
  (scroll, textSize, font, theme, lines) => AppSettings(
    scrollDirection: scroll,
    captionTextSize: textSize,
    captionFont: font,
    themeModeSetting: theme,
    maxVisibleLines: lines,
  ),
);

// --- Command generators ---

final Generator<Command> arbitraryCommand =
    any.choose(Command.values);

final Generator<List<Command>> arbitraryCommandSequence =
    any.listWithLengthInRange(0, 50, arbitraryCommand);

// --- FieldState generator ---

final Generator<FieldState> arbitraryFieldState =
    any.choose(FieldState.values);

// --- Locale ID generator ---

/// Generates BCP-47-like locale ID strings:
/// language codes, language-region pairs, and edge cases.
final Generator<String> arbitraryLocaleId = any.choose([
  'en',
  'fr',
  'de',
  'es',
  'ja',
  'zh',
  'ko',
  'ar',
  'pt',
  'en-US',
  'en-GB',
  'fr-FR',
  'zh-CN',
  'zh-TW',
  'pt-BR',
  'es-MX',
  'EN',
  'en_US',
  'EN-us',
]);
