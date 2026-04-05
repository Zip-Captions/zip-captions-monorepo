# Logical Components — Unit 1: Core Abstractions

## Overview

Unit 1 is a pure Dart library with no infrastructure components. This document maps the logical components to their test support infrastructure.

## Test Infrastructure Components

### 1. Shared PBT Generators

**Location**: `packages/zip_core/test/helpers/generators.dart`

| Generator | Produces | Used By |
|-----------|----------|---------|
| `ArbitrarySttResult` | Random valid `SttResult` instances | stt_result_properties_test |
| `ArbitraryTransitionSequence` | Random `List<StateTransition>` | recording_state_machine_test |
| `ArbitraryDisplaySettings` | Random valid `DisplaySettings` | display_settings_roundtrip_test |
| `ArbitraryRegistryOps` | Random registry operation sequences | stt_engine_registry_test |
| `ArbitraryCaptionEvent` | Random `CaptionEvent` (either variant) | caption_bus_properties_test |

**Note**: The existing `test/helpers/generators.dart` from Phase 0 contains generators for `AppSettings`. These will be updated to `DisplaySettings` as part of the rename.

### 2. Mock SttEngine

**Location**: `packages/zip_core/test/helpers/mock_stt_engine.dart`

Configurable mock implementing the full `SttEngine` interface. Default async delay of 100ms. Test trigger `emitResult(SttResult)` for injecting recognition results.

### 3. Test Output Targets

**Location**: `packages/zip_core/test/helpers/test_targets.dart`

| Target | Behavior | Used By |
|--------|----------|---------|
| `CollectingTarget` | Collects all events into a list | Bus throughput, delivery verification |
| `ThrowingTarget` | Throws on every `onCaptionEvent` | Error isolation tests |

### 4. Existing Test Helpers (Updated)

**Location**: `packages/zip_core/test/helpers/prefs_helpers.dart`

Phase 0 SharedPreferences test helper. Updated to use `display_settings` key prefix.

---

## Runtime Component Map

```
+-----------------------------------------------------+
|                    zip_core                           |
|                                                      |
|  +------------------+    +---------------------+     |
|  | SttEngineRegistry|    | CaptionBus          |     |
|  | (plain class)    |    | (plain class,       |     |
|  |                  |    |  broadcast stream)   |     |
|  +------------------+    +----------+----------+     |
|                                     |                |
|                          +----------v----------+     |
|                          | CaptionOutputTarget |     |
|                          | Registry            |     |
|                          | (plain class,       |     |
|                          |  lazy subscription) |     |
|                          +---------------------+     |
|                                                      |
|  +------------------+    +---------------------+     |
|  | RecordingState   |    | DisplaySettings     |     |
|  | Notifier         |    | (via Base           |     |
|  | (Riverpod,       |    |  SettingsNotifier)   |     |
|  |  keepAlive)      |    |                     |     |
|  +------------------+    +---------------------+     |
|                                                      |
|  +------------------+    +---------------------+     |
|  | TranscriptSettings    | SttEngine           |     |
|  | Notifier         |    | (interface only)    |     |
|  | (Riverpod,       |    |                     |     |
|  |  keepAlive)      |    +---------------------+     |
|  +------------------+                                |
|                                                      |
|  Providers (Riverpod, keepAlive):                    |
|  - SttEngineRegistryProvider                         |
|  - CaptionBusProvider                                |
|  - CaptionOutputTargetRegistryProvider               |
|  - SttEngineProvider (unchanged, throws)             |
|  - LocaleInfoProvider (unchanged, returns [])        |
+-----------------------------------------------------+
```

All runtime components are in-process Dart objects. No external services, databases, or network connections in Unit 1.

---

## Dependency Summary

### New Runtime Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `uuid` | ^4.x | Session ID generation |
| `logging` | ^1.x | Structured logging |

### New Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `glados` | latest stable | Property-based testing |

### Unchanged Dependencies

freezed, freezed_annotation, riverpod, riverpod_annotation, shared_preferences, build_runner, riverpod_generator

---

## Extension Compliance Summary

### Security Baseline

| Rule | Status | Notes |
|------|--------|-------|
| SECURITY-01 | N/A | No data stores |
| SECURITY-02 | N/A | No network intermediaries |
| SECURITY-03 | **Compliant** | Logging pattern excludes transcript text; Logger naming convention enforced |
| SECURITY-04 | N/A | No HTTP endpoints |
| SECURITY-05+ | N/A | Not applicable |

### Property-Based Testing

| Rule | Status | Notes |
|------|--------|-------|
| PBT-01 | **Compliant** | Properties identified in FD, carried into test file plan |
| PBT-02 | **Compliant** | Round-trip tests designed for DisplaySettings, SttEngineRegistry |
| PBT-03 | **Compliant** | Invariant tests designed for SttResult, RecordingState, CaptionBus |
| PBT-04 | **Compliant** | Idempotence tests designed for state machine transitions |
| PBT-05 | N/A | No commutativity properties |
| PBT-06 | **Compliant** | State machine PBT with ArbitraryTransitionSequence |
| PBT-07 | **Compliant** | Custom Arbitrary generators designed in shared generators.dart |
| PBT-08 | **Compliant** | glados provides automatic shrinking |
| PBT-09 | **Compliant** | PBT tests organized in pbt/ subdirectory, generators in helpers/ |
| PBT-10 | N/A | No performance properties requiring PBT |
