# NFR Requirements Plan: Unit 10, Mobile Platform Readiness (S-22, Alpha 1)

**Stage**: Construction, NFR Requirements (Phase 2). Functional Design approved 2026-10-25.
**Input**: `construction/mobile-platform-readiness/functional-design/handoff-summary.md`
**Gate**: OQ-MA-1 must be answered with evidence and recorded here and in `audit.md` before this stage is approved. Q3 below is how it gets answered.
**Constraints carried forward**: `SttEngine`, `SttResult`, `RecordingState`, `RecordingError` and the `AudioDeviceService` interface do not change. Nothing is registered locally, even temporarily, without James Petersen's approval. Physical-device results (latency under 1 s, screen on, recogniser availability) stay a later gate and are not claimed from emulators.

## Plan checklist

- [x] Step 1. Analyse the Functional Design handoff and the platform configuration
- [x] Step 2. Create this plan
- [x] Step 3. Generate questions (below)
- [x] Step 4a. Answers recorded 2026-10-25 (Q4 changed to new IDs the same day)
- [x] **Step 4b. Functional Design amendments (reopened, narrow): Amendment 01 (N9) and Amendment 02 (privacy), both Opus-reviewed and approved 2026-10-25.**
- [x] Step 4c. Q4 resolved: new IDs `app.zipcaptions.captions` (Android and iOS)
- [ ] Step 4d. Ask James Petersen before running the Q3 throwaway check (after Amendment 01 is re-approved)
- [x] Step 5. Answer OQ-MA-1 with evidence (needs Q3 approved), and record the merged release-manifest check (done 2026-10-25; `evidence/q3-throwaway-check.md`)
- [x] Step 6. Generate `nfr-requirements.md` (permission matrix, reliability, usability, security, maintainability, Security Baseline and PBT compliance) and `tech-stack-decisions.md` (PBT-09 framework, plugin versions) in `aidlc-docs/construction/mobile-platform-readiness/nfr-requirements/`
- [x] Step 7. Write `nfr-requirements/handoff-summary.md`
- [ ] Step 8. Present the completion message and stop at the approval gate. NFR Design does not start.
- [ ] Step 9. After approval only: log it in `audit.md`, tick NFR Requirements in `aidlc-state.md`

## Facts from the configuration read (2026-10-25, no device run)

| # | Fact | Evidence |
|---|---|---|
| N1 | iOS `Info.plist` already declares `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`. | `ios/Runner/Info.plist:50-53` |
| N2 | The iOS Podfile `post_install` sets no `PERMISSION_MICROPHONE=1` and no `PERMISSION_SPEECH_RECOGNIZER=1`. `permission_handler_apple` defaults both to `0`. `SttSessionManager` gates on `Permission.microphone`, so this is the cause behind G2. Not yet shown on a device. | `ios/Podfile:39-43`; `permission_handler_apple` `PermissionHandlerEnums.h` |
| N3 | The source Android manifest declares no permission. `speech_to_text` 7.3.0 ships an empty manifest, so the `RECORD_AUDIO` seen in the merged debug manifest comes from a different plugin (probably `record_android`; to be confirmed against the merged manifests). No `RecognitionService` `<queries>` entry exists. | `AndroidManifest.xml`; plugin manifest in the pub cache; evidence file |
| N4 | Release signing still uses the debug keys (`build.gradle.kts` TODO). `android/.gitignore` already ignores `key.properties` and `**/*.jks`; the root `.gitignore` ignores `*.keystore`. The iOS project has no `DEVELOPMENT_TEAM`. | `build.gradle.kts:34-37`; the two `.gitignore` files |
| N5 | Android `applicationId` and namespace are `com.zipcaptions.zip_captions`, with `android:label="zip_captions"`. iOS bundle ID is `com.zipcaptions.zipCaptions` (deployment target 13.0). The v1 store listings' IDs are not in the repo. | `build.gradle.kts`; `project.pbxproj` |
| N6 | `PlatformSttEngine` reports `requiresNetwork = false`, but `speech_to_text` uses the platform's default recogniser, which on some Android devices and on iOS can send audio to the vendor's servers. | `platform_stt_engine.dart`; plugin behaviour |
| N7 | `SttSessionManager.initialize()` has no timeout around `engine.initialize()`. A recogniser service that never answers would leave the failure panel unreachable and the controls bar spinner running. | `stt_session_manager.dart:65-77` |
| N8 | **Merged release manifest checked 2026-10-25** (`flutter build apk --release --target-platform android-arm64` succeeded, 140.8 MB, signed with the debug keys; `build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`). It declares `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `USE_BIOMETRIC` and `USE_FINGERPRINT` (all from plugins). It has **no** `INTERNET` (G4, Unit 13) and **no** `RecognitionService` `<queries>` entry (only `PROCESS_TEXT`). So the permission half of G3 does not hold in release either, and the `<queries>` half does. The supplying plugin for `RECORD_AUDIO` is still not named. No tracked file changed; `git status` shows only the docs already listed. | build output, this session |
| **N9** | **Blocking: the platform engine cannot caption continuously.** `PlatformSttEngine.startListening()` calls `_stt.listen()` once, and `initialize()` registers no `onStatus` or `onError` listener. The plugin targets "commands and short phrases, not continuous spoken conversion" (`speech_to_text` 7.3.0 README lines 9-10, 347-352). Android ends a session when the speaker pauses, and iOS stops the task after about one minute (README line 501). `SttEngine` has no error channel, so `SttSessionManager`'s REL-U2.1 restart never fires for a real engine. Result: the first utterance is captioned, then captions silently stop while the state stays Recording and the screen stays on. S-22 AC3 fails on every device. Checked against the locked source on 2026-10-25. | `platform_stt_engine.dart:49-123`; plugin README and `speech_to_text.dart` |

**Decision (James Petersen, 2026-10-25):** reopen Functional Design narrowly for N9 (internal restart, an additive error channel on `SttEngine` which is approved as a stable-contract change, and `onDevice: true`). See `functional-design/amendment-01-continuous-listening.md`.

---

## Questions

Please fill in the letter after each `[Answer]:` tag. My recommendation is marked on each question. Opus is recommended for reviewing the answers to Questions 1, 2 and 5 (permissions and signing secrets).

## Question 1
Android permissions and package visibility. How are `RECORD_AUDIO` and the speech-recogniser query declared?

A) Declare both explicitly in the source `AndroidManifest.xml`: `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` and a `<queries>` entry for `android.speech.RecognitionService`. Do not rely on a plugin's merged manifest for the permission. (Recommended)
B) Add only the `<queries>` entry and keep relying on the plugin-supplied `RECORD_AUDIO`
C) Other (please describe after [Answer]: tag below)

[Answer]: A. Do not add `INTERNET` or the Bluetooth permissions from the `speech_to_text` README. `INTERNET` is G4 (Unit 13).

## Question 2
iOS permission macros (the cause behind G2, N2). What does the Podfile `post_install` set?

A) `PERMISSION_MICROPHONE=1` only. A denied iOS speech-recognition permission stays a generic init failure with "Open settings", as designed in Functional Design (BR-U10-10). (Recommended)
B) `PERMISSION_MICROPHONE=1` and `PERMISSION_SPEECH_RECOGNIZER=1`, plus a `Permission.speech` check in `SttSessionManager` so the app can tell the two denials apart. This changes `zip_core`'s session manager and widens Unit 10 again.
C) Other (please describe after [Answer]: tag below)

[Answer]: A. Confirmed from `permission_handler_apple` 9.3.0: with the macro off, its fallback reports "denied", and a request returns "permanently denied" without showing a prompt. That is G2.

## Question 3 (answers OQ-MA-1)
OQ-MA-1 cannot be answered without a real engine, and the unit-of-work text allows a throwaway local registration "that is reverted, never committed, and needs James Petersen's approval first". Do you approve it?

The change: edit `packages/zip_captions/lib/src/bootstrap.dart` locally to register `PlatformSttEngine(stt: SpeechToText(), deviceService: <a small private stub class in the same file>)` on mobile, build to the iPhone 17 Simulator and `Pixel_9_Pro_API_36`, and run: fresh install, Start Captioning with permissions not granted (G2, G3 reproduction), then `xcrun simctl privacy <udid> reset all` and a second launch to see whether the iOS prompts return. The edit is reverted with `git checkout -- packages/zip_captions/lib/src/bootstrap.dart` before any other work, the diff is saved under this unit's `evidence/`, and `git status` is recorded before and after. No other tracked file is touched. This is not delegated to Qwen. The Simulator tap is manual (the MCP has no tap tool and this host lacks Accessibility permission).

A) Approved, as described (Recommended)
B) Approved, but only on the iPhone 17 Simulator (OQ-MA-1); the Android reproduction waits for Code Generation
C) Not approved. OQ-MA-1 stays OPEN and this stage cannot be approved until you choose another way to answer it.
D) Other (please describe after [Answer]: tag below)

[Answer]: D. Approved as described, with two changes. (1) The throwaway change also sets `PERMISSION_MICROPHONE=1` in the Podfile `post_install`, followed by `pod install`. Without it, `SttSessionManager` stops at the microphone check, so `SpeechToText.initialize()` never runs, the speech prompt never appears, and OQ-MA-1 cannot be observed. The iOS run is two passes: first without the macro (reproduce G2), then with it (fresh install, both prompts, `simctl privacy … reset all`, relaunch). (2) `Podfile.lock` already has an uncommitted change, so it is not reverted with `git checkout`: copy it to the scratchpad before `pod install` and copy it back afterwards. Revert `bootstrap.dart` and the Podfile with `git checkout`, save both diffs as evidence, and record `git status` before and after.
**Timing (James Petersen, 2026-10-25):** the throwaway check runs only after the Functional Design amendment for N9 is re-approved, because the check needs the real engine to behave as designed.

## Question 4
App identity (G5, identity only; signing is Unit 11). What are the Android `applicationId` / iOS bundle ID and the display name?

A) Keep the current IDs (`com.zipcaptions.zip_captions`, `com.zipcaptions.zipCaptions`) and set the display name to "Zip Captions" on both platforms. The v1 listings are treated as separate apps.
B) Reuse the v1 store listings' IDs so v2 ships as an update to them. I will give the IDs after the [Answer]: tag. The display name is "Zip Captions".
C) Choose new IDs (please give them after the [Answer]: tag). The display name is "Zip Captions".
D) Other (please describe after [Answer]: tag below)

[Answer]: C. New IDs. v2 is a separate app from the v1 listings. (Changed by James Petersen, 2026-10-25; this replaces the earlier answer B, "reuse the v1 store IDs", which had left both IDs as `<FILL IN>`.)
- Android `applicationId`: `app.zipcaptions.captions`
- iOS bundle ID: `app.zipcaptions.captions`
- Display name: "Zip Captions" on both platforms (Android `android:label`, iOS `CFBundleDisplayName`)

To record in the NFR artifacts:
- The IDs become permanent once uploaded to Play Console or App Store Connect, so Unit 11 checks that the ID is free in both consoles before the first upload.
- The current IDs are scaffold values that were never uploaded: `com.zipcaptions.zip_captions` on Android and `com.zipcaptions.zipCaptions` on iOS. Changing them has no store impact.
- Code Generation also moves the Android namespace to `app.zipcaptions.captions` and relocates `MainActivity.kt` to match. This keeps the namespace in step with the `applicationId`; it is not required.
- Only `zip_captions` on iOS and Android changes. The macOS and other desktop bundle IDs, and all of `zip_broadcast`, stay as they are.
- Order: the Q3 throwaway check (OQ-MA-1) runs **before** the ID change, so it installs under the current IDs, and James Petersen is asked before it runs. If the ID changes before any device run, re-install fresh so permissions start ungranted.

## Question 5
Signing secrets under the Security Baseline (SECURITY-12: no secrets in source). What does Unit 10 do about them, given that Unit 11 does the signing itself?

A) Policy only. The NFR artifact records that the keystore, `key.properties` and any `.jks` are never in git (already ignored, N4), that iOS signing uses an Apple Developer team configured outside the repo, and that CI secrets are the only source for a CI build. No Gradle or Xcode signing change in Unit 10. (Recommended)
B) Policy plus the Gradle `key.properties` loader now, falling back to the debug key when the file is absent, so Unit 11 only adds the secret
C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 6 (N7)
Should `engine.initialize()` be bounded by a timeout?

A) No timeout in this unit. There is no evidence of a hang yet; the device pass records it if one appears. (Recommended)
B) Add a 10-second timeout in `SttSessionManager.initialize()` that maps to `engineInitFailed`. This changes `zip_core` again and needs a PBT/example test.
C) Other (please describe after [Answer]: tag below)

[Answer]: A. Reason to record: on iOS, `SpeechToText.initialize()` shows the speech permission prompt, so a fixed timeout would fail a user who is still reading it. Any later timeout must not count time spent on the prompt.

## Question 7 (N6)
Recogniser availability and privacy. The platform recogniser may send audio to the OS vendor's servers on some devices. What does Alpha 1 require?

A) Accept the platform default recogniser. The NFR artifact records that audio may leave the device on some devices, and that testers are told so. No on-device-only requirement for Alpha 1 (the parked on-device multilingual unit covers that). (Recommended)
B) Require on-device recognition only. The engine would need an `onDevice` option, which is a change to `PlatformSttEngine` and may make some devices fail to start.
C) Other (please describe after [Answer]: tag below)

[Answer]: C, on-device recognition. Phase 1 NFR-2.1 ("No audio or transcript content leaves the device without explicit user opt-in") and the mobile Alex scenario (`stories.md:570-577`: "no audio or text data leaves the device", "works without an internet connection") require it, and S-22 verifies that scenario. `PlatformSttEngine` passes `onDevice: true`. In the locked 7.3.0: **iOS** sets `requiresOnDeviceRecognition`, so it is enforced, and a locale with no on-device model fails instead of falling back. **Android** on API 31 and later uses `createOnDeviceSpeechRecognizer` when one is available, and otherwise silently falls back to the default recogniser with only `EXTRA_PREFER_OFFLINE`. Record that fallback as a known gap that the device pass checks. **Risk:** the iOS Simulator may not support on-device recognition. If not, Simulator runs show the failure path, and only physical devices prove captioning.

## Question 8
Latency and emulator evidence (Phase 1 NFR-1.1, under 1 s). How are emulator results treated?

A) Emulator runs record functional behaviour only (prompts, captions appear, failure panel). Latency has no numeric gate on emulators; the under-1 s check is made on a physical iPhone and Android phone and is a later gate. (Recommended)
B) Emulator runs also record an indicative latency number, labelled non-evidential
C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 9 (G9)
How is "screen stays on while captioning" verified on a virtual device before the physical gate?

A) On the Android emulator, check the window's keep-screen-on flag with `adb shell dumpsys window` during captioning and after stopping; on the Simulator, log the wake-lock acquire and release already emitted by `WakeLockService`. The physical-device screen-timeout test remains the real gate. (Recommended)
B) Physical device only
C) Other (please describe after [Answer]: tag below)

[Answer]: C. Use the Android `dumpsys window` check only. `WakeLockService` and `WakelockPlusService` emit no log records, so the Simulator half of A has nothing to read. The Simulator relies on the physical-device gate.

## Question 10
Property-based testing framework (PBT-09) for the properties TP-1 to TP-10.

A) Reuse the repo's Dart-3-compatible shim (`test/helpers/pbt.dart`) as in earlier units, with the seed logged on failure and shrinking left on. (Recommended)
B) Add a different PBT dependency
C) Other (please describe after [Answer]: tag below)

[Answer]: C. Reuse the shim, but copy it into `zip_captions/test/helpers/pbt.dart`. TP-3, 4, 5, 8 and 10 test `zip_captions` code, and one package's tests cannot import another package's `test/` folder. `zip_broadcast` already keeps an identical copy. Correction to the option text: the shim runs fixed seeds 0–99, has no shrinking, and does not print the seed. That is the deviation earlier units accepted, not "seed logged, shrinking on".

---

## What this stage will produce after the answers

- `nfr-requirements.md`: permission matrix per platform (Android `RECORD_AUDIO`, `RecognitionService` query; iOS microphone and speech macros and usage strings), recogniser availability and failure behaviour per platform, reliability and usability requirements for the failure panel, security (signing-secret handling, log content, release fake exclusion), maintainability and test obligations, the OQ-MA-1 answer with evidence, the merged release-manifest finding, and the Security Baseline and PBT compliance tables
- `tech-stack-decisions.md`: locked plugin versions, PBT framework, app identity, nothing new unless an answer adds it
- `handoff-summary.md` for NFR Design
