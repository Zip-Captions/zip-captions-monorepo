# Business Rules — Unit 3: Output Targets

## Caption Buffer (BR-U3-01 .. BR-U3-05)

**BR-U3-01** — `OnScreenCaptionTarget` defaults to `maxBufferSegments = 2000`. This value is generous enough to cover multi-hour sessions without eviction under normal use.

**BR-U3-02** — When the buffer reaches `maxBufferSegments` and a new final result is added, the oldest entry (index 0) is evicted before the new entry is appended. Evicted entries are accessible via `loadOlderSegments()` when a `TranscriptRepository` is injected.

**BR-U3-03** — The `currentInterimEntry` is replaced (not appended) on each interim `SttResultEvent` for the same session. Only one interim entry exists at any time.

**BR-U3-04** — When a final `SttResultEvent` arrives, `currentInterimEntry` is promoted to the buffer as a final entry. `currentInterimEntry` is set to null.

**BR-U3-05** — On `SessionStateEvent(recording)`, the buffer and `currentInterimEntry` are both cleared and `currentSessionId` is updated. Previous session data in the buffer is discarded.

---

## Transcript Capture (BR-U3-06 .. BR-U3-12)

**BR-U3-06** — `TranscriptWriterTarget` only accumulates results where `isFinal == true`. Interim results are discarded.

**BR-U3-07** — Consecutive final results from the same `sourceId` within the same session, where the gap between `endTimeMs` values is <= 2000 ms, are merged into a single `TranscriptSegment`. Merged text is joined with a single space. The segment's `startTimeMs` is from the first result; `endTimeMs` is updated to the latest result.

**BR-U3-08** — Results from different `sourceId` values are never merged, regardless of timing.

**BR-U3-09** — `TranscriptWriterTarget` flushes pending segments to `TranscriptRepository` every 30 seconds during an active session, and again as a final flush when `SessionStateEvent(stopped)` is received.

**BR-U3-10** — When `TranscriptSettings.captureEnabled == false`, `TranscriptWriterTarget` discards all `SttResultEvent`s. No data is written to the repository.

**BR-U3-11** — Transcript capture state changes (`captureEnabled` toggle) take effect on the next session. In-progress sessions complete with the capture setting that was active when they started.

**BR-U3-12** — The `TranscriptSession.title` is derived from the first 50 characters of the first final segment's text, trimmed of leading/trailing whitespace. If no segments exist at flush time, `title` remains null.

---

## Transcript Storage (BR-U3-13 .. BR-U3-17)

**BR-U3-13** — `TranscriptRepository.deleteSession()` deletes the session row and all associated segments via `ON DELETE CASCADE`. FTS5 index is updated via the delete trigger.

**BR-U3-14** — `getSessions()` returns sessions ordered by `date` descending (most recent first) by default.

**BR-U3-15** — `search()` performs an FTS5 `MATCH` query. Results are ordered by BM25 relevance (ascending — lower is more relevant in SQLite FTS5). At most 50 sessions are returned. Each result includes up to 3 snippet strings.

**BR-U3-16** — FTS5 uses the `porter unicode61` tokenizer. Search is case-insensitive and applies stemming (e.g., "running" matches "run").

**BR-U3-17** — FTS5 snippet delimiters are `[` (open) and `]` (close). Snippets are extracted at 64-token windows. The UI is responsible for rendering these into highlighted text.

---

## Transcript Export (BR-U3-18 .. BR-U3-21)

**BR-U3-18** — Export timestamps are relative to session start (Q5=A). `startTimeMs = 0` means the segment began at the moment the session started.

**BR-U3-19** — Segments where `text` is empty or whitespace-only are excluded from all export formats.

**BR-U3-20** — SRT export uses `,` as the decimal separator for milliseconds (e.g., `00:00:01,240`). VTT export uses `.` (e.g., `00:00:01.240`). This is a format requirement; the underlying `int` timestamps are the same.

**BR-U3-21** — VTT export includes the `WEBVTT` header line followed by a blank line before the first cue block.

---

## OBS WebSocket (BR-U3-22 .. BR-U3-27)

**BR-U3-22** — `ObsWebSocketTarget` only sends captions when `connectionState == ObsConnected`.

**BR-U3-23** — Only final `SttResult`s (`isFinal == true`) are sent to OBS via `SendStreamCaption`. Interim results are discarded to prevent flickering in OBS.

**BR-U3-24** — OBS reconnection uses exponential backoff starting at 1 second, doubling each attempt to a maximum of 30 seconds per interval.

**BR-U3-25** — Reconnection stops and `ObsError` is emitted when the total elapsed time since the first connection failure reaches 600,000 ms (10 minutes). The user must disable and re-enable OBS output to reset the retry clock.

**BR-U3-26** — The OBS WebSocket password is never written to application logs. Host and port may appear in logs at `INFO` level for connection diagnostics.

**BR-U3-27** — When `disconnect()` is called, the reconnect timer is cancelled, `_enabled` is set to false, and no further reconnection attempts occur.

---

## Browser Source (BR-U3-28 .. BR-U3-32)

**BR-U3-28** — `browserSourcePort` must be in the range 1024–65535 inclusive. Setting a value outside this range via `OutputTargetSettingsProvider.setBrowserSourcePort()` throws `ArgumentError` and does not persist.

**BR-U3-29** — Only one `BrowserSourceServer` instance runs at a time. Calling `start()` on an already-running server is a no-op.

**BR-U3-30** — On SSE client connect, `BrowserSourceServer` immediately sends the most recent caption (if any) so the client does not render a blank page during an active session.

**BR-U3-31** — The browser source HTML page is generated from a Dart template at each HTTP GET `/` request, reflecting current `DisplaySettings` (font family, font size). Changes to display settings take effect on the next page reload.

**BR-U3-32** — SSE payload uses minimal JSON format: `{"type":"sttResult","text":"...","isFinal":true|false}` for caption events and `{"type":"sessionState","state":"stopped"}` for session lifecycle events.

---

## Caption Overlay (BR-U3-33 .. BR-U3-35)

**BR-U3-33** — `CaptionOverlayTarget.show()` creates a frameless, always-on-top platform window using `desktop_multi_window`. On mobile and web, `show()` is a no-op.

**BR-U3-34** — Only one overlay window is managed per `CaptionOverlayTarget` instance. Calling `show()` when already visible updates the window configuration (opacity, position) rather than creating a second window.

**BR-U3-35** — When `hide()` or `dispose()` is called, the overlay window is closed and its resources are released. `isVisible` returns `false` after `hide()`.

---

## Security (BR-U3-36 .. BR-U3-37)

**BR-U3-36** — Transcript text (`SttResult.text`, `TranscriptSegment.text`, `CaptionDisplayEntry.text`) is never written to logs, telemetry, or analytics in any Unit 3 component. This extends SECURITY-03 from Unit 1 and Unit 2 to all output target components.

**BR-U3-37** — `ObsSettings.password` is never included in logs. `ObsSettingsNotifier` must not log the full `ObsSettings` state object.
