# NFR Requirements: Unit 10, Mobile Platform Readiness (S-22, Alpha 1)

**Date**: 2026-10-25. **Inputs**: `functional-design/` (approved 2026-10-25, with Amendment 01 re-approved the same day), the ten answers in `plans/mobile-platform-readiness-nfr-requirements-plan.md`, and `evidence/q3-throwaway-check.md`.
**Scope limit**: virtual-device evidence only. Latency under 1 s, screen kept on under real power management, and on-device recogniser availability on real hardware are a later physical-device gate and are not claimed here.

## 1. OQ-MA-1 (the gate for this stage): answered

Evidence: `evidence/q3-throwaway-check.md` (iPhone 17 Simulator, iOS 26.0; real `PlatformSttEngine` registered by a throwaway change that was reverted).

- `xcrun simctl privacy help` lists no speech-recognition service, so iOS speech-recognition consent **cannot be pre-granted**. Microphone can be.
- `xcrun simctl privacy <udid> reset all <bundle>` **brings both prompts back** on the next Start Captioning, microphone first and then speech recognition.
- **Consequence for the QA procedure:** iOS emulator QA is scriptable for the microphone and needs one manual **Allow** on the speech prompt after every fresh install or reset. The Simulator tap is manual too. A Mac's first Simulator run also raises a host microphone prompt for `SimulatorTrampoline`.

The OQ-MA-1 row in `phase2-unit-of-work.md` is updated with this answer.

## 2. Permission matrix

| Platform | Item | Requirement | Source |
|---|---|---|---|
| Android | `RECORD_AUDIO` | Declared **explicitly** in the source `AndroidManifest.xml`. Not left to a plugin's merged manifest (today it comes from a plugin and is in the merged debug and release manifests). | NFR Q1 = A |
| Android | `<queries>` for `android.speech.RecognitionService` | Added to the source manifest. Recognition started without it on `Pixel_9_Pro_API_36`, which does not prove other devices or Android versions, so it stays as defence. | NFR Q1 = A; evidence |
| Android | `INTERNET`, Bluetooth permissions from the `speech_to_text` README | **Not added** in this unit. `INTERNET` is G4 (Unit 13). On-device recognition (section 4) does not need it. | Q1 answer |
| Android | `MODIFY_AUDIO_SETTINGS`, `USE_BIOMETRIC`, `USE_FINGERPRINT` | Present in the merged release manifest from plugins; not requested by this unit and not removed. Recorded so Unit 11 reviews the release manifest and Play's data-safety form against them. | N8 |
| iOS | `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` | Already declared in `Info.plist`; no change. | N1 |
| iOS | `PERMISSION_MICROPHONE=1` | Added to the Podfile `post_install`. Without it `permission_handler_apple` reports the microphone as denied and returns "permanently denied" without a prompt (G2, reproduced A/B on the Simulator). | NFR Q2 = A; evidence |
| iOS | `PERMISSION_SPEECH_RECOGNIZER=1` and a `Permission.speech` check | **Not added.** A denied speech-recognition permission stays a generic init failure, and the failure panel offers "Open settings" for it (BR-U10-10). Revisit if the physical-device pass shows that experience is poor. | NFR Q2 = A |
| macOS and other desktop | all of the above | **No change.** No real engine is registered on desktop, and macOS has no speech usage key. | BR-U10-02 |

## 3. App identity (G5, identity only)

- **New IDs** (James Petersen, 2026-10-25): Android `applicationId` and iOS bundle ID are both `app.zipcaptions.captions`. Display name "Zip Captions" on both (Android `android:label`, iOS `CFBundleDisplayName`). v2 is a separate app from the v1 listings.
- The current IDs, `com.zipcaptions.zip_captions` (Android) and `com.zipcaptions.zipCaptions` (iOS), are scaffold values that were never uploaded. Changing them has no store impact.
- **Permanent once uploaded:** Unit 11 checks that `app.zipcaptions.captions` is free in both Play Console and App Store Connect before the first upload.
- Code Generation also moves the Android `namespace` to `app.zipcaptions.captions` and relocates `MainActivity.kt` to match. This is tidiness, not a requirement.
- Only `zip_captions` on iOS and Android changes. The macOS and other desktop bundle IDs and all of `zip_broadcast` stay.
- Because the ID changes, the first device run under the new ID must be a **fresh install**, so permissions start ungranted.

## 4. Recogniser availability, privacy and failure behaviour (G10, N9)

| ID | Requirement |
|---|---|
| NFR-U10-01 | **On-device recognition, fail closed** (Phase 1 NFR-2.1: no audio or transcript leaves the device without explicit user opt-in; the mobile Alex scenario in `stories.md:568-577`, "no audio or text data leaves the device" and "works without an internet connection"; S-22 verifies it). `PlatformSttEngine` listens with `onDevice: true` **and** an injected `OnDeviceSupportChecker` runs before **every** `listen()` (start, internal restart, resume, REL-U2.1 restart); unsupported means no `listen()` call and a refusal (Amendment 02, BR-U10-26/27). `onDevice: true` alone enforces nothing with the stock plugin (read from 7.3.0 source: iOS replies `onDeviceError` without returning; Android falls back silently; no pre-check is exposed). |
| NFR-U10-02 | **Support check per platform.** iOS: `SFSpeechRecognizer(locale:)?.supportsOnDeviceRecognition` for the session's locale, using the same locale mapping as the plugin. Android: `SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)`; below API 31 counts as unsupported. The Android check is device-level; a language with no on-device pack fails closed at listen time as a lasting error, because `createOnDeviceSpeechRecognizer` is on-device only. The plugin's `androidIntentLookup` is never set. A checker exception, `MissingPluginException` or timeout counts as unsupported. |
| NFR-U10-03 | **DECIDED (James Petersen, 2026-10-25): keep `PlatformSttEngine`, made fail closed.** The iOS speech prompt ("Speech data from this app will be sent to Apple to process your requests.") is the system's `SFSpeechRecognizer` authorisation dialog, shown for any use of Apple's Speech framework; its Apple paragraph cannot be changed and `onDevice: true` does not change it. The app therefore (a) refuses unless on-device recognition is supported, and (b) shows a one-time explainer before the first request and rewrites `NSSpeechRecognitionUsageDescription` (Amendment 02, section 6; wording provisional until the airplane-mode check passes). **Alpha 1 is internal testers only.** **Release gate (in the `aidlc-state.md` Backlog):** before any release beyond internal testers, decide whether Sherpa-ONNX (prompt-free) becomes the mobile default, and prepare the app-store privacy answers in Unit 11. **The throwaway-check runs (Android and iOS) were not on-device**: no `onDevice` was set, and the Android log shows an online recogniser started (`evidence/q3-throwaway-check.md`). |
| NFR-U10-03a | **Known upstream defects, already reported and fixed upstream but not yet released** (correction from the Opus review session's message of 2026-10-25, applied as drafted and pending James Petersen's confirmation). (1) iOS: `speech_to_text` replies with `onDeviceError` without returning, so recognition starts anyway: upstream **#673** (https://github.com/csdcorp/speech_to_text/issues/673), fixed by **PR #674**. (2) Android stop→listen race: a `listen()` within about 80–150 ms of `stop()` or `cancel()` is dropped or picks up the old session's callbacks: upstream **#678** (https://github.com/csdcorp/speech_to_text/issues/678), fixed by **PR #679**. **Verified 2026-10-25** (`gh pr view` and the pub.dev API, by this session and the Opus review session): PR #674 merged 2026-09-14T19:26:16Z and PR #679 merged 2026-09-22T15:16:00Z. **7.5.0**, the latest stable, was published 2026-09-14T19:14:48Z, twelve minutes before #674 merged; its Swift source still has no `return` after the `onDeviceError` reply (downloaded and read by the review session). **Both fixes are in the 7.6.0 betas but in no stable release.** `7.6.0-beta.1` (2026-09-14T20:26Z) and `beta.3` (2026-09-22T15:17Z) were published right after the merges; `7.6.0-beta.4` (2026-09-25) has the iOS `return` (`SpeechToTextPlugin.swift:606`) and the Android `cancel()` destroy-and-recreate (`SpeechToTextPlugin.kt:383-385`), and lists both fixes in its CHANGELOG. It also adds a plugin method `has_on_device_support` (Android: `SDK_INT >= 31` and `isOnDeviceRecognitionAvailable`, `.kt:261-273`; iOS: takes a `localeId`, `.swift:155-157, 289`), the same check as our `OnDeviceSupportChecker`, and changes behaviour (a new iOS option `preserveExistingAudioSession` defaults to true, and it needs `speech_to_text_platform_interface` 2.5.0). **Nothing needs filing. Stay on 7.3.0 for Alpha 1** (a pre-release stays off the privacy-critical path, SECURITY-10, and the audio-session default change is avoided). Revisit when a **stable** release includes both fixes; an upgrade re-verifies R5 (the code classes and status behaviour Amendment 01 and 02 are pinned to), and the checker's upgrade path is in `tech-stack-decisions.md`. Until then the checker makes the iOS defect unreachable in normal use, and every `ListenFailedException` is cancelled at once (BR-U10-31). The plugin's Dart layer also drops the platform error code in `ListenFailedException`. |
| NFR-U10-03b | **`onDeviceCheckTimeout = 2 s`** (named constant, starting value, confirmed at the device pass). The check is a local boolean query with no permission prompt in front of it, so a short bound is safe; a timeout counts as unsupported. |
| NFR-U10-04 | **Language packs.** An on-device model may be missing: the `Pixel_9_Pro_API_36` emulator has no `en-US` pack (`error 13`), and the iOS Simulator may not support on-device recognition. A missing pack is reported as `onDeviceModelMissing` (BR-U10-18) and shown in the failure panel. Emulator QA of the on-device path needs the pack installed, or shows the failure path. Only a physical device proves captioning. |
| NFR-U10-05 | **Continuous listening** (Amendment 01): the engine restarts on the plugin's `done`, classifies errors by code, and caps repeated failures. Starting values, as **named constants**, to be confirmed on a device: `restartCap = 3` (increment-then-compare, so the third counted failure reports), `immediateFailureWindow = 2 s`, `restartDelay = 250 ms`. `restartDelay` is checked on a device because Android returns `error_busy` if a recogniser restarts too soon, and because of upstream **#678**: an Android `listen()` within about 80–150 ms of `stop()` or `cancel()` is dropped or picks up the old session's callbacks (fixed by PR #679, not yet released; NFR-U10-03a). These may change at the device pass without a redesign. |
| NFR-U10-06 | **No timeout on `engine.initialize()`** in this unit. On iOS `SpeechToText.initialize()` shows the speech-permission prompt, so a fixed timeout would fail a user who is still reading it. Any later timeout must not count time spent on a permission prompt. A hang found at the device pass is recorded and handled then. (NFR Q6 = A) |
| NFR-U10-07 | **A failed start is visible.** No start failure may leave an empty screen with a spinner (F2). On both platforms the failure panel replaces the caption area and the controls bar is hidden. Reproduced on both platforms as the defect to fix: Android and iOS each showed an empty Caption screen with an endless spinner. |
| NFR-U10-08 | **Mid-session failure is explained.** A session that stops because of an engine error shows a one-time notice (BR-U10-23). A refused `resume()` also stops the session with that notice instead of leaving the user in `Paused` (BR-U10-36). |
| NFR-U10-08a | **A session stops exactly once.** Finalising the transcript, the `StoppedState` event and the wake-lock release happen once per session whichever trigger fires (engine error, recovery failure, a refusal during the REL-U2.1 restart, or the user's `stop()`) (BR-U10-35, TP-2b). |
| NFR-U10-08b | **First error wins during `start()` and `resume()`** (BR-U10-28, BR-U10-36), so a specific error is never replaced by a generic one. |
| NFR-U10-09 | **A crash in the platform audio stack cannot be caught by the app.** An `SIGABRT` in `AVAudioEngine` was seen once on the Simulator with the host microphone prompt open (`evidence/q3-throwaway-check.md`). It did not recur. The device pass watches for it; if it reproduces on a physical iPhone it becomes a reliability defect for a later stage. |

## 5. Performance and usability

- **Latency (Phase 1 NFR-1.1, under 1 s):** a physical-device gate only. Emulator runs record functional behaviour (prompts, captions appear, failure panel) and **no latency number**. (NFR Q8 = A)
- **Screen kept on (G9):** verified on the Android emulator by checking the window's keep-screen-on flag with `adb shell dumpsys window` during captioning and after stopping. The Simulator has nothing to read (`WakeLockService` and `WakelockPlusService` emit no log records), so iOS relies on the physical-device screen-timeout test. (NFR Q9 = C)
- **Failure panel usability:** text readable at the default and large font sizes; each action is a labelled button with a minimum 48 dp tap target; strings come from the `.arb` source and are localised. No text conveys state by colour alone.
- **The on-device refusal says why and makes no unprovable claim.** Proposed text: "This device or language doesn't support on-device speech recognition, so Zip Captions didn't start." It does not say that audio was not sent anywhere, because the iOS plugin's bug window could make that untrue. "Open settings" is not offered for it.
- **The iOS explainer** is shown once before the first permission request, with "Continue" and "Not now" (Amendment 02, section 6). It claims only what Zip Captions controls.
- **Retry:** "Try again" re-runs `start()` and clears the earlier failure first.

## 6. Security (Security Baseline, enabled as blocking)

| Rule | Status | Note |
|---|---|---|
| SECURITY-03 | Compliant by design | No transcript text in logs on the new path; `SttEngineError` has no free-text field; the `recording_state_notifier.dart:102` line changes to `e.runtimeType`. Test: TP-6, TP-12 at `Logger.root.level = Level.ALL`. |
| SECURITY-09 | Compliant by design | The debug fake is gated out of release by compile-time constants and tested with `allowDevEngines: false` (TP-3, TP-10). Unsupported on-device recognition means refuse, never the default recogniser; `androidIntentLookup` is forbidden; no coupling to the plugin's error text. The release build still signs with the debug key until Unit 11; **that build must not be distributed.** |
| SECURITY-11 | Compliant by design | Misuse considered: switching to a locale with no on-device model is refused, not silently sent to a server (Amendment 02). |
| SECURITY-10 | Compliant, one action | No new package. `speech_to_text` 7.3.0 and `permission_handler` stay at the locked versions. `zip_captions` does not declare `speech_to_text`, which production registration needs (`depend_on_referenced_packages`). **Recommendation (Opus review session, correction 3; NFR Design confirms):** prefer a factory in `zip_core` that builds `PlatformSttEngine` with its own `SpeechToText()`, over declaring `speech_to_text` in `zip_captions`, so the plugin (whose code classes and status behaviour the design is pinned to) is declared in one package. No dependency is added without that being recorded in the Code Generation plan. |
| SECURITY-12 | Compliant by design | Signing secrets: the keystore, `key.properties` and any `.jks` are never in git (already ignored: `android/.gitignore` has `key.properties` and `**/*.jks`, the root `.gitignore` has `*.keystore`). iOS signing uses an Apple Developer team configured outside the repo. A CI build gets signing material only from CI secrets. **No Gradle or Xcode signing change in this unit**; Unit 11 implements it. (NFR Q5 = A) |
| SECURITY-15 | Compliant by design | Every start failure fails closed to `IdleState` with no wake lock (BR-U10-08, BR-U10-25); restarts are capped; listeners and timers are released in `dispose()`. |
| SECURITY-01, 02, 04 to 08, 13, 14 | N/A | No storage, network intermediary, web endpoint, authorisation surface, rate-limited API, deserialisation or alerting is added. |

No blocking security findings.

## 7. Maintainability and test obligations

- **PBT framework (PBT-09):** the repo's Dart-3 shim, copied to `zip_captions/test/helpers/pbt.dart` for the `zip_captions` properties (TP-3, 4, 5, 8, 10), because one package's tests cannot import another's `test/` folder; `zip_broadcast` already keeps an identical copy. **The shim runs fixed seeds 0 to 99, has no shrinking and prints no seed.** This is the deviation earlier units accepted, not "seed logged, shrinking on". A failing run is reproduced from the fixed seed plus the command list in the failure message (TP-11). (NFR Q10 = C)
- **Properties:** TP-1 to TP-14 as defined in `functional-design/business-logic-model.md` and Amendment 01, and TP-15 to TP-20, TP-2b and the extended TP-8 and TP-12 in Amendment 02 (TP-10 guards that the real engine is registered; TP-15 that every `listen()` follows a true check). TP-1, TP-2, TP-16 and TP-20 are example-based per row; TP-11 and TP-15 are stateful models with fake time.
- **Spelling (decided 2026-10-25):** **British English for all user-facing strings**, matching `zip_broadcast/l10n/arb/app_en.arb` ("Behaviour", "Colour"). It covers the `.arb` text and `NSSpeechRecognitionUsageDescription`. Code Generation applies it. `Info.plist` text is English-only until per-locale `InfoPlist.strings` exist (a recorded limitation).
- **Existing tests:** the `PlatformSttEngine` tests mock `SpeechToText`; they change with the new listener assignment and `listen` options. Code Generation names each changed test.
- **Docs:** `ARCHITECTURE`/ADR-005 get an addendum for the `SttErrorSource` capability at Documentation Refinement; `docs/` is not edited in this unit.
- **Lint:** `zip_core` uses `very_good_analysis` (`avoid_setters_without_getters`), hence `setErrorListener` as a method.

## 8. Verification obligations carried to Code Generation and the device pass

1. Emulator QA pass (recorded, through the MCP where it can attach): Android grant and deny paths, the iOS two-prompt flow after a reset, the failure panel on each failure cause, the Android `dumpsys window` flag.
2. Repeat the Q3 reproduction after the committed change, with the real engine registered by committed code (unit-of-work "Verification" step 2).
3. Physical iPhone and Android phone: Phase 1 exit criterion 1, NFR-1.1 latency, screen kept on, on-device availability (NFR-U10-02, 04), the restart behaviour and `restartDelay`, `onDeviceCheckTimeout`, and the `SIGABRT` watch (NFR-U10-09), plus these privacy checks (Amendment 02, section 11):
   - **Airplane mode:** captioning works on a physical iPhone and a physical Android phone ("works without an internet connection", the Alex scenario).
   - **Unsupported device or locale:** the app refuses with the failure panel and does not caption; the iOS check is exercised with a locale that has no on-device model.
   - **Android logs** show the on-device recogniser, not `Online recognizer`.
   - **No-pack language (R10):** switch Android to a language with no on-device pack and expect a refusal or the lasting error, never online recognition.
   - **The explainer wording** is confirmed true by the above before the provisional text is accepted.
   - **Amendment 01 restart observations (added in the Opus review session's correction 2; for James Petersen to answer at the device pass, "acceptable for Alpha 1?"):**
     - (a) Does Android play a chime on each internal restart, and how often during speech and during silence? Acceptable for Alpha 1? yes / no (to be answered).
     - (b) Are words lost in the gap between sessions? Acceptable for Alpha 1? yes / no (to be answered).
     A "no" goes back to design; it is not treated as a tuning issue.
4. Emulator and Simulator results from the throwaway check are **not** on-device evidence (no `onDevice` was set); a repeat run with the committed change, with the checker true, and with it forced false, is recorded in the emulator QA pass (obligation 1).

## 9. Compliance summary for this stage

| Check | Result |
|---|---|
| Security Baseline | No blocking findings (section 6) |
| PBT-09 (framework) | Compliant: shim selected and documented, deviation recorded (section 7) |
| PBT-01 to 08, 10 | Carried by the Functional Design property list and Code Generation |
| OQ-MA-1 | Answered with evidence (section 1) |
