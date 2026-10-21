# Functional Design Plan: On-Device Multilingual STT

**Stories**: S-01 (STT Engine Interface and Registry), S-02 (Platform-Native STT Implementation) — extended, not amended
**Package**: `zip_core` (engine, catalog, models, providers); `zip_captions` (settings surface only)
**Dependencies**: Unit 2 (Phase 1: shipped `SttEngineRegistry`, `SherpaOnnxSttEngine` + `OnlineRecognizerAdapter` seam, `SherpaModelManager`/`SherpaModelCatalogNotifier`, 100 MB download-confirmation threshold); Spike 1.4 (Q7 gates Code Generation Part 2 — vendor data is flagged unverified until then)
**Execution plan**: `aidlc-docs/construction/on-device-multilingual-stt/execution-plan.md` (scope, binding inputs, stage sequence, collision rules)

## Context

Phase 1 shipped the on-device STT tier for the **streaming** model family. The shipped `SherpaOnnxSttEngine` (`packages/zip_core/lib/src/stt/engines/sherpa_onnx_stt_engine.dart`) wraps `OnlineRecognizer` behind the `OnlineRecognizerAdapter` test seam (Unit 2, TEST-U2.2 Q1=A) and is registered under engineId `sherpa-onnx` when a model is downloaded. Its streaming pretrained models cover en/zh/fr/ko/bn/ru — **not** de/es/it/nl/pl, which the v1 UI languages include.

The research (spike-1.4-plan.md findings section) establishes that sherpa-onnx's **offline** model zoo closes the gap: Parakeet TDT 0.6B v3 int8 (~640 MB) covers 25 European languages with auto-detect, and the documented usage pattern is **Silero VAD → segment → offline decode** (the `sherpa-onnx-vad-microphone-offline-asr` pattern), exposed to Dart as `VoiceActivityDetector` + `OfflineRecognizer` on the already-declared `sherpa_onnx: ^1.10.31`. The existing model catalog already provides download lifecycle, progress, cancellation, deletion, the large-download confirmation gate (100 MB threshold — the 640 MB model trips it automatically), and engine (un)registration on download state.

This unit adds one new engine for the offline/sentence family. It does not change the ADR-005 `SttEngine`/`SttResult` contracts, the caption bus, or the streaming engine.

**Verified code facts (read 2026-10-20, not assumed):**

- `SttEngine`: `engineId`, `displayName`, `requiresNetwork`, `requiresDownload`, `requiresMicrophone`, `initialize()`, `isAvailable()`, `supportedLocales()`, `startListening(localeId, onResult)`, `stopListening()`, `pause()`, `resume()`, `dispose()`; `feedAudio` is implementation-level (audio pipeline calls it).
- `SttResult`: `text`, `isFinal`, `confidence`, `timestamp`, `sourceId`, `speakerTag` — **no word-timestamp field** (ADR-005 boundary; out of scope, execution plan).
- `SttEngineRegistry` + `sttEngineProvider` (falls back to `defaultEngine`) + `sttSessionManagerProvider` — the selection/wiring path the new engine must plug into unchanged.
- `SherpaModelCatalogEntry` exposes `primaryLocaleId` (singular) and `downloadSizeBytes` — the shape that must be extended for a multilingual model (Q5).
- `SherpaModelCatalogNotifier` registers/unregisters the `sherpa-onnx` engine on download state — the mechanism to mirror for the new engineId.

**Unverified vendor data** (Spike 1.4 Q7 pending): Parakeet v3 sizes (encoder 622 M + decoder 12 M + joiner 6.1 M + tokens), FLEURS WER per language, RK3588 RTF (0.220 @1 thread → 0.088 @4 threads, measured on v2 of the same architecture), "word-level timestamps" (the offline API returns per-token `timestamps` and/or `tokens`/`words` depending on model family — exact shape for `nemo_transducer` verified against the pub-cache `sherpa_onnx` source at Code Generation Part 1, per the project's plugin-claim verification convention).

## Planned Steps

- [ ] Business logic: the sentence-mode engine lifecycle — VAD segmentation of the fed audio, segment buffering, offline decode on segment end, result emission, in-flight-segment flush on `stopListening`
- [ ] Business logic: engine registration, availability, and picker interaction with catalog/download state (mirroring the shipped `sherpa-onnx` engine's lifecycle)
- [ ] Domain models: catalog entry extension for multilingual models, the offline engine's configuration, `SttResult` mapping
- [ ] Business rules: language-selection semantics, pause/resume behavior, error handling and continuity, SECURITY-03 redaction
- [ ] Data flow: audio pipeline → VAD → offline decode → `onResult` → caption bus (bus unchanged); model download → catalog → engine registration (catalog unchanged except entry shape)
- [ ] Frontend components: the engine-picker row and any locale-surface consequence (settings only, `zip_captions`)
- [ ] Generate `business-logic-model.md`, `business-rules.md`, `domain-entities.md`, `frontend-components.md`

## Business Logic Modeling

### Q1: Engine topology — extend the shipped engine or add a new one?

The shipped `SherpaOnnxSttEngine` is a streaming engine: one `OnlineRecognizer` stream, a 100 ms decode poll, interim results as words arrive. The offline family is a different mode: VAD-gated sentence buffering, one decode per segment, final-only results. Forcing both modes into one engine conflates two lifecycles under one engineId.

- A. **New engine, new engineId** (e.g. `parakeet-offline` or `sherpa-onnx-multilingual`): its own class, its own adapter seam (Q2), its own registration lifecycle; the streaming engine stays byte-for-byte untouched. The engine picker shows both when their models are downloaded; a future Whistle engine becomes a third row. **(recommended — smallest blast radius, cleanest A/B story against Spike 1.4, and the engine picker already handles multiple registered engines)**
- B. Extend `SherpaOnnxSttEngine` with an offline mode selected by the downloaded model's kind: one engineId, two internal code paths, the engine's `displayName`/availability reflecting whichever model is present. Fewer moving parts in the picker, but one class now owns two incompatible decode loops and the Unit 2 test seam (`OnlineRecognizerAdapter`) would need an offline sibling inside the same class.
- C. Other (write in)

[Answer]:

### Q2: The test seam for the offline path

Unit 2's `OnlineRecognizerAdapter` is the established seam: an adapter interface the engine calls, hand-written fakes in tests, real implementation over `sherpa_onnx` in production (never loaded in a unit test).

- A. **`OfflineSttAdapter` seam**: one interface covering `createSegmentDecoder()` / `decode(segment) → (text, tokens/timestamps, score?)` plus the Silero VAD operations (`acceptWaveform`, `isSpeechDetected`-shaped), mirroring the online adapter's discipline — real implementation in an `_io`-conditional file, fakes everywhere in tests. **(recommended — mirrors TEST-U2.2 exactly; keeps the `sherpa_onnx` native library out of the unit-test suite)**
- B. Two narrower seams (`OfflineRecognizerAdapter` + `VoiceActivityDetectorAdapter`) matching the two `sherpa_onnx` classes one-to-one.
- C. Other (write in)

[Answer]:

### Q3: Result emission semantics — what does the engine emit, and when?

Offline decode has no in-utterance interim results. The caption bus already distinguishes interim vs. final entries.

- A. **One `SttResult(isFinal: true)` per VAD-completed segment.** `timestamp` = segment end; `text` = the segment transcript; no interim results from this engine. `stopListening()` decodes any in-flight buffer and emits it as final (or drops it if shorter than the VAD minimum — see Q9). The user sees captions appear sentence-by-sentence; continuous speech keeps them flowing as each segment completes. **(recommended — honest to the model's behavior; the streaming engine remains the word-by-word option for users who need it)**
- B. Emit a non-final "segment in progress" placeholder at VAD speech-start, replaced by the final at segment end. Gives the UI something to render during long utterances, but the placeholder text does not exist yet (nothing to show) — it can only be a "listening" affordance, which the recording-state UI already provides.
- C. Other (write in)

[Answer]:

### Q4: Long-utterance behavior — is there a maximum segment length?

An unbounded monologue (no pauses) delays the first final result indefinitely. The Silero VAD config exposes `minSilenceDuration`/`minSpeechDuration`/`threshold`/`windowSize`; whether the Dart binding exposes a max-speech-duration needs pub-cache verification.

- A. **VAD-native segmentation only in v1** (min-silence-driven cuts), with the engine-level max-segment cap deferred to the NFR stage, where the < 1 s / perceived-latency targets are set with Spike 1.4's Q7 measurements and the cap (if any) is chosen from data. **(recommended — avoids inventing a number now; the NFR stage owns latency targets per the execution plan's binding inputs)**
- B. Fixed engine-level cap now (e.g. force-cut at 20 s), tuned later.
- C. Other (write in)

[Answer]:

### Q5: Language-selection semantics — auto-detect, forced, or both?

The app's recording flow calls `startListening(localeId:)`. Parakeet v3 auto-detects among its 25 languages; whether the `sherpa_onnx` Dart API can force a language for an `nemo_transducer` model is unverified (verify against pub-cache source during this stage; the C++ config shows `OfflineTransducerModelConfig` has no language field, which suggests no).

- A. **Auto-detect only**: the engine ignores `localeId` for decoding, `supportedLocales()` returns the model's full language list, and the settings surface reads "Language: auto-detected." If the API *does* support forcing, still ship auto-detect in v1 (it is the model's design point) and record forcing as a follow-up. **(recommended — one honest behavior; no half-supported UI)**
- B. Force when the app's selected locale is in the model's language list, auto-detect otherwise.
- C. Other (write in)

[Answer]:

## Domain Model

### Q6: Catalog entry shape for a multilingual model

`SherpaModelCatalogEntry` currently carries a single `primaryLocaleId`. Parakeet v3 is one download, 25 locales. The silero VAD model is a second, small, engine-supporting download (no locales).

- A. **Additive `localeIds: List<String>` on the entry** (freezed model change, regenerated), with `primaryLocaleId` kept as the first entry for the existing consumers until they migrate; the VAD model gets an entry with an empty `localeIds` and a new `kind` discriminator (`offlineTransducer` / `offlineCtc` / `offlineWhisper` / `vad` / the existing streaming kinds). `SherpaOnnxSttEngine.supportedLocales()` migrates to read `localeIds`; the new engine reads it natively. **(recommended — one truth per download; the discriminator is needed anyway for the engine to know how to build its recognizer config)**
- B. One catalog row per locale, all rows sharing a `downloadId`, so `primaryLocaleId` stays singular. The picker/catalog UI would show 25 rows for one download — wrong UX.
- C. A separate `MultilingualModelEntry` type alongside the existing entry (sealed hierarchy).
- D. Other (write in)

[Answer]:

### Q7: Domain entities vs. implementation detail

Candidates: `OfflineSttEngineConfig` (model file paths, `num_threads`, VAD threshold/min-silence/min-speech, decode method), the in-flight `SentenceSegment` (buffered float32 samples + start offset), the segment decode output (text, tokens/timestamps, score).

- A. **`OfflineSttEngineConfig` is a domain entity** (injected into the engine, persisted with the other engine settings if the NFR stage says so, the seam through which Q4's cap and hotwords later attach). `SentenceSegment` and the raw decode output are **implementation detail** — internal to the engine/adapter, not part of `zip_core`'s public domain surface. `SttResult` mapping stays as shipped (Q8). **(recommended — smallest public surface; the config is the only thing other code (settings, future hotwords) needs to name)**
- B. Promote `SentenceSegment` to a domain entity as well (testable segmentation in isolation).
- C. Other (write in)

[Answer]:

### Q8: `SttResult` mapping

- A. **Map what the offline API provides, else fixed values**: `text` = segment transcript (with the model's own punctuation/capitalization — a Parakeet v3 feature); `isFinal` = always `true` (Q3); `timestamp` = segment end; `sourceId` = the engine's `engineId`; `confidence` = the API's score if it exposes one for this model family, else `1` (matching the shipped streaming engine's current `confidence: 1`); `speakerTag` = not set (single-input sessions). Word timestamps: **not** added to `SttResult` (ADR-005 boundary; follow-up decision per execution plan). **(recommended — no contract change, no silent data invention)**
- B. Extend `SttResult` with optional word timestamps now (requires ADR-005 boundary discussion — explicitly out of scope here).
- C. Other (write in)

[Answer]:

## Business Rules

### Q9: Error handling and captioning continuity

Failure modes: model files missing/corrupt at `initialize()`; VAD init failure; a segment decode failure mid-session (native exception, OOM on a low-RAM device); the in-flight buffer at `stopListening`/`pause`.

- A. **Init failures make the engine unavailable, not the app broken**: `initialize()` returns false → `isAvailable()` false → the picker row shows its existing unavailable state (the shipped pattern for the streaming engine's missing model). A mid-session decode failure: log a fixed string + error type (no text, SECURITY-03), drop that segment, keep listening — one bad sentence never stalls the caption stream. `pause()` discards the in-flight buffer (no partial to flush); `stopListening()` flushes the buffer if it meets the VAD minimum-speech duration, else drops it. **(recommended — matches the shipped engine's fail-soft posture and the caption-continuity expectation of live captioning)**
- B. A mid-session decode failure fails the whole session (surface an error state to the recording UI).
- C. Other (write in)

[Answer]:

### Q10: Registration and availability rules

- A. **Mirror the shipped engine's lifecycle exactly**: the catalog notifier registers the new engineId when the Parakeet model **and** the VAD model are both downloaded, and unregisters when either is deleted (the shipped `deleteModel` unregister path, extended from one engineId to the set of engineIds backed by the deleted model). `isAvailable()` = both models present and `initialize()` last succeeded. `requiresDownload` = true, `requiresNetwork` = false, `requiresMicrophone` = true. **(recommended — no new rules invented; the engine set is a function of the catalog state, as today)**
- B. Register on the Parakeet model alone; download the VAD model lazily at first `initialize()`.
- C. Other (write in)

[Answer]:

### Q11: Redaction (SECURITY-03)

- A. **Restate the project rule for this engine with an audit test**: no log call may carry `text`, tokens, or transcript fragments — fixed strings + error types only (the Unit 8 BR-U8-18 pattern, `external_display_redaction_test.dart` is the in-repo reference); the same rule applies to the adapter seam's error surfaces. One record-level redaction audit test in this unit's suite. **(recommended — identical precedent already exists in the repo)**
- B. Restate the rule without a dedicated audit test (covered by review).
- C. Other (write in)

[Answer]:

## Data Flow

### Q12: Where the VAD lives relative to the audio pipeline

The audio capture pipeline feeds PCM16 chunks to the active engine (the `feedAudio` path used by the shipped engine). The Silero VAD consumes 16 kHz float32 in its own `windowSize` frames.

- A. **The engine owns the VAD**: `feedAudio(pcm16)` converts to float32 (as the shipped engine already does), feeds the VAD, and buffers samples while VAD reports speech; on VAD speech-end the engine decodes the buffered segment. No change to the capture pipeline, the session manager, or any other engine. **(recommended — the VAD is an engine-internal concern; the pipeline already doesn't know about the recognizer either)**
- B. The VAD moves up to the session-manager level, shared by engines.
- C. Other (write in)

[Answer]:

## Integration Points

### Q13: What the catalog/download layer needs from this unit (and vice versa)

- A. **The catalog layer changes by one model entry (Parakeet v3 + VAD) and the Q6 entry-shape extension; everything else is additive engine registration** (Q10). The Infrastructure Design stage owns where the files are served from and the catalog JSON's new rows; this unit's Functional Design fixes the shapes only. The engine never touches the network — it resolves model paths through the existing `SherpaModelManager`. **(recommended — keeps the download lifecycle exactly as Unit 2 shipped it)**
- B. The engine downloads/validates its own model files (bypasses the catalog).
- C. Other (write in)

[Answer]:

## Frontend Components

### Q14: The settings surface in `zip_captions`

The engine picker (shipped) lists registered engines; the model catalog UI (shipped) shows download state/progress/deletion per catalog entry.

- A. **No new screens**: one new picker row ("Offline multilingual — Parakeet", displayName ARB-backed) that appears when its models are downloaded (Q10), with the usual unavailable-state copy when not; the existing catalog UI renders the two new entries (the 640 MB row trips the shipped confirmation dialog by its size). The locale row reads "Language: auto-detected" for this engine (Q5). All new strings in `app_en.arb` + `gen-l10n`. **(recommended — the unit is a core-library unit with the smallest possible UI delta)**
- B. A dedicated "multilingual" settings section with per-language toggles (misleading — the model is one download; toggles would imply model selection).
- C. Other (write in)

[Answer]:

---

## Stage completion and approval

On approval of the answers above, this stage generates `business-logic-model.md`, `business-rules.md`, `domain-entities.md`, and `frontend-components.md` under `aidlc-docs/construction/on-device-multilingual-stt/functional-design/` (per `.aidlc-rule-details/construction/functional-design.md` Step 6), then waits for explicit approval before NFR Requirements (Step 8). Answers to this plan are collected as `[Answer]:` entries; any vague answer gets a follow-up question before artifacts are generated (Step 5).
