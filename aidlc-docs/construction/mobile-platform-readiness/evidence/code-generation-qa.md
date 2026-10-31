# Unit 10, Step 30: Android emulator QA (Group H tree)

> **Evidence files (2026-10-29, updated 2026-10-30):** only the `.md` reports in this folder are kept (James Petersen's decision). The screenshots, logcat and `simctl` output, crash reports, UI dumps and helper files that these reports cite by name were **not retained**: a temporary copy outside the repository was deleted on 2026-10-30 at James Petersen's instruction. Each report records the facts taken from those files (timestamps, log lines, error codes, what each screenshot showed). A file name in these reports is a record of where a fact came from, not a file you can open.

**Date**: 2026-10-26. **Emulator**: `emulator-5560`, AVD `ZipCaptions_QA_API_36` (confirmed with `adb -s emulator-5560 emu avd name`). **Build**: `packages/zip_captions/build/app/outputs/flutter-apk/app-debug.apk` (21:38, built from the tree after the Group H review fixes). **Runner**: the Group H builder session, acting as QA runner at James Petersen's authorisation. Evidence folder: `evidence/step30-android/`.

**Result: blocked at Step 4. Steps 5 to 10 were not run.** The first captions start after the microphone grant fails in the Android runner, so the on-device panel and the language download were never reached. Nothing was fixed.

## Summary

| Step | Result |
|---|---|
| 1. Setup | PASS |
| 2. Deny once | PASS |
| 3. Deny twice, Open settings | PASS |
| 4. Grant, expect the on-device panel with a download action | FAIL (blocking defect) |
| 5 to 10 | NOT RUN (depend on Step 4) |

## Step 1: Setup, PASS
- Action: confirmed the AVD name; uninstalled and installed the debug APK; checked the permission; launched with `am start -W -n app.zipcaptions.captions/.MainActivity`; confirmed focus; found the Dart VM service URL; forwarded the port; started the log listener.
- Expected: `RECORD_AUDIO: granted=false`; the app in front; Home visible.
- Observed: `android.permission.RECORD_AUDIO: granted=false`; `mCurrentFocus=Window{… app.zipcaptions.captions/app.zipcaptions.captions.MainActivity}`; log `The Dart VM service is listening on http://127.0.0.1:32963/…`. Evidence: `01-home.png`, `vmlog-1.txt`.
- Note: the first launch attempt, with `monkey`, did not bring the app to the front (focus stayed on the launcher). `01-home-or-state.png` is that launcher screen, not Home. The launch was redone with `am start`, as instructed.

## Step 2: Deny once, PASS
- Action: tapped Start Captioning (21:46:55); tapped "Don't allow" (21:47:13).
- Expected: the system prompt "Allow Zip Captions to record audio?" with no app explainer first; then "Microphone access needed" with Try again and Back, no Open settings; exactly one "Microphone permission denied" in the app log.
- Observed: the system prompt appeared directly (`02-permission-prompt-1.png`); no explainer. Panel title "Microphone access needed", body "Zip Captions needs microphone access to caption speech.", buttons Try again and Back, no Open settings (`03-panel-denied-once.png`). `vmlog-1.txt` has one line `[zip_core.SttSessionManager] Microphone permission denied`, then `[zip_core.RecordingStateNotifier] Session initialization failed`.

## Step 3: Deny twice, PASS
- Action: tapped Try again (21:47:31); tapped "Don't allow" (21:47:44); tapped Open settings (21:48:06); pressed Back.
- Expected: the prompt again; then "Microphone access is blocked" with Open settings; Open settings opens Zip Captions' App info page; Back returns to the app.
- Observed: the second prompt appeared (`04-permission-prompt-2.png`); its deny button's resource id was `permission_deny_and_dont_ask_again_button`. The panel then read "Microphone access is blocked" with Try again, Open settings and Back (`05-panel-blocked.png`). Open settings opened App info for Zip Captions, "Permissions: No permissions granted" (`06-app-info.png`). After Back, focus was on the app's `MainActivity` (`07-back-in-app.png`).

## Step 4: Grant, FAIL (blocking)
- Action: uninstalled and reinstalled the app (`granted=false` confirmed); launched; found a new VM service URL; started `vmlog-2.txt`; tapped Start Captioning (21:49:38); tapped "While using the app" (21:49:52).
- Expected: the on-device panel with a download action such as "Download English (United States)".
- Observed: the panel "Captioning couldn't start", body "The speech recognition engine failed to start listening.", with Try again and Back only (`08-on-device-panel.png`). No download action and no on-device panel.
- App log (`vmlog-2.txt`): `Engine platform initialized for locale en-US`; `On-device support check: true`; `[zip_captions.MethodChannelSegmentedRecognizerBridge] Segmented start refused by the platform`; `Segmented session refused`; `Engine platform failed to start listening`; `Stop error: PlatformException`.
- Cause, from logcat (`09-logcat-start-failure.txt`): the Android runner logs `ZipCaptionsSegmented: segmented session started` and then throws at the reply: `E/MethodChannel#app.zipcaptions/segmented_speech: java.lang.IllegalArgumentException: Unsupported value: 'kotlin.Unit' of type 'class kotlin.Unit'` at `MainActivity.start(MainActivity.kt:385)`, which calls `result.success(Unit)`. The Flutter standard codec cannot encode `kotlin.Unit`, so Dart receives a `PlatformException`, and `start` answers false. The same `result.success(Unit)` is at `MainActivity.kt` lines 75, 80, 87 and 91 (`stop`, `cancel`, `recreate`, `dispose`); the second logged exception is `MainActivity.kt:75`, the `stop` reply. This is existing Group G runner code, not Group H.
- Consequence: every captions start on Android currently fails on this build, with `engineStartFailed` and not the on-device refusal. The language-pack status check never runs, because the panel offers it only for the on-device refusal. The download flow (Step 5) could not be reached through the app. Per the QA rules, nothing was bypassed with `adb`, and nothing was fixed.
- SnackBar and toast: no SnackBar was visible in the screenshot taken 4 s after the tap. I did not take a burst for this step.

## Steps 5 to 10: NOT RUN
They need a captions session that starts (download, captions, stop, pause and resume, empty session). They are blocked by the Step 4 defect.

## James's answers
None recorded: no ASK JAMES point was reached.

## Unexpected
- The Step 4 defect above. Group G's channel tests (Dart, mocked) cannot catch it, because the mocked channel never runs the Kotlin reply codec. The debug build compiles. Only a real device run shows it.
- The emulator is left with the app installed and the microphone permission granted ("While using the app"), on the "Captioning couldn't start" panel. The VM log listener `vmlog-2.txt` may still be running in the background of the runner session.

## Evidence folder
`01-home-or-state.png` (launcher, failed `monkey` launch), `01-home.png`, `02-permission-prompt-1.png`, `03-panel-denied-once.png`, `04-permission-prompt-2.png`, `05-panel-blocked.png`, `06-app-info.png`, `07-back-in-app.png`, `08-on-device-panel.png` (shows the "Captioning couldn't start" panel, not the on-device panel), `09-logcat-start-failure.txt`, `vmlog-1.txt`, `vmlog-2.txt`.

---

# Rerun from Step 4 (21:53 build)

**Build**: `app-debug.apk` dated 2026-10-26 21:53:52, after the `kotlin.Unit` and locale-level check fixes. Fresh install (`granted=false` confirmed), launched with `am start -W`, focus confirmed, VM log listener `vmlog-3.txt`. The AVD name was confirmed again as `ZipCaptions_QA_API_36`. **Result: Steps 4 and 5 PASS. Step 6 FAIL (blocking). Steps 7 to 10 not run.**

| Step | Result |
|---|---|
| 4. Grant, on-device panel with a download action | PASS |
| 5. Download | PASS |
| 6. Captions | FAIL |
| 7 to 10 | NOT RUN |

## Step 4 (rerun): PASS
- Action: Start Captioning (21:56:25), then "While using the app" (21:56:32).
- Observed: the on-device panel "On-device captions aren't available" with "Download English (United States)", Try again and Back, no Open settings (`10-rerun-on-device-panel.png`). App log: `On-device support check: false`, `Reporting engine error: onDeviceModelMissing`. Logcat: `on-device check: en-US false`, then `language pack status: en-US downloadable`. Locale `en-US` ("Engine platform initialized for locale en-US"). No "Captioning couldn't start", no History, and no SnackBar in the screenshot taken 4 s after the tap (no burst taken for this step).

## Step 5: Download, PASS
- Action: tapped the Download button (21:56:51).
- Observed:
  - Logcat: `language pack download requested: en-US`; two status re-checks at 5 s intervals (`downloadable`), as expected before any event.
  - Android raised its own approval activity, `com.google.android.as … speech.modelmanager.languagepack.ui.DownloadActivity`: "Download English (US) update. Download this update (62.06 MB) to use speech recognition offline", with Cancel and Download (`11-download-1s.png`). I tapped Download (21:57:04), a system dialog the app raised.
  - Panel: "Downloading English (United States)… 37%" with a progress bar (`12-after-approve-2s.png`). Logcat: `language pack progress 0, 18, 37, 57, 75, 96, 100`, then `language pack download done: en-US` at 21:57:10.968.
  - Panel: "English (United States) is ready. Tap Try again to start captioning." with Try again and Back (`13-download-ready.png`). The app did not start captioning by itself.
- No "will download later" state occurred, so no ASK JAMES about waiting longer.

## Step 6: Captions, FAIL
- Action: `logcat -c`; tapped Try again (21:57:27.655); ready signal in logcat at 21:57:27.494 (`onMicrophoneOpened`) and 21:57:27.561 (`Starting to push audio`); phrase 1 spoken 21:57:41.933 to 21:57:47.951; phrase 2 spoken 21:58:00.668 to 21:58:05.331.
- Timing note: each tool call adds delay, so phrase 1 began about 14 s after the tap, not 1.5 s after the ready signal. The recogniser was listening throughout (see the renewals below); this does not explain the result.
- Expected: recognised text on screen; segmentCount > 0; en-US; no SnackBar or toast; no engine error; no extra "Segmented session started" during 20 s of silence.
- Observed:
  - **No recognised text** on the captions screen at any point (`14-captions.png`: empty caption area with pause and stop controls). Then the app left the screen for History, "No transcripts yet" (`15-captions-later.png`).
  - Recogniser (logcat): speech start was detected (`#onStartOfSpeech` at 21:57:44.4, about 2.5 s after phrase 1 began; also at 21:58:01.5 and others), and each speech burst ended with `#handleFinalResult: 1 hyp` followed by `agsa_transcription_NO_SPEECH_DETECTED code -1`. No `onSegmentResults` or partial result reached the app.
  - App (`vmlog-3.txt`, lines 15 to 69): session started for `en-US`, `lengthMs=3600000`; then repeated `Silence code 7, renewing` / `Segment session ended, renewing`; `Early-end cap reached`; `Reporting engine error: restartCapReached`; `Engine error — attempting restart`; `Transient engine error (code 5)`, `Recogniser recreated`, `Engine restart succeeded`; more silence-code renewals; a second `Early-end cap reached` and `restartCapReached`; `Engine error after restart attempt — stopping`; `Session stopped`; then `TranscriptWriterTarget: finalizeCurrentSession: … skipped, no row`. So there was no finalize line with a segment count, and no transcript was saved. The session ended by itself at about 21:58:22, 55 s after the tap.
  - No `Toast` in logcat (count 0). I did not take a SnackBar screenshot burst when the session ended, so whether the error notice appeared is not recorded.
  - `dumpsys window`: no `KEEP_SCREEN_ON` flag and no `mHoldingScreenWindow` entry in the output, taken after the session had ended.
- James Petersen's answer (verbatim): "I heard a few chimes between the spoken words, I did not see any text appear on the emulator screen".
- Result: FAIL. Silence code 7 (`NO_SPEECH_DETECTED`) renewals consume the early-end budget (BR-U10-44) quickly, even with speech detected in between; after two cap rounds the engine stops the session. The recogniser returned an empty hypothesis for the played speech, so no segment was delivered. The chimes James heard match the repeated session renewals. The 20 s silence check was not run, but the renewals during silence are already visible in the log.

## Steps 7 to 10: NOT RUN
Stop, pause and resume, the empty session and the final History screenshot depend on a captions session that stays up and recognises speech. Step 9 (empty session) would also hit the early-end cap on the same renewals, so I did not run it independently.

## Evidence added (rerun)
`10-rerun-on-device-panel.png`, `11-download-1s.png`, `12-after-approve-2s.png`, `13-download-ready.png`, `14-captions.png`, `15-captions-later.png`, `vmlog-3.txt`.

## Unexpected (rerun)
- The language download flow works end to end through the app, including Android's own approval activity and percent progress.
- The captions failure is in recognition and renewal behaviour, not in the language pack. Open questions for the reviewer: why the on-device recogniser returns an empty hypothesis (`1 hyp` then `NO_SPEECH_DETECTED`) for speech it detected; and whether silence code 7 should count against the early-end budget when speech was detected in the same session.
- The emulator is left on History with the app running and the en-US pack installed.

---

# Segmented session length probe

**Question**: what is the largest `EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS` that Android's on-device recogniser accepts with `EXTRA_SEGMENTED_SESSION`? **Why**: in the Step 6 failure the recogniser logged "EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS is too high, ignored" and "… ignoring EXTRA_SEGMENTED_SESSION" for the product's 3,600,000 ms (decision D-2).

**Setup**: AVD `ZipCaptions_QA_API_36` on `emulator-5560` (SDK 36, `onDeviceAvailable=true`). The throwaway spike app `dev.spike.segspike` only, never the product (`app.zipcaptions.captions` was force-stopped first). The spike app was given `RECORD_AUDIO` with `pm grant` for that package only, as authorised, and uninstalled afterwards. The spike sends N × 1000 as an `Int`. Each probe: force-stop the spike, `logcat -c`, `am start -W … --ei seconds N --ez segmented true`, then `sleep 4` and `grep -E "SEGSPIKE|MINIMUM_LENGTH|SEGMENTED"`. A probe is REJECTED if "too high" or "ignoring EXTRA_SEGMENTED_SESSION" appears; ACCEPTED if neither appears and `onReadyForSpeech` appears. No speech was played by the runner. Raw output: `evidence/step30-android/16-length-probe.txt`.

| N (s) | Length (ms) | Verdict | Deciding log line |
|---|---|---|---|
| 300 | 300000 | ACCEPTED (run 1) | no rejection line; `SEGSPIKE: onReadyForSpeech`, then `onSegmentResults` |
| 3600 | 3600000 | REJECTED | `RecognitionServiceInten: EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS is too high, ignored` and `… not set with positive value; ignoring EXTRA_SEGMENTED_SESSION` |
| 600 | 600000 | REJECTED | same two lines |
| 420 | 420000 | REJECTED | same two lines |
| 360 | 360000 | REJECTED (run 1) | same two lines |
| 301 | 301000 | REJECTED | same two lines |
| 300 | 300000 | ACCEPTED (run 2, confirmation) | no rejection line; `onReadyForSpeech`, `onSegmentResults` |
| 360 | 360000 | REJECTED (run 2, confirmation) | same two lines |

**Maximum accepted: 300 s (300,000 ms).** 301 s is already rejected, so the limit is at 300,000 ms, not between the 60 s steps. The 300 s value was accepted twice and the value 60 s above it (360 s) was rejected twice. The two rejection lines come from tag `RecognitionServiceInten` and are logged by the recogniser service, about 0.8 s after `startListening`.

**Not probed**: 900, 1200, 1800 and 2700 s. Every length from 301 s up that was tried (301, 360, 420, 600, 3600) was rejected, and the brief's bisect step only needed the boundary between the largest accepted and the smallest rejected value, so I did not spend further probes above 600 s.

**Notes**
- In both ACCEPTED runs the spike showed `onBeginningOfSpeech`, `onEndOfSpeech` and `onSegmentResults` within about 3 s of the start, with no speech played by the runner (ambient sound in the room or the Mac microphone). This shows segmented results arriving normally in an accepted run.
- No code or constant was changed. The new D-2 value is for the reviewer and James Petersen to decide.
- Clean-up: the spike app was uninstalled (`Success`). The product app is left installed.

## Step 30 rerun, 2026-10-27

Evidence folder: `evidence/step30-rerun/`. Build under test: the Group I build (`app-debug.apk`, Group I gate 2026-10-27). Emulator `emulator-5560`, AVD `ZipCaptions_QA_API_36` (checked with `adb -s emulator-5560 emu avd name`). The brief's `vmlog.py` path carried a typo in the session id; the script was found at `.../d9722121-558e-4fdf-82a0-aedad3639cef/scratchpad/tools/vmlog.py` and read before use (read-only Dart-log streamer).

**Step 0, preparation: DONE.** The old emulator (qemu pid 61197, started 8:25 PM the day before) was still running after James closed the window, so the first cold-start was refused ("same AVD"). With James's instruction ("kill the process yourself") I verified pid 61197's command line (`-avd ZipCaptions_QA_API_36 -port 5560`) and killed only it; emulator-5554 was untouched. I then started `emulator -avd ZipCaptions_QA_API_36 -port 5560 -allow-host-audio`; `sys.boot_completed` = 1. James turned on "Virtual microphone uses host audio input" and confirmed ("It's on"). Uninstall, install, launch (`mCurrentFocus` = app.zipcaptions.captions), VM-service listener on port 36233 (`vmlog-1.txt`). Start Captioning produced the system dialog "Allow Zip Captions to record audio?"; tapped "While using the app" (coordinates from the uiautomator dump); captioning started directly with no language-pack panel (`01-home.png`, `02-after-permission.png`).

**Step 6, captions: FAIL (environment, blocked), 2 attempts.**
- Attempt 1. Start tapped 12:23:50 (permission accepted 12:23:59); `SodaAudioPusher: Starting to push audio to Soda` at 12:23:59.361; app log: `On-device support check: true`, `Segmented session started for en-US, lengthMs=300000`, `Session started`. Phrase 1 said 12:24:11.6 to 12:24:17.6, phrase 2 12:24:25.6 to 12:24:30.3. Screenshot `03-captions.png` (12:27): the screen is empty, no recognised words. The audio HAL logged `pcm_readi failed with 'cannot read/write stream data: I/O error'` and `pcm_readi was late delivering frames, inserting 16000 us of silence` from 12:24:02.280, before the first phrase (1,967 I/O-error lines in `04-logcat-step6.txt`).
- Attempt 2 (after Stop, with James's agreement). `logcat -c`, Start 12:29:06.056, Soda push at 12:29:06.301. Phrase 1 12:29:13.0 to 12:29:18.7, phrase 2 12:29:26.8 to 12:29:31.5. `06-captions-retry.png` (12:29): empty. I/O errors again from 12:29:09.254, before the speech (262 lines in `07-logcat-step6-retry.txt`).
- Cause: the emulator's host-audio input starved again (same signature as `evidence/no-captions-debug.md`), not app code. No engine error in the app log. No captions result counts, so 6, 6b and 8 could not be judged.
- Other checks in the same runs: `grep -cE "too high|ignoring EXTRA_SEGMENTED_SESSION"` = 0 (PASS, recogniser accepted the 300 s length); `dumpsys window windows | grep -c KEEP_SCREEN_ON` = 1 while captioning (PASS) and 0 after Stop (PASS for the clearing half of Step 7).
- James, attempt 1, asked "How many sounds did you hear since tapping Start, and when?": "I don't know when you tapped start, but I heard the sample spoken audio, but never heard any chime". (Expected: none between the phrases: PASS for no chime between phrases; the spoken samples were the `say` output.)
- James, on Stop (attempt 1), mid-run: "when you hit stop, I heard the chime but it sounded like both the start and stop chimes may have sounded at the same time". Not matching BR-U10-43's expectation of a single stop sound; recorded as an observation to re-check once captions work, for the sound-at-Stop check. James also asked "am i supposed to hear a chime before the speaking starts?" (answer given: no start chime is expected from this design).

**Step 7, Stop, partly: Stop on a session with no recognised speech (both attempts) behaved as the empty-session path.** Tap Stop at 12:28:18.972; `05-stop-burst-01..08.png`: the SnackBar "No speech was recognised, so no transcript was saved." is visible (`05-stop-burst-03.png`) on History, which shows "No transcripts yet". App log: `Segmented session stopped`, `Session stopped`, `finalizeCurrentSession ... skipped, no row`. This is the Step 9(a)-style result, but with a 4-minute (not 10-second) silence and not a deliberate silent test. Stop 2: tap 12:29:45.368, `08-stop2-burst-01..12.png`, same log lines, KEEP_SCREEN_ON = 0 after. The Step 7 criteria (a new transcript and `segmentCount` > 0) cannot be met without captions: **FAIL (blocked by Step 6)**.

**Continuation (James chose "Run silent 9(a)+9(b)" after the Step 6 failure).**

**Step 9(a), silent 10 s then Stop: INVALID (not silent).** Start 12:34:29.8, Stop tap 12:34:41.2 did not take effect (the session kept recording; screenshots `10-9a-stop-burst-*.png`, `09-9a-silent.png`). By about 12:35 the on-screen caption read "It's not actually showing me that it's" (`11-before-stop.png`): the Mac microphone had picked up James talking, so the run was not silent. A second Stop tap at 12:35:19.8 (`12-stop-burst-*.png`) stopped it: app log `finalizeCurrentSession ... durationMs=33974 segmentCount=1`; History shows one transcript, "0m 33s · 1 segments" (`12-stop-burst-03.png`); no SnackBar in the burst; KEEP_SCREEN_ON = 0. This shows recognition, locale `en-US` (`Segmented session started for en-US`), a saved transcript and `segmentCount` > 0 working when real speech reaches the recogniser, but it is **not** a Step 6 or Step 7 pass (words were not the protocol phrases; the first Stop tap failing to register is unexplained and unrepeated). During this run the I/O-error count rose only to 333 and did not grow afterwards.

**Step 6, attempt 3 (clean run, James told to stay quiet): FAIL (environment).** Start 12:45:40.9 (`logcat -c` first; Soda push at 12:45:42.0), phrases said 12:50:02.2 to 12:50:07.9 and 12:50:15.96 to 12:50:20.7 (the tool call carrying them ran ~4 minutes after the tap, which is why the phrases came late in the session). `pcm_readi ... I/O error` from 12:45:44.201 continuously (2,705 lines by 12:50:32). Screenshot `13-step6-captions.png`: no words. App log (`vmlog-2.txt`): no results, no engine error. James's instruction ("repeat when captions fail: stop, start a second session, replay the same audio") was applied from attempt 2 on; attempts 1 and 2 (stop then start, same phrases) both failed the same way, and attempt 3 failed too. Conclusion so far: with the host-audio input starved the failure is consistent across stop-then-start; it recovered by itself only in the session where James was speaking into the Mac microphone.

**Amendment 05, accidental run inside Step 6 attempt 3: PASS.** Session started 12:45:41; the app log shows `Session stopping: inactivity after 300s without speech`, then `Segmented session stopped`, `Session stopped`, `finalizeCurrentSession ... skipped, no row`, `session stopped`; the screen went to History and showed the SnackBar "Captioning stopped after 5 minutes without speech." (`14-state.png`); KEEP_SCREEN_ON = 0 (`15-late-burst-*.png`; the queued second notice was missed because that capture was late).

**Step 9(b), Amendment 05 silent 5-minute stop: PASS.** Driver `silent9b.py` (scratchpad, only the allowed `adb -s emulator-5560` commands: tap, screencap, `dumpsys window windows`, `logcat -c`), output `16-9b-driver.txt`. Start tapped 12:51:47.252, James silent. Screenshots every ~1.4 s from t = 290.9 s. KEEP_SCREEN_ON = 1 until t = 299.4 s and 0 from t = 300.9 s (host 12:56:48). App log (`vmlog-2.txt`): `Session stopping: inactivity after 300s without speech`, `Session stopped`, `finalizeCurrentSession ... skipped, no row`. Screens: `16-9b-09-t302s.png` shows the SnackBar "Captioning stopped after 5 minutes without speech." on History; `16-9b-13-t307s.png` shows "No speech was recognised, so no transcript was saved." (the notices are in the required order); no new transcript in History (still the single earlier 33 s transcript); no other SnackBar or toast in the 17 frames; no engine error in the app log.

**Steps 6b, 8, 10: NOT RUN** (6, 6b and 8 need working audio; 10 is a History screenshot, partly covered by `12-stop-burst-03.png` and `16-9b-*.png`).

**Part 3 (iOS Simulator): NOT RUN.** Asked after the Android results, James answered "Stop here". The Simulator was never booted; assumption A-1 is not reachable from this session.

## Step 30 rerun with injectAudio, 2026-10-27

Evidence folder: `evidence/step30-rerun-inject/`. Tool: scratchpad venv (`grpcio`, `grpcio-tools`), stubs generated from the SDK's `emulator_controller.proto`, `inject.py` (copy in `tool/inject.py`): one `injectAudio` stream, 16 kHz mono S16, `MODE_UNSPECIFIED`, 20 ms packets, self-paced; silence until a trigger file; a script of WAV phrases and silences; host timestamps at each phrase; `--open-file` delays opening the stream. The emulator was started on port 5560 with `-grpc 8560` (no JWT, so no token exists) and `getMicrophoneState` gave `realAudioEnabled=False`. James approved the gRPC work, the emulator restarts and the corrected retry in this session.

**Finding 1: injectAudio before any guest microphone crashes the emulator.** Two runs, both with the stream opened while the app was on Home and no capture open: (a) no `-allow-host-audio`, (b) with `-allow-host-audio` and the mic switched off through gRPC. Each ended with exit 139 about 0.25 s after the stream opened (`inject-C.txt`: `stream open 15:41:06.862`, reset 15:41:07.116; second run `stream open 15:49:24.932`, reset 15:49:25.189). Crash reports `crash-1-154133.ips` and `crash-2-154926.ips`: `EXC_BAD_ACCESS` / SIGSEGV at `0x58`; top frames `audio_forwarder_enable`, `QemuAudioInputEngine::start`, `QemuAudioInputStream::QemuAudioInputStream`, `EmulatorControllerImpl::injectAudio`. Emulator logs: `emulator-run3-*.log`, `emulator-run4-*.log`. The first relaunch (run 2) restored the quick-boot snapshot, so it was killed and replaced by a `-no-snapshot` cold boot.

**Finding 2 (corrected order): with Start tapped and the microphone open first, the stream opened without a crash.** Run 5, cold boot, `-grpc 8560 -no-snapshot`, no `-allow-host-audio`: Start tapped 15:58:43.190 (touch sounds on); `RecognitionService#onMicrophoneOpened` 15:58:43.665; `injectAudio` opened 15:59:06.847 (`inject-C2.txt`); the emulator stayed up (1 process). Phrases: p1 15:59:06.8 to 15:59:11.7, p2 15:59:19.7 to 15:59:23.7, p3 15:59:31.7 to 15:59:35.3.

**Part C result: FAIL, input died before the injection started.** `logcat-c2.txt`: `threadLoop: entering standby, frames: 149056` and `~TinyalsaSink: stopping PCM stream` at 15:58:46.457 (2.8 s after the Start tap); the first `pcm_readi ... I/O error` at 15:58:46.619, 0.16 s later; 2,855 I/O-error lines in total. So the guest input was already dead 20 s before the stream was opened (the gap is the tool-call latency between seeing `onMicrophoneOpened` and creating the open file). No captions appeared (UI dump and `c-01-after-p1.png`: no caption text), no SnackBar, no engine error. The app log (`vmlog-3.txt`) shows the session ran with no result and then `Session stopping: inactivity after 300s without speech` (16:03:43, 300 s after the 15:58:43 start; a second, unplanned confirmation of Amendment 05). The standby and I/O-error pattern is the same as in the three earlier failed runs, and it appears without any injected or host audio. It does not show whether a stream opened within the 2.8 s before standby would survive; that was not tried.

**Part D: NOT RUN** (Part C did not pass). Steps 6, 6b, 7, 8 and 9(a) with injection remain open; 9(b) and the Amendment 05 stop were already passed above.

**Phrase-word grep (outstanding item): clean.** `grep -ciE 'quick|brown|fox|lazy|dog|second sentence|pause of several|third sentence|captions continue|testing zip|emulator\.'` over `step30-rerun-inject/vmlog-1.txt`, `-2`, `-3` (and `step30-rerun/vmlog-1.txt`, `-2`): 0 matches in each. `vmlog-4.txt` (the next run) was checked by reading its tail: no phrase text.

**Part C, repeated with one driver script (`drive.py`, run once, output `drive-C3.txt`, files in `c3/`): FAIL, the input still dies after standby with the stream already open.** Fresh cold boot (`-grpc 8560 -no-snapshot`, no `-allow-host-audio`, `realAudioEnabled=False`, AVD `ZipCaptions_QA_API_36`). One process: gRPC channel connected first; `adb logcat -c`; tap Start (touch sounds on) 16:09:00.177; poll `logcat -d`; `onMicrophoneOpened` seen 16:09:00.755 (+0.58 s; logcat time 16:09:00.439); `injectAudio` opened at once, first packet 16:09:00.760; the emulator did not crash. Phrases: p1 16:09:00.76 to 05.58, p2 13.58 to 17.60, p3 25.60 to 29.18; stream closed 16:09:35; Stop tapped 16:09:40.422.
- `drive-logcat.txt`: output `entering standby` 16:09:03.215 and `~TinyalsaSink: stopping PCM stream` 03.232 (2.8 s after the tap, while the stream was open and phrase 1 was playing); first `pcm_readi ... I/O error` 16:09:03.381, 0.17 s later, then one every ~100 ms until 16:09:40.353 (356 lines).
- Screen before Stop (`c3/drive-before-stop.png`, UI dump `drive-ui-before-stop.xml`): "Sting zip captions on the emulator the quick brown" and nothing else. That is the part of phrase 1 that was spoken before the input failed (3 s into a 5 s phrase); phrases 2 and 3 never appeared.
- History (`c3/drive-stop-burst-03.png`): new transcript "0m 39s · 1 segments"; log `finalizeCurrentSession ... durationMs=39859 segmentCount=1` (vmlog-4). So `segmentCount` is 1, not at least 2. No SnackBar in the burst. Locale en-US (`Segmented session started for en-US`). No engine error.
- Verdict: the recogniser received injected audio until the standby and nothing after. This is the emulator's audio HAL, not app code, and the injector cannot work around it: injected audio is lost at the same moment as host audio. Steps 6, 6b, 7 and 8 (and the chime re-check) go to the physical-device pass; 9(b) and the Amendment 05 stop are already passed on the emulator.

## Step 30 iOS, 2026-10-27

Evidence folder: `evidence/step30-ios/` (first run, defect Q-7) and `evidence/step30-ios/rerun/` (after the fix). Device: iPhone 17 Simulator `3A0EDA8C-BAAF-47A6-A213-E29485B92547`, iOS 26.0. James Petersen did every tap. The Android emulator and `adb` were not touched. Recognised text never reached the app log: the phrase-word grep over `step30-ios/vmlog-1.txt` and `rerun/vmlog-1.txt`, `-2`, `-3` (`grep -ciE 'testing|zip captions on|simulator|quick|brown|fox|lazy|dog|second sentence|pause of several|several seconds|spoken after'`) gave 0 matches in each, and 0 over `rerun/syslog-speech-audio.txt`.

**Step 1, build and setup (first run): PASS.** `flutter build ios --simulator --debug`: `Xcode build done. 12.4s`, `✓ Built build/ios/iphonesimulator/Runner.app`. Booted, `privacy reset all`, uninstalled, installed. VM service from the Simulator log (`Dart VM service is listening on http://127.0.0.1:55629/…`, because `--console-pty` printed nothing) and `vmlog.py` (read before use) started.

**Step 2 (first run): FAIL, defect Q-7.** Start tap, then `01-home.png`, `02-after-start-tap.png`: the explainer appeared first (PASS for that part). Continue was tapped at about 16:30:20. No microphone or speech prompt appeared. `03-after-continue.png` shows scripted text ("Hello and welcome to Zip Captions.", "This is a scripted caption for UI review."). `vmlog-1.txt`: `Engine fake initialized for locale en-CA`, `Engine fake listening`, then `saveSegment (new)` lines with nobody speaking. The dev fake was running on iOS. Cause: `bootstrap.dart` passed `defaultTargetPlatform.name` (`'iOS'`) to `registerSttEngines`, which compared it with `'ios'` (`stt_engine_registration.dart`), so iOS debug builds used the fake and iOS release builds registered nothing. Steps 3 to 5 and 7 of the first run were blocked. The fix and its tests are recorded in the audit entry "Q-7 iOS engine registration fix" (zip_captions 402 passed, gates green).

### Step 30 iOS rerun after Q-7

Build under test: the fixed tree (`flutter build ios --simulator --debug` succeeded again after the fix; `flutter build apk --debug` too). Reset (`privacy reset all`), uninstall, install, launch; VM service `http://127.0.0.1:58615/…`, `rerun/vmlog-1.txt`.

| Step | Action | Expected | Observed | Result |
|---|---|---|---|---|
| 2 | Start, then Continue, then Allow, then Allow | Explainer first; microphone prompt, speech prompt | `rerun/02-explainer.png` (16:51:35), `rerun/03-mic-prompt.png` (16:51:54), `rerun/04-speech-prompt.png` (16:52:13). Log: `Platform STT initialized: true`, `Engine platform initialized for locale en-CA`, `On-device support check: true`, `Listening started for locale en-CA`, `Engine platform listening`. No `Engine fake`. | PASS (Q-7 fixed) |
| 3, A | Captions run: phrase 1 16:52:43.6 to 16:52:52.1, phrase 2 16:53:14.9 to 16:53:19.7 | Words on screen, `segmentCount` > 0, en-US, no toast | `rerun/05-captioning-started.png`, `rerun/06-after-phrase1.png`, `rerun/07-after-phrase2.png`: recording controls shown and an empty caption area after both phrases. App log: no result and no engine error. Stop (tapped about 16:53:59, several taps needed per James): `Listening stopped`, `Session stopped`, `finalizeCurrentSession … skipped, no row`. History empty (`rerun/08-stop-burst-01.png`). The burst ran about 85 s after Stop (tool latency), so the notice was missed in this run. System log (`rerun/syslog-speech-audio.txt`): AVAudioEngine and AURemoteIO started and stopped normally, no error. Locale was `en-CA`, which is the Q-3 default (Amendment 03 section 6, region CA preferred); the brief said en-US. | FAIL (no recognised text; cause not established) |
| 3 | Sounds | None from the app on iOS | James: "I saw no text appear, but I heard the speech"; then "I heard speech, no chimes, no other sounds." | PASS (no chime) |
| 4 | Outcome B, language panel | Only if the panel appears | The panel did not appear (on-device support check true). A-1 was not reachable. | NOT REACHED |
| 5 | (a) continuous, (b) pause and resume, (c) silent 10 s, (d) Amendment 05 | Only if captioning works | NOT RUN: step 3 produced no recognised text. (Amendment 05 and the empty-session notice were already passed on Android.) | NOT RUN |
| 3 (empty Stop) | Second session, `rerun/stop2/`: Allow, Allow, silent, Stop with a 4 frames/s capture running (`stop2/times.txt`) | The notice "No speech was recognised, so no transcript was saved." | `stop2/f-15` to `f-22` (17:11:03.5 to 17:11:07.0): the SnackBar on History; `f-17.png` shows the text; no other toast; log `finalizeCurrentSession … skipped, no row` (`rerun/vmlog-2.txt`). James: "I saw the toast about no captions were recorded". | PASS |
| 7 | `privacy reset all`, relaunch, Start | Both system prompts again | The explainer did not appear (its seen-flag `onboarding.speechExplainerSeen` is in the app's preferences, which `privacy reset` does not clear; by design in `speech_explainer_gate.dart`). `rerun/10-start-no-explainer.png` (17:09): the microphone prompt. After Allow: `rerun/11-second-speech-prompt.png` (17:10): the speech prompt. James: "I clicked start captioning, there's no "not now" just a microphone prompt", then "yes, speech recognition prompt appeared again". | PASS (both prompts return; explainer once only, by design) |
| 6 | Uninstall and reinstall (clears the flag), Start, Not now | Home, no system prompt | `rerun/12-fresh-install-home.png`, `rerun/13-after-not-now.png`: Home, no prompt; `rerun/vmlog-3.txt` has only `Target added: on_screen`. James: "done, it took me back to the home screen". | PASS |
| 8 | History and shutdown | History screenshot; Simulator shut down | History: `rerun/stop2/f-30.png` ("No transcripts yet"). The Simulator was shut down (`xcrun simctl list devices` shows `Shutdown`). A separate History tap was not requested after the Not now run. | PASS |

**Open finding (not a code defect proven): no recognised text on the Simulator.** With the real engine registered, the on-device check true, the session listening and speech audible on the Mac, neither phrase produced a result or an error. The Android emulator showed an input failure at this point, which was an emulator fault; for the Simulator no error was logged, so whether the Mac microphone reaches the Simulator, or the recogniser returns nothing, is unknown. It needs a Simulator input check by James (I/O menu, input device) or the physical-device pass. Steps 3 to 5 and the A-1 assumption remain open.

## Physical Android device pass, 2026-10-30

**Device**: Pixel 6 (`25071FDF600953`), Android 17 (API 37), stock Google build `CP3A.261005.002.A1`. Default recognition service: Speech Services by Google (`com.google.android.tts`). Phone language en-CA. James Petersen cleared the phone for this session.

**Build**: `feature/mobile-platform-readiness` at `a437719`, debug, `flutter run -d 25071FDF600953` from a QA worktree. The app was freshly installed and the microphone was not granted beforehand.

**Method**: Opus drove the app through its own screens with `adb input` taps. James Petersen authorised adb for driving and observing, and was present to report sounds.
- **App state and the Dart log:** the Flutter MCP (`flutter-agent-lens`).
- **Native timestamps:** `adb logcat -s ZipCaptionsSegmented`.
- **Keep-screen-on and screen state:** `dumpsys window` and `dumpsys power`.
- **Speech:** a YouTube video playing near the phone, then macOS `say` from the host speakers.

The screenshots were not retained (see the note at the top). The table below records what each one showed.

**Result: every Android check passes. The session found one design change request and four observations.**

| Step | Result | Evidence |
|---|---|---|
| B0 Permission and start | PASS | System prompt with no explainer. "Engine platform initialized for locale en-CA", "On-device support check: true", "Segmented session started for en-CA, lengthMs=300000". No panel, no toast |
| B1 Step 6, captions | PASS | Recognised text from the video on screen, segments saved (`createSession`, then `saveSegment`), en-CA, no toast. The app log carries IDs only, never recognised text (SECURITY-03) |
| B2 Step 6b, silence between phrases | PASS | Three `say` phrases with 8 s and 20 s silences, all captioned correctly. No session end or restart in the native log during the silences |
| B3 Sounds (BR-U10-43) | PASS | James heard sounds only at Start, Pause, Resume, Stop and renewal. Volumes set to maximum through Settings first (see observation 3) |
| B4 Step 7, Stop | PASS | History opens ("9m 33s · 21 segments"). `KEEP_SCREEN_ON` set while captioning, cleared after Stop |
| B5 Stop sound, ×3 | PASS | One sound at Stop in runs 1 and 3. Run 2 was "I think one" (James was not listening closely) |
| B6 Step 8, Pause and Resume | PASS | One sound on each. Captions continue, and "session continued" logs the same transcript session |
| B7 Amendment 06, last phrase (BR-U10-55/56) | PASS | Stop straight after speech, ×3: the phrase arrives during the drain after "Segmented session stopped", is saved, and then `finalizeSession` runs. Pause straight after speech, ×1: "Paused (via stop)", then `saveSegment`, then "Session paused"; the phrase stays on screen above the "paused" marker |
| B8 Quick Pause and Resume, ×3 | PASS | Three clean pairs in the log. Six sounds, one per tap, nothing extra |
| B9 Renewal (D-2) | PASS | Session 10:50:45.255 to 10:55:45.574 (300.3 s), then a new session 0.34 s later, with one chime. Second run with twelve numbered `say` sentences: due at 11:10:26, ended at 11:10:43.088 after the speech finished. All twelve sentences captioned with no gap (see observation 1) |
| B10 Screen on | PASS | Screen timeout set to 30 s for the test, then restored to 30 minutes. `mWakefulness=Awake` more than 5 minutes after the last touch while captioning, then `Dozing` about 45 s after the stop |
| B11 Amendment 05 inactivity stop | PASS with change request | "Session stopping: inactivity after 300s without speech", then "skipped, no row", then History. Both notices are queued in order (`recording_screen.dart:135-182`). The second was captured; the first had already gone before the first capture. James asked for one combined notice (Amendment 07) |
| Empty session (Q-2) | PASS | A 10 s silent session shows "No speech was recognised, so no transcript was saved." and creates no row |
| Airplane mode (NFR, "works without an internet connection") | PASS | Airplane mode on and Wi-Fi off, confirmed with `cmd connectivity` and `cmd wifi`. A sentence was recognised and the session saved with `segmentCount=1` |
| AC-2, microphone denied | PASS | Revoked in App info, then Start. Android asks again; after Don't allow the panel shows "Microphone access is blocked" with Try again, Open settings and Back, and no crash |
| Open settings, grant, Try again | PASS | Open settings goes to Zip Captions' App info. After granting, Try again starts captioning (on-device check, then session started) |
| Amendment 06 recovery twice (BR-U10-57) | Not provoked | No way to cause a recogniser failure through the app. Covered by unit tests (TP-36) |
| Amendment 06 5 s Stop bound (BR-U10-58) | Not provoked | Unit tests only (TP-37), as section 6 states |
| Language-pack download (Steps 4 and 5) | Not reached | The en-CA pack was already installed. Passed on the emulator on 2026-10-26 |

**Change request (James Petersen, 2026-10-30)**: the inactivity notice and the no-transcript notice should be one combined notice, not two shown one after the other. The same applies to every pair of stop notices. Built as Amendment 07.

**Amendment 07 on the phone (build `fa7b61a`): PASS.**
- **The passing run:** a silent session from 13:02:28.9. The phone recorded its own screen (`screenrecord`) from 15 s before the inactivity stop to 25 s after it.
- **What the frames show:**
  - the recording screen with no captions;
  - then History, with no new transcript row;
  - then **one** SnackBar: "Captioning stopped after 5 minutes without speech, so no transcript was saved."
  - The recording has no later frame (it only writes frames when the screen changes), so no second notice followed.
- **Earlier attempts:**
  - Two silent runs, at 12:30:48 and 12:40:35, stopped by themselves with no row. But the screenshots missed the 4 s notice: one was taken too late, and one burst ended before the stop. Both showed nothing on screen more than 10 s after the stop.
  - Two runs were invalid, because speech in the room was captioned.
- **Error and save-failed combinations:** they can't be provoked on a device, and are covered by TP-43.

**Observations (no defect in Unit 10's code)**:
1. **The renewal waits for a pause.** The recogniser keeps a segmented session open past `EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS` while speech continues (16.6 s past 300 s here) and renews at the next pause. No words were lost. So D-2's renewal comes at 5 minutes or later, at the first pause.
2. **The app requests `ACCESS_LOCAL_NETWORK`**, a new Android 17 runtime permission shown as "Nearby devices", which is granted. Something the app pulls in requests it. For the Unit 11 manifest review.
3. **The shell cannot set volume on Android 17.** `cmd media_session volume --set` returns but does not change the level. The volumes were raised through Settings.
4. **The text-size button is drawn very small** on the permission-denied panel (full size on the recording screen). It's cosmetic and was recorded for a later UI pass.
5. **A Stop tap twice did not register** on its first press, on the phone at 12:52 and once on the emulator (Step 9(a), 2026-10-27). The second tap worked both times. The cause is unknown and it has not been reproduced on purpose. Watch for it in later passes.
6. **Tooling: the Flutter MCP's device screenshot hung** for about 40 minutes on the Settings screens. `adb exec-out screencap` with a timeout worked at once. Revoking the microphone in Settings killed the app's process, as Android does, which ended `flutter run`; the app was relaunched with `flutter run`.

## iOS Simulator pass, 2026-10-30

**Device**: iPhone 17 Simulator `3A0EDA8C-BAAF-47A6-A213-E29485B92547`, iOS 26.0. Language English, region first Canada (`en_CA`), later United States (`en_US`) for A8. Mac: MacBook Pro Microphone as the default input, MacBook Pro Speakers as the default output, input volume 50, output volume 100.

**Build**: `feature/mobile-platform-readiness` at `134acbb`, debug, `flutter run -d 3A0EDA8C-…` from the Unit 10 QA worktree. `privacy reset all` and an uninstall were done before the first launch. Nothing was committed and no app code was changed.

**Method**: a Sonnet session acting as QA runner. No screenshots, videos or logs were kept in the repository (see the note at the top).
- **Taps and system dialogs:** AXe (`axe tap --label …` or `-x/-y`), installed by James Petersen, addressed to the Simulator by UDID. An earlier attempt with `osascript` and synthetic mouse clicks moved the real cursor and was dropped at James's request; he then removed the Accessibility grant.
- **Screen:** `xcrun simctl io <UDID> screenshot`, and `recordVideo` with frames extracted by `ffmpeg` for the Stop notice.
- **System log:** `xcrun simctl spawn <UDID> log stream --predicate 'process == "Runner"'`.
- **Speech:** macOS `say` from the host speakers, picked up by the Mac microphone and passed to the Simulator through I/O > Audio Input.
- **Dart log:** not available this run. The Flutter MCP connected to the VM service but its `console_logs` returned no lines in `fetch` or in a 30 s `watch`, and `flutter run` printed only `flutter:` lines. The listening locale was therefore taken from the Simulator's settings, not from an app log line.

**First-run result (A2, A3 and the verdict below are superseded by "A3 troubleshooting and resolution": the failure was a macOS microphone denial, now fixed, and A3 passes): A1 passes, A2 not verified, A3 not possible as written (replaced by an iOS dictation test), A4 passes on the Mac side, A5 recorded, A6 passes. A7 and A8 fail with no recognised text. A9 and A10 were not reached. On-device recognition is not demonstrated on the Simulator.**

| Step | Result | Evidence |
|---|---|---|
| A1 Simulator I/O > Audio Input | PASS | The menu lists System (MacBook Pro Microphone), BlackHole 2ch and MacBook Pro Microphone; "System (MacBook Pro Microphone)" carries the checkmark. Not BlackHole, not Zoom |
| A2 Simulator allowed in macOS Privacy > Microphone | FAIL, then fixed | First run: the setting could not be read from the shell, and the Simulator was not listed in the pane. The `tccd` log later showed a stored denial for `com.apple.CoreSimulator.SimulatorTrampoline`. After `tccutil reset Microphone` and Allow it logs a grant. See "A3 troubleshooting and resolution" |
| A3 Input path through the Simulator (as first written: record 5 s in Voice Memos and play it back) | REDEFINED (James Petersen, 2026-10-30) | The Simulator's iOS image has no Voice Memos app (home screen: Calendar, Photos, Reminders, News, Maps, Health, Wallet, Settings, Safari, Messages). A3 is now the iOS dictation test: Settings > General > Keyboard > Enable Dictation on; in Settings, tap the Search field and then the keyboard's dictate button; speak a repeatable phrase with macOS `say`; the phrase must appear in the field. It counts only if text appears. First run: FAIL (macOS microphone denial, see "A3 troubleshooting and resolution"). After the fix: PASS. A7 onward wait for A3 to pass |
| A4 Mac input level moves when speaking | PASS (Mac side) | `ffmpeg -f avfoundation` from the MacBook Pro Microphone while `say` played: max volume -2.4 dB, mean -19.9 dB. The host hears `say` clearly. The System Settings level bar was not looked at |
| A5 Dictation language offered | RECORDED | Settings > General > Keyboard shows Enable Dictation, Auto-Punctuation and Dictation Shortcut only. No per-language list, so neither en-CA nor en-US is offered or confirmed there. Language & Region: English, region Canada |
| A6 Permissions from scratch | PASS | After `privacy reset all`, uninstall and `flutter run`: Start Captioning, then the explainer ("Before your device asks for permission", Continue and Not now), then the microphone prompt, then the speech-recognition prompt, in that order. Allow, Allow, then the recording screen with Pause and Stop. No toast |
| A7 Captions, en-CA | FAIL | Listening from 15:20. `say` from 15:20:35: two sentences, a 10 s pause, then two more, about 58 s in all. The caption area stayed empty throughout. System log: `AVAudioSession … Got Permission value 1`, AURemoteIO and an aggregate device started, `SFSpeechAssetManager … fetching the path to the Assistant asset`, no error. No segment text on screen, no toast. Stop at 15:21:50 (video): History opened, one notice "No speech was recognised, so no transcript was saved.", History empty ("No transcripts yet") |
| A8 Captions, en-US | FAIL | Region changed to United States through Settings (the Simulator restarted; `AppleLocale` read `en_US`). App relaunched, Start Captioning (no explainer, no prompts: both already granted). Listening from 15:24. `say` 15:24:38 to 15:25:36, same phrases and pauses. Caption area empty. Same system log pattern, no error. Stop was tapped but its notice was not captured |
| iOS dictation (Settings > Search), extra | FAIL | James Petersen allowed enabling Dictation for the tests. After "Enable Dictation", the keyboard's dictate button showed the blue listening bubble at the cursor. `say` was spoken twice; the field stayed empty. This is iOS's own recogniser, not our app |
| A9 Missing-language panel, Download, Try again | NOT REACHED (superseded: passed in "A9 run" below) | The panel never appeared in en-CA or en-US, which both had an on-device model |
| A10 (a) 2 minutes, (b) Pause and Resume, (c) silent 10 s, (d) 5 minutes silent | NOT RUN | Captions never worked |
| Amendment 06, Stop and Pause straight after a sentence | NOT RUN | Needs recognised text |
| Amendment 07, one notice per stop | OBSERVED, not a pass | The A7 Stop produced exactly one notice (the no-speech one) and no second. This was not the silent-session case the check asks for, because speech had been played |

**Findings**
1. **Recognition returns nothing on the Simulator, and nothing fails.** In both locales the app is listening, the audio engine runs, the on-device check was true in the earlier run (`Engine platform initialized for locale en-CA`, `On-device support check: true`, 2026-10-27), and neither a result nor an error arrives. This repeats the 2026-10-27 run.
2. **The host side is not the cause.** The Mac microphone hears `say` at -2.4 dB peak, and the Simulator's input is set to it.
3. **iOS's own dictation also hears nothing in the Simulator.** That makes an app fault unlikely and points to the Simulator not delivering host audio, or not recognising it. It does not prove either: dictation on the Simulator may also depend on assets or services that are absent. This matches the Android emulator, where host audio was lost until a physical device was used (2026-10-27 and 2026-10-30).
4. **Verdict: "on-device recognition not demonstrated on the Simulator".** No code change was made. The iOS captions path (A7, A10, Amendments 06 and 07, and the A-1 download) needs a physical iPhone. James Petersen has none on hand at this time.
5. **Decision needed (James):** whether Unit 10 closes with the iOS captions behaviour verified on the Simulator only for permissions, the explainer, the empty-session notice and the reset paths, and the rest deferred to a physical-device pass; or whether an iPhone is found first.
6. **Docs-mcp:** no indexed library covered the Simulator's audio hardware. Apple's "Configuring the environment of a simulated device" states that audio input is set from Device > Sound > Sound Input (or the Settings inspector), and that "System" uses the same input as the Mac; this matches A1. It describes Xcode 27's Device Hub; this Mac runs the Xcode 26 Simulator app, whose I/O > Audio Input menu showed the same three choices. A library `xcode-simulator` was indexed from those Apple pages at James's request.

**A3 troubleshooting and resolution (2026-10-30, later the same session)**
- **Cause found:** macOS had a stored microphone **denial** for the Simulator's responsible process, `com.apple.CoreSimulator.SimulatorTrampoline` (an XPC service inside CoreSimulator, not an app). The `tccd` log at 15:20:14, when the app's audio engine started, shows `AUTHREQ_RESULT … authValue=0, authReason=2` (denied by user consent) and `authValue=1` (preflight unknown), where a grant is `authValue=2`. The Simulator therefore received silent input. iOS raised no error, because the simulated phone's microphone looked normal. The Simulator did not appear in System Settings > Privacy & Security > Microphone (neither "Simulator" nor "SimulatorTrampoline"), so the setting could not be switched there.
- **Why this explains the earlier symptoms:** the audio engine started and ran cleanly, the Mac microphone heard `say` at -2.4 dB, and recognition (the app and iOS dictation) returned nothing and no error. The Android emulator's "no host audio" may have a similar host-side cause; it was not checked for one.
- **Fix:** `tccutil reset Microphone` (all apps; `tccutil reset Microphone com.apple.CoreSimulator.SimulatorTrampoline` fails with "No such bundle identifier"), authorised by James Petersen, then the simulated iPhone was shut down and booted. Starting dictation raised the macOS microphone prompt; James clicked Allow. `tccd` then logged `AUTHREQ_RESULT … authValue=2, authReason=2` at 15:40:28. Side effect: every other app on the Mac now asks for microphone access again on its next use.
- **A3 retest: PASS.** The prompt interrupted the first dictation. On the second start, with `say` speaking the test phrase, the Search field received the phrase (one word differed from the spoken text) and the screen showed "No Results for …" with the phrase in it. This was in the English (United States) region.
- **Consequence for the A2 row:** A2 is now verified through the `tccd` log rather than the System Settings pane, which does not list the Simulator.
- **Rerun:** done next, in en-CA, see "Rerun of every microphone check after the fix" below.

**Rerun of every microphone check after the fix, en-CA (2026-10-30, 15:40 to 15:58)**

Region restored to Canada (`AppleLocale` read `en_CA`, the Simulator restarted). Same build `134acbb`. `privacy reset all`, uninstall, `flutter run`. This time the Dart log was read through a small VM-service reader (Logging and Stdout streams) that I wrote in the session scratchpad. The macOS microphone grant from the fix above was in place, so these runs are valid. Room speech was not captured in any run (every phrase on screen was a test phrase). Timestamps below are the Mac's clock.

| Step | Result | Evidence |
|---|---|---|
| A6 Permissions from scratch | PASS | Start Captioning 15:44:11, explainer ("Before your device asks for permission"), Continue, microphone prompt, Allow, speech-recognition prompt, Allow. Log: `Platform STT initialized: true`, `Engine platform initialized for locale en-CA`, `On-device support check: true`, `Listening started for locale en-CA`. No panel, no toast |
| A7 Captions | PASS | `say` 15:44:39 to 15:45:40: two sentences, a 10 s pause, one sentence, a 15 s pause, one sentence, a 15 s pause, and a last sentence. Recognised text was on screen: all four phrases, with small errors ("positive" for "pause of", "Captions on the simulator" for "Zip captions on the simulator"). Locale en-CA. No SnackBar in the video frames around Stop. Stop 15:45:54: History row "1m 24s · 1 segments"; log `finalizeCurrentSession … durationMs=84933 segmentCount=1` |
| A8 en-US repeat | NOT NEEDED | A7 passed in en-CA. The earlier en-US failure was the macOS denial, not the locale |
| A9 Missing-language panel, Download, Try again | PASS (run separately, see "A9 run" below) | First rerun: not reached, because en-CA already had an on-device model, so the panel did not appear. James Petersen rejected "not reached" ("let's do it properly"); A9 was then provoked through the app's own flow with a language that has no pack. A-1 confirmed |
| A10(a) 2 minutes with pauses | PASS | Session 15:46:29. `say` 15:46:38 to 15:48:32: eight numbered sentences with pauses of 6, 20, 10, 25, 8 and 12 s. All eight were on screen, as one block. No segment was saved until the Pause at 15:48:44 (see finding 1) |
| A10(b) Pause, then Resume | PASS | Pause 15:48:44: text stayed above a "paused" marker; log `Paused (via stop)`, `Session paused`. Resume 15:48:56: `Listening started`, `Session resumed`, `session continued` with the same session id. A sentence spoken after Resume was captioned below the marker. Stop 15:49:09: `durationMs=160440 segmentCount=2` (History "2m 40s · 2 segments") |
| A10(c) Silent 10 s, then Stop | PASS | Session 15:49:30, Stop 15:49:44.7, video at 1.5 frames/s: exactly one SnackBar, "No speech was recognised, so no transcript was saved.", on History; no second notice; no new History row; log `finalizeCurrentSession … skipped, no row` |
| A10(d) 5 minutes of silence | PASS | Session 15:52:10 (nobody spoke). Log `Session stopping: inactivity after 300s without speech` at 15:57:10.172, then `skipped, no row`. Video (15:56:53 to 15:57:40): the recording screen, then History, then exactly one SnackBar, "Captioning stopped after 5 minutes without speech, so no transcript was saved."; no second notice; no new row |
| Amendment 06, Stop straight after a sentence, ×3 | PASS ×3 | Each trial: `say` ended, the Stop tap about 0.2 s later, then `saveSegment (new)` 0.04 to 0.1 s after the tap, then `Listening stopped` (2.6 s after the tap in trial 1, 0.06 s in trial 2, 2.6 s in trial 3), then `finalizeCurrentSession … segmentCount=1` (durationMs about 8 s). The trial-3 transcript, opened from History, held the whole test phrase. Both well inside the 5 s Stop bound |
| Amendment 06, Pause straight after a sentence, ×3 | PASS ×3 | Each trial: the Pause tap about 0.2 s after the speech ended; `saveSegment (new)` 0.04 s after the tap, then `Paused (via stop)`, `Session paused`. The phrase stayed on screen above its "paused" marker in all three (screenshot after trial 3 shows all three phrases and three markers). Resume and the final Stop followed: `segmentCount=3` |
| Amendment 07, one notice per stop | PASS | A10(c) and A10(d) each produced exactly one notice. The error and save-failed combinations cannot be provoked on a device (TP-43) |
| Sounds on iOS | NOT CHECKED | James was not asked to listen in this rerun (the 2026-10-27 run recorded no chime) |
| Amendment 06 recovery twice and the 5 s Stop bound | NOT PROVOKED | Unit tests only (TP-36, TP-37), as on Android |

**Findings from the rerun**
1. **Change request (James Petersen): a pause in speech should start a new segment.** Evidence: in A7 and A10(a) the whole run, 60 s and then 2 minutes with pauses of up to 25 s, was one block on screen, and the only `saveSegment` for the run came at Stop or Pause. The `SFSpeechRecognizer` task did not report a final result at the pauses. Segments split only where the session itself ended (Pause, Stop). A side effect: the transcript is written to storage only at Pause or Stop, so a crash mid-session loses the run. This is behaviour of the existing iOS runner, not a Unit 10 regression, and it was not changed. The design question is whether the app should split on silence itself (for example a silence timer over the partial results) or ask the recogniser to.
2. **Change request (James Petersen): punctuation and capitalisation.** Evidence: the recognised text on screen has no punctuation and only some capitals (for example "Sentence one the first test phrase for the long run Sentence two comes after a short pause"). Apple documents `SFSpeechRecognitionRequest.addsPunctuation` ("Set this property to `true` for the speech framework to automatically include punctuation … a period or question mark at the end of a sentence, and a comma within a sentence"); the on-device iOS dictation in this Simulator, by comparison, produced "Keyboard language privacy the quick brown fox jumped over the lazy dog" with no punctuation in the search field. Whether the runner sets the property was not checked in this run (no code was read for it). Android's recogniser may behave differently. Decision for James: scope, and whether this belongs in Unit 10 or a later unit.
3. **Recognition quality on the Simulator is test-grade, not a pass criterion.** Numbers read as digits ("123", "20"), "pause of" became "positive", and one word differed in every long run. None of this is a defect in Unit 10's code.
4. **Stop can take about 2.6 s to complete** (trials 1 and 3; trial 2 took 0.06 s), consistent with the Amendment 06 drain. It is inside the 5 s bound.

**A9 run: missing-language panel, Download, Try again (2026-10-30, 16:04 to 16:08)**

Why it was not reached before: with en-CA or en-US the on-device check was true, so no panel. The app has no language option in its own Settings (Display, Transcripts and Accessibility only); its locale comes from the phone's preferred languages, in order (Amendment 03 section 6). So the panel was provoked through the phone's own language setting, which any user can do, with no `simctl` shortcut and no change to the app.

| Step | Result | Evidence |
|---|---|---|
| Set a language with no on-device model | done | Simulator Settings > General > Language & Region > Add Language > English (Australia) > "Use English (Australia)". The Simulator restarted. `AppleLanguages` read `("en-AU")`, region still Canada. `flutter run` and the log reader were restarted |
| Start Captioning | PASS (panel shown) | Log: `Engine platform initialized for locale en-AU`, `On-device support check: false`, `Reporting engine error: onDeviceModelMissing`, `Engine platform failed to start listening`. Panel: "On-device captions aren't available", "This device or language doesn't support on-device speech recognition, so Zip Captions didn't start.", buttons "Download English (Australia)", "Try again" and "Back". No "Open settings" (BR-U10-10 holds) |
| Tap Download English (Australia) | PASS | Video (about 0.7 frames/s): the button replaced by "Downloading English (Australia)…" with an indeterminate bar, then 4%, 26%, 35%, 53%, 60%, 79%, 87%, 99%, then "English (Australia) is ready. Tap Try again to start captioning." with Try again and Back only. About 40 s. No download started before the tap (BR-U10-48) |
| Tap Try again (assumption A-1) | PASS: A-1 CONFIRMED on the iOS 26.0 Simulator | Log: `On-device support check: true`, `Listening started for locale en-AU`, `Session started`. After an `AssetInventory` download, `SFSpeechRecognizer.supportsOnDeviceRecognition` is true for that locale and the session starts. The app did not start captioning by itself before the tap (BR-U10-47) |
| Captions in the downloaded language | PASS | `say` spoke a sentence, a 6 s pause and a second sentence; both were on screen in en-AU. Stop: `saveSegment`, then `finalizeCurrentSession … segmentCount=1`. The phrase matched the spoken text, apart from missing punctuation |

Not provoked: the failure text ("Couldn't download…"), the scheduled state (BR-U10-47a), `unsupported` and `unknown` statuses (no action shown), and the iOS 13 to 25 instructions path. These need a failing network, a locale the platform refuses, or an older device. Covered by unit tests (TP-28 to TP-30) only.

**Findings from the A9 run**
1. **A-1 is confirmed** (iOS 26.0 Simulator): the Amendment 04 iOS 26 button works end to end, so the fallback to instructions on iOS 26 is not needed.
2. **The app has no way to choose the captioning language.** On iOS the only route to a different language is the phone's own language setting. Amendment 04 BR-U10-50 expects "Settings can list them" for the Android language list; no language list appears in the app's Settings on iOS. Decision for James: whether a language selector is in scope for Unit 10.
3. The phrase captured with no punctuation, one block across the pause: change requests 1 and 2 above apply here as well.

**State left behind**: the Simulator is booted, with the language and region restored to English (Canada) (`AppleLanguages` `("en-CA")`, `AppleLocale` `en_CA`), Dictation enabled, the app installed with both permissions granted, and seven transcripts in History. The English (Australia) on-device model stays installed (it cannot be removed through the app). The VM-service reader, the log stream and `flutter run` were stopped. Nothing is stored outside the session scratchpad.

**Observations (no defect in Unit 10's code)**
1. The Simulator's iOS image has no Voice Memos, so the brief's A3 cannot be run as written.
2. Mouse-event automation from the shell (`osascript`, `CGEvent`) did not reach the Simulator's touch layer; AXe did, with labels or coordinates, and without moving the Mac's cursor.
3. `screencapture` showed only the wallpaper (no Screen Recording grant); `simctl io … screenshot` worked.
4. Changing the region restarts the simulated iPhone and ends `flutter run`.

## Amendment 08 device check, 2026-10-30

**Build**: the Amendment 08 working tree on `feature/mobile-platform-readiness` (based on `134acbb`, committed afterwards), debug, `flutter run` from the Unit 10 QA worktree. It ran on the Pixel 6 (`25071FDF600953`, Android 17) and on the iPhone 17 Simulator (`3A0EDA8C-…`, iOS 26.0, en-CA).

**Method**: Opus drove both apps through their own screens: `adb input` on the phone, AXe on the Simulator. The same macOS `say` script was played on each: three short sentences (a greeting with a question, a statement, and a question) after 2 s of silence, with 3 s of silence after each sentence. Screens were read from `adb exec-out screencap` and `simctl io … screenshot`. No screenshots were kept.

| Check (Amendment 08 section 5) | Android | iOS Simulator |
|---|---|---|
| Separate segments at pauses of about 3 s | PASS: three blocks on screen, one per sentence | PASS: three blocks on screen, one per sentence (before Amendment 08, a whole run stayed one block) |
| History count = pauses + 1 | PASS: "0m 33s · 3 segments" | PASS: "0m 36s · 3 segments" |
| Saved transcript | PASS: three rows, at 00:06, 00:11 and 00:17 | PASS: three rows, at 00:11, 00:16 and 00:20 |
| Punctuation and capitals | PASS: sentence capitals, full stops and question marks, on screen and in the saved transcript. So `EXTRA_ENABLE_FORMATTING` takes effect on this recogniser | PASS: a comma and question marks, on screen and in the saved transcript. Apple ended the statement with no full stop |

**Notes**
- **The saves at each pause** are shown by the three stored rows. A row is written per final, and the three finals were 5 s apart, outside the 2 s merge window. The `saveSegment` log lines were not read: `flutter run` on iOS prints only `flutter:` lines, and the VM-service reader from the earlier pass was not used.
- **Pause and Resume, and Stop straight after speech,** with a pause commit (TP-47) were not run on a device. Unit tests only.
- **Observation (Android, cosmetic):** after Back from a transcript, the History list kept "Transcript" as its app-bar title. Not investigated. For the later UI pass with observation 4 of the Android pass.
