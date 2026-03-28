# NFR Design Patterns — Unit 2: zip_core Library

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

### Implementation Sketch

```dart
// Individual enum generators — reusable across test suites
final arbitraryScrollDirection = Arbitrary.oneOf(ScrollDirection.values);
final arbitraryCaptionTextSize = Arbitrary.oneOf(CaptionTextSize.values);
final arbitraryCaptionFont = Arbitrary.oneOf(CaptionFont.values);
final arbitraryThemeModeSetting = Arbitrary.oneOf(ThemeModeSetting.values);

// Composed AppSettings generator
// Uses Glados.combine to build from individual generators
// maxVisibleLines: 0 = unlimited, positive int = capped lines
```

### Test Suites Using This Pattern

| Test file | Generator(s) used | Property tested |
|---|---|---|
| `test/pbt/app_settings_roundtrip_test.dart` | `Arbitrary<AppSettings>` | Save to SharedPreferences and reload produces equal `AppSettings` |
| `test/pbt/settings_recovery_test.dart` | Individual enum generators + corruption generator | Per-field recovery with random corruption patterns |
| `test/pbt/locale_roundtrip_test.dart` | `Arbitrary<Locale>` (language codes) | Locale persistence round-trip |
| `test/pbt/speech_locale_properties_test.dart` | `Arbitrary<String>` (localeId patterns) | `languageCode` invariant, equality symmetry |

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

### Generator

```dart
// Generate command sequences of variable length
Arbitrary<List<Command>> arbitraryCommandSequence =
    Arbitrary.list(Arbitrary.oneOf(Command.values), minLength: 0, maxLength: 50);
```

### Test Structure

For each generated command sequence:
1. Create fresh `ProviderContainer` with `RecordingStateNotifier`
2. Initialize model state to `idle`
3. For each command in the sequence:
   a. Apply command to the real notifier
   b. Apply command to the pure-function model
   c. Assert real state matches model state
4. On failure, glados shrinks to the minimal failing sequence

### Properties Verified

| Property | Assertion |
|---|---|
| Model equivalence | Real notifier state == model state after every command |
| Invalid transition no-op | State unchanged when command is invalid for current state |
| Transition determinism | Same command from same state always produces the same next state |

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

### Enumerated Pairs

Tests verify exactly the 16 pairs from `nfr-requirements.md` NFR-U2-05 — 8 dark, 8 light. Each pair is extracted from the `ColorScheme` produced by `AppTheme.dark()` and `AppTheme.light()` respectively.

### Test Organization

File: `test/pbt/theme_contrast_test.dart` (named PBT for organizational consistency, but these are exhaustive enumeration tests since the color pairs are finite and known).

```dart
group('Dark theme WCAG AAA contrast', () {
  final dark = AppTheme.dark().colorScheme;
  test('onSurface on surface >= 7:1', () { ... });
  test('onSurface on surfaceContainerLowest >= 7:1', () { ... });
  // ... 8 pairs total
});

group('Light theme WCAG AAA contrast', () {
  final light = AppTheme.light().colorScheme;
  test('onSurface on surface >= 7:1', () { ... });
  // ... 8 pairs total
});
```

---

## Pattern 4: SharedPreferences Corruption Generator

### Problem

PBT recovery tests need to verify that `BaseSettingsNotifier` handles arbitrary corruption patterns in SharedPreferences — missing keys, wrong types, unrecognized enum names — with per-field fallback to defaults.

### Pattern

Use `SharedPreferences.setMockInitialValues()` with generated corrupt data maps. Each PBT run seeds a fresh mock where each field independently may be: valid, missing, wrong type, or unrecognized value.

### Corruption Categories

| Category | Example | Expected recovery |
|---|---|---|
| Missing key | Key not present in map | Default value for that field |
| Wrong type | `scrollDirection` stored as `int` instead of `String` | Default value |
| Unrecognized enum | `scrollDirection` = `'diagonal'` | Default value |
| Valid value | `scrollDirection` = `'topToBottom'` | Loaded value preserved |

### Generator

```dart
enum FieldState { valid, missing, wrongType, unrecognizedEnum }

// For each of the 5 AppSettings fields, independently generate a FieldState
// Then build the mock initial values map accordingly:
// - valid: write the correct serialized value
// - missing: omit the key
// - wrongType: write an int where String expected, or vice versa
// - unrecognizedEnum: write a plausible but invalid enum name string
```

### Key Property

For any combination of per-field corruption states, the loaded `AppSettings`:
- Has valid values for every field (never null, never out of range)
- Preserves the loaded value for fields with `valid` state
- Uses `AppSettings.defaults()` value for fields with any corruption state
- No exceptions thrown during load

---

## Pattern 5: Locale Round-Trip and Fallback

### Problem

`LocaleProvider` must persist and reload locales correctly, and always return a valid `Locale` regardless of SharedPreferences state.

### Pattern

PBT generates random language codes and verifies the round-trip property. Separately, generates corrupt/missing SharedPreferences states and verifies the fallback chain always produces a non-null `Locale`.

### Properties

| Property | Generator | Assertion |
|---|---|---|
| Round-trip | Random BCP-47 language codes | `setLocale(locale)` then fresh `build()` returns same locale |
| Fallback validity | Random SharedPreferences states (missing, corrupt, empty) | `build()` always returns non-null `Locale` |
