# Functional Design Plan: On-Device Multilingual STT

**Answers collected**: 2026-10-20, in-session, 14/14 (all option A). Q1 was refined during review for the project's streaming-caption premise: the engine's decode strategy is sherpa-onnx's documented **simulated-streaming** pattern (interim re-decodes while the user speaks + final on VAD end-of-speech), not final-only sentence mode.
**Status (2026-10-21)**: PARKED per human decision. The Stage 6 artifacts are **written and committed** under `aidlc-docs/construction/on-device-multilingual-stt/functional-design/` (plus `handoff-summary.md`); the FD approval gate has **not** been passed.
**Next step (at pickup)**: present the four artifacts for the human FD-approval gate (or revise them), then NFR Requirements. Full pickup procedure: `aidlc-docs/construction/on-device-multilingual-stt/README.md` and `execution-plan.md` "Parking and Pickup".

**Stories**: S-01 (STT Engine Interface and Registry), S-02 (Platform-Native STT Implementation) — extended, not amended
**Package**: `zip_core` (engine, catalog, models, providers); `zip_captions` (settings surface only)
**Dependencies**: Unit 2 (Phase 1: shipped `SttEngineRegistry`, `SherpaOnnxSttEngine` + `OnlineRecognizerAdapter` seam, `SherpaModelManager`/`SherpaModelCatalogNotifier`, 100 MB download-confirmation threshold); Spike 1.4 (Q7 gates Code Generation Part 2 — vendor data is flagged unverified until then)
**Execution plan**: `aidlc-docs/construction/on-device-multilingual-stt/execution-plan.md` (scope, binding inputs, stage sequence, collision rules)

## Context

Phase 1 shipped the on-device STT tier for the **streaming** model family. The shipped `SherpaOnnxSttEngine` (`packages/zip_core/lib/src/stt/engines/sherpa_onnx_stt_engine.dart`) wraps `OnlineRecognizer` behind the `OnlineRecognizerAdapter` test seam (Unit 2, TEST-U2.2 Q1=A) and is registered under engineId `sherpa-onnx` when a model is downloaded. Its streaming pretrained models cover en/zh/fr/ko/bn/ru — **not** de/es/it/nl/pl, which the v1 UI languages include.

The research (spike-1.4-plan.md findings section) establishes that sherpa-onnx's non-streaming model zoo closes the gap: Parakeet TDT 0.6B v3 int8 (~640 MB) covers 25 European languages with auto-detect, and the documented real-time usage pattern that delivers **streaming caption results** from it is sherpa-onnx's **simulated-streaming** mode (`sherpa-onnx-vad-microphone-simulated-streaming-asr`): Silero VAD detects the in-progress utterance, the offline model re-decodes the accumulating segment on a cadence and emits interim results while the user speaks, and a final is emitted on VAD end-of-speech. An official simulated-streaming build of Parakeet TDT 0.6B v3 exists in sherpa-onnx's release set, so this is a vendor-supported combination, not an invention. The pattern is exposed to Dart as `VoiceActivityDetector` + `OfflineRecognizer` on the already-declared `sherpa_onnx: ^1.10.31`. No true-streaming (causal) pretrained model exists for de/es/it/nl/pl in the streaming zoo (en/zh/fr/ko/bn/ru/ja/th/vi only) — verified twice against the indexed docs.

**Terminology (fixed 2026-10-20 in review).** "Offline" in this document describes the **model family** (non-streaming / chunk-decode), never the engine's network posture: both this engine and the shipped streaming engine are fully on-device and functional without any connection once models are downloaded. The user-facing distinction is "streaming decode" vs "chunk decode (simulated streaming)".

This unit adds one new engine for the non-streaming model family, in simulated-streaming mode. The existing model catalog already provides download lifecycle, progress, cancellation, deletion, the large-download confirmation gate (100 MB threshold — the 640 MB model trips it automatically), and engine (un)registration on download state. The unit does not change the ADR-005 `SttEngine`/`SttResult` contracts, the caption bus, or the streaming engine.

**Verified code facts (read 2026-10-20, not assumed):**

- `SttEngine`: `engineId`, `displayName`, `requiresNetwork`, `requiresDownload`, `requiresMicrophone`, `initialize()`, `isAvailable()`, `supportedLocales()`, `startListening(localeId, onResult)`, `stopListening()`, `pause()`, `resume()`, `dispose()`; `feedAudio` is implementation-level (audio pipeline calls it).
- `SttResult`: `text`, `isFinal`, `confidence`, `timestamp`, `sourceId`, `speakerTag` — **no word-timestamp field** (ADR-005 boundary; out of scope, execution plan).
- `SttEngineRegistry` + `sttEngineProvider` (falls back to `defaultEngine`) + `sttSessionManagerProvider` — the selection/wiring path the new engine must plug into unchanged.
- `SherpaModelCatalogEntry` exposes `primaryLocaleId` (singular) and `downloadSizeBytes` — the shape that must be extended for a multilingual model (Q5).
- `SherpaModelCatalogNotifier` registers/unregisters the `sherpa-onnx` engine on download state — the mechanism to mirror for the new engineId.

**Unverified vendor data** (Spike 1.4 Q7 pending): Parakeet v3 sizes (encoder 622 M + decoder 12 M + joiner 6.1 M + tokens), FLEURS WER per language, RK3588 RTF (0.220 @1 thread → 0.088 @4 threads, measured on v2 of the same architecture), "word-level timestamps" (the offline API returns per-token `timestamps` and/or `tokens`/`words` depending on model family — exact shape for `nemo_transducer` verified against the pub-cache `sherpa_onnx` source at Code Generation Part 1, per the project's plugin-claim verification convention).

## Planned Steps

- [ ] Business logic: the simulated-streaming engine lifecycle — VAD segmentation of the fed audio, segment buffering, interim re-decodes on a cadence (Q4), final decode + best-effort commit on VAD end-of-speech (Q9), in-flight-segment flush on `stopListening`
- [ ] Business logic: engine registration, availability, and picker interaction with catalog/download state (mirroring the shipped `sherpa-onnx` engine's lifecycle)
- [ ] Domain models: catalog entry extension for multilingual models, the engine's configuration, `SttResult` mapping
- [ ] Business rules: language-selection semantics, pause/resume behavior, error handling and continuity, SECURITY-03 redaction
- [ ] Data flow: audio pipeline → VAD → interim re-decodes / final decode → `onResult` → caption bus (bus unchanged); model download → catalog → engine registration (catalog unchanged except entry shape)
- [ ] Frontend components: the engine-picker row and any locale-surface consequence (settings only, `zip_captions`)
- [ ] Generate `business-logic-model.md`, `business-rules.md`, `domain-entities.md`, `frontend-components.md`

## Business Logic Modeling

### Q1: Engine topology — extend the shipped engine or add a new one?

The shipped `SherpaOnnxSttEngine` is a streaming engine: one `OnlineRecognizer` stream, a 100 ms decode poll, interim results as words arrive. The multilingual model family is non-streaming, and its documented real-time pattern is **simulated streaming**: VAD-gated segment buffering, interim re-decodes on a cadence, final on end-of-speech. The project premise is streaming caption results (interim text updating while the user speaks, committed on final) — the simulated-streaming pattern satisfies it, because each interim re-decode emits the segment text so far as a non-final `SttResult`, mapped onto the caption pipeline's trailing-interim line exactly as the streaming engine's results already are. Forcing both decode modes into one engine would conflate two lifecycles under one engineId.

- A. **New engine, new engineId** (e.g. `parakeet-multilingual`): its own class, its own adapter seam (Q2), its own registration lifecycle; the streaming engine stays byte-for-byte untouched. Its decode strategy is the simulated-streaming pattern (VAD + interim re-decodes + final on end-of-speech). The engine picker shows: streaming (en), multilingual chunk-decode (25 languages), and later Whistle (true streaming, 7 languages) as separate rows. **(recommended — smallest blast radius; cleanest A/B story against Spike 1.4; the engine picker already handles multiple registered engines)**
- B. Extend `SherpaOnnxSttEngine` with a chunk-decode mode selected by the downloaded model's kind: one engineId, two internal code paths. Fewer picker rows, but one class now owns two incompatible decode loops (streaming poll vs VAD-gated re-decode) and the Unit 2 test seam (`OnlineRecognizerAdapter`) would need an offline sibling inside the same class.
- C. Other (write in)

[Answer]: A

### Q2: The test seam for the offline path

Unit 2's `OnlineRecognizerAdapter` is the established seam: an adapter interface the engine calls, hand-written fakes in tests, real implementation over `sherpa_onnx` in production (never loaded in a unit test).

- A. **`OfflineSttAdapter` seam**: one interface covering `createSegmentDecoder()` / `decode(segment) → (text, tokens/timestamps, score?)` plus the Silero VAD operations (`acceptWaveform`, `isSpeechDetected`-shaped), mirroring the online adapter's discipline — real implementation in an `_io`-conditional file, fakes everywhere in tests. **(recommended — mirrors TEST-U2.2 exactly; keeps the `sherpa_onnx` native library out of the unit-test suite)**
- B. Two narrower seams (`OfflineRecognizerAdapter` + `VoiceActivityDetectorAdapter`) matching the two `sherpa_onnx` classes one-to-one.
- C. Other (write in)

[Answer]: A

### Q3: Result emission semantics — interim during the segment, final at VAD end

Because the engine runs simulated streaming, it produces interim results while the user speaks and a final at VAD end-of-speech. The shipped streaming engine already behaves as "one in-progress utterance, text updated over time, committed on final", and the caption pipeline's trailing-interim-line rendering maps onto that directly.

- A. **One in-progress slot**: each interim re-decode emits `SttResult(text = segment text so far, isFinal: false)` — the caption pipeline treats it as the single trailing interim line (exactly as it does the streaming engine's results); on VAD end-of-speech the engine emits the final (`isFinal: true`), which commits the line. A named minimum-buffer constant gates the first interim decode (so a 300 ms blip does not produce an unstable one-word flash); its value is an NFR-stage parameter informed by Spike 1.4. Zero changes to the caption bus or session manager. **(recommended — same result contract as the shipped engine, so the pipeline is untouched; the streaming engine remains the word-granular option for English)**
- B. Same as A, plus a distinct "segment starting" non-final emission (empty text) the moment VAD detects speech, so the UI can react before the first decode. Redundant today (the recording-state UI already shows active capture) and an empty-text `SttResult` is an odd contract to introduce.
- C. Per-word interim updates via the offline result's token timestamps. Requires an ADR-005 `SttResult` extension (word-timestamp field) — explicitly a boundary change needing discussion — and new consumption logic in the caption pipeline. Better as a follow-up unit that also benefits the streaming engine.

[Answer]: A

### Q4: Long-utterance behavior — how is the re-decode cost bounded?

In simulated-streaming mode each interim re-decode re-decodes the **whole in-progress segment**, so per-update cost grows with utterance length (e.g. at 4 threads on an A76-class core, a 30 s buffer costs roughly 2–3 s of decode). An unbounded monologue (no pauses) would delay interim updates indefinitely and eventually saturate the CPU. The Silero VAD config exposes `minSilenceDuration`/`minSpeechDuration`/`threshold`/`windowSize`; whether the Dart binding exposes a max-speech-duration needs pub-cache verification.

- A. **VAD-native segmentation in v1** (min-silence-driven cuts), with the interim re-decode **cadence** and an optional **max-segment force-cut** as engine-level named parameters (on `OfflineSttEngineConfig`, Q7) whose VALUES are set at the NFR stage from Spike 1.4 Q7 measurements on the target device. Cadence and cap are the two knobs that keep interims feeling live; choosing them from data rather than invention is the point. **(recommended — avoids inventing numbers now; the NFR stage owns latency targets per the execution plan's binding inputs)**
- B. Fixed cap + cadence now (e.g. force-finalize at 20 s; one interim decode per 1 s of new audio), both revisable later. Guarantees bounded worst-case latency before measurements exist, at the risk of cutting sentences mid-thought at a number chosen without data.
- C. Re-decode as fast as audio arrives (every VAD window). Maximally live but roughly 30x the re-decode load of B; the spike would have to prove viability on low-spec CPUs, and the implementation would tune toward a configuration we would then have to strip out.
- D. Other (write in)

[Answer]: A

### Q5: Language-selection semantics — auto-detect, forced, or both?

The app's recording flow calls `startListening(localeId:)`. Parakeet v3 auto-detects among its 25 languages; whether the `sherpa_onnx` Dart API can force a language for an `nemo_transducer` model is unverified (verify against pub-cache source during this stage; the C++ config shows `OfflineTransducerModelConfig` has no language field, which suggests no).

- A. **Auto-detect only**: the engine ignores `localeId` for decoding, `supportedLocales()` returns the model's full language list, and the settings surface reads "Language: auto-detected." If the API *does* support forcing, still ship auto-detect in v1 (it is the model's design point) and record forcing as a follow-up. **(recommended — one honest behavior; no half-supported UI)**
- B. Force when the app's selected locale is in the model's language list, auto-detect otherwise.
- C. Other (write in)

[Answer]: A

## Domain Model

### Q6: Catalog entry shape for a multilingual model

`SherpaModelCatalogEntry` currently carries a single `primaryLocaleId`. Parakeet v3 is one download, 25 locales. The silero VAD model is a second, small, engine-supporting download (no locales).

- A. **Additive `localeIds: List<String>` on the entry** (freezed model change, regenerated), with `primaryLocaleId` kept as the first entry for the existing consumers until they migrate; the VAD model gets an entry with an empty `localeIds` and a new `kind` discriminator (`offlineTransducer` / `offlineCtc` / `offlineWhisper` / `vad` / the existing streaming kinds). `SherpaOnnxSttEngine.supportedLocales()` migrates to read `localeIds`; the new engine reads it natively. **(recommended — one truth per download; the discriminator is needed anyway for the engine to know how to build its recognizer config)**
- B. One catalog row per locale, all rows sharing a `downloadId`, so `primaryLocaleId` stays singular. The picker/catalog UI would show 25 rows for one download — wrong UX.
- C. A separate `MultilingualModelEntry` type alongside the existing entry (sealed hierarchy).
- D. Other (write in)

[Answer]: A

### Q7: Domain entities vs. implementation detail

Candidates: `OfflineSttEngineConfig` (model file paths, `num_threads`, VAD threshold/min-silence/min-speech, decode method, and the Q4 parameters — interim cadence, max-segment cap, min-buffer-for-first-interim), the in-flight `SentenceSegment` (buffered float32 samples + start offset), the segment decode output (text, tokens/timestamps, score).

- A. **`OfflineSttEngineConfig` is a domain entity** (injected into the engine, persisted with the other engine settings if the NFR stage says so, the seam through which Q4's cap and hotwords later attach). `SentenceSegment` and the raw decode output are **implementation detail** — internal to the engine/adapter, not part of `zip_core`'s public domain surface. `SttResult` mapping stays as shipped (Q8). **(recommended — smallest public surface; the config is the only thing other code (settings, future hotwords) needs to name)**
- B. Promote `SentenceSegment` to a domain entity as well (testable segmentation in isolation).
- C. Other (write in)

[Answer]: A

### Q8: `SttResult` mapping

- A. **Map what the offline API provides, else fixed values**: `text` = the segment transcript from the model (Parakeet v3 emits punctuation and capitalization itself — a real quality gain over the streaming engine's raw text); `isFinal` = `false` for interim re-decodes, `true` on VAD end-of-speech (Q3); `timestamp` = now at emission (interim) / segment end (final); `sourceId` = the engine's `engineId`; `confidence` = the offline result's score if the binding exposes one for `nemo_transducer`, else `1` (matching the shipped streaming engine's current `confidence: 1` rather than inventing a number); `speakerTag` = not set (single-input sessions). Word timestamps: **not** added to `SttResult` (ADR-005 boundary; follow-up decision per execution plan). **(recommended — no contract change, no silent data invention)**
- B. Extend `SttResult` with optional word timestamps now, so the multilingual engine's per-token timestamps are available to the caption pipeline and future features. Requires the ADR-005 boundary discussion the project rules reserve for human review, and the caption pipeline gets no consumer for the field in this unit.
- C. Other (write in)

[Answer]: A

## Business Rules

### Q9: Error handling and captioning continuity

Failure modes: model files missing/corrupt at `initialize()`; VAD init failure; a mid-session **interim** re-decode failure (native exception, OOM on a low-RAM device — retryable, since the next re-decode re-decodes a larger buffer); a mid-session **final** decode failure (leaves the trailing interim line uncommitted); the in-flight buffer at `stopListening`/`pause`.

- A. **Fail-soft with best-effort final commit**: init failures make the engine unavailable, not the app broken — `initialize()` returns false → `isAvailable()` false → the picker row shows its existing unavailable state (the shipped pattern for the streaming engine's missing model). A mid-session interim decode failure drops that update only — the next re-decode retries with a larger buffer, so a transient hiccup costs one missed caption update. A final decode failure promotes the last good interim of that segment to final (best-effort commit, so a sentence is not lost to one thrown decode; if the segment never produced a good interim, it is dropped). `pause()` discards the in-flight buffer; `stopListening()` flushes the buffer when it meets the VAD min-speech duration, else drops it. Every failure logged as a fixed string + error type, never text (SECURITY-03). **(recommended — matches the shipped engine's fail-soft posture and the caption-continuity expectation of live captioning)**
- B. Same as A, but a final decode failure drops the segment entirely — stricter about never committing text the model did not finalize, at the cost of losing whole sentences to single decode exceptions (the rarer failure mode).
- C. A mid-session decode failure fails the whole session (surface an error state to the recording UI) — one native exception stalls the entire caption stream, exactly the continuity failure live captioning should not have.
- D. Other (write in)

[Answer]: A

### Q10: Registration and availability rules

- A. **Mirror the shipped engine's lifecycle exactly**: the catalog notifier registers the new engineId when the Parakeet model **and** the VAD model are both downloaded, and unregisters when either is deleted (the shipped `deleteModel` unregister path, extended from one engineId to the set of engineIds backed by the deleted model). `isAvailable()` = both models present and `initialize()` last succeeded. `requiresDownload` = true, `requiresNetwork` = false, `requiresMicrophone` = true. **(recommended — no new rules invented; the engine set is a function of the catalog state, as today)**
- B. Register on the Parakeet model alone; download the VAD model lazily at first `initialize()`.
- C. Other (write in)

[Answer]: A

### Q11: Redaction (SECURITY-03)

- A. **Restate the project rule for this engine with an audit test**: no log call may carry `text`, tokens, or transcript fragments — fixed strings + error types only (the Unit 8 BR-U8-18 pattern; `external_display_redaction_test.dart` is the in-repo reference); the same rule applies to the adapter seam's error surfaces, including one native-error hazard this engine adds: a thrown `sherpa_onnx` error's message string can quote audio-derived text, so the rule is "log the type, not the message". One record-level redaction audit test in this unit's suite (capture `Logger.root.onRecord` + sentinel string in flight; drive the interim-failure, final-failure, init-failure and dispose paths; assert no record contains the sentinel). **(recommended — identical precedent already exists in the repo)**
- B. Restate the rule without a dedicated audit test (covered by review) — cheaper, but the in-repo precedent (Unit 8) went the audit-test route for exactly this engine-adjacent surface, and the native-error-message hazard is easy to reintroduce in a future edit.
- C. Other (write in)

[Answer]: A

## Data Flow

### Q12: Where the VAD lives relative to the audio pipeline

The audio capture pipeline feeds PCM16 chunks to the active engine (the `feedAudio` path used by the shipped engine). The Silero VAD consumes 16 kHz float32 in its own `windowSize` frames.

- A. **The engine owns the VAD**: `feedAudio(pcm16)` converts to float32 (as the shipped engine already does), feeds the VAD, and buffers samples while VAD reports speech; the engine drives the interim re-decodes on the Q4 cadence from the same buffer. No change to the capture pipeline, the session manager, or any other engine — the pipeline still doesn't know about the recognizer, just as today. **(recommended — the VAD is an engine-internal concern; the pipeline already doesn't know about the recognizer either)**
- B. The VAD moves up to the session-manager level, shared by engines — speculative sharing: only one engine is active per session by the shipped design, so this couples the session manager to a model-internal concern it deliberately doesn't have today.
- C. A pipeline-level VAD stage feeding pre-segmented audio to every engine — the streaming engine has its own endpointing inside sherpa-onnx and would get double-gated.
- D. Other (write in)

[Answer]: A

## Integration Points

### Q13: What the catalog/download layer needs from this unit (and vice versa)

- A. **The catalog layer changes by one model entry (Parakeet v3 + VAD) and the Q6 entry-shape extension; everything else is additive engine registration** (Q10). The Infrastructure Design stage owns where the files are served from and the catalog JSON's new rows; this unit's Functional Design fixes the shapes only. The engine never touches the network — it resolves model paths through the existing `SherpaModelManager`. **(recommended — keeps the download lifecycle exactly as Unit 2 shipped it)**
- B. The engine downloads/validates its own model files (bypasses the catalog) — two integrity mechanisms for one state, and a second, divergent source of truth about the model's state.
- C. The engine downloads its own VAD model, bypassing the catalog for it — two download code paths for one feature, and the engine gains network access it should not have.
- D. Other (write in)

[Answer]: A

## Frontend Components

### Q14: The settings surface in `zip_captions`

The engine picker (shipped) lists registered engines; the model catalog UI (shipped) shows download state/progress/deletion per catalog entry.

- A. **No new screens**: one new picker row ("Multilingual — on-device", displayName ARB-backed) that appears when its two models are downloaded (Q10), with the picker's existing unavailable-state treatment when they are not; the shipped catalog UI renders the two new download rows as-is (the 640 MB row trips the shipped confirmation dialog by its size, the 2 MB VAD row doesn't). The language/locale row for this engine reads "Language: auto-detected" (Q5). All new strings in `app_en.arb` via `gen-l10n`. **(recommended — the unit stays a `zip_core` unit with the smallest possible UI delta)**
- B. A dedicated "multilingual" settings section with its own 25-entry language list — honest about coverage, but selecting a language changes nothing in v1 (Q5, auto-detect only), so the list is a UI promise the engine cannot keep.
- C. Show the engine row always with an inline "Download" affordance in the picker — duplicates the catalog UI's download/progress/cancel state in a second place that must stay in sync.
- D. Other (write in)

[Answer]: A

---

## Stage completion and approval

**Status: all 14 answers collected 2026-10-20 in-session (Q1–Q14, all option A).** No vague answers detected, so no clarification-questions file is required (Step 5). Q1 was refined during review for the project's streaming-caption premise (simulated-streaming decode strategy, recorded in Q1's text); the terminology fix ("offline" = model family, not network posture) is recorded in the Context section. One verification item remains for artifact generation: whether the `sherpa_onnx` Dart binding can force a language for an `nemo_transducer` model (Q5's premise) — to be checked against the pub-cache source, with the auto-detect-only design holding regardless of the answer.

**Artifacts generated 2026-10-21** (Step 6): `business-logic-model.md`, `business-rules.md`, `domain-entities.md`, `frontend-components.md`, plus `handoff-summary.md` (project stage-handoff rule), under `aidlc-docs/construction/on-device-multilingual-stt/functional-design/`. All committed on `feature/popout-live-captions` (they land on `develop` via the pop-out run's PR). **Unit PARKED 2026-10-21 (human decision)** — the next action is Step 8: present the artifacts for explicit human approval before NFR Requirements. Pickup procedure: `aidlc-docs/construction/on-device-multilingual-stt/README.md`.
