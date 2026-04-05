// PBT generator library for glados (LC-01).
//
// Centralized Arbitrary<T> instances for all domain types.
// Imported by PBT test files.

import 'package:glados/glados.dart';
import 'package:zip_core/src/models/audio_device.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/display_settings.dart';
import 'package:zip_core/src/models/enums.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/sherpa_model_catalog.dart';
import 'package:zip_core/src/models/sherpa_model_download_progress.dart';
import 'package:zip_core/src/models/sherpa_model_info.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';

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
  any.doubleInRange(0, 1), // confidence
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

/// Generates random [RecordingState] instances across all five variants.
final Generator<RecordingState> arbitraryRecordingState = any.combine3(
  any.intInRange(0, 5),
  any.letterOrDigits,
  any.letterOrDigits,
  (variant, sessionId, segment) {
    final sid = sessionId.isEmpty ? 'test-session' : sessionId;
    return switch (variant) {
      0 => const RecordingState.idle(),
      1 => RecordingState.recording(sessionId: sid, currentSegment: segment),
      2 => RecordingState.paused(sessionId: sid, currentSegment: segment),
      3 => RecordingState.reconnecting(sessionId: sid, currentSegment: segment),
      _ => RecordingState.stopped(sessionId: sid, currentSegment: segment),
    };
  },
);

/// Generates random CaptionEvent instances (either SttResultEvent or
/// SessionStateEvent with a varied [RecordingState]).
final Generator<CaptionEvent> arbitraryCaptionEvent = any.combine3(
  any.bool,
  arbitrarySttResult,
  arbitraryRecordingState,
  (useResult, result, state) =>
      useResult ? SttResultEvent(result) : SessionStateEvent(state),
);

// --- Registry operation generators ---

/// Operations that can be applied to SttEngineRegistry.
enum RegistryOp { register, unregister, get }

final Generator<RegistryOp> arbitraryRegistryOp =
    any.choose(RegistryOp.values);

final Generator<List<RegistryOp>> arbitraryRegistryOps =
    any.listWithLengthInRange(0, 30, arbitraryRegistryOp);

// --- Unit 2 domain generators ---

/// Generates [AudioDevice] instances with varied IDs and names.
final Generator<AudioDevice> arbitraryAudioDevice = any.combine3(
  any.letterOrDigits,
  any.letterOrDigits,
  any.bool,
  (id, name, isDefault) => AudioDevice(
    deviceId: id.isEmpty ? 'dev-0' : id,
    name: name.isEmpty ? 'Device' : name,
    isDefault: isDefault,
  ),
);

/// Generates [WakeLockSettings] with all boolean combinations.
final Generator<WakeLockSettings> arbitraryWakeLockSettings = any.combine2(
  any.bool,
  any.bool,
  (enabled, releaseOnPause) => WakeLockSettings(
    enabled: enabled,
    releaseOnPause: releaseOnPause,
  ),
);

/// Generates [SherpaModelCatalogEntry] instances.
final Generator<SherpaModelCatalogEntry> arbitrarySherpaModelCatalogEntry =
    any.combine4(
  any.letterOrDigits,
  arbitraryLocaleId,
  any.intInRange(1000, 500000000),
  any.letterOrDigits,
  (modelId, locale, sizeBytes, checksum) => SherpaModelCatalogEntry(
    modelId: modelId.isEmpty ? 'model-0' : modelId,
    displayName: 'Model $modelId',
    primaryLocaleId: locale,
    downloadSizeBytes: sizeBytes,
    downloadUrl: 'https://example.com/$modelId.tar.bz2',
    sha256Checksum: checksum.isEmpty ? 'abc123' : checksum,
  ),
);

/// Generates [SherpaModelInfo] instances.
final Generator<SherpaModelInfo> arbitrarySherpaModelInfo = any.combine2(
  arbitrarySherpaModelCatalogEntry,
  any.bool,
  (entry, isDownloaded) => SherpaModelInfo(
    catalogEntry: entry,
    isDownloaded: isDownloaded,
    localPath: isDownloaded ? '/models/${entry.modelId}' : null,
  ),
);

/// Generates [SherpaModelDownloadProgress] instances with valid invariants.
///
/// `downloadedBytes` is varied across 0%, partial, and 100% to cover all
/// progress edge cases.
final Generator<SherpaModelDownloadProgress>
    arbitrarySherpaModelDownloadProgress = any.combine3(
  any.letterOrDigits,
  any.intInRange(1, 500000000),
  any.doubleInRange(0, 1),
  (modelId, totalBytes, fraction) => SherpaModelDownloadProgress(
    modelId: modelId.isEmpty ? 'model-0' : modelId,
    downloadedBytes: (totalBytes * fraction).round(),
    totalBytes: totalBytes,
  ),
);
