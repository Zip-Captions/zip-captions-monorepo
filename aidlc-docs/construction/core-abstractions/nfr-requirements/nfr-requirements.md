# NFR Requirements — Unit 1: Core Abstractions

## 1. Performance

### PERF-U1.1: CaptionBus Throughput

The CaptionBus must sustain at least **20 events/second** without dropped events or backpressure. This covers single-input captioning with interim results arriving every 50ms.

**Verification**: A test publishes 20 events in 1 second to the bus with a registered target and asserts all 20 are received in order.

**Rationale**: Single-input is the Phase 1 baseline. Multi-input throughput (Zip Broadcast) will be validated in Unit 2 when multiple STT engines are active.

### PERF-U1.2: State Machine Transition Latency

`RecordingStateNotifier` transitions (start, pause, resume, stop) must complete in under **10ms** excluding STT engine operations (which are async and engine-dependent). The state machine itself is pure in-memory state assignment.

**Verification**: Transition timing tests. Not a formal benchmark — just a sanity check that no blocking I/O is introduced in the state machine path.

---

## 2. Reliability

### REL-U1.1: Error Isolation

A thrown exception in any `CaptionOutputTarget.onCaptionEvent()` must not:
- Prevent other targets from receiving the same event
- Crash the CaptionBus or CaptionOutputTargetRegistry
- Cause the bus subscription to be cancelled

**Verification**: Register two targets, make one throw on every event. Assert the other target receives all events. Assert no unhandled exceptions propagate.

### REL-U1.2: Bus Lifecycle Safety

- `CaptionBus.publish()` after `dispose()` is a no-op (no exception).
- `CaptionOutputTargetRegistry.add()` after `dispose()` is a no-op.
- `CaptionOutputTargetRegistry.remove()` on an unregistered target is a no-op.

**Verification**: Lifecycle edge case tests for each scenario.

### REL-U1.3: State Machine Integrity

The `RecordingStateNotifier` must never enter an invalid state regardless of the sequence of method calls. Invalid transitions are silently ignored (Phase 0 behavior preserved).

**Verification**: PBT test generating random sequences of `start/pause/resume/stop/clearSession` and asserting the resulting state is always one of the four valid states with consistent sessionId.

---

## 3. Security

### SEC-U1.1: No Transcript Logging (SECURITY-03)

No component in Unit 1 may include transcript text (`SttResult.text`, `RecordingState.currentSegment`) in any log output, error message, or exception message.

**Permitted in logs**: State names (idle/recording/paused/stopped), engineId, targetId, sessionId, error types, stack traces.

**Verification**:
- Code review: no `log()` call references `.text` or `.currentSegment`
- The `CaptionOutputTargetRegistry` error handler logs `target.targetId` and `e.runtimeType` only
- `RecordingError.message` contains operational descriptions only

### SEC-U1.2: No Sensitive Data in SharedPreferences Keys

The `DisplaySettings` key prefix (`display_settings`) and `TranscriptSettings` key (`transcript.captureEnabled`) contain only preference values (enum names, booleans, integers). No transcript text, session content, or PII is stored in SharedPreferences.

**Verification**: Code review of all SharedPreferences write operations.

---

## 4. Testing

### TEST-U1.1: Coverage Target

80%+ line coverage for all Unit 1 code in zip_core (carried forward from Phase 0 NFR-4.1).

### TEST-U1.2: Property-Based Testing with glados

All PBT properties identified in the Functional Design business-rules.md must have corresponding `glados` property tests:

| Component | Properties | Test Type |
|-----------|-----------|-----------|
| SttResult | Round-trip (JSON if applicable), confidence range invariant, sourceId non-empty | `Glados<SttResult>` with custom `Arbitrary` |
| RecordingState | Session ID consistency, idempotent transitions, valid state after any sequence | `Glados<List<StateTransition>>` generating random transition sequences |
| CaptionBus + Registry | All-targets-receive invariant, error isolation invariant | `Glados<List<CaptionEvent>>` with mock targets |
| DisplaySettings | Save/load round-trip, defaults invariant, reset idempotence | `Glados<DisplaySettings>` with mock SharedPreferences |
| SttEngineRegistry | Register/get round-trip, defaultEngine invariant | `Glados<List<RegistryOp>>` generating random register/unregister sequences |

### TEST-U1.3: Mock SttEngine Pattern

Unit 1 must provide a reusable `MockSttEngine` test helper that:
- Implements the updated `SttEngine` interface
- Allows configuring: `engineId`, `displayName`, `requiresNetwork`, `requiresDownload`, `supportedLocales`, `isAvailable`
- Captures `startListening` calls and provides a way to inject `SttResult` events via the `onResult` callback
- Is usable by downstream units (Unit 2+) for testing components that depend on `SttEngine`

**Location**: `packages/zip_core/test/helpers/mock_stt_engine.dart`

### TEST-U1.4: No Platform Dependencies in Unit Tests

All Unit 1 tests must run without Flutter test infrastructure where possible (pure Dart tests). Tests that require `WidgetsFlutterBinding` (e.g., SharedPreferences) should minimize platform coupling.

---

## 5. Maintainability

### MAINT-U1.1: API Stability for Downstream Units

The following interfaces defined in Unit 1 are consumed by Units 2-7. Changes after Unit 1 completion require updating all downstream consumers:

| Interface | Consumed By |
|-----------|-------------|
| `SttEngine` | Unit 2 (PlatformSttEngine, SherpaOnnxSttEngine) |
| `CaptionOutputTarget` | Unit 3 (OnScreenCaptionTarget, TranscriptWriterTarget, ObsWebSocketTarget, BrowserSourceTarget) |
| `CaptionEvent` | Units 2-7 (all bus consumers) |
| `SttResult` | Units 2-7 (all result consumers) |
| `RecordingState` (with ActiveSessionState mixin) | Units 5-6 (app UI) |

**Mitigation**: These interfaces are designed from the Application Design artifacts with all downstream use cases considered. The Functional Design has validated compatibility with Sherpa-ONNX (Spike 1.3) and platform STT patterns.

### MAINT-U1.2: Logging Migration

Phase 0 code uses `dart:developer` `log()`. Unit 1 introduces the `logging` package. Existing Phase 0 log calls in modified files (BaseSettingsNotifier, RecordingStateNotifier) should be migrated to `logging` in Unit 1. Phase 0 files not modified in Unit 1 can be migrated opportunistically.

---

## Extension Compliance Summary

### Security Baseline

| Rule | Status | Notes |
|------|--------|-------|
| SECURITY-01 | N/A | No data stores in Unit 1 |
| SECURITY-02 | N/A | No network intermediaries |
| SECURITY-03 | **Compliant** | SEC-U1.1 enforces no transcript logging |
| SECURITY-04 | N/A | No HTTP endpoints |
| SECURITY-05+ | N/A | Not applicable to Unit 1 |

### Property-Based Testing

| Rule | Status | Notes |
|------|--------|-------|
| PBT-01 | **Compliant** | Properties identified in FD business-rules.md |
| PBT-02 | **Compliant** | Round-trip tests planned for SttResult, DisplaySettings, SttEngineRegistry |
| PBT-03 | **Compliant** | Invariant tests planned for all components |
| PBT-04 | **Compliant** | Idempotence tests planned for state machine and registry |
| PBT-05 | N/A | No commutativity properties |
| PBT-06 | **Compliant** | State machine PBT for RecordingState |
| PBT-07 | **Compliant** | glados Arbitrary generators to be defined per component |
| PBT-08 | Deferred to NFR Design | Shrinking strategy |
| PBT-09 | Deferred to NFR Design | Test organization |
| PBT-10 | N/A | No performance properties |
