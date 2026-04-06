# Tech Stack Decisions — Unit 3: Output Targets

## Confirmed from Functional Design

These packages were selected during FD (Q6=A, Q11=A, Q12=A) and are confirmed with no changes.

| Package | Version constraint | Purpose | Package location |
|---------|--------------------|---------|-----------------|
| `drift` + `drift_flutter` | `^2.x` | SQLite ORM + FTS5 virtual table | `zip_core` |
| `obs_websocket` | pub.dev latest stable | OBS WebSocket v5 protocol client | `zip_broadcast` |
| `shelf` + `shelf_router` | pub.dev latest stable | HTTP + SSE server for browser source | `zip_broadcast` |
| `flutter_secure_storage` | `^9.x` | OBS WebSocket password storage | `zip_broadcast` |
| `desktop_multi_window` | pub.dev latest stable | Caption overlay platform window (desktop only) | `zip_broadcast` |

---

## New Decisions from NFR Assessment

### uuid — Token Generation for BrowserSourceServer (SEC-U3.3)

`BrowserSourceServer` generates a one-time UUID token at start using the `uuid` package (`Uuid().v4()`). The `uuid` package is already a common Flutter dependency; if it is not already in `pubspec.yaml` for `zip_broadcast`, it must be added.

**Package**: `uuid` (pub.dev)
**Location**: `zip_broadcast`

---

### DesktopWindowService Abstraction (TEST-U3.2)

A new abstract class `DesktopWindowService` is introduced in `zip_broadcast` to wrap `desktop_multi_window` platform channel calls. This enables `CaptionOverlayTarget` to be unit-tested with `MockDesktopWindowService` (mocktail).

**Not a new package** — this is a new interface in `zip_broadcast/lib/src/output/overlay/desktop_window_service.dart`.

The production implementation `DesktopMultiWindowService` lives alongside it in the same directory.

---

### fake_async — Timer Control in Tests (TEST-U3.4)

`fake_async` is used to control `Timer`-based behaviour in tests for:
- `TranscriptWriterTarget` merge-window (2s boundary behaviour)
- `ObsWebSocketTarget` exponential backoff schedule and 10-minute timeout

**Package**: `fake_async` (test dependency only)
**Location**: `zip_broadcast` dev dependencies (and `zip_core` dev dependencies if merge-window tests live there)

---

## Package Placement Summary

### zip_core (shared library)

| Package | Type | Reason |
|---------|------|--------|
| `drift` | dependency | `TranscriptDatabase`, `TranscriptRepository` |
| `drift_flutter` | dependency | Platform SQLite bindings |

### zip_broadcast (broadcaster app)

| Package | Type | Reason |
|---------|------|--------|
| `obs_websocket` | dependency | `ObsWebSocketTarget` |
| `shelf` | dependency | `BrowserSourceServer` |
| `shelf_router` | dependency | Route dispatch in `BrowserSourceServer` |
| `flutter_secure_storage` | dependency | OBS password via `ObsSettingsNotifier` |
| `desktop_multi_window` | dependency | `DesktopMultiWindowService` (overlay window) |
| `uuid` | dependency | SSE token generation |
| `fake_async` | dev_dependency | Timer-based tests |

### zip_captions (personal user app)

No new packages for Unit 3. `zip_captions` uses `zip_core`'s `TranscriptRepository` and `OnScreenCaptionTarget` transitively; no broadcast-specific output targets apply.

---

## Packages Explicitly Not Used

| Package | Rationale |
|---------|-----------|
| `sqflite` | Replaced by `drift` (provides FTS5, type-safe queries, code generation, migration scaffolding) |
| `hive` / `isar` | Insufficient FTS5 support; drift is the approved ORM per the tech spec |
| `web_socket_channel` | `obs_websocket` wraps the OBS protocol; raw WebSocket channel not needed |
| `express` / `dart_frog` | `shelf` is the approved HTTP framework per the tech spec |
