# Business Rules — On-Device Multilingual STT

Numbered, each traceable to a Functional Design plan answer. PBT references name the property the rule underwrites; the NFR Requirements stage assigns the final PBT IDs.

**Rule 1 — The set of available engines is a pure function of catalog state.**
The new engineId is registered if and only if both its catalog entries (the ASR model and the VAD model) are downloaded, and it is unregistered the moment either is deleted (the shipped `deleteModel` path, generalized from one engineId to the set of engineIds backed by the removed model). `isAvailable()` additionally requires the last `initialize()` to have succeeded. No other input (network, locale, device class) gates registration. *(Q10 — mirrors the shipped `sherpa-onnx` engine's lifecycle exactly; the engine picker remains a function of downloaded models.)*

**Rule 2 — Exactly one in-progress segment; interims replace, the final commits.**
At most one segment is in flight at a time. While it is in flight, each interim decode emits a non-final `SttResult` whose `text` is the whole current segment text; the caption pipeline treats successive interims as revisions of the same trailing line, never as new lines. Exactly one final `SttResult` per segment is emitted, on VAD end-of-speech (or the `stopListening` flush / best-effort commit), and it is what commits the line. A segment that produces no non-empty text emits nothing. *(Q3 — same result contract as the shipped streaming engine, so the caption bus and session manager are untouched.)*

**Rule 3 — At most one decode in flight; a cadence tick that fires mid-decode is skipped, not queued.**
An interim decode is scheduled when the buffer has grown by `config.interimCadence` of audio since the last decode completed and no decode is in flight. If the cadence fires while a decode is running, that tick is dropped — the next tick re-decodes the (larger) buffer, so no audio is lost, only the update is deferred. The interim re-decode **cadence** and the **max-segment force-cut** are `MultilingualSttEngineConfig` parameters whose values are set at the NFR stage from Spike 1.4 Q7 measurements; Functional Design fixes the mechanism, not the numbers. *(Q4 — the two knobs that keep interims feeling live on a device whose per-update cost grows with segment length.)*

**Rule 4 — The first interim decode is gated on a minimum buffer.**
No interim decode runs until the in-flight buffer reaches `config.minBufferForFirstInterim`, a named constant fixed at the NFR stage. This prevents a sub-second blip from producing an unstable one-word flash on the trailing line. *(Q3 — companion to Rule 2.)*

**Rule 5 — Language is auto-detected; the selected locale is not used for decoding.**
`startListening(localeId, …)` accepts `localeId` (shipped contract) but the engine ignores it for decoding; the model auto-detects among its 25 languages. `supportedLocales()` returns the entry's full `localeIds` list, and the settings surface reads "Language: auto-detected". If the `sherpa_onnx` binding turns out to support forcing a language for an `nemo_transducer` model, forcing is a follow-up setting, not a v1 behavior. *(Q5 — one honest behavior; no half-supported UI. The pub-cache check for forcing is recorded as an open verification item in the plan's completion section.)*

**Rule 6 — Fail-soft: init failure makes the engine unavailable; a mid-session failure never stalls the stream.**
- `initialize()` failure (missing/corrupt model, VAD init failure, OOM) → return `false` → `isAvailable()` false → the picker row shows its shipped unavailable state. The app and its other engines are unaffected; the engine leaves no partial state.
- A mid-session **interim** decode failure drops that update only; the engine keeps listening and the next re-decode retries with a larger buffer.
- A mid-session **final** decode failure promotes the segment's last good interim to final (best-effort commit); if the segment never produced a good interim, the segment is dropped. In both cases the engine returns to idle and continues.
- Every failure is logged as a fixed string + error type, never transcript text (Rule 8).
*(Q9 — matches the shipped engine's fail-soft posture; one bad decode costs at most one caption update or one best-effort-committed sentence, never the whole stream.)*

**Rule 7 — `pause()` discards the in-flight buffer; `stopListening()` flushes only a real utterance.**
`pause()` drops the current buffer and any in-flight decode — no partial is ever committed from a pause; `resume()` starts fresh from idle. `stopListening()` runs the final decode and emits a result only if the in-flight buffer meets the VAD `minSpeechDuration`; a sub-threshold tail is dropped. *(Q9 — companion to Rule 6.)*

**Rule 8 — No transcript text reaches a log, a metric, or a crash report (SECURITY-03), including native error messages.**
No log, metric, or telemetry call may carry `text`, tokens, or any transcript fragment — fixed strings + error types only (the Unit 8 BR-U8-18 pattern; `external_display_redaction_test.dart` is the in-repo reference). One native-error hazard this engine adds: a thrown `sherpa_onnx` error's message can quote audio-derived text, so the rule is **"log the type, not the message"** for adapter-surface exceptions. A record-level redaction audit test (capture `Logger.root.onRecord` with a sentinel string in flight; drive the interim-failure, final-failure, init-failure, and dispose paths; assert no record contains the sentinel) is in this unit's suite. *(Q11 — the project's absolute transcript-privacy constraint, enforced with an audit test per the in-repo precedent.)*

**Rule 9 — The engine never touches the network.**
The engine resolves model directory paths through the injected `SherpaModelManager` and holds no URL, no download call, and no network permission. All model acquisition is the catalog/download layer's job (the shipped `SherpaModelManager`, unchanged). *(Q13 — keeps the download lifecycle exactly as Unit 2 shipped it; the engine is offline by construction.)*

**Rule 10 — The VAD is engine-internal; the audio pipeline and other engines are unchanged.**
The engine owns its VAD: `feedAudio(pcm16)` converts to float32, feeds the VAD, and buffers while speech is detected. The capture pipeline, `SttSessionManager`, the caption bus, and every other engine (including the shipped streaming engine) are untouched. *(Q12 — the pipeline still doesn't know about the recognizer, as today; no shared-VAD coupling introduced speculatively.)*

**Rule 11 — The catalog entry is one row per download, with an explicit kind.**
A multilingual model is a single catalog entry carrying a `localeIds` list (one truth per download) and a `kind` discriminator; the VAD model is its own entry with empty `localeIds` and `kind: vad`. The engine builds its recognizer config from the entry's `kind` + file paths. No per-locale rows for a single download. *(Q6 — the shape that lets the 640 MB / 25-language download render as one row and be deleted as one unit.)*

**Rule 12 — The `SttResult` mapping is exact; the contract is not extended.**
`text` = the model's segment transcript (Parakeet v3 emits its own punctuation/capitalization); `isFinal` = false for interims, true for the final/flush/best-effort commit; `timestamp` = now (interim) / segment end (final); `sourceId` = the engine's `engineId`; `confidence` = the offline result's score if the binding exposes one for `nemo_transducer`, else `1`; `speakerTag` = unset. No word-timestamp field is added to `SttResult`. *(Q8 — ADR-005 boundary untouched; no silent data invention.)*
