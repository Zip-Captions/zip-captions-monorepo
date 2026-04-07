# Logical Components — Unit 3: Output Targets

## Overview

Unit 3 introduces output target implementations in two packages: `zip_core` (transcript storage and
on-screen captions) and `zip_broadcast` (OBS WebSocket, browser source, caption overlay). Nine
runtime components and six test infrastructure elements are defined below.

---

## Runtime Component Map

```
+-----------------------------------------------------------------------+
|                             zip_core                                   |
|                                                                        |
|  +-----------------------------+   +------------------------------+    |
|  | OnScreenCaptionTarget       |   | TranscriptRepository         |    |
|  | implements CaptionOutputTarget  | (plain class, keepAlive      |    |
|  | - _buffer: List<CaptionDisplayEntry>  provider)               |    |
|  | - _currentInterim: CaptionDisplayEntry?  - FTS5 search        |    |
|  | - _debounceTimer: Timer?    |   | - saveSegment / upsert       |    |
|  | - _controller: StreamController  - getSegmentsBefore          |    |
|  | - _repository: TranscriptRepository?  - exportSession         |    |
|  | - _maxBufferSegments: int   |   | - finalizeSession            |    |
|  | Debounce: 50ms Timer (P1)   |   | - Stream<RepositoryEvent>    |    |
|  +-----------------------------+   +------------------------------+    |
|                                               |                        |
|  +-----------------------------+   +------------------------------+    |
|  | TranscriptWriterTarget      |   | TranscriptDatabase           |    |
|  | implements CaptionOutputTarget  | (drift, schemaVersion: 1)   |    |
|  | - _repository: TranscriptRepository  - TranscriptSessions     |    |
|  | - _lastFinalBySource: Map   |   | - TranscriptSegments         |    |
|  | - _sessionId, _startMs      |   | - transcript_fts (FTS5)      |    |
|  | Immediate persistence (P6)  |   | - INSERT/DELETE triggers     |    |
|  | No _pendingSegments list     |   | - onCreate PRAGMA integrity  |    |
|  | No _flushTimer               |   |   check + rename (P5)        |    |
|  +-----------------------------+   +------------------------------+    |
|                                                                        |
|  New Providers (Riverpod, keepAlive):                                  |
|  - transcriptRepositoryProvider  (Provider<TranscriptRepository>)      |
|  - transcriptSettingsProvider    (Notifier<TranscriptSettings>)        |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
|                           zip_broadcast                                |
|                                                                        |
|  +-----------------------------+   +------------------------------+    |
|  | ObsWebSocketTarget          |   | BrowserSourceServer          |    |
|  | implements CaptionOutputTarget  | (shelf HTTP + SSE)           |    |
|  | - _client: ObsWebSocket?    |   | - _clients: List<SC<List<int>>>   |
|  | - _reconnectTimer: Timer?   |   | - _activeClientCount: int    |    |
|  | - _connectionState          |   | - _token: String?            |    |
|  | - _stateController          |   | - _latestCaption: String?    |    |
|  | Backoff: 1s→30s cap (P8)    |   | Cap: 5 clients (P3)          |    |
|  | 10min timeout               |   | Disconnect: SC.done (P3)     |    |
|  +-----------------------------+   | Token: UUID bypass (P4)      |    |
|                                    +------------------------------+    |
|  +-----------------------------+              |                        |
|  | BrowserSourceTarget         |   +------------------------------+    |
|  | implements CaptionOutputTarget  | CaptionOverlayTarget         |    |
|  | - _server: BrowserSourceServer  | implements CaptionOutputTarget    |
|  | bridges CaptionBus → server |   | - _windowId: int?            |    |
|  +-----------------------------+   | - _windowService: DesktopWindowService  |
|                                    | - _isVisible: bool           |    |
|  +-----------------------------+   +------------------------------+    |
|  | DesktopWindowService        |              |                        |
|  | (abstract interface)        |   +------------------------------+    |
|  | - createWindow()            |   | DesktopMultiWindowService    |    |
|  | - closeWindow()             |   | implements DesktopWindowService   |
|  | - invokeMethod()            |   | wraps desktop_multi_window   |    |
|  | - isSupported               |   | platform channel APIs        |    |
|  +-----------------------------+   +------------------------------+    |
|                                                                        |
|  New Providers (Riverpod, keepAlive):                                  |
|  - obsSettingsProvider           (Notifier<ObsSettings>)               |
|  - outputTargetSettingsProvider  (Notifier<OutputTargetSettings>)      |
+-----------------------------------------------------------------------+
```

---

## RC-01: OnScreenCaptionTarget

**Package**: `zip_core`
**Location**: `packages/zip_core/lib/src/output/on_screen_caption_target.dart`
**Pattern**: P1 (Timer-Based Debounce)

**Responsibilities**:
- Maintain `_buffer: List<CaptionDisplayEntry>` (up to `_maxBufferSegments`, default 2000)
- Track `_currentInterim: CaptionDisplayEntry?` for the in-progress utterance
- Coalesce `_controller.add()` calls to ≤1 per 50ms via `_debounceTimer`
- Expose `onVisibleCaptionsChanged: Stream<List<CaptionDisplayEntry>>`
- Serve scrollback via `loadOlderSegments()` when `_repository != null`

**Key fields**:

| Field | Type | Purpose |
|-------|------|---------|
| `_buffer` | `List<CaptionDisplayEntry>` | Final segments, oldest→newest |
| `_currentInterim` | `CaptionDisplayEntry?` | Current interim result |
| `_debounceTimer` | `Timer?` | 50ms emission debounce |
| `_controller` | `StreamController<List<CaptionDisplayEntry>>` | Broadcast stream |
| `_repository` | `TranscriptRepository?` | Optional; null when capture disabled |
| `_maxBufferSegments` | `int` | Eviction threshold (default 2000) |
| `_currentSessionId` | `String?` | Active session for scrollback queries |

**Constructor**:
```dart
OnScreenCaptionTarget({
  required String targetId,
  int maxBufferSegments = 2000,
  TranscriptRepository? repository,
})
```

**NFR links**: PERF-U3.1, TEST-U3.3

---

## RC-02: TranscriptWriterTarget

**Package**: `zip_core`
**Location**: `packages/zip_core/lib/src/output/transcript_writer_target.dart`
**Pattern**: P6 (Immediate Segment Persistence)

**Responsibilities**:
- Accept final `SttResultEvent`s; apply 2-second merge window per `sourceId`
- Persist each segment immediately via `repository.saveSegment()` (new or upsert)
- On session stop: call `repository.finalizeSession()` and clear state
- No periodic flush timer; no `_pendingSegments` list

**Key fields**:

| Field | Type | Purpose |
|-------|------|---------|
| `_repository` | `TranscriptRepository` | Write target |
| `_settings` | `TranscriptSettings` | `captureEnabled` toggle |
| `_lastFinalBySource` | `Map<String, TranscriptSegment>` | Merge window state per source |
| `_sessionId` | `String?` | Active session ID |
| `_sessionStartMs` | `int?` | Wall-clock ms at session start |
| `_totalSegmentCount` | `int` | For `finalizeSession()` metadata |

**NFR links**: REL-U3.3, TEST-U3.3, TEST-U3.4

---

## RC-03: TranscriptDatabase

**Package**: `zip_core`
**Location**: `packages/zip_core/lib/src/database/transcript_database.dart`
**Pattern**: P2 (FTS5 Schema), P5 (Corruption Recovery)

**Responsibilities**:
- drift database at `schemaVersion: 1` with `TranscriptSessions` and `TranscriptSegments` tables
- Create FTS5 virtual table `transcript_fts` and sync triggers in `onCreate`
- Run `PRAGMA integrity_check` on open; rename corrupt file and emit event before opening fresh DB
- Scaffold `onUpgrade` switch for future schema versions (MAINT-U3.1)

**Schema**: See `business-logic-model.md` §3.

**Corruption Recovery**: Implemented in `TranscriptDatabase.open()` static factory. No
`DatabaseHealthChecker` abstraction (NFR-DQ2 = C). The PRAGMA + rename path is covered by
acceptance tests only; unit tests cover downstream event handling.

**NFR links**: PERF-U3.2, REL-U3.1, MAINT-U3.1

---

## RC-04: TranscriptRepository

**Package**: `zip_core`
**Location**: `packages/zip_core/lib/src/output/transcript_repository.dart`
**Pattern**: P2 (FTS5 search)

**Responsibilities**:
- Wrap `TranscriptDatabase`; expose the domain API used by `TranscriptWriterTarget` and
  `OnScreenCaptionTarget`
- Implement `search()` using `customSelect` with the FTS5 MATCH + BM25 + snippet pipeline
- Expose `Stream<RepositoryEvent> get events` for corruption notifications
- Implement `exportSession()` for TXT, SRT, and VTT formats

**Public API**:

| Method | Purpose |
|--------|---------|
| `saveSession(session, segments)` | Upsert session row + insert segments |
| `saveSegment(sessionId, segment)` | Insert or replace single segment (immediate persistence) |
| `finalizeSession(sessionId, {durationMs, segmentCount})` | Update session metadata on stop |
| `getSessions({limit, offset})` | Paginated session list |
| `getSession(sessionId)` | Single session lookup |
| `getSegments(sessionId)` | All segments for a session |
| `getSegmentsBefore({sessionId, beforeTimestamp, limit})` | Scrollback query |
| `search(query)` | FTS5 full-text search → `List<TranscriptSearchResult>` |
| `deleteSession(sessionId)` | Cascade delete (FK) |
| `exportSession(sessionId, format)` | TXT / SRT / VTT export |
| `events` | `Stream<RepositoryEvent>` (corruption events) |

**NFR links**: PERF-U3.2, REL-U3.1, TEST-U3.3

---

## RC-05: ObsWebSocketTarget

**Package**: `zip_broadcast`
**Location**: `packages/zip_broadcast/lib/src/output/obs/obs_websocket_target.dart`
**Pattern**: P8 (fake_async backoff tests)

**Responsibilities**:
- Connect to OBS via `obs_websocket` (WebSocket v5 protocol)
- Send `SendStreamCaption` for final `SttResultEvent`s only
- Implement exponential backoff reconnection (1s→30s cap) with 10-minute timeout
- Expose `Stream<ObsConnectionState>` for UI state display

**Key fields**:

| Field | Type | Purpose |
|-------|------|---------|
| `_client` | `ObsWebSocket?` | Active connection |
| `_settings` | `ObsSettings` | host, port, password |
| `_connectionState` | `ObsConnectionState` | Current connection state |
| `_reconnectTimer` | `Timer?` | Next retry timer |
| `_retryStartMs` | `int?` | Wall-clock ms of first failure |
| `_retryAttempt` | `int` | Current attempt number (for delay calculation) |
| `_stateController` | `StreamController<ObsConnectionState>` | State broadcast |
| `_enabled` | `bool` | False after `disconnect()` — suppresses reconnection |

**Backoff schedule**: `min(1000 * pow(2, attempt - 1), 30000)` ms. Stops when
`now - _retryStartMs >= 600_000ms`.

**NFR links**: REL-U3.4, TEST-U3.4, SEC-U3.2

---

## RC-06: BrowserSourceServer

**Package**: `zip_broadcast`
**Location**: `packages/zip_broadcast/lib/src/output/browser_source/browser_source_server.dart`
**Pattern**: P3 (SSE Cap + Disconnect), P4 (Token Auth)

**Responsibilities**:
- Serve `GET /` → HTML overlay page with embedded SSE client and token URL
- Serve `GET /captions` → SSE endpoint (5-client cap; `StreamController` per client; DQ3=B)
- Enforce UUID token auth for non-localhost clients (DQ3 auth bypass)
- Track `_latestCaption` for new-client replay
- Expose `pushCaption(text, isFinal)` and `pushSessionState(state)` for `BrowserSourceTarget`

**Key fields**:

| Field | Type | Purpose |
|-------|------|---------|
| `_server` | `HttpServer?` | shelf `IOServer` instance |
| `_clients` | `List<StreamController<List<int>>>` | Active SSE client streams |
| `_activeClientCount` | `int` | Live counter; max 5 |
| `_token` | `String?` | UUID v4; generated at `start()` |
| `_latestCaption` | `String?` | Last SSE payload; replayed to new clients |

**Port validation**: `start()` throws `ArgumentError` if port outside [1024, 65535]. On
`SocketException` at bind, throws `BrowserSourceStartException(reason: portInUse)`.

**NFR links**: PERF-U3.3, SEC-U3.3, REL-U3.2, TEST-U3.5

---

## RC-07: BrowserSourceTarget

**Package**: `zip_broadcast`
**Location**: `packages/zip_broadcast/lib/src/output/browser_source/browser_source_target.dart`

**Responsibilities**:
- Implement `CaptionOutputTarget`; bridge `CaptionBus` events to `BrowserSourceServer`
- Forward `SttResultEvent` → `server.pushCaption(text, isFinal)`
- On `SessionStateEvent(recording)` → `server.pushCaption('', false)` (clear on new session)
- On `SessionStateEvent(stopped)` → `server.pushSessionState('stopped')`

**Key fields**:

| Field | Type | Purpose |
|-------|------|---------|
| `_server` | `BrowserSourceServer` | Injected; shared singleton |

**NFR links**: PERF-U3.3

---

## RC-08: CaptionOverlayTarget

**Package**: `zip_broadcast`
**Location**: `packages/zip_broadcast/lib/src/output/overlay/caption_overlay_target.dart`
**Pattern**: P7 (DesktopWindowService abstraction)

**Responsibilities**:
- Implement `CaptionOutputTarget`; create/manage a desktop platform window for caption overlay
- Delegate all `desktop_multi_window` calls to `DesktopWindowService` (injectable seam)
- Guard `show()` on `_windowService.isSupported`; no-op on mobile/web
- Forward `SttResultEvent` to overlay window via `invokeMethod('captionUpdate', ...)`

**Key fields**:

| Field | Type | Purpose |
|-------|------|---------|
| `_windowId` | `int?` | Platform window handle |
| `_config` | `OverlayConfig?` | Current overlay configuration |
| `_isVisible` | `bool` | Visibility guard |
| `_windowService` | `DesktopWindowService` | Injected (production: `DesktopMultiWindowService`) |

**NFR links**: TEST-U3.2, TEST-U3.1 (excluded from coverage denominator)

---

## RC-09: DesktopWindowService / DesktopMultiWindowService

**Package**: `zip_broadcast`
**Locations**:
- `packages/zip_broadcast/lib/src/output/overlay/desktop_window_service.dart` (abstract)
- `packages/zip_broadcast/lib/src/output/overlay/desktop_multi_window_service.dart` (impl)
**Pattern**: P7

**Interface**:
```dart
abstract class DesktopWindowService {
  Future<int> createWindow(String arguments);
  Future<void> closeWindow(int windowId);
  Future<void> invokeMethod(int windowId, String method, dynamic arguments);
  bool get isSupported;
}
```

**NFR links**: TEST-U3.2

---

## Test Infrastructure

### TI-01: MockTranscriptRepository

**Location**: `packages/zip_core/test/helpers/mock_transcript_repository.dart`
**Tool**: mocktail

Used by `TranscriptWriterTarget` and `OnScreenCaptionTarget` tests to isolate from database
behaviour. Provides a `Stream<RepositoryEvent>` controller for corruption event testing.

```dart
class MockTranscriptRepository extends Mock implements TranscriptRepository {}
```

**Consumed by**: `transcript_writer_target_test.dart`, `on_screen_caption_target_test.dart`

---

### TI-02: MockDesktopWindowService

**Location**: `packages/zip_broadcast/test/helpers/mock_desktop_window_service.dart`
**Tool**: mocktail

Used by `CaptionOverlayTarget` tests.

```dart
class MockDesktopWindowService extends Mock implements DesktopWindowService {}
```

**Consumed by**: `caption_overlay_target_test.dart`

---

### TI-03: drift In-Memory Database Helper

**Location**: `packages/zip_core/test/helpers/db_helpers.dart`

Provides a `buildTestDatabase()` helper that creates a `TranscriptDatabase` backed by
`NativeDatabase.memory()`. FTS5 virtual table and triggers are created via the normal `onCreate`
path.

```dart
Future<TranscriptDatabase> buildTestDatabase() async {
  final db = TranscriptDatabase(NativeDatabase.memory());
  // onCreate fires automatically on first open
  return db;
}
```

**Consumed by**: `transcript_repository_test.dart`, FTS5 and export tests.

---

### TI-04: fake_async Wrapper

**Package**: `fake_async` (dev_dependency in `zip_core` and `zip_broadcast`)

Used directly in test bodies via `fakeAsync(...)`. No wrapper file needed — imported from the
`fake_async` package directly.

**Consumed by**:
- `transcript_writer_target_test.dart` (2s merge window boundary)
- `obs_websocket_target_test.dart` (backoff schedule + 10-minute timeout)
- `on_screen_caption_target_test.dart` (50ms debounce timer)

---

### TI-05: PBT Generator Extensions

**Locations**:
- `packages/zip_core/test/helpers/generators.dart` (extend existing file)
- `packages/zip_broadcast/test/helpers/generators.dart` (new file)

New generators to add:

| Generator | Type | Package |
|-----------|------|---------|
| `arbitraryTranscriptSession` | `Arbitrary<TranscriptSession>` | zip_core |
| `arbitraryTranscriptSegment` | `Arbitrary<TranscriptSegment>` | zip_core |
| `arbitraryTranscriptSearchResult` | `Arbitrary<TranscriptSearchResult>` | zip_core |
| `arbitraryObsConnectionState` | `Arbitrary<ObsConnectionState>` | zip_broadcast |
| `arbitraryOutputTargetSettings` | `Arbitrary<OutputTargetSettings>` | zip_broadcast |

**Consumed by**: PBT tests for merge logic, export round-trip, and buffer invariant.

---

### TI-06: BrowserSourceServer Test Seam

**Location**: Inline in `browser_source_server.dart` via `@visibleForTesting` constructor
parameter.

Provides an injectable `isLocalhost` function to simulate remote addresses in tests that run on
localhost:

```dart
BrowserSourceServer({
  @visibleForTesting bool Function(Request)? isLocalhost,
}) : _isLocalhost = isLocalhost ?? _defaultIsLocalhost;
```

**Consumed by**: `browser_source_server_test.dart` — token auth tests.

---

## Test File Map

| Test file | TI-01 MockRepo | TI-02 MockWindow | TI-03 drift | TI-04 fake_async | TI-05 PBT | TI-06 Seam |
|-----------|:--------------:|:----------------:|:-----------:|:----------------:|:---------:|:----------:|
| `on_screen_caption_target_test.dart` | ✓ | | | ✓ | ✓ | |
| `transcript_writer_target_test.dart` | ✓ | | | ✓ | ✓ | |
| `transcript_repository_test.dart` | | | ✓ | | ✓ | |
| `caption_overlay_target_test.dart` | | ✓ | | | | |
| `obs_websocket_target_test.dart` | | | | ✓ | | |
| `browser_source_server_test.dart` | | | | | | ✓ |
| `browser_source_target_test.dart` | | | | | | |

---

## Directory Structure

```
packages/zip_core/
  lib/src/
    database/
      transcript_database.dart        # RC-03: drift DB, FTS5, corruption recovery
    output/
      on_screen_caption_target.dart   # RC-01: debounced stream + buffer
      transcript_repository.dart      # RC-04: FTS5 search, export, events
      transcript_writer_target.dart   # RC-02: immediate segment persistence
  test/
    helpers/
      db_helpers.dart                 # TI-03: in-memory drift helper
      generators.dart                 # TI-05: extend with new Unit 3 generators
      mock_transcript_repository.dart # TI-01
    output/
      on_screen_caption_target_test.dart
      transcript_repository_test.dart
      transcript_writer_target_test.dart

packages/zip_broadcast/
  lib/src/
    output/
      obs/
        obs_websocket_target.dart     # RC-05
      browser_source/
        browser_source_server.dart    # RC-06: shelf SSE, token auth, cap
        browser_source_target.dart    # RC-07: bridge to server
      overlay/
        caption_overlay_target.dart   # RC-08
        desktop_window_service.dart   # RC-09 (abstract)
        desktop_multi_window_service.dart  # RC-09 (impl)
  test/
    helpers/
      generators.dart                 # TI-05: zip_broadcast domain generators
      mock_desktop_window_service.dart # TI-02
    output/
      browser_source_server_test.dart
      browser_source_target_test.dart
      caption_overlay_target_test.dart
      obs_websocket_target_test.dart
```

---

## Provider Dependency Map

```
SharedPreferencesProvider (existing)
    ├──> transcriptSettingsProvider    (zip_core)
    ├──> obsSettingsProvider           (zip_broadcast, host + port)
    └──> outputTargetSettingsProvider  (zip_broadcast)

FlutterSecureStorage (instantiated inline)
    └──> obsSettingsProvider           (password field)

transcriptRepositoryProvider
    ├──> TranscriptWriterTarget        (injected at construction)
    └──> OnScreenCaptionTarget         (injected, nullable — null when capture disabled)

CaptionBusProvider (existing, Unit 1)
    ├──> OnScreenCaptionTarget         (subscribes via CaptionOutputTargetRegistry)
    ├──> TranscriptWriterTarget        (subscribes)
    ├──> ObsWebSocketTarget            (subscribes)
    ├──> BrowserSourceTarget           (subscribes)
    └──> CaptionOverlayTarget          (subscribes)

outputTargetSettingsProvider
    ├──> BrowserSourceServer           (reads port; provides enable/disable signal)
    └──> CaptionOutputTargetRegistry   (enables/disables targets based on toggles)
```
