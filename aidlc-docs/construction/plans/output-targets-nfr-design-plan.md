# NFR Design Plan — Unit 3: Output Targets

## Unit Context

Unit 3 covers four stories: S-04 (on-screen captions), S-05 (transcript persistence), S-07 (OBS
WebSocket output), and S-08 (browser source / caption overlay). NFR Requirements are complete and
approved (2026-04-05). This plan captures the design questions needed before generating the two
NFR Design artifacts.

## Prerequisites

- [x] Functional Design complete — all 12 questions answered; artifacts at
  `aidlc-docs/construction/output-targets/functional-design/`
- [x] NFR Requirements complete — 20 requirements across 5 categories; artifacts at
  `aidlc-docs/construction/output-targets/nfr-requirements/`
- [x] Prior unit NFR Design references available (Units 1, 2, zip-core)

## Steps

- [x] Step 1: Analyze NFR Requirements artifacts
- [x] Step 2: Identify open design questions
- [x] Step 3: Generate and collect answers (questions below)
- [ ] Step 4: Generate NFR Design artifacts
- [ ] Step 5: Present for approval
- [ ] Step 6: Update `audit.md` and `aidlc-state.md`

---

## Design Questions

### NFR-DQ1: Debounce Pattern for OnScreenCaptionTarget (PERF-U3.1)

`OnScreenCaptionTarget.onCaptionEvent()` updates internal state synchronously and must coalesce
stream emissions to ≤1 per 50ms. `rxdart` is not present in the monorepo, so both options use
pure Dart only.

- **A** — Debounce at the `StreamController.add()` call site: update `_buffer`/`_currentInterim`
  synchronously on each call, then cancel + restart a `Timer(Duration(milliseconds: 50), () =>
  _controller.add(_snapshot()))`. Only the trailing state is emitted when the timer fires. State
  is always current even if the emission is delayed.
- **B** — Debounce via a `StreamTransformer` on the output stream: `_controller.add()` is called
  synchronously on every mutation; consumers subscribe to
  `stream.transform(_debounceTransformer(50ms))`. Internal mutation logic stays simple; the
  coalescing is in the delivery layer. Requires a custom `StreamTransformer` implementation.

[Answer]:

---

### NFR-DQ2: Database Corruption Recovery Test Strategy (REL-U3.1)

REL-U3.1 requires: on startup, run `PRAGMA integrity_check`; if it fails, rename the file to
`transcripts.db.corrupt`, open a fresh database, and emit `RepositoryEvent.corruption`. Drift's
in-memory database (`NativeDatabase.memory()`) cannot simulate a `PRAGMA integrity_check` failure,
so the full recovery path requires a test-specific hook or a real file.

- **A** — Introduce a `DatabaseHealthChecker` abstract class with a single method
  `Future<bool> isHealthy(Database db)`. `TranscriptDatabase` is injected with an instance
  (default: `SqliteHealthChecker` that runs the real `PRAGMA`; tests use
  `MockDatabaseHealthChecker`). Full unit test coverage of the rename + notify path with no
  real files.
- **B** — Test using a real file-backed drift database in a `dart:io` temp directory. The test
  writes a corrupt SQLite file (e.g., all-zero bytes), then opens `TranscriptDatabase` and
  asserts the recovery behavior. Slower, requires `--platform vm`, but no additional production
  abstraction.
- **C** — Skip unit testing of the `PRAGMA` + file-rename path. Unit-test only the downstream
  effects: given a `RepositoryEvent.corruption` emission, the UI receives the notification and
  the repository returns a fresh empty state. Treat the SQLite path itself as an acceptance test.

[Answer]:

---

### NFR-DQ3: SSE Client Disconnect Detection (PERF-U3.3)

`BrowserSourceServer` caps simultaneous SSE clients at 5. When a client disconnects (browser
closed, OBS tab changed), its slot must be freed. In `shelf`, the response body is a
`Stream<List<int>>` and the framework does not provide an explicit disconnect callback.

- **A** — Use `request.hijack()` to take over the raw socket. Listen to `socket.done` to detect
  disconnect and decrement the active-client counter. Gives direct socket access for writing SSE
  frames, but bypasses shelf's normal response lifecycle.
- **B** — Keep each client's SSE events in a `StreamController<List<int>>`. The shelf response
  streams from `controller.stream`. Catch write errors (`SocketException`, broken pipe) via an
  `onError` handler on the sink; close the controller and decrement the counter on error or
  `onDone`. Works within shelf's normal response model.
- **C** — Maintain a `Set<StreamController<List<int>>>` of active clients. When shelf closes a
  client's response stream (client gone), the controller's `onCancel` callback fires;
  `onCancel` decrements the counter and removes the entry from the set. Cleanest from a
  lifecycle standpoint; relies on shelf closing the stream when the connection drops.

[Answer]:

---

## Planned Patterns

_(To be fully specified in `nfr-design-patterns.md` after answers are collected.)_

| # | Pattern | NFR IDs |
|---|---------|---------|
| 1 | Timer-Based Debounce — OnScreenCaptionTarget | PERF-U3.1 |
| 2 | FTS5 Query via drift — TranscriptRepository.search | PERF-U3.2 |
| 3 | SSE Client Cap + Disconnect Detection — BrowserSourceServer | PERF-U3.3 |
| 4 | UUID Token Auth + Localhost Bypass — BrowserSourceServer | SEC-U3.3 |
| 5 | Database Corruption Recovery — PRAGMA → rename → fresh DB | REL-U3.1 |
| 6 | Immediate Segment Persistence via Merge Window | REL-U3.3 |
| 7 | DesktopWindowService Abstraction + MockDesktopWindowService | TEST-U3.2 |
| 8 | fake_async Timer Tests — merge window + OBS backoff | TEST-U3.4 |
| 9 | BrowserSourceServer Test Pattern — shelf test client | TEST-U3.5 |
| 10 | PBT Generators — new domain types | general |
| 11 | Logging Pattern Extension — zip_broadcast logger names | SEC-U3.1/2, MAINT-U3.2 |

## Planned Components

_(To be fully specified in `logical-components.md` after answers are collected.)_

**Runtime (9 components):**

| Component | Package | Notes |
|-----------|---------|-------|
| OnScreenCaptionTarget | zip_core | Debounced StreamController, CaptionDisplayEntry buffer |
| TranscriptWriterTarget | zip_core | Immediate segment persistence, merge window |
| TranscriptDatabase | zip_core | drift, FTS5 virtual table, schemaVersion 1 |
| TranscriptRepository | zip_core | Wraps TranscriptDatabase; FTS5 search, export |
| ObsWebSocketTarget | zip_broadcast | obs_websocket, exponential backoff |
| BrowserSourceServer | zip_broadcast | shelf, SSE, UUID token, 5-client cap |
| BrowserSourceTarget | zip_broadcast | Bridges CaptionBus → BrowserSourceServer |
| CaptionOverlayTarget | zip_broadcast | Depends on DesktopWindowService abstraction |
| DesktopWindowService | zip_broadcast | Abstract interface; DesktopMultiWindowService impl |

**Test Infrastructure:**
- `MockTranscriptRepository` (mocktail) — for TranscriptWriterTarget + OnScreenCaptionTarget tests
- `MockDesktopWindowService` (mocktail) — for CaptionOverlayTarget tests
- drift in-memory database helper — for TranscriptRepository tests
- `fake_async` wrapper — for merge-window (2s) and OBS backoff schedule tests
- PBT `Arbitrary<T>` generators — ObsConnectionState, TranscriptSession, TranscriptSegment,
  OutputTargetSettings, TranscriptSearchResult
- shelf test client setup — for BrowserSourceServer integration tests
