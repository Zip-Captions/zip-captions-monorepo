# Services — Phase 1: Core Captioning

Phase 1 introduces substantial service layer architecture on top of the Phase 0 pattern. All services follow the same orchestration principle: Riverpod providers are the sole access mechanism — no service locators, no global singletons. New in Phase 1, several services are standalone Dart classes held by `keepAlive` providers rather than being Riverpod notifiers themselves. This keeps business logic testable without framework dependencies.

---

## Service Architecture Overview

```
                    ┌─────────────────────────────────────────────┐
                    │             Riverpod Providers               │
                    │  (sole access layer — widgets use ref.watch) │
                    └────────────┬────────────────────────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        ▼                        ▼                        ▼
  ┌───────────┐          ┌─────────────┐          ┌──────────────┐
  │ Notifiers │          │  Service    │          │  Repository  │
  │ (state    │          │  Classes    │          │  Classes     │
  │  machines)│          │ (plain Dart)│          │ (plain Dart) │
  └───────────┘          └─────────────┘          └──────────────┘
  RecordingState          CaptionBus               TranscriptRepo
  Settings notifiers      SttEngineRegistry         (drift/SQLite)
                          OutputTargetRegistry
                          BrowserSourceServer
                          AudioInputManager*

  * AudioInputManager logic lives in AudioInputSettingsProvider
    (list-based provider per Q6=A)
```

---

## Service Inventory

### 1. STT Engine Service Layer

**Components**: `SttEngine` (abstract), `PlatformSttEngine`, `SttEngineRegistry`

**Orchestration pattern**:
```
App startup
  │
  ▼
SttEngineRegistryProvider.build()
  → creates SttEngineRegistry
  │
  ▼
App registers engines:
  registry.register(PlatformSttEngine())
  registry.register(...)  // additional engines per platform
  │
  ▼
SttEngineProvider.build()
  → reads selected engine ID from settings
  → retrieves engine from registry
  → calls engine.initialize()
  → returns active SttEngine
  │
  ▼
RecordingStateNotifier.start()
  → ref.read(sttEngineProvider) to get active engine
  → engine.startListening(localeId: ..., onResult: ...)
  → onResult callback publishes SttResult to CaptionBus
```

**Key interactions**:
- `SttEngineRegistry` has no dependencies — pure registration container
- `SttEngineProvider` depends on: `SttEngineRegistryProvider`, settings (for selected engine ID)
- `RecordingStateNotifier` depends on: `SttEngineProvider`, `CaptionBusProvider`
- `LocaleInfoProvider` depends on: `SttEngineProvider` (for supported locales)

**Error handling**: Engine initialization failure → `RecordingState` remains idle, user sees error message. Engine errors during listening → published as error state, recording continues if possible.

---

### 2. Caption Bus Service Layer

**Components**: `CaptionBus`, `CaptionOutputTargetRegistry`, `CaptionOutputTarget` implementations

**Orchestration pattern**:
```
App startup
  │
  ▼
CaptionBusProvider.build()
  → creates CaptionBus (broadcast StreamController internally)
  │
  ▼
CaptionOutputTargetRegistryProvider.build()
  → creates CaptionOutputTargetRegistry
  → registry subscribes to CaptionBus.stream
  │
  ▼
App configures targets based on settings:
  if (onScreenEnabled) registry.add(OnScreenCaptionTarget(...))
  if (transcriptCaptureEnabled) registry.add(TranscriptWriterTarget(...))
  if (obsEnabled) registry.add(ObsWebSocketTarget(...))          // Zip Broadcast only
  if (browserSourceEnabled) registry.add(BrowserSourceTarget(...)) // Zip Broadcast only
  if (overlayEnabled) registry.add(CaptionOverlayTarget(...))     // Zip Broadcast only
  │
  ▼
During captioning:
  STT engine → onResult → captionBus.publish(CaptionEvent.sttResult(...))
  RecordingStateNotifier → captionBus.publish(CaptionEvent.sessionState(...))
  │
  ▼
Registry receives events from bus → fans out to each registered target:
  for (target in activeTargets) {
    try { target.onCaptionEvent(event); } catch (e) { /* isolate error */ }
  }
```

**Error isolation**: The registry wraps each `target.onCaptionEvent()` call in a try/catch. A failure in one target (e.g., OBS WebSocket disconnects) does not affect other targets (e.g., on-screen rendering continues). Target-specific error state is managed by each target independently.

**Target lifecycle**:
- Targets are added to the registry when the user enables them (via settings toggle)
- Targets are removed from the registry when the user disables them
- On removal, `target.dispose()` is called by the registry
- On app shutdown, `registry.dispose()` disposes all remaining targets

---

### 3. Transcript Storage Service Layer

**Components**: `TranscriptWriterTarget`, `TranscriptRepository`, `TranscriptDatabase` (drift)

**Orchestration pattern**:
```
App startup
  │
  ▼
TranscriptRepositoryProvider.build()
  → creates TranscriptDatabase (drift, opens/creates SQLite file)
  → creates TranscriptRepository wrapping the database
  │
  ▼
If transcript capture is enabled:
  TranscriptWriterTarget is created and registered with output target registry
  │
  ▼
During captioning:
  TranscriptWriterTarget.onCaptionEvent(SttResultEvent)
    → accumulates TranscriptSegments in memory
  │
  ▼
  TranscriptWriterTarget.onCaptionEvent(SessionStateEvent(stopped))
    → calls transcriptRepository.saveSession(session, segments)
    → clears accumulated segments
  │
  ▼
User views session history:
  transcriptRepository.getSessions() → List<TranscriptSession>
  │
  ▼
User searches transcripts:
  transcriptRepository.search("doctor said") → FTS5 query → BM25-ranked results
  │
  ▼
User exports transcript:
  transcriptRepository.exportSession(id, ExportFormat.srt) → SRT string
  → platform share sheet
```

**Database schema** (drift-managed):
- `sessions` table: id, date, duration_ms, word_count, language, engine_id
- `segments` table: id, session_id (FK), text, start_ms, end_ms, source_id, is_pause
- `segments_fts` virtual table (FTS5): full-text index on segments.text, tokenizer = unicode61

**Phase 3 preparation**: The `TranscriptRepository` API is designed so that encryption can be added at the database level (SQLCipher or drift's encryption support) without changing the repository interface or any consumers.

---

### 4. Browser Source Service Layer (Zip Broadcast only)

**Components**: `BrowserSourceServer`, `BrowserSourceTarget`

**Orchestration pattern**:
```
User enables browser source output
  │
  ▼
BrowserSourceServer.start(port: 8080)
  → shelf pipeline: static HTML/CSS/JS + SSE endpoint
  → serves caption overlay page at http://localhost:8080
  │
  ▼
BrowserSourceTarget created and registered with output target registry
  │
  ▼
Browser (OBS browser source, standalone browser) connects to URL
  → loads HTML page
  → opens SSE connection to /events endpoint
  │
  ▼
During captioning:
  BrowserSourceTarget.onCaptionEvent(event)
    → pushes event data to SSE stream
    → connected browsers receive and render in real time
  │
  ▼
Browser page rendering:
  → fixed-position container showing most recent two lines
  → text does not scroll or shift position
  → transparent background
  → respects display settings (size, font, color)
```

**Server architecture** (shelf):
- `GET /` → serves the caption overlay HTML page (inline CSS/JS, self-contained)
- `GET /events` → SSE endpoint, streams `CaptionEvent` data as JSON
- `GET /settings` → returns current display settings as JSON (for page rendering)
- Server binds to localhost only (not exposed to network by default)

---

### 5. OBS WebSocket Service Layer (Zip Broadcast only)

**Components**: `ObsWebSocketTarget`

**Orchestration pattern**:
```
User enables OBS output and configures connection settings
  │
  ▼
ObsWebSocketTarget created with ObsSettings (host, port, password)
  → registered with output target registry
  → connects to OBS via WebSocket
  │
  ▼
OBS WebSocket v5 handshake:
  → identify (authentication with password if required)
  → connected state exposed via onConnectionStateChanged stream
  │
  ▼
During captioning:
  ObsWebSocketTarget.onCaptionEvent(SttResultEvent)
    → sends SendStreamCaption request to OBS
  │
  ▼
Connection drop handling:
  → connectionState changes to disconnected
  → automatic reconnect with backoff
  → UI shows connection state via ObsConnectionState stream
```

**Protocol**: OBS WebSocket v5 (`web_socket_channel` + custom message framing). Authentication uses the OBS WebSocket v5 auth flow (challenge-response with SHA256).

---

### 6. Caption Overlay Service Layer (Zip Broadcast only)

**Components**: `CaptionOverlayTarget`

**Orchestration pattern**:
```
User enables caption overlay and selects target display
  │
  ▼
CaptionOverlayTarget.show(config: OverlayConfig(
  targetDisplay: ...,
  position: OverlayPosition.bottom,
  transparency: true,
  clickThrough: true,
))
  → creates platform-specific always-on-top window (approach TBD per spike)
  │
  ▼
CaptionOverlayTarget registered with output target registry
  │
  ▼
During captioning:
  CaptionOverlayTarget.onCaptionEvent(event)
    → renders captions in the overlay window
    → respects display settings
    → multi-input sources render with distinct visual styles
```

**Note**: The window management implementation is deferred to construction (Q5=C). The interface and data flow are defined here; the platform-specific mechanics will be resolved during a construction-phase investigation.

---

### 7. Multi-Input Audio Service Layer (Zip Broadcast only)

**Components**: `AudioInputSettingsProvider` (list-based, Q6=A)

**Orchestration pattern**:
```
User configures multiple audio inputs
  │
  ▼
AudioInputSettingsProvider manages List<AudioInputConfig>
  │
  ▼
For each active input config:
  → create SttEngine instance (from registry)
  → engine.startListening(localeId: ..., onResult: (result) {
      // tag result with input's sourceId
      captionBus.publish(CaptionEvent.sttResult(
        result.copyWith(sourceId: config.inputId)
      ));
    })
  │
  ▼
All engines publish to the same CaptionBus
  → output targets receive results with distinct sourceIds
  → on-screen renderer uses sourceId to apply visual styles from AudioInputConfig
```

**Lifecycle**: Adding an input → creates and starts a new STT engine instance. Removing an input → stops and disposes its engine instance. The `RecordingStateNotifier` coordinates start/stop across all active inputs.

---

## Settings Persistence Services

Phase 1 follows the same `shared_preferences` persistence pattern as Phase 0, but with separate providers per concern:

| Provider | Key Prefix | Scope | Fields |
|---|---|---|---|
| `DisplaySettingsNotifier` | `'zip_captions.'` or `'zip_broadcast.'` | Per-app | scrollDirection, captionTextSize, captionFont, themeModeSetting, maxVisibleLines |
| `TranscriptSettingsProvider` | `'transcript.'` | Shared (zip_core) | captureEnabled |
| `ObsSettingsProvider` | `'zip_broadcast.obs.'` | Zip Broadcast only | host, port, password |
| `AudioInputSettingsProvider` | `'zip_broadcast.audio.'` | Zip Broadcast only | List\<AudioInputConfig\> (JSON-serialized) |
| `OutputTargetSettingsProvider` | `'zip_broadcast.targets.'` | Zip Broadcast only | onScreen, obs, browserSource, overlay toggles |

---

## Service Orchestration: Complete Captioning Session

This shows the full data flow for a Zip Broadcast session with multi-input and all output targets enabled:

```
User taps Start
  │
  ▼
RecordingStateNotifier.start()
  ├── for each AudioInputConfig where isActive:
  │     ├── sttEngineRegistry.getEngine(engineId)
  │     ├── engine.initialize()
  │     └── engine.startListening(onResult: → captionBus.publish(...))
  ├── captionBus.publish(SessionStateEvent(recording))
  └── state = RecordingState.recording()
  │
  ▼
CaptionBus broadcasts CaptionEvents
  │
  ▼
CaptionOutputTargetRegistry fans out to each target:
  ├── OnScreenCaptionTarget → updates visible caption buffer → UI rebuilds
  ├── TranscriptWriterTarget → accumulates segments (if enabled)
  ├── ObsWebSocketTarget → sends to OBS (if connected)
  ├── BrowserSourceTarget → pushes to SSE clients
  └── CaptionOverlayTarget → renders in overlay window
  │
  ▼
User taps Stop
  │
  ▼
RecordingStateNotifier.stop()
  ├── for each active engine: engine.stopListening()
  ├── captionBus.publish(SessionStateEvent(stopped))
  └── state = RecordingState.stopped()
  │
  ▼
TranscriptWriterTarget receives SessionStateEvent(stopped)
  └── transcriptRepository.saveSession(session, segments)
```
