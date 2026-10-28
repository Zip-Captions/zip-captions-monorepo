# Functional Design Plan: Unit 10, Mobile Platform Readiness (S-22, Alpha 1)

**Stage**: Construction, Functional Design (Phase 2)
**Opened**: 2026-10-25, branch `feature/mobile-platform-readiness`
**Scope**: G10 only (app-level speech-recogniser registration). The `ios/` and `android/` runner work (G2, G3, G5, G9) is NFR Requirements and Code Generation material, not Functional Design.
**Constraints**: `SttEngine` and `SttResult` are stable contracts (AGENTS.md) and are not changed. No transcript text in logs (SECURITY-03). `zip_broadcast` is recorded only, not fixed. Nothing is registered locally, even temporarily, without James Petersen's approval.

## Plan checklist

- [x] Step 1. Analyse unit context (unit-of-work, S-22, evidence file, `bootstrap.dart`, `SttEngine`, `PlatformSttEngine`, registry, session manager, `RecordingStateNotifier`, `RecordingScreen`, `zip_broadcast` factory)
- [x] Step 2. Create this plan
- [x] Step 3. Generate questions (below)
- [x] Step 4. Collect answers and check for ambiguity (answered 2026-10-25; Q5 and Q7 are "Other" and clarified inline)
- [ ] Step 5. Generate `business-logic-model.md`, `business-rules.md`, `domain-entities.md` in `aidlc-docs/construction/mobile-platform-readiness/functional-design/`
- [ ] Step 6. Include a "Testable Properties" section (PBT-01) and a Security Compliance and PBT Compliance summary. It must contain TP-1 and TP-2 from "Required testable properties" below, word for word in substance.
- [ ] Step 7. Write `functional-design/handoff-summary.md` (stage-handoff override)
- [ ] Step 8. Present the completion message and stop at the approval gate. NFR Requirements does not start.
- [ ] Step 9. After approval only: log it in `audit.md`, tick Functional Design in `aidlc-state.md`

## Findings from the code read (they shape the questions)

These come from reading source on 2026-10-25. None are device-tested.

| # | Finding | Evidence |
|---|---|---|
| F1 | **No production `AudioDeviceService` exists.** `PlatformSttEngine` and `SherpaOnnxSttEngine` both require one in their constructors. `audioDeviceServiceProvider` throws `UnimplementedError` unless overridden, and no app overrides it. The only implementation is `zip_core/test/helpers/mock_audio_device_service.dart`. So registering `PlatformSttEngine` needs a concrete `AudioDeviceService` first. This is a second missing piece beyond G10. | `audio_device_service_provider.dart`; search for `implements AudioDeviceService` finds only the test mock |
| F2 | **A failed start shows nothing in `zip_captions`.** `RecordingScreen.initState` calls `notifier.start()`. On any start failure, `start()` returns with state still `IdleState`. No file under `zip_captions/lib` reads `lastError` or calls `openMicrophoneSettings()`. The user sees an empty recording screen. S-22's second acceptance criterion (permission-denied state with a way to open settings) has no UI behind it. **Corrected 2026-10-25:** `_lastError` is set only on the engine-null and `startListening()`-false paths. Permission-denied and init-failed errors reach `_handleEngineError` through the `onError` callback, which returns early while the state is `IdleState`, so those errors are dropped and `lastError` stays `null`. `lastError` is also a plain getter outside the notifier's state, so a failed start causes no rebuild. | `recording_state_notifier.dart:65-106, 185-190, 223-232`; `stt_session_manager.dart:175-202`; `recording_screen.dart:29-44`; `zip_broadcast`'s `lastError` belongs to its own `BroadcastIdleState`, so it is unrelated |
| F3 | **`PlatformSttEngine.isAvailable()` is false until `initialize()` has succeeded**, because it returns `speech_to_text`'s `isAvailable` flag. A bootstrap-time availability check would wrongly drop the engine. | `platform_stt_engine.dart:60-67` |
| F4 | **One failure signal covers several causes.** `SpeechToText.initialize()` returns `false` for microphone denial, iOS speech-recognition denial, and no recogniser installed. `SttSessionManager` maps every `false` to the same generic `engineInitFailed()` message. | `platform_stt_engine.dart:49-58`; `stt_session_manager.dart:65-77` |
| F5 | **Registration order decides the default.** `defaultEngine` is the first registered engine. `FakeSttEngine` is exported from the public `zip_core` barrel and annotated `@visibleForTesting`. | `stt_engine_registry.dart:37-40`; `zip_core.dart:8` |
| F6 | `sherpa_model_catalog_provider.dart:106` unregisters `'sherpa-onnx'` but nothing registers it. | `grep register(` over `zip_core/lib` |
| F7 | **Unit 10's scope widens.** The unit-of-work says Functional Design adds "no new entities beyond the registration seam". The answers to Q3 and Q5 add a minimal `AudioDeviceService` and a failure state for `zip_captions`, plus a small `RecordingStateNotifier` change in `zip_core`. James Petersen approved this on 2026-10-25. | `phase2-unit-of-work.md:352` |
| F8 | One existing log line records a whole exception (`$e`) instead of `e.runtimeType`, unlike the rest of the STT path. | `recording_state_notifier.dart:102` |

---

## Questions

Please fill in the letter after each `[Answer]:` tag. My recommendation is marked on each question. Question 3 and Question 5 depend on F1 and F2, which are new findings and are your call because they widen Unit 10.

## Question 1
Which engine does `zip_captions` register as its real speech recogniser on iOS and Android?

A) `PlatformSttEngine` only. Sherpa-ONNX needs a model download and is part of the parked on-device multilingual unit. (Recommended)
B) `PlatformSttEngine`, plus `SherpaOnnxSttEngine` registered when a model is present
C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 2
`zip_captions` also ships on desktop, where a release build has the same missing-engine defect. Which platforms does the new registration cover?

A) iOS and Android only. Desktop stays as it is and is recorded as the same defect for a later unit. Unit 10 verifies only what it ships. (Recommended)
B) Every platform `speech_to_text` supports (iOS, Android, macOS, Windows) through the same seam, with only mobile verified in this unit
C) Other (please describe after [Answer]: tag below)

[Answer]: A. The platform check must actively leave desktop out: macOS without a speech usage key in `Info.plist` would be killed by the OS at the permission request, which is worse than today's error.

## Question 3 (new finding F1)
`PlatformSttEngine` cannot be built without an `AudioDeviceService`, and no production implementation exists. How should Unit 10 supply one?

A) Add a minimal mobile `AudioDeviceService` in `zip_core`. It lists one system-default input, stores the preference in SharedPreferences under `audio.preferredInputDeviceId` as the interface documents, and does no routing. The interface already allows "a single default entry if enumeration is unsupported". This adds one concrete entity to Unit 10. (Recommended)
B) Make the `deviceService` constructor parameter of `PlatformSttEngine` optional, so mobile passes none. This changes a Phase 1 Unit 2 constructor and its tests, though not the `SttEngine` interface.
C) Other (please describe after [Answer]: tag below)

[Answer]: A. Bootstrap also overrides `audioDeviceServiceProvider` with it, so a future reader of the provider gets the service instead of `UnimplementedError`.

## Question 4
When is the engine's availability checked? (F3: `isAvailable()` is false until `initialize()` has run.)

A) Register the engine unconditionally at bootstrap and make no platform call there. `SttSessionManager.initialize()` at Start Captioning is the single place that finds out whether it works. (Recommended)
B) Call `initialize()` once at bootstrap and register the engine only if it succeeds. This triggers the OS speech-recognition prompt at app launch, before the user asks for captions.
C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 5 (new finding F2)
When the engine is unavailable, `initialize()` fails, or permission is denied, the user currently sees an empty recording screen. S-22's second acceptance criterion needs a visible permission-denied state with an "open settings" action. Where does that behaviour belong?

A) In Unit 10. Functional Design defines a failure state for `zip_captions` that shows the `RecordingError` message and, for the permanently-denied case, calls `openMicrophoneSettings()`. It reads `lastError` through the existing notifier, with no change to `SttEngine`, `SttResult` or `RecordingState`. (Recommended: S-22 cannot pass without it.)
B) Record it as a new gap G11 and assign it to a later unit, leaving Unit 10 with registration only. S-22's AC2 then stays unmet when Unit 10 closes.
C) Other (please describe after [Answer]: tag below)

[Answer]: C. A, plus the fix the corrected F2 requires. In Unit 10: (1) `RecordingStateNotifier.start()` keeps the `RecordingError` reported during `initialize()`, which `_handleEngineError` drops today while the state is `IdleState`. (2) `RecordingScreen` waits for `start()` to finish, then shows the failure state from `lastError`. No change to `SttEngine`, `SttResult` or `RecordingState`.

## Question 6 (depends on F4)
Should the failure messages tell the causes apart? Today a denied speech-recognition permission on iOS, a missing recogniser on Android, and a generic init failure all read "Speech recognition engine failed to initialize."

A) Reuse the existing `RecordingErrorFactories` messages. One generic init-failure message, plus the existing microphone-denied messages. No new error kinds. (Recommended: the engine cannot distinguish the causes today, and splitting them would need changes to the engine's contract surface.)
B) Add one new factory, "speech recognition unavailable on this device", used when the engine reports unavailable, and keep the generic message for other init failures. The engine still cannot tell iOS speech denial from the rest.
C) Other (please describe after [Answer]: tag below)

[Answer]: A. The failure state also offers the "Open settings" action for the generic init failure, not only for permanently-denied microphone access, because a denied iOS speech-recognition permission shows up as that generic failure. A `Permission.speech` check in the session manager is the fuller fix, but it needs another Podfile flag, so NFR Requirements decides it.

## Question 7
Does the debug-only `FakeSttEngine` stay registered in debug builds? (F5: registration order decides the default engine.)

A) Debug registers only the real engine by default. The fake is registered only when a debug run passes `--dart-define=ZIP_FAKE_STT=true`, so emulator QA exercises the real permission path unless a tester opts out. (Recommended)
B) Debug registers the real engine first (so it is the default) and the fake second. The fake is selectable through the active-engine setting only, which has no debug picker today.
C) Debug keeps today's behaviour: only the fake. Real-engine runs need a code change.
D) Other (please describe after [Answer]: tag below)

[Answer]: D. A, with two fixes. (a) When `ZIP_FAKE_STT=true`, debug registers the fake only, so the flag actually changes the default engine. (b) Debug also registers the fake when the platform has no real engine. Under Q2=A that means desktop, so desktop debug runs keep the fake they use today (Units 8 and 8.1 were tested with it). Rule: in debug, the fake is registered if the flag is set or the platform has no real engine.

## Question 8
How is the fake kept out of release builds?

A) Move the registration decision into one small, pure, testable function (inputs: platform, whether dev engines are allowed). The call site passes `kDebugMode && fakeFlag`. A unit test asserts that a `false` input never registers the fake, because `kDebugMode` itself cannot be flipped in a test. (Recommended)
B) Keep the inline `if (kDebugMode)` guard as it is today, with a code-review check only
C) Other (please describe after [Answer]: tag below)

[Answer]: A. The call-site input stays a compile-time constant (`kDebugMode && bool.fromEnvironment('ZIP_FAKE_STT')`) so release builds strip the fake out entirely.

## Question 9
How is "no transcript content in logs" shown for the new path?

A) A test that drives a session with generated transcript text, captures every `package:logging` record emitted (message, error and stack trace), and asserts that none contains the generated text. It is recorded as a PBT-01 invariant, plus one example-based test. (Recommended)
B) Code review of the new code only
C) Other (please describe after [Answer]: tag below)

[Answer]: A. The test sets `Logger.root.level = Level.ALL`, because release runs at WARNING and would hide info-level records. The F8 log line is changed to log `e.runtimeType`.

## Question 10
`zip_broadcast` has the same defect (its factory returns the fake in debug and throws `UnimplementedError` in release). Where is it recorded?

A) In this unit's evidence and in `audit.md`, plus a Backlog entry in `aidlc-state.md` that names the defect and says it is unfixed. No code change. (Recommended)
B) In this unit's evidence and `audit.md` only
C) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Required testable properties (James Petersen, 2026-10-25)

These guard the `RecordingStateNotifier` change from Q5. They must appear in `business-logic-model.md`'s "Testable Properties" section, and Code Generation must implement each one as a test in `zip_core/test`.

**TP-1. Every start failure leaves its error in `lastError`.** For each start-failure cause below, after `start()` completes: the state is `IdleState`, `lastError` equals the error that cause maps to, no wake lock is acquired, and no `SessionStateEvent` is published. The test runs one case per row (table-driven), so a missing case fails by name.

| Cause | Expected `lastError` |
|---|---|
| No engine registered (`sttEngineProvider` returns `null`) | `engineInitFailed()` |
| Microphone permission denied | `permissionDenied()` |
| Microphone permission permanently denied (before or after the request) | `permissionPermanentlyDenied()` |
| `initialize()` returns `false` | `engineInitFailed()` |
| `initialize()` throws | `engineInitFailed()` |
| `startListening()` returns `false` or throws | `engineStartFailed()` |

Today the permission rows and both `initialize()` rows fail (corrected F2). Messages are compared through the factories, not by retyping their strings.

**TP-2. The engine-error and reconnect path is unchanged.** `_handleEngineError`'s Recording and Reconnecting branches behave as they did before the fix:
- An engine error while recording moves to `ReconnectingState`, and a successful restart returns to `RecordingActiveState` with `lastError` cleared.
- A failed restart, or a second error after one restart attempt, moves to `StoppedState`, finalises the transcript and releases the wake lock.
- An engine error while paused or stopped is ignored.
- If the user stops while recovery is in progress, the state the user set is not overwritten.

These are existing behaviours. If current tests already cover a bullet, Code Generation names that test in the code summary instead of duplicating it, and adds tests only for bullets with no coverage.

---

## What this stage will produce after the answers

- `business-logic-model.md`: the registration seam, the start-up flow from Start Captioning to listening, and each failure path (engine missing, permission denied, `initialize()` false or throwing, `startListening()` false)
- `business-rules.md`: engine selection per platform, fake gating, no-transcript-logging rule, `zip_broadcast` record-only rule
- `domain-entities.md`: the registration seam and, depending on your answers to Questions 3 and 5, a mobile `AudioDeviceService` and a failure-state view model
- "Testable Properties" (PBT-01), for example: registration never includes the fake when dev engines are disallowed; for any generated transcript, no log record contains it; the default engine is never the fake unless the flag is set
- Security Baseline and PBT compliance summaries, then the approval gate
