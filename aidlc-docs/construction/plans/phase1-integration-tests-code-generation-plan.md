# Phase 1 Integration Tests — Code Generation Plan

## Unit Context
- **Branch**: `feature/phase1-integration-tests`
- **Stories**: Implements Phase 1 Build and Test integration scenarios (from `integration-test-instructions.md`)
- **Goal**: Automate the four provider-level integration scenarios that can run headlessly in CI

## Files to Create

- [x] Step 1 — `packages/zip_broadcast/test/integration/caption_bus_flow_test.dart`
- [x] Step 2 — `packages/zip_broadcast/test/integration/audio_config_recording_integration_test.dart`
- [x] Step 3 — `packages/zip_broadcast/test/integration/obs_settings_connection_integration_test.dart`
- [x] Step 4 — `packages/zip_captions/test/integration/recording_pipeline_integration_test.dart`
- [x] Step 5 — 477 tests pass (zip_core 313, zip_captions 71, zip_broadcast 93); 0 regressions
- [x] Step 6 — Updated `aidlc-docs/construction/build-and-test/integration-test-instructions.md`: automated table added, manual scenarios annotated

## Dependencies / Helpers Reused
All helpers already exist in the respective `test/helpers/` directories:
- `MockSttEngine` — controllable engine with `emit(SttResult)` API
- `MockCaptionBus` — records published events, extends CaptionBus (stream still works)
- `FakeWakeLockService` — no-op wake lock
- `MockObsWebSocketTarget` — records `sentCaptions`, emits status stream

## Test Strategy per File

### Step 1: caption_bus_flow_test.dart
Tests that `BroadcastRecordingNotifier` routes results to the `CaptionBus` with correct `sourceId` tags, and that the gate on `_handleResult` (only publishes when `BroadcastActiveState`) blocks events during pause.

Pattern: real `CaptionBus` stream subscription; `MockSttEngine.emit()` to inject results.

Scenarios:
- start → emit → verify `SttResultEvent` on bus with correct sourceId
- pause → emit → verify no new `SttResultEvent` on bus
- resume → emit → verify `SttResultEvent` resumes
- stop → verify `SessionStateEvent(StoppedState)` on bus

### Step 2: audio_config_recording_integration_test.dart
Tests that `BroadcastRecordingNotifier.start()` reads from real `AudioInputConfigNotifier` (with SharedPreferences) rather than a hardcoded stub.

Pattern: `SharedPreferences.setMockInitialValues({})`, real `AudioInputConfigNotifier`, override `sttEngineFactoryProvider` per deviceId.

Scenarios:
- Default config ('default') → start → 1 active session
- Remove default, add custom config → start → session created for custom deviceId
- No configs → start → `BroadcastIdleState` with error

### Step 3: obs_settings_connection_integration_test.dart
Tests `ObsConnectionNotifier` + `OutputTargetSettingsNotifier` + real `CaptionBus` together: enabling OBS connects and wires caption forwarding; disabling disconnects and stops forwarding.

Pattern: `MockObsWebSocketTarget`, real `OutputTargetSettingsNotifier` + `ObsConnectionNotifier`, `MockCaptionBus`.

Scenarios:
- Enable OBS → final SttResult on bus → `MockObsWebSocketTarget.sentCaptions` receives it
- Disable OBS → final SttResult on bus → `sentCaptions` unchanged

### Step 4: recording_pipeline_integration_test.dart (zip_captions)
Tests the full `RecordingStateNotifier` state machine with a real `CaptionBus`, using `SttEngineRegistry` to supply the `MockSttEngine` so both `sttEngineProvider` and `SttSessionManager` resolve to the same mock.

Pattern: override `sttEngineRegistryProvider` with populated registry; subscribe to `mockBus.stream`.

Scenarios:
- start → `RecordingActiveState` + `SessionStateEvent(recording)` on bus
- emit final SttResult → `SttResultEvent` on bus
- pause → `PausedState` + `SessionStateEvent(paused)` on bus
- resume → `RecordingActiveState` + `SessionStateEvent(recording)` on bus
- stop → `StoppedState` + `SessionStateEvent(stopped)` on bus
