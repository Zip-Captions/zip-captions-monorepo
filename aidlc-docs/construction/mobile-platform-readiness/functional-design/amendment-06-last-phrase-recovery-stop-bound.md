# Functional Design Amendment 06: the last phrase at Stop and Pause, recovery re-arming, and a bounded Stop

**Unit**: 10, Mobile Platform Readiness (S-22). **Date**: 2026-10-29. **Revision**: 3. **Status**: APPROVED by James Petersen: revision 1 and revision 2 (section 8, the first CodeRabbit review of PR #44) on 2026-10-29; revision 3 (section 9, the full CodeRabbit review) on 2026-10-30.
**Decisions recorded** (James Petersen, 2026-10-29, answering the three open items from the Step 29d review):
- **(1)** Keep the last phrase, bounded: after Stop, wait up to about 1 s for the final result before the transcript is finalised; after Pause, accept it into the transcript; if nothing arrives in time, carry on as now.
- **(2)** Re-arm the REL-U2.1 recovery once the recovered session delivers recognised text.
- **(3)** Bound Stop at 5 s: go to Stopped anyway, release the wake lock, and report the transcript as not saved if it did not finish finalising.

**Also approved the same day:** the BR-U10-40 wording correction (section 5).

**Amendments 01 to 05 stand** except where named here. No stable contract changes: `SttEngine`, `SttResult`, `RecordingState` and the notifier's public API are unchanged.

## 1. Why

- **(1) The last phrase is lost.**
  - Both platforms finish recognising the speech already captured after a stop:
    - Android: `SpeechRecognizer.stopListening()` "Speech captured so far will be recognized as if the user had stopped speaking at this point" (Android SDK 36 source, `SpeechRecognizer.java:461-463`).
    - iOS: the plugin's stop calls `SFSpeechRecognitionTask.finish()`, which "finishes processing on the audio input that has already been accepted" (`speech_to_text` 7.3.0 `SpeechToTextPlugin.swift:379`; Apple Speech docs).
  - Unit 10 throws that result away:
    - `SegmentedSpeechEngine` drops every event once `stopListening()` or `pause()` has run (`_sessionLive = false`, `_onEvent`).
    - `PlatformSttEngine.stopListening()` calls `cancel()` straight after `stop()`, which discards the iOS final result.
    - A result that reaches `RecordingStateNotifier` after `pause()` has set `PausedState` is dropped by `_handleSttResult`.
  - Either way, the words spoken just before Stop or Pause never reach the captions or the transcript.
- **(2) The recovery is never re-armed.**
  - `_hasAttemptedRestart` is reset only by `start()`. One REL-U2.1 recovery is allowed per session, however long it runs.
  - So in a long lecture, two unrelated engine failures an hour apart end captioning at the second one.
- **(3) Stop has no time limit.**
  - `_runFinish` awaits the engine stop, then the transcript finalise.
  - If either never completes (the platform channel never replies, or a database write hangs), Stop never completes. The app stays on the recording screen with the wake lock held.
  - That breaks the screen-on consent constraint in reverse: the screen stays on after the user asked to stop.

## 2. Rules

| ID | Rule |
|---|---|
| BR-U10-55 | **Drain the last phrase.** `stopListening()` and `pause()` still set the intent first and move the epoch (BR-U10-19), so nothing can restart or renew. Each then asks the platform to stop and **waits, up to `finalResultDrainTimeout` (1 s, a named constant in `SttListeningLimits`), for the platform to finish recognising the captured speech**, before it returns. During that wait the engine delivers results through the existing `onResult` callback, and only results; it never renews, restarts, counts or reports an error from the drain. The wait ends at the first of: (a) a final result is delivered, (b) the platform signals the end (Android: `endOfSession` or an error; iOS: status `done` or an error), (c) the deadline. If the wait ends without a final result and an interim result is pending, that interim is delivered once as final (the BR-U10-16 flush). Then: `stopListening()` cancels the platform session (as today), and `pause()` leaves it stopped. Drained text is held in memory only and never logged (SECURITY-03). |
| BR-U10-56 | **Where the drained phrase goes.** Because the engine delivers it before `stopListening()` or `pause()` returns, the notifier is still in `RecordingActiveState` and publishes it as usual. On Stop it reaches the transcript before the finalise in `_runFinish`. On Pause it is saved to the same session before `PausedState` is set. `_handleSttResult` is not changed. A drained result does not restart the inactivity timer once `_finishing` is set (BR-U10-51 as written). |
| BR-U10-57 | **Re-arm the recovery.** After a successful REL-U2.1 recovery (back to `RecordingActiveState`), the first result with non-empty text that the notifier receives clears `_hasAttemptedRestart`, so a later engine error gets its own recovery attempt. Until that result arrives, a second error stops the session as today. A recover-and-fail loop therefore needs recognised speech on every cycle and cannot repeat silently. `start()` still resets the flag. |
| BR-U10-58 | **Bounded Stop.** `_runFinish` gives the engine stop and the transcript finalise together at most `stopFinaliseTimeout` (5 s, a named constant in `zip_core`), measured from the start of `_runFinish`. When the deadline passes before both have completed: the routine stops waiting, logs a fixed string and which step was pending, and goes on to `StoppedState`, the `SessionStateEvent` and the wake-lock release exactly as now (BR-U10-35, once). If the finalise had not completed, the transcript save outcome is set to "not saved", so the existing notice is shown (Amendment 03 section 7). The abandoned calls are not cancelled and may still complete later. A late finalise may still write the transcript, which then appears in History even though the notice said it was not saved; this is accepted. The 5 s includes the 1 s drain (BR-U10-55). |
| BR-U10-59 | **What a bounded Stop cannot guarantee.** The engine's intent is already `stopped` before any platform call, so no restart or renewal follows a timed-out stop (BR-U10-19). Whether the platform releases the microphone when its own stop call never returns is outside Dart's control. It is recorded as a limitation for the physical-device pass, not claimed. |

## 3. Interplay

- **Stop during the REL-U2.1 recovery:** BR-U10-35 and TP-2c are unchanged. `_finishSession` is still called synchronously; the drain happens inside `_sessionManager.stop()`; the recovery still checks `_finishing` first.
- **Pause then Resume:** `resume()` can only be reached once `pause()` has returned (the notifier sets `PausedState` after it), so a drain never overlaps a resume's start.
- **Inactivity stop:** it goes through `_finishSession`, so it drains and is bounded the same way.
- **Android renewal:** a renewal is not a stop or a pause, so BR-U10-55 does not apply to it; BR-U10-39 and BR-U10-44 are unchanged.
- **Sounds:** unchanged. Stop and Pause are user actions (BR-U10-42); the drain adds no platform call.

## 4. Testable properties

| ID | Property |
|---|---|
| TP-34 | Example-based and stateful, fake time, both engines with their fakes: a final result that the fake platform delivers within `finalResultDrainTimeout` after `stopListening()` or `pause()` is delivered exactly once through `onResult` before the call returns. A result after the deadline is never delivered. A pending interim with no final is delivered once as final at the end of the wait. No `listen()`/`start`, renewal, count or error happens during a drain (extends TP-11 (a)). |
| TP-35 | Notifier: a drained final result on Stop reaches the caption bus before the transcript finalise, so the transcript writer saves it (one segment more than without it). On Pause it is saved to the same session and then `PausedState` is set. |
| TP-36 | Stateful, fake time: after a successful recovery, a second error before any non-empty result stops the session (one finalise). A second error after a non-empty result gets a recovery attempt. Every session ends with exactly one finalise (extends TP-2b). |
| TP-37 | Fake time: with the engine stop or the finalise never completing, `stop()` completes at `stopFinaliseTimeout`; the state is `StoppedState` once, the event is published once, the wake lock is released once, and a pending finalise sets the outcome to "not saved". With both completing in time, the behaviour and the outcome are as before. |
| TP-12 (extended) | No transcript text in any new log record (the drain and the timeout). |

## 5. BR-U10-40 wording (approved 2026-10-29)

BR-U10-40's Silence clause said codes 6 and 7 were "never counted", which contradicts decision D-4 (BR-U10-44). It now reads: "Silence: 6, 7 (renew as in BR-U10-39; never counted as a transient failure; a silence end before 90% of the session length is an early end and counts under BR-U10-44)." This is a wording fix only; the code already follows D-4.

## 6. QA

The device pass adds three checks, all through the app on the Android 13+ phone and the iOS device or Simulator:
- Stop and Pause while speaking: the last phrase appears in the captions and the transcript.
- Captioning continues after one recovery and a later one (if a recogniser failure can be provoked through the app; otherwise unit tests only, and recorded as such).
- The 5 s bound is unit-tested only. It is not provoked on a device.

## 7. Compliance

- **Security Baseline:** no new permission. BR-U10-58 shortens the worst case for the screen staying on after Stop. BR-U10-59 records the microphone limitation honestly. SECURITY-03 holds by BR-U10-55 and TP-12.
- **PBT:** TP-34 and TP-36 are stateful (PBT-06); TP-35 and TP-37 are example pins (PBT-10).
- No blocking finding.

## 8. Revision 2: CodeRabbit review of PR #44

The items in this section come from the CodeRabbit review of PR #44 (findings #1, #3, #4, #15, #16, #2, #9 and #10). James Petersen approved the triage and the notice text on 2026-10-29. BR-U10-58's "not saved" now means the `saveFailed` outcome of BR-U10-60.

| ID | Rule |
|---|---|
| BR-U10-60 | **Three save outcomes** (CodeRabbit #1, #3). The transcript save outcome is no longer a `bool?`. It is one of `saved`, `nothingRecognised` or `saveFailed`; `null` means no outcome yet. `TranscriptWriterTarget` reports:<br>• `nothingRecognised` when no row was ever asked for (Q-2, as today);<br>• `saved` when the row was created **and** at least one segment save or merge succeeded;<br>• `saveFailed` otherwise: the create failed, or every segment save and merge failed.<br>BR-U10-58's timeout with the finalise still pending sets `saveFailed`. `RecordingScreen` shows the existing "No speech was recognised, so no transcript was saved." for `nothingRecognised`, and a new one-time notice, "The transcript could not be saved.", for `saveFailed`. The new string goes in `app_en.arb` with a `ZcStrings` getter. It is queued after the inactivity notice, exactly like the current notice (BR-U10-53). |
| BR-U10-61 | **The engine stop at finish never strands the session** (CodeRabbit #4). In `_runFinish`, the engine stop is wrapped so that anything it throws, an `Error` included, is logged by type only. The finalise, `StoppedState`, the event and the wake-lock release then still run, once (BR-U10-35). `_finishing` therefore always completes normally. |
| BR-U10-62 | **Results that arrive while a start or a resume is in flight are kept** (CodeRabbit #15). While `start()` or `resume()` is running (the existing capture window that keeps the first error, BR-U10-25), the notifier holds the results it receives, in order, in memory only, and never logs them. Once the state becomes `RecordingActiveState`, it replays them through the normal result path, in order, before any later result. On every path that does not reach Recording (a failure, a captured error, a stop or a refused resume), it drops them. Stop still wins (BR-U10-35). |
| BR-U10-63 | **A throwing pause keeps the session usable** (CodeRabbit #16). If the engine pause throws (an `Error` passes through the session manager's `on Exception` catch), the notifier logs the type and stays in `RecordingActiveState`. If the same session still owns the recording and no finish has begun, it re-arms the inactivity timer. A timer for an older session never replaces one for a newer session. |
| BR-U10-64 | **Language-pack panel deadlines** (Amendment 04; CodeRabbit #2, #9, #10).<br>• **(a)** The status request has a 5 s deadline. When it passes, the section shows its existing failed state with Try again, instead of nothing.<br>• **(b)** After a progress event, if no further event arrives within `kLanguagePackRecheckLimit` (5 minutes), the download shows the failed state.<br>• **(c)** On Android, a re-check after a tap that finds `downloading` (pending) shows the scheduled state, not failed, as BR-U10-47a already states for the first check. iOS is unchanged, because there `downloading` is a real transfer. |

| ID | Property |
|---|---|
| TP-38 | Table-driven: each way a session can end maps to one outcome and one notice: no segment; created and saved; create failed; every save failed; one save failed and a later merge succeeded; the BR-U10-58 timeout. No notice is shown for `saved`. The inactivity notice comes first when both apply. |
| TP-39 | Fake engine and fake time: results delivered while `startListening()` or `resume()` is pending reach the caption bus exactly once, in order, after `RecordingState.recording` is published. They never reach it when the start fails, an error is captured or a stop lands first. No log record holds their text (extends TP-12). |
| TP-40 | An engine stop that throws an `Error` during `_runFinish` still ends in `StoppedState` once, with one event, one wake-lock release and the finalise attempted. A later `stop()` completes normally. |
| TP-41 | An engine pause that throws an `Error` leaves the session Recording with the inactivity timer armed. After a stop and a new start, a pause on the old session cannot arm a timer for the new one. |
| TP-42 | Widget tests, fake time: a status reply that never comes shows failed with Try again at 5 s; a stall after progress shows failed at the limit; Android `downloading` after a tap shows scheduled; iOS `downloading` after a tap does not. |

**Declined from the same review**, with a reply on its thread:
- **#14** (an unbounded write queue): BR-U10-58 stops it from blocking Stop, and the queue holds text only. Recorded in the Backlog.

**#17 and #18** (freezed for `LanguagePackInfo` and `SttEngineError`): first declined, then accepted on 2026-10-30. The decline cited AGENTS.md ("freezed for state classes"). The project rule is wider: `docs/04-technical-specification.md` section 2 says "Use freezed for immutable data/value classes (settings, locale models, error objects)". Both classes are now freezed. What Amendment 01 approved is unchanged: `SttEngineError` holds only its kind, has value equality on the kind, and has no free-text field (SECURITY-03, TP-12). Its textual form is now freezed's `SttEngineError(kind: SttEngineErrorKind.<name>)`. `LanguagePackInfo` keeps its two fields and its equality.

**Fixed without a design change:**
- #5: the Android bridge `onError` gets the same live-session guard as `_onEvent`.
- #11: the explainer's buttons are disabled while Continue's write is pending.
- The `_regionOf` follow-up: the region subtag is taken, skipping a script subtag.
- The `// ignore` removals in tests.
- The split of the two Unit 10 test helpers (one public class per file).
- The test-coverage nitpicks.
- An "additional comment" (2026-10-30): the Android activity's two teardown paths now also clear the language-pack event sink, so a model download that outlives the engine cannot reach the old engine's sink.

## 9. Revision 3: the full CodeRabbit review of PR #44 (approved by James Petersen, 2026-10-30)

| ID | Rule |
|---|---|
| BR-U10-58 (clarified) | **Work abandoned at the 5 s bound does not reach a new session.**<br>• When the deadline passes while the engine stop is still pending, the finalise **never starts**. A new session may already own the transcript writer by the time the stop returns, and the finalise would close it. The session is reported as `saveFailed`, as before.<br>• A finalise that was already running when the deadline passed may still complete and write the old transcript, as before.<br>• In both engines, a stop whose platform call returns after a new `startListening()` does **not** send its closing cancel. The cancel runs only while the engine's intent is still "stopped". |

| ID | Property |
|---|---|
| TP-37 (extended) | An engine stop that completes after the bound and after `clearSession()` plus a new `start()` does not call the finaliser, and the new session stays Recording. For each engine, a stop held open in the platform, then a new start, then the stop releasing: no cancel after the new start. |

**From the same review, fixed with no design change:** after a failed session-row create, no segment write (new or merged) is attempted. SQLite foreign keys are on (`transcript_database.dart`), so each would fail. The outcome stays `saveFailed`.

**Declined from the same review:** dropping "It doesn't send your audio anywhere." from `NSSpeechRecognitionUsageDescription`. Section 6.2 of Amendment 02 approved that sentence for the Info.plist text and the explainer. Only the after-the-fact failure sentence was removed (Amendment 02 section 6.3). The wording stays provisional until the iOS airplane-mode check passes.
