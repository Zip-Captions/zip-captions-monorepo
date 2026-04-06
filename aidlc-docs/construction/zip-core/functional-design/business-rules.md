# Business Rules — Unit 2: zip_core Library

## BR-01: Recording State Machine Transition Rules

**Rule**: State transitions are guarded by the current state. Invalid transitions are silently ignored (no exception, no error).

| From | Valid actions | Invalid actions (ignored) |
|---|---|---|
| `idle` | `start` | `pause`, `resume`, `stop`, `clearSession` |
| `recording` | `pause`, `stop` | `start`, `resume`, `clearSession` |
| `paused` | `resume`, `stop` | `start`, `pause`, `clearSession` |
| `stopped` | `clearSession` | `start`, `pause`, `resume`, `stop` |

**Rationale**: Silent ignore prevents UI race conditions (e.g., user double-taps a button). The UI should disable invalid actions, but the state machine must be safe regardless.

---

## BR-02: Pause/Resume Workflow

**Rule**: Pause and resume are a core user workflow. The state machine supports unlimited pause/resume cycles within a single recording session without requiring stop and clear.

**Rule**: Each pause/resume cycle produces a `PauseEvent` that is accumulated in the session data. Pause events are included in transcript exports as visible markers (e.g., `[Paused 00:12 - 00:47]`) so that consumers of the export understand where intentional gaps exist.

**Rule**: If `stop()` is called while in `paused` state, the final `PauseEvent` has `resumedAt` = null, indicating the session ended during a pause.

**Phase 0**: `PauseEvent` model is defined; pause events are not accumulated (stub state machine has no real timeline). Phase 1: `RecordingStateNotifier` creates a `PauseEvent` on each `pause()` call and completes it on `resume()`.

---

## BR-03: Recording Error Severity Rules

**Rule**: Fatal errors halt recording; transient errors do not.

- **Fatal error**: transitions state to `idle`; `lastError` preserved until `clearSession()` or successful `start()`
- **Transient error**: state unchanged; `lastError` set; cleared on next successful state transition

**Rule**: Error messages must never contain transcript text content. Only operational information (permission status, engine state, connection status) is permitted.

---

## BR-04: AppSettings Defaults

**Rule**: Every `AppSettings` field has a defined default. `AppSettings.defaults()` is the single source of truth for initial values.

| Field | Default | Rationale |
|---|---|---|
| `scrollDirection` | `bottomToTop` | Matches natural reading flow; PoC default |
| `captionTextSize` | `md` | Middle tier; maps to `headlineSmall` (~24sp) |
| `captionFont` | `atkinsonHyperlegible` | Designed for maximum legibility; v1 default |
| `themeModeSetting` | `system` | Respects OS preference; least surprising |
| `maxVisibleLines` | `0` (unlimited) | Show all captions; PoC default |

---

## BR-05: Settings Persistence Recovery

**Rule**: When loading persisted settings, each field is recovered independently (per-field fallback).

- If a SharedPreferences key is missing: use the default for that field
- If a value cannot be deserialized (unrecognized enum name, wrong type): use the default for that field
- Successfully loaded fields are preserved even if other fields fail
- A debug-level warning is logged for each recovery event. The warning includes the field name and failure reason only. It must never include the corrupt value itself (defense in depth against data leakage).

---

## BR-06: Locale Fallback Chain

**Rule**: Display locale resolution follows this priority:

1. User-persisted locale (SharedPreferences key `app_locale`)
2. Device locale (`PlatformDispatcher.instance.locale`)
3. English (`en`) as ultimate fallback

**Rule**: Display locale uses top-level language codes only (e.g., `en`, not `en-US`). Regional variants are not relevant for UI string resolution — the l10n system handles regional fallback internally.

---

## BR-07: Speech Locale Selection Flow

**Rule**: Speech locale selection is language-first. The user selects a language, then a regional variant only if more than one is available from the active STT engine.

- If the engine offers `en-US`, `en-GB`, `en-AU`: user picks "English", then picks from US/GB/AU
- If the engine offers `fr` (no regional variants): user picks "French" and selection is complete (one step)
- If the engine offers `es-ES`, `es-MX`: user picks "Spanish", then picks from ES/MX

**Rule**: When only one regional variant exists for a language, the region step is skipped and the sole variant is auto-selected.

---

## BR-08: Speech Locale Format and Matching

**Rule**: Speech locale identifiers are engine-dependent. The `localeId` field stores whatever the active `SttEngine` reports — it may be language-only (`en`), language-region with hyphen (`en-US`), language-region with underscore (`en_US`), or an engine-specific format. The model treats `localeId` as an opaque key; no format is enforced.

**Rule**: `SpeechLocale` equality is determined by `localeId` (case-insensitive comparison).

**Rule**: When matching a persisted speech locale against available locales (e.g., after an engine change or app update), the fallback chain is:
1. Exact `localeId` match (case-insensitive)
2. Language-code match (extracted via `languageCode` computed property) — pick the first available locale with the same language
3. Device locale language match
4. First available locale from the engine

---

## BR-09: Theme Mode Application

**Rule**: `ThemeModeSetting` maps to Flutter's `ThemeMode` at the widget layer:

| `ThemeModeSetting` | Flutter `ThemeMode` |
|---|---|
| `system` | `ThemeMode.system` |
| `dark` | `ThemeMode.dark` |
| `light` | `ThemeMode.light` |

**Rule**: `MaterialApp` must receive both `theme` (light) and `darkTheme` (dark) from `AppTheme`, plus `themeMode` from the user's setting. This ensures system mode works correctly.

---

## BR-10: Caption Text Size Resolution

**Rule**: `CaptionTextSize` enum values resolve to Material 3 `TextTheme` style names at render time.

| Enum value | TextTheme getter |
|---|---|
| `xs` | `textTheme.bodySmall` |
| `sm` | `textTheme.bodyLarge` |
| `md` | `textTheme.headlineSmall` |
| `lg` | `textTheme.headlineMedium` |
| `xl` | `textTheme.headlineLarge` |
| `xxl` | `textTheme.displaySmall` |

**Rule**: The resolved `TextStyle` is further modified with the user's `CaptionFont` selection. System accessibility scaling (`MediaQuery.textScaleFactor`) is inherited from the `TextTheme` style automatically.

---

## BR-11: SharedPreferences Key Namespace

**Rule**: All SharedPreferences keys are prefixed with the app-specific `keyPrefix` from `BaseSettingsNotifier`, followed by a dot separator.

Format: `{keyPrefix}.{fieldName}`

Examples:
- `zip_captions.scrollDirection`
- `zip_broadcast.captionFont`

**Rule**: The `LocaleProvider` uses an unprefixed key (`app_locale`) because the display locale is shared across both apps when installed on the same device. This is intentional — a user who sets French as their display language expects both apps to respect that choice.

---

## BR-12: Dependency Approval Required

**Rule**: The following dependency is required for Unit 2 and is NOT on the current approved list (`docs/04-technical-specification.md` Section 6):

| Package | Purpose | Justification |
|---|---|---|
| `google_fonts` | Cross-platform caption font loading | All 8 v1 fonts are Google Fonts; package provides consistent rendering across iOS, Android, macOS, Windows, Linux, web with runtime caching. Alternative: manually bundle `.ttf` files (more maintenance, same result). |
| `shared_preferences` | Settings and locale persistence | Used by PoC; referenced throughout inception design. Implicitly approved but not listed in Section 6. |

These require human approval before Code Generation.

---

## Security Rules (SECURITY-03 / AGENTS.md Absolute Constraint)

### SR-01: Transcript Content Prohibition

**Rule**: Transcript text content must NEVER appear in:
- Log output at any level (debug, info, warning, error)
- Error messages (including `RecordingError.message`)
- Analytics or telemetry events
- Crash reports or stack traces
- SharedPreferences or any persistence layer not explicitly designed for transcript storage

**What MAY be logged**:
- State transitions: `"RecordingState: idle -> recording"`
- Error categories: `"STT engine error: permission denied"`
- Operational metrics: `"Session duration: 45s"`, `"Segments finalized: 12"`
- Settings changes: `"captionTextSize changed to lg"`

**What MUST NOT be logged**:
- Interim or final speech recognition results
- Segment text content
- Any string that originated from the STT engine's text output callbacks

### SR-02: Error Message Content

**Rule**: `RecordingError.message` must contain only operational information. It must never include text recognized by the STT engine. Error messages describe the failure mode, not the content being processed when the failure occurred.

### SR-03: Debug Warning Content (Settings Recovery)

**Rule**: When `BaseSettingsNotifier` logs a debug warning for corrupt persisted data, the warning must include only the field name and failure reason (e.g., `"Failed to load captionFont: unrecognized value"`). The corrupt value itself must not be included in the log message.
