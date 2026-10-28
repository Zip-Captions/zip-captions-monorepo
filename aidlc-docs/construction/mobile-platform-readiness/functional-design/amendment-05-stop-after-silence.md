# Functional Design Amendment 05: stop captioning after a period without speech

**Unit**: 10, Mobile Platform Readiness (S-22). **Date**: 2026-10-26. **Revision**: 1. **Status**: APPROVED by James Petersen, 2026-10-26.
**Decision recorded** (James Petersen, verbatim): "the expected behaviour for the app is that it should stop recognition if it has not recognized any speech for 5 minutes. the 5 minutes should be able to be exposed as a user-facing setting in a future release". Details chosen the same day: any recognition result resets the timer; a one-time notice is shown; paused time does not count.
**Amendments 01 to 04 stand.** No stable contract changes.

## 1. Why

Nothing in the app ends a session when nobody is speaking. A forgotten session keeps the microphone open, holds the screen on (wake lock), and on Android renews the segmented session every 5 minutes (Amendment 03 D-2 as revised), each renewal with a chime. Stopping after 5 minutes without speech closes all three.

## 2. Rules

| ID | Rule |
|---|---|
| BR-U10-51 | **Inactivity stop.** While a session is in `RecordingActiveState` or `ReconnectingState`, a timer of `speechInactivityTimeout` runs. It starts when the session enters recording (start, resume, the REL-U2.1 recovery back to recording) and restarts on **every** recognition result the notifier receives, interim or final. Pause cancels it; resume starts it again from zero (paused time does not count). When it fires, the session is stopped exactly as the user's Stop does it, through the single-flight `_finishSession` (BR-U10-35): one finalise, `StoppedState`, the `SessionStateEvent`, the wake-lock release. It is not an error: `lastError` stays null. |
| BR-U10-52 | **The setting.** `speechInactivityTimeout` defaults to **5 minutes**, a named constant in `zip_core`, read through a provider so a future settings screen can override it without changing the rule. No settings UI in this unit. |
| BR-U10-53 | **The notice.** When a session stops for inactivity, `RecordingScreen` shows a one-time SnackBar: "Captioning stopped after {minutes} minutes without speech." (British English; "1 minute" in the singular), using the timeout in force. If no transcript was saved (Amendment 03 section 7), the "no transcript was saved" notice is queued after it. The stop reason reaches the screen through a small `zip_core` provider, consumed once like the transcript save outcome; `RecordingState` and the notifier's public API are unchanged. |
| BR-U10-54 | **Scope.** Applies wherever `RecordingStateNotifier` runs (Zip Captions on every platform). `zip_broadcast`'s `BroadcastRecordingNotifier` does not use it; recorded as a Backlog item for the unit that next changes `zip_broadcast`. |

## 3. Interplay

- With 5-minute Android segmented sessions, a silent room stops at about 5 minutes instead of renewing with a chime. A session with speech keeps renewing (BR-U10-39) and never trips this rule.
- A user Stop, an engine error stop or a refused resume that lands first wins (BR-U10-35); the timer is cancelled by `_finishSession`.
- Logs: the stop reason enum and the timeout in seconds only (SECURITY-03).

## 4. Testable properties

| ID | Property |
|---|---|
| TP-32 | Stateful, `fake_async`: over random sequences of results (interim, final) at random gaps, pause and resume with random durations, stop and engine errors, the inactivity stop happens exactly when there was no result for `speechInactivityTimeout` of non-paused time, at most once, never after another stop began, with one finalise and `lastError` null. |
| TP-33 | The notice: shown once on an inactivity stop, with the minutes from the provider and the singular for 1; queued before the no-transcript notice; never shown for a user, error or refused-resume stop. |
| TP-12 (extended) | No transcript text in the new logs. |

## 5. QA

The Step 30 silent-wait check changes: after 5 minutes without speech the session stops with the notice, rather than renewing. The renewal (Amendment 03 BR-U10-39) is checked with speech continuing past 5 minutes instead.

## 6. Compliance

Security Baseline: no new permission; the rule reduces how long the microphone stays open. PBT: TP-32 stateful (PBT-06), TP-33 example pins (PBT-10). No blocking finding.
