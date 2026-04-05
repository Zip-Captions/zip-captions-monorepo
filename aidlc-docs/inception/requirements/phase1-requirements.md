# Phase 1 Requirements — Core Captioning

## Intent Analysis

- **User Request**: Build Phase 1 (Core Captioning) per the project roadmap
- **Request Type**: New Feature (multiple components, multi-platform)
- **Scope**: System-wide — changes across zip_core, zip_captions, zip_broadcast, plus platform-native code
- **Complexity**: Complex — multiple STT engine integrations, 6 target platforms, caption bus architecture, transcript storage, OBS integration, browser source server
- **Requirements Depth**: Comprehensive

---

## Functional Requirements

### FR-1: STT Engine Interface and Registry

**FR-1.1**: `SttEngine` abstract class in zip_core defining the contract for all speech-to-text engines per ADR-005. Methods: `isAvailable()`, `initialize()`, `startListening()`, `stopListening()`, `pause()`, `resume()`, `dispose()`. Properties: `engineId`, `displayName`, `requiresNetwork`, `requiresDownload`.

**FR-1.2**: `SttResult` model in zip_core with fields: `text`, `isFinal`, `confidence`, `timestamp`, `speakerTag` (nullable, future diarization).

**FR-1.3**: `SttEngineRegistry` in zip_core for runtime engine registration and discovery. Each app registers its available engines at startup. Registry provides methods to list available engines, get the current engine, and switch engines.

**FR-1.4**: `SttEngineProvider` Riverpod notifier (keepAlive) that wraps the registry and manages the active engine lifecycle. Replaces the current `UnimplementedError` placeholder.

### FR-2: Platform-Native STT Implementation

**FR-2.1**: Use the `speech_to_text` pub.dev package as the primary platform-native engine wrapper implementing `SttEngine`.

**FR-2.2**: Platform priority: iOS + Android + macOS first (platform-native STT known to work). Windows and Linux implementations depend on Spike 1.1 results.

**FR-2.3**: Web platform is best-effort — include if `speech_to_text` / Web Speech API works without web-specific workarounds.

**FR-2.4**: Engines that lack native pause must implement transparent stop/restart. The `SttEngine` contract guarantees pause/resume semantics from the caller's perspective. Pause implies a gap in the transcript (not the end of a session); stop implies session end.

**FR-2.5**: Language/locale selection within the active engine. Leverages the existing `SpeechLocaleProvider` language-first selection flow from Phase 0.

### FR-3: Caption Bus

**FR-3.1**: `CaptionOutputTarget` abstract interface in zip_core per ADR-008. Methods: `onSttResult(SttResult)`, `onSessionStateChange(RecordingState)`, `dispose()`.

**FR-3.2**: `CaptionBus` implementation in zip_core — a pub-sub stream where the STT engine publishes `SttResult` events and output targets subscribe independently.

**FR-3.3**: Phase 1 output targets:
- On-screen caption renderer (both apps)
- Transcript file writer (both apps)
- OBS WebSocket output (Zip Broadcast)
- Browser source output (Zip Broadcast)

**FR-3.4**: Adding new output targets requires zero changes to existing code — subscribe to the bus only.

### FR-4: Caption Rendering UI

**FR-4.1**: Live caption display widget with configurable text size, font, and contrast using the existing `AppSettings` model (CaptionTextSize, CaptionFont, ThemeModeSetting).

**FR-4.2**: Text flow direction (top-to-bottom / bottom-to-top) per existing `ScrollDirection` setting.

**FR-4.3**: Visual break on speaker change (best-effort, based on STT engine pauses or speakerTag changes).

**FR-4.4**: Screen wake lock during active captioning. Release behavior when paused is a user setting (default: release on pause).

**FR-4.5**: Pause/resume controls without losing context. Paused state shows a visible indicator.

**FR-4.6**: Audio level indicator in UI during active captioning.

### FR-5: Transcript Management

**FR-5.1**: Separate `TranscriptProvider` that subscribes to the caption bus independently from the recording state. Recording and transcription can have independent error states (e.g., recording active but transcription error).

**FR-5.2**: SQLite database for session history storage. Session metadata: date, duration, word count, language, STT engine used. Transcript content stored as structured data (segments with timestamps).

**FR-5.3**: Transcript search — users can search through previously captured transcripts by content or metadata using SQLite FTS5 full-text search with BM25 ranking. *(Note: requires new user story in docs/)*

**FR-5.4**: Export/share transcript via platform share sheet in TXT, SRT, and VTT formats.

**FR-5.5**: Session history screen — list of past transcripts with date, duration, word count, searchable.

**FR-5.6**: Local storage only (no sync, no encryption yet — Phase 3).

### FR-6: Audio Capture

**FR-6.1**: Microphone input capture for all platforms. External microphone support (USB, Bluetooth audio devices).

**FR-6.2**: System audio capture (line-in, loopback) investigation and implementation across all platforms. Scope informed by Spike 1.2 results. Includes macOS (entitlements, virtual audio device), Windows (WASAPI loopback), Linux (PulseAudio/PipeWire monitor sources).

**FR-6.3**: Platform permission handling — microphone permission requests per platform with graceful degradation on denial.

**FR-6.4**: Audio source selection UI (microphone list, system audio sources where available).

### FR-7: OBS WebSocket Integration (Zip Broadcast)

**FR-7.1**: OBS WebSocket client in Zip Broadcast that sends captions as closed captions to OBS.

**FR-7.2**: OBS connection settings UI (host, port, password).

**FR-7.3**: OBS output target subscribes to the caption bus as a `CaptionOutputTarget`.

**FR-7.4**: OBS integration is independent of broadcast viewing (remote viewers joining via WebRTC/Realtime is Phase 2). Jordan can use OBS output locally in Phase 1.

### FR-8: Browser Source Output (Zip Broadcast)

**FR-8.1**: Local HTTP server in Zip Broadcast serving a caption overlay page.

**FR-8.2**: Browser source URL display and copy in the Zip Broadcast UI.

**FR-8.3**: Browser source output target subscribes to the caption bus as a `CaptionOutputTarget`.

**FR-8.4**: Caption overlay page displays styled captions, respecting text appearance settings.

### FR-9: Zip Captions App UI (Alex Persona)

**FR-9.1**: Single-tap start captioning from home screen.

**FR-9.2**: Settings screen: STT engine selection, language/locale, text appearance (size, font, contrast, flow direction), wake lock behavior.

**FR-9.3**: Recording screen with live captions, pause/resume/stop controls, audio level indicator.

**FR-9.4**: Session history / transcript viewer with search.

**FR-9.5**: Transcript export via share sheet.

### FR-10: Zip Broadcast App UI (Jordan Persona)

**FR-10.1**: Start captioning from home screen.

**FR-10.2**: Settings screen: same core settings as Zip Captions, plus OBS connection settings, output target selection.

**FR-10.3**: Recording screen with live captions, pause/resume/stop controls.

**FR-10.4**: OBS WebSocket status indicator and browser source URL display.

**FR-10.5**: Audio source selection (microphone, system audio where available).

---

### FR-11: UI Design Prototypes

**FR-11.1**: All UI work in Phase 1 requires a design prototype stage before implementation. Prototypes must cover all screens and interaction flows for both Zip Captions and Zip Broadcast.

**FR-11.2**: Zip Captions screens requiring prototypes:
- Home screen (single-tap start)
- Recording screen (live captions, controls, audio level)
- Settings screen (STT engine, language, text appearance, wake lock, audio source)
- Session history / transcript list (with search)
- Transcript viewer (individual transcript detail, export)

**FR-11.3**: Zip Broadcast screens requiring prototypes:
- Home screen (start captioning)
- Recording screen (live captions, controls, OBS status, browser source URL)
- Settings screen (core settings + OBS connection, output target selection, audio source)
- Audio source selection (microphone list, system audio)

**FR-11.4**: Design prototypes must be reviewed and approved by a human before UI implementation begins. The prototype review is a gate — no UI code is written until the design is approved.

**FR-11.5**: Prototypes are delivered as standalone HTML/CSS files that can be opened in a browser. Each screen gets its own HTML file. Prototypes must demonstrate both light and dark themes (toggle), text customization options (size, font, flow direction), and responsive layout across mobile and desktop form factors.

**FR-11.6**: Prototype files are placed in `aidlc-docs/construction/{unit-name}/prototypes/` alongside the unit's design artifacts. They are working documents — not shipped in the final app.

---

## Non-Functional Requirements

### NFR-1: Performance

**NFR-1.1**: Captions appear with < 1 second perceived latency using platform-native STT.

**NFR-1.2**: Stable 1-2 hour sessions without memory leaks or CPU throttling (Alex S1.2 family dinner scenario).

**NFR-1.3**: Low CPU footprint for OBS integration (Jordan S2.1 solo streamer — OBS already uses significant resources).

### NFR-2: Privacy and Security

**NFR-2.1**: No audio or transcript content leaves the device without explicit user opt-in (security constraint from AGENTS.md and ADR-006).

**NFR-2.2**: Platform-native STT must work offline by default. No network-dependent STT as the only option on any platform.

**NFR-2.3**: No account required for any Phase 1 feature.

**NFR-2.4**: Transcript data in SQLite is unencrypted locally in Phase 1 (encryption added in Phase 3). However, the storage abstraction must be designed for encryption to be added later without breaking the API.

### NFR-3: Accessibility

**NFR-3.1**: WCAG AAA contrast (7:1) maintained for all caption text (carried forward from Phase 0 AppTheme).

**NFR-3.2**: All text customization features (size, font, contrast, flow direction) are free and available without an account.

**NFR-3.3**: Screen wake lock prevents the device from sleeping during active use.

### NFR-4: Testing

**NFR-4.1**: 80%+ code coverage per package (carried forward from Phase 0).

**NFR-4.2**: Property-based testing for all state machines, round-trips, and invariants (PBT extension enabled).

**NFR-4.3**: All `CaptionOutputTarget` implementations must be testable with mock `SttResult` streams.

**NFR-4.4**: STT engine implementations testable via mock platform channels.

### NFR-5: Platform Support

**NFR-5.1**: Tier 1 platforms (Phase 1 delivery): iOS, Android, macOS.

**NFR-5.2**: Tier 2 platforms (dependent on spike results): Windows, Linux.

**NFR-5.3**: Tier 3 platform (best-effort): Web.

---

## Research Spikes (Pre-Construction)

All three spikes must complete before Phase 1 construction begins. Spike outcomes inform design decisions for STT engine implementations and audio capture.

**Spike 1.1**: Windows and Linux STT availability. Survey and test all viable options: platform-native speech recognition APIs (Windows Speech API, Linux speech services), on-device models (Whisper.cpp, Vosk, Sherpa-ONNX), and any relevant third-party packages. Evaluate each option on accuracy, latency, language support, offline capability, resource usage, and integration effort. Produce a comparison matrix with a recommendation — do not predetermine the solution.

**Spike 1.2**: System audio capture feasibility per platform. macOS entitlements and virtual audio devices, Windows WASAPI loopback, Linux PulseAudio/PipeWire monitor sources. Document what works and what doesn't.

**Spike 1.3**: Windows/Linux STT integration PoC. Based on the recommended solution from Spike 1.1, build a minimal Flutter proof-of-concept that integrates the chosen engine on at least one desktop platform. Measure real-world accuracy, latency, memory usage, and model size (if applicable). Validate that the engine can implement the `SttEngine` interface contract (start, stop, pause/resume, locale selection).

---

## Documentation Updates Required

These updates are tracked for the Documentation Refinement stage:

1. **Clarify OBS independence**: Update roadmap/persona docs to explicitly state that OBS WebSocket and browser source outputs are local-only in Phase 1, independent of the broadcast viewing story (which is Phase 2).

2. **Transcript search user story**: Add a user story where a user can search through previously captured transcripts by content or metadata.

3. **SQLite dependency approval**: Add `sqflite` (or `drift`) to the approved dependencies list in the technical specification once the specific package is selected during construction.

---

## Extension Compliance

### Security Baseline
All SECURITY rules remain enabled as blocking constraints. Phase 1 applicable rules:
- **SECURITY-03** (Application Logging): No transcript content in logs
- **SECURITY-09** (Hardening): SQLite data unencrypted locally (acceptable for Phase 1; encryption deferred to Phase 3 per roadmap)
- **SECURITY-10** (Supply Chain): New dependencies (`speech_to_text`, `sqflite`/`drift`, OBS WebSocket client) require version pinning and justification
- **SECURITY-15** (Exception Handling): STT engine errors must not crash the app; graceful degradation required

### Property-Based Testing
All PBT rules remain enabled. Phase 1 PBT targets:
- **PBT-02** (Round-trip): Transcript serialize/deserialize, SttResult model round-trips
- **PBT-03** (Invariant): Caption bus subscription/unsubscription, recording state machine transitions (extending Phase 0 PBT), transcript accumulation
- **PBT-06** (Stateful): Extended recording state machine with transcript provider interaction

---

## Phase 1 Exit Criteria (from roadmap)

1. User can open Zip Captions on mobile (iOS or Android), tap start, speak, see live captions
2. User can open Zip Captions on desktop (macOS, Windows, or Linux), tap start, speak, see live captions
3. User can open Zip Broadcast on desktop, tap start, speak, see live captions
4. Captions appear with < 1 second perceived latency using platform-native STT
5. User can save and export a transcript in TXT format
6. Text size, font, contrast, and flow direction are configurable
7. At least two STT engine options available on at least one platform (e.g., platform-native + Whisper on macOS)
