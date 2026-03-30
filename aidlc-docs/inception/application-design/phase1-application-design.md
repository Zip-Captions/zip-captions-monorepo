# Application Design — Phase 1: Core Captioning

## Summary

Phase 1 builds the core captioning architecture on the Phase 0 scaffold. The design introduces an STT engine system, a pub-sub caption bus, multiple output target types, transcript storage with full-text search, multi-input audio management, OBS integration, a browser source server, and a caption overlay system.

### Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| CaptionBus pattern | Standalone Dart class held by `keepAlive` provider (Q1=B) | Clean separation from Riverpod; testable without framework; explicit pub/sub |
| Output target lifecycle | Registry-managed (Q2=B) | Centralized target tracking; enables UI enumeration of active targets; error isolation per target |
| SQLite package | drift ORM (Q3=B) | Type-safe queries, built-in FTS5 support, migration management, compile-time safety |
| Browser source server | shelf package (Q4=A) | Dart-team maintained, structured middleware, easy to test |
| Caption overlay approach | Spike-dependent (Q5=C) | Platform window management needs investigation; interface defined, implementation deferred |
| Multi-input model | List-based provider (Q6=A) | Simple for small input counts (2-4); consistent immutable state pattern |
| Output target locations | Interface + shared in zip_core, broadcast-only in zip_broadcast (Q7=B) | Clean package boundaries; scales across future phases |
| OBS WebSocket | web_socket_channel + custom v5 protocol (Q8=B) | No dependency on third-party OBS package quality; full control over protocol |
| Settings architecture | Separate providers per concern (Q9=B) | `DisplaySettings` (renamed from `AppSettings`), `TranscriptSettings`, `ObsSettings`, `AudioInputSettings`, `OutputTargetSettings` |

### Naming Changes from Phase 0

| Phase 0 Name | Phase 1 Name | Reason |
|---|---|---|
| `AppSettings` | `DisplaySettings` | Accurately describes scope (caption display config only) |
| `BaseSettingsNotifier` | `BaseSettingsNotifier` (unchanged) | Still manages `DisplaySettings`; base class name is generic by design |
| `ZipCaptionsSettingsNotifier` | `DisplaySettingsNotifier` (in zip_captions) | Aligns with `DisplaySettings` rename |
| `ZipBroadcastSettingsNotifier` | `DisplaySettingsNotifier` (in zip_broadcast) | Aligns with `DisplaySettings` rename |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter UI Layer                      │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐ │
│  │ Zip Captions│  │ Zip Broadcast│  │ Shared Widgets     │ │
│  │ Screens     │  │ Screens      │  │ (CaptionDisplay)   │ │
│  └──────┬──────┘  └──────┬───────┘  └────────────────────┘ │
│         │   ref.watch     │                                  │
└─────────┼─────────────────┼──────────────────────────────────┘
          │                 │
┌─────────▼─────────────────▼──────────────────────────────────┐
│                    Riverpod Provider Layer                     │
│  ┌─────────────────┐ ┌──────────────┐ ┌───────────────────┐ │
│  │ RecordingState  │ │ Settings     │ │ TranscriptRepo    │ │
│  │ Notifier        │ │ Providers    │ │ Provider          │ │
│  └────────┬────────┘ └──────────────┘ └───────────────────┘ │
│           │                                                   │
│  ┌────────▼────────┐ ┌──────────────────────────────────┐   │
│  │ SttEngine       │ │ CaptionBus + OutputTargetRegistry│   │
│  │ Provider        │ │ Providers (keepAlive)            │   │
│  └────────┬────────┘ └──────────────┬───────────────────┘   │
└───────────┼─────────────────────────┼────────────────────────┘
            │                         │
┌───────────▼─────────────────────────▼────────────────────────┐
│                    Service Layer (plain Dart)                  │
│                                                               │
│  ┌────────────────┐   ┌───────────────┐   ┌───────────────┐ │
│  │ SttEngine      │   │ CaptionBus    │   │ Transcript    │ │
│  │ Registry       │   │ (broadcast    │   │ Repository    │ │
│  │                │   │  stream)      │   │ (drift/SQLite)│ │
│  └────────────────┘   └───────┬───────┘   └───────────────┘ │
│                               │                               │
│  ┌────────────────────────────▼──────────────────────────┐   │
│  │          CaptionOutputTargetRegistry                   │   │
│  │  ┌──────────┐ ┌───────────┐ ┌─────┐ ┌───────┐ ┌────┐│   │
│  │  │OnScreen  │ │Transcript │ │ OBS │ │Browser│ │Over││   │
│  │  │Caption   │ │Writer     │ │ WS  │ │Source │ │lay ││   │
│  │  │Target    │ │Target     │ │     │ │       │ │    ││   │
│  │  └──────────┘ └───────────┘ └─────┘ └───────┘ └────┘│   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
│  zip_core targets ─────────┤  zip_broadcast targets ─────────┤
│  (OnScreen, TranscriptWriter) (OBS, BrowserSource, Overlay)   │
└───────────────────────────────────────────────────────────────┘
```

---

## Component Summary

### New Components (Phase 1)

| Component | Package | Type | Purpose |
|---|---|---|---|
| `SttResult` | zip_core | freezed model | STT recognition result with sourceId |
| `CaptionEvent` | zip_core | sealed class | Union type for bus events (SttResult + SessionState) |
| `AudioInputConfig` | zip_core | freezed model | Per-input config (speaker label, visual style) |
| `TranscriptSession` | zip_core | freezed model | Session metadata for transcript history |
| `TranscriptSegment` | zip_core | freezed model | Individual segment within a transcript |
| `PlatformSttEngine` | zip_core | service | speech_to_text wrapper implementing SttEngine |
| `SttEngineRegistry` | zip_core | service | Runtime engine registration and discovery |
| `CaptionBus` | zip_core | service | Pub-sub event bus (broadcast StreamController) |
| `CaptionOutputTarget` | zip_core | interface | Contract for caption consumers |
| `CaptionOutputTargetRegistry` | zip_core | service | Manages active targets with error isolation |
| `OnScreenCaptionTarget` | zip_core | service | Buffers captions for UI rendering |
| `TranscriptWriterTarget` | zip_core | service | Accumulates and persists transcripts |
| `TranscriptRepository` | zip_core | service | SQLite storage abstraction (drift) |
| `TranscriptDatabase` | zip_core | internal | drift schema + FTS5 virtual table |
| `DisplaySettings` | zip_core | freezed model | Renamed from AppSettings |
| `TranscriptSettingsProvider` | zip_core | provider | Transcript capture toggle |
| `ObsWebSocketTarget` | zip_broadcast | service | OBS WebSocket v5 caption output |
| `BrowserSourceTarget` | zip_broadcast | service | Pushes events to browser clients |
| `BrowserSourceServer` | zip_broadcast | service | shelf HTTP server for overlay page |
| `CaptionOverlayTarget` | zip_broadcast | service | Always-on-top overlay (spike-dependent impl) |
| `ObsSettingsProvider` | zip_broadcast | provider | OBS connection settings |
| `AudioInputSettingsProvider` | zip_broadcast | provider | Multi-input configs (list-based) |
| `OutputTargetSettingsProvider` | zip_broadcast | provider | Target enable/disable toggles |

### Modified Components (Phase 0 → Phase 1)

| Component | Package | Change |
|---|---|---|
| `SttEngine` | zip_core | Formalized contract: properties, localeId param, pause semantics |
| `SttEngineProvider` | zip_core | No longer throws; manages active engine lifecycle via registry |
| `RecordingStateNotifier` | zip_core | Wired to SttEngine and CaptionBus; coordinates multi-input |
| `RecordingState` | zip_core | `recording` gains currentSegment; `stopped` gains sessionId |
| `LocaleInfoProvider` | zip_core | Reads locales from active SttEngine instead of stub |
| `AppSettings` → `DisplaySettings` | zip_core | Renamed; fields unchanged |
| `ZipCaptionsSettingsNotifier` → `DisplaySettingsNotifier` | zip_captions | Renamed to match DisplaySettings |
| `ZipBroadcastSettingsNotifier` → `DisplaySettingsNotifier` | zip_broadcast | Renamed to match DisplaySettings |
| `HomeScreen` | zip_captions | Functional start button wired to RecordingStateNotifier |
| `HomeScreen` | zip_broadcast | Functional start button with output target summary |

---

## Security Design Notes (Phase 1 additions)

1. **No transcript logging** (carried from Phase 0): All components in the caption pipeline — SttEngine, CaptionBus, CaptionOutputTargets, TranscriptRepository — must never log, emit to analytics, or surface transcript text content. This constraint applies to all new components.

2. **OBS password storage**: OBS WebSocket password is stored in `shared_preferences` (unencrypted locally). Acceptable for Phase 1 local-only use. Phase 3 adds encrypted storage.

3. **Browser source server**: Binds to localhost only. Not exposed to the network by default. No authentication required for local connections.

4. **Transcript data**: Stored unencrypted in SQLite (Phase 1). The `TranscriptRepository` API is designed for encryption to be added later (Phase 3) without breaking consumers.

5. **Multi-input audio**: Each STT engine instance handles its own platform permissions. No additional security surface beyond existing microphone permission handling.

---

## Detailed Artifacts

- [phase1-components.md](phase1-components.md) — Full component definitions and responsibilities
- [phase1-component-methods.md](phase1-component-methods.md) — Method signatures and field definitions
- [phase1-services.md](phase1-services.md) — Service layer, orchestration patterns, and data flows
- [phase1-component-dependency.md](phase1-component-dependency.md) — Dependency graph and communication patterns
