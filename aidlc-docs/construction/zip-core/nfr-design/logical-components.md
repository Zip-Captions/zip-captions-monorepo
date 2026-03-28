# Logical Components — Unit 2: zip_core Library

## Overview

Unit 2 is a Dart library package with no network, deployment, or infrastructure components. The logical components below are test infrastructure elements that support the NFR design patterns.

---

## LC-01: PBT Generator Library

**Location**: `packages/zip_core/test/helpers/generators.dart`

**Purpose**: Centralized glados `Arbitrary<T>` instances for all domain types. Imported by PBT test files.

**Contents**:

| Generator | Type | Strategy |
|---|---|---|
| `arbitraryScrollDirection` | `Arbitrary<ScrollDirection>` | `oneOf(ScrollDirection.values)` |
| `arbitraryCaptionTextSize` | `Arbitrary<CaptionTextSize>` | `oneOf(CaptionTextSize.values)` |
| `arbitraryCaptionFont` | `Arbitrary<CaptionFont>` | `oneOf(CaptionFont.values)` |
| `arbitraryThemeModeSetting` | `Arbitrary<ThemeModeSetting>` | `oneOf(ThemeModeSetting.values)` |
| `arbitraryAppSettings` | `Arbitrary<AppSettings>` | Composed via `Glados.combine` from above |
| `arbitraryCommand` | `Arbitrary<Command>` | `oneOf(Command.values)` |
| `arbitraryCommandSequence` | `Arbitrary<List<Command>>` | `list(arbitraryCommand, minLength: 0, maxLength: 50)` |
| `arbitraryLocaleId` | `Arbitrary<String>` | Language codes, language-region pairs, edge cases |
| `arbitraryFieldState` | `Arbitrary<FieldState>` | `oneOf(FieldState.values)` — valid/missing/wrongType/unrecognizedEnum |

**Design note**: Generators are not part of the production code. They live in `test/helpers/` and are dev-only. The `Command` enum and `FieldState` enum are test-only types defined alongside the generators.

---

## LC-02: State Machine Model

**Location**: `packages/zip_core/test/helpers/recording_state_model.dart`

**Purpose**: Pure-function reference model for `RecordingStateNotifier`. Used by PBT-06 stateful model-based tests to verify the real notifier matches expected behavior.

**Contents**:

```dart
enum ModelState { idle, recording, paused, stopped }
enum Command { start, pause, resume, stop, clearSession }

ModelState applyCommand(ModelState current, Command cmd) { ... }
```

**Design note**: The model is intentionally minimal — a single pure function implementing the BR-01 transition table. It has no dependencies on Riverpod, SharedPreferences, or any production code. This separation ensures the model cannot accidentally share bugs with the implementation.

---

## LC-03: Contrast Ratio Utility

**Location**: `packages/zip_core/test/helpers/contrast_utils.dart`

**Purpose**: WCAG 2.1 relative luminance and contrast ratio computation for theme tests.

**Contents**:

| Function | Signature | Purpose |
|---|---|---|
| `relativeLuminance` | `double relativeLuminance(Color color)` | Compute relative luminance per WCAG 2.1 |
| `contrastRatio` | `double contrastRatio(Color foreground, Color background)` | Compute contrast ratio between two colors |

**Design note**: Test-only utility. Not exported from zip_core. Uses the standard sRGB linearization formula. Returns a ratio >= 1.0 (always lighter/darker ordered).

---

## LC-04: SharedPreferences Test Helpers

**Location**: `packages/zip_core/test/helpers/prefs_helpers.dart`

**Purpose**: Utilities for seeding `SharedPreferences.setMockInitialValues()` with valid, corrupt, and partial data maps for settings persistence tests.

**Contents**:

| Function | Purpose |
|---|---|
| `validPrefsMap(String keyPrefix, AppSettings settings)` | Builds a complete, valid mock values map from an `AppSettings` instance |
| `corruptPrefsMap(String keyPrefix, Map<String, FieldState> fieldStates, AppSettings validSource)` | Builds a mock values map where each field is independently valid, missing, wrong-typed, or unrecognized based on the `fieldStates` map |

**Design note**: These helpers bridge the gap between glados-generated `AppSettings` / `FieldState` values and the `Map<String, Object>` that `setMockInitialValues()` expects. They encode the serialization format (enum name strings, int values) so test assertions can focus on the recovery property.

---

## Test File Map

Maps logical components to the test files that consume them.

| Test file | LC-01 Generators | LC-02 Model | LC-03 Contrast | LC-04 Prefs |
|---|---|---|---|---|
| `test/pbt/app_settings_roundtrip_test.dart` | `arbitraryAppSettings` | | | `validPrefsMap` |
| `test/pbt/settings_recovery_test.dart` | `arbitraryAppSettings`, `arbitraryFieldState` | | | `corruptPrefsMap` |
| `test/pbt/recording_state_machine_test.dart` | `arbitraryCommandSequence` | `applyCommand` | | |
| `test/pbt/locale_roundtrip_test.dart` | `arbitraryLocaleId` | | | |
| `test/pbt/speech_locale_properties_test.dart` | `arbitraryLocaleId` | | | |
| `test/pbt/theme_contrast_test.dart` | | | `contrastRatio` | |
| `test/models/app_settings_test.dart` | | | | |
| `test/models/recording_state_test.dart` | | | | |
| `test/providers/settings_notifier_test.dart` | | | | `validPrefsMap` |
| `test/providers/locale_provider_test.dart` | | | | |
| `test/providers/recording_state_notifier_test.dart` | | `applyCommand` (regression) | | |
| `test/theme/app_theme_test.dart` | | | `contrastRatio` | |

---

## Directory Structure

```
packages/zip_core/test/
  helpers/
    generators.dart              # LC-01: PBT generators
    recording_state_model.dart   # LC-02: State machine model
    contrast_utils.dart          # LC-03: WCAG contrast utilities
    prefs_helpers.dart           # LC-04: SharedPreferences test helpers
  models/
    app_settings_test.dart
    recording_state_test.dart
    speech_locale_test.dart
  providers/
    locale_provider_test.dart
    settings_notifier_test.dart
    recording_state_notifier_test.dart
  theme/
    app_theme_test.dart
  pbt/
    app_settings_roundtrip_test.dart
    settings_recovery_test.dart
    recording_state_machine_test.dart
    locale_roundtrip_test.dart
    speech_locale_properties_test.dart
    theme_contrast_test.dart
```
