# NFR Design Patterns: Unit 10, Mobile Platform Readiness (S-22, Alpha 1)

**Date**: 2026-10-25. **Status**: drafted on the proposed answers in `plans/mobile-platform-readiness-nfr-design-plan.md` (each "proposed by Sonnet, awaiting James Petersen"); awaiting the NFR Design approval gate.
**Inputs**: `nfr-requirements/` (approved 2026-10-25), `functional-design/` including Amendments 01 and 02 (approved 2026-10-25).
**Fixed constraints**: `SttResult`, `RecordingState`, `RecordingError` and the `AudioDeviceService` interface are unchanged; `SttEngine` is extended only by the approved additive `SttErrorSource`; `speech_to_text` stays on 7.3.0; no new package; no source file is changed by this stage.

## 1. Pattern map (NFR to pattern)

| NFR | Pattern |
|---|---|
| NFR-U10-01, 02 (fail-closed on-device) | P1 pre-flight guard |
| NFR-U10-05, 06 (continuous listening, no init timeout) | P2 bounded self-healing loop |
| NFR-U10-07, 08b (a failed start is visible; first error wins) | P3 operation-scoped error capture, P9 failure presentation |
| NFR-U10-08, 08a (mid-session notice; a session stops once) | P4 idempotent single-flight finish |
| NFR-U10-03, 03a (privacy decision; upstream status) | P1, P8 disclosure gate, P10 upgrade seam |
| NFR-U10-09 (platform audio crash) | no in-app pattern possible (recorded); device-pass watch |
| SECURITY-03 | P7 log hygiene |
| SECURITY-09 (fake never in release) | P6 compile-time gating seam |
| SECURITY-10 (one plugin declaration) | P5 factory placement |
| SECURITY-15 (fail closed, release resources) | P1, P2, P4 |
| Screen-on and privacy constraint (the microphone is never live after Stop) | P4 rules (a) to (d), TP-2c |
| PBT-06, 07, 09 | P11 testing patterns |

## 2. Patterns

### P1. Pre-flight guard (fail-closed gate before every `listen()`)

- **Where:** inside `PlatformSttEngine`, as one private method `_onDeviceAllowed(localeId)` called immediately before every call to the plugin's `listen()`: the first start, an internal restart, the restart in `resume()`, and the outer REL-U2.1 restart (all reach the engine through `startListening()`).
- **The guard owns its failure modes** (plan Q6 = A): the checker call is wrapped in `try`/`catch` and `Future.timeout(limits.onDeviceCheckTimeout)`; any exception, `MissingPluginException`, `PlatformException` or timeout is `false`. A checker (real or fake) therefore cannot hang or crash a listen, and there is exactly one place to test.
- **No cache, no prefetch** (plan Q7 = A): the result is used once and discarded (BR-U10-26). The extra method-channel hop sits inside `restartDelay`; its cost and any lost words are the Amendment 01 device-pass observations.
- **Outcome:** `true` → `listen(onDevice: true, partialResults: true, cancelOnError: false)`. `false` → no `listen()`; report `SttEngineError(onDeviceModelMissing)` once through the error listener and return `false` (BR-U10-27); a refusal during a restart is lasting and moves the engine to `failed`.
- **Never configured:** `androidIntentLookup` (BR-U10-32). A test asserts the engine passes none of the plugin's initialise options that would change the recogniser.
- **Logging:** the guard logs only the boolean result (P7).

### P2. Bounded self-healing loop (continuous listening)

- **Shape:** one private `_SessionLoop` in `platform_stt_engine.dart` (plan Q1 = A), holding the intent (`idle`, `listening`, `paused`, `stopped`, `failed`) and one per-session record: `startedAt`, `deliveredResult`, `worstClass` (none < silence < transient < lasting), `restartScheduled`.
- **Inputs:** the plugin's `statusListener` and `errorListener` fields, assigned directly after `_stt.initialize()` returns (BR-U10-24), results, the restart timer, and the public API (`startListening`, `stopListening`, `pause`, `resume`, `dispose`).
- **Error classes by code, never by `permanent`** (Amendment 01, section 4.1): silence (`error_no_match`, `error_speech_timeout`) restarts and never counts; lasting (`error_permission`, `error_language_unavailable`, `error_language_not_supported`) reports once and stops; everything else is transient, restarts and counts. An unrecognised code is transient. The code table is one `const` map in the engine file so it can be re-verified when the plugin is upgraded (R5).
- **Restart on `done` only, once per session end:** errors and `notListening` only update the per-session record; `done` decides. `restartScheduled` is the guard that makes "error then `done`" restart exactly once. The single exception is a `listen()` that throws during a restart, where no session exists and no `done` will come (BR-U10-30); that throw is treated as a transient session end and the next attempt is checked again first.
- **Failure budget:** `++count >= restartCap` → report `restartCapReached` once → `failed`. Silence neither increments nor resets; a delivered result resets. The session length is measured with an injected `DateTime Function() now` (plan Q2 = A; `package:clock` is only a dev dependency, D1).
- **Tunable numbers in one file** (plan Q3 = A): `SttListeningLimits` and `defaultSttListeningLimits` in `zip_core/lib/src/constants/` (the `defaultBroadcastLimits` precedent, D2): `restartCap = 3`, `immediateFailureWindow = 2 s`, `restartDelay = 250 ms`, `onDeviceCheckTimeout = 2 s`. Changing them at the device pass is a one-file edit, not a design change.
- **Final-first flush:** on `done`, a pending interim is delivered once as `isFinal: true` before the restart is scheduled, and never on `notListening` (BR-U10-16). The held text is in memory only.
- **Stop and pause win (BR-U10-19):** both set the intent first, cancel the timer, then call the plugin; `dispose()` cancels the timer and clears the callbacks and the error listener. Cancel on any `ListenFailedException` (BR-U10-31).
- **No timeout on `engine.initialize()`** (NFR-U10-06): the iOS permission prompt is inside it.
- **Resource cleanup (SECURITY-15):** the restart `Timer`, the plugin listener fields and the error listener are released in `dispose()` and in `failed`.

### P3. Operation-scoped first-error capture

- **Where:** `RecordingStateNotifier.start()` and `resume()` (plan Q5 = A).
- **Mechanism:** a nullable `RecordingError? _captured` and a `bool _capturing`, set when the operation begins and cleared when it ends. The `onError` wrapper writes `_captured` only if it is null, and otherwise ignores the error while `_capturing`. After `startListening()` returns, `start()` uses `_captured` for: the returned-`false` branch (BR-U10-28 b, which must not overwrite), and the race rule (an engine error captured after `startListening()` returned `true` stops the session manager, stays `IdleState`, acquires no wake lock; BR-U10-25). `resume()` uses it for BR-U10-36.
- **Outside an operation** the wrapper behaves exactly as `_handleEngineError` does today (TP-2 unchanged).

### P4. Idempotent single-flight finish (exactly-once stop)

- **Where:** one private `Future<void> _finishSession(String sessionId)` in `RecordingStateNotifier`, with a `Future<void>? _finishing` field (plan Q4 = A).
- **Mechanism:** the first caller starts the routine (finalise the transcript, set `StoppedState`, publish the `SessionStateEvent`, release the wake lock) and stores its future; every later caller returns **that same future**, so a user `stop()` during an in-flight finalise awaits it instead of racing it. `start()` and `clearSession()` reset `_finishing`.
- **Callers:** both `_handleEngineError` branches, the recovery future's failure and exception branches, a refused `resume()`, and the user's `stop()`. This closes the double-stop in the REL-U2.1 refusal path (the recovery future resumes while the first finalise still awaits and still sees `ReconnectingState`).
- **Why a shared future and not a boolean:** a boolean would let a Stop tap return before the first finalise completes, so the UI could navigate away mid-finalise.
- **Stop must win against the REL-U2.1 recovery (Opus review fix, 2026-10-25).** The existing `stop()` (`recording_state_notifier.dart:155-175`) does `await _sessionManager.stop()`, then `await _finalizeTranscript()`, then sets `StoppedState`, publishes and releases the wake lock, and the state stays `ReconnectingState` across both awaits. The recovery's `handleEngineError` (`stopListening`, `initialize`, `startListening`; `stt_session_manager.dart:146-163`) can therefore call `startListening` **after** the user's `stop()` has already stopped the engine, and its `state is! ReconnectingState` guard (`:261`) still passes, so it sets `Recording`; `stop()` then sets `Stopped` and releases the wake lock while the engine is still listening. With Amendment 01's self-restart loop the microphone would stay live after Stop with the screen allowed to sleep, which breaks the screen-on consent constraint and the privacy stance. As first drafted, P4 did not close this: `stop()` reached `_finishSession` only after its first await, and the recovery's success branch never checked `_finishing`. The rules:
  - **(a)** `stop()` calls `_finishSession` **synchronously at entry**, so `_finishing` is set before any `await`.
  - **(b)** `_finishSession`'s first step, for every caller, is `_sessionManager.stop()`; then finalise, set `StoppedState`, publish, release the wake lock.
  - **(c)** When `handleEngineError` returns, the recovery future checks `_finishing != null` **first**. If it is set, the recovery calls `_sessionManager.stop()` again (its restart may have started the engine) and returns without changing state, `lastError` or the wake lock.
  - **(d)** `_handleEngineError` ignores errors once `_finishing` is set.
  The property that guards it is **TP-2c** (section P11).

### P5. Capability interface and factory placement

- **Error channel:** `SttErrorSource.setErrorListener(...)` plus `SttEngineError` (kind only, no free text) as a sibling of `SttEngine` in `zip_core`. `SttSessionManager.initialize()` does `if (engine is SttErrorSource) engine.setErrorListener(_forward)` and clears it in `dispose()`. `_forward` maps the kind through the Amendment 02 table (`onDeviceModelMissing` to `onDeviceRecognitionUnavailable()`).
- **Factory** (plan Q10 = A, confirming correction 3): `createPlatformSttEngine({required OnDeviceSupportChecker onDeviceSupportChecker, required AudioDeviceService deviceService})` in `zip_core/lib/src/stt/engines/`, exported from the barrel. It constructs `SpeechToText()` itself, so `speech_to_text` stays declared only in `zip_core` and `zip_captions/pubspec.yaml` is unchanged. The engine constructor still takes a `SpeechToText` so tests inject a fake.
- **Checker typedef** `OnDeviceSupportChecker` lives in `zip_core` (platform-free); the method-channel implementation lives in `zip_captions`.

### P6. Compile-time gating seam (dev engine never in release)

`registerSttEngines(registry, {platform, isWeb, allowDevEngines, forceFake, createPlatformEngine})` in `zip_captions/lib/src/services/`: a pure function with no platform call. The call site passes `kDebugMode` and `kDebugMode && bool.fromEnvironment('ZIP_FAKE_STT')`, both compile-time constants, so a release build strips the fake. `createPlatformEngine` is a closure so desktop and web never construct the platform engine (TP-5). TP-10 guards that the real engine is registered.

### P7. Log hygiene (SECURITY-03)

Every new `Logger` call on the path (engine loop, guard, refusal, finalise routine, failure view) logs an enum name, a boolean or `e.runtimeType`, never an interpolated exception or result (plan Q8 = A). The one existing offender (`recording_state_notifier.dart:102`, `$e`) is changed. One test at `Logger.root.level = Level.ALL` drives generated transcripts through the whole path and asserts no record contains them (TP-6, TP-12). No custom lint.

### P8. Disclosure gate (iOS explainer)

- **Where:** `SpeechExplainerGate` in `zip_captions`, consulted by `RecordingScreen` before it calls `start()` on iOS.
- **Mechanism:** a `SharedPreferences` flag `onboarding.speechExplainerSeen`, set only on "Continue"; "Not now" sets nothing and returns to Home with nothing requested. The flag is a non-sensitive convenience, so no secure storage is needed; if it is cleared the explainer simply appears again.
- **Ordering guarantee:** `start()` is unreachable on iOS until the gate has been passed (TP-19). Android has no explainer.
- **Strings:** British English `.arb` keys through `ZcStrings` (D5), provisional until the airplane-mode device check passes; the `Info.plist` text is separate and English-only.

### P9. Failure presentation

`StartFailureView.from(error, platform:, isWeb:)` classifies through the `RecordingErrorFactories` (no retyped strings) into `micDenied`, `micPermanentlyDenied`, `engineInitFailed`, `engineStartFailed`, `onDeviceUnavailable`, `other`. `RecordingScreen` awaits `start()` and shows a failure panel in place of the caption area, **hides `RecordingControlsBar`** while it is shown (the bar spins on `IdleState`), offers "Try again" always and "Open settings" only on iOS and Android for `micPermanentlyDenied` and `engineInitFailed` (never for `onDeviceUnavailable`). The same classification feeds the mid-session notice (BR-U10-23) shown as a one-time `SnackBar` when a session stops with a non-null `lastError`.

### P10. Upgrade seam for the on-device checker

The checker is a `typedef` behind `createPlatformSttEngine`. When a **stable** `speech_to_text` 7.6.0 ships, the runner method channels can be replaced by the plugin's own `has_on_device_support` behind the same typedef, removing the Swift and Kotlin code; R5 (error codes, `done` and `notListening` ordering, listener fields) and the audio-session default (`preserveExistingAudioSession`) are re-verified at that point. Until then the plugin stays on 7.3.0.

### P11. Testing patterns

- **Time:** `fake_async` for the restart timer; an injected `now` function for session length (D1).
- **Doubles:** hand-written fakes for `SpeechToText`, `OnDeviceSupportChecker`, `SttErrorSource` and `AudioDeviceService` (reuse `zip_core/test/helpers/mock_audio_device_service.dart`).
- **Stateful model (TP-11, TP-15):** a model of the intent states over random command sequences (start, stop, pause, resume, `notListening`, `done`, interim and final results, errors of each code class, checker results `true`/`false`/throws, `listen()` outcomes), checked after each command; failing sequences are reproducible from the fixed seed plus the printed command list (the shim runs seeds 0 to 99, has no shrinking and prints no seed).
- **Placement** (plan Q12 = A): `zip_core/test/pbt/` for TP-1, 2, 2b, **2c**, 6, 9, 11, 12 to 15, 17, 18, 20; `zip_captions/test/pbt/` for TP-3, 4, 5, 8, 10, 16, 19, with the shim copied to `zip_captions/test/helpers/pbt.dart`; example-based pins beside each class (PBT-10).
- **TP-2c (stateful, fake time; Opus review fix), `zip_core/test/pbt/`:** for any interleaving of a user `stop()` with the REL-U2.1 recovery (the stop before, during or after each recovery `await`; the recovery succeeding, failing or throwing), (1) **no engine `listen()` happens after `stop()` begins**; (2) **the last engine call is `stopListening`**; (3) the state **never re-enters `Recording` after `stop()` begins** and ends at `StoppedState`; (4) the session is **finalised exactly once**. It extends TP-2b (which covers pairs of stop triggers) to the engine-liveness question.
- **Pinned to the locked plugin:** a test asserts the engine passes no recogniser-changing option and that the error-code table matches the locked 7.3.0 strings.

## 3. Sequences

**Start with a refusal**
```
RecordingScreen ─ (iOS: explainer gate) ─► notifier.start()   [capture on]
   └► sessionManager.initialize ─► (permissions) ─► engine.initialize (assigns plugin listeners)
   └► sessionManager.startListening ─► engine.startListening
         └► _onDeviceAllowed(locale)  ── false ──► errorListener(onDeviceModelMissing) ; return false
   notifier: startListening false ─► _captured already set ─► keep it; stop manager; stay Idle
   RecordingScreen: lastError != null ─► failure panel (no controls bar, no "Open settings")
```

**Refusal during the REL-U2.1 restart (the double-stop case)**
```
engine error while Recording ─► Reconnecting ; _hasAttemptedRestart = true
   recovery: handleEngineError ─► engine.startListening ─► check false ─► error reported
   └► _handleEngineError (state Reconnecting, attempted) ─► _finishSession(id)   [starts, stores future]
   └► recovery future resumes (false) ─► _finishSession(id) ─► returns the SAME future (no second finalise)
   result: one finalise, one Stopped event, one wake-lock release   (TP-2b)
```

**User Stop during the REL-U2.1 recovery (TP-2c)**
```
engine error while Recording ─► Reconnecting ; recovery future starts: handleEngineError (stopListening, initialize, startListening)
user taps Stop ─► stop(): _finishSession called synchronously (_finishing set) ─► sessionManager.stop() ─► finalise ─► Stopped
recovery returns ─► _finishing != null ─► sessionManager.stop() again ; return (no state, lastError or wake-lock change)
result: the engine is stopped, the state never re-enters Recording, one finalise
```

**Refused resume**
```
Paused ─► resume() [capture on] ─► engine check false ─► error captured
   └► resume() returned false and an error was captured ─► _finishSession ; lastError set ; notice shown (BR-U10-36)
```

## 4. NFR Design compliance

| Check | Result |
|---|---|
| Security Baseline | SECURITY-03 (P7), 09 (P1, P6), 10 (P5), 11 (P1), 12 (policy only), 15 (P1, P2, P4): compliant by design; the rest N/A. No blocking findings. |
| PBT-01, 03, 06, 07 | TP-1 to TP-20, TP-2b with the stateful models above; PBT-09 per the shim decision |
| Contracts | `SttResult`, `RecordingState`, `RecordingError`, `AudioDeviceService` unchanged; `SttEngine` extended only by `SttErrorSource` |
