# Tech Stack Decisions — Unit 2: zip_core Library

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

---

## State Management Stack

| Tool | Role |
|---|---|
| `flutter_riverpod` | Runtime provider framework |
| `riverpod_annotation` | Annotations for code generation |
| `riverpod_generator` | Code generation for providers |
| `build_runner` | Dart code generation orchestration |

---

## Data Modeling Stack

| Tool | Role |
|---|---|
| `freezed` / `freezed_annotation` | Immutable data classes with `copyWith`, equality, JSON |
| Dart sealed classes | State machine representation (`RecordingState`) |
| Dart enums (enhanced) | `ScrollDirection`, `ThemeModeSetting`, `CaptionTextSize`, `CaptionFont`, `RecordingErrorSeverity` |

---

## Persistence Stack

| Tool | Role |
|---|---|
| `shared_preferences` | Key-value persistence for settings and locale |

SharedPreferences key format: `{appPrefix}.{fieldName}` (e.g., `zip_captions.scrollDirection`).

All values stored as strings (enum names) or ints. No JSON serialization — fields are individually keyed for independent recovery on corruption.

---

## Font Stack

| Approach | Decision |
|---|---|
| Caption fonts | Bundled `.ttf` assets (offline-first) |
| UI chrome font | Inter — bundled `.ttf` asset |
| Font resolution | `CaptionFont` enum maps to font family name string; app registers fonts in `pubspec.yaml` |

No `google_fonts` dependency. All fonts sourced from Google Fonts under OFL license, downloaded once and committed to the repository as assets.

Font assets live in the app packages (zip_captions, zip_broadcast), not in zip_core. zip_core defines the `CaptionFont` enum with font family name mappings.

---

## Code Quality Stack

| Tool | Role |
|---|---|
| `very_good_analysis` | Linting rules (zero warnings enforced) |
| `dart format` | Code formatting |
| `dart analyze` | Static analysis |

---

## Decisions Log

| Decision | Choice | Rationale | Alternatives Considered |
|---|---|---|---|
| PBT framework | `glados` | Custom generators, shrinking, seed reproducibility, dart test integration | `propcheck` (less mature), `quick_check` (unmaintained) |
| Font loading | Bundled .ttf assets | Offline-first; no runtime network dependency; predictable | `google_fonts` package (rejected: requires network on first use) |
| Settings persistence | `shared_preferences` | First-party Flutter plugin; cross-platform; simple key-value; PoC precedent | `hive` (overkill for flat settings), `drift`/`sqflite` (relational; overkill) |
| Provider testing | `ProviderContainer` (unit) + `ProviderScope` (widget) | Clean separation: library tests logic, apps test integration | `ProviderScope`-only (requires widget tree; not applicable to library package) |
| Contrast target | WCAG AAA (7:1) hard NFR | Design spec mandates it; accessibility is a core product value | WCAG AA (4.5:1) minimum (rejected: design spec explicitly targets AAA) |
| Test separation | `test/` (example-based) + `test/pbt/` (property-based) | Clear distinction per PBT-10; easy to run selectively | Mixed in same files (harder to distinguish, review) |
