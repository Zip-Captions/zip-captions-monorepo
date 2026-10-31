# Handoff: NFR Requirements -> NFR Design
**Unit**: mobile-platform-readiness (Unit 10, S-22)
**Date**: 2026-10-25
**Status**: complete and ready for the NFR Requirements approval gate. The privacy decision below was made on 2026-10-25 (Amendment 02).

## Decisions Made
- OQ-MA-1 answered: iOS speech consent cannot be pre-granted; `simctl privacy … reset all` brings both the microphone and speech prompts back; iOS QA needs one manual Allow on the speech prompt after each fresh install or reset.
- Android: explicit `RECORD_AUDIO` and a `RecognitionService` `<queries>` entry; no `INTERNET`/Bluetooth. iOS: `PERMISSION_MICROPHONE=1` only; speech denial stays a generic init failure with "Open settings".
- New IDs: `app.zipcaptions.captions` on Android and iOS, display name "Zip Captions"; Unit 11 checks the ID is free in both consoles before the first upload; Android namespace and `MainActivity.kt` move to match.
- No `initialize()` timeout (iOS shows the speech prompt there). Latency is a physical-device gate. Android keep-screen-on check by `dumpsys window` only. Signing: policy only. PBT shim copied into `zip_captions/test/helpers/pbt.dart` (fixed seeds 0-99, no shrinking, no seed printed).
- Engine constants as named values, starting at `restartCap = 3` (increment-then-compare), `immediateFailureWindow = 2 s`, `restartDelay = 250 ms`, confirmed at the device pass.

## Privacy decision (made 2026-10-25, James Petersen): fail-closed platform engine
`SpeechToText.initialize()` calls `SFSpeechRecognizer.requestAuthorization`, so iOS shows Apple's dialog ("Speech data from this app will be sent to Apple...") for any use of Apple's Speech framework, even with `onDevice: true`, and the text cannot be changed. Decision: keep `PlatformSttEngine`, run an `OnDeviceSupportChecker` before every `listen()`, refuse when unsupported (Amendment 02), show a one-time iOS explainer and a rewritten `NSSpeechRecognitionUsageDescription` (British English). Alpha 1 is internal testers only. Gate before any wider release (Backlog in `aidlc-state.md`): decide whether Sherpa-ONNX becomes the mobile default, and prepare the app-store privacy answers (Unit 11). The plugin's iOS missing-`return` defect is upstream #673 (fixed by PR #674) and the Android stop→listen race is #678 (fixed by PR #679); both fixes are in the 7.6.0 betas but in no stable release (verified 2026-10-25), nothing needs filing, and the plugin stays on 7.3.0 for Alpha 1 (NFR-U10-03a); the checker's upgrade path to the plugin's `has_on_device_support` is in `tech-stack-decisions.md`. Option C (iOS 26 native API) was dropped.

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
| `PlatformSttEngine` | existing, `zip_core` | `onDevice: true`; Amendment 01 loop; assigns plugin listeners directly |
| `SttErrorSource` / `SttEngineError` | new, `zip_core` | kind-only error; mapped to existing factories |
| `registerSttEngines`, `StartFailureView`, `MobileAudioDeviceService` | new | as in Functional Design |

## Constraints
- `SttResult`, `RecordingState`, `RecordingError`, `AudioDeviceService` unchanged; `SttEngine` extended only by the approved additive channel.
- Nothing from a physical device is claimed. The release build is debug-signed and must not be distributed.

## Open Questions for Next Stage
- Prefer a `zip_core` factory that builds `PlatformSttEngine` with its own `SpeechToText()` over declaring `speech_to_text` in `zip_captions` (SECURITY-10); NFR Design confirms.
- Device pass: Amendment 01 restart observations (chime on each internal restart, and how often; words lost between sessions), each to be answered "acceptable for Alpha 1?" by James Petersen; a "no" returns to design.
- Device pass: airplane mode on a physical iPhone and Android phone; refusal on an unsupported device or locale; Android logs show the on-device recogniser, not "Online recognizer"; a no-pack language is refused (not online); `restartDelay`, `onDeviceCheckTimeout` and the restart constants.
- Confirm at Code Generation: the iOS locale mapping used by the checker matches the plugin's `getLocale`; the string iOS sends for `onDeviceError` through the error listener; the iOS missing-`return` behaviour.
- NFR Design: where the exactly-once stop routine, the checker channel and the explainer gate sit in the existing structure.
