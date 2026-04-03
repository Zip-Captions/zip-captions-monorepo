# NFR Requirements Plan — Unit 2: Platform STT + Audio

## Unit Context

**Unit**: Unit 2 — Platform STT + Audio
**Stories**: S-02 (Platform-Native STT), S-06 (Audio Capture)
**Packages**: zip_core, zip_broadcast
**Functional Design**: Complete (domain-entities, business-logic-model, business-rules)
**Extensions**: Security Baseline (blocking), Property-Based Testing (full enforcement)

## Plan Checklist

- [x] Step 1: Assess tech stack — audio device enumeration package (Q2=D deferred)
- [x] Step 2: Assess tech stack — HTTP client for catalog fetch
- [x] Step 3: Assess tech stack — model archive format and extraction library
- [x] Step 4: Assess performance — STT audio pipeline latency
- [x] Step 5: Assess performance — model download UX and storage constraints
- [x] Step 6: Assess reliability — engine failure recovery and download resume
- [x] Step 7: Assess security — catalog endpoint pinning and model integrity
- [x] Step 8: Assess platform scope — iOS background audio session
- [x] Step 9: Assess catalog endpoint — hosting and build scope
- [x] Step 10: Assess testing strategy — STT engine mocking and audio PBT generators
- [x] Step 11: Generate NFR Requirements artifacts

## Applicability Assessment

| NFR Category | Applicable | Rationale |
|-------------|-----------|-----------|
| Performance | Yes | STT pipeline latency; model download throughput |
| Scalability | Partial | Single-input in Unit 2; multi-input deferred to Unit 6 |
| Availability | Partial | Catalog endpoint availability; offline fallback behaviour |
| Security | Yes | SECURITY-03; model archive integrity; catalog HTTPS |
| Reliability | Yes | Engine crash recovery; download interruption handling |
| Testing | Yes | PBT generators for audio streams; STT engine mock strategy |
| Maintainability | Yes | Package version pinning; engine registration lifecycle |
| Usability | Partial | Permission prompt UX; download progress UX |

---

## Questions

Please answer each question by filling in the letter (or free text) after `[Answer]:`.

---

## Question 1
**Audio device enumeration package (Q2=D)**

The Functional Design specified a package that can both enumerate audio input devices and set the preferred input device. Three viable options exist for Flutter desktop/mobile:

A) `record` package — exposes `listInputDevices()` on desktop and provides an `AudioRecorder` that honours device selection. Already designed for streaming audio capture. Would replace the need for a custom platform channel for device routing.

B) `flutter_sound` package — cross-platform audio with device enumeration. More feature-heavy than needed; licence is LGPL.

C) Custom platform channel in zip_core — `MethodChannel` per platform (AVAudioSession/WASAPI/PulseAudio/AudioManager). Maximum control; no third-party dependency; significant implementation cost.

D) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 2
**HTTP client for catalog fetch and model download**

The catalog fetch and model archive download both require HTTP. Two well-maintained options exist in the Flutter ecosystem:

A) `http` package — lightweight, Dart team maintained. Suitable for catalog fetch; streaming download requires manual chunk handling with `http.Client.send()`.

B) `dio` package — feature-rich HTTP client with built-in download progress streaming, interceptors, and cancellation tokens. More ergonomic for the download stream (`SherpaModelDownloadProgress`) and cancel (`cancelDownload`) use cases.

C) `dart:io` `HttpClient` directly — no dependency; lower-level; sufficient for both use cases but more boilerplate.

D) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 3
**Model archive format and extraction library**

Sherpa-ONNX model releases are typically distributed as `.tar.bz2` archives. Flutter/Dart has limited built-in support for archive extraction. Options:

A) `.tar.bz2` — matches upstream Sherpa-ONNX distribution format. Requires `archive` package (pure Dart, supports tar+bz2). One extraction step; files placed directly into `_storageDir/{modelId}/`.

B) `.zip` — simpler extraction with `archive` package (zip is first-class). Requires re-packaging upstream models as zip on the CDN; adds a CDN build step but simplifies the app-side code.

C) Pre-extracted flat directory served as a zip of just the model files — avoids nested archive handling entirely. CDN hosts a flat zip of only the required model files (no build scripts, no extras).

D) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 4
**STT audio pipeline latency target**

The time from a user speaking to a caption appearing in the UI involves: microphone → audio buffer → STT engine → `SttResult` → `handleSttResult` → `CaptionBus` → UI rebuild. What end-to-end latency is acceptable for interim results?

A) ≤ 500ms — comfortable for live captioning; allows for audio buffering of 200–400ms chunks which is standard for Sherpa-ONNX streaming.

B) ≤ 250ms — tighter target; requires smaller audio chunk sizes (50–100ms) which increases CPU load on the Sherpa-ONNX decode loop.

C) ≤ 1000ms — relaxed; acceptable for non-real-time use cases (e.g., lecture capture) where slight delay is tolerable.

D) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 5
**Model storage: size limit and pre-download warning**

Sherpa-ONNX streaming models range from ~20MB (small English) to ~300MB (large multilingual). Should the app enforce a storage limit or warn the user before initiating a large download?

A) No storage limit enforced; warn the user of download size (already shown via `downloadSizeBytes`) but do not block. Trust the OS to manage storage pressure.

B) Warn and require confirmation when a single model download exceeds a threshold (e.g., 100MB). Below the threshold, download starts immediately.

C) Enforce a soft cap on total model storage (e.g., 2GB across all downloaded models). Warn when approaching the cap; block new downloads when exceeded until the user deletes a model.

D) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 6
**Model download: resume on network interruption**

If a model download is interrupted (network drop, app backgrounded), should the download resume from where it left off or restart?

A) Resume using HTTP `Range` requests — send `Range: bytes=N-` on retry. The CDN must support `Accept-Ranges`. Requires tracking the partially-downloaded file size on disk. Significantly better UX for large models.

B) Restart — simpler implementation; delete any partial file and re-download from byte 0. Acceptable if models are small (< 50MB) or the CDN does not support range requests.

C) Resume if the CDN supports it (detected via `Accept-Ranges` response header); fall back to restart if not supported.

D) Other (please describe after [Answer]: tag below)

[Answer]: C

---

## Question 7
**STT engine crash recovery during an active session**

If the STT engine throws an unhandled exception during an active captioning session (e.g., Sherpa-ONNX native crash, audio session interrupted by a phone call), how should the app recover?

A) Transition to `stopped` state, set `_lastError = RecordingErrorFactories.engineStartFailed()`, require the user to restart manually. Simple; no silent retry.

B) Attempt one automatic restart: re-call `SttSessionManager.initialize()` + `startListening()` preserving the same `sessionId`. If the restart fails, transition to `stopped` and set `_lastError`. Surface a transient "Reconnecting..." indicator during the retry.

C) Log the error and keep the session in `recording` state silently — results simply stop arriving. The user sees captions freeze but no explicit error. UI recovers when the engine recovers.

D) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 8
**Certificate pinning for catalog and download endpoints**

The catalog endpoint and model `downloadUrl` values are served over HTTPS. Should the app additionally pin the TLS certificate or public key?

A) No pinning — standard OS certificate validation is sufficient. Simpler to maintain; avoids breaking the app when certificates rotate.

B) Pin the catalog endpoint's certificate (or SPKI hash) — provides defence against compromised CAs at the cost of maintenance overhead when the certificate rotates.

C) Pin only the root CA (not the leaf certificate) — more stable than leaf pinning; still provides protection against rogue intermediate CAs.

D) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 9
**iOS background audio session**

S-06 (Audio Capture) may require the app to continue capturing audio when the screen locks or the app moves to background (e.g., user is captioning a lecture and locks their phone). Does Unit 2 need to configure an iOS background audio session (`AVAudioSession` with background modes)?

A) Yes — configure `audio` background mode in `Info.plist` and set `AVAudioSession.setCategory(.record, options: .allowBluetooth)`. Required for continuous captioning while backgrounded.

B) No — Unit 2 targets foreground captioning only. Background audio is a future enhancement (post-Phase 1). The app may pause when backgrounded; this is acceptable.

C) Yes for iOS, but only for the `zip_captions` app — `zip_broadcast` is a desktop-only app and does not require this.

D) Other (please describe after [Answer]: tag below)

[Answer]: B - background captioning cannot allow for any device to be used to caption without a visual representation, as this may violate consent if used maliciously. Thus, screen must be on during captioning

---

## Question 10
**Catalog endpoint: hosting scope and build responsibility**

The Functional Design specifies an app-operated catalog endpoint that proxies/aggregates from an upstream source (e.g., HuggingFace). Is building and hosting this endpoint in scope for Phase 1?

A) Yes — build the catalog endpoint as part of Phase 1 (Unit 2 or a later unit). It is a required dependency for `SherpaModelCatalogNotifier` to function. Define the tech stack (e.g., Supabase Edge Function, simple static JSON on CDN, Cloud Function).

B) No — the catalog endpoint is out of scope for Phase 1. Unit 2 uses a bundled/hardcoded fallback catalog list for now. The remote fetch is implemented when the endpoint exists (Phase 2 or ops work).

C) Partial — build a static JSON file hosted on a CDN as the catalog in Phase 1 (no server-side proxy logic). The static file is manually updated when models change. A dynamic proxy (HuggingFace aggregation) is deferred to Phase 2.

D) Other (please describe after [Answer]: tag below)

[Answer]: C

---

## Question 11
**PBT: audio chunk stream generators**

Unit 2's Sherpa-ONNX engine integration requires testing the audio feed/decode loop with synthetic PCM audio data. The established PBT library is `glados`. How should audio chunk generators be structured?

A) `Arbitrary<Uint8List>` generator producing random PCM16 chunks of varying sizes (50–400ms at 16kHz = 1600–12800 bytes). Tests assert that the engine processes all chunks without error and emits at least one `SttResult` for non-silent audio.

B) Pre-recorded PCM16 fixtures (silence, tone, real speech) loaded from test assets. Property tests iterate over these fixtures rather than generating random audio. Simpler to reason about; not truly property-based.

C) `glados` generators for chunk sizes and counts only; audio content is silence (zero-filled PCM). Tests assert engine lifecycle properties (no crash, correct state transitions) without requiring real speech recognition.

D) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 12
**STT engine test strategy: mock vs real engine in unit tests**

Unit 1 established `MockSttEngine` (100ms delay, controllable `emitResult()`). Unit 2 introduces real engine implementations. What is the test strategy for `PlatformSttEngine` and `SherpaOnnxSttEngine`?

A) Unit tests use `MockSttEngine` throughout. `PlatformSttEngine` and `SherpaOnnxSttEngine` are covered only by integration tests that run on real devices/platforms (excluded from CI unit test suite). This keeps the unit test suite fast and platform-independent.

B) Unit tests for `PlatformSttEngine` mock the `SpeechToText` object (via dependency injection). Unit tests for `SherpaOnnxSttEngine` mock the `OnlineRecognizer` bindings. Both engines have unit tests; no real speech recognition in CI.

C) `SherpaOnnxSttEngine` has integration tests in CI using a small bundled test model (included in the test assets). This validates the real Sherpa-ONNX bindings. `PlatformSttEngine` is tested only on devices.

D) Other (please describe after [Answer]: tag below)

[Answer]: B
