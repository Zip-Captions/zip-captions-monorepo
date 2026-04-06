# Business Logic Model — Unit 3: Output Targets

## 1. OnScreenCaptionTarget (Q1=B, Q2=B)

Implements `CaptionOutputTarget`. Maintains an in-memory buffer of `CaptionDisplayEntry` items for live caption rendering with paged scrollback from `TranscriptRepository`.

```
+--------------------------------------------------------------------+
| OnScreenCaptionTarget implements CaptionOutputTarget               |
+--------------------------------------------------------------------+
| - _buffer: List<CaptionDisplayEntry>                               |
| - _currentInterim: CaptionDisplayEntry?                            |
| - _maxBufferSegments: int (default: 2000)                          |
| - _currentSessionId: String?                                       |
| - _repository: TranscriptRepository?                               |
| - _controller: StreamController<List<CaptionDisplayEntry>>         |
+--------------------------------------------------------------------+
| targetId: String                                                   |
| visibleCaptions: List<CaptionDisplayEntry>                         |
| onVisibleCaptionsChanged: Stream<List<CaptionDisplayEntry>>        |
+--------------------------------------------------------------------+
| + onCaptionEvent(CaptionEvent event): void                         |
| + loadOlderSegments({required String beforeEntryId,                |
|     required int limit}): Future<List<CaptionDisplayEntry>>        |
| + dispose(): void                                                  |
+--------------------------------------------------------------------+
```

### Event Handling

```
onCaptionEvent(SttResultEvent)
    |
    ├── result.isFinal == false
    |       |
    |       └── replace _currentInterim with new entry (same entryId if same sourceId + session, new UUID otherwise)
    |           emit updated visibleCaptions (_buffer + [_currentInterim])
    |
    └── result.isFinal == true
            |
            ├── promote _currentInterim to _buffer (appended as final entry)
            ├── _currentInterim = null
            ├── if _buffer.length > _maxBufferSegments → evict oldest entry from _buffer.removeAt(0)
            └── emit updated visibleCaptions

onCaptionEvent(SessionStateEvent)
    |
    ├── state is recording → _currentSessionId = state.sessionId; clear _buffer; _currentInterim = null
    ├── state is stopped   → _currentInterim = null; emit final visibleCaptions
    └── other             → no-op
```

### visibleCaptions Ordering

`visibleCaptions` returns `[..._buffer, if (_currentInterim != null) _currentInterim!]`.

The buffer grows from oldest (index 0) to newest (last). The UI widget determines scroll direction based on `DisplaySettings.scrollDirection`. Buffer eviction removes from index 0 (oldest first) — the evicted entries are accessible via `loadOlderSegments()` for scrollback.

### Scrollback via loadOlderSegments() (Q1=B)

When the user scrolls up past the in-memory buffer boundary, the UI calls `loadOlderSegments()`:

```
loadOlderSegments(beforeEntryId, limit)
    |
    ├── if _repository == null → return []  (transcript capture not active)
    |
    └── query _repository.getSegmentsBefore(
              sessionId: _currentSessionId,
              beforeTimestamp: _timestampOf(beforeEntryId),
              limit: limit,
          )
          |
          └── map TranscriptSegment → CaptionDisplayEntry (isFinal: true)
              return results ordered oldest-first
```

`loadOlderSegments()` is available only when a `TranscriptRepository` is injected (via constructor). When transcript capture is disabled, scrollback returns an empty list; the in-memory buffer is the full history.

### Constructor

```dart
OnScreenCaptionTarget({
  required String targetId,
  int maxBufferSegments = 2000,
  TranscriptRepository? repository,
})
```

The `repository` parameter is injected by the provider that constructs this target. It is `null` when `TranscriptSettings.captureEnabled == false`.

---

## 2. TranscriptWriterTarget (Q3=C)

Implements `CaptionOutputTarget`. Accumulates only final results, merging consecutive results from the same `sourceId` within a 2-second window into a single segment. Flushes to `TranscriptRepository` periodically and on session stop.

```
+----------------------------------------------------+
| TranscriptWriterTarget implements CaptionOutputTarget|
+----------------------------------------------------+
| - _repository: TranscriptRepository               |
| - _settings: TranscriptSettings                   |
| - _pendingSegments: List<TranscriptSegment>        |
| - _lastFinalBySource: Map<String, TranscriptSegment>|
| - _sessionId: String?                             |
| - _sessionStartMs: int?                           |
| - _flushTimer: Timer?                             |
+----------------------------------------------------+
| isEnabled: bool                                   |
+----------------------------------------------------+
| + onCaptionEvent(CaptionEvent event): void        |
| + dispose(): void                                 |
+----------------------------------------------------+
```

### Segment Accumulation Logic (Q3=C)

On each `SttResultEvent` where `result.isFinal == true`:

```
isFinal result arrives for sourceId S at wallClockMs T
    |
    ├── _settings.captureEnabled == false → discard
    |
    └── check _lastFinalBySource[S]:
            |
            ├── no prior segment for S
            |       └── create new segment; store in _lastFinalBySource[S] + _pendingSegments
            |
            ├── prior segment exists AND (T - priorSegment.endTimeMs) <= 2000ms
            |       └── merge: append result.text to prior segment text (with a space);
            |           update prior segment endTimeMs = T - _sessionStartMs;
            |           replace in _pendingSegments
            |
            └── prior segment exists AND (T - priorSegment.endTimeMs) > 2000ms
                    └── create new segment; store in _lastFinalBySource[S] + _pendingSegments
```

**Merge semantics**: `segment.text` becomes `"${prior.text} ${result.text}"` (single space separator). `endTimeMs` is updated; `startTimeMs` is unchanged (beginning of the merged utterance).

### Session Lifecycle

```
SessionStateEvent(recording) arrives
    |
    └── _sessionId = state.sessionId
        _sessionStartMs = DateTime.now().millisecondsSinceEpoch
        _pendingSegments.clear()
        _lastFinalBySource.clear()
        start _flushTimer (periodic, every 30 seconds)

SessionStateEvent(stopped) arrives
    |
    └── cancel _flushTimer
        flush all _pendingSegments to _repository (final flush)
        update TranscriptSession.durationMs and segmentCount
        _sessionId = null
```

### Periodic Flush

Every 30 seconds during an active session:
```
_flushPending()
    |
    └── if _pendingSegments.isEmpty → no-op
        else → _repository.saveSegments(_sessionId!, List.of(_pendingSegments))
               _pendingSegments.clear()
               (Note: _lastFinalBySource retained — merge window continues across flush boundary)
```

The 30-second flush makes recent segments available to `OnScreenCaptionTarget.loadOlderSegments()` for scrollback (Q1=B requirement).

### isEnabled

```dart
bool get isEnabled => _settings.captureEnabled;
```

When `isEnabled == false`, all `SttResultEvent`s are discarded. `SessionStateEvent`s are still processed to maintain internal state consistency, but no data is written to the repository.

---

## 3. TranscriptDatabase (drift schema)

A `drift` database with two tables and one FTS5 virtual table.

### Schema

```dart
class TranscriptSessions extends Table {
  TextColumn get sessionId => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get title => text().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get segmentCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {sessionId};
}

class TranscriptSegments extends Table {
  TextColumn get segmentId => text()();
  TextColumn get sessionId => text().references(TranscriptSessions, #sessionId,
      onDelete: KeyAction.cascade)();
  TextColumn get text => text()();
  TextColumn get sourceId => text()();
  IntColumn get startTimeMs => integer()();
  IntColumn get endTimeMs => integer()();

  @override
  Set<Column> get primaryKey => {segmentId};
}
```

**FTS5 virtual table** (created via `customStatement` in `onCreate`):

```sql
CREATE VIRTUAL TABLE transcript_fts USING fts5(
  text,
  segment_id UNINDEXED,
  session_id UNINDEXED,
  content=transcript_segments,
  content_rowid=rowid,
  tokenize='porter unicode61'
);
```

Triggers keep the FTS5 index in sync:

```sql
-- Insert trigger
CREATE TRIGGER fts_insert AFTER INSERT ON transcript_segments BEGIN
  INSERT INTO transcript_fts(rowid, text, segment_id, session_id)
  VALUES (NEW.rowid, NEW.text, NEW.segment_id, NEW.session_id);
END;

-- Delete trigger
CREATE TRIGGER fts_delete AFTER DELETE ON transcript_segments BEGIN
  INSERT INTO transcript_fts(transcript_fts, rowid, text, segment_id, session_id)
  VALUES ('delete', OLD.rowid, OLD.text, OLD.segment_id, OLD.session_id);
END;
```

**Database file location**: `getApplicationDocumentsDirectory()/transcripts.db` (all platforms).

---

## 4. TranscriptRepository

A plain Dart class wrapping the drift `TranscriptDatabase`. Implements the contract from Application Design with the updated `search()` return type.

```
+-----------------------------------------------------------------------+
| TranscriptRepository                                                  |
+-----------------------------------------------------------------------+
| - _db: TranscriptDatabase                                             |
+-----------------------------------------------------------------------+
| + saveSession(session, segments): Future<void>                        |
| + saveSegments(sessionId, segments): Future<void>                     |
| + getSessions({limit, offset}): Future<List<TranscriptSession>>       |
| + getSession(sessionId): Future<TranscriptSession?>                   |
| + getSegments(sessionId): Future<List<TranscriptSegment>>             |
| + getSegmentsBefore({sessionId, beforeTimestamp, limit}):             |
|     Future<List<TranscriptSegment>>                                   |
| + search(query): Future<List<TranscriptSearchResult>>                 |
| + deleteSession(sessionId): Future<void>                              |
| + exportSession(sessionId, format): Future<String>                    |
+-----------------------------------------------------------------------+
```

### saveSession()

```
saveSession(session, segments)
    |
    ├── upsert TranscriptSession row (update durationMs, segmentCount, title if null)
    ├── insert all new TranscriptSegment rows
    └── (FTS5 triggers fire automatically on INSERT)
```

`saveSegments()` is a lower-level version used during periodic flush — it inserts only segments without updating the session row.

### getSegmentsBefore()

Used by `OnScreenCaptionTarget.loadOlderSegments()` for scrollback:

```sql
SELECT * FROM transcript_segments
WHERE session_id = :sessionId
  AND start_time_ms < :beforeTimestamp
ORDER BY start_time_ms DESC
LIMIT :limit
```

Results are returned in ascending order (oldest first) for display.

### search() — FTS5 with BM25 (Q4=C)

```
search(query)
    |
    ├── run FTS5 query:
    |     SELECT
    |       ts.session_id,
    |       snippet(transcript_fts, 0, '[', ']', '...', 64) AS snippet,
    |       bm25(transcript_fts) AS score
    |     FROM transcript_fts
    |     JOIN transcript_segments seg ON seg.segment_id = transcript_fts.segment_id
    |     JOIN transcript_sessions ts ON ts.session_id = seg.session_id
    |     WHERE transcript_fts MATCH :query
    |     ORDER BY score ASC  -- lower BM25 = more relevant
    |     LIMIT 50
    |
    ├── group rows by session_id (collect up to 3 snippets per session)
    |
    └── for each unique session:
          fetch TranscriptSession metadata from DB
          return TranscriptSearchResult(session, snippets, relevanceScore)
```

Results are ordered by the best (lowest) BM25 score across that session's matching segments.

**Snippet delimiters**: `[` and `]` surround matched terms. Example: `"...your [microphone] is working..."`. The UI replaces these with styled spans for highlighting.

### exportSession()

```
exportSession(sessionId, format)
    |
    ├── fetch session + all segments (ordered by startTimeMs ASC)
    |
    └── switch format:
          case txt → join segment.text with '\n\n'
          case srt → format each segment as SRT block (see export format section)
          case vtt → format each segment as VTT block (see export format section)
```

---

## 5. Transcript Export Formats (Q5=A)

All timestamps are relative to session start (Q5=A). Empty segments are excluded (BR-U3-15).

### TXT

```
Plain text, one segment per paragraph, separated by blank lines.
No timestamps, no metadata header.
```

### SRT (SubRip)

```
{index}\n
{HH:MM:SS,mmm} --> {HH:MM:SS,mmm}\n
{text}\n
\n
```

Example:
```
1
00:00:01,240 --> 00:00:04,110
Hello, welcome to today's session.

2
00:00:04,580 --> 00:00:07,920
The microphone is working correctly.
```

**Timestamp conversion**:
```dart
String _srtTimestamp(int ms) {
  final h = ms ~/ 3600000;
  final m = (ms % 3600000) ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  final millis = ms % 1000;
  return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')},${millis.toString().padLeft(3,'0')}';
}
```

### VTT (WebVTT)

```
WEBVTT\n
\n
{HH:MM:SS.mmm} --> {HH:MM:SS.mmm}\n
{text}\n
\n
```

VTT differs from SRT in two ways: the `WEBVTT` header and `.` instead of `,` as the decimal separator.

---

## 6. ObsWebSocketTarget (Q6=A, Q7=C)

Implements `CaptionOutputTarget`. Uses the `obs_websocket` pub.dev package for OBS WebSocket v5 protocol. Sends captions via the `SendStreamCaption` request.

```
+------------------------------------------------------------+
| ObsWebSocketTarget implements CaptionOutputTarget          |
+------------------------------------------------------------+
| - _client: ObsWebSocket?                                   |
| - _settings: ObsSettings                                   |
| - _connectionState: ObsConnectionState                     |
| - _reconnectTimer: Timer?                                  |
| - _retryStartMs: int?                                      |
| - _retryAttempt: int                                       |
| - _stateController: StreamController<ObsConnectionState>   |
| - _enabled: bool                                           |
+------------------------------------------------------------+
| targetId: 'obs-websocket'                                  |
| connectionState: ObsConnectionState                        |
| onConnectionStateChanged: Stream<ObsConnectionState>       |
+------------------------------------------------------------+
| + onCaptionEvent(CaptionEvent event): void                 |
| + connect(ObsSettings settings): Future<void>              |
| + disconnect(): Future<void>                               |
| + dispose(): void                                          |
+------------------------------------------------------------+
```

### connect()

```
connect(settings)
    |
    ├── _settings = settings
    ├── _enabled = true
    ├── _retryStartMs = now()
    ├── _retryAttempt = 0
    ├── emit ObsConnecting
    └── _attemptConnect()
```

### _attemptConnect()

```
_attemptConnect()
    |
    ├── try:
    |     _client = await ObsWebSocket.connect(
    |       'ws://${_settings.host}:${_settings.port}',
    |       password: _settings.password,
    |     )
    |     _client.onClose = _handleDisconnect
    |     emit ObsConnected
    |
    └── catch (e):
          _handleConnectionFailure()
```

### _handleDisconnect() / _handleConnectionFailure()

```
_handleConnectionFailure()
    |
    ├── if !_enabled → no-op (user disabled OBS output)
    |
    ├── elapsed = now() - _retryStartMs!
    │
    ├── elapsed >= 10 minutes (600,000 ms) → emit ObsError; stop
    |
    └── _retryAttempt++
        delayMs = min(1000 * pow(2, _retryAttempt - 1), 30000)
        emit ObsReconnecting(attempt: _retryAttempt, nextRetryMs: delayMs)
        _reconnectTimer = Timer(Duration(milliseconds: delayMs), _attemptConnect)
```

### Caption Sending

```
onCaptionEvent(SttResultEvent)
    |
    ├── _connectionState is! ObsConnected → discard
    ├── result.isFinal == false → discard (send final captions only)
    └── _client!.sendRequest(RequestBatch([
            Request('SendStreamCaption', {'captionText': result.text})
        ]))
        on error → _handleDisconnect()
```

`SttResultEvent`s with `isFinal == false` are discarded — OBS captions show only committed utterances to avoid flickering interim text.

### Reconnection Backoff Schedule

| Attempt | Delay |
|---------|-------|
| 1 | 1 s |
| 2 | 2 s |
| 3 | 4 s |
| 4 | 8 s |
| 5 | 16 s |
| 6+ | 30 s (capped) |

Retry stops when total elapsed time since first failure >= 600,000 ms (10 minutes).

---

## 7. BrowserSourceServer (Q8=B, Q9=C)

A `shelf`-based HTTP server serving the caption overlay HTML page and an SSE endpoint.

```
+--------------------------------------------------+
| BrowserSourceServer                              |
+--------------------------------------------------+
| - _server: HttpServer?                           |
| - _sseClients: List<StreamSink<String>>          |
| - _latestCaption: String?                        |
| - _settings: OutputTargetSettings                |
+--------------------------------------------------+
| url: String?                                     |
| isRunning: bool                                  |
+--------------------------------------------------+
| + start({int? port}): Future<void>               |
| + stop(): Future<void>                           |
| + pushCaption(String text, bool isFinal): void   |
+--------------------------------------------------+
```

### shelf Pipeline

```
Router:
  GET /           → HTML overlay page (generated from template)
  GET /captions   → SSE endpoint
  ALL *           → 404
```

### HTML Template Generation (Q9=C)

The overlay HTML page is generated at request time by interpolating current `DisplaySettings` values into a Dart string template. This allows font size, font family, and color to update on page reload without a server restart.

```dart
String _generateHtml(DisplaySettings displaySettings) {
  final fontSize = switch (displaySettings.captionTextSize) {
    CaptionTextSize.sm => '1.2rem',
    CaptionTextSize.md => '1.8rem',
    CaptionTextSize.lg => '2.4rem',
    CaptionTextSize.xl => '3rem',
  };
  final fontFamily = switch (displaySettings.captionFont) {
    CaptionFont.atkinsonHyperlegible => "'Atkinson Hyperlegible', sans-serif",
    CaptionFont.openDyslexic => "'OpenDyslexic', sans-serif",
    CaptionFont.systemDefault => "system-ui, sans-serif",
  };
  // ... returns full HTML/CSS/JS with SSE client that connects to /captions
}
```

The generated page includes a JavaScript SSE client that:
1. Connects to `/captions`
2. On `sttResult` event: updates the caption display element; fades out interim text, makes final text opaque
3. On `sessionState` event: clears display on `stopped` state

### SSE Endpoint — Minimal JSON Payload (Q10=A)

```
GET /captions → 200 text/event-stream

On pushCaption(text, isFinal):
    broadcast to all connected clients:
        data: {"type":"sttResult","text":"...","isFinal":true}\n\n

On session state change (stopped):
    broadcast:
        data: {"type":"sessionState","state":"stopped"}\n\n
```

New clients receive the `_latestCaption` immediately on connect (if one exists) so they do not see a blank page during an active session.

### Port Validation

`browserSourcePort` must be in range 1024–65535. If `OutputTargetSettings.browserSourcePort` is outside this range, `start()` throws `ArgumentError`. The `OutputTargetSettingsProvider` validates on set (BR-U3-20).

---

## 8. BrowserSourceTarget

Implements `CaptionOutputTarget`. Bridges the `CaptionBus` to `BrowserSourceServer.pushCaption()`.

```
+--------------------------------------------------+
| BrowserSourceTarget implements CaptionOutputTarget|
+--------------------------------------------------+
| - _server: BrowserSourceServer                   |
+--------------------------------------------------+
| targetId: 'browser-source'                       |
+--------------------------------------------------+
| + onCaptionEvent(CaptionEvent event): void       |
| + dispose(): void                                |
+--------------------------------------------------+
```

```
onCaptionEvent(SttResultEvent)
    |
    └── _server.pushCaption(result.text, result.isFinal)

onCaptionEvent(SessionStateEvent)
    |
    ├── state is recording → _server.pushCaption('', false)  [clear on new session]
    └── state is stopped   → _server.pushSessionState('stopped')
```

---

## 9. CaptionOverlayTarget (Q12=A)

Implements `CaptionOutputTarget`. Creates and manages a Flutter platform window on the specified display using the `desktop_multi_window` package. Renders captions in the secondary window.

```
+----------------------------------------------------+
| CaptionOverlayTarget implements CaptionOutputTarget|
+----------------------------------------------------+
| - _windowId: int?                                  |
| - _config: OverlayConfig?                          |
| - _isVisible: bool                                 |
+----------------------------------------------------+
| targetId: 'caption-overlay'                        |
| isVisible: bool                                    |
+----------------------------------------------------+
| + onCaptionEvent(CaptionEvent event): void         |
| + show({required OverlayConfig config}): Future<void>|
| + hide(): Future<void>                             |
| + dispose(): void                                  |
+----------------------------------------------------+
```

### Window Lifecycle

```
show(config)
    |
    ├── if _isVisible → update window config (resize/reposition)
    |
    └── _windowId = await DesktopMultiWindow.createWindow(
              jsonEncode({'type': 'captionOverlay', 'config': config.toJson()})
          )
        configure window: frameless, always-on-top, opacity = config.opacity
        position on config.targetDisplayId if specified
        _isVisible = true

hide()
    |
    └── if _windowId != null → DesktopMultiWindow.closeWindow(_windowId!)
        _windowId = null
        _isVisible = false
```

### Caption Rendering in Overlay Window

The secondary window is a minimal Flutter widget tree rendering the last two lines of captions. Caption events are forwarded via `DesktopMultiWindow` event channel:

```
onCaptionEvent(SttResultEvent)
    |
    └── if !_isVisible → discard
        DesktopMultiWindow.invokeMethod(
          _windowId!,
          'captionUpdate',
          {'text': result.text, 'isFinal': result.isFinal},
        )
```

The overlay window's widget listens on the method channel and updates its `ValueNotifier<String>` to trigger a rebuild.

### Platform Support

`CaptionOverlayTarget` is only available on desktop platforms (macOS, Windows, Linux) where `desktop_multi_window` is supported. On mobile and web, `isVisible` always returns `false` and `show()` is a no-op.

---

## 10. Provider Layer

### New Providers in zip_core

| Provider | Type | keepAlive | Purpose |
|----------|------|-----------|---------|
| `transcriptRepositoryProvider` | `Provider<TranscriptRepository>` | Yes | Singleton repository; drift database init |
| `transcriptSettingsProvider` | `Notifier<TranscriptSettings>` | Yes | SharedPreferences-backed capture toggle |

### New Providers in zip_broadcast

| Provider | Type | keepAlive | Purpose |
|----------|------|-----------|---------|
| `obsSettingsProvider` | `Notifier<ObsSettings>` | Yes | OBS settings; password via flutter_secure_storage |
| `outputTargetSettingsProvider` | `Notifier<OutputTargetSettings>` | Yes | Per-target toggles + browser port |

### obsSettingsProvider — Password Handling (Q11=A)

```dart
@Riverpod(keepAlive: true)
class ObsSettingsNotifier extends _$ObsSettingsNotifier {
  static const _hostKey = 'obs.host';
  static const _portKey = 'obs.port';
  static const _passwordKey = 'obs.password';

  @override
  ObsSettings build() {
    // Load host/port from SharedPreferences synchronously
    final prefs = ref.read(sharedPreferencesProvider);
    final host = prefs.getString(_hostKey) ?? 'localhost';
    final port = prefs.getInt(_portKey) ?? 4455;

    // Load password from flutter_secure_storage asynchronously
    // Initial state has empty password; updates when secure read completes
    _loadPassword();

    return ObsSettings(host: host, port: port);
  }

  Future<void> _loadPassword() async {
    const storage = FlutterSecureStorage();
    final password = await storage.read(key: _passwordKey) ?? '';
    if (password.isNotEmpty) {
      state = state.copyWith(password: password);
    }
  }

  Future<void> setPassword(String password) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: _passwordKey, value: password);
    state = state.copyWith(password: password);
  }

  Future<void> setHost(String host) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_hostKey, host);
    state = state.copyWith(host: host);
  }

  Future<void> setPort(int port) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_portKey, port);
    state = state.copyWith(port: port);
  }
}
```

### outputTargetSettingsProvider — Port Validation

```dart
Future<void> setBrowserSourcePort(int port) async {
  if (port < 1024 || port > 65535) {
    throw ArgumentError.value(port, 'port', 'Must be in range 1024–65535');
  }
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.setInt('output_targets.browser_source_port', port);
  state = state.copyWith(browserSourcePort: port);
}
```

### Provider Dependency Map

```
SharedPreferencesProvider (existing)
    |
    +---> TranscriptSettingsProvider
    +---> ObsSettingsNotifier (host, port)
    +---> OutputTargetSettingsProvider

FlutterSecureStorage (instantiated inline)
    |
    +---> ObsSettingsNotifier (password)

TranscriptRepositoryProvider
    |
    +---> TranscriptWriterTarget (injected at construction)
    +---> OnScreenCaptionTarget (injected at construction, nullable)

CaptionBusProvider (existing, Unit 1)
    |
    +---> OnScreenCaptionTarget (subscribes via CaptionOutputTargetRegistry)
    +---> TranscriptWriterTarget (subscribes)
    +---> ObsWebSocketTarget (subscribes)
    +---> BrowserSourceTarget (subscribes via BrowserSourceServer)
    +---> CaptionOverlayTarget (subscribes)

OutputTargetSettingsProvider
    |
    +---> BrowserSourceServer (reads port)
    +---> CaptionOutputTargetRegistry (enables/disables targets based on toggles)
```
