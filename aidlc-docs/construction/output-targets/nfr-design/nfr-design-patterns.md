# NFR Design Patterns — Unit 3: Output Targets

## Design Question Answers

| Question | Answer | Summary |
|----------|--------|---------|
| NFR-DQ1 | A | Timer at the `StreamController.add()` call site; state updated synchronously, trailing emission only |
| NFR-DQ2 | C | Skip unit testing the PRAGMA + file-rename path; test only downstream notification/state effects |
| NFR-DQ3 | B | `StreamController<List<int>>` per client; catch `SocketException` on write errors to detect disconnect |

---

## Pattern 1: Timer-Based Debounce — OnScreenCaptionTarget (PERF-U3.1)

### Problem

`OnScreenCaptionTarget.onCaptionEvent()` is called on every STT result, which can arrive multiple
times per second during active speech. Without coalescing, `_controller.add()` would fire on every
call, causing excessive widget rebuilds.

### Pattern

Internal state (`_buffer`, `_currentInterim`) is updated **synchronously** on every
`onCaptionEvent()` call. A debounce `Timer` wraps the `_controller.add()` call only: on each
invocation, cancel any pending timer and start a new `Timer(Duration(milliseconds: 50), ...)`. When
the timer fires, it snapshots current visible captions and emits them. Only the trailing state is
emitted; no intermediate state is dropped permanently.

### Implementation Sketch

```dart
class OnScreenCaptionTarget implements CaptionOutputTarget {
  Timer? _debounceTimer;
  final _controller = StreamController<List<CaptionDisplayEntry>>.broadcast();

  void _scheduleEmit() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      _controller.add(visibleCaptions);
    });
  }

  @override
  void onCaptionEvent(CaptionEvent event) {
    switch (event) {
      case SttResultEvent():
        if (event.result.isFinal) {
          _buffer.add(_makeEntry(event.result));
          _currentInterim = null;
          if (_buffer.length > _maxBufferSegments) _buffer.removeAt(0);
        } else {
          _currentInterim = _makeInterimEntry(event.result);
        }
        _scheduleEmit();
      case SessionStateEvent():
        // ... session lifecycle handling
        _scheduleEmit();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.close();
  }
}
```

### Verification

- Publish 10 `SttResultEvent`s within 10ms; assert `onVisibleCaptionsChanged` emits exactly 1–2
  times (not 10). Use `fake_async` to advance time past the 50ms window.
- Publish two events 60ms apart; assert exactly 2 emissions occur.
- Assert `visibleCaptions` returns the latest state even before the timer fires.

### Design Notes

- `_debounceTimer` must be cancelled in `dispose()` to prevent a post-dispose emission.
- No `rxdart` dependency; pure Dart `dart:async` only.
- The `visibleCaptions` getter always returns current state, so callers reading the getter directly
  (not the stream) are never stale.

---

## Pattern 2: FTS5 Query via drift — TranscriptRepository.search (PERF-U3.2)

### Problem

Full-text search across up to 100,000 segments must complete within 500ms. The drift query must
invoke FTS5 `MATCH` and aggregate results by session with BM25 ranking and snippet extraction.

### Pattern

Use drift's `customSelect` to issue the raw FTS5 query, then post-process results in Dart to group
by session and collect snippets. The FTS5 virtual table (`transcript_fts`) is kept in sync with
`transcript_segments` via INSERT/DELETE triggers set up in `onCreate`.

### FTS5 Query

```dart
Future<List<TranscriptSearchResult>> search(String query) async {
  final rows = await _db.customSelect(
    '''
    SELECT
      ts.session_id,
      snippet(transcript_fts, 0, '[', ']', '...', 64) AS snippet,
      bm25(transcript_fts) AS score
    FROM transcript_fts
    JOIN transcript_segments seg ON seg.segment_id = transcript_fts.segment_id
    JOIN transcript_sessions ts ON ts.session_id = seg.session_id
    WHERE transcript_fts MATCH ?
    ORDER BY score ASC
    LIMIT 50
    ''',
    variables: [Variable.withString(query)],
    readsFrom: {_db.transcriptSessions, _db.transcriptSegments},
  ).get();

  // Group by session_id — collect up to 3 snippets per session
  final grouped = <String, ({double bestScore, List<String> snippets})>{};
  for (final row in rows) {
    final sessionId = row.read<String>('session_id');
    final snippet = row.read<String>('snippet');
    final score = row.read<double>('score');
    final entry = grouped[sessionId];
    if (entry == null) {
      grouped[sessionId] = (bestScore: score, snippets: [snippet]);
    } else if (entry.snippets.length < 3) {
      grouped[sessionId] = (bestScore: entry.bestScore, snippets: [...entry.snippets, snippet]);
    }
  }

  // Fetch session metadata and build results
  final results = <TranscriptSearchResult>[];
  for (final MapEntry(:key, :value) in grouped.entries) {
    final session = await getSession(key);
    if (session != null) {
      results.add(TranscriptSearchResult(
        session: session,
        snippets: value.snippets,
        relevanceScore: value.bestScore,
      ));
    }
  }
  return results;
}
```

### FTS5 Schema Setup (in TranscriptDatabase.onCreate)

```dart
await customStatement('''
  CREATE VIRTUAL TABLE transcript_fts USING fts5(
    text,
    segment_id UNINDEXED,
    session_id UNINDEXED,
    content=transcript_segments,
    content_rowid=rowid,
    tokenize='porter unicode61'
  )
''');
await customStatement('''
  CREATE TRIGGER fts_insert AFTER INSERT ON transcript_segments BEGIN
    INSERT INTO transcript_fts(rowid, text, segment_id, session_id)
    VALUES (NEW.rowid, NEW.text, NEW.segment_id, NEW.session_id);
  END
''');
await customStatement('''
  CREATE TRIGGER fts_delete AFTER DELETE ON transcript_segments BEGIN
    INSERT INTO transcript_fts(transcript_fts, rowid, text, segment_id, session_id)
    VALUES ('delete', OLD.rowid, OLD.text, OLD.segment_id, OLD.session_id);
  END
''');
```

### Verification

- Seed an in-memory drift database with 1,000 sessions × 100 segments; run a representative search
  query; assert result returns within 500ms. This is a logged warning threshold, not a CI gate.
- Assert snippets contain `[`/`]` delimiters around matched terms.
- Assert results are ordered by ascending BM25 score (most relevant first).
- Assert at most 3 snippets are returned per session.

---

## Pattern 3: SSE Client Cap + Disconnect Detection — BrowserSourceServer (PERF-U3.3)

### Problem

`BrowserSourceServer` must cap simultaneous SSE clients at 5 and free a slot when a client
disconnects (browser closed, OBS tab changed). In `shelf`, the response body is a
`Stream<List<int>>` with no explicit disconnect callback.

### Pattern (NFR-DQ3 = B)

Each connected client gets its own `StreamController<List<int>>`. The shelf SSE response streams
from `controller.stream`. Write errors (`SocketException`, broken pipe) are caught via the sink's
`onError` handler; `onDone` catches clean disconnects. Both paths close the controller and
decrement the active client counter.

### Implementation Sketch

```dart
class BrowserSourceServer {
  static const _maxClients = 5;
  final _clients = <StreamController<List<int>>>[];
  int _activeClientCount = 0;
  String? _token;

  Handler get _sseHandler => (Request request) async {
    if (_activeClientCount >= _maxClients) {
      return Response(
        503,
        body: '{"error":"max_clients_exceeded"}',
        headers: {'content-type': 'application/json'},
      );
    }

    final controller = StreamController<List<int>>();
    _clients.add(controller);
    _activeClientCount++;

    // Send latest caption immediately on connect
    if (_latestCaption != null) {
      _sendToController(controller, _latestCaption!);
    }

    controller.sink.done.then((_) {
      _removeClient(controller);
    });

    return Response.ok(
      controller.stream,
      headers: {
        'content-type': 'text/event-stream',
        'cache-control': 'no-cache',
        'connection': 'keep-alive',
      },
    );
  };

  void _sendToController(StreamController<List<int>> controller, String sseData) {
    try {
      if (!controller.isClosed) {
        controller.sink.add(utf8.encode(sseData));
      }
    } on SocketException catch (_) {
      _removeClient(controller);
    }
  }

  void _removeClient(StreamController<List<int>> controller) {
    if (_clients.remove(controller)) {
      _activeClientCount--;
      if (!controller.isClosed) controller.close();
    }
  }

  void pushCaption(String text, bool isFinal) {
    final payload = 'data: ${jsonEncode({'type': 'sttResult', 'text': text, 'isFinal': isFinal})}\n\n';
    _latestCaption = payload;
    for (final client in List.of(_clients)) {
      _sendToController(client, payload);
    }
  }
}
```

### Verification

- Test: 5th SSE connection is accepted (200); 6th returns 503 with `max_clients_exceeded`.
- Test: after client disconnect, `_activeClientCount` decrements and a new connection is accepted.
- Test: `pushCaption()` broadcasts to all connected clients.
- Test: new client receives `_latestCaption` immediately on connect.

---

## Pattern 4: UUID Token Auth + Localhost Bypass — BrowserSourceServer (SEC-U3.3)

### Problem

`BrowserSourceServer` binds to `0.0.0.0` and is reachable beyond localhost. The SSE endpoint must
be protected against unauthorized remote access while remaining frictionless for OBS on the same
machine.

### Pattern

Generate a UUID v4 token at `start()` via `Uuid().v4()`. For `GET /captions` requests:

1. Inspect `request.context['shelf.io.connection_info']` to get the remote address.
2. If the remote address is `127.0.0.1` or `::1`: bypass token validation.
3. Otherwise: require `?token={uuid}` matching the generated token; respond `401` on mismatch.

The HTML page served by `GET /` embeds the token in the JavaScript SSE client URL
(`/captions?token={uuid}`), so OBS browser sources on a remote machine work without manual URL
construction.

### Implementation Sketch

```dart
Future<void> start({int? port}) async {
  _token = const Uuid().v4();
  // ... bind server
}

bool _isLocalhost(Request request) {
  final info = request.context['shelf.io.connection_info'];
  if (info is HttpConnectionInfo) {
    final addr = info.remoteAddress.address;
    return addr == '127.0.0.1' || addr == '::1';
  }
  return false;
}

Handler get _sseHandler => (Request request) async {
  if (!_isLocalhost(request)) {
    final token = request.url.queryParameters['token'];
    if (token != _token) {
      return Response(401, body: '{"error":"unauthorized"}',
          headers: {'content-type': 'application/json'});
    }
  }
  // ... proceed to SSE stream
};
```

### Token Lifecycle

- Generated fresh on each `start()` call.
- `stop()` + `start()` produces a new token; the old token is no longer valid.
- The token is stable for the lifetime of a running server instance.

### Verification

- Remote request to `/captions` without token → 401.
- Remote request to `/captions` with wrong token → 401.
- Remote request to `/captions` with correct token → 200 `text/event-stream`.
- Localhost (127.0.0.1) request to `/captions` without token → 200 `text/event-stream`.

---

## Pattern 5: Database Corruption Recovery — PRAGMA → rename → fresh DB (REL-U3.1, NFR-DQ2 = C)

### Problem

If `transcripts.db` fails `PRAGMA integrity_check` at startup, the app must: rename the corrupt
file, open a fresh database, and notify the UI — without silent data loss.

### Pattern (NFR-DQ2 = C)

Unit tests do **not** test the PRAGMA + file-rename path directly. Instead:

- The PRAGMA + rename path is treated as an acceptance test (exercised manually or via integration
  test with a real file-backed DB and a pre-corrupted fixture).
- Unit tests cover only the **downstream effects**: given that `TranscriptRepository` emits a
  `RepositoryEvent.corruption` event, assert the UI receives the notification and the repository
  returns an empty fresh state.

No `DatabaseHealthChecker` abstraction is introduced.

### Production Implementation in TranscriptDatabase.open()

```dart
static Future<TranscriptDatabase> open(String dbPath) async {
  // First, run integrity check on the existing file
  final file = File(dbPath);
  if (await file.exists()) {
    final checkDb = sqlite3.open(dbPath);
    try {
      final result = checkDb.select('PRAGMA integrity_check');
      final ok = result.first.values.first == 'ok';
      if (!ok) {
        checkDb.dispose();
        final corruptPath = '$dbPath.corrupt';
        await file.rename(corruptPath);
        // Fresh DB will be created below; caller emits corruption event
        return TranscriptDatabase._openFresh(dbPath, corruptPath: corruptPath);
      }
    } finally {
      checkDb.dispose();
    }
  }
  return TranscriptDatabase._openFresh(dbPath);
}
```

### RepositoryEvent

```dart
@freezed
class RepositoryEvent with _$RepositoryEvent {
  const factory RepositoryEvent.corruption({required String corruptFilePath}) = CorruptionEvent;
}
```

`TranscriptRepository` exposes `Stream<RepositoryEvent> get events`.

### Unit Test Scope (what IS tested)

```dart
// Given a pre-emitted corruption event on the repository stream,
// assert the UI state notifier transitions to an error state that
// surfaces the corrupt file path in the notification message.
test('corruption event surfaces in UI state', () async {
  final container = ProviderContainer(overrides: [
    transcriptRepositoryProvider.overrideWith((_) => fakeRepository),
  ]);
  fakeRepository.emitCorruption('/path/transcripts.db.corrupt');
  // ... assert UI state update
});
```

### Acceptance Test Scope (not in unit suite)

A separate integration test (tagged `@Tags(['integration'])`, `--platform vm` only) opens
`TranscriptDatabase` with a pre-written corrupt SQLite file (all-zero bytes), asserts the corrupt
file is renamed, a fresh database is created, and a `RepositoryEvent.corruption` is emitted.

---

## Pattern 6: Immediate Segment Persistence via Merge Window (REL-U3.3)

### Problem

The FD specified a 30-second periodic flush. REL-U3.3 supersedes this: each finalized
`TranscriptSegment` must be persisted immediately after it exits the 2-second merge window. The
periodic timer is removed.

### Pattern

`TranscriptWriterTarget` removes `_pendingSegments` and the `_flushTimer`. Each call path that
previously added to `_pendingSegments` now calls `repository.saveSegment()` (or an upsert variant)
directly.

### Revised Segment Accumulation Logic

```dart
void _handleFinalResult(SttResultEvent event) {
  if (!_settings.captureEnabled) return;

  final sourceId = event.result.sourceId;
  final prior = _lastFinalBySource[sourceId];
  final now = DateTime.now().millisecondsSinceEpoch;

  if (prior != null && (now - (prior.startMs + prior.durationMs)) <= 2000) {
    // Within merge window: update in-place
    final merged = prior.copyWith(
      text: '${prior.text} ${event.result.text}',
      endTimeMs: now - _sessionStartMs!,
    );
    _lastFinalBySource[sourceId] = merged;
    // Upsert: overwrites the previously-persisted row for this segmentId
    _repository.saveSegment(_sessionId!, merged);
  } else {
    // New segment (gap > 2s or no prior)
    final segment = _makeSegment(event.result, now);
    _lastFinalBySource[sourceId] = segment;
    _repository.saveSegment(_sessionId!, segment);
  }
}
```

**At-risk window**: the in-progress merge window (up to 2s) for the most recent segment per source.
Any segment that has already exceeded the 2s gap and been committed is fully durable.

### Session Stop Flush

```dart
void _handleSessionStopped() {
  // No pending segments to flush — all are already persisted.
  // Final responsibility: update session metadata.
  _repository.finalizeSession(
    _sessionId!,
    durationMs: DateTime.now().millisecondsSinceEpoch - _sessionStartMs!,
    segmentCount: _totalSegmentCount,
  );
  _lastFinalBySource.clear();
  _sessionId = null;
  _sessionStartMs = null;
  _totalSegmentCount = 0;
}
```

### Verification

- Test: a final result triggers an immediate `repository.saveSegment()` call (mock assertion).
- Test: a second final result within 2s from the same source calls `saveSegment()` again with the
  merged text (upsert behaviour).
- Test: session stop calls `finalizeSession()` with correct duration and count.
- Use `fake_async` to verify the 2s merge window boundary precisely.

---

## Pattern 7: DesktopWindowService Abstraction + MockDesktopWindowService (TEST-U3.2)

### Problem

`CaptionOverlayTarget` calls `desktop_multi_window` platform channel APIs that require a native
host runner and cannot be exercised in unit tests.

### Pattern

Introduce a `DesktopWindowService` abstract class. `CaptionOverlayTarget` depends on this
interface, not on `desktop_multi_window` directly. Tests inject `MockDesktopWindowService`
(mocktail).

### Interface

```dart
abstract class DesktopWindowService {
  Future<int> createWindow(String arguments);
  Future<void> closeWindow(int windowId);
  Future<void> invokeMethod(int windowId, String method, dynamic arguments);
  bool get isSupported;
}
```

### Production Implementation

```dart
class DesktopMultiWindowService implements DesktopWindowService {
  @override
  Future<int> createWindow(String arguments) =>
      DesktopMultiWindow.createWindow(arguments);

  @override
  Future<void> closeWindow(int windowId) =>
      DesktopMultiWindow.closeWindow(windowId);

  @override
  Future<void> invokeMethod(int windowId, String method, dynamic arguments) =>
      DesktopMultiWindow.invokeMethod(windowId, method, arguments);

  @override
  bool get isSupported => Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}
```

### Tested Scenarios (with MockDesktopWindowService)

| Scenario | Assertion |
|----------|-----------|
| `show()` on fresh target | `createWindow()` called once; `_isVisible = true` |
| `show()` when already visible | No second `createWindow()`; `invokeMethod` called to update config |
| `hide()` | `closeWindow()` called; `_isVisible = false` |
| `dispose()` when visible | `closeWindow()` called |
| `onCaptionEvent()` when not visible | `invokeMethod` not called |
| `onCaptionEvent()` when visible | `invokeMethod('captionUpdate', ...)` called |
| Mobile/web guard (`isSupported == false`) | `show()` is a no-op; `isVisible` stays `false` |

---

## Pattern 8: fake_async Timer Tests — merge window + OBS backoff (TEST-U3.4)

### Problem

`TranscriptWriterTarget`'s 2-second merge window and `ObsWebSocketTarget`'s exponential backoff
schedule involve `Timer`-based delays that must be tested without real waits.

### Pattern

Wrap timer-dependent tests in `fakeAsync(...)`. Use `FakeAsync.elapse()` to advance time.
All `Timer` calls inside the system under test fire deterministically.

### Merge Window Tests

```dart
test('segments more than 2s apart are not merged', () {
  fakeAsync((fake) {
    final repository = MockTranscriptRepository();
    final target = TranscriptWriterTarget(repository: repository, settings: enabledSettings);
    target.onCaptionEvent(SessionStateEvent.recording(sessionId: 'sid'));

    target.onCaptionEvent(SttResultEvent(result: finalResult('Hello', sourceId: 'mic')));
    fake.elapse(const Duration(milliseconds: 2001));
    target.onCaptionEvent(SttResultEvent(result: finalResult('World', sourceId: 'mic')));

    // Two separate saveSegment() calls, not one merged call
    verify(() => repository.saveSegment('sid', any())).called(2);
  });
});
```

### OBS Backoff Tests

```dart
test('backoff schedule matches expected delays', () {
  fakeAsync((fake) {
    final target = ObsWebSocketTarget(connector: mockConnector);
    target.connect(testSettings);

    // Attempt 1 fails immediately
    mockConnector.simulateFailure();

    fake.elapse(const Duration(seconds: 1)); // 1s delay
    mockConnector.simulateFailure(); // attempt 2

    fake.elapse(const Duration(seconds: 2)); // 2s delay
    // ... continue through full schedule

    // After 10 minutes total elapsed, assert ObsError emitted
    fake.elapse(const Duration(minutes: 10));
    expect(target.connectionState, isA<ObsErrorState>());
  });
});
```

### Design Notes

- `fake_async` must be in `dev_dependencies` for both `zip_core` and `zip_broadcast`.
- All `Timer` and `Future.delayed` calls inside the SUT respect `fakeAsync`'s clock automatically.
- The 10-minute timeout test must track elapsed time from the first failure, not from `connect()`.

---

## Pattern 9: BrowserSourceServer Test Pattern — shelf test client (TEST-U3.5)

### Problem

`BrowserSourceServer` must be tested for HTTP routing, SSE streaming, token auth, and client cap
without depending on a live OS socket or a real browser.

### Pattern

Bind the server to port 0 (OS-assigned ephemeral port) in `setUp`, obtain the assigned port from
`server.port`, and construct test HTTP requests using Dart's `http` package or `shelf_io`'s test
utilities. For SSE streaming tests, use `dart:io`'s `HttpClient` to consume the stream.

### Test Setup

```dart
late BrowserSourceServer server;
late Uri baseUri;

setUp(() async {
  server = BrowserSourceServer();
  await server.start(port: 0); // OS-assigned port
  baseUri = Uri.parse('http://127.0.0.1:${server.port}');
});

tearDown(() async {
  await server.stop();
});
```

### Token Auth Tests

```dart
test('remote request without token returns 401', () async {
  // Shelf test: simulate a non-localhost remote address by
  // inspecting request context; use mockable connection info
  final response = await http.get(baseUri.resolve('/captions'));
  // localhost bypasses token — use a subclass/override to simulate remote addr
  expect(response.statusCode, 401);
});
```

**Note**: Because tests run on localhost, simulating a remote address requires overriding
`_isLocalhost()` to return `false` in a test subclass, or injecting an `AddressResolver` seam.
The preferred approach is a `@visibleForTesting` constructor that accepts a `localAddressChecker`
function:

```dart
BrowserSourceServer({
  @visibleForTesting bool Function(Request)? isLocalhost,
}) : _isLocalhost = isLocalhost ?? _defaultIsLocalhost;
```

### SSE Streaming Test

```dart
test('pushCaption broadcasts to connected client', () async {
  final client = HttpClient();
  final request = await client.getUrl(baseUri.resolve('/captions'));
  final response = await request.close();

  server.pushCaption('Hello', true);

  final lines = response
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  final first = await lines.first;
  expect(first, contains('"text":"Hello"'));

  client.close(force: true);
});
```

---

## Pattern 10: PBT Generators — New Domain Types (general)

### Problem

Property-based tests for `TranscriptWriterTarget` merge logic, `TranscriptRepository` export
round-trip, and `OnScreenCaptionTarget` buffer invariant need generators for new Unit 3 domain
types.

### Generator Hierarchy

```
Arbitrary<ObsConnectionState>      — oneOf enum/sealed variants
Arbitrary<TranscriptSession>       — composed: arbitrary sessionId (UUID-shaped string),
                                     arbitrary DateTime, optional title
Arbitrary<TranscriptSegment>       — composed: segmentId, sessionId, non-empty text,
                                     sourceId, constrained startTimeMs/endTimeMs (start < end)
Arbitrary<OutputTargetSettings>    — composed: bool toggles, port in [1024, 65535]
Arbitrary<TranscriptSearchResult>  — composed: arbitrary session + 1–3 non-empty snippet strings
```

### Key Testable Properties

| Component | Property | PBT Category |
|-----------|----------|--------------|
| `TranscriptWriterTarget` merge logic | Given any sequence of final `SttResultEvent`s, merged segment text equals space-joined input texts; `startTimeMs` is always from the first result; `endTimeMs` from the last | PBT-03 Invariant |
| `TranscriptRepository` export | Round-trip invariant: `exportSession(SRT)` segments parse back to the same timestamps | PBT-02 Round-trip |
| `OnScreenCaptionTarget` buffer | Buffer length never exceeds `_maxBufferSegments` after any sequence of events | PBT-03 Invariant |

### Generator Location

```
packages/zip_core/test/helpers/generators.dart       (existing file — add new generators)
packages/zip_broadcast/test/helpers/generators.dart  (new file — zip_broadcast domain types)
```

---

## Pattern 11: Logging Pattern Extension — zip_broadcast Logger Names (SEC-U3.1/2, MAINT-U3.2)

### Problem

All Unit 3 components must log operational events without ever logging transcript text, session
titles, or OBS passwords. The naming convention from Units 1/2 must be extended to `zip_broadcast`.

### Logger Naming Convention

| Package | Pattern | Example |
|---------|---------|---------|
| `zip_core` | `'zip_core.{ClassName}'` | `'zip_core.TranscriptRepository'` |
| `zip_broadcast` | `'zip_broadcast.{ClassName}'` | `'zip_broadcast.ObsWebSocketTarget'` |

### Permitted vs. Prohibited Log Content

**Permitted**:
- `sessionId`, `segmentId`, `entryId`, `sourceId`, `targetId`
- Byte counts, event types, connection state names
- Port numbers, error types, stack traces
- OBS `host`, `port` (but never `password`)

**Prohibited** (SEC-U3.1, SEC-U3.2):
- `SttResult.text`, `TranscriptSegment.text`, `CaptionDisplayEntry.text`
- `TranscriptSession.title`
- SSE payload `text` fields
- `ObsSettings` as a whole object (generated `toString()` includes password)

### Compliant Logging Examples

```dart
// zip_core.TranscriptRepository
final _log = Logger('zip_core.TranscriptRepository');

_log.fine('saveSegment: sessionId=$sessionId segmentId=${segment.segmentId}');
// NOT: _log.fine('text=${segment.text}');

// zip_broadcast.ObsWebSocketTarget
final _log = Logger('zip_broadcast.ObsWebSocketTarget');

_log.info('connecting to ${_settings.host}:${_settings.port}');
// NOT: _log.info('settings=$_settings'); // would include password via toString()

_log.warning('connection failed (attempt $_retryAttempt); retrying in ${delayMs}ms');
```

### Verification

Code review of all `log()` / `_log.*()` call sites in Unit 3 components is a mandatory item in
Code Generation. No automated test can comprehensively enforce this constraint — it is a reviewer
checklist item.
