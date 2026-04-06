# Business Logic Model — Unit 2: zip_core Library

## 1. RecordingStateNotifier — State Machine

### State Transition Table

| Current State | Action | Next State | Guard / Precondition |
|---|---|---|---|
| `idle` | `start()` | `recording` | Phase 0: unconditional stub. Phase 1: SttEngine.initialize() succeeds, permissions granted |
| `recording` | `pause()` | `paused` | Must be in `recording` state |
| `paused` | `resume()` | `recording` | Must be in `paused` state |
| `recording` | `stop()` | `stopped` | Must be in `recording` state |
| `paused` | `stop()` | `stopped` | Must be in `paused` state |
| `stopped` | `clearSession()` | `idle` | Must be in `stopped` state |
| `idle` | `pause()` | no-op | Invalid; ignore silently |
| `idle` | `resume()` | no-op | Invalid; ignore silently |
| `idle` | `stop()` | no-op | Invalid; ignore silently |
| `idle` | `clearSession()` | no-op | Already idle |
| `recording` | `start()` | no-op | Already recording |
| `recording` | `resume()` | no-op | Not paused |
| `recording` | `clearSession()` | no-op | Must stop first |
| `paused` | `start()` | no-op | Must stop and clear first |
| `paused` | `pause()` | no-op | Already paused |
| `paused` | `clearSession()` | no-op | Must stop first |
| `stopped` | `start()` | no-op | Must clear first |
| `stopped` | `pause()` | no-op | Not recording |
| `stopped` | `resume()` | no-op | Not paused |

### State Diagram

```
         start()
idle ──────────────> recording
  ^                   |     ^
  |                   |     |
  |          pause()  |     | resume()
  |                   v     |
  |                  paused
  |                   |
  |        stop()     | stop()
  |        (from      | (from
  |        recording) | paused)
  |                   v
  |                 stopped
  |                   |
  +───────────────────+
      clearSession()
```

### Error Handling

Errors are **separate from the state machine**. The notifier holds an optional `RecordingError` alongside the current state.

**Fatal errors** (severity: `fatal`):
- Trigger a state transition to `idle` (recording cannot continue)
- The `RecordingError` is preserved until `clearSession()` is called or a new `start()` succeeds
- Example: microphone permission revoked mid-session, STT engine crash

**Transient errors** (severity: `transient`):
- Do NOT change the current state
- The `RecordingError` is surfaced to the UI for display
- Cleared automatically on the next successful state transition
- Example: brief network hiccup in a cloud STT fallback, temporary audio buffer underrun

**Error field on the notifier**: `RecordingError? lastError`
- Watchable by the UI via a separate provider or as part of a composite state exposed by the notifier
- Cleared on: successful `start()`, successful `clearSession()`, or when a transient error is superseded

### Phase 0 Stub Behavior

All methods perform state transitions only (no STT wiring):
- `start()`: immediately transitions `idle` -> `recording`
- `pause()`: immediately transitions `recording` -> `paused`
- `resume()`: immediately transitions `paused` -> `recording`
- `stop()`: immediately transitions `recording|paused` -> `stopped`
- `clearSession()`: immediately transitions `stopped` -> `idle`, clears `lastError`
- No errors are generated in Phase 0 (no real STT to fail)

### Phase 1 Hooks (documented for forward compatibility, not implemented)

- `start()` will call `SttEngine.initialize()` and `startListening()`, handling async results
- `stop()` will call `SttEngine.stopListening()` and accumulate final segments
- `onError` callback from `SttEngine` will create `RecordingError` with appropriate severity

---

## 2. BaseSettingsNotifier — Persistence Model

### Architecture

`BaseSettingsNotifier` is an abstract Dart class (not directly `@riverpod`-annotated). Each app creates a concrete subclass annotated with `@riverpod`, which gives each app its own independent Riverpod provider and SharedPreferences namespace.

### Key Prefix Mechanism

Abstract getter: `String get keyPrefix;`

Each subclass overrides this to return its app-specific prefix:
- `ZipCaptionsSettingsNotifier` returns `'zip_captions'`
- `ZipBroadcastSettingsNotifier` returns `'zip_broadcast'`

Full SharedPreferences key format: `{keyPrefix}.{fieldName}`

### SharedPreferences Key Map

| Field | Key suffix | Storage type | Serialization |
|---|---|---|---|
| `scrollDirection` | `.scrollDirection` | `String` | Enum name (e.g., `'bottomToTop'`) |
| `captionTextSize` | `.captionTextSize` | `String` | Enum name (e.g., `'md'`) |
| `captionFont` | `.captionFont` | `String` | Enum name (e.g., `'atkinsonHyperlegible'`) |
| `themeModeSetting` | `.themeModeSetting` | `String` | Enum name (e.g., `'system'`) |
| `maxVisibleLines` | `.maxVisibleLines` | `int` | Integer value |

Example full key: `zip_captions.scrollDirection`

### Load Lifecycle (`build()`)

1. Obtain `SharedPreferences` instance
2. For each field in `AppSettings`:
   a. Read the value from SharedPreferences using `{keyPrefix}.{fieldName}`
   b. Attempt to deserialize (parse enum name for enums, read int for int)
   c. On success: use the loaded value
   d. On failure (key missing, corrupt value, unrecognized enum name): use `AppSettings.defaults()` value for that field; log a debug-level warning (field name and failure reason only — never log the corrupt value itself, it could contain user data)
3. Construct and return `AppSettings` from loaded/default values

### Save Lifecycle (setter methods)

Each setter method (e.g., `setScrollDirection(ScrollDirection direction)`):
1. Write the new value to SharedPreferences using the appropriate key
2. `await` the write to ensure persistence
3. Update state with a `copyWith()` of the current `AppSettings`

### Reset

`reset()`:
1. Remove all keys with the current `keyPrefix` from SharedPreferences
2. Set state to `AppSettings.defaults()`

---

## 3. LocaleProvider — Display Locale Management

### Responsibility

Manages the user's selected **display locale** (language for UI strings). This is a top-level language code only (e.g., `en`, `fr`, `de`), not a regional variant.

### Persistence

| Key | Storage type | Value |
|---|---|---|
| `app_locale` | `String?` | Language code (e.g., `'en'`, `'fr'`). Null = system default. |

### Load Lifecycle (`build()`)

1. Read `app_locale` from SharedPreferences
2. If present and valid: return `Locale(languageCode)`
3. If absent or invalid: return device locale via `PlatformDispatcher.instance.locale`

### `setLocale(Locale locale)`

1. Write `locale.languageCode` to SharedPreferences key `app_locale`
2. Update state with the new `Locale`

### Validation

- Accept any BCP-47 language code; no whitelist (the app's l10n system falls back to English for unsupported locales)
- Null/empty stored value triggers device locale fallback

---

## 4. SpeechLocaleProvider (Phase 0: Stub)

### Responsibility

Manages the user's selected **speech recognition locale**. This is separate from `LocaleProvider` because STT locale requirements vary significantly across engines:

- Some engines accept **language only** (e.g., `en`) and handle regional variation internally
- Some engines accept language and offer **optional regional variants** (e.g., `en` or `en-US`)
- Some engines **require** a language + region pair (e.g., `en-US`, `en-GB` as distinct entries)

The `SpeechLocale` model must accommodate all three patterns. The `localeId` field stores whatever the engine provides — it may be language-only, language-region, or a more complex identifier. The provider does not enforce a format; it passes through what the active `SttEngine` reports.

### Phase 0 Behavior

- Returns a stub/placeholder `SpeechLocale` (e.g., `SpeechLocale(localeId: 'en-US', displayName: 'English (United States)')`)
- No persistence in Phase 0 — the selected speech locale is only meaningful when STT is wired up in Phase 1
- Provider exists with the correct interface so Phase 1 can implement without breaking changes

### Selection Flow: Language-First, Then Region

Speech locale selection is a one- or two-step process:

1. **Step 1 — Language**: Present a list of distinct languages derived from available locales (grouped by `languageCode`). The user picks a language (e.g., "English", "French").
2. **Step 2 — Region (conditional)**: If the selected language has multiple regional variants available from the engine, present them for selection (e.g., "English (United States)", "English (United Kingdom)"). If only one variant exists, skip this step and auto-select it.

This means the provider exposes two pieces of derived data:
- `availableLanguages`: distinct language codes from the current engine's locale list, with a display name for each
- `regionsForLanguage(String languageCode)`: filtered list of `SpeechLocale` entries matching that language; returns a single-element list if no regional choice exists

The UI consumes these to render a one- or two-step picker. The model and provider are unaware of the UI — they expose the grouped data and accept a final `SpeechLocale` selection.

### Phase 1 Behavior (documented for forward compatibility)

- Queries `SttEngine.getAvailableLocales()` to populate available options
- Each `SttEngine` implementation is responsible for returning the locales it supports in whatever granularity is appropriate for that engine
- Groups locales by `languageCode` to support the language-first selection flow
- Persists the selected `SpeechLocale.localeId` to SharedPreferences
- Falls back to device locale if no selection persisted
- When matching a persisted locale against available locales, uses a fallback chain: exact match -> language-only match -> device locale -> first available

---

## 5. LocaleInfoProvider (Phase 0: Stub)

### Responsibility

Exposes the list of locales available for speech recognition.

### Phase 0 Behavior

- Returns an empty `List<SpeechLocale>` (no STT engine to query)
- Auto-dispose provider; recalculated when accessed

### Phase 1 Behavior

- Queries `SttEngine.getAvailableLocales()`
- Caches result to avoid repeated platform calls

---

## 6. sttEngineProvider (Phase 0: Stub)

### Phase 0 Behavior

- `AsyncNotifier<SttEngine>` that throws `UnimplementedError('STT engine implementation is Phase 1')`
- Exists to establish the provider graph; consumers can reference it without compilation errors

---

## 7. AppTheme — Theme Factory

### Architecture

`AppTheme` is a static utility class (not a provider) that produces `ThemeData` instances. Both apps consume the same theme factory.

### Theme Modes

The app supports three theme modes via `ThemeModeSetting`:
- `system`: follows OS preference
- `dark`: Monolith Editorial dark palette
- `light`: Monolith Editorial light palette

### Dark Theme — Monolith Editorial

Color tokens (from design spec):

| Token | Hex | Usage |
|---|---|---|
| `surface` | `#0B141D` | Primary canvas (Foundation) |
| `surfaceContainerLowest` | `#060F18` | Carved-out areas, sidebars (Inset) |
| `surfaceContainerHigh` | `#222B34` | Cards, interactive modules (Plinth) |
| `surfaceContainerHighest` | `#2D3640` | Elevated cards, input fields |
| `primary` | `#9ACBFF` | Primary actions, focus indicators (AAA-compliant on dark) |
| `onPrimary` | `#003355` | Text on primary surfaces |
| `secondaryContainer` | `#414A54` | Secondary buttons |
| `onSecondaryContainer` | `#E0E8F2` | Text on secondary containers (lightened from spec #B0B9C6 for AAA) |
| `onSurface` | `#DAE3F0` | Primary text on surfaces (7:1 target) |
| `outline` | `#8B919A` | High-contrast edge for floating elements |
| `outlineVariant` | `#41474F` | Ghost borders (20% opacity max) |
| `error` | `#FFB4AB` | Error states |
| `inverseSurface` | `#DAE3F0` | Tooltip/overlay background |
| `inverseOnSurface` | `#28313B` | Tooltip/overlay text |

Typography: Inter as UI chrome font. Minimum weight 500 for text below 14px. Letter-spacing +0.05em for label-sm and label-md.

Design rules: No gradients. No 1px borders for sectioning (tonal layering only). Ambient shadows only (no drop shadows).

### Light Theme — Monolith Editorial

**Design spec seed tokens**: `primary: #427EB5`, `secondary: #DAE3F0`, `tertiary: #FFFFFF`, `neutral: #0B141D`.

**AAA adjustment**: The spec's `primary` (#427EB5, relative luminance ~0.19) is a mid-tone that cannot achieve 7:1 contrast with any text color. Darkened to `#1A5A8C` (luminance ~0.094) for AAA compliance with white `onPrimary`. The original `#427EB5` is preserved as a reference color but is not used in the `ColorScheme`. Similarly, standard Material error red fails AAA on light surfaces; `error` is set to `#A8191F` (~7.2:1 on light surfaces).

Color tokens (full Material 3 ColorScheme):

| Token | Hex | Usage | Derivation |
|---|---|---|---|
| `surface` | `#FAFCFF` | Primary canvas | Near-white with slight blue tint from palette |
| `surfaceContainerLowest` | `#FFFFFF` | Inset areas | Spec tertiary (pure white) |
| `surfaceContainerHigh` | `#EEF2F8` | Cards, interactive modules | Midpoint between white and secondary |
| `surfaceContainerHighest` | `#E4EAF2` | Elevated cards, input fields | Slightly darker tint |
| `primary` | `#1A5A8C` | Primary actions, focus indicators | Darkened from spec #427EB5 for AAA |
| `onPrimary` | `#FFFFFF` | Text on primary surfaces | White on darkened primary |
| `secondaryContainer` | `#DAE3F0` | Secondary surfaces | Spec secondary (direct) |
| `onSecondaryContainer` | `#0B141D` | Text on secondary containers | Spec neutral |
| `onSurface` | `#0B141D` | Primary text on surfaces (7:1+ target) | Spec neutral |
| `outline` | `#6B7380` | High-contrast edge for floating elements | Medium grey from palette |
| `outlineVariant` | `#C4CAD4` | Ghost borders | Light grey from palette |
| `error` | `#A8191F` | Error states | Darkened for AAA on light surfaces |
| `inverseSurface` | `#0B141D` | Tooltip/overlay background | Spec neutral |
| `inverseOnSurface` | `#DAE3F0` | Tooltip/overlay text | Spec secondary |

Shape: Subtle roundedness (small border radius). Spacing: Normal density.

Typography: Inter for all UI chrome. Same weight and tracking rules as dark theme.

### Caption Text Rendering

Caption display uses the user-selected `CaptionFont` from `AppSettings`, resolved to the actual font family at render time. The `CaptionTextSize` enum maps to a `TextTheme` style which provides the base `TextStyle`; the font family is overridden with the user's selection.

```
Final caption TextStyle = TextTheme[captionTextSize.textThemeStyle].copyWith(
  fontFamily: captionFont.fontFamily,  // from google_fonts or bundled asset
)
```
