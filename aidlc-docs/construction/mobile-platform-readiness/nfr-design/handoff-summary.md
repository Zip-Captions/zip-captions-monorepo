# Handoff: NFR Design -> Code Generation
**Unit**: mobile-platform-readiness (Unit 10, S-22)
**Date**: 2026-10-25
**Status**: drafted on proposed answers; awaiting James Petersen's confirmation at the NFR Design approval gate. Not approved.

## Decisions Made (proposed by Sonnet, awaiting James Petersen)
- Restart loop and check-before-listen are a private `_SessionLoop` inside `PlatformSttEngine` (no public controller type); session length uses an injected `now` function, not `package:clock`.
- Tunables in one file: `SttListeningLimits` / `defaultSttListeningLimits` in `zip_core/lib/src/constants/` (`restartCap 3`, `immediateFailureWindow 2 s`, `restartDelay 250 ms`, `onDeviceCheckTimeout 2 s`).
- The engine itself wraps any checker in `try`/`catch` plus a timeout (fail closed); no caching of the check.
- **Stop wins against the REL-U2.1 recovery (Opus review fix):** `stop()` calls `_finishSession` synchronously at entry; `_finishSession`'s first step is `_sessionManager.stop()`; the recovery future checks `_finishing != null` first and stops the manager again without changing state, `lastError` or the wake lock; `_handleEngineError` ignores errors once `_finishing` is set. New property TP-2c (stateful, fake time) in `zip_core/test/pbt/`.
- Exactly-once stop is a single-flight shared future (`_finishing`), used by every stop path including `stop()`; first-error capture is operation-scoped (`_captured`, `_capturing`) for `start()` and `resume()`.
- `createPlatformSttEngine` in `zip_core` builds `PlatformSttEngine` with `SpeechToText()`; `zip_captions/pubspec.yaml` is unchanged (correction 3 confirmed).
- iOS channel code goes inside `AppDelegate.swift` (implicit-engine delegate), Android inside `MainActivity.kt`; no new native file, no `project.pbxproj` edit for it.
- New `zip_captions` pieces: `services/stt_engine_registration.dart`, `services/method_channel_on_device_support_checker.dart`, `widgets/start_failure_view.dart`, `widgets/speech_explainer_gate.dart`; strings through `ZcStrings`, British English.
- Tests: `zip_core/test/pbt/` and `zip_captions/test/pbt/` with the shim copied to `zip_captions/test/helpers/pbt.dart`; `fake_async` for timers; hand-written fakes.

## Key Entities / Components
| Name | Type | Constraint for Code Generation |
|---|---|---|
| `PlatformSttEngine` | changed, `zip_core` | required `onDeviceSupportChecker`; implements `SttErrorSource`; never sets `androidIntentLookup`; cancel on any `ListenFailedException` |
| `SttErrorSource`, `SttEngineError` | new, `zip_core` | method not setter (`very_good_analysis`); kind-only payload |
| `RecordingStateNotifier` | changed | no new state or public method; `_finishSession`, capture, race rule, refused-resume rule |
| `registerSttEngines`, `StartFailureView`, `SpeechExplainerGate` | new, `zip_captions` | per Functional Design and the amendments |
| Runner channel code | changed | `app.zipcaptions/speech_support`, `isOnDeviceSupported` |

## Constraints
- `SttResult`, `RecordingState`, `RecordingError`, `AudioDeviceService` unchanged; `SttEngine` extended only by `SttErrorSource`.
- Stay on `speech_to_text` 7.3.0; no new package; nothing from a physical device is claimed; the release build is debug-signed and must not be distributed.
- At Code Generation Part 2 follow `CLAUDE.local.md` for delegation; the engine loop, error mapping and `RecordingStateNotifier` changes are security- and contract-sensitive and stay with the orchestrator (the delegation protocol decides).

## Open Questions for Code Generation
- Items in `logical-components.md` section 6 (the iOS locale mapping, the iOS `onDeviceError` string, error-code strings, `dispose()` reachability). The iOS channel API and the existing `stop()` sequence were settled in the Opus review.
- Device pass (later gate): airplane mode; refusal on an unsupported device or locale; a no-pack language refused; Android logs show the on-device recogniser; the restart observations (chime, words lost) each answered "acceptable for Alpha 1?" by James Petersen, a "no" returns to design.
