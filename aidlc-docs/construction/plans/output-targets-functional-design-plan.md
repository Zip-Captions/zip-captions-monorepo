# Functional Design Plan — Unit 3: Output Targets

## Unit Summary

**Stories**: S-04 (Caption Rendering), S-05 (Transcript Management), S-07 (OBS WebSocket), S-08 (Browser Source)

**Packages**: `zip_core` (shared targets), `zip_broadcast` (broadcast-only targets)

## Plan Steps

- [ ] Phase A: Domain models
  - [ ] A1: `CaptionDisplayEntry` model
  - [ ] A2: `ExportFormat` enum (TXT, SRT, VTT)
  - [ ] A3: `TranscriptSettings` (freezed)
  - [ ] A4: `ObsSettings` (freezed)
  - [ ] A5: `ObsConnectionState` (sealed class or enum)
  - [ ] A6: `OutputTargetSettings` (freezed)

- [ ] Phase B: zip_core shared targets
  - [ ] B1: `OnScreenCaptionTarget` (buffer model, display entry lifecycle, style mapping)
  - [ ] B2: `TranscriptWriterTarget` (segment accumulation, session lifecycle, flush)

- [ ] Phase C: Transcript storage layer
  - [ ] C1: `TranscriptDatabase` drift schema (tables, FTS5 virtual table)
  - [ ] C2: `TranscriptRepository` implementation (CRUD, search, export)
  - [ ] C3: Export format logic (TXT, SRT, VTT)

- [ ] Phase D: zip_broadcast targets
  - [ ] D1: `ObsWebSocketTarget` (WS v5 handshake, auth, caption send, reconnect)
  - [ ] D2: `BrowserSourceServer` (shelf pipeline, SSE endpoint, static HTML)
  - [ ] D3: `BrowserSourceTarget` (SSE fan-out, client lifecycle)
  - [ ] D4: `CaptionOverlayTarget` (interface + implementation scope decision)

- [ ] Phase E: Providers
  - [ ] E1: `TranscriptRepositoryProvider` (keepAlive, database init)
  - [ ] E2: `TranscriptSettingsProvider` (shared_preferences, captureEnabled)
  - [ ] E3: `ObsSettingsProvider` (settings persistence, password storage)
  - [ ] E4: `OutputTargetSettingsProvider` (per-target toggles)

- [ ] Phase F: Business rules document (BR-U3-01..N)

- [ ] Phase G: Generate artifacts
  - [ ] G1: `domain-entities.md`
  - [ ] G2: `business-logic-model.md`
  - [ ] G3: `business-rules.md`

---

## Questions

**Q1 — Caption display buffer and scrollback model**

**Confirmed design constraints:**
- `maxVisibleLines` is a *viewport* setting only — caps how many lines auto-scroll at the bottom; does not truncate history
- A separate `maxBufferSegments` cap limits in-memory storage to prevent unbounded growth for long sessions
- Buffer starts at the beginning of the session; UI uses virtualized list rendering (only visible items rendered)
- One current interim entry held separately; replaced on update; promoted to buffer on final; `sourceId` carried through for widget-layer style lookup

**Question**: When the buffer reaches `maxBufferSegments` and older entries are evicted, how does the user access the full session history beyond the in-memory buffer?

A) Evicted entries are permanently gone from `OnScreenCaptionTarget` — the cap is generous (e.g., 2000 segments) and acceptable as a practical limit for the live view. Full historical review is the job of the Session History screen post-session.
B) `OnScreenCaptionTarget` pages older evicted segments back in from `TranscriptRepository` on demand as the user scrolls up past the buffer boundary — requires `TranscriptWriterTarget` to flush periodically during the session, not just on stop.
C) `OnScreenCaptionTarget` never evicts — it always keeps the full session in memory. `maxBufferSegments` only controls how many items the widget renders in its visible window (virtualized rendering), not how many are stored.

[Answer]: B

---

**Q2 — sourceId → visual style mapping in OnScreenCaptionTarget**

How does `OnScreenCaptionTarget` know which `AudioInputVisualStyle` to apply for a given `sourceId`?

A) `OnScreenCaptionTarget` is constructed with a `Map<String, AudioInputVisualStyle> styleMap`; updated via `updateStyleMap()` when input configs change.
B) Visual styling is not the target's responsibility — `CaptionDisplayEntry` carries the `sourceId` string only and the widget layer does the style lookup independently.
C) `OnScreenCaptionTarget` receives an `AudioInputSettingsProvider` reference and reads the current config on each event.

[Answer]: B

---

**Q3 — TranscriptWriterTarget segment granularity**

How does `TranscriptWriterTarget` accumulate segments?

A) Final results only (`SttResult.isFinal == true`). Interim results are ignored by the writer.
B) All results (interim + final), replacing the pending interim when a final arrives — one in-progress segment at a time.
C) Final results only, but consecutive results from the same `sourceId` within a short time window (e.g., 2 s) are merged into a single segment.

[Answer]: C

---

**Q4 — FTS5 search return type**

`TranscriptRepository.search()` is specified to return `List<TranscriptSession>`. How should the internal query be structured?

A) FTS5 MATCH on segments, joining back to sessions. Returns distinct sessions ordered by BM25 relevance (summed across matching segments).
B) Simple LIKE query on `segments.text` (no FTS5), ordered by session date descending.
C) FTS5 MATCH on segments, but return a richer `List<TranscriptSearchResult>` that includes matching snippet text alongside the session — changing the public API signature.

[Answer]: C

---

**Q5 — SRT/VTT export timestamp base**

How should timestamps be formatted in SRT and VTT export?

A) Relative to session start — timestamps begin at `00:00:00,000` and increase with `segment.startTime`.
B) Absolute wall-clock — use `session.date + segment.startTime` as the real-world timestamp.

[Answer]: A

---

**Q6 — OBS WebSocket package**

Which approach for the OBS WebSocket v5 integration?

A) `obs_websocket` pub.dev package (handles v5 protocol, auth challenge-response, message types)
B) `web_socket_channel` + thin hand-written OBS WS v5 message layer (auth + SendStreamCaption only — minimal surface)
C) `web_socket_channel` + full custom serialization for all OBS WS v5 message types

[Answer]: A

---

**Q7 — OBS reconnection strategy**

What reconnection behaviour should `ObsWebSocketTarget` use when the connection drops?

A) Fixed 2 s interval, max 5 attempts, then give up (user must re-enable OBS output to retry)
B) Exponential backoff starting at 1 s, doubling to max 30 s, retrying indefinitely until the user disables OBS output
C) Exponential backoff starting at 1 s, doubling to max 30 s, giving up after 10 minutes of total retry time

[Answer]: C

---

**Q8 — Browser source port**

How should the `BrowserSourceServer` port be managed?

A) Fixed at 8080 — no configuration; URL is always `http://localhost:8080`
B) User-configurable port (1024–65535), default 8080, stored in `OutputTargetSettings`
C) System-assigned random available port; URL is shown to the user after the server starts

[Answer]: B

---

**Q9 — Browser source HTML delivery**

How should the caption overlay HTML page be served?

A) Inline Dart string constant — self-contained HTML/CSS/JS embedded directly in source code
B) Flutter asset file bundled with the app, loaded via `rootBundle.loadString()` at server start
C) Generated at runtime from a template, interpolating current display settings into the HTML at request time

[Answer]: C

---

**Q10 — SSE payload format**

What should each Server-Sent Event carry?

A) Minimal JSON: `{"type": "sttResult"|"sessionState", "text": "...", "isFinal": true|false}` — only fields the browser rendering needs
B) Full serialized `CaptionEvent` JSON (mirrors the Dart model exactly)
C) Plain text caption string only, with event type in the SSE `event:` field header

[Answer]: A

---

**Q11 — OBS password storage**

`ObsSettingsProvider` needs to persist an OBS WebSocket password. How should it be stored?

A) `flutter_secure_storage` for the password field; host and port in `shared_preferences`
B) All OBS settings in `shared_preferences` plain text (OBS is localhost-only; password is low-sensitivity connection credential)
C) All OBS settings in `flutter_secure_storage`

[Answer]: A

---

**Q12 — CaptionOverlayTarget scope in Unit 3**

What should Unit 3 deliver for `CaptionOverlayTarget`?

A) Interface + full multi-window implementation using Flutter's platform channel / multi-window APIs
B) Interface + no-op stub (`StubCaptionOverlayTarget`) — logs events, does nothing; full implementation deferred to Unit 6
C) Skip entirely from Unit 3 — define and implement alongside the Zip Broadcast UI in Unit 6

[Answer]: A
