# Phase 1 — Core Captioning: Requirements Verification Questions

Please answer the following questions to clarify Phase 1 scope and priorities. Fill in the letter choice after each `[Answer]:` tag. If none of the options match, choose the last option (Other) and describe your preference.

---

## Question 1
The roadmap lists OBS WebSocket integration and browser source output under Phase 1 (Jordan's scenarios), but broadcasting transport (WebRTC, Supabase Realtime) is Phase 2. Should Phase 1 include the OBS/browser-source output targets, or defer all broadcast-specific outputs to Phase 2 and keep Phase 1 focused on local captioning + transcript management?

A) Include OBS WebSocket and browser source output in Phase 1 (Jordan can use Zip Broadcast for local captioning with OBS integration, even without remote viewers)
B) Defer all broadcast-specific outputs to Phase 2 (Phase 1 Zip Broadcast is captioning-only with on-screen display, identical to Zip Captions but desktop-focused)
C) Include OBS WebSocket only, defer browser source to Phase 2
D) Other (please describe after [Answer]: tag below)

[Answer]: A - the obs integration is independent of the user story where a user relies on zip captions app to view a broadcast. we need to update the `docs` folder documentation to clarify that.

---

## Question 2
The roadmap lists BLE local discovery under Phase 5 (dedicated phase), but Sam's S3.2 scenario (discovering local broadcast sessions) is referenced as Phase 1. Should Phase 1 include any BLE discovery work, or should Sam's scenario S3.2 be deferred entirely to Phase 5?

A) Defer all BLE discovery to Phase 5 — Phase 1 Sam only gets self-captioning (S3.1)
B) Include basic BLE advertising in Zip Broadcast and scanning in Zip Captions for Phase 1 (minimum viable local discovery)
C) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 3
The roadmap mentions research spikes 1.1 (Windows/Linux STT), 1.2 (system audio capture), and 1.3 (Whisper.cpp FFI). How should these spikes relate to Phase 1 construction units?

A) Complete all spikes before Phase 1 construction begins (separate spike units that inform design decisions)
B) Run spikes in parallel as early Phase 1 units, with platform STT implementations depending on spike outcomes
C) Fold spike work into the relevant construction units (e.g., Whisper.cpp investigation happens during the STT engine implementation unit)
D) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 4
For platform-native STT, the roadmap references both the `speech_to_text` pub.dev package and custom platform channels. Which approach for Phase 1?

A) Use the `speech_to_text` package as the primary platform-native engine wrapper (covers iOS, Android, macOS, web; evaluate Windows/Linux support from Spike 1.1)
B) Write custom platform channels for each platform from scratch (maximum control, no third-party dependency)
C) Use `speech_to_text` for mobile (iOS/Android), custom platform channels for desktop where the package falls short
D) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 5
The caption bus (ADR-008) defines an abstract `CaptionOutputTarget` interface. For Phase 1, which output targets are in scope beyond the on-screen renderer?

A) On-screen renderer + transcript file writer only (minimum for Phase 1 exit criteria)
B) On-screen renderer + transcript file writer + OBS WebSocket (if Q1 includes OBS)
C) On-screen renderer + transcript file writer + OBS WebSocket + browser source (full Phase 1 roadmap scope)
D) Other (please describe after [Answer]: tag below)

[Answer]: C

---

## Question 6
Transcript management: the roadmap specifies local storage with TXT, SRT, and VTT export formats. What local storage approach for the session history (list of past transcripts)?

A) SQLite database (structured queries, efficient for session listing/search, scales to thousands of transcripts)
B) JSON files on the local filesystem (one file per session, simple, no additional dependency)
C) SharedPreferences for metadata + individual transcript files on disk (hybrid: prefs for the session list, files for content)
D) Other (please describe after [Answer]: tag below)

[Answer]: A - we should update the `docs` to include a user story where a user can search through previously captured transcripts

---

## Question 7
Audio capture: the roadmap mentions microphone input, external microphone support, and audio level indicator. For Phase 1, should system audio capture (line-in, loopback) also be in scope for the broadcaster app?

A) Microphone input only for Phase 1 (system audio capture is complex per-platform and depends on Spike 1.2 results)
B) Microphone input for both apps + system audio capture for Zip Broadcast on platforms where it's straightforward (macOS/Windows)
C) Microphone input for both apps + full system audio capture investigation across all platforms
D) Other (please describe after [Answer]: tag below)

[Answer]: C

---

## Question 8
Platform priority for Phase 1 STT implementation. The exit criteria require mobile (iOS or Android) + desktop (macOS, Windows, or Linux). Given that Windows/Linux STT availability is uncertain (Spike 1.1), what's the platform delivery order?

A) iOS + Android + macOS first (platform-native STT known to work), then Windows/Linux based on spike results
B) Android + macOS first (faster iteration with local hardware), then iOS, then Windows/Linux
C) All platforms simultaneously (risk: Windows/Linux may block completion)
D) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 9
Screen wake lock: the roadmap requires this during active captioning. What behavior during the paused state?

A) Release wake lock when paused (save battery; user can see the pause indicator when they wake the screen)
B) Keep wake lock during paused state (user may glance at the screen to see the "paused" indicator; releasing could cause them to miss that captioning is paused)
C) Make it a user setting (default: release on pause)
D) Other (please describe after [Answer]: tag below)

[Answer]: C

---

## Question 10
The existing `RecordingState` sealed class has four variants (idle, recording, paused, stopped). Phase 1 needs to add segment data and pause events. Should the recording state carry the transcript data directly, or should transcript accumulation be a separate provider?

A) Separate `TranscriptProvider` that subscribes to the caption bus independently (clean separation: recording state manages the session lifecycle, transcript provider manages the accumulated text)
B) Recording state carries accumulated segments and pause events directly (single source of truth for the entire session)
C) Other (please describe after [Answer]: tag below)

[Answer]: A - it's possible that the recording and transcript processes can be in different states (e.g. recording active, transcription error)

---

## Question 11
The `SttEngine` interface in ADR-005 includes `pause()` and `resume()` methods. Some platform STT APIs do not support true pause — they only support stop and restart. How should the engine handle this?

A) Engines that lack native pause should stop/restart transparently (the `SttEngine` contract guarantees pause/resume from the caller's perspective, implementation details are hidden)
B) Engines should report their capabilities via a `supportsPause` flag, and the recording state notifier adapts behavior accordingly
C) Both — transparent fallback by default, but expose capability flags for UI hints (e.g., showing "pause may cause brief gap in captions" on engines that restart)
D) Other (please describe after [Answer]: tag below)

[Answer]: A - pause/resume is a meaningful distinction from stop/start in the context of the recorded transcript, where a pause implies a gap, and a stop implies the end of a transcript.

---

## Question 12
Web platform support: the roadmap mentions Web Speech API as "fallback, best-effort" for web. What's the Phase 1 web target?

A) Web is out of scope for Phase 1 (focus on native mobile + desktop; web deferred)
B) Web is best-effort — if `speech_to_text` or Web Speech API works, include it; don't spend time on web-specific workarounds
C) Web is a full target — ensure captioning works in Chrome/Edge/Safari with Web Speech API
D) Other (please describe after [Answer]: tag below)

[Answer]: B

---
