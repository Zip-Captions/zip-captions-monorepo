# Unit of Work — Phase 1: Core Captioning

## Overview

Phase 1 is decomposed into 3 pre-construction research spikes and 7 construction units. All work occurs within the existing monorepo packages (zip_core, zip_captions, zip_broadcast). No new packages are created.

---

## Pre-Construction: Research Spikes

### Spike 1.1: Windows/Linux STT Survey

**Scope**: Survey and test all viable STT options for Windows and Linux: platform-native APIs (Windows Speech API, Linux speech services), on-device models (Whisper.cpp, Vosk, Sherpa-ONNX), and relevant third-party packages. Prioritize real-time capabilities with offline functionality.

**Deliverables**:
- Comparison matrix evaluating: accuracy, latency, language support, offline capability, resource usage, integration effort
- Recommendation with rationale (not predetermined)
- Spike report at `aidlc-docs/construction/spikes/spike-1.1-report.md`

**Exit Criteria**: Comparison matrix complete with at least 3 options evaluated. Clear recommendation for Spike 1.3.

**Sequencing**: Must complete before Spike 1.3. Must complete before Unit 1.

---

### Spike 1.2: System Audio Capture Feasibility

**Scope**: Investigate system audio capture (loopback, line-in) on each platform. macOS entitlements and virtual audio devices, Windows WASAPI loopback, Linux PulseAudio/PipeWire monitor sources.

**Deliverables**:
- Per-platform feasibility assessment (works / works-with-workaround / not-feasible)
- Required entitlements, permissions, or third-party components
- Spike report at `aidlc-docs/construction/spikes/spike-1.2-report.md`

**Exit Criteria**: Each Tier 1+2 platform assessed. Clear guidance for Unit 2's audio capture implementation.

**Sequencing**: Independent of Spike 1.1 and 1.3. Can run in parallel with Unit 1. Must complete before Unit 2.

---

### Spike 1.3: STT Integration PoC

**Scope**: Based on Spike 1.1's recommendation, build a minimal Flutter proof-of-concept integrating the chosen engine on at least one desktop platform.

**Deliverables**:
- Minimal Flutter app demonstrating: engine initialization, start/stop listening, locale selection, SttResult output
- Measurements: accuracy, latency, memory usage, model size (if applicable)
- Validation that the engine can implement the `SttEngine` interface contract
- Spike report at `aidlc-docs/construction/spikes/spike-1.3-report.md`

**Exit Criteria**: PoC demonstrates working STT on at least one desktop platform. SttEngine interface compatibility confirmed.

**Sequencing**: Depends on Spike 1.1. Must complete before Unit 1.

---

## Construction Units

### Unit 1: Core Abstractions

**Package**: zip_core (+ rename in zip_captions, zip_broadcast)
**Stories**: S-01 (STT Engine Interface and Registry), S-03 (Caption Bus)

**Components** (from Application Design):
- `SttResult` model (freezed)
- `CaptionEvent` sealed class
- `AudioInputConfig` model (freezed)
- `AudioInputVisualStyle` model
- `SttEngine` abstract class (update existing)
- `SttEngineRegistry` service
- `CaptionBus` service
- `CaptionOutputTarget` abstract interface
- `CaptionOutputTargetRegistry` service
- `SttEngineRegistryProvider`
- `SttEngineProvider` (update existing — no longer throws)
- `CaptionBusProvider`
- `CaptionOutputTargetRegistryProvider`
- `DisplaySettings` rename (from `AppSettings`) + `BaseSettingsNotifier` update
- `DisplaySettingsNotifier` rename in both apps (from `ZipCaptionsSettingsNotifier` / `ZipBroadcastSettingsNotifier`)
- `TranscriptSettingsProvider` (transcript capture toggle)
- `RecordingState` model update (add currentSegment, sessionId fields)
- `RecordingStateNotifier` update (wire to SttEngine and CaptionBus)
- `LocaleInfoProvider` update (read from active SttEngine)

**Construction Stages**:
1. Functional Design — SttEngine contract, CaptionBus pub-sub model, CaptionOutputTarget contract, registry patterns, DisplaySettings rename, RecordingState extensions
2. NFR Requirements — PBT properties (state machines, round-trips), security constraints (no transcript logging), performance (bus throughput)
3. NFR Design — PBT test patterns, mock STT engine for testing, bus error isolation tests
4. Code Generation — Implementation + tests

**Acceptance**: SttEngineRegistry registers/discovers engines. CaptionBus publishes events to registered targets with error isolation. DisplaySettings rename complete. RecordingStateNotifier wired to engine and bus. All existing Phase 0 tests still pass.

**Dependencies**: Spikes 1.1 and 1.3 complete.

---

### Unit 2: Platform STT + Audio

**Package**: zip_core, platform code
**Stories**: S-02 (Platform-Native STT), S-06 (Audio Capture)

**Components**:
- `PlatformSttEngine` (implements SttEngine, wraps speech_to_text)
- Audio capture abstraction (microphone enumeration, source selection)
- Platform permission handling (microphone)
- Multi-input audio management (`AudioInputSettingsProvider` in zip_broadcast)
- `wakelock_plus` integration

**Construction Stages**:
1. Functional Design — PlatformSttEngine implementation, transparent pause, locale mapping, audio source enumeration, multi-input lifecycle, wake lock behavior
2. NFR Requirements — Platform-specific test strategy, STT latency (<1s), session stability (1-2hr), wake lock behavior
3. NFR Design — Mock platform channels for STT testing, audio source mock, multi-input PBT
4. Code Generation — Implementation + tests

**Acceptance**: PlatformSttEngine works on Tier 1 platforms (iOS, Android, macOS). Microphone permission flow works. Audio source selection UI functional. Multi-input with per-source SttEngine instances works in Zip Broadcast. Wake lock activates/deactivates per settings.

**Dependencies**: Unit 1 (SttEngine interface, CaptionBus). Spike 1.1 + 1.3 (Tier 2 engine). Spike 1.2 (system audio capture scope).

---

### Unit 3: Output Targets

**Package**: zip_core (shared targets), zip_broadcast (broadcast-only targets)
**Stories**: S-04 (Caption Rendering), S-05 (Transcripts), S-07 (OBS WebSocket), S-08 (Browser Source)

**Components — zip_core (shared)**:
- `OnScreenCaptionTarget` (CaptionOutputTarget implementation)
- `TranscriptSession` model (freezed)
- `TranscriptSegment` model (freezed)
- `TranscriptDatabase` (drift schema + FTS5)
- `TranscriptRepository` service
- `TranscriptRepositoryProvider`
- `TranscriptWriterTarget` (CaptionOutputTarget implementation)
- Transcript export (TXT, SRT, VTT)

**Components — zip_broadcast**:
- `ObsWebSocketTarget` (CaptionOutputTarget implementation)
- `ObsSettingsProvider`
- `BrowserSourceTarget` (CaptionOutputTarget implementation)
- `BrowserSourceServer` (shelf HTTP server)
- `CaptionOverlayTarget` (CaptionOutputTarget implementation — spike-dependent)
- `OutputTargetSettingsProvider`

**Construction Stages**:
1. Functional Design — On-screen caption buffer, transcript accumulation and persistence, FTS5 search, export formats, OBS WebSocket v5 protocol, browser source SSE + HTML rendering (fixed two-line), caption overlay interface
2. NFR Requirements — Transcript round-trip PBT, FTS5 search quality, OBS reconnection, browser source latency, export format correctness
3. NFR Design — Drift database testing, mock CaptionBus for target testing, OBS protocol mock, browser source integration test
4. Infrastructure Design — Browser source server architecture (shelf pipeline, SSE endpoint, static HTML), caption overlay platform investigation
5. Code Generation — Implementation + tests

**Acceptance**: On-screen captions render with configurable appearance. Transcripts persist to SQLite with FTS5 search. Export produces valid TXT/SRT/VTT. OBS WebSocket sends captions with reconnection. Browser source serves fixed two-line overlay page. Caption overlay interface defined (implementation depth depends on spike findings).

**Dependencies**: Unit 1 (CaptionOutputTarget interface, CaptionBus, CaptionOutputTargetRegistry).

---

### Unit 4: UI Prototypes

**Package**: aidlc-docs (HTML/CSS files, not shipped code)
**Stories**: Proto-01 through Proto-09

**Prototype Files**:
- Proto-01: `zip-captions-home.html` — Home screen, single-tap start
- Proto-02: `zip-captions-recording.html` — Recording screen, captions, controls, audio level
- Proto-03: `zip-captions-settings.html` — Settings screen, all options
- Proto-04: `zip-captions-history.html` — Session history with search
- Proto-05: `zip-captions-viewer.html` — Transcript viewer with export
- Proto-06: `zip-broadcast-home.html` — Home screen, output summary
- Proto-07: `zip-broadcast-recording.html` — Recording with OBS status, browser source URL, multi-input, overlay toggle
- Proto-08: `zip-broadcast-settings.html` — Settings with OBS, targets, audio
- Proto-09: `zip-broadcast-audio-config.html` — Multi-input configuration

**Construction Stages**:
1. Code Generation only — HTML/CSS prototypes with light/dark theme toggle, responsive layout, text customization preview

**Human Review Gate**: All 9 prototypes must be reviewed and approved before Units 5 and 6 can begin. Individual prototypes may be approved independently (Proto-01..05 unblocks Unit 5, Proto-06..09 unblocks Unit 6).

**Acceptance**: Each prototype opens in a browser, demonstrates both themes, shows responsive layout at mobile and desktop widths, and demonstrates the screen's interaction states.

**Dependencies**: Units 1-3 (need to know what components exist to prototype their UI).

---

### Unit 5: Zip Captions App

**Package**: zip_captions
**Stories**: S-09 (Zip Captions App UI)

**Components**:
- `HomeScreen` (update — functional start button)
- `RecordingScreen` (new)
- `SettingsScreen` (new)
- `SessionHistoryScreen` (new)
- `TranscriptViewerScreen` (new)
- `CaptionDisplayWidget` (new — may extract to zip_core)
- App-level orchestration: target registration based on settings, engine startup wiring

**Construction Stages**:
1. Functional Design — Screen-level state management, navigation flow, widget-to-provider wiring, target registration orchestration
2. NFR Requirements — Widget test coverage, accessibility (screen reader labels, tap targets), session stability
3. NFR Design — Widget test patterns, integration test strategy
4. Code Generation — Implementation + tests

**Acceptance**: All S-09 acceptance criteria pass. Single-tap start → recording screen with live captions. Settings configurable. Session history searchable. Transcript export works via share sheet.

**Dependencies**: Units 1-3 (all components). Proto-01 through Proto-05 approved.

---

### Unit 6: Zip Broadcast App

**Package**: zip_broadcast
**Stories**: S-10 (Zip Broadcast App UI)

**Components**:
- `HomeScreen` (update — functional start button with output summary)
- `RecordingScreen` (new)
- `SettingsScreen` (new)
- `AudioSourceConfigScreen` (new)
- App-level orchestration: multi-target registration, multi-input engine management, OBS connection lifecycle, browser source server lifecycle, overlay lifecycle

**Construction Stages**:
1. Functional Design — Screen-level state management, multi-input UI, OBS status display, browser source URL display, overlay configuration flow, navigation
2. NFR Requirements — Widget test coverage, multi-input performance, OBS reconnection UX, accessibility
3. NFR Design — Widget test patterns, multi-input integration test, OBS mock
4. Infrastructure Design — Caption overlay window management (informed by spike findings)
5. Code Generation — Implementation + tests

**Acceptance**: All S-10 acceptance criteria pass. Start captioning with OBS + browser source active. Multi-input with distinct visual styles. Caption overlay on target display. Audio source configuration functional.

**Dependencies**: Units 1-3 (all components). Proto-06 through Proto-09 approved.

---

### Unit 7: Integration Milestones

**Package**: All
**Stories**: M-S1.1, M-S1.2, M-S1.3, M-S2.1, M-S2.2, M-S3.1

**Scope**: Cross-unit Build and Test + Documentation Refinement. Validates end-to-end persona scenarios.

**Construction Stages**:
1. Build and Test — Full build across all packages, all unit tests pass, integration milestone scenarios verified, static analysis clean, coverage targets met
2. Documentation Refinement — Update docs (architecture decisions, technical specification, roadmap progress), clean aidlc-docs artifacts, generate build/test summary

**Acceptance**: All 6 milestone scenarios pass. 80%+ coverage per package. Zero lint warnings. All CI checks pass. Documentation current.

**Dependencies**: Units 1-6 all complete.

---

## Code Organization

All code lives in the existing package structure established in Phase 0:

```
packages/
  zip_core/lib/src/
    models/          — SttResult, CaptionEvent, AudioInputConfig, TranscriptSession,
                       TranscriptSegment, DisplaySettings (renamed)
    providers/       — SttEngineRegistryProvider, SttEngineProvider, CaptionBusProvider,
                       CaptionOutputTargetRegistryProvider, TranscriptRepositoryProvider,
                       TranscriptSettingsProvider
    services/
      stt/           — SttEngine, PlatformSttEngine, SttEngineRegistry
      caption/       — CaptionBus, CaptionOutputTarget, CaptionOutputTargetRegistry
      caption/targets/ — OnScreenCaptionTarget, TranscriptWriterTarget
      transcript/    — TranscriptRepository, TranscriptDatabase
    theme/           — AppTheme (unchanged)

  zip_captions/lib/
    providers/       — DisplaySettingsNotifier (renamed)
    screens/         — HomeScreen, RecordingScreen, SettingsScreen,
                       SessionHistoryScreen, TranscriptViewerScreen
    widgets/         — CaptionDisplayWidget

  zip_broadcast/lib/
    providers/       — DisplaySettingsNotifier (renamed), ObsSettingsProvider,
                       AudioInputSettingsProvider, OutputTargetSettingsProvider
    screens/         — HomeScreen, RecordingScreen, SettingsScreen,
                       AudioSourceConfigScreen
    services/        — ObsWebSocketTarget, BrowserSourceTarget, BrowserSourceServer,
                       CaptionOverlayTarget
```
