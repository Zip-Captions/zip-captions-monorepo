# Zip Captions v2 — User Personas

> **Document Status:** Draft v0.5
> **Last Updated:** 2026-03-26
> **Purpose:** Defines the user personas that drive all feature, architecture, and UX decisions for Zip Captions v2. Every user story, technical choice, and roadmap item must trace back to a persona and scenario defined here.

---

## Guiding Principles

### Accessibility Is Free
Any feature that enables a person to understand spoken language through text is a core accessibility feature and must never require payment, an account, or network connectivity.

### Transcription Data Belongs to the User
Zip Captions will never collect, analyze, store, access, or review any transcription content. Transcript data saved to any server must be encrypted with a key that never leaves the user's device, using a zero-knowledge architecture. Not even project maintainers can access transcript content. This is a foundational architectural constraint, not a policy — the system must be built such that accessing transcript content server-side is technically impossible.

### Privacy by Default, Security by Design
- No audio or text leaves the device unless the user explicitly opts in to a cloud STT provider
- Devices without authentication (no PIN, no biometrics) must not be permitted to save transcription data locally
- Security settings are strict by default; users may relax them, but the app must prevent configurations that would compromise transcript security
- Telemetry, if opted into, is limited to anonymized performance data (latency, settings, session duration) — never transcript content, never tied to user identity

### Platform Independence
Zip Captions will not depend on any single distribution platform. The project will not adopt business models that rely on predatory platform monopolies. If an app store's policies conflict with the project's values or payment model, the app will be distributed through alternative channels (PWA, sideloading, alternative stores). Core accessibility functionality must never be at risk due to platform gatekeeper disputes.

---

## Persona 1: Personal User ("Alex")

### Who They Are
Alex is a d/Deaf or hard-of-hearing individual who uses Zip Captions in everyday life. They may also be a hearing person who wants to provide captions for a d/Deaf or HoH family member, friend, or colleague. Alex is not necessarily technical — they need the app to work immediately with minimal setup.

### Primary Goal
See real-time text of what people around them are saying, on their own device, with zero friction.

### Environment & Constraints
- **Devices:** Smartphone (primary), tablet, laptop
- **Connectivity:** Unreliable or absent — Alex may be at a restaurant, outdoors, in a hospital waiting room, or at home with poor WiFi
- **Audio conditions:** Variable — quiet 1:1 conversations, noisy family dinners, background music, overlapping speakers
- **Privacy sensitivity:** High — conversations are personal; no audio or text should leave the device without explicit consent
- **Technical skill:** Low to moderate — should not need to configure anything to start captioning

### Scenarios

#### S1.1 — One-on-One Conversation
Alex is meeting a friend at a coffee shop. They place their phone on the table, tap one button, and spoken words appear as text. Background noise from the café is present. The friend speaks at a normal pace. Alex reads captions on the phone screen facing them.

**Key requirements:**
- Single-tap start
- Noise filtering / voice activity detection
- Low latency (< 1 second from utterance to text)
- Works offline using the device's native speech recognition
- Accessible typeface 
- Screen stays awake during captioning

#### S1.2 — Family Dinner Table
Alex places their phone in the center of the table. Multiple family members speak, sometimes overlapping. Alex wants to follow the conversation.

**Key requirements:**
- Multi-directional microphone capture (or ability to use external mic)
- Handles speaker changes without dropping utterances
- Visual distinction when speaker changes (not speaker identification — just a visual break or separator)
- Handles simultaneous/overlapping speech gracefully (even if imperfectly)
- Long-running session stability (1-2 hours without degradation)

#### S1.3 — Medical Appointment
Alex is at a doctor's office. The doctor explains a diagnosis. Alex needs accurate captions and may want to save or export the transcript afterward.

**Key requirements:**
- High accuracy for medical/technical vocabulary (user may select a cloud STT option for domain-specific models)
- Transcript saving and export (TXT, SRT, VTT)
- Transcription save/export is free — the content is accessibility-critical
- Clear indication of when captioning is active (for the doctor's awareness)

#### S1.4 — Providing Captions for Someone Else
Alex's hearing parent places the phone facing their deaf child at the table. The parent needs to set it up, but the child is the one reading.

**Key requirements:**
- Screen orientation lock or "kiosk mode" (prevent accidental navigation)
- Large, readable text with customizable size
- Auto-scroll behavior that doesn't require interaction from the reader
- Large print with text broken into easily readable chunks

#### S1.5 — Cross-Language Conversation
Alex is a teacher meeting with parents who are not proficient in the same language. They place the phone between them and enable conversation translation mode. The teacher speaks English; the parent speaks Spanish. Each sees the other's words translated into their language on screen, enabling a back-and-forth conversation despite the language barrier.

**Key requirements:**
- Bidirectional translation: each speaker's language is detected and translated to the other's selected language
- Low latency — translation must keep pace with conversation (combined STT + translation should feel near-real-time)
- Clear visual separation between "what was said" (source text) and "what it means" (translated text)
- Prominent disclaimer: "Source language: [detected]. Translation may be inaccurate."
- Works with on-device translation models where available (no cloud dependency for basic language pairs)
- Supports at minimum the common language pairs for the user's locale (e.g., English↔French for Québec, English↔Spanish for US)
- This is a free accessibility feature — language barriers are accessibility barriers

### What's Free vs. Premium for This Persona

| Feature | Tier | Notes |
|---------|------|-------|
| Real-time captioning (any available STT engine) | Free | |
| Offline captioning (platform-native or on-device model) | Free | |
| Text size, font, contrast customization | Free | |
| Screen wake lock | Free | |
| Transcript save/export (TXT, SRT, VTT) | Free | |
| Language/dialect selection | Free | |
| STT engine selection (switch between providers) | Free | |
| On-device conversation translation (basic language pairs) | Free | Accessibility — language barriers are accessibility barriers |
| Cloud-powered translation (higher quality, more language pairs) | Premium | Usage-based (requires cloud API) |
| Custom themes beyond accessibility defaults | Premium | One-time purchase (no recurring cost) |
| Trigger-word actions (e.g., highlight when a keyword is spoken) | Premium | One-time purchase |
| Animated text effects, decorative fonts | Premium | One-time purchase |
| Custom vocabulary / domain-specific model hints | Premium | One-time purchase if on-device; usage-based if cloud |

---

## Persona 2: Broadcaster ("Jordan")

### Who They Are
Jordan is a content creator, streamer, educator, or event organizer who needs to provide captions to an audience. Jordan may be a solo streamer on Twitch who can't afford a monthly captioning subscription, a teacher running a hybrid classroom, or an AV technician setting up captioning for a conference. Jordan is technically competent but time-constrained — setup should be straightforward and reliable once running.

A key insight: many streamers have a gaming computer that's one or two generations old sitting idle. Zip Captions can leverage that hardware for on-device STT processing, eliminating the need for expensive cloud subscriptions.

### Primary Goal
Capture speech and deliver captions to one or more output targets: an OBS browser source, a projected display, a remote viewer stream, or a chromakey-friendly window.

### Environment & Constraints
- **Devices:** Desktop/laptop (primary for streaming), possibly a dedicated captioning machine at an event
- **Connectivity:** Usually available, but core captioning should work without it
- **Audio conditions:** Controlled — dedicated microphone, possibly line-in from a mixer or PA system
- **Performance:** May be running on an older machine alongside streaming software; captioning must be lightweight
- **Output flexibility:** Needs multiple ways to get captions out of the app and into other tools

### Scenarios

#### S2.1 — Solo Streamer with OBS
Jordan streams on Twitch 3x/week. They want captions in their stream for accessibility. They connect Zip Captions to a Live Streaming tool, such as OBS via the OBS WebSocket protocol or add a browser source. Captions appear as an overlay on the stream.

**Key requirements:**
- OBS WebSocket integration (send captions as closed captions)
- VMix Support
- Browser source output (transparent background, customizable styling)
- Low CPU/memory footprint (running alongside a game + OBS + Discord)
- Ability to pause/resume captioning without stopping the stream
- Persistent configuration (remembers OBS connection settings)

#### S2.2 — Classroom / Hybrid Meeting
Jordan is a teacher with some remote students and in-person students. They want captions displayed on a second monitor in the classroom AND available to remote students on their own devices.

**Key requirements:**
- Second-screen / external display output
- Remote caption streaming (viewers discover and join available sessions)
- Low-latency delivery to remote viewers
- Works with external microphone / classroom audio system
- Text flow direction configurable (top-to-bottom or bottom-to-top) — critical for projected displays where the audience needs a specific reading direction

#### S2.3 — Conference / Auditorium (Deployment Mode)
An AV technician (or Jordan themselves) sets up captioning for a live event. A speaker presents to an audience. Captions appear on a projector or large display. This is a deployment mode of the broadcaster persona, not a separate persona — the same app, configured for large-venue use.

**Key requirements:**
- Pre-configurable profiles ("Event Mode" preset that a non-technical operator can activate)
- Line-in audio capture (from a mixer or PA system, not just a microphone)
- Large-format display output optimized for projection (high contrast, large text, minimal UI chrome)
- Text flow direction configurable for projection context
- Graceful handling of multiple speakers at a podium (speaker changes, panel discussions)
- Session recording / transcript export for event records

#### S2.4 — Remote Setup & Delegation
Jordan visits a venue, configures the captioning system for an upcoming event, saves the configuration as a named profile, and leaves. On the day of the event, on-site staff (who may not be technical) open the app, select the profile Jordan created, and tap "Start." Jordan monitors the system remotely from a different location. If something goes wrong, Jordan can see system status without being physically present.

**Key requirements:**
- Named configuration profiles (saveable, selectable by a non-technical operator)
- Configurable rooms and spaces which allow different speaker to present with captions without setup
- Minimal-interaction "operator mode" (prominent start/stop, status indicators, no access to settings)
- Remote status monitoring (is captioning active? errors? audio levels?)
- This is a premium feature — professional tooling, not core accessibility

#### S2.5 — Remote Captioning Machine
Jordan has a powerful desktop at home but the event is at a venue across town. Jordan configures their home machine to accept a remote audio stream from the venue, process it with a high-quality on-device STT model, and send the caption results back. The venue machine handles audio capture and caption display; Jordan's machine handles the compute.

**Key requirements:**
- Secure, private, end-to-end encrypted tunnel between two authenticated Zip Captions instances
- Audio stream from venue → processing machine, caption results back to venue
- Both machines must be logged into the same account (or authorized via a pairing mechanism)
- Handles network latency and intermittent connectivity gracefully
- This is a premium feature — requires account, facilitates professional/advanced workflows

#### S2.6 — Bilingual Broadcast Display
Jordan is running captioning for a school auditorium event in Québec. The audience is mixed between French and English speakers. The speaker presents in French. Jordan configures Zip Broadcast to display captions in both French (original) and English (translated) simultaneously on the projected display. Both languages appear on screen, clearly labeled, so all audience members can follow along.

**Key requirements:**
- Dual-language display: source language captions + translated captions shown simultaneously
- Clear visual labeling of which text is the original and which is the translation
- Prominent disclaimer on screen: "Source language: French. Translation may be inaccurate."
- Translation must keep pace with live speech (combined STT + translation latency must be acceptable for live viewing)
- Configurable layout for bilingual display (side-by-side, stacked, alternating lines)
- Works with on-device translation for common language pairs (English↔French)
- Cloud translation available as a premium option for higher quality or less common language pairs
- This display mode is a free accessibility feature when using on-device translation

### What's Free vs. Premium for This Persona

| Feature | Tier | Notes |
|---------|------|-------|
| Real-time captioning on device | Free | |
| OBS closed-caption integration (WebSocket) | Free | Accessibility — makes streams accessible |
| Browser source output (basic) | Free | Accessibility |
| Remote caption streaming (viewers join to read) | Free | Accessibility — extends captions to others |
| Text flow direction (top-to-bottom / bottom-to-top) | Free | Accessibility — needed for projection |
| Bilingual display with on-device translation | Free | Accessibility — serves multilingual audiences |
| Cloud-powered broadcast translation (higher quality, more pairs) | Premium | Usage-based (requires cloud API) |
| Custom overlay styling (colors, animations, positioning) | Premium | One-time purchase |
| Chromakey-optimized window output | Premium | One-time purchase |
| Configuration profiles / presets | Premium | One-time purchase |
| Operator mode (delegated event management) | Premium | One-time purchase |
| Remote status monitoring / debugging | Premium | Subscription or one-time (requires server infrastructure) |
| Remote captioning machine (off-site processing) | Premium | Subscription (requires relay infrastructure) |
| Trigger-word actions (sound effects, scene changes) | Premium | One-time purchase |
| Multi-input source management (switching between mics) | Premium | One-time purchase |
| Analytics (viewer count, session duration, word count) | Premium | One-time purchase |

### Future Concept: Community Hardware Sharing
Community members with capable hardware could volunteer processing time on a schedule, making high-quality on-device STT available to users whose own devices can't handle it. This would function as a donation/community feature — the inverse of a paid feature. It requires significant trust, privacy, and scheduling infrastructure, and is captured here as a future concept only. It must be designed with the same zero-knowledge principles: the volunteer machine processes audio but never stores or transmits transcript data except back to the requesting user.

---

## Persona 3: Student / Attendee ("Sam")

### Who They Are
Sam is a d/Deaf or hard-of-hearing student, meeting participant, or conference attendee who needs to follow along with what's being said. Sam may be in-person or remote. They are a *consumer* of captions, not a producer — someone else (a broadcaster, teacher, or event organizer) may be generating the captions, or Sam may be captioning for themselves.

### Primary Goal
Read captions in real-time, either self-generated from their own device's microphone or received from a nearby broadcaster's caption stream.

### Environment & Constraints
- **Devices:** Smartphone, tablet, or laptop. Sam may have a remote microphone.
- **Connectivity:** May or may not have internet; must still be able to discover and connect to local broadcast sessions
- **Audio conditions:** Sam is not controlling the audio environment — the speaker may be far away, there may be echo, the room may be noisy
- **Attention split:** Sam is also taking notes, watching a presentation, or looking at the speaker — captions need to be glanceable
- **Privacy:** Sam may not want others to know they're using captioning software

### Scenarios

#### S3.1 — Lecture Hall (Self-Captioning)
Sam is in a large lecture hall. The professor uses a microphone but Sam is far from the speakers. Sam opens the app on their phone and uses their own device mic to capture audio. The device's native speech recognition handles the processing.

**Key requirements:**
- Works with ambient/distant audio (not just close-talking into the mic)
- Handles echo and reverb from room acoustics
- Low power consumption for multi-hour lectures
- Discreet UI (doesn't draw attention from other students)
- Transcript save for later review

#### S3.2 — Discovering a Local Broadcast Session
Sam arrives at a conference. The conference has configured multiple captioning sessions (one per room/track). Sam opens the Zip Captions app, which discovers available broadcast sessions in the vicinity — no internet connection required, no join code needed. The app presents a list of named sessions (e.g., "Main Stage," "Room 201 — Panel Discussion"). Sam taps one and begins receiving live captions.

**Key requirements:**
- Local session discovery via BLE advertising (Auracast?) — the limited range is a feature, not a limitation, as it surfaces only the most proximal sessions (the ones Sam is physically near)
- Once discovered, caption data delivery may use BLE, local Wi-Fi, or internet depending on what's available — BLE handles discovery, the transport layer is separate
- Device does not need to be on the same Wi-Fi network as the broadcaster (but being on the same LAN is an optimization for higher-bandwidth delivery)
- No account required to view a broadcast
- Named sessions with descriptive titles (configured by the broadcaster)
- Handles temporary disconnections gracefully (reconnects without losing context)
- Text customization (Sam controls their own font size, contrast, flow direction, etc.)
- Works even if Sam's device has no internet connectivity, as long as BLE radio is active (not in airplane mode)

#### S3.3 — Remote Meeting
Sam is on a video call. They run Zip Captions alongside their meeting software to get captions of what others are saying through their device's speakers or a virtual audio device.

**Key requirements:**
- Ability to capture system audio (not just microphone input) — platform dependent
- Runs alongside video conferencing without excessive CPU/memory usage
- Handles multiple remote speakers

#### S3.4 — Viewer-Side Translation
Sam is attending a conference where the speaker presents in French. Sam's French is limited. Sam joins the broadcast caption stream and enables translation to English on their own device. The captions appear in English (translated), with the original French text shown smaller or toggleable. A disclaimer reads: "Source language: French. Translation may be inaccurate."

**Key requirements:**
- Viewer selects their preferred language independently of the broadcaster's configuration
- Translation happens on the viewer's device (not the broadcaster's) — does not add load to the broadcaster
- Source language and translated text are both available (viewer can toggle between them or see both)
- Disclaimer always visible when translation is active
- Works with on-device translation models for common language pairs
- Cloud translation available as a premium option for the viewer
- No account required for on-device translation; account required for cloud translation

#### S3.5 — Caption Overlay on Screen Share / Video
Sam is in a classroom where the teacher is projecting a video or sharing their screen. Sam wants captions overlaid directly on top of what's being displayed, so they don't have to look back and forth between the projected content and a separate captioning device. On their laptop, Sam enables the caption overlay mode, which displays a transparent always-on-top window with captions that floats over all other applications.

**Key requirements:**
- Transparent, always-on-top window that overlays captions on top of other applications (desktop platforms)
- Captions are positioned at the bottom of the screen (or user-configurable position)
- Overlay does not intercept mouse/keyboard input (click-through to applications beneath)
- Text size, font, contrast, and background opacity are customizable
- Works with both self-captioning (microphone input) and broadcast caption streams
- On mobile: platform-dependent (Android system overlay may be possible with SYSTEM_ALERT_WINDOW permission; iOS does not support third-party overlays — mobile falls back to split-screen or picture-in-picture if available)
- This is a premium feature on all platforms (convenience, not core accessibility — the non-overlay caption display remains free)

### What's Free vs. Premium for This Persona

| Feature | Tier | Notes |
|---------|------|-------|
| Self-captioning from device microphone | Free | |
| Discovering and joining local broadcast sessions | Free | |
| Text customization (size, font, contrast, flow direction) | Free | |
| Transcript save/export | Free | |
| System audio capture (where platform allows) | Free | Accessibility |
| Viewer-side on-device translation (basic language pairs) | Free | Accessibility — language barriers are accessibility barriers |
| Viewer-side cloud translation (higher quality, more pairs) | Premium | Usage-based (requires cloud API) |
| Caption overlay on top of other apps | Premium | One-time purchase |
| AI-powered summary of captured transcript | Premium | Usage-based (requires cloud processing) |
| Searchable transcript history across sessions | Premium | One-time purchase |

---

## Cross-Persona Requirements

These requirements apply regardless of persona and must be considered in every feature design.

### Accessibility Baseline (Always Free, Always Available)
- Real-time speech-to-text with < 1 second perceived latency
- Works offline using platform-native speech recognition or a bundled on-device model
- No account required for core captioning
- Text size, font family, line height, and contrast customization
- Text flow direction (top-to-bottom or bottom-to-top)
- Screen wake lock during active captioning
- Multiple language and dialect support
- Pause/resume without losing context
- Transcript save and export (TXT, SRT, VTT)

### Authentication & Account Features
- Users may sign in using an external OAuth provider (Google, Microsoft, Apple, etc.)
- Signing in unlocks optional features: settings sync, transcript backup, premium purchases, broadcast management
- No account is ever required for core captioning functionality
- Account deletion must be straightforward and must remove all server-side data

### Data Sync & Backup
- Signed-in users may opt in to sync settings and/or transcripts across devices
- Transcript data stored server-side must use zero-knowledge encryption: the encryption key is derived or stored on the client device and is never transmitted to the server
- The server stores only encrypted blobs; project maintainers cannot decrypt or access transcript content under any circumstances
- Sync is an opt-in convenience feature, not a default

### Telemetry & Analytics
- All telemetry is opt-in and clearly described to the user before activation
- Telemetry is limited to anonymized performance data: STT engine latency, session duration, app settings distribution, error rates, crash reports
- Telemetry data is never tied to a user identity — it is fully anonymized at the point of collection
- **Transcription content is never included in telemetry, analytics, crash reports, or any data sent off-device.** This is an absolute, non-negotiable constraint.

### Multi-Speaker Handling (All Personas)
- Graceful handling of speaker changes (visual break/separator in text)
- Best-effort concurrent speech handling (capture as much as possible, even if accuracy drops)
- No speaker identification by default (premium feature if technically feasible)
- Clear UX indication when the system is struggling with audio conditions
- Clear communication of English/French English/Spanish models which support bilingual communication

### STT Engine Strategy
- **Default: Platform-native offline API** — Apple Speech Recognition on iOS/macOS, Google on-device speech on Android. This is the zero-configuration, works-out-of-the-box option for non-technical users who want the best possible quality without configuring anything.
- **Alternative on-device models:** User may select Whisper.cpp, Vosk, Hugging Face models, or other on-device providers if they prefer different accuracy/performance/privacy tradeoffs.
- **Online option (free):** A cloud STT provider available for users who want it and have connectivity. Must be clearly labeled as sending audio to an external server.
- **Online option (premium):** High-accuracy cloud STT (Azure, Google Cloud, etc.) with usage-based billing for users who need domain-specific or highest-quality recognition.
- User can select and switch between available engines at any time.
- Engine selection is saved per-configuration-profile.

### Translation Strategy
- **Default: Platform-native on-device translation** — Google ML Kit on Android (50+ languages), Apple Translation on iOS/macOS. Free, on-device, no cloud dependency for supported language pairs.
- **Desktop gap:** Windows and Linux lack platform-native translation APIs. Strategy: bundle open-source translation models (e.g., NLLB, Helsinki-NLP) via FFI, or leverage Chrome's Translator API for web builds. This requires investigation during implementation.
- **Cloud option (premium):** High-quality cloud translation (Google Cloud Translation, DeepL) for language pairs not supported on-device, or when on-device quality is insufficient. Usage-based billing.
- **Translation disclaimer:** All translated text must display a prominent, persistent disclaimer: "Source language: [detected language]. Translation may be inaccurate." This disclaimer cannot be hidden or dismissed — it is always visible when translation is active.
- **Three distinct language lists exist and may not fully overlap:** (1) UI localization languages (app interface), (2) STT recognition languages (speech engine input), (3) translation target languages (output translation). The app must handle gaps gracefully (e.g., "Translation to Polish is not available on this device").
- On-device translation is a free accessibility feature. Cloud translation is premium (usage-based cost).

### Premium Feature Payment Model
- Features that do not incur ongoing server/cloud costs are offered as **one-time purchases**
- Features that require ongoing infrastructure (remote captioning relay, cloud STT, remote monitoring) are offered as **subscriptions or usage-based billing**
- **Interim payment:** Patreon API integration for supporter tiers and entitlements until dedicated payment processing is implemented
- **Target payment processing:** Stripe or equivalent Canadian-compatible processor, handled outside app store channels to avoid platform commissions
- **App store contingency:** If Apple or Google refuse to list the app due to external payment references, the fallback strategy is: (1) distribute core Zip Captions as a free app with no premium features through app stores, (2) offer premium features through a separate companion app distributed outside app stores or via alternative stores, and/or (3) direct users to install the PWA version which is not subject to app store policies. We will not adopt business models that rely on predatory platform monopolies.
- The core accessibility app must never be at risk due to payment model disputes with platform gatekeepers

### Device Security Requirements
- Devices without any authentication mechanism (no PIN, no passcode, no biometrics) must not be permitted to save transcription data to local storage
- The app should detect device security posture and warn or restrict accordingly
- Users may relax security settings (e.g., disable biometric lock for transcript viewing) but the app must prevent configurations that would leave transcript data unprotected on an unsecured device

---

## Document Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-03-25 | 0.1 | Initial draft — 3 active personas, 1 parked, auditorium as deployment mode |
| 2026-03-25 | 0.2 | Corrected text flow (projection context, not screen flip). Added one-time purchase model for non-recurring-cost premium features with out-of-store payment. Added remote captioning machine scenario (S2.5). Added community hardware sharing as future concept. Clarified S2.4 (Jordan configures on-site, monitors remotely during event). Rewrote S3.2 as local session discovery (no internet, no join code — proximity-based). Added authentication, sync, zero-knowledge encryption requirements. Added telemetry principles with hard constraint on transcript content exclusion. Changed STT strategy to platform-native-first. Added device security requirements. Removed interpreter persona. |
| 2026-03-25 | 0.3 | Confirmed BLE as local discovery mechanism (limited range is a feature). Added Patreon API as interim payment integration. Added app store contingency strategy (free core app in stores, premium via separate app/PWA/alternative stores if needed). Added Platform Independence guiding principle. |
| 2026-03-26 | 0.4 | Added translation scenarios: S1.5 (cross-language conversation), S2.6 (bilingual broadcast display), S3.4 (viewer-side translation). Added Translation Strategy to cross-persona requirements. Updated free/premium matrices for all personas with on-device translation (free) and cloud translation (premium). All translations require persistent "may be inaccurate" disclaimer. |
| 2026-03-26 | 0.5 | Added S3.5 (caption overlay on screen share/video — desktop overlay window, premium feature). |
