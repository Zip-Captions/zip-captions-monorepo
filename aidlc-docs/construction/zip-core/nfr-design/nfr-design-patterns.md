# NFR Design — Unit 2: zip_core Library

## Testing Stack

| Tool | Role | Version Strategy |
|---|---|---|
| `dart test` / `flutter test` | Test runner | Pinned via Flutter SDK version |
| `glados` | Property-based testing framework | Caret syntax (`^x.y.z`) in dev_dependencies |
| `mocktail` | Mocking library | Caret syntax in dev_dependencies |
| `SharedPreferences.setMockInitialValues()` | SharedPreferences test seeding | Built into `shared_preferences` package |
| `ProviderContainer` | Riverpod provider unit testing | Built into `flutter_riverpod` |

### Test Organization

```
packages/zip_core/test/
  models/
    app_settings_test.dart           # Example-based: defaults, copyWith, equality
    recording_state_test.dart        # Example-based: sealed class pattern matching
    speech_locale_test.dart          # Example-based: languageCode extraction, equality
  providers/
    locale_provider_test.dart        # Example-based: set/get, device fallback
    settings_notifier_test.dart      # Example-based: load, save, reset, corrupt recovery
    recording_state_notifier_test.dart  # Example-based: specific transitions, invalid ops
  theme/
    app_theme_test.dart              # Example-based: theme data not null, contrast checks
  pbt/
    app_settings_roundtrip_test.dart     # PBT: serialize/deserialize round-trip
    settings_recovery_test.dart          # PBT: per-field recovery with random corruption
    recording_state_machine_test.dart    # PBT: stateful model-based testing
    locale_roundtrip_test.dart           # PBT: locale persistence round-trip
    speech_locale_properties_test.dart   # PBT: languageCode invariant, equality
    theme_contrast_test.dart             # PBT: WCAG AAA contrast for all color pairs
```

### Provider Test Strategy

**Unit 2 (zip_core)**: `ProviderContainer`-based unit tests — create per test, seed with `SharedPreferences.setMockInitialValues()`, assert state changes. PBT tests use `glados` with `ProviderContainer`.

**Unit 3+ (app packages)**: `ProviderScope` override-based widget tests — wrap widgets in `ProviderScope(overrides: [...])` with mock notifiers.

**Complementary testing (PBT-10)**: Example-based tests pin specific known scenarios; PBT tests verify general invariants across generated inputs. When PBT discovers a failure, the shrunk case is added as a permanent example-based regression test.

---

## Pattern 1: Composed PBT Generators (glados)

### Problem

Property-based tests for `AppSettings` round-trip, recovery, and reset need to generate arbitrary valid instances. Individual enum generators are also needed for per-field corruption testing.

### Pattern

Compose `Arbitrary<AppSettings>` from individual field generators using `Glados.combine`. Each enum and field type gets its own `Arbitrary<T>` instance, reusable across multiple test suites.

### Generator Hierarchy

```
Arbitrary<ScrollDirection>        — random enum value
Arbitrary<CaptionTextSize>        — random enum value
Arbitrary<CaptionFont>            — random enum value
Arbitrary<ThemeModeSetting>       — random enum value
Arbitrary<int> (maxVisibleLines)  — constrained range [0, 100]
        |
        v
Arbitrary<AppSettings>            — composed via Glados.combine
```

### Testable Properties

| Property | PBT Category | Component | Description |
|---|---|---|---|
| Settings round-trip | PBT-02 Round-trip | AppSettings + BaseSettingsNotifier | For any valid `AppSettings`, saving to SharedPreferences and reloading produces an equal `AppSettings` |
| Defaults validity | PBT-03 Invariant | AppSettings | `AppSettings.defaults()` produces values within all defined ranges/enum sets |
| Per-field recovery | PBT-03 Invariant | BaseSettingsNotifier | When any subset of SharedPreferences keys contains corrupt data, the loaded `AppSettings` still has valid values for every field |
| Reset idempotence | PBT-04 Idempotence | BaseSettingsNotifier | `reset()` called twice produces the same state as calling it once |

---

## Pattern 2: Stateful Model-Based Testing (RecordingStateNotifier)

### Problem

The recording state machine has 5 commands and 4 states with specific valid/invalid transition rules. Need to verify that random command sequences produce identical behavior in the real notifier and a simplified model.

### Pattern

Generate random `List<Command>` sequences of variable length (1-50, including empty sequences as edge cases). Execute each command against both the real `RecordingStateNotifier` (via `ProviderContainer`) and a pure-function model. Assert state equality at each step.

### Model Definition

```dart
enum Command { start, pause, resume, stop, clearSession }

// Pure-function model — mirrors BR-01 transition table
ModelState applyCommand(ModelState current, Command cmd) {
  return switch ((current, cmd)) {
    (ModelState.idle, Command.start)          => ModelState.recording,
    (ModelState.recording, Command.pause)     => ModelState.paused,
    (ModelState.paused, Command.resume)        => ModelState.recording,
    (ModelState.recording, Command.stop)       => ModelState.stopped,
    (ModelState.paused, Command.stop)          => ModelState.stopped,
    (ModelState.stopped, Command.clearSession) => ModelState.idle,
    _                                          => current, // invalid = no-op
  };
}
```

### Testable Properties

| Property | PBT Category | Description |
|---|---|---|
| Stateful model equivalence | PBT-06 Stateful | Random command sequences applied to both real notifier and model produce identical state at each step |
| Invalid transition no-op | PBT-03 Invariant | Any action called from an invalid state leaves the state unchanged |
| Transition determinism | PBT-03 Invariant | The same action from the same state always produces the same next state |

---

## Pattern 3: WCAG AAA Contrast Verification

### Problem

Both dark and light themes must achieve 7:1 contrast ratio for all text-on-surface color pairs. 16 pairs total (8 per theme).

### Pattern

Implement a `contrastRatio(Color foreground, Color background)` utility function in test code. Assert each enumerated pair individually. The utility computes relative luminance per WCAG 2.1 formula and returns the contrast ratio.

### Contrast Ratio Computation

```dart
double relativeLuminance(Color color) {
  double r = _linearize(color.red / 255.0);
  double g = _linearize(color.green / 255.0);
  double b = _linearize(color.blue / 255.0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _linearize(double channel) {
  return channel <= 0.04045
      ? channel / 12.92
      : pow((channel + 0.055) / 1.055, 2.4);
}

double contrastRatio(Color foreground, Color background) {
  double lum1 = relativeLuminance(foreground);
  double lum2 = relativeLuminance(background);
  double lighter = max(lum1, lum2);
  double darker = min(lum1, lum2);
  return (lighter + 0.05) / (darker + 0.05);
}
```

### Verified Color Pairs

Tests verify exactly 16 pairs — 8 dark, 8 light — extracted from `AppTheme.dark()` and `AppTheme.light()` `ColorScheme` instances. See `business-logic-model.md` for full color token tables.

---

## Pattern 4: SharedPreferences Corruption Generator

### Problem

PBT recovery tests need to verify that `BaseSettingsNotifier` handles arbitrary corruption patterns in SharedPreferences — missing keys, wrong types, unrecognized enum names — with per-field fallback to defaults.

### Pattern

Use `SharedPreferences.setMockInitialValues()` with generated corrupt data maps. Each PBT run seeds a fresh mock where each field independently may be: valid, missing, wrong type, or unrecognized value.

### Corruption Categories

| Category | Example | Expected Recovery |
|---|---|---|
| Missing key | Key not present in map | Default value for that field |
| Wrong type | `scrollDirection` stored as `int` instead of `String` | Default value |
| Unrecognized enum | `scrollDirection` = `'diagonal'` | Default value |
| Valid value | `scrollDirection` = `'topToBottom'` | Loaded value preserved |

### Key Property

For any combination of per-field corruption states, the loaded `AppSettings` has valid values for every field (never null, never out of range), preserves loaded values for valid fields, uses defaults for corrupt fields, and throws no exceptions during load.

---

## Pattern 5: Locale Round-Trip and Fallback

### Problem

`LocaleProvider` must persist and reload locales correctly, and always return a valid `Locale` regardless of SharedPreferences state.

### Properties

| Property | Generator | Assertion |
|---|---|---|
| Round-trip | Random BCP-47 language codes | `setLocale(locale)` then fresh `build()` returns same locale |
| Fallback validity | Random SharedPreferences states (missing, corrupt, empty) | `build()` always returns non-null `Locale` |

### SpeechLocale Properties

| Property | PBT Category | Description |
|---|---|---|
| languageCode extraction | PBT-03 Invariant | For any non-empty `localeId`, `languageCode` returns a non-empty string |
| Equality symmetry | PBT-03 Invariant | `SpeechLocale(a) == SpeechLocale(b)` if and only if `a.toLowerCase() == b.toLowerCase()` |

---

## Accessibility — WCAG AAA Contrast (Hard NFR)

**Requirement**: `AppTheme` must produce `ColorScheme` values where all text-on-surface color combinations achieve a minimum **7:1 contrast ratio** (WCAG AAA).

**Light theme adjustment**: The design spec's `primary` (#427EB5, luminance ~0.19) is a mid-tone that cannot achieve 7:1 with any text color. Darkened to `#1A5A8C` for AAA compliance. Standard Material error red also fails AAA on light surfaces; set to `#A8191F` (~7.2:1).

**Typography constraint**: Minimum font weight 500 for text smaller than 14px (from design spec). Enforced by `AppTheme`'s `TextTheme` definition.

---

## Dependency Approvals

### Approved (new for Unit 2)

| Package | Purpose | Justification |
|---|---|---|
| `shared_preferences` | Settings and locale persistence | First-party Flutter plugin (Flutter Favorite). Cross-platform key-value store. |

### Bundled Font Assets (no package dependency)

8 v1 caption fonts bundled as `.ttf` files in app packages (zip_captions, zip_broadcast), not in zip_core. zip_core defines the `CaptionFont` enum with font family name mappings. All fonts sourced from Google Fonts under OFL license. No `google_fonts` runtime dependency — offline-first.

### Existing Approved Dependencies

| Package | Used For |
|---|---|
| `flutter_riverpod` / `riverpod_generator` | State management, provider code generation |
| `freezed` / `freezed_annotation` | Immutable data classes (AppSettings, SpeechLocale) |
| `mocktail` | Test mocking |
| `very_good_analysis` | Linting |

### Dev Dependencies

| Package | Purpose |
|---|---|
| `glados` | PBT framework (PBT-09) |
| `build_runner` | Code generation for riverpod_generator and freezed |

---

## Security Assessment

### Applicable Rules

| Rule | Status | Assessment |
|---|---|---|
| SECURITY-03 (Application Logging) | Compliant | Transcript logging prohibition established (SR-01, SR-02, SR-03). State transitions and operational metrics may be logged at debug level. |
| SECURITY-09 (Hardening) | Compliant | No credentials or secrets in zip_core. SharedPreferences stores user preferences only. |
| SECURITY-10 (Supply Chain) | Compliant | All dependencies from pub.dev (official registry). Lock files committed. `glados` is dev-only. Bundled .ttf fonts sourced from Google Fonts (OFL licensed). |
| SECURITY-15 (Exception Handling) | Compliant | BaseSettingsNotifier uses per-field recovery with fail-safe defaults (BR-05). RecordingStateNotifier uses severity-based error handling. Invalid state transitions silently ignored. |

### N/A Rules

SECURITY-01, -02, -04, -05, -06, -07, -08, -11, -12, -13, -14 are not applicable to zip_core in Phase 0 (no network, no auth, no API endpoints, no deployment).

---

## Key Decisions Log

| Decision | Choice | Rationale |
|---|---|---|
| PBT framework | `glados` | Custom generators, shrinking, seed reproducibility, dart test integration |
| Font loading | Bundled .ttf assets | Offline-first; no runtime network dependency; predictable |
| Settings persistence | `shared_preferences` | First-party Flutter plugin; cross-platform; simple key-value; PoC precedent |
| Provider testing | `ProviderContainer` (unit) + `ProviderScope` (widget) | Clean separation: library tests logic, apps test integration |
| Contrast target | WCAG AAA (7:1) hard NFR | Design spec mandates it; accessibility is a core product value |
| Test separation | `test/` (example-based) + `test/pbt/` (property-based) | Clear distinction per PBT-10; easy to run selectively |
