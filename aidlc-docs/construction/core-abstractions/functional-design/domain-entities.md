# Domain Entities — Unit 1: Core Abstractions

## New Models

### SttResult (freezed)

Immutable value object representing a single speech recognition result from any STT engine.

```dart
@freezed
class SttResult with _$SttResult {
  const factory SttResult({
    required String text,
    required bool isFinal,
    required double confidence,
    required DateTime timestamp,
    String? speakerTag,
    required String sourceId,
  }) = _SttResult;
}
```

| Field | Type | Constraints | Purpose |
|-------|------|-------------|---------|
| `text` | `String` | Non-empty for final results; may be empty for interim | Recognized speech text |
| `isFinal` | `bool` | — | `true` = committed utterance, `false` = interim/partial |
| `confidence` | `double` | 0.0-1.0. Engines that don't report confidence use `1.0` | Recognition confidence |
| `timestamp` | `DateTime` | UTC | When the utterance was recognized |
| `speakerTag` | `String?` | Optional; reserved for future diarization | Speaker identification |
| `sourceId` | `String` | Non-empty. Identifies the input source | Multi-input disambiguation |

**Default sourceId**: Single-input apps use a constant like `'default'`. Multi-input (Zip Broadcast) uses the `AudioInputConfig.inputId`.

---

### CaptionEvent (sealed class)

All events that flow through the CaptionBus. Sealed for exhaustive pattern matching.

```dart
sealed class CaptionEvent {
  const CaptionEvent();
}

class SttResultEvent extends CaptionEvent {
  const SttResultEvent(this.result);
  final SttResult result;
}

class SessionStateEvent extends CaptionEvent {
  const SessionStateEvent(this.state);
  final RecordingState state;
}
```

| Variant | Fields | When Published |
|---------|--------|----------------|
| `SttResultEvent` | `SttResult result` | Every interim and final recognition result |
| `SessionStateEvent` | `RecordingState state` | On start, pause, resume, stop transitions |

**Exhaustive matching**: Consumers use `switch (event)` with `SttResultEvent` and `SessionStateEvent` cases. No default case needed — the compiler enforces all variants are handled.

---

### AudioInputConfig (freezed)

Configuration for a single audio input source. Defined in Unit 1 for use by RecordingState and multi-input references; full audio capture implementation is Unit 2.

```dart
@freezed
class AudioInputConfig with _$AudioInputConfig {
  const factory AudioInputConfig({
    required String inputId,
    String? sourceDeviceId,
    required String speakerLabel,
    required AudioInputVisualStyle visualStyle,
    @Default(true) bool isActive,
  }) = _AudioInputConfig;
}
```

---

### AudioInputVisualStyle (freezed)

Visual differentiation for multi-input caption rendering.

```dart
@freezed
class AudioInputVisualStyle with _$AudioInputVisualStyle {
  const factory AudioInputVisualStyle({
    required int colorValue,
    String? label,
  }) = _AudioInputVisualStyle;
}
```

**Note**: Uses `int colorValue` (ARGB) rather than `Color` to keep the model layer free of Flutter UI imports. UI code converts via `Color(colorValue)`.

---

## Modified Models

### RecordingState (sealed class — updated)

Phase 1 adds a shared mixin for session-related fields across non-idle variants.

```dart
/// Mixin providing session fields for active recording states.
mixin ActiveSessionState {
  String get sessionId;
  String get currentSegment;
}

sealed class RecordingState {
  const RecordingState();

  const factory RecordingState.idle() = IdleState;
  const factory RecordingState.recording({
    required String sessionId,
    @Default('') String currentSegment,
  }) = RecordingActiveState;
  const factory RecordingState.paused({
    required String sessionId,
    @Default('') String currentSegment,
  }) = PausedState;
  const factory RecordingState.stopped({
    required String sessionId,
    @Default('') String currentSegment,
  }) = StoppedState;
}

class IdleState extends RecordingState {
  const IdleState();
}

class RecordingActiveState extends RecordingState with ActiveSessionState {
  const RecordingActiveState({
    required this.sessionId,
    this.currentSegment = '',
  });

  @override
  final String sessionId;
  @override
  final String currentSegment;
}

class PausedState extends RecordingState with ActiveSessionState {
  const PausedState({
    required this.sessionId,
    this.currentSegment = '',
  });

  @override
  final String sessionId;
  @override
  final String currentSegment;
}

class StoppedState extends RecordingState with ActiveSessionState {
  const StoppedState({
    required this.sessionId,
    this.currentSegment = '',
  });

  @override
  final String sessionId;
  @override
  final String currentSegment;
}
```

**Key changes from Phase 0**:
- `IdleState` remains field-less
- `RecordingActiveState`, `PausedState`, `StoppedState` gain `sessionId` (required) and `currentSegment` (defaults to `''`)
- `ActiveSessionState` mixin allows consumers to access session fields without knowing the specific variant: `if (state is ActiveSessionState) { state.sessionId }`
- `sessionId` is generated via `Uuid().v4()` when transitioning from idle to recording
- `currentSegment` is updated by `RecordingStateNotifier` when interim results arrive, cleared on final results

---

### DisplaySettings (renamed from AppSettings)

Class and file rename only. No new fields. Key prefix changes from `app_settings` to `display_settings` (Q6=A).

```dart
// File: display_settings.dart (renamed from app_settings.dart)
@freezed
class DisplaySettings with _$DisplaySettings {
  const factory DisplaySettings({
    required ScrollDirection scrollDirection,
    required CaptionTextSize captionTextSize,
    required CaptionFont captionFont,
    required ThemeModeSetting themeModeSetting,
    required int maxVisibleLines,
  }) = _DisplaySettings;

  factory DisplaySettings.defaults() => const DisplaySettings(
    scrollDirection: ScrollDirection.bottomToTop,
    captionTextSize: CaptionTextSize.md,
    captionFont: CaptionFont.atkinsonHyperlegible,
    themeModeSetting: ThemeModeSetting.system,
    maxVisibleLines: 0,
  );
}
```

**Rename scope** (all in Unit 1):

| File/Class | Old Name | New Name |
|------------|----------|----------|
| zip_core model file | `app_settings.dart` | `display_settings.dart` |
| zip_core model class | `AppSettings` | `DisplaySettings` |
| zip_core base notifier | `Notifier<AppSettings>` | `Notifier<DisplaySettings>` |
| zip_core base notifier key prefix | `app_settings` | `display_settings` |
| zip_captions notifier | `ZipCaptionsSettingsNotifier` | `DisplaySettingsNotifier` |
| zip_broadcast notifier | `ZipBroadcastSettingsNotifier` | `DisplaySettingsNotifier` |
| All test files | References to `AppSettings` | References to `DisplaySettings` |
| Generated files | `app_settings.freezed.dart`, `.g.dart` | `display_settings.freezed.dart`, `.g.dart` |

---

## Existing Models (Unchanged in Unit 1)

| Model | Status |
|-------|--------|
| `SpeechLocale` | Unchanged — used by SttEngine.supportedLocales() |
| `RecordingError` | Unchanged — used by SttEngine error handling |
| `PauseEvent` | Unchanged — future use |
| Enums (`ScrollDirection`, `CaptionTextSize`, etc.) | Unchanged |
