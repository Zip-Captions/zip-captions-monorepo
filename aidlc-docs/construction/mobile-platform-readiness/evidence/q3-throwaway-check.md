# Unit 10 evidence: Q3 throwaway real-engine check (OQ-MA-1, G2, G3, N9)

**Run**: 2026-10-25, branch `feature/mobile-platform-readiness` at `84e32b7`, under the **current** IDs (`com.zipcaptions.zip_captions`, `com.zipcaptions.zipCaptions`).
**Approval**: James Petersen, NFR plan Q3 = D, and "Go ahead under the current IDs" (2026-10-25).
**Throwaway change** (never committed, reverted with `git checkout`; diffs saved beside this file): `packages/zip_captions/lib/src/bootstrap.dart` registers `PlatformSttEngine(stt: SpeechToText(), deviceService: <private stub>)` on every platform in place of the debug fake. The iOS second pass also adds `PERMISSION_MICROPHONE=1` to the Podfile `post_install`.
**Limits**: virtual devices only. Nothing here proves physical-device behaviour (latency, recogniser availability on real hardware, wake lock). The emulator's microphone is silent, so no caption text was produced.

## Android: `Pixel_9_Pro_API_36` (Android 16, API 36, `google_apis_playstore`)

Fresh install by `flutter run`, then `adb` taps. `RECORD_AUDIO: granted=false` before the first tap (`dumpsys package`).

| Step | Observation | Evidence |
|---|---|---|
| Home before tap | Home screen, no permission granted | `android-03-before-tap-real-engine.png` |
| Tap Start Captioning (real engine, nothing granted) | **The system microphone prompt appears** ("Allow zip_captions to record audio?"), from `GrantPermissionsActivity`. The permission half of G3 is therefore **not** reproduced: `RECORD_AUDIO` is in the merged debug and release manifests, supplied by a plugin. | `android-04-after-tap-real-engine.png` |
| Tap "While using the app" | `RECORD_AUDIO: granted=true`. The Recording screen opens with Pause and Stop controls. `logcat` shows the Google recogniser service starting for `com.zipcaptions.zip_captions` (`en-US`), both an online and an offline recogniser started, and `onMicrophoneOpened`. | `android-05-after-grant-real-engine.png` |
| Recognition without a `RecognitionService` `<queries>` entry | Recognition **started** with the manifest's only `<queries>` entry being `PROCESS_TEXT`. So the missing `<queries>` entry did not stop recognition on this emulator and API level. This is not shown for other Android versions, devices or recogniser services; the explicit entry (NFR Q1 = A) stays as defence. | logcat excerpt below |
| About 5 seconds of silence | `RecognitionService#onMicrophoneCloseRequested`, then `Speech recognition error type NO_SPEECH_DETECTED`. **No further recogniser activity follows**, while the app stays on the Recording screen. **This reproduces N9 on a real run**: the platform session ends at the first silence and nothing restarts it. | logcat excerpt; `android-06-after-silence.png` |
| On-device language pack | `SodaSpeechRecognizer: Failed to get language pack of required locale: error 13` (the offline pack for `en-US` is not installed on this emulator). With `onDevice: true` (NFR Q7 = C) the engine would meet this as a language-unavailable error on this emulator. Relevant to BR-U10-18 and the device pass. | logcat excerpt |
| Deny path (revoke, relaunch, tap Start, "Don't allow") | `granted=false` with `USER_FIXED`. The Caption screen is **empty with a spinner that never stops** and no message. This reproduces F2 and the spinner finding on a real run. | `android-07-denied-once-current-ui.png` |

Logcat excerpt (filtered, no transcript content exists; the microphone was silent):

```
13:00:15 RecognitionService#logStartListening: callingApp: com.zipcaptions.zip_captions, locale: en-US
13:00:15 NetworkSpeechRecognizer: Online recognizer - start listening
13:00:15 SodaSpeechRecognizer: Offline recognizer - start listening
13:00:15 RecognitionService#onMicrophoneOpened
13:00:15 SodaSpeechRecognizer: Failed to get language pack of required locale: error 13
13:00:20 RecognitionService#onMicrophoneCloseRequested
13:00:20 Speech recognition error type NO_SPEECH_DETECTED with error code -1
```

The `flutter-agent-lens` `console_logs` buffer was empty for this run (the MCP attached after the app had started, and no new records arrived), so the app-side log lines were not captured; the evidence above is from `adb`, `dumpsys` and `logcat`.

## iOS: `iPhone 17` Simulator (iOS 26.0)

### Pass 1: without `PERMISSION_MICROPHONE=1` (reproduces G2)

`xcrun simctl privacy <udid> reset all com.zipcaptions.zipCaptions` (exit 0), app relaunched, then a manual tap on Start Captioning by James Petersen (the MCP has no tap tool and this host has no Accessibility permission).

| Step | Observation | Evidence |
|---|---|---|
| Home before tap | Home screen | `ios-03-pass1-before-tap.png` |
| Tap Start Captioning (real engine registered, macro off) | **No microphone prompt and no speech prompt.** The Caption screen is empty with a spinner that never stops. This reproduces G2 on a real run: with the macro off, `permission_handler_apple` reports the microphone as denied and a request returns "permanently denied" without showing a prompt, so `SttSessionManager` stops at the permission check and `SpeechToText.initialize()` never runs. The empty screen and endless spinner are also F2. | `ios-04-pass1-after-tap-no-macro.png` |

### Pass 2: with `PERMISSION_MICROPHONE=1`

Podfile `post_install` edited (throwaway), `pod install` run (needed `LANG=en_US.UTF-8`; it changed only the Podfile checksum line of `Podfile.lock`), app uninstalled, fresh install by `flutter run`. Home before the tap: `ios-05-pass2-fresh-install-before-tap.png`.

| Step | Observation | Evidence |
|---|---|---|
| Tap Start Captioning (macro on, fresh install) | **The microphone prompt appears**: "Zip Captions" would like to access the Microphone. The Caption screen is behind it with the spinner. This confirms the missing macro was the cause of G2. | `ios-06-pass2-first-prompt.png` |
| Tap Allow | **The speech-recognition prompt appears**: "Zip Captions" would like to access Speech Recognition, with the system text "Speech data from this app will be sent to Apple to process your requests. This will also help Apple improve its speech recognition technology." plus the app's `NSSpeechRecognitionUsageDescription`. **Both iOS prompts appear, in that order, on a fresh install.** | `ios-07-pass2-speech-prompt.png` |
| Tap Allow on the speech prompt | A **macOS host** prompt appeared: "SimulatorTrampoline.xpc would like to access the microphone" (the host asking whether the Simulator may use the Mac's microphone). Then **the app crashed** (`SIGABRT`, report `Runner-2026-10-25-130728.ips`; `flutter run` printed "Lost connection to device") and the Simulator showed the iOS home screen. | `ios-08-pass2-after-both-prompts.png` |

**Crash analysis** (from the report; the cause is a hypothesis, not proven):
- Faulting thread stack, top to bottom: `abort` ← `_ReportRPCTimeout` ← `AudioUnitInitialize` / `AURemoteIO::Initialize` ← `-[AVAudioEngine inputNode]` ← `SpeechToTextPlugin.initAudioEngine` ← `SpeechToTextPlugin.listenForSpeech(... onDevice: ...)` ← `SpeechToTextPlugin.handle`.
- So the abort is a timeout of the Simulator's audio RPC inside the plugin's audio engine setup, after both consents were given. The host microphone prompt was on screen at the same time and unanswered, which is the likely reason the RPC timed out. Not yet tested with the host prompt answered.
- It is a Simulator and host artefact until shown otherwise. It does not show that the same abort would happen on a physical iPhone, and it must not be counted as a physical-device result either way.
- It is a **crash**, not a handled failure: nothing in the app can catch an `SIGABRT` from the audio stack. If it reproduces with the host prompt answered, that belongs in the NFR reliability requirements.

### Host prompt, then the reset run (answers the second half of OQ-MA-1)

James Petersen answered the macOS host prompt "SimulatorTrampoline.xpc would like to access the microphone" with **Don't Allow**, and dismissed the macOS "Runner quit unexpectedly" dialog (the crash reporter for the crash above, not a second crash). Then: `xcrun simctl privacy <udid> reset all com.zipcaptions.zipCaptions` (exit 0), app relaunched with `simctl launch` (`ios-09-after-reset-all-relaunch.png`), and a manual tap on Start Captioning.

| Step | Observation | Evidence |
|---|---|---|
| Tap Start Captioning after `reset all` | **The microphone prompt returns.** | `ios-10-after-reset-all-first-prompt.png` |
| Tap Allow | **The speech-recognition prompt returns** (same system text as before). | `ios-11-after-reset-all-speech-prompt.png` |
| Tap Allow, with the host microphone set to Don't Allow | **No crash.** No new crash report appeared and the app process was still running. The app is on the Recording screen with Pause and Stop and no caption text (no audio reached it). This is consistent with, but does not prove, the host prompt having blocked the first run's audio setup. The run used the unmodified `PlatformSttEngine` (no restart loop, no `onDevice`). | `ios-12-after-second-allow.png` |

### OQ-MA-1 answer

- `xcrun simctl privacy help` lists no speech-recognition service (`all, calendar, contacts-limited, contacts, location, location-always, photos-add, photos, media-library, microphone, motion, reminders, siri`), so speech-recognition consent **cannot be pre-granted** with `simctl privacy grant`. Microphone can be.
- `xcrun simctl privacy <udid> reset all <bundle>` **does bring both prompts back** on the next Start Captioning: the microphone prompt first, then the speech-recognition prompt (observed on the iPhone 17 Simulator, iOS 26.0, with the macro on, `Podfile` throwaway change, real `PlatformSttEngine`).
- So iOS QA is **scriptable for the microphone and not for speech recognition**: every fresh install or reset needs one manual **Allow** on the speech prompt. The Simulator tap is also manual (the MCP has no tap tool, and this host has no Accessibility permission). The first run on a Mac also raises a host microphone prompt for the Simulator.

## What changed and what was reverted

- Throwaway edits: `bootstrap.dart` (`q3-throwaway-bootstrap.diff`, 52 lines) and the Podfile `post_install` macro (`q3-throwaway-podfile.diff`, 15 lines). Both were reverted with `git checkout -- <path>`.
- `Podfile.lock` carried the pre-existing uncommitted change. It was copied to the scratchpad before `pod install` and **restored from that copy** (not `git checkout`); `cmp` shows it identical to the saved copy, and the Podfile matches the saved original.
- `git status --short` before and after the run are identical (9 lines, the docs diff and `Podfile.lock` already modified, plus the untracked unit folders). Saved copies are in the session scratchpad; the content is:

```
 M aidlc-docs/aidlc-state.md
 M aidlc-docs/audit.md
 M aidlc-docs/inception/application-design/phase2-unit-of-work.md
 M aidlc-docs/inception/user-stories/phase2-stories.md
 M opencode.json
 M packages/zip_captions/ios/Podfile.lock
?? aidlc-docs/construction/mobile-platform-readiness/
?? aidlc-docs/construction/plans/mobile-platform-readiness-functional-design-plan.md
?? aidlc-docs/construction/plans/mobile-platform-readiness-nfr-requirements-plan.md
```

## Privacy correction (added 2026-10-25 after James Petersen's question)

**Every run above used the current `PlatformSttEngine`, which never sets `onDevice`** (checked: no `onDevice` or `listenOptions` in `platform_stt_engine.dart`). So these runs used the platform's default recognisers, which can send audio to a vendor's servers:
- **Android:** the `logcat` excerpt shows `NetworkSpeechRecognizer: Online recognizer - start listening` next to the offline one. An online recogniser was started on that run. My earlier summary said only that recognition "started"; that omitted this.
- **iOS:** the speech prompt is `SFSpeechRecognizer.requestAuthorization`, which `speech_to_text` calls from `initialize()` (`SpeechToTextPlugin.swift:237`). It is shown for **any** use of Apple's Speech framework, on-device or not, and its first paragraph is Apple's fixed text. With `onDevice` unset the recogniser is free to use Apple's servers.
- **What `onDevice: true` changes in 7.3.0:** iOS sets `requiresOnDeviceRecognition = true` and returns an error instead of recognising if `supportsOnDeviceRecognition` is false (`:495-499, :545-546`), so it fails closed. Android prefers `createOnDeviceSpeechRecognizer` (API 31+ / 33+ checks) and has a fallback on older versions (known gap). **The prompt text does not change** with `onDevice: true.`
- Whether `onDevice: true` really keeps audio off the network has **not** been observed on a device; it is the plugin's documented behaviour, read from source.

## Findings for NFR Requirements and Code Generation

1. **G2 confirmed on iOS** by the A/B: macro off, no prompt, empty screen with an endless spinner; macro on, both prompts appear.
2. **G3** (Android) is half wrong, as in the earlier note: the microphone prompt appears (the permission is merged in from a plugin), and recognition started without the `RecognitionService` `<queries>` entry on `Pixel_9_Pro_API_36`. The explicit entry stays as defence (NFR Q1 = A).
3. **N9 reproduced on Android**: about 5 s of silence ended the session with no restart.
4. **F2 reproduced on both platforms**: a denied or blocked start leaves an empty Caption screen and a spinner that never stops.
5. **The iOS system prompt says "Speech data from this app will be sent to Apple to process your requests."** That wording conflicts with the product statement "no audio or text data leaves the device" unless on-device recognition is enforced (NFR Q7 = C, `onDevice: true`). The prompt text is Apple's and the app cannot change it.
6. **The iOS Simulator crashed once** (`SIGABRT`, audio RPC timeout in `AVAudioEngine.inputNode`) while the macOS host microphone prompt was open. It did not recur with the host prompt answered. Not a physical-device result.
7. **The Android emulator has no on-device `en-US` pack** (`error 13`). With `onDevice: true` this emulator would take the language-unavailable path, so emulator QA of the on-device path needs the pack installed or shows the failure panel.
8. **Production registration needs a declared dependency.** `zip_captions` does not declare `speech_to_text`, and the throwaway import raised a `depend_on_referenced_packages` lint. The committed change must either declare it or have `zip_core` expose a factory (a Code Generation and SECURITY-10 decision).
9. **`pod install` needs `LANG=en_US.UTF-8`** on this host (a Ruby encoding error otherwise).

Not claimed: anything from a physical iPhone or Android phone (latency, on-device availability, wake lock).
