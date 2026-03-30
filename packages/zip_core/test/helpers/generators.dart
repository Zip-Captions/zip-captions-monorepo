// PBT generator library for glados (LC-01).
//
// Centralized Arbitrary<T> instances for all domain types.
// Imported by PBT test files.

import 'package:glados/glados.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/display_settings.dart';
import 'package:zip_core/src/models/enums.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';

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

// --- Composed DisplaySettings generator ---

final Generator<DisplaySettings> arbitraryDisplaySettings =
    any.combine5(
  arbitraryScrollDirection,
  arbitraryCaptionTextSize,
  arbitraryCaptionFont,
  arbitraryThemeModeSetting,
  any.intInRange(0, 101),
  (scroll, textSize, font, theme, lines) => DisplaySettings(
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

// --- SttResult generator ---

/// Generates valid SttResult instances with randomized fields.
final Generator<SttResult> arbitrarySttResult = any.combine5(
  any.letterOrDigits, // text
  any.bool, // isFinal
  any.doubleInRange(0.0, 1.0), // confidence
  any.choose(['default', 'mic-1', 'mic-2', 'system-audio']), // sourceId
  any.choose([null, 'Speaker A', 'Speaker B']), // speakerTag
  (text, isFinal, confidence, sourceId, speakerTag) => SttResult(
    text: text.isEmpty && isFinal ? 'fallback' : text,
    isFinal: isFinal,
    confidence: confidence,
    timestamp: DateTime.utc(2026),
    sourceId: sourceId,
    speakerTag: speakerTag,
  ),
);

// --- CaptionEvent generator ---

/// Generates random CaptionEvent instances (either SttResultEvent or
/// SessionStateEvent).
final Generator<CaptionEvent> arbitraryCaptionEvent = any.combine2(
  any.bool,
  arbitrarySttResult,
  (useResult, result) => useResult
      ? SttResultEvent(result)
      : SessionStateEvent(
          const RecordingState.recording(sessionId: 'test-session'),
        ),
);

// --- Registry operation generators ---

/// Operations that can be applied to SttEngineRegistry.
enum RegistryOp { register, unregister, get }

final Generator<RegistryOp> arbitraryRegistryOp =
    any.choose(RegistryOp.values);

final Generator<List<RegistryOp>> arbitraryRegistryOps =
    any.listWithLengthInRange(0, 30, arbitraryRegistryOp);
