# NFR Requirements Plan — Unit 3: Output Targets

## Prerequisites
- [x] Functional Design complete — all 12 questions answered
- [x] FD artifacts present at `aidlc-docs/construction/output-targets/functional-design/`
- [x] Prior unit NFR references available (Unit 1, Unit 2)

## Steps

- [x] Step 1: Analyze Functional Design artifacts
- [x] Step 2: Generate NFR assessment questions
- [x] Step 3: Collect answers
- [x] Step 4: Generate NFR artifacts (`nfr-requirements.md`, `tech-stack-decisions.md`)
- [ ] Step 5: Present for approval

---

## NFR Assessment Questions

### Performance

**NFR-Q1: onCaptionEvent() Synchronous Latency**

`OnScreenCaptionTarget.onCaptionEvent()` synchronously updates the in-memory buffer and emits to a `StreamController`. At 20+ events/second (inherited from PERF-U1.1), each call must complete quickly enough to not stall the `CaptionBus` subscription.

Is an upper bound of **1ms** per `onCaptionEvent()` call (for the synchronous buffer/stream work, excluding downstream listener processing) a suitable NFR, or should we treat this as "no blocking I/O allowed — no explicit latency bound needed"?

[Answer]: That seems unnecessarily restrictive, we should instead debounce and limit the synchronous updates from the `OnScreenCaptionTarget.onCaptionEvent()` emitter so that we can roll up very rapid changes into updates every ~50ms.

---

**NFR-Q2: FTS5 Search Latency**

`TranscriptRepository.search()` runs a BM25 FTS5 query returning up to 50 sessions. For an accessibility tool, search is user-initiated and not on the caption path.

What is the acceptable query latency target? Options:
- A — Under 500ms for a database with up to 1,000 sessions and 100,000 segments (suitable for a single-user local database, measurable in test)
- B — No formal latency bound; treat as "should feel fast" and test for correctness only
- C — Under 200ms (tighter target, may constrain FTS5 index design in future)

[Answer]: A

---

**NFR-Q3: BrowserSourceServer — Maximum Simultaneous SSE Clients**

`BrowserSourceServer` broadcasts every caption event to all connected SSE clients. In practice, most users will have one OBS browser source connected. However, the server has no enforced limit.

Should there be a cap on simultaneous SSE connections?
- A — No cap (accept all connections; Dart's `HttpServer` + `shelf` will handle backpressure naturally)
- B — Cap at 5 clients; reject additional connections with `503 Service Unavailable`
- C — Cap at 10 clients

[Answer]: B

---

### Security

**NFR-Q4: BrowserSourceServer — Network Interface Binding**

`BrowserSourceServer` will start an HTTP server on the configured port. The binding interface determines who can reach it:

- A — Bind to `localhost` (127.0.0.1) only. Only processes on the same machine can connect. OBS must be on the same machine. Most secure.
- B — Bind to all interfaces (`0.0.0.0`). OBS on a networked machine (e.g., a dedicated capture PC) can connect. Exposes the port on the local network.

This is a security and usability trade-off. Note: AGENTS.md constraints require all relay infrastructure to have zero-retention, but no constraint exists on local HTTP servers.

[Answer]: B

---

**NFR-Q5: BrowserSourceServer SSE Endpoint — Access Control**

The `/captions` SSE endpoint currently has no authentication. Any process that can reach the server's port can subscribe to captions.

Given that `BrowserSourceServer` serves transcript text (which must never leave the device per the project's zero-knowledge principle), should `/captions` require a one-time token (generated at server start, embedded in the HTML page's JS client)?

- A — No authentication. Acceptable because the server is localhost-only (if NFR-Q4=A) and the caption stream is not stored.
- B — One-time token in the SSE URL (`/captions?token={uuid}`). The HTML page embeds the token; a direct request without it gets `401`.

[Answer]: B but only for requests that are not from the same machine. Requests from 127.0.0.1 should not require a token.

---

### Reliability

**NFR-Q6: TranscriptDatabase — Corruption Recovery**

If the drift database file is corrupt or unreadable at app startup (e.g., truncated file from a crash mid-write), what should `TranscriptRepository` do?

- A — Surface an error; disable transcript capture and search until the user clears app data. No automatic data loss.
- B — Delete the corrupt database file and open a fresh empty database. Transcript data is lost, but the app continues normally.
- C — Run SQLite `PRAGMA integrity_check`; if it fails, rename the corrupt file to `transcripts.db.corrupt` and open a fresh database. No silent data loss — the corrupt file is preserved for potential recovery.

[Answer]: C - but notify the user with the error and instructions on where to find the corrupt db file on their device.

---

**NFR-Q7: BrowserSourceServer — Port-In-Use Handling**

If `BrowserSourceServer.start()` is called and the configured port is already in use (e.g., another app holds it, or the server was not cleanly stopped), what should happen?

- A — Throw immediately with a structured error. `OutputTargetSettingsProvider` surfaces it to the user ("Port 8080 is in use. Change the port in settings.").
- B — Attempt to bind to `port + 1` up to 5 times before giving up. Update `OutputTargetSettings.browserSourcePort` to the successfully bound port.

[Answer]: A

---

**NFR-Q8: TranscriptWriterTarget — Durability of Pending Segments**

Pending segments in `TranscriptWriterTarget._pendingSegments` are flushed every 30 seconds and on `SessionStateEvent(stopped)`. On an unexpected app crash or kill, up to 30 seconds of final captions can be lost.

Is this level of durability acceptable for Phase 1, or should segments be written to the database more aggressively?
- A — Acceptable. 30s loss on crash is fine for an accessibility tool; the periodic flush is a best-effort durability measure.
- B — Flush immediately on each final result (one DB write per segment; no 30s buffer). Guarantees no loss on crash.
- C — Flush more frequently (e.g., every 5 seconds) as a middle ground.

[Answer]: B

---

### Testing

**NFR-Q9: Unit 3 Coverage Target**

Unit 1 targeted ≥ 80% coverage. Unit 2 raised this to ≥ 90%. What is the coverage target for Unit 3?

- A — ≥ 90% (carry forward Unit 2 target)
- B — ≥ 80% (acknowledge that platform-channel-dependent code in `CaptionOverlayTarget` is hard to unit-test)
- C — ≥ 90% with `CaptionOverlayTarget` excluded from the coverage denominator (desktop_multi_window platform channels cannot be tested without native runners)

[Answer]: C

---

**NFR-Q10: CaptionOverlayTarget — Test Strategy**

`CaptionOverlayTarget` calls `DesktopMultiWindow.createWindow()` and `DesktopMultiWindow.invokeMethod()` — these are platform channel calls with no pure-Dart fallback. Testing strategies:

- A — Mock the `DesktopMultiWindow` static class using a thin wrapper interface injected into `CaptionOverlayTarget`, allowing full unit test coverage including window lifecycle. (Adds an indirection layer to production code.)
- B — Exclude `CaptionOverlayTarget` from unit tests. Cover it with a manual acceptance test checklist only.
- C — Introduce a `DesktopWindowService` abstraction used by `CaptionOverlayTarget`, with a `MockDesktopWindowService` for tests. `CaptionOverlayTarget` depends on the abstraction, not the package directly. (Adds an interface but is clean and consistent with the SttEngine pattern.)

[Answer]: C

---

**NFR-Q11: TranscriptDatabase — Test Database**

`TranscriptDatabase` (drift) supports in-memory databases for testing. Should:

- A — All `TranscriptRepository` tests use an in-memory drift database. FTS5 is tested via the real SQLite FTS5 module (available in drift's bundled SQLite). No file I/O in tests.
- B — Use a mocked `TranscriptRepository` for all consumer tests (`TranscriptWriterTarget`, `OnScreenCaptionTarget`), and test `TranscriptRepository` itself with the real in-memory drift database.

(Note: option B is layered — consumers use mocks, the repository itself uses real drift.)

[Answer]: A

---

### Maintainability

**NFR-Q12: Transcript Retention Policy**

`TranscriptRepository` accumulates sessions indefinitely. Over months of use, the SQLite database could grow to many hundreds of sessions and millions of segments.

Should Unit 3 implement a retention policy?
- A — No retention policy in Unit 3. Manual deletion via `deleteSession()` is the only mechanism. A retention policy is deferred to a future phase.
- B — Implement a configurable maximum session count (default: 90 sessions). When the limit is exceeded, the oldest session is auto-deleted. Exposed as a `TranscriptSettings` field.
- C — Implement auto-delete for sessions older than a configurable number of days (default: 90 days).

[Answer]: A - capture this as a future feature post-launch

---

**NFR-Q13: Drift Database Schema Version**

The `TranscriptDatabase` is a new database introduced in Unit 3. It must declare a `schemaVersion`. Future phases may add columns or tables.

Should the initial `schemaVersion` be:
- A — `1` (standard for a new database; migrations added when schema changes are needed)
- B — `1` with a documented migration scaffold already in place (empty `MigrationStrategy` with `from` switch ready for `2`, `3`, etc.)

[Answer]: B

