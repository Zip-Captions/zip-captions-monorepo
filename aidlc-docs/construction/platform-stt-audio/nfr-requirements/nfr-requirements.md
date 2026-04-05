# NFR Requirements — Unit 2: Platform STT + Audio

## 1. Performance

### PERF-U2.1: STT Pipeline End-to-End Latency ≤ 500ms

The end-to-end path from microphone audio being captured to an interim `SttResult` arriving at the `CaptionBus` must complete within **500ms** under normal operating conditions.

**Path**: microphone → `record` audio stream → PCM chunk → STT engine decode → `SttResult` → `handleSttResult` → `CaptionBus.publish`

**Chunk sizing implication**: At 16kHz PCM16, 200–400ms chunks = 6,400–12,800 bytes per chunk. This is the standard Sherpa-ONNX streaming window and keeps the audio buffer within the latency budget.

**Verification**: Latency measured in integration tests using timestamped synthetic audio fixtures. The measurement point is from the first byte of the audio chunk fed to the engine to receipt of the first `SttResult` in `handleSttResult`. Not a hard CI gate — a logged warning if exceeded.

**Not applicable to `PlatformSttEngine`**: Platform STT latency is OS-controlled and is not testable in isolation. The budget applies to `SherpaOnnxSttEngine` and the in-process pipeline only.

### PERF-U2.2: CaptionBus Throughput (inherited from Unit 1)

Unchanged: 20 events/second sustained for single-input captioning. Unit 2 does not introduce multi-input (deferred to Unit 6).

### PERF-U2.3: Catalog Fetch Timeout

The catalog fetch (`SherpaModelManager.catalogModels()`) must time out after **10 seconds** with no response. On timeout, the cached catalog is returned (stale-while-revalidate). If no cache exists, an empty list is returned.

**dio configuration**: `connectTimeout: Duration(seconds: 10)`, `receiveTimeout: Duration(seconds: 10)`.

---

## 2. Reliability

### REL-U2.1: Engine Crash Recovery — One Automatic Restart (Q7=B)

If the active STT engine throws an unhandled exception during a captioning session:

1. `SttSessionManager` catches the exception and attempts **one** automatic restart:
   - Re-calls `initialize()` + `startListening()` with the same `localeId` and `onResult` callback
   - The `sessionId` is **preserved** across the restart (session continuity)
2. During the restart attempt, `RecordingStateNotifier` emits a transient reconnecting indicator (mechanism defined in NFR Design)
3. If the restart **succeeds**: captioning resumes transparently. No `_lastError` is set.
4. If the restart **fails**: transitions to `stopped`, sets `_lastError = RecordingErrorFactories.engineStartFailed()`, requires manual restart.

**Verification**: Unit test with a mock engine that throws on the first `startListening()` call and succeeds on the second.

### REL-U2.2: Model Download Resume (Q6=C)

Download resume behaviour is adaptive:

1. On download interruption (network drop, cancellation, app termination), the partial file is retained on disk.
2. On next `startDownload(modelId)` call, `SherpaModelManager` inspects the partial file size and sends `Range: bytes={partialSize}-` in the HTTP request.
3. If the server responds with `206 Partial Content`: download resumes from the byte offset.
4. If the server responds with `200 OK` (does not support `Accept-Ranges`): the partial file is deleted and the download restarts from byte 0.
5. If the server responds with any error: the partial file is retained and the error is surfaced via `SherpaModelCatalogNotifier.lastFailedDownloadId`.

**CDN requirement**: The CDN serving model archives must support `Accept-Ranges: bytes`.

**Verification**: dio mock test with 206 response; separate test with 200 response (fallback).

### REL-U2.3: Catalog Availability (Stale-While-Revalidate)

`SherpaModelManager.catalogModels()` must never throw to the caller on network failure. It returns the locally cached catalog (potentially stale) or an empty list. The UI is responsible for surfacing staleness if relevant.

**Cache freshness window**: 24 hours from `cachedAt` timestamp.

**Verification**: Test with network unavailable (dio mock throwing `DioException`) — assert cached data is returned without error.

### REL-U2.4: Model Archive Integrity

After a model archive download completes, `SherpaModelManager` must verify the downloaded file's SHA-256 checksum against `SherpaModelCatalogEntry.sha256Checksum` before extraction. If the checksum does not match:
- The partial/corrupt file is deleted
- `lastFailedDownloadId` is set on `SherpaModelCatalogNotifier`
- The model remains `isDownloaded: false`

**Verification**: Test with a fixture archive whose checksum deliberately does not match.

---

## 3. Security

### SEC-U2.1: No Transcript Text in Logs — All Unit 2 Components (SECURITY-03)

Extends SR-01 from Unit 1. All new components in Unit 2 that handle audio data or `SttResult` objects must never log transcript text:

- `PlatformSttEngine` — `onResult` callback
- `SherpaOnnxSttEngine` — `OnlineRecognizer.getResult()` output
- `SttSessionManager` — passes `onResult` through; must not inspect or log its contents
- `AudioDeviceService` — logs device IDs only (not audio content)
- `SherpaModelManager` — logs model IDs, byte counts; never audio or transcript content

**Permitted in logs**: engine ID, model ID, locale ID, device ID, session ID, error type, byte counts, download progress percentage.

### SEC-U2.2: HTTPS Enforced for All Network Requests

All HTTP requests (catalog fetch, model archive download) must use HTTPS. The `dio` instance is configured to reject HTTP URLs. `downloadUrl` values from the catalog that do not begin with `https://` are rejected before the request is initiated — the model entry is skipped with a logged warning.

### SEC-U2.3: No Certificate Pinning (Q8=A)

Standard OS certificate chain validation is used for all HTTPS connections. No additional pinning is applied. This avoids operational burden when certificates rotate and is sufficient given the model archives are integrity-verified via SHA-256 post-download.

### SEC-U2.4: Catalog URL Is a Compile-Time Constant

The catalog endpoint URL is defined as a Dart constant (e.g., in `lib/src/constants/catalog_constants.dart`). It is not constructed from user input, not configurable at runtime, and not sourced from the catalog response itself. `downloadUrl` values in the catalog are validated to match the expected CDN domain before use.

### SEC-U2.5: No Background Captioning (Q9=B — Consent Constraint)

The app must not capture or transcribe audio while the screen is off or the app is backgrounded. This is a **consent and visibility requirement**: users being captioned must be able to see that captioning is active.

- No `audio` background mode in `Info.plist`
- No background audio session configuration on any platform
- `WakeLockService` keeps the screen on during captioning as a reinforcing measure
- If the OS suspends the app (e.g., incoming phone call), the captioning session transitions to `stopped` via `SttSessionManager` engine exception handling (REL-U2.1)

---

## 4. Usability

### USA-U2.1: Large Download Confirmation (Q5=B)

When `SherpaModelCatalogNotifier.startDownload(modelId)` is called for a model whose `downloadSizeBytes > 100MB`, the download does not begin immediately. The notifier emits a `pendingConfirmation` state for that model. The UI must display a confirmation dialog showing the download size. Only after explicit user confirmation does `startDownload` proceed.

**Threshold**: 100MB (`100 * 1024 * 1024` bytes). This is a constant in `SherpaModelManager`; not user-configurable in Phase 1.

**Below threshold**: Download begins immediately upon `startDownload()` — no confirmation required.

### USA-U2.2: Engine Restart Indicator (Q7=B)

During the automatic engine restart attempt (REL-U2.1), the UI must show a non-blocking "Reconnecting..." indicator. The mechanism (e.g., a transient `reconnecting` field on `SttSessionManager` provider state) is defined in NFR Design.

### USA-U2.3: Permission Error Messaging

When `_lastError` is `permissionDenied`, the UI shows: "Microphone access denied." with a "Try Again" affordance (tapping Start re-runs `initialize()`).

When `_lastError` is `permissionPermanentlyDenied`, the UI shows: "Microphone access is blocked. Enable it in system Settings." with an "Open Settings" button that calls `RecordingStateNotifier.openMicrophoneSettings()`.

---

## 5. Testing

### TEST-U2.1: PlatformSttEngine — Mocked SpeechToText (Q12=B)

`PlatformSttEngine` is unit-tested by injecting a mock `SpeechToText` instance. The mock is created with `mocktail`. Tests cover: `initialize()` → success/failure, `startListening()` → result delivery, `pause()`/`resume()` → stop+restart sequence, `stopListening()`.

No real speech recognition runs in CI.

### TEST-U2.2: SherpaOnnxSttEngine — Mocked OnlineRecognizer (Q12=B)

`SherpaOnnxSttEngine` is unit-tested by injecting a mock wrapper around the `sherpa_onnx` `OnlineRecognizer`. Because `OnlineRecognizer` is a native class, a thin `OnlineRecognizerAdapter` interface is introduced in production code to allow mocking. Tests cover: `isAvailable()` (models present/absent), `initialize()` (model load success/failure), feed/decode loop, `pause()`/`resume()`, `dispose()`.

### TEST-U2.3: PCM16 Audio Fixtures (Q11=B)

Three fixture files are added to `test/fixtures/audio/`:

| File | Content | Duration | Purpose |
|------|---------|----------|---------|
| `silence_16k.pcm` | Zero-filled PCM16 at 16kHz | 2s | Tests that engine handles silence without crashing |
| `tone_440hz_16k.pcm` | 440Hz sine wave, PCM16 at 16kHz | 2s | Tests that engine processes non-speech audio without error |
| `speech_en_16k.pcm` | Pre-recorded English speech, PCM16 at 16kHz | 5s | Used in integration fixture tests to assert at least one result is emitted |

Tests using these fixtures assert engine lifecycle properties (no crash, correct state transitions), not speech recognition accuracy.

### TEST-U2.4: SttSessionManager Integration

`SttSessionManager` is tested with a `MockSttEngine` (from Unit 1). Tests cover: full lifecycle (initialize → startListening → pause → resume → stop → dispose), permission denial at each status variant, engine crash + auto-restart (one success, one failure), locale fallback path.

### TEST-U2.5: SherpaModelManager — dio Mock + Fixture Archive

`SherpaModelManager` download tests use a `DioAdapter` (from `http_mock_adapter` or equivalent) to simulate:
- Successful download with correct sha256 → extraction verified
- Interrupted download + 206 resume
- Interrupted download + 200 restart fallback
- Checksum mismatch → model not marked downloaded
- Network error → cached catalog returned

A minimal valid `.tar.bz2` fixture (a single-file archive) is included in `test/fixtures/` for extraction tests.

### TEST-U2.6: Coverage Target

Unit 2 targets ≥ 90% line coverage on new zip_core code. `SherpaOnnxSttEngine` native adapter seams (`OnlineRecognizerAdapter`) are excluded from coverage measurement.

---

## 6. Maintainability

### MAINT-U2.1: Engine Registration Is App-Layer Responsibility

Engines (`PlatformSttEngine`, `SherpaOnnxSttEngine`) are registered into `SttEngineRegistry` at app startup (in `main.dart` or an app-level provider override), not inside `zip_core` providers. This keeps `zip_core` free of app-specific startup logic.

### MAINT-U2.2: Logger Naming Convention (Inherited)

All new Unit 2 components use the `logging` package with the `'zip_core.{ComponentName}'` naming convention established in Unit 1. Example: `'zip_core.SttSessionManager'`, `'zip_core.SherpaModelManager'`.

---

## 7. Availability

### AVAIL-U2.1: Static JSON Catalog (Q10=C)

The model catalog is a static JSON file hosted on a CDN. There is no server-side computation. The file is manually maintained and deployed when models are added or removed. A dynamic proxy (auto-syncing from HuggingFace or similar) is deferred to Phase 2.

**Implication**: The CDN URL and catalog JSON format must be stable across app versions. Adding new models to the catalog is a non-breaking change (new entries). Removing models or changing existing `modelId` values is a breaking change requiring a coordinated app update.

### AVAIL-U2.2: Offline Operation After Initial Download

Once at least one model is downloaded, `SherpaOnnxSttEngine` operates fully offline. `PlatformSttEngine` on some locales may require network (OS-managed); this is outside app control and is not a reliability guarantee made by Unit 2.

The app does not require network connectivity to caption if models are already downloaded.
