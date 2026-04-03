# NFR Design Plan — Unit 2: Platform STT + Audio

## Unit Context

**Unit**: Unit 2 — Platform STT + Audio
**Stories**: S-02 (Platform-Native STT), S-06 (Audio Capture)
**NFR Requirements**: Complete (PERF-U2.1–3, REL-U2.1–4, SEC-U2.1–5, USA-U2.1–3, TEST-U2.1–6, MAINT-U2.1–2, AVAIL-U2.1–2)
**Extensions**: Security Baseline (blocking), Property-Based Testing (full enforcement)

## Plan Checklist

- [ ] Step 1: Design engine crash recovery + auto-restart pattern (REL-U2.1, USA-U2.2)
- [ ] Step 2: Design OnlineRecognizerAdapter test seam for SherpaOnnxSttEngine (TEST-U2.2)
- [ ] Step 3: Design PlatformSttEngine mock strategy via SpeechToText injection (TEST-U2.1)
- [ ] Step 4: Design dio mock + download resume pattern (REL-U2.2, TEST-U2.5)
- [ ] Step 5: Design stale-while-revalidate catalog caching pattern (REL-U2.3, PERF-U2.3)
- [ ] Step 6: Design archive integrity verification pattern (REL-U2.4)
- [ ] Step 7: Design large download confirmation flow (USA-U2.1)
- [ ] Step 8: Design WakeLockService and AudioDeviceService test patterns
- [ ] Step 9: Design PBT generators and properties for Unit 2 components
- [ ] Step 10: Generate NFR Design artifacts (nfr-design-patterns.md, logical-components.md)

## Applicability Assessment

| NFR Design Category | Applicable | Rationale |
|--------------------|-----------|-----------|
| Resilience Patterns | Yes | Engine crash recovery with auto-restart; download resume with range requests |
| Scalability Patterns | No | Single-input in Unit 2; multi-input deferred to Unit 6 |
| Performance Patterns | Minimal | Latency budget is a configuration constraint, not a design pattern |
| Security Patterns | Minimal | Logging exclusion inherited from Unit 1; HTTPS enforcement is dio config |
| Logical Components | Yes | Catalog cache storage, dio HTTP client configuration, adapter seams |
| Test Patterns | Yes | Primary focus: engine adapter seams, dio mocking, PBT generators, fixture strategy |

---

## Questions

Please answer each question by filling in the letter (or free text) after `[Answer]:`

---

## Question 1
**OnlineRecognizerAdapter — wrapper scope**

TEST-U2.2 requires a thin `OnlineRecognizerAdapter` interface to mock the native `OnlineRecognizer`. How much of the Sherpa-ONNX API surface should the adapter expose?

A) Minimal — only the methods called by `SherpaOnnxSttEngine`: `createStream()`, `acceptWaveform()`, `isReady()`, `decode()`, `getResult()`, `reset()`. The adapter is a one-to-one pass-through for these calls. `SherpaOnnxSttEngine` owns the feed/decode loop logic.

B) Higher-level — the adapter encapsulates the entire feed/decode loop and exposes only `feedAudio(Uint8List chunk)` → `Stream<String>`. This moves more logic behind the seam, making the mock simpler but the adapter harder to test.

C) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 2
**Reconnecting indicator mechanism (USA-U2.2)**

During the one-attempt auto-restart (REL-U2.1), the UI needs a "Reconnecting..." indicator. How should this transient state be surfaced?

A) A `bool isReconnecting` field on `SttSessionManager` — set to `true` before the restart attempt, `false` after success or failure. `RecordingStateNotifier` watches this (via explicit read in `onError`) and exposes it on its own state. The `RecordingState` remains `recording` throughout.

B) A new `RecordingState.reconnecting(sessionId:)` variant — the state machine transitions from `recording` → `reconnecting` → `recording` (on success) or `reconnecting` → `stopped` (on failure). This integrates naturally with the state machine.

C) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 3
**Catalog cache storage mechanism**

REL-U2.3 requires stale-while-revalidate catalog caching with a 24-hour freshness window. Where should the cached catalog JSON be persisted?

A) SharedPreferences — store the serialized JSON string under a key (e.g., `catalog.json`) with a `catalog.cachedAt` timestamp. Simple; consistent with other settings storage. May hit size limits if the catalog grows very large.

B) File on disk — write the raw JSON to `_storageDir/catalog_cache.json` with a sibling `catalog_cache_meta.json` (containing `cachedAt`, `etag`, `lastModified`). More scalable; keeps SharedPreferences lean.

C) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 4
**dio test adapter**

TEST-U2.5 requires mocking dio for download and catalog tests. Which approach?

A) `http_mock_adapter` package — mature, purpose-built for dio. Provides `DioAdapter` with route matching and response queuing. Supports simulating 206 partial responses.

B) Custom `Interceptor` subclass — a test-only dio interceptor that intercepts requests and returns canned responses. No additional dependency; slightly more boilerplate.

C) Abstract `HttpService` wrapper — wrap all dio calls behind an interface; mock the interface. More indirection but fully decouples from dio.

D) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 5
**WakeLockService test seam**

`WakeLockService` wraps `wakelock_plus`, which is a platform plugin. How should it be tested?

A) Abstract `WakeLockService` as an interface — production code uses `WakelockPlusService implements WakeLockService`; tests use a `MockWakeLockService` (mocktail). `RecordingStateNotifier` receives it via dependency injection (provider).

B) `WakeLockService` remains a concrete class but accepts a `WakelockPlus` instance in its constructor. Tests inject a mock `WakelockPlus` (using mocktail).

C) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 6
**PBT scope for Unit 2**

Unit 1 established PBT with glados for core domain types. Unit 2 introduces network-dependent and platform-dependent components. What is the PBT scope?

A) PBT for domain types only — new `Arbitrary` generators for `AudioDevice`, `SherpaModelCatalogEntry`, `SherpaModelInfo`, `WakeLockSettings`, `SherpaModelDownloadProgress`. Property tests assert serialisation round-trips, invariant relationships (e.g., `isDownloaded` implies `localPath != null`). No PBT for service-layer behaviour.

B) PBT for domain types + state machine extensions — in addition to (A), extend `ArbitraryTransitionSequence` with new transitions (`reconnect`, `engineSwitch`) and test `RecordingStateNotifier` state machine properties with the expanded set.

C) Minimal PBT — only the domain type generators for consistency with Unit 1. No new property tests; effort focused on example-based tests for services.

D) Other (please describe after [Answer]: tag below)

[Answer]: B

---
