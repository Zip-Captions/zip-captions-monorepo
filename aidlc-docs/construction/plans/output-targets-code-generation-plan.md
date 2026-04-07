# Code Generation Plan — Unit 3: Output Targets

**Unit**: Unit 3: Output Targets  
**Stories**: S-04, S-05, S-07, S-08  
**Branch**: `feature/output-targets`  
**Packages**: `zip_core`, `zip_broadcast`

## Reference Artifacts

Before executing any step, read:
- `aidlc-docs/construction/output-targets/nfr-design/logical-components.md` — file paths, field definitions, RC-01 through RC-09, TI-01 through TI-06
- `aidlc-docs/construction/output-targets/nfr-design/nfr-design-patterns.md` — implementation sketches for P1–P11
- `aidlc-docs/construction/output-targets/functional-design/domain-entities.md` — all model/entity definitions (freezed classes, sealed classes, enums)
- `aidlc-docs/construction/output-targets/functional-design/business-rules.md` — business rules referenced in implementation logic

## NFR Decisions (locked)

| DQ | Answer | Impact |
|----|--------|--------|
| DQ1 | A | 50ms Timer debounce at `_controller.add()` call site in `OnScreenCaptionTarget` |
| DQ2 | C | No unit test for PRAGMA+rename path; unit tests cover downstream events only |
| DQ3 | B | `StreamController<List<int>>` per SSE client; disconnect via `sink.done` + `SocketException` |

## Extension Rules (enforced)

- **Security Baseline**: No transcript text, session titles, or OBS passwords in logs. See Pattern 11.
- **Property-Based Testing**: Add PBT generators per TI-05; write PBT tests where specified.

---

## Step 1: Update zip_core pubspec.yaml

- [ ] Add to `dependencies`:
  - `drift: ^2.20.0`
  - `drift_flutter: ^0.2.3`
  - `sqlite3_flutter_libs: ^0.5.0`
- [ ] Add to `dev_dependencies`:
  - `drift_dev: ^2.20.0`
  - `fake_async: ^1.3.2`
- [ ] Note: `uuid`, `logging`, `path_provider`, `shared_preferences`, `freezed_annotation`, `riverpod_annotation` already present — do not duplicate.

---

## Step 2: Update zip_broadcast pubspec.yaml

- [ ] Add to `dependencies`:
  - `obs_websocket: ^5.0.0`
  - `shelf: ^1.4.2`
  - `shelf_router: ^1.1.4`
  - `flutter_secure_storage: ^9.2.2`
  - `desktop_multi_window: ^0.2.0`
  - `uuid: ^4.5.1`
  - `logging: ^1.3.0`
  - `freezed_annotation: ^2.4.4`
  - `json_annotation: ^4.9.0`
- [ ] Add to `dev_dependencies`:
  - `fake_async: ^1.3.2`
  - `mocktail: ^1.0.4`
  - `glados: ^1.1.7`
  - `http: ^1.2.2`
  - `build_runner: ^2.4.15`
  - `freezed: ^2.5.8`
  - `json_serializable: ^6.9.4`
  - `riverpod_generator: ^2.6.3`
- [ ] Run `flutter pub get` from workspace root after both pubspecs updated.

---

## Step 3: Generate domain models (zip_core)

- [ ] Create freezed models that do not yet exist in `packages/zip_core/lib/src/models/`:
  - `CaptionDisplayEntry` — from domain-entities.md §CaptionDisplayEntry
  - `TranscriptSession` — from domain-entities.md §TranscriptSession (freezed + JSON)
  - `TranscriptSegment` — from domain-entities.md §TranscriptSegment (freezed + JSON)
  - `TranscriptSettings` — from domain-entities.md §TranscriptSettings (freezed)
  - `TranscriptSearchResult` — from domain-entities.md §TranscriptSearchResult (freezed)
  - `ExportFormat` — from domain-entities.md §ExportFormat (enum)
  - `RepositoryEvent` — from nfr-design-patterns.md §Pattern 5 (freezed sealed)
- [ ] Check each file path before creating — modify in place if the file already exists.
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` from `packages/zip_core/`.

---

## Step 4: Generate domain models (zip_broadcast)

- [ ] Create freezed/sealed models that do not yet exist in `packages/zip_broadcast/lib/src/models/`:
  - `ObsSettings` — from domain-entities.md §ObsSettings (freezed)
  - `ObsConnectionState` (sealed) — from domain-entities.md §ObsConnectionState
  - `OutputTargetSettings` — from domain-entities.md §OutputTargetSettings (freezed)
  - `OverlayConfig` — from domain-entities.md §OverlayConfig (freezed, if defined there)
  - `OverlayPosition` (sealed) — from domain-entities.md §OverlayPosition (if defined there)
  - `BrowserSourceStartException` — simple exception class with `reason` field and a `portInUse` const factory
- [ ] Check each file before creating — modify in place if exists.
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` from `packages/zip_broadcast/`.

---

## Step 5: Create TranscriptDatabase (RC-03)

**File**: `packages/zip_core/lib/src/database/transcript_database.dart`

- [ ] Define drift `@DataClassName` table classes:
  - `TranscriptSessions` table: `sessionId` (TEXT PK), `date` (INTEGER epoch ms), `title` (TEXT nullable), `durationMs` (INTEGER), `segmentCount` (INTEGER)
  - `TranscriptSegments` table: `segmentId` (TEXT PK), `sessionId` (TEXT, FK → sessions), `text` (TEXT), `sourceId` (TEXT), `startTimeMs` (INTEGER), `endTimeMs` (INTEGER)
- [ ] Implement `TranscriptDatabase extends $Database` with `schemaVersion: 1`
- [ ] In `onCreate`: create FTS5 virtual table `transcript_fts` and INSERT/DELETE sync triggers — use exact SQL from nfr-design-patterns.md §Pattern 2 (FTS5 Schema Setup)
- [ ] Implement static `open(String dbPath)` factory with PRAGMA integrity_check + rename path — use exact logic from nfr-design-patterns.md §Pattern 5 (Production Implementation)
  - On corruption: rename to `$dbPath.corrupt`, return `_openFresh(dbPath, corruptPath: corruptPath)`
  - `_openFresh` opens a new drift database at the path
- [ ] Scaffold `onUpgrade` switch statement (no migrations yet; `schemaVersion: 1`)
- [ ] Part of the `dart:io` path; do NOT import flutter plugins here.

---

## Step 6: Create TranscriptRepository (RC-04)

**File**: `packages/zip_core/lib/src/output/transcript_repository.dart`

- [ ] Implement `TranscriptRepository` as a plain class (not abstract; `keepAlive` provider)
- [ ] Constructor: `TranscriptRepository(TranscriptDatabase db)`
- [ ] Implement full public API from logical-components.md §RC-04:
  - `saveSegment(String sessionId, TranscriptSegment segment)` — INSERT OR REPLACE
  - `finalizeSession(String sessionId, {required int durationMs, required int segmentCount})`
  - `getSessions({int limit = 50, int offset = 0})` → `Future<List<TranscriptSession>>`
  - `getSession(String sessionId)` → `Future<TranscriptSession?>`
  - `getSegments(String sessionId)` → `Future<List<TranscriptSegment>>`
  - `getSegmentsBefore({required String sessionId, required DateTime beforeTimestamp, int limit = 100})` → `Future<List<TranscriptSegment>>`
  - `search(String query)` → `Future<List<TranscriptSearchResult>>` — use exact FTS5 query from nfr-design-patterns.md §Pattern 2
  - `deleteSession(String sessionId)` — cascade delete segments
  - `exportSession(String sessionId, ExportFormat format)` → `Future<String>` — TXT/SRT/VTT
  - `events` → `Stream<RepositoryEvent>` — backed by internal `StreamController.broadcast()`
- [ ] `events` stream is fed by `TranscriptDatabase.open()` via a controller passed to the repository constructor or exposed as a separate sink
- [ ] Logger: `Logger('zip_core.TranscriptRepository')` — log sessionId/segmentId only, never text content (Pattern 11)

---

## Step 7: Create OnScreenCaptionTarget (RC-01)

**File**: `packages/zip_core/lib/src/output/on_screen_caption_target.dart`

- [ ] Implement `OnScreenCaptionTarget implements CaptionOutputTarget`
- [ ] Use exact field set from logical-components.md §RC-01
- [ ] Constructor: `OnScreenCaptionTarget({required String targetId, int maxBufferSegments = 2000, TranscriptRepository? repository})`
- [ ] Implement debounce via `_debounceTimer` — exact pattern from nfr-design-patterns.md §Pattern 1
  - State updated synchronously on every `onCaptionEvent()` call
  - Only `_controller.add()` is debounced at 50ms (trailing emission)
- [ ] `onCaptionEvent(CaptionEvent event)` — handle `SttResultEvent` (final/interim) and `SessionStateEvent`
- [ ] `dispose()`: cancel `_debounceTimer`, close `_controller`
- [ ] `onVisibleCaptionsChanged`: `Stream<List<CaptionDisplayEntry>>` getter → `_controller.stream`
- [ ] `visibleCaptions`: synchronous getter — returns `[..._buffer, if (_currentInterim != null) _currentInterim!]`
- [ ] `loadOlderSegments()`: calls `_repository?.getSegmentsBefore(...)` when `_repository != null`
- [ ] Logger: `Logger('zip_core.OnScreenCaptionTarget')` — no text content in logs

---

## Step 8: Create TranscriptWriterTarget (RC-02)

**File**: `packages/zip_core/lib/src/output/transcript_writer_target.dart`

- [ ] Implement `TranscriptWriterTarget implements CaptionOutputTarget`
- [ ] Use exact field set from logical-components.md §RC-02
- [ ] Constructor: `TranscriptWriterTarget({required TranscriptRepository repository, required TranscriptSettings settings})`
- [ ] No `_pendingSegments`, no `_flushTimer` — immediate persistence only
- [ ] Implement `_handleFinalResult(SttResultEvent)` — exact merge window logic from nfr-design-patterns.md §Pattern 6
  - 2-second merge window per `sourceId` via `_lastFinalBySource`
  - Each path (new segment or merge) calls `_repository.saveSegment()` immediately
- [ ] Implement `_handleSessionStopped()` — calls `_repository.finalizeSession()`, clears state (Pattern 6 §Session Stop Flush)
- [ ] `onCaptionEvent()` — route to `_handleFinalResult` (final STT only) or `_handleSessionStopped`
- [ ] `dispose()`: no timer to cancel; just clear state
- [ ] Logger: `Logger('zip_core.TranscriptWriterTarget')` — log sessionId/segmentId only

---

## Step 9: Create zip_core providers

**File**: `packages/zip_core/lib/src/providers/transcript_providers.dart` (new or update existing)

- [ ] `transcriptRepositoryProvider` — `Provider<TranscriptRepository>` with `keepAlive: true`
  - Reads `path_provider` to obtain DB path
  - Opens `TranscriptDatabase` via static factory
  - Instantiates `TranscriptRepository`
- [ ] `transcriptSettingsProvider` — `Notifier<TranscriptSettings>` with `keepAlive: true`
  - Reads/writes `captureEnabled` to `SharedPreferences` key `transcript.captureEnabled`
- [ ] Export from `packages/zip_core/lib/zip_core.dart` barrel if needed.
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` from `packages/zip_core/`.

---

## Step 10: Create zip_core test infrastructure

### TI-01: MockTranscriptRepository
**File**: `packages/zip_core/test/helpers/mock_transcript_repository.dart`

- [ ] `class MockTranscriptRepository extends Mock implements TranscriptRepository {}`
- [ ] Add a `StreamController<RepositoryEvent>` and expose `emitCorruption(String path)` helper method for tests

### TI-03: drift In-Memory Helper
**File**: `packages/zip_core/test/helpers/db_helpers.dart`

- [ ] Implement `buildTestDatabase()` → `Future<TranscriptDatabase>` using `NativeDatabase.memory()`
- [ ] `onCreate` fires automatically; FTS5 table and triggers are created via normal path

### TI-05: PBT Generator Extensions (zip_core)
**File**: `packages/zip_core/test/helpers/generators.dart` (extend existing)

- [ ] Add `arbitraryTranscriptSession` — arbitrary UUID sessionId, arbitrary DateTime (UTC), optional title (null or ≤50 char string), non-negative durationMs, non-negative segmentCount
- [ ] Add `arbitraryTranscriptSegment` — arbitrary segmentId/sessionId (UUID-shaped strings), non-empty text, non-empty sourceId, `startTimeMs >= 0`, `endTimeMs >= startTimeMs`
- [ ] Add `arbitraryTranscriptSearchResult` — composed from arbitraryTranscriptSession + 1–3 non-empty snippet strings, arbitrary relevanceScore (double)

---

## Step 11: Write zip_core tests

### on_screen_caption_target_test.dart
**File**: `packages/zip_core/test/output/on_screen_caption_target_test.dart`

- [ ] Uses: TI-01 MockTranscriptRepository, TI-04 fake_async, TI-05 PBT generators
- [ ] Test: 10 `SttResultEvent`s within 10ms → `onVisibleCaptionsChanged` emits ≤2 times (fake_async, advance 50ms)
- [ ] Test: two events 60ms apart → exactly 2 emissions
- [ ] Test: `visibleCaptions` getter returns latest state before timer fires
- [ ] Test: `_debounceTimer` cancelled in `dispose()` — no post-dispose emission
- [ ] PBT: buffer length never exceeds `_maxBufferSegments` after any sequence of events

### transcript_writer_target_test.dart
**File**: `packages/zip_core/test/output/transcript_writer_target_test.dart`

- [ ] Uses: TI-01 MockTranscriptRepository, TI-04 fake_async, TI-05 PBT generators
- [ ] Test: final result → immediate `saveSegment()` call (mock verify)
- [ ] Test: second final result within 2s same source → `saveSegment()` called with merged text (upsert)
- [ ] Test: segments >2s apart (fake_async) → two separate `saveSegment()` calls
- [ ] Test: session stop → `finalizeSession()` with correct duration and count
- [ ] PBT: merged segment text equals space-joined input texts; `startTimeMs` from first result; `endTimeMs` from last

### transcript_repository_test.dart
**File**: `packages/zip_core/test/output/transcript_repository_test.dart`

- [ ] Uses: TI-03 drift in-memory, TI-05 PBT generators
- [ ] Test: `saveSegment()` + `getSegments()` round-trip
- [ ] Test: FTS5 search returns results with `[`/`]` snippet delimiters, ordered by ascending BM25 score, ≤3 snippets per session
- [ ] Test: `exportSession(SRT)` produces correctly formatted timestamps
- [ ] Test: corruption event emitted correctly (downstream: given `RepositoryEvent.corruption`, assert `events` stream carries it)
- [ ] PBT: `exportSession(SRT)` round-trip — segments parse back to same timestamps

---

## Step 12: Create DesktopWindowService + DesktopMultiWindowService (RC-09)

**Files**:
- `packages/zip_broadcast/lib/src/output/overlay/desktop_window_service.dart` (abstract)
- `packages/zip_broadcast/lib/src/output/overlay/desktop_multi_window_service.dart` (impl)

- [ ] Implement abstract interface from nfr-design-patterns.md §Pattern 7 (Interface section)
- [ ] Implement `DesktopMultiWindowService` from Pattern 7 (Production Implementation section)
  - `isSupported`: `Platform.isMacOS || Platform.isWindows || Platform.isLinux`

---

## Step 13: Create ObsWebSocketTarget (RC-05)

**File**: `packages/zip_broadcast/lib/src/output/obs/obs_websocket_target.dart`

- [ ] Implement `ObsWebSocketTarget implements CaptionOutputTarget`
- [ ] Use exact field set from logical-components.md §RC-05
- [ ] Constructor: `ObsWebSocketTarget({ObsWebSocket? connector})` — `connector` is `@visibleForTesting` seam for injecting mock; production creates its own `ObsWebSocket`
- [ ] `connect(ObsSettings settings)` — initiates connection, starts reconnect loop on failure
- [ ] Backoff schedule: `min(1000 * pow(2, attempt - 1), 30000)` ms delay between attempts
- [ ] 10-minute timeout: if `now - _retryStartMs >= 600_000`, emit `ObsError`, set `_enabled = false`
- [ ] `onCaptionEvent()` — send `SendStreamCaption` for final `SttResultEvent` only when `_connectionState is ObsConnected`
- [ ] `disconnect()` — set `_enabled = false`, cancel `_reconnectTimer`, close `_client`
- [ ] `dispose()` — calls `disconnect()`
- [ ] `connectionStateStream` — `Stream<ObsConnectionState>` getter → `_stateController.stream`
- [ ] Logger: `Logger('zip_broadcast.ObsWebSocketTarget')` — log host:port, attempt count, error type. Never log password.

---

## Step 14: Create BrowserSourceServer (RC-06)

**File**: `packages/zip_broadcast/lib/src/output/browser_source/browser_source_server.dart`

- [ ] Implement `BrowserSourceServer` using `shelf` + `shelf_router`
- [ ] Use exact field set from logical-components.md §RC-06
- [ ] Constructor: `BrowserSourceServer({@visibleForTesting bool Function(Request)? isLocalhost})` — TI-06 seam (Pattern 9)
- [ ] `start({int? port})` — generate UUID v4 token, bind shelf server; throw `ArgumentError` for port outside [1024, 65535]; throw `BrowserSourceStartException(reason: portInUse)` on `SocketException`
- [ ] `stop()` — close server, close all client controllers
- [ ] `GET /` — serve HTML page with embedded SSE JS client; embed token in JS SSE URL
- [ ] `GET /captions` — SSE endpoint: token auth (Pattern 4), 5-client cap → 503 on exceeded, `StreamController<List<int>>` per client (Pattern 3)
- [ ] `pushCaption(String text, bool isFinal)` — broadcast SSE event to all clients; cache as `_latestCaption`; replay to new client on connect
- [ ] `_removeClient()` — idempotent: check `_clients.remove()` return value before decrementing count
- [ ] Disconnect detection: `controller.sink.done` (clean) and `SocketException` on write (abrupt) — both call `_removeClient()`
- [ ] Logger: `Logger('zip_broadcast.BrowserSourceServer')` — log client count, port, token events. Never log SSE text payload.

---

## Step 15: Create BrowserSourceTarget (RC-07)

**File**: `packages/zip_broadcast/lib/src/output/browser_source/browser_source_target.dart`

- [ ] Implement `BrowserSourceTarget implements CaptionOutputTarget`
- [ ] Constructor: `BrowserSourceTarget({required BrowserSourceServer server})`
- [ ] `onCaptionEvent()`:
  - `SttResultEvent` → `_server.pushCaption(event.result.text, event.result.isFinal)`
  - `SessionStateEvent.recording` → `_server.pushCaption('', false)` (clear on new session)
  - `SessionStateEvent.stopped` → `_server.pushSessionState('stopped')`
- [ ] `dispose()` — no resources owned directly

---

## Step 16: Create CaptionOverlayTarget (RC-08)

**File**: `packages/zip_broadcast/lib/src/output/overlay/caption_overlay_target.dart`

- [ ] Implement `CaptionOverlayTarget implements CaptionOutputTarget`
- [ ] Use exact field set from logical-components.md §RC-08
- [ ] Constructor: `CaptionOverlayTarget({required String targetId, required DesktopWindowService windowService, OverlayConfig? config})`
- [ ] `show()`:
  - Guard: `if (!_windowService.isSupported) return;`
  - If already visible: call `_windowService.invokeMethod(_windowId!, 'updateConfig', config?.toJson())` only
  - Else: call `_windowService.createWindow(...)` → store `_windowId`; set `_isVisible = true`
- [ ] `hide()`: call `_windowService.closeWindow(_windowId!)`, set `_isVisible = false`, clear `_windowId`
- [ ] `onCaptionEvent()`: if `_isVisible`, call `_windowService.invokeMethod(_windowId!, 'captionUpdate', event payload)`
- [ ] `dispose()`: call `hide()` if visible

---

## Step 17: Create zip_broadcast providers

**File**: `packages/zip_broadcast/lib/src/providers/broadcast_providers.dart`

- [ ] `obsSettingsProvider` — `Notifier<ObsSettings>` with `keepAlive: true`
  - Reads host/port from `SharedPreferences` (`obs.host`, `obs.port`)
  - Reads password from `FlutterSecureStorage` key `obs.password`
  - `update()` writes host/port to prefs, password to secure storage
- [ ] `outputTargetSettingsProvider` — `Notifier<OutputTargetSettings>` with `keepAlive: true`
  - Reads/writes all bool toggles and `browserSourcePort` to `SharedPreferences`
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` from `packages/zip_broadcast/`.

---

## Step 18: Create zip_broadcast test infrastructure

### TI-02: MockDesktopWindowService
**File**: `packages/zip_broadcast/test/helpers/mock_desktop_window_service.dart`

- [ ] `class MockDesktopWindowService extends Mock implements DesktopWindowService {}`

### TI-05: PBT Generators (zip_broadcast — new file)
**File**: `packages/zip_broadcast/test/helpers/generators.dart`

- [ ] Add `arbitraryObsConnectionState` — `oneOf` across all sealed variants; for variants with fields, generate plausible values
- [ ] Add `arbitraryOutputTargetSettings` — bool toggles arbitrary, port in range [1024, 65535]

---

## Step 19: Write zip_broadcast tests

### obs_websocket_target_test.dart
**File**: `packages/zip_broadcast/test/output/obs_websocket_target_test.dart`

- [ ] Uses: TI-04 fake_async, TI-05 generators
- [ ] Test: backoff schedule — 1s, 2s, 4s, 8s, 16s, 30s cap (fake_async, verify timer delays)
- [ ] Test: after 10-minute total elapsed → `ObsError` emitted, `_enabled = false`
- [ ] Test: `onCaptionEvent` with final result when connected → `SendStreamCaption` called
- [ ] Test: `onCaptionEvent` when not connected → no send
- [ ] Test: `disconnect()` suppresses further reconnection attempts

### browser_source_server_test.dart
**File**: `packages/zip_broadcast/test/output/browser_source_server_test.dart`

- [ ] Uses: TI-06 `isLocalhost` seam, `http` package, `dart:io HttpClient`
- [ ] Test setup: `start(port: 0)`, teardown: `stop()`
- [ ] Test: 5th SSE client accepted (200); 6th returns 503 with `max_clients_exceeded` body
- [ ] Test: after disconnect (close HttpClient), `_activeClientCount` decrements; new client accepted
- [ ] Test: `pushCaption()` broadcasts to all connected clients
- [ ] Test: new client receives `_latestCaption` replay immediately
- [ ] Test (remote, using `isLocalhost` seam → false): request without token → 401
- [ ] Test (remote): request with wrong token → 401
- [ ] Test (remote): request with correct token → 200 `text/event-stream`
- [ ] Test (localhost): request without token → 200 (bypasses auth)
- [ ] Test: `start()` with port outside [1024, 65535] → `ArgumentError`

### browser_source_target_test.dart
**File**: `packages/zip_broadcast/test/output/browser_source_target_test.dart`

- [ ] Mock `BrowserSourceServer` (mocktail)
- [ ] Test: final `SttResultEvent` → `pushCaption(text, true)` called
- [ ] Test: interim `SttResultEvent` → `pushCaption(text, false)` called
- [ ] Test: `SessionStateEvent.recording` → `pushCaption('', false)` called
- [ ] Test: `SessionStateEvent.stopped` → `pushSessionState('stopped')` called

### caption_overlay_target_test.dart
**File**: `packages/zip_broadcast/test/output/caption_overlay_target_test.dart`

- [ ] Uses: TI-02 MockDesktopWindowService
- [ ] Test: `show()` on fresh target → `createWindow()` called once; `_isVisible = true`
- [ ] Test: `show()` when already visible → no second `createWindow()`; `invokeMethod('updateConfig', ...)` called
- [ ] Test: `hide()` → `closeWindow()` called; `_isVisible = false`
- [ ] Test: `dispose()` when visible → `closeWindow()` called
- [ ] Test: `onCaptionEvent()` when not visible → `invokeMethod` not called
- [ ] Test: `onCaptionEvent()` when visible → `invokeMethod('captionUpdate', ...)` called
- [ ] Test: `isSupported == false` → `show()` is no-op; `isVisible` stays `false`

---

## Step 20: Update barrel exports

- [ ] `packages/zip_core/lib/zip_core.dart` — export new models and classes:
  - `CaptionDisplayEntry`, `TranscriptSession`, `TranscriptSegment`, `TranscriptSettings`, `TranscriptSearchResult`, `ExportFormat`, `RepositoryEvent`
  - `TranscriptDatabase`, `TranscriptRepository`
  - `OnScreenCaptionTarget`, `TranscriptWriterTarget`
  - `transcriptRepositoryProvider`, `transcriptSettingsProvider`
- [ ] `packages/zip_broadcast/lib/zip_broadcast.dart` — export new classes:
  - `ObsSettings`, `ObsConnectionState`, `OutputTargetSettings`
  - `ObsWebSocketTarget`, `BrowserSourceServer`, `BrowserSourceTarget`, `CaptionOverlayTarget`
  - `DesktopWindowService`, `DesktopMultiWindowService`
  - `obsSettingsProvider`, `outputTargetSettingsProvider`

---

## Step 21: Update aidlc-docs state and audit

- [ ] Edit `aidlc-docs/aidlc-state.md` line 71: mark Unit 3 CG complete
- [ ] Append to `aidlc-docs/audit.md`:
  ```
  ## Code Generation — Unit 3: Output Targets
  **Timestamp**: [ISO timestamp at completion]
  **AI Response**: Code generation complete per output-targets-code-generation-plan.md
  **Context**: All 21 steps executed; 9 RC + 6 TI elements generated across zip_core and zip_broadcast
  ```

---

## Completion Criteria

All steps marked [x] and:
- `flutter analyze packages/zip_core packages/zip_broadcast` → 0 issues
- `flutter test packages/zip_core` → all pass
- `flutter test packages/zip_broadcast` → all pass
- No files created in `aidlc-docs/` (application code in workspace root only)
- No transcript text, session titles, or OBS passwords appear in any log call
