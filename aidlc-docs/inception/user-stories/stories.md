# Phase 1 User Stories — Core Captioning

## Organization

Stories are organized by **feature area** (Q1: B), at **coarse granularity** — one story per FR group (Q2: A). **Scenario-level integration milestones** validate end-to-end persona workflows (Q3: C). **UI design prototype stories** are separate per screen and block the corresponding implementation stories (Q6: A). All acceptance criteria use **Given/When/Then** format (Q4: A). Research spikes are not stories — they are referenced as dependencies only (Q5: A).

---

## Feature Stories

### S-01: STT Engine Interface and Registry
**Feature Area:** STT | **FR:** FR-1 | **Package:** zip_core
**Personas:** Alex, Jordan, Sam (all)

> As a user, I need a pluggable speech-to-text engine system so that I can use the best available STT option for my platform and preferences.

**Acceptance Criteria:**

```gherkin
Given the app starts on any supported platform
When the SttEngineRegistry is initialized
Then at least one SttEngine is registered and available

Given multiple STT engines are registered
When the user views the engine selection list
Then each engine shows its displayName, requiresNetwork, and requiresDownload status

Given an SttEngine is selected
When initialize() is called with a valid localeId
Then the engine is ready to accept audio input

Given an SttEngine is listening
When speech is detected
Then the engine emits SttResult events with text, isFinal, confidence, and timestamp fields

Given an SttEngine does not support native pause
When pause() is called
Then the engine transparently stops and resumes on resume(), preserving pause semantics in the transcript

Given an SttEngine is active
When dispose() is called
Then all resources are released and no further events are emitted
```

**Note:** SttResult must carry a source identifier so that results from multiple simultaneous engines/inputs can be distinguished (see S-06 multi-input).

**Dependencies:** Spike 1.1 (informs which engines are available on Windows/Linux)

---

### S-02: Platform-Native STT Implementation
**Feature Area:** STT | **FR:** FR-2 | **Package:** zip_core, platform code
**Personas:** Alex, Jordan, Sam (all)

> As a user, I need platform-native speech recognition to work out of the box so that I can start captioning without downloading models or configuring anything.

**Acceptance Criteria:**

```gherkin
Given the app is running on iOS or macOS
When the platform-native STT engine is selected
Then Apple Speech Recognition is used via the speech_to_text package

Given the app is running on Android
When the platform-native STT engine is selected
Then Google on-device speech recognition is used via the speech_to_text package

Given the app is running on a Tier 2 platform (Windows or Linux)
When the user opens the engine selection
Then the available engines reflect the Spike 1.1 findings for that platform

Given the app is running on the web
When the Web Speech API is available in the browser
Then the platform-native engine uses it on a best-effort basis

Given the user selects a language/locale
When the engine supports that locale
Then captioning uses the selected locale

Given the user selects a language/locale
When the engine does not support that locale
Then the user sees a clear message and the locale selection falls back to the closest available match
```

**Dependencies:** Spike 1.1 (Tier 2 platforms), Spike 1.3 (if Spike 1.1 recommends an on-device model)

---

### S-03: Caption Bus
**Feature Area:** Caption Pipeline | **FR:** FR-3 | **Package:** zip_core
**Personas:** Alex, Jordan, Sam (all)

> As a developer, I need a pub-sub caption bus so that STT results are delivered to multiple independent output targets without coupling.

**Acceptance Criteria:**

```gherkin
Given the caption bus is initialized
When an SttEngine publishes an SttResult
Then all subscribed CaptionOutputTargets receive the result

Given multiple output targets are subscribed (e.g., renderer, transcript writer, OBS)
When an SttResult is published
Then each target receives the result independently and a failure in one target does not affect others

Given a new CaptionOutputTarget is created
When it subscribes to the bus
Then it receives all subsequent SttResults without any changes to existing code

Given the recording state changes (start, pause, resume, stop)
When onSessionStateChange is called on the bus
Then all subscribed targets receive the state change notification

Given a CaptionOutputTarget is disposed
When subsequent SttResults are published
Then the disposed target does not receive them and no errors occur

Given multiple audio inputs are active simultaneously (Zip Broadcast multi-input)
When each input publishes SttResults with distinct source identifiers
Then all subscribed targets receive results from all sources with source metadata preserved
```

---

### S-04: Caption Rendering UI
**Feature Area:** Caption Display | **FR:** FR-4 | **Package:** zip_captions, zip_broadcast
**Personas:** Alex (S1.1, S1.2), Jordan (S2.1, S2.2), Sam (S3.1)

> As a user, I need to see live captions on screen with configurable appearance so that I can read speech as text in a way that suits my needs.

**Acceptance Criteria:**

```gherkin
Given captioning is active
When the STT engine emits results
Then captions appear on screen within 1 second of the utterance

Given the user has configured text size via CaptionTextSize setting
When captions are rendered
Then text displays at the configured size

Given the user has configured a CaptionFont
When captions are rendered
Then text displays in the configured font family

Given the user has set scroll direction to bottom-to-top
When new captions arrive
Then new text appears at the bottom and older text scrolls upward

Given the user has set scroll direction to top-to-bottom
When new captions arrive
Then new text appears at the top and older text scrolls downward

Given the STT engine detects a speaker change (pause or speakerTag change)
When the next SttResult arrives
Then a visual break or separator is rendered between the segments

Given multiple audio inputs are active (Zip Broadcast multi-input)
When SttResults arrive from different sources
Then each source's captions are rendered with a visually distinct style (e.g., color, label, or position) as configured by the user

Given captioning is active
When the screen wake lock setting is enabled
Then the device screen does not turn off

Given captioning is paused
When the wake lock release-on-pause setting is enabled (default)
Then the wake lock is released

Given captioning is paused
When the wake lock release-on-pause setting is disabled
Then the wake lock remains active

Given captioning is active
When audio is being captured
Then an audio level indicator is visible in the UI
```

---

### S-05: Transcript Management
**Feature Area:** Transcripts | **FR:** FR-5 | **Package:** zip_core, zip_captions, zip_broadcast
**Personas:** Alex (S1.3), Sam (S3.1)

> As a user, I need to save, search, and export my caption transcripts so that I can review what was said after a session ends.

**Acceptance Criteria:**

```gherkin
Given the user has enabled transcript capture in settings
When captioning is active and the TranscriptProvider receives SttResults from the caption bus
Then it accumulates text segments with timestamps independently of the recording state

Given the user has disabled transcript capture in settings
When captioning is active
Then no transcript data is accumulated or persisted (captions are displayed live but not retained)

Given transcript capture is enabled and the recording state has an error
When the TranscriptProvider is operating normally
Then transcript accumulation continues unaffected (independent error states)

Given transcript capture is enabled and a captioning session has ended (stopped)
When the session ends
Then the session metadata (date, duration, word count, language, engine) and transcript content are automatically persisted to the SQLite database

Given saved transcripts exist
When the user opens the session history screen
Then transcripts are listed with date, duration, and word count

Given the user enters a search query on the session history screen
When the query is submitted
Then FTS5 full-text search returns matching transcripts ranked by BM25 relevance

Given a saved transcript is selected
When the user chooses to export
Then the transcript is available in TXT, SRT, and VTT formats via the platform share sheet

Given the recording is paused and then resumed
When the transcript is saved
Then pause events are recorded in the transcript with timestamps
```

**Note:** Searchable transcript history is listed as Premium for Sam in the personas document. The search capability itself is built in Phase 1; the entitlement gate is enforced in Phase 4.

---

### S-06: Audio Capture
**Feature Area:** Audio | **FR:** FR-6 | **Package:** zip_core, platform code
**Personas:** Alex (S1.1, S1.2), Jordan (S2.1, S2.2), Sam (S3.1, S3.3)

> As a user, I need the app to capture audio from my microphone and system audio sources so that spoken words can be converted to text.

**Acceptance Criteria:**

```gherkin
Given the app is launched for the first time
When captioning is started
Then the platform microphone permission dialog is shown

Given microphone permission is granted
When captioning starts
Then audio is captured from the default microphone

Given microphone permission is denied
When captioning is attempted
Then the app shows a clear message explaining that microphone access is required and how to enable it

Given an external microphone is connected (USB or Bluetooth)
When the user opens the audio source selector
Then the external microphone appears in the list and can be selected

Given the app is running on a platform with system audio capture support
When the user selects a system audio source (loopback, line-in)
Then system audio is captured and passed to the STT engine

Given the app is running on a platform where system audio capture is not available
When the user opens the audio source selector
Then system audio options are not shown (graceful absence, not an error)

Given the user is in Zip Broadcast
When the user configures multiple audio inputs
Then each input can be assigned a speaker label and visual style (color or indicator)

Given multiple audio inputs are active in Zip Broadcast
When each input captures audio simultaneously
Then each input runs its own STT engine instance and publishes SttResults with a distinct source identifier

Given the user removes an active audio input from the multi-input configuration
When the input is removed
Then its STT engine instance is stopped and disposed, and its captions stop appearing
```

**Dependencies:** Spike 1.2 (system audio capture feasibility per platform)

---

### S-07: OBS WebSocket Integration
**Feature Area:** OBS Output | **FR:** FR-7 | **Package:** zip_broadcast
**Personas:** Jordan (S2.1)

> As a broadcaster, I need to send captions to OBS via WebSocket so that my live stream includes closed captions for accessibility.

**Acceptance Criteria:**

```gherkin
Given the user has configured OBS connection settings (host, port, password)
When the OBS output target is enabled
Then a WebSocket connection is established to OBS

Given the OBS WebSocket connection is active
When the caption bus publishes an SttResult
Then the OBS output target sends the caption text as closed captions to OBS

Given the OBS WebSocket connection fails
When the user views the recording screen
Then an OBS connection error indicator is visible

Given the OBS WebSocket connection drops during a session
When the connection is re-established
Then caption delivery to OBS resumes without user intervention

Given the user has saved OBS connection settings
When the app is restarted
Then the OBS settings are persisted and available
```

---

### S-08: Browser Source Output
**Feature Area:** Browser Source | **FR:** FR-8 | **Package:** zip_broadcast
**Personas:** Jordan (S2.1, S2.2)

> As a broadcaster, I need a browser source URL that serves a caption overlay page so that I can add captions to OBS, VMix, or a projected display via a browser window.

**Acceptance Criteria:**

```gherkin
Given captioning is active in Zip Broadcast
When the browser source output target is enabled
Then a local HTTP server starts serving a caption overlay page

Given the browser source server is running
When a browser navigates to the browser source URL
Then captions appear in real time on a transparent background

Given the user has configured text appearance settings
When the browser source page renders captions
Then text size, font, and contrast reflect the configured settings

Given captions are being rendered on the browser source page
When new caption text arrives
Then the most recent two lines of text are visible in a fixed position within the viewport
And text does not scroll or shift position as new text replaces old text
And the layout is suitable for embedding in a fixed-size OBS browser source or projection viewport

Given the browser source URL is displayed in the Zip Broadcast UI
When the user taps the URL
Then it is copied to the clipboard

Given captioning is stopped
When the browser source server is active
Then the overlay page shows an idle/stopped state
```

---

### S-09: Zip Captions App UI
**Feature Area:** App UI | **FR:** FR-9 | **Package:** zip_captions
**Personas:** Alex (S1.1-S1.3), Sam (S3.1)

> As a personal user, I need a simple app interface to start captioning, adjust settings, view transcripts, and export them so that I can use captions in everyday situations with minimal friction.

**Acceptance Criteria:**

```gherkin
Given the user opens the Zip Captions app
When the home screen loads
Then a prominent start-captioning button is visible (single-tap start)

Given the user taps start
When microphone permission is granted
Then the recording screen appears with live captions, pause/resume/stop controls, and an audio level indicator

Given the user taps the settings icon
When the settings screen loads
Then options are available for: STT engine, language/locale, text size, font, contrast/theme, scroll direction, wake lock behavior, audio source, and transcript capture (on/off)

Given the user taps stop on the recording screen and transcript capture is enabled
When the session ends
Then the transcript is automatically saved and the user can view it in session history

Given the user taps stop on the recording screen and transcript capture is disabled
When the session ends
Then no transcript is saved and the session returns to idle

Given the user navigates to session history
When transcripts have been saved
Then a searchable list of past sessions is displayed with date, duration, and word count

Given the user selects a transcript
When the transcript viewer opens
Then the full transcript text is displayed with an export/share button

Given the user taps export
When the share sheet appears
Then TXT, SRT, and VTT format options are available
```

**Blocked by:** Proto-01 through Proto-05 (all Zip Captions prototype stories)

---

### S-10: Zip Broadcast App UI
**Feature Area:** App UI | **FR:** FR-10 | **Package:** zip_broadcast
**Personas:** Jordan (S2.1, S2.2)

> As a broadcaster, I need a desktop-focused interface to start captioning with OBS integration, browser source output, and audio source selection so that I can provide captions to my audience.

**Acceptance Criteria:**

```gherkin
Given the user opens the Zip Broadcast app
When the home screen loads
Then a start-captioning button is visible

Given the user taps start
When captioning begins
Then the recording screen shows live captions, pause/resume/stop controls, OBS connection status, and browser source URL

Given the user opens settings
When the settings screen loads
Then options include: STT engine, language/locale, text appearance, OBS connection (host/port/password), output target toggles (on-screen, OBS, browser source), audio source selection, and transcript capture (on/off)

Given the user opens the audio source configuration
When microphones and system audio sources are available
Then all available sources are listed, and the user can add multiple inputs simultaneously

Given the user has configured multiple audio inputs
When each input is assigned a speaker label and visual style
Then the recording screen renders each source's captions with the configured visual distinction

Given the user opens the audio source configuration
When an input is added
Then the user can assign a speaker name/label and select a visual style (color or indicator) for that input

Given OBS output is enabled and connected
When the recording screen is visible
Then an OBS status indicator shows the connection state (connected, disconnected, error)

Given browser source output is enabled
When the recording screen is visible
Then the browser source URL is displayed and copyable

Given the user enables caption overlay mode
When a target display is selected (second monitor, projector, or specific application window)
Then a transparent always-on-top caption window renders over the target content
And the overlay position is configurable (bottom, top, or custom)
And the overlay does not intercept mouse or keyboard input (click-through)

Given the caption overlay is active on a second display
When new captions arrive
Then they render on the target display, not the primary screen
```

**Blocked by:** Proto-06 through Proto-09 (all Zip Broadcast prototype stories)

---

## UI Design Prototype Stories

Each prototype is a standalone HTML/CSS file demonstrating the screen design in both light and dark themes with responsive layout. Prototype approval is required before the corresponding implementation story can begin.

### Proto-01: Zip Captions — Home Screen
**Screen:** Home / launch screen | **App:** zip_captions
**Blocks:** S-09

```gherkin
Given the prototype HTML file is opened in a browser
When the home screen design is displayed
Then a prominent single-tap start button is visible
And the design works at mobile and desktop widths
And a theme toggle switches between light and dark themes
```

### Proto-02: Zip Captions — Recording Screen
**Screen:** Active captioning | **App:** zip_captions
**Blocks:** S-09

```gherkin
Given the prototype HTML file is opened in a browser
When the recording screen design is displayed
Then live caption text area, pause/resume/stop controls, and audio level indicator are visible
And text appearance reflects configurable size, font, and scroll direction
And speaker change visual breaks are demonstrated
And the paused state variant is shown
```

### Proto-03: Zip Captions — Settings Screen
**Screen:** Settings | **App:** zip_captions
**Blocks:** S-09

```gherkin
Given the prototype HTML file is opened in a browser
When the settings screen design is displayed
Then sections for STT engine, language/locale, text appearance (size, font, contrast, direction), wake lock behavior, and audio source are shown
And interactive controls demonstrate the setting options
```

### Proto-04: Zip Captions — Session History
**Screen:** Transcript list with search | **App:** zip_captions
**Blocks:** S-09

```gherkin
Given the prototype HTML file is opened in a browser
When the session history design is displayed
Then a search bar and list of session cards (date, duration, word count) are visible
And search results filtering is demonstrated
And empty state (no transcripts) is shown
```

### Proto-05: Zip Captions — Transcript Viewer
**Screen:** Individual transcript detail | **App:** zip_captions
**Blocks:** S-09

```gherkin
Given the prototype HTML file is opened in a browser
When the transcript viewer design is displayed
Then full transcript text with timestamps and pause markers is shown
And export/share button is visible
And format selection (TXT, SRT, VTT) is demonstrated
```

### Proto-06: Zip Broadcast — Home Screen
**Screen:** Home / launch screen | **App:** zip_broadcast
**Blocks:** S-10

```gherkin
Given the prototype HTML file is opened in a browser
When the home screen design is displayed
Then a start-captioning button and output target summary are visible
And the design works at desktop widths
And a theme toggle switches between light and dark themes
```

### Proto-07: Zip Broadcast — Recording Screen
**Screen:** Active captioning with outputs | **App:** zip_broadcast
**Blocks:** S-10

```gherkin
Given the prototype HTML file is opened in a browser
When the recording screen design is displayed
Then live caption area, controls, OBS status indicator, browser source URL, caption overlay toggle, and audio level indicator are visible
And the OBS connected/disconnected/error states are demonstrated
And multi-input captions are shown with visually distinct styles per source (color, label)
And the caption overlay configuration (target display, position) is accessible
```

### Proto-08: Zip Broadcast — Settings Screen
**Screen:** Settings with OBS and output config | **App:** zip_broadcast
**Blocks:** S-10

```gherkin
Given the prototype HTML file is opened in a browser
When the settings screen design is displayed
Then sections for STT engine, language/locale, text appearance, OBS connection settings, output target toggles, and audio source selection are shown
```

### Proto-09: Zip Broadcast — Audio Source Configuration
**Screen:** Multi-input audio source configuration | **App:** zip_broadcast
**Blocks:** S-10

```gherkin
Given the prototype HTML file is opened in a browser
When the audio source configuration design is displayed
Then the multi-input interface is shown: add/remove inputs, each with source selector, speaker label, and visual style (color/indicator)
And a list of available microphones and system audio sources is shown per input
And the empty state (no system audio available) is demonstrated
And the single-input default state is shown
```

---

## Scenario Integration Milestones

These are end-to-end acceptance tests that validate complete persona workflows. They are not implementation units — they compose multiple feature stories into scenario-level verification.

### M-S1.1: Alex — One-on-One Conversation
**Persona:** Alex | **Scenario:** S1.1
**Composed from:** S-01, S-02, S-03, S-04, S-06, S-09

```gherkin
Given Alex opens Zip Captions on a mobile device (iOS or Android)
When Alex taps start and speaks into the microphone
Then live captions appear on screen within 1 second
And the device screen stays awake
And no audio or text data leaves the device
And captioning works without an internet connection
```

### M-S1.2: Alex — Family Dinner
**Persona:** Alex | **Scenario:** S1.2
**Composed from:** S-01, S-02, S-03, S-04, S-06, S-09

```gherkin
Given Alex starts a captioning session at a dinner table
When multiple people speak over a 1-2 hour period
Then captions continue without degradation in performance or memory usage
And speaker changes produce visual breaks in the caption display
And the app handles overlapping speech gracefully (best-effort)
```

### M-S1.3: Alex — Medical Appointment
**Persona:** Alex | **Scenario:** S1.3
**Composed from:** S-01, S-02, S-03, S-04, S-05, S-06, S-09

```gherkin
Given Alex has completed a captioning session at a medical appointment
When Alex taps stop and chooses to save
Then the transcript is persisted to the local database with session metadata
And Alex can export the transcript in TXT format via the share sheet
And the exported transcript includes timestamps and pause markers
```

### M-S2.1: Jordan — Solo Streamer with OBS
**Persona:** Jordan | **Scenario:** S2.1
**Composed from:** S-01, S-02, S-03, S-04, S-06, S-07, S-08, S-10

```gherkin
Given Jordan opens Zip Broadcast on a desktop and configures OBS connection settings
When Jordan starts captioning and speaks
Then captions appear on screen in Zip Broadcast
And captions are sent to OBS as closed captions via WebSocket
And the browser source URL serves a live caption overlay page
And CPU/memory usage remains low alongside OBS
And Jordan can pause and resume captioning without stopping the stream
```

### M-S2.2: Jordan — Classroom
**Persona:** Jordan | **Scenario:** S2.2
**Composed from:** S-01, S-02, S-03, S-04, S-06, S-08, S-10

```gherkin
Given Jordan starts captioning in a classroom with an external microphone
When Jordan uses the browser source as a standalone fullscreen page on the projector
Then captions appear on the projected display with no other UI chrome
And text flow direction is configurable (critical for projection readability)
And the external microphone is selectable from the audio source list

Given Jordan is projecting content (slides, a browser tab, or a video) on a second display
When Jordan enables the caption overlay mode
Then a transparent always-on-top caption window appears over the projected content
And captions are readable without obscuring the underlying content
And the overlay position is configurable (bottom, top, or custom)

Given Jordan is mirroring or extending their display to a projector
When the caption overlay is active
Then the overlay renders on the target display (not just the primary screen)
And the overlay does not intercept mouse or keyboard input (click-through)

Given Jordan configures multiple audio inputs (e.g., teacher mic + student mic)
When both inputs are active with assigned speaker labels
Then captions from each source appear with visually distinct styles on the projected display
```

### M-S3.1: Sam — Lecture Hall Self-Captioning
**Persona:** Sam | **Scenario:** S3.1
**Composed from:** S-01, S-02, S-03, S-04, S-05, S-06, S-09

```gherkin
Given Sam opens Zip Captions in a lecture hall
When Sam starts captioning using the device microphone
Then captions of the professor's speech appear (ambient audio, best-effort)
And the UI is discreet (minimal visual footprint)
And Sam can save the transcript for later review
And power consumption remains acceptable for a multi-hour session
```

---

## Traceability Matrix

| Story | FR | Personas | Milestones |
|-------|-----|----------|------------|
| S-01 | FR-1 | Alex, Jordan, Sam | M-S1.1, M-S1.2, M-S1.3, M-S2.1, M-S2.2, M-S3.1 |
| S-02 | FR-2 | Alex, Jordan, Sam | M-S1.1, M-S1.2, M-S1.3, M-S2.1, M-S2.2, M-S3.1 |
| S-03 | FR-3 | Alex, Jordan, Sam | M-S1.1, M-S1.2, M-S1.3, M-S2.1, M-S2.2, M-S3.1 |
| S-04 | FR-4 | Alex, Jordan, Sam | M-S1.1, M-S1.2, M-S1.3, M-S2.1, M-S2.2, M-S3.1 |
| S-05 | FR-5 | Alex, Sam | M-S1.3, M-S3.1 |
| S-06 | FR-6 | Alex, Jordan, Sam | M-S1.1, M-S1.2, M-S2.1, M-S2.2, M-S3.1 |
| S-07 | FR-7 | Jordan | M-S2.1 |
| S-08 | FR-8 | Jordan | M-S2.1, M-S2.2 |
| S-09 | FR-9 | Alex, Sam | M-S1.1, M-S1.2, M-S1.3, M-S3.1 |
| S-10 | FR-10 | Jordan | M-S2.1, M-S2.2 |
| Proto-01..05 | FR-11 | Alex, Sam | Blocks S-09 |
| Proto-06..09 | FR-11 | Jordan | Blocks S-10 |

---

## Story Dependencies and Sequencing

```
Spike 1.1 ──► Spike 1.3 ──► S-02 (Platform STT)
Spike 1.2 ──────────────────► S-06 (Audio Capture)

S-01 (STT Interface) ──► S-02 (Platform STT)
S-01 ──► S-03 (Caption Bus)
S-03 ──► S-04 (Rendering)
S-03 ──► S-05 (Transcripts)
S-03 ──► S-07 (OBS)
S-03 ──► S-08 (Browser Source)

Proto-01..05 ──► S-09 (Zip Captions UI)
Proto-06..09 ──► S-10 (Zip Broadcast UI)

S-02 + S-04 + S-06 + S-09 ──► M-S1.1 (Alex conversation)
M-S1.1 ──► M-S1.2 (Alex family dinner — adds long session)
M-S1.1 + S-05 ──► M-S1.3 (Alex medical — adds transcript)
S-07 + S-08 + S-10 ──► M-S2.1 (Jordan OBS)
S-08 + S-10 ──► M-S2.2 (Jordan classroom)
S-02 + S-04 + S-05 + S-06 + S-09 ──► M-S3.1 (Sam lecture)
```

---

## INVEST Compliance

| Criterion | Assessment |
|-----------|-----------|
| **Independent** | Each feature story can be developed and tested independently. Prototype stories are independent per screen. Milestones are integration verification, not implementation units. |
| **Negotiable** | Acceptance criteria define what, not how. Implementation details are deferred to construction. |
| **Valuable** | Each feature story delivers user-visible or developer-enabling value. Milestones validate end-to-end persona value. |
| **Estimable** | Coarse granularity (one per FR group) maps to known technical scope from requirements analysis. |
| **Small** | At coarse granularity, stories are larger than typical agile stories but appropriate for AI-DLC construction units where each story maps to a design-implement-test cycle. |
| **Testable** | All acceptance criteria are Given/When/Then, directly translatable to automated tests. |
