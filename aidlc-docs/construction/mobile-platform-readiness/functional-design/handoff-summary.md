# Handoff: Functional Design -> NFR Requirements
**Unit**: mobile-platform-readiness (Unit 10, S-22)
**Date**: 2026-10-25

## Decisions Made
- `PlatformSttEngine` is the only real engine, on iOS and Android only. Desktop and web register no real engine (macOS lacks a speech usage key).
- Registration is a pure function `registerSttEngines` with no platform calls. Availability is discovered lazily at Start Captioning.
- Debug: real engine by default on mobile; fake only with `--dart-define=ZIP_FAKE_STT=true` or when the platform has no real engine (desktop). Release never registers the fake.
- New `MobileAudioDeviceService` in `zip_core` (one default device, preference stored, no routing), built before the `ProviderContainer` and overridden into `audioDeviceServiceProvider` on every platform.
- TP-10 guards that the real engine is actually registered (release, hasRealEngine → exactly the platform engine).
- `RecordingStateNotifier.start()` keeps the error reported during `initialize()`. `RecordingScreen` awaits `start()` and shows a failure state with Try again / Open settings / Back. No new error kinds.
- No transcript text in logs; `recording_state_notifier.dart:102` changes to `e.runtimeType`.
- `zip_broadcast` is recorded only (evidence, `audit.md`, Backlog entry in `aidlc-state.md`).

- **Amendment 01 (2026-10-25, N9, revision 2 after Opus review, APPROVED 2026-10-25; the cap check increments first, then compares):** `PlatformSttEngine` restarts listening on the plugin's `done` status only, once per session end; classifies errors by code, not by the `permanent` flag (silence restarts and never counts, lasting stops, transient counts toward a cap); listens with `onDevice: true`; assigns the plugin's listener fields itself; and reports lasting errors and the cap through the additive `SttErrorSource.setErrorListener` / `SttEngineError` (decided shape). `RecordingStateNotifier.start()` also closes a start race (BR-U10-25). The cap, window and restart-delay numbers are NFR Requirements' to set. See `amendment-01-continuous-listening.md`.

- **Amendment 02 (2026-10-25, privacy, revision 2 after Opus review, APPROVED 2026-10-25; the exactly-once stop also covers `stop()`; British English for user-facing strings):** fail-closed on-device recognition. An injected `OnDeviceSupportChecker` (runner method channels in `zip_captions`, timeout a named constant) is called before every `listen()`; unsupported means refuse; a thrown `listen()` is always cancelled and treated as transient (no message matching); a session is finalised and stopped exactly once; first error wins in `start()`; a refused `resume()` stops the session; a one-time iOS explainer precedes Apple's prompt and `NSSpeechRecognitionUsageDescription` is rewritten. See `amendment-02-fail-closed-on-device.md`. The earlier "OPEN privacy question" in the NFR handoff is answered by it (A, hardened); option C was dropped.

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
| `registerSttEngines` | function, `zip_captions` | tests pass `allowDevEngines: false`; call-site inputs are compile-time constants |
| `MobileAudioDeviceService` | class, `zip_core` | implements the unchanged `AudioDeviceService` |
| `StartFailureView` | view model, `zip_captions` | classifies via `RecordingErrorFactories`, no retyped strings |
| `RecordingStateNotifier` | existing | only the `start()` `onError` wrapper and one log line change; TP-2 guards the rest |

## Constraints
- Resolved in review: `SpeechToText()` makes no platform call. The locked `speech_to_text` is 7.3.0 (`pubspec.lock`), where `factory SpeechToText() => _instance` and `withMethodChannel()` has an empty body. BR-U10-03 holds.
- "Open settings" shows only on iOS and Android (macOS has no `permission_handler` plugin). The failure panel hides the controls bar.
- `SttResult`, `RecordingState`, `RecordingError` and the `AudioDeviceService` interface are unchanged. The `SttEngine` contract surface is extended additively by Amendment 01, which James Petersen approved on 2026-10-25 (the shape is confirmed at re-approval). Any further change to a stable contract: stop and ask.
- Nothing may be registered locally, even temporarily, without James Petersen's approval.
- Physical-device results (latency under 1 s, screen on, recogniser availability) stay a later gate.

## Open Questions for Next Stage
- OQ-MA-1: whether `simctl privacy … reset all` returns the iOS speech prompt. It needs a real engine, so it needs an approved throwaway local registration. **Must be answered before NFR Requirements is approved.**
- Does an iOS denial of speech recognition need a `Permission.speech` check in the session manager, and the matching Podfile flag? (Q6; this affects the Open-settings rule for `engineInitFailed`.)
- The permission matrix per platform, the Android `RecognitionService` `<queries>` entry, and whether the merged release manifest carries `RECORD_AUDIO`.
- The PBT shim and seed logging (PBT-09).
- Signing-secret handling and the bundle-ID decision (G5), unchanged from the unit-of-work text. Opus is recommended for that review.
