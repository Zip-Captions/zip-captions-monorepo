# Functional Design Amendment 07: one notice per stop

**Unit**: 10, Mobile Platform Readiness (S-22). **Date**: 2026-10-30. **Revision**: 1. **Status**: APPROVED by James Petersen, 2026-10-30.

**Decision recorded** (James Petersen, 2026-10-30, during the physical Android device pass):
- **Request:** "The two separate toast messages for stopping after 5 minutes of no speech and the no transcript was saved should appear in one combined toast, rather than two separate toasts that are shown to the user one after another."
- **Wording:** one sentence when the session stopped after 5 minutes and nothing was recognised.
- **Scope:** combine every pair, so a stop never shows two notices in a row.

**Amendments 01 to 06 stand** except where this one names them. No `zip_core` change. The stop reason, the save outcome and the error are read exactly as now. `RecordingState`, the notifier's API and the save outcome provider are unchanged.

## 1. Why

When a session stops, `RecordingScreen` can show up to two SnackBars, queued one after the other (`recording_screen.dart`, the `StoppedState` listener):
- **the cause:** the mid-session error notice (BR-U10-23) or the inactivity notice (BR-U10-53);
- **the save outcome:** "No speech was recognised, so no transcript was saved." or "The transcript could not be saved." (BR-U10-60).

Each SnackBar shows for 4 s, so the second appears 4 s after the first. On the phone this read as two separate messages about one event.

## 2. Rules

| ID | Rule |
|---|---|
| BR-U10-65 | **One notice per stop.** When a session stops, `RecordingScreen` shows at most one one-time notice. It is built from the stop's **cause** and its **save outcome**:<br>• the cause is the error notice's title when the stop came with an error (BR-U10-23); otherwise the inactivity notice when the app stopped the session (BR-U10-53); otherwise none;<br>• the save outcome is `nothingRecognised` or `saveFailed` (BR-U10-60) while capture is on; otherwise none.<br>The table in BR-U10-66 gives the text. With neither, no notice is shown. The one-time guards (per session) and the navigation to History are unchanged. |
| BR-U10-66 | **Notice text.**<br>• inactivity + `nothingRecognised`: "Captioning stopped after {minutes} minutes without speech, so no transcript was saved." (new string; "1 minute" for 1, as BR-U10-53)<br>• inactivity + `saveFailed`: "Captioning stopped after {minutes} minutes without speech. The transcript could not be saved." (the two existing sentences, joined)<br>• error + `nothingRecognised`: "{error title}. No speech was recognised, so no transcript was saved."<br>• error + `saveFailed`: "{error title}. The transcript could not be saved."<br>• cause only, or save outcome only: that notice alone, unchanged.<br>The joins are ARB templates, so a translation can reorder them. The error titles carry no full stop of their own, and the template adds it. |
| BR-U10-67 | **What this replaces.** It replaces the queueing in BR-U10-23 ("shown after the error notice"), BR-U10-53 ("shown before the no-transcript notice (ScaffoldMessenger queues)") and BR-U10-60 ("queued after the inactivity notice, exactly like the current notice"). Each of those notices still appears alone when it is the only part. |

## 3. Testable properties

| ID | Property |
|---|---|
| TP-43 | Table-driven widget test over cause ∈ {none, inactivity, error} × save outcome ∈ {`saved`, `nothingRecognised`, `saveFailed`, unknown} × capture ∈ {on, off}. Each stop shows **at most one** SnackBar, with the exact text from BR-U10-66; it never shows a second one after the first is dismissed. With capture off, only the cause shows. The singular "1 minute" holds in both inactivity combinations. Replaces the three "queues … after …" tests. |
| TP-44 | `ZcStrings`: the new strings read their ARB keys, fill `{minutes}` (singular for 1) and `{title}`, and the real ARB file contains each key with the exact English text above. |

## 4. Strings

New `app_en.arb` keys, each with a `ZcStrings` getter or method (`zip_captions` has no `gen-l10n`):
- `inactivityStopNoTranscriptNotice`: "Captioning stopped after {minutes} minutes without speech, so no transcript was saved." (`{minutes}` int)
- `inactivityStopSaveFailedNotice`: "{inactivityNotice} {saveFailedNotice}". It joins the two existing sentences, filled from `inactivityStopNoticeFor` and `transcriptSaveFailedNotice`.
- `stopErrorWithSaveOutcomeNotice`: "{errorTitle}. {saveOutcomeNotice}"

The existing keys stay as they are, because each still shows alone.

## 5. QA

On the Android phone, through the app:
- **A silent 5-minute session:** exactly one notice, "Captioning stopped after 5 minutes without speech, so no transcript was saved.", and no second notice after it.
- **A silent 10-second Stop:** "No speech was recognised, so no transcript was saved." alone, as before.

The error and save-failed combinations can't be provoked on a device; they are widget-tested only (TP-43).

## 6. Compliance

- **Security Baseline:** no change. The notices carry no recognised text (SECURITY-03).
- **PBT:** TP-43 is an exhaustive table rather than a generated property, which is acceptable for a finite input space (PBT-10).
- **No blocking finding.**
