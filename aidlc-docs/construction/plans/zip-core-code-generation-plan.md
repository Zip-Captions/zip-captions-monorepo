# Code Generation Plan — Unit 2: zip_core Library

## Unit Context

**Package**: `packages/zip_core/`
**Branch**: `feature/phase0-zip-core`
**Depends on**: Unit 1 merged (monorepo scaffold in place)

### Requirements Implemented

| Requirement | Description |
|---|---|
| FR-01.2 | `zip_core` package populated with providers, models, build_runner |
| FR-02.1 | Replace `provider` with Riverpod; add `riverpod_generator` + `build_runner` |
| FR-02.2 | Migrate PoC providers to Riverpod (locale, settings, recording) |
| FR-02.3 | Stub providers for Phase 1 domain objects (`sttEngineProvider`) |
| FR-02.5 | Settings persistence via `shared_preferences` in Riverpod pattern |
| FR-05.1 | `l10n.yaml` and ARB scaffold in `zip_core` |
| FR-05.2 | Import + convert v1 translations (ar, de, es, fr, id, it, pl, pt, uk) |
| FR-05.3 | Phase 0 English string keys seeded; non-English ARBs carry forward v1 keys |
| NFR-01.1 | `very_good_analysis` zero warnings |
| NFR-01.3 | Package imports only |
| NFR-02.2 | TDD workflow established (Unit 2 is exemplar) |
| NFR-02.3 | `glados` PBT framework in dev dependencies |
| NFR-03.4 | Transcript logging prohibition established |

### Design Artifacts

- `aidlc-docs/construction/zip-core/functional-design/domain-entities.md`
- `aidlc-docs/construction/zip-core/functional-design/business-logic-model.md`
- `aidlc-docs/construction/zip-core/functional-design/business-rules.md`
- `aidlc-docs/construction/zip-core/nfr-requirements/nfr-requirements.md`
- `aidlc-docs/construction/zip-core/nfr-requirements/tech-stack-decisions.md`
- `aidlc-docs/construction/zip-core/nfr-design/nfr-design-patterns.md`
- `aidlc-docs/construction/zip-core/nfr-design/logical-components.md`

### File Organization

Per `packages/zip_core/AGENTS.md`, feature-based layout with barrel exports:

```
packages/zip_core/
  lib/
    src/
      models/
        models.dart                     # barrel
        app_settings.dart               # freezed
        app_settings.freezed.dart       # generated
        recording_state.dart            # sealed class
        speech_locale.dart              # freezed
        speech_locale.freezed.dart      # generated
        recording_error.dart            # freezed
        recording_error.freezed.dart    # generated
        pause_event.dart                # freezed
        pause_event.freezed.dart        # generated
        enums.dart                      # ScrollDirection, ThemeModeSetting, CaptionTextSize, CaptionFont, RecordingErrorSeverity
      providers/
        providers.dart                  # barrel
        locale_provider.dart
        locale_provider.g.dart          # generated
        speech_locale_provider.dart
        speech_locale_provider.g.dart   # generated
        locale_info_provider.dart
        locale_info_provider.g.dart     # generated
        base_settings_notifier.dart
        recording_state_notifier.dart
        recording_state_notifier.g.dart # generated
        stt_engine_provider.dart
        stt_engine_provider.g.dart      # generated
      stt/
        stt.dart                        # barrel
        stt_engine.dart                 # abstract interface
      theme/
        theme.dart                      # barrel
        app_theme.dart
    zip_core.dart                       # package barrel
  l10n/
    l10n.yaml
    arb/
      app_en.arb
      app_ar.arb
      app_de.arb
      app_es.arb
      app_fr.arb
      app_id.arb
      app_it.arb
      app_pl.arb
      app_pt.arb
      app_uk.arb
  test/
    helpers/
      generators.dart                   # LC-01
      recording_state_model.dart        # LC-02
      contrast_utils.dart               # LC-03
      prefs_helpers.dart                # LC-04
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

---

## Steps

### Step 1: Update pubspec.yaml with dependencies
- [x] Add runtime dependencies: `flutter_riverpod`, `riverpod_annotation`, `freezed_annotation`, `shared_preferences`
- [x] Add dev dependencies: `riverpod_generator`, `freezed`, `build_runner`, `glados`, `mocktail`
- [x] Keep existing: `test`, `very_good_analysis`
- [x] Add Flutter SDK dependency for theme support (`flutter: sdk: flutter`)
- [x] Run `melos bootstrap` to verify resolution

### Step 2: Create domain enums
- [x] Create `lib/src/models/enums.dart` with `ScrollDirection`, `ThemeModeSetting`, `CaptionTextSize`, `CaptionFont`, `RecordingErrorSeverity`
- [x] `CaptionTextSize` includes a `textThemeGetter` method that returns the Material 3 `TextTheme` style name (per BR-10)
- [x] `CaptionFont` includes a `fontFamily` getter returning the font family string
- [x] All enums per `domain-entities.md`

### Step 3: Create freezed data classes
- [x] Create `lib/src/models/app_settings.dart` — `@freezed` with 5 fields, `AppSettings.defaults()` factory (per BR-04)
- [x] Create `lib/src/models/speech_locale.dart` — `@freezed` with `localeId`, `displayName`, computed `languageCode`, case-insensitive equality (per BR-08)
- [x] Create `lib/src/models/recording_error.dart` — `@freezed` with `message`, `severity`, `timestamp`
- [x] Create `lib/src/models/pause_event.dart` — `@freezed` with `pausedAt`, `resumedAt` (nullable)

### Step 4: Create RecordingState sealed class
- [x] Create `lib/src/models/recording_state.dart` — Dart sealed class with `idle`, `recording`, `paused`, `stopped` variants (all field-less in Phase 0)

### Step 5: Create SttEngine abstract interface
- [x] Create `lib/src/stt/stt_engine.dart` — abstract interface class with method signatures per `domain-entities.md`
- [x] Security constraint documented in dartdoc: callbacks receive transcript text, must never be logged

### Step 6: Create models barrel export
- [x] Create `lib/src/models/models.dart` — exports all model files
- [x] Create `lib/src/stt/stt.dart` — exports stt_engine.dart

### Step 7: Run build_runner for freezed code generation
- [x] Run `dart run build_runner build --delete-conflicting-outputs` in `packages/zip_core/`
- [x] Verify `.freezed.dart` files generated for AppSettings, SpeechLocale, RecordingError, PauseEvent

### Step 8: Write model tests (example-based) — TDD: tests first
- [x] Create `test/models/app_settings_test.dart` — defaults, copyWith, equality, factory
- [x] Create `test/models/recording_state_test.dart` — sealed class pattern matching, all 4 variants
- [x] Create `test/models/speech_locale_test.dart` — languageCode extraction (hyphen, underscore, language-only), case-insensitive equality
- [x] Run tests — verify they pass

### Step 9: Create test helpers
- [x] Create `test/helpers/generators.dart` (LC-01) — glados `Arbitrary<T>` for all enums, `AppSettings`, command sequences
- [x] Create `test/helpers/recording_state_model.dart` (LC-02) — pure-function state machine model
- [x] Create `test/helpers/contrast_utils.dart` (LC-03) — WCAG 2.1 `relativeLuminance` and `contrastRatio`
- [x] Create `test/helpers/prefs_helpers.dart` (LC-04) — `validPrefsMap`, `corruptPrefsMap`

### Step 10: Create AppTheme
- [x] Create `lib/src/theme/app_theme.dart` — `AppTheme` with static `light()` and `dark()` methods returning `ThemeData`
- [x] Dark theme: all 14 color tokens per `business-logic-model.md` dark palette
- [x] Light theme: all 14 color tokens per `business-logic-model.md` light palette (adjusted primary `#1A5A8C`, error `#A8191F`)
- [x] Typography: Inter as UI chrome font, minimum weight 500 below 14px, letter-spacing +0.05em for label-sm/label-md
- [x] Design rules: no gradients, tonal layering, ambient shadows only
- [x] Create `lib/src/theme/theme.dart` barrel

### Step 11: Write theme tests — TDD
- [x] Create `test/theme/app_theme_test.dart` — theme data not null, both themes produce valid `ThemeData`, `ColorScheme` tokens match spec
- [x] Create `test/pbt/theme_contrast_test.dart` — 16 pairs (8 dark + 8 light), all >= 7.0 contrast ratio using LC-03 utility
- [x] Run tests — verify they pass

### Step 12: Create BaseSettingsNotifier
- [x] Create `lib/src/providers/base_settings_notifier.dart` — abstract class with `String get keyPrefix`, all setter methods, `build()` with per-field recovery (BR-05), `reset()`, debug warnings per SR-03
- [x] Uses SharedPreferences key format `{keyPrefix}.{fieldName}` (BR-11)
- [x] Per-field fallback: missing/corrupt fields get defaults, valid fields preserved (BR-05)

### Step 13: Create LocaleProvider
- [x] Create `lib/src/providers/locale_provider.dart` — `@riverpod` notifier, persists to `app_locale` key, fallback chain: persisted -> device -> English (BR-06)

### Step 14: Create SpeechLocaleProvider (stub)
- [x] Create `lib/src/providers/speech_locale_provider.dart` — Phase 0 stub returning placeholder `SpeechLocale('en-US', 'English (United States)')`
- [x] Includes `availableLanguages` and `regionsForLanguage()` method signatures (BR-07), stub implementations

### Step 15: Create LocaleInfoProvider (stub)
- [x] Create `lib/src/providers/locale_info_provider.dart` — Phase 0 stub returning empty `List<SpeechLocale>`

### Step 16: Create RecordingStateNotifier
- [x] Create `lib/src/providers/recording_state_notifier.dart` — `@riverpod` notifier implementing full state machine transition table (BR-01)
- [x] Invalid transitions silently ignored (no exception)
- [x] Phase 0: stub transitions only, no STT wiring
- [x] `lastError` field for error handling (BR-03) — not populated in Phase 0
- [x] Security: no transcript text in any log or error message (SR-01, SR-02)

### Step 17: Create sttEngineProvider (stub)
- [x] Create `lib/src/providers/stt_engine_provider.dart` — `@riverpod` async notifier that throws `UnimplementedError`

### Step 18: Create providers barrel export
- [x] Create `lib/src/providers/providers.dart` — exports all provider files

### Step 19: Run build_runner for riverpod code generation
- [x] Run `dart run build_runner build --delete-conflicting-outputs`
- [x] Verify `.g.dart` files generated for all `@riverpod` providers

### Step 20: Write provider tests (example-based) — TDD
- [x] Create `test/providers/settings_notifier_test.dart` — load defaults, save each field, reset, corrupt recovery, key prefix isolation
- [x] Create `test/providers/locale_provider_test.dart` — set/get locale, device fallback, persistence round-trip
- [x] Create `test/providers/recording_state_notifier_test.dart` — all valid transitions, all invalid transitions (no-op), clearSession resets
- [x] Run tests — verify they pass

### Step 21: Write PBT tests
- [x] Create `test/pbt/app_settings_roundtrip_test.dart` — arbitrary AppSettings save/reload equality
- [x] Create `test/pbt/settings_recovery_test.dart` — arbitrary corruption patterns, per-field recovery
- [x] Create `test/pbt/recording_state_machine_test.dart` — random command sequences (0-50) vs pure-function model
- [x] Create `test/pbt/locale_roundtrip_test.dart` — arbitrary locale persistence round-trip
- [x] Create `test/pbt/speech_locale_properties_test.dart` — languageCode invariant, equality symmetry
- [x] Run PBT tests — verify they pass

### Step 22: Update barrel export
- [x] Update `lib/zip_core.dart` to export models, providers, stt, and theme barrels
- [x] Verify public API surface is correct (no internal-only exports)

### Step 23: Set up l10n scaffold
- [x] Create `l10n/l10n.yaml` configuration
- [x] Create `l10n/arb/app_en.arb` with Phase 0 shared string keys (settings labels, theme names, common UI strings)
- [x] Import and convert v1 translation JSON files to ARB format for: ar, de, es, fr, id, it, pl, pt, uk
- [x] Tag non-English ARBs with `"@@x-machine-generated": true`

### Step 24: Create FR-02.4 Riverpod conventions documentation
- [x] Create `docs/RIVERPOD_CONVENTIONS.md` with conventions established by Unit 2: `@riverpod` annotation pattern, `ProviderContainer` testing, `BaseSettingsNotifier` abstract pattern, no hand-written providers

### Step 25: Final verification
- [x] Run `dart analyze` — zero warnings
- [x] Run `dart test` — all tests pass (example-based + PBT)
- [x] Run `dart pub publish --dry-run` — verify publish-ready
- [x] Verify no `provider` package dependency
- [x] Verify `glados` in dev dependencies
- [x] Remove placeholder `test/zip_core_test.dart` (replaced by real tests)
- [x] Delete generated `.dart_tool/` artifacts from VCS if present

---

## Exit Criteria Checklist

- [x] `melos run analyze` passes on `zip_core` (zero warnings)
- [x] `melos run test` passes on `zip_core`
- [x] `dart pub publish --dry-run` passes
- [x] No `provider` dependency in `zip_core`
- [x] `glados` present in dev dependencies
- [x] All non-English ARB files present and tagged `machine-generated`
- [x] FR-02.1, FR-02.2, FR-02.3, FR-02.5, FR-05.1, FR-05.2, FR-05.3 implemented
- [x] NFR-02.2 (TDD), NFR-02.3 (glados), NFR-03.4 (transcript prohibition) verified
