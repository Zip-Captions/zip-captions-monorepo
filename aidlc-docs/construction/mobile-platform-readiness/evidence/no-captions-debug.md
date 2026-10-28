# No captions on Android emulator — debug report

Date: 2026-10-26 (evening). Device: `emulator-5560` (`ZipCaptions_QA_API_36`, verified via
`adb -s emulator-5560 emu avd name`). Branch: `feature/mobile-platform-readiness`, working tree
untouched apart from this report and the `evidence/no-captions-debug/` folder.

## 1. Root cause

**The defect is not in the app.** The emulator's host-microphone capture path
(macOS AVAudioEngine inside the emulator process → QEMU → ranchu audio HAL) enters a
starved/dead state in which the guest `TinyalsaSource` continuously fails
`pcm_readi ... 'cannot read/write stream data: I/O error'` and the HAL substitutes silence.
The on-device recogniser is then fed digital silence: it opens the mic (`onMicrophoneOpened`),
fires one burst of VAD activity plus a few **empty** segments from stale/ambient frames about
4.5 s after `onReadyForSpeech`, and then delivers nothing — no partials, no segments, no
errors. The app therefore stays "Recording" with no text, exactly as reported.

While that stream was starved, the Mac's **physical microphone clearly heard the played
speech** (host-side ffmpeg probe: mean −20.1 dB / −22.4 dB vs the BlackHole default device at
−91.0 dB pure silence), and the throwaway spike app failed identically in the same windows.
When the emulator's capture stream is healthy, the **unmodified app recognises and renders
text correctly end-to-end** (verified repeatedly, see timeline).

Starvation windows on this emulator today all began shortly after heavy host-CPU bursts
(`flutter build apk` — one of which had Gradle SIGKILLed and retried — and `flutter run`
rebuilds). Once starved the stream did not reliably recover; each fresh mic-open was a coin
flip. This pattern is an emulator/host audio defect, fixable only outside the device
(emulator cold restart / macOS mic permission hygiene) and explicitly outside the adb
allow-list of this task ("Do not work around it with adb").

### Decisive evidence

| # | Evidence | File |
|---|---|---|
| E1 | Spike recognises the exact standard phrase (`-r 150`) end-to-end on this emulator while the app was stopped — proves emulator + recogniser + host audio CAN work on 5560 | `no-captions-debug/spike-stepA-recognised.log` |
| E2 | During missed-speech windows, `android.hardware.audio@7.1-impl.ranchu` logs `entering standby` + continuous `pcmRead:221 pcm_readi failed with 'cannot read/write stream data: I/O error' (-1)` (23:01, 23:28) | `no-captions-debug/emulator-hal-starvation.log` |
| E3 | Host mic probe while the app received nothing: physical mic −20.1/−22.4 dB (speech audible), BlackHole default −91.0 dB | `no-captions-debug/host-mic-probe.txt` |
| E4 | App (original code) with captions on screen: uiautomator dump shows two full-phrase caption entries; History later showed "6m 53s · 5 segments" | `no-captions-debug/ui-dump-captions-visible-original-code.xml` |
| E5 | Step-D fresh install recording screen with recogniser listening and zero caption nodes | `no-captions-debug/ui-dump-stepD-no-captions.xml`, `05-stepD-recording-no-captions.png` |
| E6 | Post-Stop window: no SnackBar in any dump; History clean; finalize logged `skipped, no row` for the empty sessions | `no-captions-debug/ui-dump-poststop-no-snackbar.xml`, `app-logger-fresh-install.txt`, `06-poststop-01..12.png` |
| E7 | Engine renewal verified: `onEndOfSegmentedSession` → check → new session gets `onReadyForSpeech` | §4 timeline 23:19:56 |

### Ruled out (measured, not assumed)

- **Native listener / eventSink (steps B1/B2):** temporary Kotlin logs (type + text length +
  sink state only) showed every `RecognitionListener` callback firing and `sink=set` for the
  whole session, including `emit partial textLen=80`, `emit segment textLen=81`. Nothing is
  lost Kotlin→Dart.
- **Bridge decode / engine (B3/B4):** `sink=set` events with real text reached Dart and the
  engine delivered them (interim + final) in every healthy window.
- **Session manager / bus / on-screen target / screen (B5/B6):** `uiautomator` dumps show the
  caption entries rendered (`Caption` bar + entries + control bar), and TranscriptWriterTarget
  + History show the segments (2 segments at 23:11, 5 segments at 23:21).
- **`checkRecognitionSupport` poisoning:** briefly suspected; A/B disproved it (with the check
  active, the app captured every phrase during healthy windows, e.g. 23:14:50 run).
- **permission_handler AudioManager mode toggling:** the resolved `permission_handler_android`
  12.1.0 contains no `AudioManager.setMode` usage.
- **App leaking recognition sessions:** the `capacity is full - ignoring` line seen at 22:21
  was AiAi refusing the *spike* because the user's own live app session held the single slot —
  correct single-session behaviour, not a leak.

## 2. Files changed

**None.** Net diff of app code is empty. Temporary diagnostics added to
`packages/zip_captions/android/app/src/main/kotlin/app/zipcaptions/captions/MainActivity.kt`
(TEMP-DBG `Log.i` of event type/text length/sink state only — never recognised text — plus a
temporary on-device-check bypass used for the A/B test) were all removed; the file is byte-identical
to the received state (612 lines, `grep -c TEMP` = 0). No Dart file was modified.
`git diff --stat -- packages/zip_broadcast` is empty. Untracked files under `evidence/` are
this report's artefacts only.

## 3. Tests

No production code defect was found, so no code fix and therefore no reproduction tests could
be written (a test would have to exercise the emulator's audio HAL). The full suites were run
as regression evidence of the untouched tree (baselines match exactly):

- `zip_core`: `00:29 +1125 ~4: All tests passed!` (baseline 1125 passed, 4 skipped)
- `zip_captions`: `00:10 +391: All tests passed!` (baseline 391)
- `zip_broadcast`: `00:08 +195: All tests passed!` (baseline 195)

How the Kotlin side was verified instead: temporary `Log.i` lines (type/length/sink only) plus
the spike app as a control — the spike and the app exhibited identical behaviour in identical
audio windows (both captured during healthy windows, both missed everything during starved
windows), isolating the fault to the emulator audio path rather than either app.

## 4. Verification timeline (key points)

| Time | Event |
|---|---|
| 22:21 | Spike blocked by `RecognitionService: #startListening received when the service's capacity is full - ignoring` — the user's still-running captioning session held the slot |
| 22:22–23 | Spike (segmented) recognises the standard phrase incl. partials + `onSegmentResults` → **Step A PASS** |
| 22:25–33 | `flutter build apk` (Gradle SIGKILL + retry) — heavy host CPU |
| 22:34–23:08 | STARVED: app sessions + spike receive only empty segments; HAL `pcm_readi` I/O errors |
| 23:07–23:09 | Spike captures phonetic + standard phrase (healthy window) |
| 23:10–11 | App (diagnostic build) captures 2 phrases → captions on screen, History "1m 45s · 2 segments" |
| 23:14:50–23:16:18 | App (ORIGINAL code, on-device check active): partials `textLen=4..80`, segments, both phrases rendered on screen; Stop → History "6m 53s · 5 segments" |
| 23:19:56 | Engine renewal after `endOfSession`: new session gets `ready` (renewal path works) |
| 23:22–23:23 | App (original) captures phrase + phonetic; host-mic probe proves audibility (E3) |
| 23:27–23:35 | **Step D** fresh install, permission via app prompt ("While using the app"), Start, mandated `-r 150` protocol + second sentence + 6 stop/start retries: recogniser starved the whole time → no captions (E5), no SnackBar (E6), finalize `skipped, no row` |

## 5. Step D result: **FAIL — blocked by the emulator, not by the app**

PASS requires recognised words visible on screen; under the current starved host-mic state no
app (and not the control spike either) can produce them. All non-audio PASS criteria were met
in the fresh-install run: clean install, mic granted through the app's own system dialog,
session starts and stays running, correct service-side `onMicrophoneOpened`/`SodaAudioPusher`,
no SnackBar after Stop, no engine errors in the app log, empty transcript correctly not saved.
The transcript/segmentCount/History criteria were demonstrated in the identical build during a
healthy capture window (5 segments, 23:14–23:21).

**What the user must change (outside agent scope, no adb workaround per task rules):**
1. Cold-restart the `ZipCaptions_QA_API_36` emulator (kill and relaunch the emulator process)
   — this re-initialises its host-audio capture. Toggling "Virtual microphone uses host audio
   input" off/on is worth a try first, but a process restart is the reliable fix after a
   starved stream.
2. Confirm macOS System Settings → Privacy & Security → Microphone allows the emulator
   (QEMU / Android Studio).
3. Avoid saturating the Mac (Gradle/`flutter build`) while captioning tests run; every
   starvation window today began right after a build burst.
4. Then re-run Step D as specified — expected to PASS based on the healthy-window evidence.

## 6. Not resolved / recommendations

- Emulator host-mic starvation itself (host/AVAudioEngine level) — not agent-fixable per rules;
  needs the user actions above.
- Optional hardening (needs a design discussion, NOT implemented): the engine has no watchdog
  for "session accepted but zero events ever arrive", so a starved capture keeps the UI in
  "Recording" indefinitely with no feedback. A "listening but silent" hint (state change or
  notification after N seconds of complete silence with the mic open) would surface this class
  of environment failure to users. Contract impact must be reviewed first.

## 7. Gate output tails

```
$ melos run analyze  (dart analyze --fatal-infos, all packages)
  └> SUCCESS
ANALYZE_EXIT=0

$ flutter test (zip_core)
00:29 +1125 ~4: All tests passed!   EXIT_CORE=0
$ flutter test (zip_captions)
00:10 +391: All tests passed!       EXIT_CAPTIONS=0
$ flutter test (zip_broadcast)
00:08 +195: All tests passed!       EXIT_BROADCAST=0

$ git diff --stat -- packages/zip_broadcast
(empty)

$ flutter build apk --debug (packages/zip_captions)
Running Gradle task 'assembleDebug'...                             13.1s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

Cleanup: spike app `dev.spike.segspike` uninstalled from emulator-5560; Zip Captions left
installed (fresh, original code) with microphone granted "While using the app".
