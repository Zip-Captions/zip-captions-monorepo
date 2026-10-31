# Joint QA runbook: Unit 10 (Mobile Platform Readiness)

For a session with James present, with the Mac, the iPhone 17 Simulator and his own Android 13+ phone.

**QA rules (apply to every step)**
- Everything goes through the app's own flows. No `adb` workarounds: no `pm grant`, no `adb shell am`, no settings changes by `adb`, no injected audio.
- A captions run counts only if all four hold: recognised text is on screen; `segmentCount` > 0; the locale is the expected one; no SnackBar or toast appeared.
- Play or speak only after the recogniser is ready (the mic is open). Do not speak straight after the tap.
- For each step, record: time, what you did, what you saw or heard, pass or fail.

Note on step names: Steps 6, 6b, 7 and 8 are defined below from the Step 30 evidence. The original protocol text for 6b and 8 was not available to the author of this runbook (not verified); the definitions are reconstructed, so correct them if the original differs.

---

## Part 0: Setup

### 0.1 Android phone: Pixel 6, `25071FDF600953` (Android 17, API 37; Speech Services by Google is the default recogniser)

Steps 1 to 3 below are already done for the Pixel 6; use `-d 25071FDF600953`.

1. Enable Developer options: Settings, About phone, tap "Build number" seven times.
2. Settings, System, Developer options, turn on "USB debugging". Connect the phone by USB and accept the "Allow USB debugging?" prompt on the phone.
3. Find the device id. In a terminal:
   ```
   cd /Users/oblivious/Documents/zip-captions-monorepo/packages/zip_captions
   flutter devices
   ```
   Copy the id in the second column for your phone (for example `R58M123ABC`). Call it `<device-id>`.
4. Build and run a debug build on the phone:
   ```
   flutter run -d <device-id>
   ```
   Or install without running:
   ```
   flutter install -d <device-id>
   ```
   (`flutter install` installs the last built APK; run `flutter build apk --debug` first if none exists.)
5. Do not pre-grant the microphone. The first Start Captioning must show the system permission prompt.
6. Language pack. If the app shows "On-device captions aren't available" with "Download English (United States)" or "Download English (Canada)", tap that Download button in the app and approve Android's own dialog. Never install the pack with `adb` or from Settings on the side. Wait for "is ready", then tap Try again.
7. Keep the phone unlocked and its screen on. Note the phone model and Android version.

Record: device id, model, Android version, build time, which locale the app resolved (en-US or en-CA).

### 0.2 iPhone 17 Simulator

1. Quit anything else using the Simulator. In Simulator, menu I/O, Audio Input: see Part A.
2. Build and run from `packages/zip_captions`:
   ```
   flutter run -d 3A0EDA8C-BAAF-47A6-A213-E29485B92547
   ```
   (the iPhone 17 Simulator, iOS 26.0).

---

## Part A: iOS Simulator input checks, then rerun of iOS Steps 3 to 5

Background (from the diagnosis): on the earlier run, listening started with the real engine and the on-device check true, but no text and no error appeared. Silent input produces exactly that. Rule out the input path before judging the app. Do these before launching the app.

**A1. Simulator audio input device.** Action: Simulator menu I/O, Audio Input. Expected: "MacBook Pro Microphone" or "Host Default" is ticked, not BlackHole or Zoom. Record: what was ticked; fix it if wrong.

**A2. macOS microphone permission.** Action: System Settings, Privacy and Security, Microphone. Expected: Simulator is switched on (toggle off and on if it is present; if absent, the first use should prompt). Record: state.

**A3. Mic path probe.** Action: in the booted Simulator open Voice Memos, record 5 s while speaking, play it back. Expected: your voice is heard on playback. Record: heard / silent. Silence means the Simulator input path is the problem; stop and fix before continuing.

**A4. Mac input level.** Action: System Settings, Sound, Input, watch the level bar while speaking. Expected: the bar moves. Record: moved / flat.

**A5. Dictation availability (informational).** Action: Simulator Settings, General, Keyboard, Enable Dictation; Settings, Siri if present. Expected: note whether en-CA or en-US dictation is offered or says unavailable. Record: what it says.

**A6. Rerun iOS Step 2 (permissions).** Action: `xcrun simctl privacy 3A0EDA8C-BAAF-47A6-A213-E29485B92547 reset all`, uninstall the app, run it, tap Start Captioning. Expected: the explainer first, then Continue, then the microphone prompt, then the speech prompt. Record: each screen seen. (Note: the explainer shows once only; a reset does not clear its flag, an uninstall does.)

**A7. Rerun iOS Step 3 (captions).** Action: after the Simulator shows "Listening" and the engine reports ready, speak a clear sentence near the Mac for about 10 s, pause, then a second sentence. Let the window run at least 60 s in total, because Apple's silence and timeout errors can arrive late. Expected: recognised text on screen; locale as expected (en-CA is the app default; if testing en-US, set it explicitly in Settings first); no SnackBar or toast; no chime or other app sound. Then tap Stop. Expected: a new transcript in History with `segmentCount` > 0. Record: text seen or not, locale shown, any toast, the History row.

**A8. If A3 and A4 pass but A7 still shows nothing.** Action: set the Simulator Settings, General, Language and Region to English (US) and repeat A7 (tests the en-CA hypothesis). If still nothing, record "on-device recognition not demonstrated on the Simulator" and move to a physical iOS 26 device. A diagnostic build (`onDevice: false` or a sound-level log line) would be decisive but is not made and needs your approval.

**A9. Rerun iOS Step 4 (language panel) and assumption A-1.** Only if the missing-language panel appears (on-device check false). Action: tap the Download button, watch progress, then Try again. Expected: download completes, panel shows "is ready", Try again starts captioning. Record: whether `supportsOnDeviceRecognition` became true after the download. If the panel does not appear, record "not reached". A-1 stays inconclusive on the Simulator.

**A10. Rerun iOS Step 5 (only if A7 passed).** (a) Continuous: speak across 2 minutes with pauses; text keeps coming, no chime. (b) Pause and resume: pause, wait, resume; captions continue. (c) Silent 10 s, then Stop: the notice "No speech was recognised, so no transcript was saved." appears and no transcript row is created. (d) Amendment 05: 5 minutes of silence stops the session with "Captioning stopped after 5 minutes without speech." (already passed on Android; optional here). Record each result.

---

## Part B: Android phone captions (Steps 6, 6b, 7, 8 and observations)

Precondition: Part 0.1 complete, language pack ready, app on the Home screen, microphone not yet granted.

**B0. Permission and start.** Action: tap Start Captioning, then "While using the app". Expected: no explainer on Android; captioning starts directly when the pack is installed; no failure panel, no toast. Record: screens seen and the locale shown.

**B1. Step 6: captions.** Action: wait until you see the recording controls (the recogniser is ready), then speak phrase 1 (one clear sentence, 5 s), pause 8 s, speak phrase 2. Expected: recognised text appears for both phrases; locale is the expected one; no SnackBar or toast; no engine error. Record: text seen (yes/no, roughly how soon after speaking), locale, any toast. Pass only if all four pass rules hold at the end of B3.

**B2. Step 6b: silence between phrases.** Action: after phrase 2, stay silent for 20 s, then speak phrase 3. Expected: captions continue after the silence with no new session started by the silence; no chime between phrases or during the silence. Record: chimes heard (count and when), text for phrase 3.

**B3. Sound budget (BR-U10-43).** Android may sound only on a user Start, Stop, Pause or Resume, on a renewal, and on a lasting or cap error; never on a pause in speech, a segment or silence. Action: during B1 and B2, count every sound and note when. Record: a list of sounds with times and what you were doing at each.

**B4. Step 7: Stop.** Action: tap Stop. Expected: one stop sound only; History opens; a new transcript with `segmentCount` > 0; the screen returns to its normal timeout (keep-screen-on cleared). Record: how many sounds you heard at Stop (one, or start and stop together), the History row text "Nm Ns · N segments".

**B5. Stop sound check.** Action: repeat a short session (Start, speak, Stop) three times. Expected: a single, consistent sound at Stop each time. Record: per run, one or two sounds.

**B6. Step 8: pause and resume.** Action: while captioning, tap Pause, wait 10 s, tap Resume, speak a phrase. Expected: one sound on Pause, one on Resume; captions continue after Resume; paused time does not count towards the 5-minute inactivity timer. Record: sounds heard, whether text resumed.

**B7. Amendment 06: Stop and Pause while speaking (BR-U10-55, 56).**
- **(a) Stop.** Action: speak one sentence and tap Stop while still finishing it, or straight after. Expected: the last phrase appears in the captions before the screen leaves, and in the saved transcript. History opens within about 1 s (at most 5 s, BR-U10-58).
- **(b) Pause.** Action: speak one sentence and tap Pause straight after. Expected: the phrase appears in the captions and is in the transcript after Stop.
- Repeat each three times.
- Record: for each run, whether the phrase was kept, and how long Stop took.

**B8. Review observation: quick pause and resume.** Action: pause and resume quickly three times in a row. Question: is there any extra chime beyond the expected sounds (one per tap)? Record: total sounds heard and expected count (six).

**B9. 5-minute renewal chime (D-2).** Action: start captioning and keep speaking across the 5-minute mark, with a short phrase every 30 to 60 s, for at least 11 minutes. Expected: one chime at each 5-minute renewal (about 5:00 and 10:00) and no other sounds; no missed words across a renewal; the app never stops itself while speech continues. Record: time of every chime; count; any word lost at a renewal. Also confirm the recogniser accepted 300,000 ms (no "too high" error; the app does not stop early).

**B10. Screen-on check.** Action: while captioning, leave the phone untouched for the normal timeout period. Expected: the screen stays on. After Stop, leave it again. Expected: the screen dims and locks at the normal timeout. Record: stays on during captioning (yes/no); times out after Stop (yes/no).

**B11. Amendment 05 (optional, 5 minutes of silence).** Action: start captioning and stay silent for 5 minutes. Expected: the session stops, History opens, the SnackBar "Captioning stopped after 5 minutes without speech." appears, then "No speech was recognised, so no transcript was saved." Record: time of stop and both notices.

**B12. Amendment 01 restart observations.** Record anything unexpected: gaps in words, repeated phrases after a renewal, any transient failure notice.

---

## Part C: Amendment 06 checks (decided 2026-10-29, section 6)

1. **Last phrase at Stop and Pause:** Part B7 on Android, and the same on iOS in A10(b) plus a Stop-while-speaking run.
2. **Recovery twice (BR-U10-57):** only if the app can provoke a recogniser failure through its own flows. There is no known way, so record "unit tests only" (TP-36) unless one turns up during the run.
3. **5 s Stop bound (BR-U10-58):** unit tests only (TP-37). It is not provoked on a device.
4. **Save outcomes (BR-U10-60):** a normal session shows no save notice. A silent session shows "No speech was recognised, so no transcript was saved." "The transcript could not be saved." is not provoked on a device.

**App state and logs:** read them through the Flutter MCP (`flutter-agent-lens`) connected to the debug run. Use it to read the resolved locale, engine events, errors and segment counts. Never use it to drive the app past a step the user couldn't take.

---

## Part D: Unit 9 agenda (decisions and NEEDS-JAMES items only)

Source: the Unit 9 feasibility report. This is an agenda, not a set of steps.

**Decisions that block Unit 9 runs**
- B1: macOS entitlements lack `com.apple.security.network.client` in both apps; every macOS network check fails until it is added (a repo change you must approve).
- B2: anonymous viewers cannot get ICE servers (`get_turn_credentials()` is for `authenticated` only). Decide: grant to anon, anonymous sign-in, or a STUN-only fallback.
- Broadcaster sign-in on the local stack: approve the Google OAuth config (client, compose env, redirect list) and do one Google sign-in on macOS in `zip_broadcast`; or approve a session-injection route over the VM service.
- B3 and B4: Coturn local config blocks app-level relay, and no way exists to force relay in the app. Decide whether to add a relay-only switch or use a phone hotspot or restricted network.
- B6: no real-protocol viewer swarm for the 50-viewer cap. Decide whether to build the harness or defer M3 and EC5.
- Whether to defer the two-hour run at capacity (M3) as not claimable.
- Windows and Linux broadcaster sign-in is unavailable today; sign-in checks are macOS-only.

**NEEDS-JAMES checks**
- EC1, EC2, EC3b, EC4, EC5, M1, M2, M3, M5 (signed-in broadcaster, a second device or Chrome, network toggling).
- EC6, U8-1 to U8-6 (second display, hot-plug, borderless window on three OSes, font, opacity, theme, output-off behaviour).
- AOT, AOT-FS, A7, B4 (pop-out above other windows, closing from the OS, foreign full-screen window as an accepted limitation).
- EC7 live-OBS follow-up (OBS install status unknown).
- R1: a phone viewer is Unit 13, out of Unit 9 scope.
- Accessibility permission for the driving host (A7, B4 cannot be driven without it).
