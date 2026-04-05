# Component Dependencies — Phase 1: Core Captioning

This document extends the Phase 0 dependency graph with all new Phase 1 components. Phase 0 package structure is unchanged: `zip_captions` and `zip_broadcast` depend on `zip_core`; `zip_core` depends on neither app.

---

## Package Dependency Graph (Phase 1)

```
zip_captions ──depends on──► zip_core
zip_broadcast ──depends on──► zip_core
zip_supabase: standalone (no Dart deps)
```

No new package-level dependencies. All new code lives within the existing three Dart packages.

### External Dependencies (new in Phase 1)

| Package | Used By | Purpose |
|---|---|---|
| `speech_to_text` | zip_core | Platform-native STT wrapper |
| `drift` + `drift_flutter` | zip_core | Type-safe SQLite ORM with FTS5 |
| `sqlite3_flutter_libs` | zip_core | Platform SQLite binaries |
| `shelf` | zip_broadcast | Browser source HTTP server |
| `web_socket_channel` | zip_broadcast | OBS WebSocket v5 communication |
| `wakelock_plus` | zip_core | Screen wake lock during captioning |
| `share_plus` | zip_core | Platform share sheet for transcript export |
| `build_runner` + `drift_dev` | zip_core (dev) | drift code generation |

---

## Riverpod Provider Dependency Graph (Phase 1)

```
                    ┌──────────────────────┐
                    │  SttEngineRegistry   │
                    │  Provider (keepAlive) │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐       ┌─────────────────────┐
                    │  SttEngineProvider    │◄──────│  DisplaySettings    │
                    │  (keepAlive)          │       │  Notifier           │
                    └──────────┬───────────┘       │  (selected engine)  │
                               │                   └─────────────────────┘
              ┌────────────────┼────────────────┐
              │                │                │
   ┌──────────▼──────┐  ┌─────▼──────┐  ┌──────▼──────────┐
   │ RecordingState  │  │ LocaleInfo │  │ (multi-input    │
   │ Notifier        │  │ Provider   │  │  engine create) │
   └──────────┬──────┘  └────────────┘  └─────────────────┘
              │
              │ publishes SessionStateEvents
              ▼
   ┌──────────────────────┐
   │  CaptionBusProvider  │◄──── STT engines publish SttResultEvents
   │  (keepAlive)         │
   └──────────┬───────────┘
              │
   ┌──────────▼───────────────────┐
   │  CaptionOutputTargetRegistry │
   │  Provider (keepAlive)        │
   │  subscribes to CaptionBus   │
   └──────────┬───────────────────┘
              │ fans out to registered targets
              │
   ┌──────────┼──────────────────────────────────┐
   │          │              │          │         │
   ▼          ▼              ▼          ▼         ▼
OnScreen  Transcript    ObsWebSocket Browser  Caption
Caption   Writer        Target      Source   Overlay
Target    Target                    Target   Target
   │          │
   │          ▼
   │   ┌──────────────────────┐
   │   │ TranscriptRepository │
   │   │ Provider (keepAlive) │
   │   └──────────────────────┘
   │
   ▼
 UI Widgets (ref.watch/ref.listen)
```

### Settings Provider Dependencies

```
DisplaySettingsNotifier (per app)
  └── SharedPreferences (no provider deps)

TranscriptSettingsProvider (zip_core)
  └── SharedPreferences

ObsSettingsProvider (zip_broadcast)
  └── SharedPreferences

AudioInputSettingsProvider (zip_broadcast)
  └── SharedPreferences

OutputTargetSettingsProvider (zip_broadcast)
  └── SharedPreferences
```

Settings providers have no inter-provider dependencies. They are read by other providers as needed.

---

## Dependency Matrix (Phase 1)

### Provider-to-Provider Dependencies

| Provider | Depends On |
|---|---|
| `SttEngineRegistryProvider` | (none) |
| `SttEngineProvider` | `SttEngineRegistryProvider`, `DisplaySettingsNotifier` (engine ID) |
| `RecordingStateNotifier` | `SttEngineProvider`, `CaptionBusProvider`, `AudioInputSettingsProvider` (Zip Broadcast) |
| `LocaleInfoProvider` | `SttEngineProvider` |
| `CaptionBusProvider` | (none) |
| `CaptionOutputTargetRegistryProvider` | `CaptionBusProvider` |
| `TranscriptRepositoryProvider` | (none — self-contained SQLite) |
| `TranscriptSettingsProvider` | (none) |
| `DisplaySettingsNotifier` | (none) |
| `ObsSettingsProvider` | (none) |
| `AudioInputSettingsProvider` | (none) |
| `OutputTargetSettingsProvider` | (none) |

### Service-to-Service Dependencies

| Service | Depends On |
|---|---|
| `CaptionBus` | (none — standalone) |
| `SttEngineRegistry` | (none — standalone) |
| `CaptionOutputTargetRegistry` | `CaptionBus` (subscribes to its stream) |
| `OnScreenCaptionTarget` | (none — receives events from registry) |
| `TranscriptWriterTarget` | `TranscriptRepository` (for persistence on session stop) |
| `ObsWebSocketTarget` | `ObsSettings` (for connection config) |
| `BrowserSourceTarget` | `BrowserSourceServer` (for pushing events to clients) |
| `BrowserSourceServer` | `DisplaySettings` (for page rendering config) |
| `CaptionOverlayTarget` | `DisplaySettings` (for rendering config) |
| `PlatformSttEngine` | `speech_to_text` package |
| `TranscriptRepository` | `TranscriptDatabase` (drift) |

---

## Inter-Component Communication Patterns (Phase 1)

### Pattern 1: STT Engine → CaptionBus (publish)

```
SttEngine.startListening(onResult: callback)
  │
  │ callback receives SttResult
  ▼
captionBus.publish(CaptionEvent.sttResult(result))
  │
  │ broadcast to all subscribers
  ▼
CaptionOutputTargetRegistry receives event
```

**Direction**: Unidirectional. Engines publish, they never subscribe.
**Coupling**: Engines have no knowledge of targets. The bus is the only shared dependency.

### Pattern 2: CaptionBus → OutputTargetRegistry → Targets (fan-out)

```
CaptionBus.stream emits CaptionEvent
  │
  ▼
CaptionOutputTargetRegistry.onData(event)
  │
  ├── try { onScreenTarget.onCaptionEvent(event) } catch (e) { ... }
  ├── try { transcriptWriter.onCaptionEvent(event) } catch (e) { ... }
  ├── try { obsTarget.onCaptionEvent(event) } catch (e) { ... }
  ├── try { browserSourceTarget.onCaptionEvent(event) } catch (e) { ... }
  └── try { overlayTarget.onCaptionEvent(event) } catch (e) { ... }
```

**Error isolation**: Each target call is wrapped in try/catch. One target's failure does not block others.

### Pattern 3: RecordingStateNotifier → CaptionBus (session lifecycle)

```
RecordingStateNotifier.start()
  ├── starts STT engine(s)
  ├── state = RecordingState.recording()
  └── captionBus.publish(CaptionEvent.sessionState(RecordingState.recording()))

RecordingStateNotifier.stop()
  ├── stops STT engine(s)
  ├── state = RecordingState.stopped()
  └── captionBus.publish(CaptionEvent.sessionState(RecordingState.stopped()))
```

**Purpose**: Targets need to know about session lifecycle — e.g., TranscriptWriterTarget persists on stop, OnScreenCaptionTarget clears on new session.

### Pattern 4: Settings → Target Configuration (reactive)

```
User toggles "OBS Output" in settings
  │
  ▼
OutputTargetSettingsProvider.setObsEnabled(true)
  │
  ▼
App-level orchestration code watches OutputTargetSettingsProvider
  │
  ├── obsEnabled == true → create ObsWebSocketTarget, registry.add(...)
  └── obsEnabled == false → registry.remove(obsTarget), target.dispose()
```

**Note**: The orchestration code that watches settings and adds/removes targets lives in the app package, not in zip_core. This is app-specific wiring.

### Pattern 5: Multi-Input → Multiple STT Engines → Single CaptionBus

```
AudioInputSettingsProvider.state = [input1, input2]
  │
  ▼
For each active input:
  ├── engine1 = sttEngineRegistry.getEngine(engineId)
  │   engine1.startListening(onResult: (r) →
  │     captionBus.publish(sttResult(r.copyWith(sourceId: "input1"))))
  │
  └── engine2 = sttEngineRegistry.getEngine(engineId)
      engine2.startListening(onResult: (r) →
        captionBus.publish(sttResult(r.copyWith(sourceId: "input2"))))
  │
  ▼
CaptionBus receives interleaved SttResults with distinct sourceIds
  │
  ▼
OnScreenCaptionTarget uses sourceId to look up visual style from AudioInputConfig
```

**Key insight**: The CaptionBus doesn't know or care about multi-input. It just receives events. The source differentiation happens at publish time (tagging with sourceId) and render time (looking up visual style).

### Pattern 6: TranscriptWriterTarget → TranscriptRepository (persist on stop)

```
TranscriptWriterTarget accumulates segments during session
  │
  ▼
Receives CaptionEvent.sessionState(RecordingState.stopped())
  │
  ▼
transcriptRepository.saveSession(
  TranscriptSession(date: ..., duration: ..., ...),
  accumulatedSegments
)
  │
  ▼
Clears accumulated segments, ready for next session
```

---

## Data Flow: Complete Zip Captions Session

```
User opens app → ProviderScope initializes
  │
  ├── SttEngineRegistryProvider → SttEngineRegistry
  │     └── app registers PlatformSttEngine
  ├── CaptionBusProvider → CaptionBus
  ├── CaptionOutputTargetRegistryProvider → registry subscribes to bus
  ├── TranscriptRepositoryProvider → drift database opened
  ├── DisplaySettingsNotifier → loads from SharedPreferences
  └── TranscriptSettingsProvider → loads capture toggle
  │
  ▼
User taps Start
  │
  ▼
RecordingStateNotifier.start()
  ├── engine = ref.read(sttEngineProvider)
  ├── engine.startListening(onResult: → captionBus.publish(...))
  ├── captionBus.publish(sessionState(recording))
  └── state = recording
  │
  ▼
Registry fans out events:
  ├── OnScreenCaptionTarget → visible captions update → UI rebuilds
  └── TranscriptWriterTarget → accumulates segments (if capture enabled)
  │
  ▼
User taps Stop
  │
  ▼
RecordingStateNotifier.stop()
  ├── engine.stopListening()
  ├── captionBus.publish(sessionState(stopped))
  └── state = stopped
  │
  ▼
TranscriptWriterTarget → saveSession() to SQLite
  │
  ▼
User views Session History → transcriptRepository.getSessions()
User searches → transcriptRepository.search("query")
User exports → transcriptRepository.exportSession(id, format) → share sheet
```

---

## Data Flow: Complete Zip Broadcast Session (Multi-Input)

```
User opens app → ProviderScope initializes
  │
  ├── (same as Zip Captions, plus:)
  ├── ObsSettingsProvider → loads OBS connection config
  ├── AudioInputSettingsProvider → loads [input1(teacher), input2(student)]
  └── OutputTargetSettingsProvider → loads target toggles
  │
  ▼
App orchestration watches settings, registers targets:
  ├── OnScreenCaptionTarget → registry.add(...)
  ├── TranscriptWriterTarget → registry.add(...) (if capture enabled)
  ├── ObsWebSocketTarget → registry.add(...), connect(obsSettings)
  ├── BrowserSourceTarget + BrowserSourceServer.start() → registry.add(...)
  └── CaptionOverlayTarget → registry.add(...) (if overlay enabled)
  │
  ▼
User taps Start
  │
  ▼
RecordingStateNotifier.start()
  ├── for input1: engine1.startListening(onResult: → bus.publish(sourceId: "teacher"))
  ├── for input2: engine2.startListening(onResult: → bus.publish(sourceId: "student"))
  ├── captionBus.publish(sessionState(recording))
  └── state = recording
  │
  ▼
Registry fans out interleaved events:
  ├── OnScreenCaptionTarget → renders teacher captions in blue, student in green
  ├── TranscriptWriterTarget → accumulates all segments with source IDs
  ├── ObsWebSocketTarget → sends caption text to OBS
  ├── BrowserSourceTarget → pushes to SSE → browsers render fixed two-line display
  └── CaptionOverlayTarget → renders on projector display
  │
  ▼
User taps Stop → same teardown as Zip Captions
```
