# Functional Design Amendment 03: silent continuous captioning on Android, and the emulator QA decisions

**Unit**: 10, Mobile Platform Readiness (S-22). **Date**: 2026-10-26. **Revision**: 1. **Status**: APPROVED by James Petersen, 2026-10-26, with D-1 = refuse below Android 13 and D-2 = 60 minutes (section 12). Sections 6 to 8 record decisions James Petersen has already made (2026-10-26); they are being built under plan Step 29b and are listed here so the design record is complete.
**Amendments 01 and 02 stand.** This amendment replaces Amendment 01's restart loop **on Android only** (iOS keeps it) and adds rules; every change to earlier documents is named in section 10.
**Why**: the Step 30 emulator QA answered the Amendment 01 device-pass observation (a), "Does Android play a chime on each internal restart? Acceptable for Alpha 1?", with **no** (James Petersen, 2026-10-26: "it should be silently running, with only the sound emitting on user interaction (start/stop/pause)"). NFR section 8 says a "no" returns to design, not to tuning.

## 1. Evidence

| Fact | Evidence |
|---|---|
| The chime comes from Android, not the app, on every recogniser session start or end | `speech_to_text` 7.3.0 README, "Android beeps on start/stop of speech recognition": "This is a feature of the Android OS and there is no supported way to disable it." |
| Amendment 01's loop starts a session after every pause | Emulator, 2026-10-26, about 10.5 minutes of silence: 116 `listen()` sessions, about one every 5 s, each heard as a chime |
| The plugin cannot run one long session | README: "designed for short intermittent use"; 7.3.0's Android `listen()` sets no segmented-session extra (`SpeechToTextPlugin.kt` lines 636 to 657) |
| Android 13 (API 33) has a segmented session | `RecognizerIntent.EXTRA_SEGMENTED_SESSION`, added in API 33: results arrive through `RecognitionListener.onSegmentResults(Bundle)`, and the session ends with `onEndOfSegmentedSession()`, "when segmented session mode is supported by the recognizer implementation" |
| The on-device recogniser supports it (throwaway spike, never committed; `Pixel_9_Pro_API_36`, en-US pack, `createOnDeviceSpeechRecognizer`, `EXTRA_SEGMENTED_SESSION = EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS`) | A 40 s session: two phrases 8 s apart, each recognised correctly as its own segment, with partial results about every 0.6 s, and the session ended at the requested length. A 300 s session: phrases at 0:03 and 4:48 both recognised, no early end. Heard by James Petersen: no chime between phrases, one chime when the session ended |
| The minimum length must be an `int` | With a `long` value the service logged "EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS is not set with positive value; ignoring EXTRA_SEGMENTED_SESSION" and the session ended after 5 s |
| Later segments begin with a space | Spike log: `onSegmentResults  This is the second sentence…` |
| Error codes | Android reference: `ERROR_NETWORK_TIMEOUT` 1, `ERROR_NETWORK` 2, `ERROR_AUDIO` 3, `ERROR_SERVER` 4, `ERROR_CLIENT` 5, `ERROR_SPEECH_TIMEOUT` 6, `ERROR_NO_MATCH` 7, `ERROR_RECOGNIZER_BUSY` 8, `ERROR_INSUFFICIENT_PERMISSIONS` 9, `ERROR_TOO_MANY_REQUESTS` 10, `ERROR_SERVER_DISCONNECTED` 11, `ERROR_LANGUAGE_NOT_SUPPORTED` 12, `ERROR_LANGUAGE_UNAVAILABLE` 13, `ERROR_CANNOT_CHECK_SUPPORT` 14, `ERROR_CANNOT_LISTEN_TO_DOWNLOAD_EVENTS` 15. The emulator showed 13 for a missing pack and 12 for an unsupported locale |
| O-3: the plugin's recogniser does not recover after the system service dies | After the recogniser service was killed while the app ran, every later session failed until the app restarted; the plugin creates its recogniser once, and `initialize()` returns early after the first success |

The emulator's audio path adds about 2.5 s of latency; it says nothing about devices.

## 2. Scope

- **Android**: a new engine, `SegmentedSpeechEngine`, replaces `PlatformSttEngine` as the registered `'platform'` engine. `speech_to_text` is no longer used by `zip_captions` on Android.
- **iOS**: unchanged. `PlatformSttEngine` and Amendment 01's loop stay; iOS restarts about once a minute and the plugin plays no sound there unless sound assets are added (none are). The Simulator pass confirms it is silent.
- **Not changed**: `SttEngine`, `SttErrorSource`, `SttResult`, `RecordingState`, `RecordingError`, `AudioDeviceService`; the notifier and session-manager rules (BR-U10-22, 25, 28, 35, 36, Q-1 single-flight); the on-device check before every session (BR-U10-26); `zip_broadcast`.

## 3. Shape

- **`zip_core`**: `SegmentedSpeechEngine implements SttEngine, SttErrorSource`, built on an injected `SegmentedRecognizerBridge` interface: `start(localeId, minimumLengthMs)`, `stop()`, `cancel()`, `recreate()`, and a stream of bridge events (`ready`, `partial(text)`, `segment(text)`, `endOfSession`, `error(code)`). The same pattern as the Amendment 02 checker: the contract lives in `zip_core`, and the implementation in the app.
- **`zip_captions` Android runner**: `MainActivity` creates the recogniser with `SpeechRecognizer.createOnDeviceSpeechRecognizer`, and exposes it on a method channel `app.zipcaptions/segmented_speech` plus an event channel `app.zipcaptions/segmented_speech/events`. The intent carries `LANGUAGE_MODEL_FREE_FORM`, `EXTRA_LANGUAGE`, `EXTRA_PARTIAL_RESULTS = true`, `EXTRA_SEGMENTED_SESSION = EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS`, and `EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS` as an **`Int`**. Kotlin logs carry no recognised text.
- **The on-device check** on Android becomes `SDK_INT >= 33 && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)`, on the existing `app.zipcaptions/speech_support` channel.
- **Registration** (`registerSttEngines`): Android registers `SegmentedSpeechEngine` and iOS registers `PlatformSttEngine`, both with `engineId == 'platform'`; the debug-fake rules are unchanged.
- **Limits**: `SttListeningLimits` gains `segmentedSessionLength` (default **5 minutes**, decision D-2 as revised; the recogniser's measured maximum), a named constant.

## 4. Rules

| ID | Rule |
|---|---|
| BR-U10-37 | **One session per user start.** `startListening()` checks on-device support (BR-U10-26), then starts **one** segmented session for the resolved locale with the minimum length `segmentedSessionLength`. No new session starts because of a pause, a segment or silence. |
| BR-U10-38 | **Results.** `partial(text)` is an interim `SttResult`; `segment(text)` is a final `SttResult` after trimming; an empty segment after trimming is ignored. A pending interim is not flushed separately: the segment that follows it is its final. |
| BR-U10-39 | **Renewal.** `endOfSession` while the intent is `listening` starts a new session, checked first; this is the only way a session is renewed without an error, so a session renewal chimes at most once per `segmentedSessionLength`. It is a normal end and never counts towards the cap. |
| BR-U10-40 | **Error classes by code.** Silence: 6, 7 (renew as in BR-U10-39, never counted). Lasting: 9 → `permissionRevoked`, 12 → `localeUnsupported`, 13 → `onDeviceModelMissing`, 14 and 15 → `onDeviceModelMissing`; each reported once, then `failed`, as BR-U10-18. Transient: every other code, and an unknown code; counted against the Amendment 01 cap (`++count >= restartCap` within `immediateFailureWindow`, then `restartCapReached`). |
| BR-U10-41 | **Recreate after a dead service (O-3).** Codes 5 and 11 call `recreate()` (destroy and create the recogniser) before the transient retry, so a restarted system service is used rather than a stale binding. |
| BR-U10-42 | **Stop, pause, resume.** `stopListening()` and `pause()` set the intent first, then `stop()` the session; `resume()` starts a new checked session. These are user actions, so their sounds are expected. The Amendment 01 epoch rule (BR-U10-19, Step 16a) applies to every await in the engine. |
| BR-U10-43 | **Sound budget (the acceptance rule for the device pass).** Android may sound only on a user Start, Stop, Pause or Resume, on a renewal (BR-U10-39), and on a lasting or cap error; never on a pause in speech, a segment or silence. |

| BR-U10-44 | **Early ends (decision D-4).** A session that ends (`endOfSession`, or a silence code 6 or 7) before 90% of `segmentedSessionLength` with no user action is an **early end**: the recogniser is not honouring segmented mode, so each renewal would chime. Early ends are counted in their own counter, which recognised speech does **not** reset (only a user start does). The early end that reaches `restartCap` (3) reports `restartCapReached` and stops; earlier ones renew. |
| BR-U10-45 | **Renewals wait and retry.** Every renewal (BR-U10-39, 40, 41, 44) waits `restartDelay`, then checks and starts. A renewal whose start is refused or throws is a transient failure: it is counted and retried after `restartDelay` until the cap reports `restartCapReached`. The engine never stops silently. |

Amendment 02's refusal rules apply unchanged: a false, throwing or timed-out check means no session and one `onDeviceModelMissing`.

## 5. Android version floor

Segmented sessions need API 33. Below it the check is false, so the app refuses with the on-device panel; Android 12 and 12L (API 31 and 32) keep no chiming fallback (decision D-1). Before this amendment, the floor was API 31.

## 6. Default language (Q-3, decided 2026-10-26)

Replaces the Phase 1 rule "first supported locale when no explicit selection" (`platform-stt-audio` code summary). The resolution order is:
1. the app's explicit choice;
2. the phone's preferred languages, in order, each an exact match then a language-only match;
3. **en-CA** ("a piece of software built and maintained in Canada by Canadians");
4. otherwise pass en-CA through, so the engine reports `localeNotSupported`.

The rule never picks an arbitrary first supported locale. Matching ignores case and treats `-` and `_` as the same. A language-only tie prefers region CA, then US. While the locale list is still loading, the first device locale is used, else en-CA. `zip_broadcast` reads the same resolver, so its default changes the same way, with no `zip_broadcast` file edited.

## 7. No empty transcripts (Q-2, decided 2026-10-26)

A transcript row is created only when its first segment is saved, so a session with no captioned text leaves no transcript, even if the app is killed mid-session. When transcription is on and a session ends with nothing saved, `RecordingScreen` shows one SnackBar: "No speech was recognised, so no transcript was saved." If the stop also has an error notice (BR-U10-23), the error notice comes first.

## 8. Transcript continuity (Q-4, pre-existing defect)

Returning to recording with the **same** session id, after a resume or the REL-U2.1 recovery, continues the transcript: it keeps the start time, the segment count and the merge state, and creates nothing. Before the fix, it reset the count and duration and re-created the session row.

## 9. Testable properties

| ID | Property |
|---|---|
| TP-21 | Stateful model of `SegmentedSpeechEngine` (fake bridge, `fake_async`): every bridge `start` is preceded by a true check for the same locale; no `start` after `stop()` or `pause()` until the next start or resume; a pause in speech, a segment and silence never cause a `start`; `endOfSession` while listening causes exactly one checked `start`; the cap reports exactly one error. |
| TP-22 | The error codes 1 to 15 and an unknown code map totally to silence, lasting or transient as BR-U10-40, and the kinds map to the existing factories. |
| TP-23 | Segments are delivered once, trimmed, and empty segments never; partials are always interim. |
| TP-24 | Codes 5 and 11 call `recreate()` before the retry, and no other code does. |
| TP-25 | Locale resolution (section 6), including the regression row: supported `[cmn_CN, en_US, …]`, no choice, device `[en-US]`, gives `en_US`. |
| TP-26 | No transcript row without a segment; the outcome is reported to the screen; the notice rules in section 7. |
| TP-27 | Continuity under resume and recovery (section 8). |
| TP-12 (extended) | The log-hygiene test covers `SegmentedSpeechEngine`'s path; the Kotlin side has no log line carrying text (reviewed by grep). |

## 10. Changes to earlier documents

- **Amendment 01:** BR-U10-15 to 21 and TP-11, 14 and 15 now apply to iOS only; BR-U10-43 replaces observation (a) as the Android acceptance rule.
- **Amendment 02:** the Android checker floor rises from API 31 to 33 (section 5); BR-U10-30 and 31 (`ListenFailedException`) are iOS only.
- **The Phase 1 locale rule** is replaced (section 6).
- **NFR Requirements:** add `segmentedSessionLength`; NFR-U10-04's device pass gains the BR-U10-43 sound check, the 60-minute session-length check (D-2) and the renewal check. The Android floor for captioning is API 33 (D-1).

## 11. Compliance

- **Security Baseline:** no new permission. `RECORD_AUDIO` and the `RecognitionService` query exist already. On-device only, as before (`createOnDeviceSpeechRecognizer`, checked before every session). SECURITY-03 is covered by TP-12 extended. No blocking finding.
- **PBT:** TP-21 is stateful (PBT-06); TP-22, 23, 25 and 26 are invariants with generators (PBT-07); there are example pins for each code and for the spike's observed sequence (PBT-10).

## 12. Decisions

| ID | Question | Recommendation | Status |
|---|---|---|---|
| D-1 | Android 12 and 12L (API 31 and 32) cannot run a segmented session. Refuse there (on-device panel), or keep the chiming loop for them? | Refuse: the chime was rejected, and Alpha 1 is internal testers | **decided: refuse below Android 13** (James Petersen, 2026-10-26) |
| D-2 | `segmentedSessionLength`: one renewal chime per session length | 30 minutes, verified at the device pass (only 300 s was tested) | **revised: 5 minutes (300,000 ms)** (James Petersen, 2026-10-26, after the Step 30 QA). The first decision (60 minutes) was rejected by the recogniser: "EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS is too high, ignored", which drops the segmented session. A probe on `ZipCaptions_QA_API_36` (Android 16, Google on-device recogniser) found the maximum is exactly 300,000 ms (300 s accepted twice; 301, 360, 420, 600 and 3,600 s rejected). The device pass re-checks the limit on a physical phone and the word gap at each renewal |
| D-3 | Silent continuous captioning on Android through the segmented session | as specified above | **approved** (James Petersen, 2026-10-26) |
| D-4 | A recogniser that ends sessions early (ignoring segmented mode) would bring back a chime per pause | Count early ends toward the cap of 3, not reset by speech; stop with the notice at the 3rd (BR-U10-44) | **decided** (James Petersen, 2026-10-26, found in the Group G part A review). BR-U10-45 (renewals wait and retry; never stop silently) was added in the same review as a correction, not a new decision |
| Q-2, Q-3, Q-4 | sections 6 to 8 | decided by James Petersen, 2026-10-26 | decided |
