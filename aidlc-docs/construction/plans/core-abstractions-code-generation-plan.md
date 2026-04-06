# Code Generation Plan — Unit 1: Core Abstractions

## Unit Context

**Unit**: Unit 1 — Core Abstractions
**Stories**: S-01 (STT Engine Interface and Registry), S-03 (Caption Bus)
**Package**: zip_core (primary), zip_captions + zip_broadcast (rename only)
**Workspace Root**: /Users/oblivious/Documents/zip-captions-monorepo
**Project Type**: Brownfield (Phase 0 scaffold exists)

## Dependencies

- **Spikes 1.1, 1.3**: Complete (Sherpa-ONNX confirmed)
- **Phase 0 scaffold**: Existing SttEngine, AppSettings, RecordingState, providers, tests
- **New runtime deps**: `uuid`, `logging` (add to pubspec.yaml)
- **Existing dev deps**: `glados` already in pubspec.yaml

## Story Traceability

| Story | Components | Steps |
|-------|-----------|-------|
| S-01 | SttEngine (update), SttResult, SttEngineRegistry, SttEngineRegistryProvider, SttEngineProvider (unchanged), MockSttEngine | 2, 3, 5, 6, 11, 12 |
| S-03 | CaptionEvent, CaptionBus, CaptionOutputTarget, CaptionOutputTargetRegistry, CaptionBusProvider, CaptionOutputTargetRegistryProvider | 4, 7, 8, 9, 13, 14 |
| Cross-cutting | DisplaySettings rename, RecordingState update, RecordingStateNotifier update, LocaleInfoProvider, TranscriptSettingsProvider, logging migration | 1, 10, 15, 16, 17, 18, 19 |

---

## Plan Steps

### Phase A: Dependencies and Rename

- [x] **Step 1**: Add `uuid` and `logging` to zip_core pubspec.yaml dependencies
- [x] **Step 2**: Rename `AppSettings` to `DisplaySettings` — rename file `app_settings.dart` to `display_settings.dart`, update class name, factory, all imports in zip_core (model, base_settings_notifier, barrel exports, tests, helpers). Delete old generated files (`app_settings.freezed.dart`)
- [x] **Step 3**: Update `BaseSettingsNotifier` — change `Notifier<AppSettings>` to `Notifier<DisplaySettings>`, update key prefix from `app_settings` to `display_settings`, migrate `dart:developer` log to `logging` package
- [x] **Step 4**: Rename app-level settings notifiers — `ZipCaptionsSettingsNotifier` to `DisplaySettingsNotifier` in zip_captions, `ZipBroadcastSettingsNotifier` to `DisplaySettingsNotifier` in zip_broadcast, update provider names and `AppSettings` references to `DisplaySettings`
- [x] **Step 5**: Update all test files referencing `AppSettings` — `app_settings_test.dart` (rename to `display_settings_test.dart`), `app_settings_roundtrip_test.dart` (rename to `display_settings_roundtrip_test.dart`), `settings_recovery_test.dart`, `settings_notifier_test.dart`, `generators.dart`, `prefs_helpers.dart`

### Phase B: New Models (S-01)

- [x] **Step 6**: Create `SttResult` model — `packages/zip_core/lib/src/models/stt_result.dart` (freezed). Add to models barrel export
- [x] **Step 7**: Create `AudioInputConfig` and `AudioInputVisualStyle` models — `packages/zip_core/lib/src/models/audio_input_config.dart` (freezed). Add to models barrel export

### Phase C: New Models (S-03)

- [x] **Step 8**: Create `CaptionEvent` sealed class — `packages/zip_core/lib/src/models/caption_event.dart`. Add to models barrel export

### Phase D: SttEngine Interface Update (S-01)

- [x] **Step 9**: Update `SttEngine` abstract interface — add `engineId`, `displayName`, `requiresNetwork`, `requiresDownload` properties. Replace `startListening` callbacks with single `onResult(SttResult)`. Replace `getAvailableLocales()` with `supportedLocales()`. Update stt barrel export

### Phase E: New Service Classes

- [x] **Step 10**: Create `SttEngineRegistry` — `packages/zip_core/lib/src/services/stt/stt_engine_registry.dart`. Add services directory and barrel exports
- [x] **Step 11**: Create `CaptionBus` — `packages/zip_core/lib/src/services/caption/caption_bus.dart` with broadcast StreamController
- [x] **Step 12**: Create `CaptionOutputTarget` interface — `packages/zip_core/lib/src/services/caption/caption_output_target.dart`
- [x] **Step 13**: Create `CaptionOutputTargetRegistry` — `packages/zip_core/lib/src/services/caption/caption_output_target_registry.dart` with lazy subscription, fire-and-forget error isolation
- [x] **Step 14**: Create service barrel exports — `packages/zip_core/lib/src/services/services.dart`, `stt/stt.dart`, `caption/caption.dart`. Update zip_core.dart

### Phase F: RecordingState + Notifier Update

- [x] **Step 15**: Update `RecordingState` sealed class — add `ActiveSessionState` mixin, add `sessionId` and `currentSegment` fields to non-idle variants
- [x] **Step 16**: Update `RecordingStateNotifier` — add CaptionBus dependency, generate sessionId on start, publish SessionStateEvents, add `_handleSttResult` method, migrate logging to `logging` package

### Phase G: New Providers

- [x] **Step 17**: Create `SttEngineRegistryProvider` — `packages/zip_core/lib/src/providers/stt_engine_registry_provider.dart` (keepAlive)
- [x] **Step 18**: Create `CaptionBusProvider` — `packages/zip_core/lib/src/providers/caption_bus_provider.dart` (keepAlive)
- [x] **Step 19**: Create `CaptionOutputTargetRegistryProvider` — `packages/zip_core/lib/src/providers/caption_output_target_registry_provider.dart` (keepAlive, depends on CaptionBusProvider)
- [x] **Step 20**: Create `TranscriptSettingsProvider` — `packages/zip_core/lib/src/providers/transcript_settings_provider.dart` (keepAlive, SharedPreferences-backed bool)
- [x] **Step 21**: Update `LocaleInfoProvider` — comment update noting it reads from SttEngine in Unit 2 (no functional change yet since SttEngineProvider still throws)
- [x] **Step 22**: Update providers barrel export — add all new providers

### Phase H: Test Helpers

- [x] **Step 23**: Create `MockSttEngine` — `packages/zip_core/test/helpers/mock_stt_engine.dart` with configurable properties, 100ms default async delay, `emitResult()` trigger
- [x] **Step 24**: Create test output targets — `packages/zip_core/test/helpers/test_targets.dart` with `CollectingTarget` and `ThrowingTarget`
- [x] **Step 25**: Update `generators.dart` — rename `AppSettings` generators to `DisplaySettings`, add `ArbitrarySttResult`, `ArbitraryCaptionEvent`, `ArbitraryRegistryOps` generators
- [x] **Step 26**: Update `prefs_helpers.dart` — rename all `AppSettings` references to `DisplaySettings`, update key prefix to `display_settings`
- [x] **Step 27**: Update `recording_state_model.dart` — add sessionId tracking to the pure-function reference model

### Phase I: Unit Tests

- [x] **Step 28**: Create `stt_result_test.dart` — example-based tests for SttResult freezed model
- [x] **Step 29**: Create `caption_event_test.dart` — exhaustive pattern matching test for sealed class
- [x] **Step 30**: Create `stt_engine_registry_test.dart` — register, unregister, getEngine, defaultEngine, duplicate handling
- [x] **Step 31**: Create `caption_bus_test.dart` — publish, stream subscription, dispose safety
- [x] **Step 32**: Create `caption_output_target_registry_test.dart` — add, remove, lazy subscription, error isolation, dispose
- [x] **Step 33**: Update `recording_state_test.dart` — add tests for ActiveSessionState mixin, sessionId/currentSegment fields
- [x] **Step 34**: Update `recording_state_notifier_test.dart` — add tests for sessionId generation, CaptionBus publishing, _handleSttResult
- [x] **Step 35**: Create `transcript_settings_provider_test.dart` — toggle persistence, default value

### Phase J: PBT Tests

- [x] **Step 36**: Create `pbt/stt_result_properties_test.dart` — confidence range, sourceId non-empty invariants
- [x] **Step 37**: Update `pbt/recording_state_machine_test.dart` — add sessionId consistency property, update for new fields
- [x] **Step 38**: Create `pbt/caption_bus_properties_test.dart` — all-targets-receive invariant, error isolation invariant
- [x] **Step 39**: Rename and update `pbt/app_settings_roundtrip_test.dart` to `pbt/display_settings_roundtrip_test.dart`
- [x] **Step 40**: Update `pbt/settings_recovery_test.dart` — update for DisplaySettings rename
- [x] **Step 41**: Create `pbt/stt_engine_registry_properties_test.dart` — register/get round-trip, defaultEngine invariant

### Phase K: Code Generation and Verification

- [x] **Step 42**: Run `dart run build_runner build --delete-conflicting-outputs` to generate freezed and riverpod code
- [x] **Step 43**: Run `dart analyze` on zip_core, zip_captions, zip_broadcast — fix any issues
- [x] **Step 44**: Run `flutter test` on all three packages — fix any failures
- [x] **Step 45**: Generate code summary documentation at `aidlc-docs/construction/core-abstractions/code/code-summary.md`
