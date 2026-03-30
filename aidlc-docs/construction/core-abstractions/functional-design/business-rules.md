# Business Rules — Unit 1: Core Abstractions

## State Machine Rules

### BR-01: RecordingState Transitions

Valid transitions (unchanged from Phase 0):

| From | To | Trigger |
|------|----|---------|
| `idle` | `recording` | `start(localeId)` |
| `recording` | `paused` | `pause()` |
| `paused` | `recording` | `resume()` |
| `recording` | `stopped` | `stop()` |
| `paused` | `stopped` | `stop()` |
| `stopped` | `idle` | `clearSession()` |

**Invalid transitions are silently ignored** — no exception, no error. This prevents UI race conditions (e.g., double-tap).

### BR-02: Session Identity Persistence

- A `sessionId` is generated exactly once per session: when transitioning from `idle` to `recording`.
- The same `sessionId` persists through `recording` -> `paused` -> `recording` -> `stopped`.
- `clearSession()` discards the sessionId by transitioning to `idle` (which has no session fields).
- `sessionId` is a UUID v4 string.

### BR-03: CurrentSegment Lifecycle

- `currentSegment` is empty (`''`) at session start.
- Updated to `result.text` on each interim `SttResult` (where `isFinal == false`).
- Cleared to `''` on each final `SttResult` (where `isFinal == true`).
- Preserved across `recording` -> `paused` transition (the partial text stays visible).
- Reset to `''` on `paused` -> `recording` resume (new utterance begins).
- Preserved in `stopped` state (captures the last segment state at stop time).

---

## CaptionBus Rules

### BR-04: Event Ordering

Events are delivered in publication order. The broadcast StreamController preserves insertion order. Targets receive events in the order they were published.

### BR-05: Error Isolation

A failure in any `CaptionOutputTarget.onCaptionEvent()` must not prevent other targets from receiving the same event. Each target invocation is wrapped in an independent try-catch (Q2=A).

### BR-06: Lazy Subscription

The `CaptionOutputTargetRegistry` subscribes to the `CaptionBus.stream` only when the first target is added. It unsubscribes when the last target is removed (Q5=B). This means:
- No bus subscription overhead if no targets are registered.
- Events published before any target is registered are not buffered or replayed.

### BR-07: Target Uniqueness

Targets in the registry are identified by object identity (Set semantics). Adding the same target instance twice is a no-op. Two different target instances with the same `targetId` string can coexist (the registry uses Set identity, not targetId equality).

### BR-08: Target Disposal on Remove

When a target is removed from the registry via `remove()`, the registry calls `target.dispose()`. When the registry itself is disposed, it disposes all remaining targets.

---

## SttEngine Rules

### BR-09: Engine Identity

Each `SttEngine` has a unique `engineId` string. The `SttEngineRegistry` uses this as the map key. Registering a new engine with an existing `engineId` replaces the previous one.

### BR-10: Engine Properties are Static

`engineId`, `displayName`, `requiresNetwork`, and `requiresDownload` are synchronous getters that return constant values for the engine's lifetime. They do not change after construction.

### BR-11: Locale is Required

`startListening` requires a `localeId`. The caller is responsible for selecting a valid locale from `supportedLocales()` before calling `startListening`. Behavior with an unsupported locale is engine-defined (may fail or fall back).

---

## Settings Rules

### BR-12: DisplaySettings Key Prefix

SharedPreferences keys use the format `{appPrefix}.display_settings.{fieldName}` where `appPrefix` is the app-specific key prefix (`zip_captions` or `zip_broadcast`). Changed from `app_settings` to `display_settings` (Q6=A).

### BR-13: Settings Defaults

`DisplaySettings.defaults()` returns canonical default values. If a stored value is missing or corrupted, the default is used. No error is thrown to the user.

### BR-14: TranscriptSettings Default

Transcript capture is enabled by default (`true`). The toggle persists to SharedPreferences under the key `transcript.captureEnabled`.

---

## Security Rules

### SR-01: No Transcript Logging (SECURITY-03)

No component in Unit 1 may log, emit to analytics, or surface transcript text (`SttResult.text`, `currentSegment`) in any log output. This applies to:
- `SttEngine` implementations
- `RecordingStateNotifier._handleSttResult`
- `CaptionBus.publish`
- `CaptionOutputTarget.onCaptionEvent` (contract on implementors)
- `CaptionOutputTargetRegistry._onBusEvent` error handler (logs `targetId` and exception type only, never the event's text content)

**Permitted in logs**: State transitions (idle/recording/paused/stopped), error types, targetId, engineId, sessionId.

### SR-02: No Sensitive Data in Error Messages

`RecordingError.message` must not contain transcript text. Only operational error descriptions (e.g., "Microphone permission denied", "Engine initialization failed").

---

## Testable Properties (PBT-01)

### SttResult

| Property | Category | Description |
|----------|----------|-------------|
| Round-trip | PBT-02 | `SttResult.fromJson(result.toJson()) == result` for all valid SttResult instances (if JSON serialization is added) |
| Invariant | PBT-03 | `confidence` is always in [0.0, 1.0] range |
| Invariant | PBT-03 | `sourceId` is always non-empty |
| Invariant | PBT-03 | Final results (`isFinal == true`) have non-empty `text` |

### CaptionEvent

| Property | Category | Description |
|----------|----------|-------------|
| Invariant | PBT-03 | Exhaustive pattern matching: every CaptionEvent is either SttResultEvent or SessionStateEvent |

### RecordingState State Machine

| Property | Category | Description |
|----------|----------|-------------|
| Invariant | PBT-03 | After any sequence of valid transitions, sessionId is consistent within a session (same value from start to stop) |
| Invariant | PBT-03 | `IdleState` never has sessionId or currentSegment |
| Idempotence | PBT-04 | Calling `pause()` twice from `recording` produces the same state as calling it once (second call is no-op) |
| Idempotence | PBT-04 | Calling `start()` from `recording` is a no-op (state unchanged) |
| Invariant | PBT-03 | All valid transition sequences end in one of the four states (no crash, no stuck state) |

### CaptionBus + Registry

| Property | Category | Description |
|----------|----------|-------------|
| Invariant | PBT-03 | Publishing N events results in each registered target receiving exactly N `onCaptionEvent` calls (assuming no errors) |
| Invariant | PBT-03 | Error in target A does not affect delivery to target B |
| Invariant | PBT-03 | After registry.dispose(), no further events are delivered to any target |

### DisplaySettings

| Property | Category | Description |
|----------|----------|-------------|
| Round-trip | PBT-02 | Save settings to SharedPreferences then load them back: loaded settings == original settings |
| Invariant | PBT-03 | `DisplaySettings.defaults()` always returns the same values |
| Idempotence | PBT-04 | `reset()` followed by `build()` == `DisplaySettings.defaults()` |

### SttEngineRegistry

| Property | Category | Description |
|----------|----------|-------------|
| Idempotence | PBT-04 | Registering the same engine twice: `listAvailable()` returns it once |
| Invariant | PBT-03 | `getEngine(id)` returns the engine iff it was registered and not unregistered |
| Invariant | PBT-03 | `defaultEngine` is null iff no engines are registered |

---

## Extension Compliance Summary

### Security Baseline

| Rule | Status | Notes |
|------|--------|-------|
| SECURITY-01 | N/A | No data persistence stores in Unit 1 (transcript DB is Unit 3) |
| SECURITY-02 | N/A | No network intermediaries in Unit 1 |
| SECURITY-03 | **Compliant** | SR-01 enforces no transcript logging across all components |
| SECURITY-04 | N/A | No HTTP endpoints in Unit 1 (browser source is Unit 3) |
| SECURITY-05+ | N/A | Not applicable to Unit 1 scope |

### Property-Based Testing

| Rule | Status | Notes |
|------|--------|-------|
| PBT-01 | **Compliant** | Testable properties identified per component above |
| PBT-02 | **Compliant** | Round-trip properties identified for SttResult, DisplaySettings |
| PBT-03 | **Compliant** | Invariant properties identified for all major components |
| PBT-04 | **Compliant** | Idempotence properties identified for state machine and registry |
| PBT-05 | N/A | No commutativity properties applicable |
| PBT-06 | **Compliant** | State machine properties documented for RecordingState |
| PBT-07+ | Deferred to NFR Design | Generator design happens in NFR Design stage |
