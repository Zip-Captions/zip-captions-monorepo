# Component Methods — Phase 1: Core Captioning

Detailed business logic and state machine design happens in Functional Design (Construction Phase, per-unit). This document defines public API signatures and high-level purpose only.

**Naming note**: `AppSettings` is renamed to `DisplaySettings` per Q9 decision. `BaseSettingsNotifier` manages `DisplaySettings`. App-level subclasses are renamed accordingly.

---

## zip_core — New Components

### `SttResult` (freezed)

| Field | Type | Purpose |
|---|---|---|
| `text` | `String` | Recognized speech text |
| `isFinal` | `bool` | Whether this is a final (committed) result or interim |
| `confidence` | `double` | Recognition confidence (0.0–1.0) |
| `timestamp` | `DateTime` | When the utterance was recognized |
| `speakerTag` | `String?` | Optional speaker tag for future diarization |
| `sourceId` | `String` | Identifies the input source (for multi-input disambiguation) |

---

### `AudioInputConfig` (freezed)

| Field | Type | Purpose |
|---|---|---|
| `inputId` | `String` | Unique identifier for this input |
| `sourceDeviceId` | `String?` | Platform audio device identifier (null = default mic) |
| `speakerLabel` | `String` | User-assigned label (e.g., "Teacher", "Student Mic") |
| `visualStyle` | `AudioInputVisualStyle` | Color/indicator for rendering this source's captions |
| `isActive` | `bool` | Whether this input is currently capturing |

---

### `AudioInputVisualStyle` (freezed or enum)

| Field | Type | Purpose |
|---|---|---|
| `color` | `Color` | Caption text color for this source |
| `label` | `String?` | Optional display label shown alongside captions |

---

### `TranscriptSession` (freezed)

| Field | Type | Purpose |
|---|---|---|
| `id` | `String` | Unique session identifier |
| `date` | `DateTime` | Session start time |
| `duration` | `Duration` | Total session duration |
| `wordCount` | `int` | Total words in transcript |
| `language` | `String` | BCP-47 locale ID used for STT |
| `engineId` | `String` | STT engine identifier used |

---

### `TranscriptSegment` (freezed)

| Field | Type | Purpose |
|---|---|---|
| `text` | `String` | Segment text content |
| `startTime` | `Duration` | Offset from session start |
| `endTime` | `Duration` | Offset from session start |
| `sourceId` | `String` | Source identifier (speaker/input) |
| `isPause` | `bool` | Whether this segment represents a pause event |

---

### `CaptionEvent` (sealed class)

| Variant | Fields | Purpose |
|---|---|---|
| `CaptionEvent.sttResult` | `SttResult result` | Speech recognition result |
| `CaptionEvent.sessionState` | `RecordingState state` | Session lifecycle change |

---

### `SttEngine` (abstract — updated)

| Method / Property | Signature | Purpose |
|---|---|---|
| `engineId` | `String get engineId` | Unique identifier for this engine type |
| `displayName` | `String get displayName` | Human-readable engine name |
| `requiresNetwork` | `bool get requiresNetwork` | Whether engine needs internet |
| `requiresDownload` | `bool get requiresDownload` | Whether engine needs model download |
| `supportedLocales` | `Future<List<SpeechLocale>> get supportedLocales` | Locales this engine supports |
| `isAvailable` | `Future<bool> isAvailable()` | Check if engine can run on this device |
| `initialize` | `Future<bool> initialize()` | Request permissions, prepare engine |
| `startListening` | `Future<bool> startListening({required String localeId, required void Function(SttResult) onResult})` | Begin STT session with result callback |
| `stopListening` | `Future<void> stopListening()` | End STT session |
| `pause` | `Future<bool> pause()` | Pause recognition (transparent stop/restart if not natively supported) |
| `resume` | `Future<bool> resume()` | Resume recognition |
| `dispose` | `void dispose()` | Release all resources |

---

### `PlatformSttEngine` (implements `SttEngine`)

Wraps `speech_to_text` package. No additional public methods beyond `SttEngine` contract. Internal implementation handles:
- Platform detection (iOS/macOS → Apple Speech, Android → Google, Web → Web Speech API)
- Transparent pause via stop/restart on platforms without native pause
- Locale mapping between `speech_to_text` locale format and `SpeechLocale`

---

### `SttEngineRegistry`

| Method | Signature | Purpose |
|---|---|---|
| `register` | `void register(SttEngine engine)` | Register an available engine |
| `unregister` | `void unregister(String engineId)` | Remove an engine from the registry |
| `listAvailable` | `List<SttEngine> listAvailable()` | All registered engines |
| `getEngine` | `SttEngine? getEngine(String engineId)` | Get engine by ID (null if not registered) |
| `defaultEngine` | `SttEngine? get defaultEngine` | First registered engine (convenience) |

---

### `CaptionBus`

| Method / Property | Signature | Purpose |
|---|---|---|
| `publish` | `void publish(CaptionEvent event)` | Publish an event to all subscribers |
| `stream` | `Stream<CaptionEvent> get stream` | The broadcast stream (for registry subscription) |
| `dispose` | `void dispose()` | Close the internal StreamController |

---

### `CaptionOutputTarget` (abstract)

| Method | Signature | Purpose |
|---|---|---|
| `onCaptionEvent` | `void onCaptionEvent(CaptionEvent event)` | Handle an incoming caption event |
| `targetId` | `String get targetId` | Unique identifier for this target instance |
| `dispose` | `void dispose()` | Release resources |

---

### `CaptionOutputTargetRegistry`

| Method / Property | Signature | Purpose |
|---|---|---|
| `add` | `void add(CaptionOutputTarget target)` | Register and subscribe a target |
| `remove` | `void remove(CaptionOutputTarget target)` | Unsubscribe and remove a target |
| `activeTargets` | `Set<CaptionOutputTarget> get activeTargets` | Currently registered targets |
| `dispose` | `void dispose()` | Unsubscribe all targets, cancel bus subscription |

---

### `OnScreenCaptionTarget` (implements `CaptionOutputTarget`)

| Method / Property | Signature | Purpose |
|---|---|---|
| `onCaptionEvent` | `void onCaptionEvent(CaptionEvent event)` | Buffer incoming results for display |
| `visibleCaptions` | `List<CaptionDisplayEntry> get visibleCaptions` | Current visible caption entries for widget rendering |
| `onVisibleCaptionsChanged` | `Stream<List<CaptionDisplayEntry>> get onVisibleCaptionsChanged` | Stream for UI to listen to |
| `dispose` | `void dispose()` | Clear buffer, release resources |

---

### `TranscriptWriterTarget` (implements `CaptionOutputTarget`)

| Method / Property | Signature | Purpose |
|---|---|---|
| `onCaptionEvent` | `void onCaptionEvent(CaptionEvent event)` | Accumulate segments; persist on session stop |
| `isEnabled` | `bool get isEnabled` | Whether transcript capture is active |
| `dispose` | `void dispose()` | Flush pending data, release resources |

---

### `TranscriptRepository`

| Method | Signature | Purpose |
|---|---|---|
| `saveSession` | `Future<void> saveSession(TranscriptSession session, List<TranscriptSegment> segments)` | Persist a completed session |
| `getSessions` | `Future<List<TranscriptSession>> getSessions({int? limit, int? offset})` | List saved sessions (paginated) |
| `getSession` | `Future<TranscriptSession?> getSession(String id)` | Get session by ID |
| `getSegments` | `Future<List<TranscriptSegment>> getSegments(String sessionId)` | Get all segments for a session |
| `search` | `Future<List<TranscriptSession>> search(String query)` | FTS5 full-text search with BM25 ranking |
| `deleteSession` | `Future<void> deleteSession(String id)` | Delete a session and its segments |
| `exportSession` | `Future<String> exportSession(String sessionId, ExportFormat format)` | Export as TXT, SRT, or VTT string |

---

### `TranscriptSettingsProvider` (Notifier)

| Method / Property | Signature | Purpose |
|---|---|---|
| `build` | `TranscriptSettings build()` | Load persisted transcript settings |
| `setCaptureEnabled` | `Future<void> setCaptureEnabled(bool enabled)` | Toggle transcript capture on/off |
| `state` | `TranscriptSettings get state` | Current transcript settings |

---

## zip_core — Modified Components

### `DisplaySettings` (renamed from `AppSettings`, freezed)

| Field | Type | Default | Purpose |
|---|---|---|---|
| `scrollDirection` | `ScrollDirection` | `bottomToTop` | Caption text flow direction |
| `captionTextSize` | `CaptionTextSize` | `md` | Caption text size tier |
| `captionFont` | `CaptionFont` | `atkinsonHyperlegible` | Caption font selection |
| `themeModeSetting` | `ThemeModeSetting` | `system` | Theme mode |
| `maxVisibleLines` | `int` | `0` | Max caption lines (0 = unlimited) |

No new fields — display settings remain display-only. New settings live in separate providers.

### `BaseSettingsNotifier` (updated)

- Now manages `DisplaySettings` (renamed from `AppSettings`)
- Method signatures unchanged (operate on the same fields)
- Subclass naming updated: `ZipCaptionsSettingsNotifier` → `DisplaySettingsNotifier` (in each app)

### `RecordingStateNotifier` (updated)

| Method | Signature | Phase 1 Change |
|---|---|---|
| `start` | `Future<void> start({String? localeId})` | Initializes STT engine, begins listening, publishes `SessionStateEvent` to CaptionBus |
| `pause` | `Future<void> pause()` | Delegates to STT engine pause, publishes state change |
| `resume` | `Future<void> resume()` | Delegates to STT engine resume, publishes state change |
| `stop` | `Future<void> stop()` | Stops STT engine, publishes state change |
| `clearSession` | `void clearSession()` | Unchanged |

New dependency: `SttEngineProvider`, `CaptionBusProvider`.

### `LocaleInfoProvider` (updated)

| Method | Signature | Phase 1 Change |
|---|---|---|
| `build` | `List<SpeechLocale> build()` | Reads `supportedLocales` from active STT engine instead of returning stub list |

New dependency: `SttEngineProvider`.

---

## zip_broadcast — New Components

### `ObsWebSocketTarget` (implements `CaptionOutputTarget`)

| Method / Property | Signature | Purpose |
|---|---|---|
| `onCaptionEvent` | `void onCaptionEvent(CaptionEvent event)` | Send caption text to OBS |
| `connectionState` | `ObsConnectionState get connectionState` | Current connection status (connected/disconnected/error) |
| `onConnectionStateChanged` | `Stream<ObsConnectionState> get onConnectionStateChanged` | Stream for UI status indicator |
| `connect` | `Future<void> connect(ObsSettings settings)` | Establish WebSocket connection |
| `disconnect` | `Future<void> disconnect()` | Close WebSocket connection |
| `dispose` | `void dispose()` | Disconnect and release resources |

---

### `BrowserSourceServer`

| Method / Property | Signature | Purpose |
|---|---|---|
| `start` | `Future<void> start({int port})` | Start the local HTTP server |
| `stop` | `Future<void> stop()` | Stop the server |
| `url` | `String? get url` | The browser source URL (null if not running) |
| `isRunning` | `bool get isRunning` | Whether server is active |

---

### `BrowserSourceTarget` (implements `CaptionOutputTarget`)

| Method / Property | Signature | Purpose |
|---|---|---|
| `onCaptionEvent` | `void onCaptionEvent(CaptionEvent event)` | Push caption data to connected browser clients |
| `dispose` | `void dispose()` | Stop server, release resources |

---

### `CaptionOverlayTarget` (implements `CaptionOutputTarget`)

| Method / Property | Signature | Purpose |
|---|---|---|
| `onCaptionEvent` | `void onCaptionEvent(CaptionEvent event)` | Render captions in overlay window |
| `show` | `Future<void> show({required OverlayConfig config})` | Create and show overlay window |
| `hide` | `Future<void> hide()` | Close overlay window |
| `isVisible` | `bool get isVisible` | Whether overlay is currently showing |
| `dispose` | `void dispose()` | Hide and release resources |

**Note**: `OverlayConfig` includes target display, position (top/bottom/custom), transparency. Implementation approach is spike-dependent.

---

### `ObsSettingsProvider` (Notifier)

| Method / Property | Signature | Purpose |
|---|---|---|
| `build` | `ObsSettings build()` | Load persisted OBS settings |
| `setHost` | `Future<void> setHost(String host)` | Update OBS host |
| `setPort` | `Future<void> setPort(int port)` | Update OBS port |
| `setPassword` | `Future<void> setPassword(String password)` | Update OBS password |
| `state` | `ObsSettings get state` | Current OBS settings |

---

### `AudioInputSettingsProvider` (Notifier)

| Method / Property | Signature | Purpose |
|---|---|---|
| `build` | `List<AudioInputConfig> build()` | Load persisted input configs (default: single mic input) |
| `addInput` | `Future<void> addInput(AudioInputConfig config)` | Add a new audio input |
| `removeInput` | `Future<void> removeInput(String inputId)` | Remove an input |
| `updateInput` | `Future<void> updateInput(AudioInputConfig config)` | Update label, style, or source for an input |
| `state` | `List<AudioInputConfig> get state` | Current input configurations |

---

### `OutputTargetSettingsProvider` (Notifier)

| Method / Property | Signature | Purpose |
|---|---|---|
| `build` | `OutputTargetSettings build()` | Load persisted target toggles |
| `setOnScreenEnabled` | `Future<void> setOnScreenEnabled(bool enabled)` | Toggle on-screen rendering |
| `setObsEnabled` | `Future<void> setObsEnabled(bool enabled)` | Toggle OBS output |
| `setBrowserSourceEnabled` | `Future<void> setBrowserSourceEnabled(bool enabled)` | Toggle browser source |
| `setOverlayEnabled` | `Future<void> setOverlayEnabled(bool enabled)` | Toggle caption overlay |
| `state` | `OutputTargetSettings get state` | Current target toggles |
