# Components — Phase 1: Core Captioning

This document defines all new and modified components for Phase 1. Phase 0 components that are unchanged are not repeated here — see `components.md` (Phase 0) for those.

---

## New zip_core Components

### Models

#### `SttResult`
- **File**: `lib/src/models/stt_result.dart`
- **Type**: `@freezed` data class
- **Responsibility**: Immutable value object representing a single speech-to-text result event. Carries the recognized text, finality flag, confidence score, timestamp, optional speaker tag (future diarization), and a source identifier to distinguish results from multiple simultaneous STT engine instances (multi-input).
- **Visibility**: Exported from `package:zip_core/zip_core.dart`

#### `AudioInputConfig`
- **File**: `lib/src/models/audio_input_config.dart`
- **Type**: `@freezed` data class
- **Responsibility**: Immutable configuration for a single audio input source. Fields: unique input ID, audio source reference, speaker label, visual style (color/indicator), and active/inactive state. Used by the multi-input system in Zip Broadcast; Zip Captions uses a single implicit input.
- **Visibility**: Exported

#### `TranscriptSession`
- **File**: `lib/src/models/transcript_session.dart`
- **Type**: `@freezed` data class
- **Responsibility**: Immutable value object for a saved transcript session. Fields: session ID, date, duration, word count, language, STT engine used. Does not contain the transcript content itself — content is loaded separately from SQLite.
- **Visibility**: Exported

#### `TranscriptSegment`
- **File**: `lib/src/models/transcript_segment.dart`
- **Type**: `@freezed` data class
- **Responsibility**: Immutable value object for a single segment within a transcript. Fields: text, start timestamp, end timestamp, source identifier (speaker/input), is-pause flag. A transcript is an ordered list of segments.
- **Visibility**: Exported

#### `CaptionEvent`
- **File**: `lib/src/models/caption_event.dart`
- **Type**: Sealed class
- **Responsibility**: Union type for events published on the CaptionBus. Variants: `SttResultEvent(SttResult)`, `SessionStateEvent(RecordingState)`. Allows a single event stream to carry both STT results and session lifecycle changes.
- **Visibility**: Exported

---

### Services

#### `SttEngine` (abstract — modified)
- **File**: `lib/src/services/stt/stt_engine.dart` (existing)
- **Type**: Abstract class (interface)
- **Phase 1 changes**: Formalize the full contract per FR-1. Add properties: `engineId`, `displayName`, `requiresNetwork`, `requiresDownload`, `supportedLocales`. Add `localeId` parameter to `startListening()`. Clarify pause/resume semantics: pause implies gap in transcript, stop implies session end. Engines without native pause implement transparent stop/restart.
- **Visibility**: Exported

#### `PlatformSttEngine`
- **File**: `lib/src/services/stt/platform_stt_engine.dart`
- **Type**: Concrete class implementing `SttEngine`
- **Responsibility**: Wraps the `speech_to_text` pub.dev package. Implements `SttEngine` contract using platform-native STT (Apple Speech on iOS/macOS, Google on-device on Android, Web Speech API on web best-effort). Handles transparent pause via stop/restart on platforms without native pause support.
- **Visibility**: Exported

#### `SttEngineRegistry`
- **File**: `lib/src/services/stt/stt_engine_registry.dart`
- **Type**: Plain Dart class
- **Responsibility**: Runtime registry of available STT engines. Each app registers its engines at startup. Provides methods: `register(SttEngine)`, `unregister(String engineId)`, `listAvailable()`, `getEngine(String engineId)`. Does not manage engine lifecycle — engines are created and disposed externally.
- **Visibility**: Exported

#### `CaptionBus`
- **File**: `lib/src/services/caption/caption_bus.dart`
- **Type**: Plain Dart class (standalone service, held by a `keepAlive` Riverpod provider)
- **Responsibility**: Pub-sub event bus per ADR-008. Internally uses a broadcast `StreamController<CaptionEvent>`. STT engines publish `SttResultEvent`s; the recording state notifier publishes `SessionStateEvent`s. The `CaptionOutputTargetRegistry` subscribes and fans out to individual targets. Error isolation: a failure in one subscriber does not affect others.
- **Visibility**: Exported

#### `CaptionOutputTarget` (abstract)
- **File**: `lib/src/services/caption/caption_output_target.dart`
- **Type**: Abstract class (interface)
- **Responsibility**: Contract for all caption consumers. Methods: `onCaptionEvent(CaptionEvent)`, `dispose()`. Each implementation handles events independently.
- **Visibility**: Exported

#### `CaptionOutputTargetRegistry`
- **File**: `lib/src/services/caption/caption_output_target_registry.dart`
- **Type**: Plain Dart class
- **Responsibility**: Manages the set of active `CaptionOutputTarget` instances. Subscribes to the `CaptionBus` and fans out events to all registered targets with per-target error isolation. Methods: `add(CaptionOutputTarget)`, `remove(CaptionOutputTarget)`, `activeTargets`, `dispose()`. Held by a `keepAlive` Riverpod provider.
- **Visibility**: Exported

#### `OnScreenCaptionTarget`
- **File**: `lib/src/services/caption/targets/on_screen_caption_target.dart`
- **Type**: Concrete `CaptionOutputTarget`
- **Responsibility**: Receives caption events and exposes them as state for the caption rendering widget. Both apps use this target. Maintains the visible caption buffer (text, speaker changes, pause markers).
- **Visibility**: Exported

#### `TranscriptWriterTarget`
- **File**: `lib/src/services/caption/targets/transcript_writer_target.dart`
- **Type**: Concrete `CaptionOutputTarget`
- **Responsibility**: Receives caption events and accumulates transcript segments. On session stop, persists the transcript to SQLite via `TranscriptRepository`. Only active when transcript capture setting is enabled.
- **Visibility**: Exported

#### `TranscriptRepository`
- **File**: `lib/src/services/transcript/transcript_repository.dart`
- **Type**: Plain Dart class wrapping a drift database
- **Responsibility**: Abstraction over SQLite storage for transcripts. Methods: `saveSession(TranscriptSession, List<TranscriptSegment>)`, `getSessions()`, `getSession(String id)`, `getSegments(String sessionId)`, `search(String query)` (FTS5 + BM25), `deleteSession(String id)`, `exportSession(String id, ExportFormat)`. Designed so encryption can be added later (Phase 3) without breaking the API.
- **Visibility**: Exported

#### `TranscriptDatabase` (drift)
- **File**: `lib/src/services/transcript/transcript_database.dart`
- **Type**: drift `@DriftDatabase` class
- **Responsibility**: drift schema definition with tables for sessions and segments, plus FTS5 virtual table for full-text search. Migration support built in. Platform-appropriate SQLite backend via `drift_flutter` / `drift/native`.
- **Visibility**: Internal (accessed only through `TranscriptRepository`)

---

### Providers

#### `SttEngineRegistryProvider`
- **File**: `lib/src/providers/stt_engine_registry_provider.dart`
- **Type**: `@Riverpod(keepAlive: true)` returning `SttEngineRegistry`
- **Responsibility**: Provides the singleton `SttEngineRegistry` instance. Apps register their available engines in their startup code.
- **Visibility**: Exported

#### `SttEngineProvider` (modified)
- **File**: `lib/src/providers/stt_engine_provider.dart` (existing)
- **Phase 1 changes**: No longer throws `UnimplementedError`. Reads the currently selected engine ID from settings, retrieves the engine from `SttEngineRegistry`, and manages its lifecycle (initialize, dispose on switch). Depends on `SttEngineRegistryProvider` and `DisplaySettingsProvider` (for selected engine ID).
- **Visibility**: Exported

#### `CaptionBusProvider`
- **File**: `lib/src/providers/caption_bus_provider.dart`
- **Type**: `@Riverpod(keepAlive: true)` returning `CaptionBus`
- **Responsibility**: Provides the singleton `CaptionBus` instance for the app's lifetime.
- **Visibility**: Exported

#### `CaptionOutputTargetRegistryProvider`
- **File**: `lib/src/providers/caption_output_target_registry_provider.dart`
- **Type**: `@Riverpod(keepAlive: true)` returning `CaptionOutputTargetRegistry`
- **Responsibility**: Provides the singleton registry. Subscribes to `CaptionBusProvider` on creation. Apps add/remove targets based on settings.
- **Visibility**: Exported

#### `TranscriptRepositoryProvider`
- **File**: `lib/src/providers/transcript_repository_provider.dart`
- **Type**: `@Riverpod(keepAlive: true)` returning `TranscriptRepository`
- **Responsibility**: Provides the singleton transcript repository backed by drift/SQLite.
- **Visibility**: Exported

#### `TranscriptSettingsProvider`
- **File**: `lib/src/providers/settings/transcript_settings_provider.dart`
- **Type**: `@Riverpod(keepAlive: true)` Notifier
- **Responsibility**: Manages transcript capture toggle (on/off). Persisted via `shared_preferences`. Separate from display settings per Q9 decision.
- **Visibility**: Exported

#### `LocaleInfoProvider` (modified)
- **File**: `lib/src/providers/locale_info_provider.dart` (existing)
- **Phase 1 changes**: No longer returns a stub list. Reads available locales from the active `SttEngine` via the `SttEngineProvider`. Updates when the active engine changes.
- **Visibility**: Exported

#### `RecordingStateNotifier` (modified)
- **File**: `lib/src/providers/recording_state_notifier.dart` (existing)
- **Phase 1 changes**: Wired to `SttEngineProvider`. `start()` initializes the engine and begins listening; `stop()` stops the engine; `pause()`/`resume()` delegate to engine. Publishes `SessionStateEvent`s to the `CaptionBus`. Security constraint unchanged: no transcript text in logs.
- **Visibility**: Exported

---

### Models (modified)

#### `DisplaySettings` (renamed from `AppSettings`)
- **File**: `lib/src/models/display_settings.dart` (renamed from `app_settings.dart`)
- **Phase 1 changes**: Renamed from `AppSettings` to `DisplaySettings` to accurately describe its scope — caption display configuration. Fields unchanged: `scrollDirection`, `captionTextSize`, `captionFont`, `themeModeSetting`, `maxVisibleLines`.
- **Visibility**: Exported

#### `RecordingState` (modified)
- **File**: `lib/src/models/recording_state.dart` (existing)
- **Phase 1 changes**: `recording` variant gains `currentSegment` field (nullable `TranscriptSegment` for the in-progress recognition). `stopped` variant gains `sessionId` field (reference to the completed session).
- **Visibility**: Exported

---

## New zip_captions Components

### Providers

#### `DisplaySettingsNotifier` (renamed from `ZipCaptionsSettingsNotifier`)
- **File**: `lib/providers/display_settings_notifier.dart`
- **Phase 1 changes**: Renamed from `ZipCaptionsSettingsNotifier`. Extends `BaseSettingsNotifier` (which now manages `DisplaySettings`). Key prefix: `'zip_captions.'`. No additional fields beyond the base.

### Screens

#### `RecordingScreen`
- **File**: `lib/screens/recording_screen.dart`
- **Responsibility**: Active captioning screen with live caption display, pause/resume/stop controls, audio level indicator. Watches `RecordingStateNotifier` and `OnScreenCaptionTarget` state.

#### `SettingsScreen`
- **File**: `lib/screens/settings_screen.dart`
- **Responsibility**: Settings UI for STT engine, language/locale, display settings (text size, font, theme, scroll direction), wake lock behavior, audio source, transcript capture toggle.

#### `SessionHistoryScreen`
- **File**: `lib/screens/session_history_screen.dart`
- **Responsibility**: Searchable list of saved transcripts. Uses `TranscriptRepository` for data and FTS5 search.

#### `TranscriptViewerScreen`
- **File**: `lib/screens/transcript_viewer_screen.dart`
- **Responsibility**: Individual transcript detail view with full text, timestamps, pause markers, and export/share button (TXT, SRT, VTT).

### Widgets

#### `CaptionDisplayWidget`
- **File**: `lib/widgets/caption_display_widget.dart`
- **Responsibility**: Renders live captions from `OnScreenCaptionTarget` state. Configurable text size, font, scroll direction, speaker change breaks. Reusable — also used in zip_broadcast.
- **Note**: May be extracted to zip_core if both apps need the exact same widget. Decision deferred to construction.

---

## New zip_broadcast Components

### Providers

#### `DisplaySettingsNotifier` (renamed from `ZipBroadcastSettingsNotifier`)
- **File**: `lib/providers/display_settings_notifier.dart`
- **Phase 1 changes**: Renamed from `ZipBroadcastSettingsNotifier`. Key prefix: `'zip_broadcast.'`.

#### `ObsSettingsProvider`
- **File**: `lib/providers/obs_settings_provider.dart`
- **Type**: `@Riverpod(keepAlive: true)` Notifier
- **Responsibility**: OBS WebSocket connection settings (host, port, password). Persisted via `shared_preferences` with `'zip_broadcast.obs.'` key prefix.

#### `AudioInputSettingsProvider`
- **File**: `lib/providers/audio_input_settings_provider.dart`
- **Type**: `@Riverpod(keepAlive: true)` Notifier, state type: `List<AudioInputConfig>`
- **Responsibility**: Manages the list of configured audio inputs with speaker labels and visual styles. Persisted. Single default input for initial state.

#### `OutputTargetSettingsProvider`
- **File**: `lib/providers/output_target_settings_provider.dart`
- **Type**: `@Riverpod(keepAlive: true)` Notifier
- **Responsibility**: Manages which output targets are enabled (on-screen, OBS, browser source, caption overlay). Persisted.

### Services (broadcast-only CaptionOutputTarget implementations)

#### `ObsWebSocketTarget`
- **File**: `lib/services/obs_websocket_target.dart`
- **Type**: Concrete `CaptionOutputTarget`
- **Responsibility**: Receives caption events and sends caption text to OBS via WebSocket v5 protocol. Uses `web_socket_channel` package. Manages connection lifecycle (connect, reconnect on drop, disconnect). Exposes connection state for UI status indicator.
- **Dependency**: `web_socket_channel`

#### `BrowserSourceTarget`
- **File**: `lib/services/browser_source_target.dart`
- **Type**: Concrete `CaptionOutputTarget`
- **Responsibility**: Receives caption events and pushes them to connected browser source clients via Server-Sent Events (SSE) or WebSocket. Works in conjunction with the `BrowserSourceServer`.

#### `BrowserSourceServer`
- **File**: `lib/services/browser_source_server.dart`
- **Type**: Plain Dart class
- **Responsibility**: Local HTTP server using `shelf` that serves the caption overlay HTML page and a real-time caption event endpoint (SSE or WebSocket). The HTML page renders the most recent two lines of text in a fixed position with transparent background. Respects display settings for text appearance.
- **Dependency**: `shelf`, `shelf_static` (if needed)

#### `CaptionOverlayTarget`
- **File**: `lib/services/caption_overlay_target.dart`
- **Type**: Concrete `CaptionOutputTarget`
- **Responsibility**: Receives caption events and renders them in a transparent, always-on-top, click-through overlay window on a target display. Implementation approach is spike-dependent (Q5=C) — the interface is defined now; the platform-specific window management is resolved during construction.

### Screens

#### `RecordingScreen`
- **File**: `lib/screens/recording_screen.dart`
- **Responsibility**: Active captioning screen with live captions, controls, OBS status indicator, browser source URL, caption overlay toggle, audio level indicator. Multi-input captions render with visually distinct styles per source.

#### `SettingsScreen`
- **File**: `lib/screens/settings_screen.dart`
- **Responsibility**: Settings UI for STT engine, language/locale, display settings, OBS connection, output target toggles, audio source selection, transcript capture toggle.

#### `AudioSourceConfigScreen`
- **File**: `lib/screens/audio_source_config_screen.dart`
- **Responsibility**: Multi-input audio configuration. Add/remove inputs, assign speaker labels and visual styles per input. Lists available microphones and system audio sources.
