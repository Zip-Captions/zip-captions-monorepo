# Domain Entities — Unit 3: Output Targets

## New Models

### CaptionDisplayEntry (freezed)

A single rendered caption entry held in the `OnScreenCaptionTarget` buffer. Carries the `sourceId` for widget-layer style lookup (Q2=B — styling is not the target's responsibility).

```dart
@freezed
class CaptionDisplayEntry with _$CaptionDisplayEntry {
  const factory CaptionDisplayEntry({
    required String entryId,
    required String sessionId,
    required String text,
    required bool isFinal,
    required String sourceId,
    required DateTime timestamp,
  }) = _CaptionDisplayEntry;
}
```

| Field | Type | Constraints | Purpose |
|-------|------|-------------|---------|
| `entryId` | `String` | UUID, non-empty | Unique entry identifier |
| `sessionId` | `String` | Non-empty | Session this entry belongs to |
| `text` | `String` | May be empty for interim; non-empty for final | Caption text |
| `isFinal` | `bool` | — | `true` = committed utterance; `false` = in-progress interim |
| `sourceId` | `String` | Non-empty | Input source; widget layer maps this to `AudioInputVisualStyle` |
| `timestamp` | `DateTime` | UTC | When the result was recognized |

**Widget-layer style resolution**: The widget reads `AudioInputConfig` from `AudioInputSettingsProvider` and matches `entry.sourceId` to `AudioInputConfig.inputId` to obtain the `AudioInputVisualStyle`. `OnScreenCaptionTarget` never performs this lookup.

---

### ExportFormat (enum)

```dart
enum ExportFormat {
  txt,
  srt,
  vtt,
}
```

| Value | Description |
|-------|-------------|
| `txt` | Plain text, one line per segment, no timestamps |
| `srt` | SubRip subtitle format with relative timestamps |
| `vtt` | WebVTT subtitle format with relative timestamps |

---

### TranscriptSession (freezed + JSON)

Persisted session metadata. Does not contain segment text.

```dart
@freezed
class TranscriptSession with _$TranscriptSession {
  const factory TranscriptSession({
    required String sessionId,
    required DateTime date,
    String? title,
    required int durationMs,
    required int segmentCount,
  }) = _TranscriptSession;

  factory TranscriptSession.fromJson(Map<String, dynamic> json) =>
      _$TranscriptSessionFromJson(json);
}
```

| Field | Type | Constraints | Purpose |
|-------|------|-------------|---------|
| `sessionId` | `String` | UUID, non-empty | Primary key |
| `date` | `DateTime` | UTC | Session start time |
| `title` | `String?` | Null until derived from first segment | Auto-derived display title |
| `durationMs` | `int` | >= 0 | Session duration in milliseconds |
| `segmentCount` | `int` | >= 0 | Number of committed final segments |

**Title derivation**: `title` is set to the first 50 characters of the first final segment's text, trimmed. Updated by `TranscriptRepository.saveSession()` at flush time if still null.

---

### TranscriptSegment (freezed + JSON)

A single persisted speech segment from one final result (or merged final results — see BR-U3-06).

```dart
@freezed
class TranscriptSegment with _$TranscriptSegment {
  const factory TranscriptSegment({
    required String segmentId,
    required String sessionId,
    required String text,
    required String sourceId,
    required int startTimeMs,
    required int endTimeMs,
  }) = _TranscriptSegment;

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) =>
      _$TranscriptSegmentFromJson(json);
}
```

| Field | Type | Constraints | Purpose |
|-------|------|-------------|---------|
| `segmentId` | `String` | UUID, non-empty | Primary key |
| `sessionId` | `String` | Non-empty | Foreign key → `TranscriptSession.sessionId` |
| `text` | `String` | Non-empty | Committed speech text (never interim) |
| `sourceId` | `String` | Non-empty | Input source identifier |
| `startTimeMs` | `int` | >= 0, relative to session start | Segment start offset for SRT/VTT export |
| `endTimeMs` | `int` | >= `startTimeMs` | Segment end offset |

**Timestamp basis** (Q5=A): `startTimeMs` and `endTimeMs` are offsets from session start, not wall-clock timestamps. Export functions use these directly to produce `00:00:00,000`-style timestamps.

---

### TranscriptSettings (freezed)

User preference for transcript capture. Persisted via `SharedPreferences`.

```dart
@freezed
class TranscriptSettings with _$TranscriptSettings {
  const factory TranscriptSettings({
    @Default(true) bool captureEnabled,
  }) = _TranscriptSettings;
}
```

---

### ObsSettings (freezed)

In-memory representation of OBS WebSocket connection settings. The `password` field is only ever held in RAM; it is stored to and loaded from `flutter_secure_storage`, never `SharedPreferences` (Q11=A).

```dart
@freezed
class ObsSettings with _$ObsSettings {
  const factory ObsSettings({
    @Default('localhost') String host,
    @Default(4455) int port,
    @Default('') String password,
  }) = _ObsSettings;
}
```

| Field | Type | Default | Persistence |
|-------|------|---------|-------------|
| `host` | `String` | `'localhost'` | `SharedPreferences` key `obs.host` |
| `port` | `int` | `4455` | `SharedPreferences` key `obs.port` |
| `password` | `String` | `''` | `flutter_secure_storage` key `obs.password` |

**Security**: The password is never logged. The `ObsSettingsProvider` loads it from secure storage on build and holds it in `ObsSettings` in RAM only. Logs may record host and port, never password.

---

### ObsConnectionState (sealed class)

The OBS WebSocket connection state machine. Sealed for exhaustive matching in the UI.

```dart
sealed class ObsConnectionState {
  const ObsConnectionState();
}

class ObsDisconnected extends ObsConnectionState {
  const ObsDisconnected();
}

class ObsConnecting extends ObsConnectionState {
  const ObsConnecting();
}

class ObsConnected extends ObsConnectionState {
  const ObsConnected();
}

class ObsReconnecting extends ObsConnectionState {
  const ObsReconnecting({required this.attempt, required this.nextRetryMs});
  final int attempt;
  final int nextRetryMs;
}

class ObsError extends ObsConnectionState {
  const ObsError({required this.message});
  final String message;
}
```

| Variant | Fields | Meaning |
|---------|--------|---------|
| `ObsDisconnected` | — | No active connection; user must enable OBS output to connect |
| `ObsConnecting` | — | Initial connection attempt in progress |
| `ObsConnected` | — | WebSocket established; captions are being sent |
| `ObsReconnecting` | `attempt`, `nextRetryMs` | Connection dropped; waiting for next retry |
| `ObsError` | `message` | Connection gave up (10-minute timeout exhausted) or unrecoverable error |

**State transitions**:

```
disconnected ──(connect called)──> connecting
connecting ──(success)──> connected
connecting ──(failure)──> reconnecting
connected ──(connection dropped)──> reconnecting
reconnecting ──(attempt success)──> connected
reconnecting ──(timeout exhausted)──> error
error ──(user re-enables OBS output)──> connecting
```

---

### OutputTargetSettings (freezed)

Per-target enablement toggles and browser source port. Persisted via `SharedPreferences`.

```dart
@freezed
class OutputTargetSettings with _$OutputTargetSettings {
  const factory OutputTargetSettings({
    @Default(true) bool onScreenEnabled,
    @Default(false) bool obsEnabled,
    @Default(false) bool browserSourceEnabled,
    @Default(false) bool overlayEnabled,
    @Default(8080) int browserSourcePort,
  }) = _OutputTargetSettings;
}
```

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `onScreenEnabled` | `bool` | `true` | On-screen caption rendering active |
| `obsEnabled` | `bool` | `false` | OBS WebSocket output active |
| `browserSourceEnabled` | `bool` | `false` | Browser source server active |
| `overlayEnabled` | `bool` | `false` | Caption overlay window active |
| `browserSourcePort` | `int` | `8080` | HTTP port for browser source server (1024–65535) |

---

### TranscriptSearchResult (freezed)

FTS5 search result including session metadata and a matched text snippet (Q4=C — changes the `TranscriptRepository.search()` return type from `List<TranscriptSession>` to `List<TranscriptSearchResult>`).

```dart
@freezed
class TranscriptSearchResult with _$TranscriptSearchResult {
  const factory TranscriptSearchResult({
    required TranscriptSession session,
    required List<String> snippets,
    required double relevanceScore,
  }) = _TranscriptSearchResult;
}
```

| Field | Type | Purpose |
|-------|------|---------|
| `session` | `TranscriptSession` | The matching session's metadata |
| `snippets` | `List<String>` | Matching excerpt strings from FTS5 `snippet()`, up to 3 per session |
| `relevanceScore` | `double` | BM25 relevance score (lower is more relevant in SQLite FTS5) |

**FTS5 `snippet()` format**: Each snippet is a short excerpt (~64 tokens) with match terms delimited by `[` and `]` (configurable). The UI renders these to highlight matching terms.

---

### OverlayPosition (sealed class)

The desired screen position for the caption overlay window.

```dart
sealed class OverlayPosition {
  const OverlayPosition();
}

class OverlayPositionTop extends OverlayPosition {
  const OverlayPositionTop();
}

class OverlayPositionBottom extends OverlayPosition {
  const OverlayPositionBottom();
}

class OverlayPositionCustom extends OverlayPosition {
  const OverlayPositionCustom({required this.x, required this.y});
  final double x;
  final double y;
}
```

---

### OverlayConfig (freezed)

Configuration for a caption overlay window creation request.

```dart
@freezed
class OverlayConfig with _$OverlayConfig {
  const factory OverlayConfig({
    String? targetDisplayId,
    @Default(OverlayPositionBottom()) OverlayPosition position,
    @Default(0.9) double opacity,
  }) = _OverlayConfig;
}
```

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `targetDisplayId` | `String?` | `null` = primary display | Which display to open the overlay on |
| `position` | `OverlayPosition` | `OverlayPositionBottom` | Where to position the overlay window |
| `opacity` | `double` | `0.9` | Window opacity (0.0–1.0) |

---

## Modified Contracts

### TranscriptRepository.search() — Updated Return Type (Q4=C)

The `search()` method defined in Application Design returns `Future<List<TranscriptSession>>`. Unit 3 changes this to `Future<List<TranscriptSearchResult>>` to include FTS5 snippets and BM25 scores.

```dart
// Before (Application Design spec):
Future<List<TranscriptSession>> search(String query)

// After (Unit 3 FD):
Future<List<TranscriptSearchResult>> search(String query)
```

This is a breaking change to the `TranscriptRepository` interface. It is introduced in Unit 3 before any UI consumer exists, so no migration is needed.
