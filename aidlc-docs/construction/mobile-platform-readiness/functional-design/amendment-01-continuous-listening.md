# Functional Design Amendment 01: continuous listening (N9)

**Unit**: 10, Mobile Platform Readiness (S-22). **Date**: 2026-10-25. **Revision**: 2 (after the Opus review of the same day). **Status**: APPROVED by James Petersen, 2026-10-25, with one correction applied on approval: the cap check increments first and then compares (`++count >= restartCap` → report `restartCapReached` once → `failed`), matching BR-U10-17's "at `restartCap` failures". With a cap of 3 the third counted failure reports. TP-11 (c) and the cap pin test use that count.
**Reopens** Functional Design narrowly. Everything not named here stays as approved on 2026-10-25.
**Decision recorded**: James Petersen, 2026-10-25, approved a change to the `SttEngine` stable contract surface (AGENTS.md "stop and ask") for an additive error channel.
**Review decisions applied (Opus, 2026-10-25):** R1 capability interface, with a method instead of a setter; R2 keep the flush, on `done` only; R3 keep the notice; R4 numbers left to NFR Requirements, counting rule changed. Fixes 1 to 6 below.

## 1. Finding N9 (blocking, found in the NFR Requirements review)

`PlatformSttEngine.startListening()` calls `speech_to_text`'s `listen()` once. `initialize()` registers no `onStatus` or `onError` listener, and nothing else in `zip_core` or `zip_captions` restarts listening. The locked plugin (7.3.0) is built for short phrases (README lines 9-10, 347-352). Android ends a session when the speaker pauses, and iOS stops a task after about one minute (README line 501). `SttEngine` has no error channel, so `SttSessionManager`'s one-restart recovery (REL-U2.1) never fires for a real engine, and a recogniser error after `listen()` cannot reach the UI.

Result without this amendment: the first utterance is captioned, then captions silently stop while the state stays Recording and the screen stays on. S-22 AC3 fails on every device. Nothing here is device-tested.

## 2. Scope of the amendment

1. Internal restart inside `PlatformSttEngine` (section 4).
2. An additive error channel from an engine to `SttSessionManager`, then `_handleEngineError`, then the UI (section 3).
3. `onDevice: true` in the same `PlatformSttEngine` change (NFR Q7=C, from Phase 1 NFR-2.1).
4. A start-race rule in `RecordingStateNotifier.start()` (BR-U10-25).
5. Testable properties for all of it (section 6).

Not in scope: `SttResult` (unchanged), `RecordingState` (unchanged), a different engine, the Android restart chime and the gap between sessions (device-pass observations, not design blockers).

## 3. The error channel

### 3.1 Shape (decided, R1 = A)

```dart
/// An engine that can report lasting errors after startListening() succeeded.
abstract interface class SttErrorSource {
  /// Sets (or clears with null) the listener. Called at most once per lasting error.
  void setErrorListener(void Function(SttEngineError error)? listener);
}

enum SttEngineErrorKind {
  recognizerUnavailable, onDeviceModelMissing, localeUnsupported,
  permissionRevoked, restartCapReached,
}

/// By construction it carries no free text, so it cannot carry a transcript.
final class SttEngineError { const SttEngineError(this.kind); final SttEngineErrorKind kind; }
```

A method, not a setter: `zip_core` uses `very_good_analysis`, which enables `avoid_setters_without_getters`, so a lone `set errorListener` would fail `flutter analyze`.

`SttSessionManager.initialize()` does `final e = _engine; if (e is SttErrorSource) e.setErrorListener(_forward);` and clears it in `dispose()`. `_forward` maps the kind to a `RecordingError` and calls the existing `onError`, which is `RecordingStateNotifier._handleEngineError`.

Why this shape: it is additive. `SttEngine`, `FakeSttEngine`, `SherpaOnnxSttEngine` and every mock (about ten test files implement `SttEngine`) need no edit, and ADR-005 gets an addendum at Documentation Refinement. A callback mirrors `onResult`; a stream was rejected (one consumer, plus controller lifecycle). The cost is an `is` check, a capability convention, documented in the `SttEngine` doc comment.

### 3.2 `zip_broadcast` does not receive these errors (recorded, not fixed)

`zip_broadcast`'s `BroadcastRecordingNotifier` drives engines directly through `sttEngineFactoryProvider`, not through `SttSessionManager`, so it will not receive `SttErrorSource` errors. This stays record-only under BR-U10-14 and is added to the Backlog entry.

### 3.3 Mapping to existing `RecordingError` factories (no new factory)

*Amendment 02 (proposed, privacy) changes the `onDeviceModelMissing` row to a new `onDeviceRecognitionUnavailable()` factory and adds an on-device check before every `listen()`; see `amendment-02-fail-closed-on-device.md`.*

| `SttEngineErrorKind` | `RecordingError` |
|---|---|
| `recognizerUnavailable` | `engineInitFailed()` |
| `onDeviceModelMissing` | `engineRequiresModelDownload()` |
| `localeUnsupported` | `localeNotSupported(localeId)` |
| `permissionRevoked` | `permissionDenied()` |
| `restartCapReached` | `engineStartFailed()` |

### 3.4 Recovery interplay (REL-U2.1)

A lasting error reaches `_handleEngineError`, whose existing single recovery attempt calls `handleEngineError`: `stopListening()`, `initialize()`, `startListening()`. That also resets the engine's cap counter and leaves `failed`. The worst case before the session stops is two caps' worth of failures. A normal session end never reaches this path. Because `SpeechToText.initialize()` returns early once it has succeeded (`speech_to_text.dart:313-319`), listeners passed to it on that re-initialise are ignored; BR-U10-24 sets them directly.

## 4. `PlatformSttEngine` session loop

Intent states: `idle`, `listening`, `paused`, `stopped`, `failed`. Plugin signals: status `listening`, `notListening`, `done` (the plugin's `doneNoResult` reaches Dart as `done`, and the Dart layer holds `done` back until the final result has been delivered, `speech_to_text.dart:708-724`), errors (`errorMsg`, `permanent`), results, and a restart timer.

### 4.1 Error code classes (decided by code, never by `permanent`)

Android's `sendError` always sets `permanent: true` (`SpeechToTextPlugin.kt:730-733`) and iOS does the same (`SpeechToTextPlugin.swift:611, 786`), so the flag carries no information and is ignored.

| Class | Codes | Effect |
|---|---|---|
| **Silence** (a normal end) | `error_no_match`, `error_speech_timeout` | Restarts, reports no error, never counts toward the cap. The plugin already turns a quiet `no_match` into `speech_timeout` (`:697-699`). |
| **Lasting** | `error_permission` → `permissionRevoked`; `error_language_unavailable` → `onDeviceModelMissing`; `error_language_not_supported` → `localeUnsupported` | Report once, stop restarting, enter `failed`. |
| **Transient** | everything else (`error_busy`, `error_client`, `error_audio_error`, `error_network*`, `error_server*`, `error_too_many_requests`, `error_unknown`) | Restarts and counts toward the cap. |

The exact Android and iOS code strings are verified against the locked source at Code Generation (R5). A code that is not recognised is treated as transient.

### 4.2 Rules

| ID | Rule |
|---|---|
| BR-U10-15 | **Restart on `done` only, exactly once per session end.** Android sends `notListening` and then `done`, including after an error (`:387-405, :718-721`). Errors only classify the session (they record the worst class seen in this session); `notListening` does nothing; `done` drives the restart. A guard (a per-session flag) makes a second `done` or an error followed by `done` produce one restart. On `done`, when the intent is `listening`: lasting → already `failed` (see BR-U10-18); otherwise count (BR-U10-17), then restart after `restartDelay` with the same locale and callback, with no error reported. This is not an error and does not use REL-U2.1's one-restart budget. |
| BR-U10-16 | **Final results first, flush on `done` only.** On `done`, if an interim result is pending and no final result for it arrived, the engine delivers that text once as `isFinal: true` before restarting. It never flushes on `notListening` (the final result may still be on its way). The held text lives in memory only and is never logged. Nothing is delivered twice. |
| BR-U10-17 | **Cap counting.** Silence never counts. At `done`, a session counts as one failure only if (a) it saw a transient-class error, or (b) it lasted less than `immediateFailureWindow` with no result delivered and no silence code. Any delivered result resets the count. Silence ends neither increment nor reset it. At `restartCap` failures the engine stops restarting, enters `failed` and reports exactly one `SttEngineError(restartCapReached)`; no restart and no further error until a new `startListening()`. `restartCap`, `immediateFailureWindow` and `restartDelay` are named constants whose numbers NFR Requirements sets. `restartDelay` is checked on a device because Android returns `error_busy` if a recogniser restarts too soon. |
| BR-U10-18 | **Lasting errors.** On a lasting-class error the engine enters `failed` at once and reports exactly one `SttEngineError` (mapped as in 4.1); a following `done` restarts nothing. |
| BR-U10-19 | **Stop and pause win.** `stopListening()` and `pause()` set the intent before calling the plugin and cancel any pending restart timer, so the trailing `done` never restarts. `resume()` clears the pause and starts a session (as today). `dispose()` cancels the timer and clears the callbacks and the error listener. The engine never restarts after `stop()` or `pause()` until the next `startListening()` or `resume()`. |
| BR-U10-20 | **On-device.** `listen()` is called with `SpeechListenOptions(onDevice: true, partialResults: true, cancelOnError: false)` instead of the deprecated arguments. On iOS this sets `requiresOnDeviceRecognition`, so a locale with no on-device model fails instead of falling back. On Android API 31 and later it prefers `createOnDeviceSpeechRecognizer`, and otherwise falls back silently to the default recogniser; that fallback is a known gap for the device pass. The iOS Simulator may not support on-device recognition, so Simulator runs may show the failure path and only a physical device proves captioning. |
| BR-U10-21 | **Logging.** The new path logs state transitions and `SttEngineErrorKind` names only. No result text, no pending-interim text, no raw plugin message. |
| BR-U10-22 | **Session manager.** `SttSessionManager` registers the error listener when it initialises an engine that is an `SttErrorSource`, forwards each error once as a `RecordingError` through the existing `onError`, and clears the listener on `dispose()`. Errors that arrive while the state is not Recording or Reconnecting are ignored, as `_handleEngineError` already does. |
| BR-U10-23 | **Mid-session stop notice (kept, R3).** When `RecordingScreen` leaves for History because a session reached `StoppedState` with a non-null `lastError`, it shows a one-time `SnackBar` with the localised text for the error's kind (the same classification as `StartFailureView`, without "Open settings"). |
| BR-U10-24 | **Assign the listeners directly.** After `_stt.initialize()` returns, `PlatformSttEngine` sets the public `_stt.statusListener` and `_stt.errorListener` fields itself (`speech_to_text.dart:203-204`), on every call to its own `initialize()`. It does not rely on arguments to `SpeechToText.initialize()`, because once that has succeeded a second call returns before assigning any listener (`:313-319`) and the first call assigns `null` when none is passed. |
| BR-U10-25 | **Close the race during start.** If an engine error arrives while `RecordingStateNotifier.start()` is still running, after `startListening()` returned `true`, the Q5 wrapper has stored it in `lastError`. Then `start()` does not move to Recording: it stops the session manager, stays at `IdleState`, acquires no wake lock, publishes no `SessionStateEvent`, and `RecordingScreen` shows the failure panel from `lastError`. Without this the engine is `failed` with its one error spent and the screen stalls silently. |

## 5. Flow 5. Continuous listening (engine internals)

```
startListening ─ listen(onDevice) ─► listening (new session; per-session worst class = none)
 results ───────────────────────────► onResult ; reset failure count ; mark session "had result"
 plugin error (classify by CODE, not by `permanent`)
   ├─ lasting ........................► report once, intent = failed  (BR-U10-18)
   ├─ transient ......................► session worst = transient
   └─ silence ........................► session worst = max(session worst, silence)
 plugin notListening ................► nothing (no flush, no restart)
 plugin done  (final result already delivered by the Dart layer)
   ├─ intent != listening ............► nothing (stop/pause won, or already failed)
   ├─ pending interim ................► deliver once as final   (BR-U10-16)
   ├─ count failure? (transient seen, or < window with no result and no silence)
   │     ++count >= restartCap ? report restartCapReached once → failed : continue
   └─ otherwise ......................► wait restartDelay → listen again, no error
                                         (one restart per session; guard against error+done)
stop / pause .......................► set intent, cancel timer, call plugin
```

## 6. Testable properties (PBT-01)

| ID | Category | Property | Component |
|---|---|---|---|
| **TP-11** | Stateful (PBT-06), model-based | Over random command sequences (start, stop, pause, resume, status `notListening`, status `done`, interim result, final result, an error with each code class — **silence, lasting, transient** — optionally followed by `done`, timer advance under fake time) against a model of the intent states, checked after each command: (a) **no `listen()` call after `stop()` or `pause()`** until the next `start` / `resume`; (b) **a normal end while `listening` causes exactly one new `listen()` and zero errors**; (c) **reaching the cap reports exactly one error** (the increment-then-compare count: with `restartCap = 3` the third counted failure reports), then no further `listen()` and no further error until the next `start`; (d) at most one error per `start`; (e) **silence ends never count toward the cap and never report an error**; (f) **a session that ends with an error followed by `done` restarts exactly once**; (g) **`notListening` or an error on its own never causes a `listen()`**; only `done` does. Example-based pins (PBT-10): the iOS one-minute end restarts, the Android pause-end restarts, many silence ends in a row do not trip the cap, a run of transient errors does, and `permanent: true` on a silence code is still silence. | `PlatformSttEngine` (fake `SpeechToText`) |
| **TP-12** | Invariant (SECURITY-03) | For generated transcript text delivered through results and held as pending interim, no emitted `SttEngineError`, no `RecordingError` produced from one, and no log record on this path contains it. `SttEngineError` has no free-text field, so the first part holds by construction. Extends TP-6. | engine, session manager |
| **TP-13** | Invariant | Mapping is total and deterministic: every `SttEngineErrorKind` maps to one existing `RecordingErrorFactories` error, and every code class maps as in 4.1. | `SttSessionManager`, `PlatformSttEngine` |
| **TP-14** | Invariant | For any sequence of interim results followed by `done`, every pending interim text is delivered as final at most once and before the next `listen()`; nothing is flushed on `notListening`. | `PlatformSttEngine` |
| **TP-2 (extended)** | Invariant (regression) | The reconnect path from the first design still holds **with real engine errors now arriving** through an `SttErrorSource` fake: an error while Recording → `ReconnectingState` and, on a successful restart, back to Recording with `lastError` cleared; a failed restart or second error → `StoppedState` with the transcript finalised and the wake lock released; an error while paused or stopped is ignored; a user stop during recovery is not overwritten. | `RecordingStateNotifier`, `SttSessionManager` |
| **TP-1 (new row)** | Invariant, table-driven | **An engine error arrives while `start()` is still running, after `startListening()` returned `true`** → after `start()`: state `IdleState`, `lastError` equals the mapped error, `stop` was called on the session manager, no wake lock, no `SessionStateEvent`. Added to the TP-1 table in `business-logic-model.md`. | `RecordingStateNotifier` |

PBT-09 note carried from the NFR answers: the repo shim (`test/helpers/pbt.dart`) runs fixed seeds 0 to 99, has no shrinking and prints no seed. For TP-11 a failing sequence must be reproducible from the fixed seed and the command list printed in the failure message.

## 7. Compliance of the amendment

| Rule | Status |
|---|---|
| SECURITY-03 | Compliant by design: `SttEngineError` has no free text; BR-U10-21; TP-12 |
| SECURITY-15 | Compliant by design: bounded restarts (cap), exactly one error, a guard against double restart, timers and callbacks released in `dispose()` (BR-U10-19), failures fail closed (BR-U10-25) |
| SECURITY-10 | N/A here; no new dependency |
| PBT-01, 03, 06 | TP-11 (stateful), TP-12, TP-13, TP-14, extended TP-2, TP-1 new row |

No blocking findings.

## 8. Decisions made and what remains

- **R1** capability interface with `setErrorListener(...)`: decided. **R2** flush kept, on `done` only: decided. **R3** notice kept: decided. **R4** numbers (`restartCap`, `immediateFailureWindow`, `restartDelay`) left to NFR Requirements: decided; the counting rule is fixed here.
- **R5.** The exact Android and iOS error-code strings are verified at Code Generation against the locked plugin source (Android codes were read in this review; the iOS codes are still to be read).
- **Outside this amendment:** Q4 is resolved (new IDs `app.zipcaptions.captions`, 2026-10-25). Nothing in it changes this amendment.

## 9. Documents amended with this

`domain-entities.md` (E5 as a method), `business-rules.md` (pointer to BR-U10-15..25), `business-logic-model.md` (Flow 5 pointer, the TP-1 new row, TP-11 pointer), `handoff-summary.md`, and the Backlog entry in `aidlc-state.md` (the `zip_broadcast` note).
