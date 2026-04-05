# Tech Stack Decisions — Unit 1: Core Abstractions

## New Dependencies

### uuid (runtime)

| Attribute | Detail |
|-----------|--------|
| **Package** | `uuid` |
| **Purpose** | Generate UUID v4 session IDs in RecordingStateNotifier |
| **Version** | Latest stable (^4.x) |
| **Target** | zip_core `dependencies` |
| **Rationale** | Standard, well-maintained (1000+ pub points). Used for a single purpose: `Uuid().v4()` to generate sessionId on recording start. Preferable to a hand-rolled alternative for correctness and collision resistance |

### logging (runtime)

| Attribute | Detail |
|-----------|--------|
| **Package** | `logging` |
| **Purpose** | Structured logging with named loggers and log levels |
| **Version** | Latest stable (^1.x) |
| **Target** | zip_core `dependencies` |
| **Rationale** | Replaces `dart:developer` `log()` for better filtering, named loggers per component, and structured output. Maintained by the Dart team. Minimal footprint |

**Migration plan**: New Unit 1 code uses `logging`. Modified Phase 0 files (BaseSettingsNotifier, RecordingStateNotifier) are migrated from `dart:developer` to `logging`. Unmodified Phase 0 files retain `dart:developer` and can be migrated opportunistically.

**Logger naming convention**: `'zip_core.{ComponentName}'` (e.g., `'zip_core.CaptionOutputTargetRegistry'`, `'zip_core.BaseSettingsNotifier'`).

### glados (dev)

| Attribute | Detail |
|-----------|--------|
| **Package** | `glados` |
| **Purpose** | Property-based testing framework with generators and shrinking |
| **Version** | Latest stable |
| **Target** | zip_core `dev_dependencies` |
| **Rationale** | Provides `Arbitrary<T>` generators, automatic shrinking to minimal counterexamples, and a clean `Glados<T>().test()` API. Preferred over custom `dart:math` generators for shrinking support and over `fast_check` for simpler API and better Dart idiom fit |

**Usage pattern**:
```dart
// Custom generator for SttResult
final arbitrarySttResult = Arbitrary.combine2(
  Arbitrary.string, // text
  Arbitrary.bool,   // isFinal
  (text, isFinal) => SttResult(
    text: text,
    isFinal: isFinal,
    confidence: 1.0,
    timestamp: DateTime.now(),
    sourceId: 'test',
  ),
);

Glados(arbitrarySttResult).test('confidence is always in range', (result) {
  expect(result.confidence, inInclusiveRange(0.0, 1.0));
});
```

---

## Existing Dependencies (Unchanged)

| Package | Usage in Unit 1 |
|---------|----------------|
| `freezed` / `freezed_annotation` | SttResult, AudioInputConfig, AudioInputVisualStyle, DisplaySettings (rename) |
| `riverpod` / `riverpod_annotation` | SttEngineRegistryProvider, CaptionBusProvider, CaptionOutputTargetRegistryProvider, TranscriptSettingsNotifier, RecordingStateNotifier |
| `shared_preferences` | BaseSettingsNotifier (DisplaySettings persistence), TranscriptSettingsNotifier |
| `build_runner` / `riverpod_generator` | Code generation for providers and freezed models |

---

## Decisions Not Made in Unit 1

| Decision | Deferred To | Rationale |
|----------|-------------|-----------|
| `speech_to_text` package version | Unit 2 | PlatformSttEngine implementation |
| `sherpa_onnx` package version | Unit 2 | SherpaOnnxSttEngine implementation |
| `drift` (SQLite ORM) | Unit 3 | Transcript database |
| `shelf` (HTTP server) | Unit 3 | Browser source server |
| `web_socket_channel` | Unit 3 | OBS WebSocket target |
| `wakelock_plus` | Unit 2 | Screen wake lock |
