# Code Summary — Unit 1: Core Abstractions

## Stories Implemented

- **S-01**: STT Engine Interface and Registry
- **S-03**: Caption Bus

## Verification Results

| Check | Result |
|-------|--------|
| `build_runner build` | 26 outputs written (freezed + riverpod codegen) |
| `dart analyze` (zip_core) | 0 errors, 0 warnings, 57 infos (style only) |
| `dart analyze` (zip_captions) | No issues |
| `dart analyze` (zip_broadcast) | No issues |
| `flutter test` (zip_core) | 156 tests passed |

## Files Created

### Models (`packages/zip_core/lib/src/models/`)

| File | Type | Purpose |
|------|------|---------|
| `stt_result.dart` | freezed | Unified STT result value object |
| `audio_input_config.dart` | freezed | Audio input source config + visual style |
| `caption_event.dart` | sealed class | SttResultEvent + SessionStateEvent |

### Services (`packages/zip_core/lib/src/services/`)

| File | Type | Purpose |
|------|------|---------|
| `stt/stt_engine_registry.dart` | plain Dart | Engine registration, lookup, default selection |
| `caption/caption_bus.dart` | plain Dart | Broadcast StreamController for CaptionEvents |
| `caption/caption_output_target.dart` | abstract interface | Target contract for caption consumers |
| `caption/caption_output_target_registry.dart` | plain Dart | Fan-out with lazy subscription + error isolation |
| `services.dart`, `stt/stt.dart`, `caption/caption.dart` | barrel | Re-exports |

### Providers (`packages/zip_core/lib/src/providers/`)

| File | Type | Purpose |
|------|------|---------|
| `stt_engine_registry_provider.dart` | keepAlive | Singleton SttEngineRegistry |
| `caption_bus_provider.dart` | keepAlive | Singleton CaptionBus with dispose |
| `caption_output_target_registry_provider.dart` | keepAlive | Singleton registry, depends on CaptionBus |
| `transcript_settings_provider.dart` | keepAlive | SharedPreferences-backed capture toggle |

### Test Helpers (`packages/zip_core/test/helpers/`)

| File | Purpose |
|------|---------|
| `mock_stt_engine.dart` | Full SttEngine mock with configurable properties, 100ms async delay, emitResult() |
| `test_targets.dart` | CollectingTarget and ThrowingTarget for registry tests |

### Test Files

| File | Type | Tests |
|------|------|-------|
| `models/stt_result_test.dart` | unit | Freezed model: creation, equality, copyWith |
| `models/caption_event_test.dart` | unit | Sealed class: variants, exhaustive matching |
| `services/stt_engine_registry_test.dart` | unit | Register, unregister, get, default, duplicate |
| `services/caption_bus_test.dart` | unit | Publish, multi-subscriber, dispose, ordering |
| `services/caption_output_target_registry_test.dart` | unit | Add, remove, error isolation, lazy sub, dispose |
| `providers/transcript_settings_provider_test.dart` | unit | Default, persistence, toggle |
| `pbt/stt_result_properties_test.dart` | PBT | Confidence range, sourceId non-empty, final text |
| `pbt/caption_bus_properties_test.dart` | PBT | All-targets-receive, error isolation, throughput |
| `pbt/stt_engine_registry_properties_test.dart` | PBT | Register/get round-trip, defaultEngine invariant |

## Files Modified

| File | Change |
|------|--------|
| `models/recording_state.dart` | Added ActiveSessionState mixin, sessionId + currentSegment to non-idle variants |
| `models/display_settings.dart` | Renamed from app_settings.dart (Phase A, completed in prior session) |
| `models/models.dart` | Added exports for new models |
| `stt/stt_engine.dart` | Phase 1 interface: engineId, displayName, requiresNetwork, requiresDownload, onResult(SttResult), supportedLocales() |
| `providers/recording_state_notifier.dart` | CaptionBus integration, sessionId generation, SessionStateEvent publishing, handleSttResult() |
| `providers/locale_info_provider.dart` | Comment update for Unit 2 |
| `providers/providers.dart` | Added exports for new providers |
| `zip_core.dart` | Added services barrel export |
| `test/helpers/generators.dart` | Added SttResult, CaptionEvent, RegistryOp generators |
| `test/helpers/recording_state_model.dart` | Added sessionId tracking (applyCommandWithSession) |
| `test/models/recording_state_test.dart` | Added ActiveSessionState mixin tests |
| `test/providers/recording_state_notifier_test.dart` | Added sessionId, CaptionBus, handleSttResult tests |
| `test/pbt/recording_state_machine_test.dart` | Added sessionId consistency property, CaptionBus wiring |

## Dependencies Added

| Package | Version | Scope | Purpose |
|---------|---------|-------|---------|
| `logging` | ^1.3.0 | runtime | Structured logging (replaces dart:developer) |
| `uuid` | ^4.5.1 | runtime | Session ID generation |

## Architecture Notes

- **Lazy subscription pattern**: CaptionOutputTargetRegistry subscribes to the bus only when targets exist
- **Fire-and-forget error isolation**: Each target wrapped in try-catch; failures logged but don't propagate
- **Security (SECURITY-03)**: No transcript text in logs — only IDs, error types, and state transitions
- **STT engine wiring deferred**: SttEngineProvider still throws UnimplementedError (Unit 2)
- **handleSttResult is public**: Will be wired to SttEngine.onResult callback in Unit 2
