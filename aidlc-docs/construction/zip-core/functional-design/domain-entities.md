# Domain Entities — Unit 2: zip_core Library

## Enums

### `ScrollDirection`

Controls the flow direction of caption text on screen.

| Value | Meaning |
|---|---|
| `topToBottom` | New captions appear at top, older captions scroll down |
| `bottomToTop` | New captions appear at bottom, older captions scroll up (default) |

Persistence: stored as enum name string in SharedPreferences.

---

### `ThemeModeSetting`

User preference for app color scheme. Named `ThemeModeSetting` to avoid collision with Flutter's built-in `ThemeMode` enum. Maps directly to `ThemeMode` at the widget layer.

| Value | Meaning |
|---|---|
| `system` | Follow OS light/dark setting (default) |
| `dark` | Force dark theme (Monolith Editorial dark palette) |
| `light` | Force light theme (Monolith Editorial light palette) |

Persistence: stored as enum name string in SharedPreferences.

---

### `CaptionTextSize`

Semantic text size tiers for caption display. Maps to Material 3 `TextTheme` styles at render time, inheriting system accessibility scaling via `MediaQuery.textScaleFactor`.

| Value | v1 equivalent | Material 3 TextTheme style |
|---|---|---|
| `xs` | xs | `bodySmall` |
| `sm` | sm | `bodyLarge` |
| `md` | md (default) | `headlineSmall` |
| `lg` | lg | `headlineMedium` |
| `xl` | xl | `headlineLarge` |
| `xxl` | xxl | `displaySmall` |

Persistence: stored as enum name string in SharedPreferences.

---

### `CaptionFont`

User-selectable caption display fonts. These are the v1 fonts, all available as Google Fonts and bundled cross-platform via the `google_fonts` package (pending dependency approval — not on the current approved list in `docs/04-technical-specification.md` Section 6).

**Note**: `google_fonts` requires approval as a new dependency. If not approved, fonts can be bundled as `.ttf` assets directly in the app. The enum and model are the same either way.

Inter is the **UI chrome font** (labels, buttons, navigation, settings screens). The `CaptionFont` enum applies only to **caption display text**.

| Value | Font family | Notes |
|---|---|---|
| `atkinsonHyperlegible` | Atkinson Hyperlegible | Default. Designed for legibility; v1 default (`sans`) |
| `poppins` | Poppins | Geometric sans-serif |
| `lexend` | Lexend | Designed for reading proficiency; accessibility-focused |
| `raleway` | Raleway | Elegant sans-serif |
| `comicNeue` | Comic Neue | Casual, dyslexia-friendly alternative |
| `notoSans` | Noto Sans | Broad Unicode coverage; CJK support |
| `cousine` | Cousine | Monospace |
| `inconsolata` | Inconsolata | Monospace |

Persistence: stored as enum name string in SharedPreferences.

---

### `RecordingErrorSeverity`

Indicates whether a recording error should halt the state machine or be surfaced as a transient notification.

| Value | Meaning | State machine effect |
|---|---|---|
| `fatal` | Process halted; recording cannot continue | Transitions state to `idle`; accumulated data preserved in error |
| `transient` | Momentary issue; recording continues | No state transition; error surfaced to UI for display |

---

## Freezed Data Classes

### `AppSettings`

Immutable value object for shared display settings. All fields have defaults. This represents the **shared** settings managed by `BaseSettingsNotifier`; app-specific settings are added by subclasses in later phases.

| Field | Type | Default | Purpose |
|---|---|---|---|
| `scrollDirection` | `ScrollDirection` | `ScrollDirection.bottomToTop` | Caption text flow direction |
| `captionTextSize` | `CaptionTextSize` | `CaptionTextSize.md` | Semantic caption font size tier |
| `captionFont` | `CaptionFont` | `CaptionFont.atkinsonHyperlegible` | User-selected caption display font |
| `themeModeSetting` | `ThemeModeSetting` | `ThemeModeSetting.system` | Light/dark/system theme preference |
| `maxVisibleLines` | `int` | `0` | Max caption lines visible (0 = unlimited) |

Factory: `AppSettings.defaults()` returns the above defaults.

**Field changes from Application Design**: `textSize` (double) replaced by `captionTextSize` (CaptionTextSize enum). `fontFamily` (String) replaced by `captionFont` (CaptionFont enum). `contrastMode` (ContrastMode) replaced by `themeModeSetting` (ThemeModeSetting enum) per Q4 answer — contrast is an accessibility baseline, not a user toggle.

---

### `SpeechLocale`

Represents a locale available for speech recognition. The granularity of locale identifiers varies by STT engine — some provide language-only, some language + region, some require both. This model accommodates all patterns.

| Field | Type | Purpose |
|---|---|---|
| `localeId` | `String` | Locale identifier as reported by the STT engine. May be language-only (e.g., `en`), language-region (e.g., `en-US`), or engine-specific. Treated as an opaque key for persistence and matching. |
| `displayName` | `String` | Human-readable name in the user's current display locale |

Computed property: `languageCode` — extracts the language portion of `localeId` (everything before the first hyphen or underscore; the full string if neither is present). Used for fallback matching when an exact `localeId` match is unavailable.

Equality: two `SpeechLocale` instances are equal if `localeId` matches (case-insensitive).

Note: The PoC used underscore format (`en_US`). The model accepts both hyphen and underscore formats since different engines may use different separators. The `languageCode` extraction handles both.

---

### `RecordingError`

Represents an error that occurred during recording, with severity to determine state machine impact.

| Field | Type | Purpose |
|---|---|---|
| `message` | `String` | Human-readable error description (never contains transcript text) |
| `severity` | `RecordingErrorSeverity` | Whether this error halts recording or is transient |
| `timestamp` | `DateTime` | When the error occurred |

---

### `PauseEvent`

Records a pause/resume cycle within a recording session. Pauses represent intentional gaps where the user omitted audio from the capture. These events are preserved in the session data and included in transcript exports as visible markers (e.g., "[Paused 00:12 - 00:47]").

| Field | Type | Purpose |
|---|---|---|
| `pausedAt` | `DateTime` | When the user paused recording |
| `resumedAt` | `DateTime?` | When the user resumed recording; null if session was stopped while paused |

Phase 0: model defined but not populated (stub state machine has no real session timeline). Phase 1: populated by `RecordingStateNotifier` on each pause/resume cycle.

---

## Sealed Classes

### `RecordingState`

Represents the recording state machine. Four states; no error state (errors are handled separately via `RecordingError`).

| Variant | Fields | Meaning |
|---|---|---|
| `RecordingState.idle()` | -- | No active session. Initial state. |
| `RecordingState.recording()` | -- | Actively capturing speech. Phase 1 adds `currentSegment`. |
| `RecordingState.paused()` | -- | Session paused; user is intentionally omitting audio. Can resume to continue capturing. |
| `RecordingState.stopped()` | -- | Session ended. Phase 1 adds `segments` (accumulated results) and `pauseEvents` (pause history). |

Phase 0: all variants are field-less. Phase 1 extends `recording` and `stopped` with segment data and pause history (`List<PauseEvent>`). The pause/resume cycle is a core workflow — users pause to omit sensitive or irrelevant audio, then resume without ending the session.

---

## Abstract Interfaces

### `SttEngine`

Abstract interface for speech-to-text engines. Phase 0 defines the contract only; no concrete implementation.

| Method | Signature | Purpose |
|---|---|---|
| `initialize` | `Future<bool> initialize()` | Request permissions, prepare engine |
| `isAvailable` | `Future<bool> isAvailable()` | Check if engine can run on device/platform |
| `startListening` | `Future<bool> startListening({String? localeId, required void Function(String text) onInterimResult, required void Function(String text) onFinalResult, required void Function(RecordingError error) onError})` | Begin STT session with callbacks |
| `stopListening` | `Future<void> stopListening()` | End STT session |
| `pause` | `Future<bool> pause()` | Pause recognition |
| `resume` | `Future<bool> resume()` | Resume recognition |
| `getAvailableLocales` | `Future<List<SpeechLocale>> getAvailableLocales()` | List supported STT locales |
| `dispose` | `void dispose()` | Release resources |

Security constraint: Callbacks receive transcript text. The `SttEngine` implementation and all code handling these callbacks must never log, emit, or surface transcript text content. Only state transitions and error messages may appear in logs.
