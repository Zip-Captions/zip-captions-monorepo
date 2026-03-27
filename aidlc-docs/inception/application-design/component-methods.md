# Component Methods — Zip Captions v2, Phase 0

Note: Detailed business logic and state machine design happens in Functional Design (Construction Phase, per-unit). This document defines public API signatures and high-level purpose only.

**Supersession note**: The following inception-phase field names in `BaseSettingsNotifier` and `AppSettings` were replaced during construction-phase functional design:
- `textSize` (double) -> `captionTextSize` (`CaptionTextSize` enum) — superseded by `domain-entities.md` CaptionTextSize enum
- `fontFamily` (String) -> `captionFont` (`CaptionFont` enum) — superseded by `domain-entities.md` CaptionFont enum
- `contrastMode` (`ContrastMode`) -> `themeModeSetting` (`ThemeModeSetting` enum) — superseded by `domain-entities.md` ThemeModeSetting enum

See `aidlc-docs/construction/zip-core/functional-design/domain-entities.md` (AppSettings section) for the authoritative field definitions. The setter methods (`setTextSize`, `setFontFamily`, `setContrastMode`) are similarly superseded by their renamed equivalents.

---

## zip_core

### `LocaleProvider` (Notifier<Locale>)

| Method / Property | Signature | Purpose |
|---|---|---|
| `build` | `Locale build()` | Returns persisted locale, defaulting to device locale |
| `setLocale` | `Future<void> setLocale(Locale locale)` | Persists and applies a new display locale |
| `locale` (state) | `Locale get locale` | Currently active locale |

---

### `LocaleInfoProvider` (returns `List<SpeechLocale>`)

| Method / Property | Signature | Purpose |
|---|---|---|
| `build` | `List<SpeechLocale> build()` | Returns available STT locales; stub list in Phase 0 |

---

### `BaseSettingsNotifier` (abstract, Notifier<AppSettings>)

Concrete subclasses in each app are annotated with `@riverpod`. This abstract base provides the shared implementation.

| Method / Property | Signature | Purpose |
|---|---|---|
| `build` | `AppSettings build()` | Loads persisted settings; returns `AppSettings.defaults()` on first run |
| `setScrollDirection` | `Future<void> setScrollDirection(ScrollDirection direction)` | Updates and persists scroll direction |
| `setTextSize` | `Future<void> setTextSize(double size)` | Updates and persists caption text size |
| `setFontFamily` | `Future<void> setFontFamily(String family)` | Updates and persists selected font family |
| `setContrastMode` | `Future<void> setContrastMode(ContrastMode mode)` | Updates and persists contrast mode |
| `setMaxVisibleLines` | `Future<void> setMaxVisibleLines(int lines)` | Updates max visible caption lines (0 = unlimited) |
| `reset` | `Future<void> reset()` | Resets all settings to defaults |

---

### `RecordingStateNotifier` (Notifier<RecordingState>)

Phase 0: stub transitions only (no STT wiring). Phase 1 completes the implementation.

| Method / Property | Signature | Purpose |
|---|---|---|
| `build` | `RecordingState build()` | Returns `RecordingState.idle` |
| `start` | `Future<void> start({String? localeId})` | Transitions idle → recording; no-op stub in Phase 0 |
| `pause` | `Future<void> pause()` | Transitions recording → paused |
| `resume` | `Future<void> resume()` | Transitions paused → recording |
| `stop` | `Future<void> stop()` | Transitions any → stopped |
| `clearSession` | `void clearSession()` | Transitions stopped → idle; clears accumulated data |
| `state` | `RecordingState get state` | Current recording state |

**Security note**: No method may log, emit, or surface any text content from speech recognition results (SECURITY-03). State transitions (idle, recording, paused, stopped) may be logged at debug level; segment text may not appear in any log output under any circumstances.

---

### `sttEngineProvider` (AsyncNotifier<SttEngine>)

| Method / Property | Signature | Purpose |
|---|---|---|
| `build` | `Future<SttEngine> build()` | Phase 0: throws `UnimplementedError`. Phase 1: returns platform engine. |

---

### `AppSettings` (freezed)

| Field | Type | Default | Purpose |
|---|---|---|---|
| `scrollDirection` | `ScrollDirection` | `bottomToTop` | Caption text flow direction |
| `textSize` | `double` | `24.0` | Caption font size in logical pixels |
| `fontFamily` | `String` | `'default'` | Font family key; `'default'` uses system font |
| `contrastMode` | `ContrastMode` | `ContrastMode.standard` | Caption contrast level |
| `maxVisibleLines` | `int` | `0` | Max caption lines (0 = unlimited) |

Factory: `AppSettings.defaults()` returns the above defaults.

---

### `RecordingState` (sealed class)

| Variant | Fields | Meaning |
|---|---|---|
| `RecordingState.idle()` | — | No active session |
| `RecordingState.recording()` | — | Actively capturing (Phase 1 adds `currentSegment`) |
| `RecordingState.paused()` | — | Session paused |
| `RecordingState.stopped()` | — | Session ended (Phase 1 adds `segments`) |

---

### `SpeechLocale` (freezed)

| Field | Type | Purpose |
|---|---|---|
| `localeId` | `String` | BCP-47 locale identifier (e.g., `en-US`) |
| `displayName` | `String` | Human-readable name in the active display locale |

---

### `AppTheme`

| Method | Signature | Purpose |
|---|---|---|
| `light` | `static ThemeData light()` | Returns Material 3 light theme for both apps |
| `dark` | `static ThemeData dark()` | Returns Material 3 dark theme for both apps |

---

## zip_captions

### `ZipCaptionsSettingsNotifier` (extends `BaseSettingsNotifier`)

Phase 0: No additional methods or fields beyond `BaseSettingsNotifier`. The subclass exists to provide an independent settings store for zip_captions (separate `shared_preferences` key namespace from zip_broadcast).

| Override | Purpose |
|---|---|
| `_prefsKeyPrefix` | Returns `'zip_captions.'` — prefixes all SharedPreferences keys to avoid collisions with zip_broadcast |

---

## zip_broadcast

### `ZipBroadcastSettingsNotifier` (extends `BaseSettingsNotifier`)

Phase 0: No additional methods or fields. Phase 2 will add broadcast-specific settings.

| Override | Purpose |
|---|---|
| `_prefsKeyPrefix` | Returns `'zip_broadcast.'` — prefixes all SharedPreferences keys |
