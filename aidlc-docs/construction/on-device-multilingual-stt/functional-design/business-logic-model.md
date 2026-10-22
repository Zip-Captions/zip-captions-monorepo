# Business Logic Model — On-Device Multilingual STT

**Answers**: all from the Functional Design plan (`aidlc-docs/construction/plans/on-device-multilingual-stt-functional-design-plan.md`), 14/14 recorded 2026-10-20.
**Terminology**: "chunk decode" / "simulated streaming" = the non-streaming model family driven by VAD segmentation + interim re-decodes. "Offline" describes the model family only, never network posture — the engine is fully on-device after download.

## `MultilingualSttEngine` — the new `SttEngine` implementation

Class name and engineId (`multilingual-onnx`) are proposals for this stage; final names settle at Code Generation. Implements the shipped `SttEngine` contract (ADR-005, unchanged) with a chunk-decode lifecycle:

### Lifecycle

1. **`initialize()`** — resolves model directory paths through the injected `SherpaModelManager` (Rule 9: the engine never touches the network), then asks the `OfflineSttAdapter` to create the recognizer + VAD from `MultilingualSttEngineConfig` (domain-entities.md). Any failure (missing/corrupt files, VAD init failure, OOM loading the ~640 MB model) → return `false`; the engine then reports `isAvailable() = false` and the picker row shows its shipped unavailable state (Rule 6). No partial state is left behind: a failed init disposes whatever the adapter created.
2. **`isAvailable()`** — both catalog entries (ASR model + VAD model) present per the catalog state (Rule 1) **and** the last `initialize()` succeeded.
3. **`startListening(localeId, onResult)`** — per the shipped contract. `localeId` is accepted and **ignored for decoding** (Rule 5, auto-detect only); the engine stores `onResult` and starts the segment state machine (below). Sets the preferred audio device through the injected `AudioDeviceService`, exactly as the shipped streaming engine does.
4. **`feedAudio(pcm16Bytes)`** — the pipeline's existing call site, unchanged (Rule 10). Converts PCM16 → float32 (the shipped engine already performs this conversion), feeds the VAD through the adapter, and appends to the in-flight segment buffer while the VAD reports speech. When the buffer has grown by `config.interimCadence` of audio since the last decode completed (Rule 3) and no decode is in flight, the engine starts an interim decode of the whole buffer (Rule 2).
5. **VAD end-of-speech** — the adapter reports the segment complete. The engine runs the **final decode** of the full segment buffer. Success → emit the final `SttResult` (Rule 2) and return to idle. Final decode failure → best-effort commit: promote the last good interim of the segment to final, or drop the segment if none exists (Rule 6).
6. **`pause()`** — discards the in-flight buffer and any in-flight decode (Rule 7). No partial is ever committed from a pause.
7. **`resume()`** — restarts the segment state machine from idle; a new segment starts on the next VAD speech detection. (A resume does not resurrect a discarded buffer.)
8. **`stopListening()`** — if an in-flight buffer meets the VAD `minSpeechDuration`, run the final decode and emit it (best-effort commit applies, Rule 6); otherwise drop it. Then return to idle (Rule 7).
9. **`dispose()`** — cancels any in-flight decode, disposes the adapter (recognizer + VAD), releases the buffer. Idempotent.

### The simulated-streaming segment state machine

```
Idle ──VAD speech-start──▶ InProgress ──buffer ≥ minBufferForFirstInterim,
                            │  (buffer grows with feedAudio)        cadence elapsed,
                            │                                       no decode in flight
                            │  ─────────────────────────────────▶ InterimDecoding
                            │                                          │ (decode finishes)
                            │                                          ▼
                            ◀────────────────────────────────── InProgress
                            │   (emit interim SttResult if text non-empty;
                            │    buffer keeps growing; next interim at next cadence)
InProgress ──VAD end-of-speech──▶ FinalDecoding ──success──▶ Idle (final emitted)
                                   │
                                   └──failure──▶ Idle (best-effort commit, Rule 6)
```

- Exactly one segment can be in flight at a time; a VAD speech-start while a segment is in flight is impossible by construction (the VAD cannot report a new segment until the current one ends — the adapter's VAD state is single-segment).
- At most one decode (interim or final) is in flight at a time; a cadence tick that fires while a decode is running is **skipped, not queued** — the next tick re-decodes the larger buffer, so no work is lost, only deferred (Rule 3).
- The buffer is the single source of truth for what gets decoded; decodes are pure reads of the buffer, never destructive.

### Result emission (Rule 2)

- **Interim**: `SttResult(text = <current segment text>, isFinal: false, timestamp = now, sourceId = engineId, confidence = <Rule 8 mapping>)`. The caption pipeline's trailing-interim line replaces its content with each emission — the identical contract the shipped streaming engine already exercises (the whole-utterance text blob, updated over time).
- **Final**: same shape with `isFinal: true` and `timestamp` = segment end. Commits the caption line.
- An interim decode that produces empty text emits nothing (no empty interim).
- `stopListening`/flush and best-effort-commit finals use the same `SttResult` shape; nothing downstream distinguishes their origin.

## `OfflineSttAdapter` — the test seam (Q2)

One interface (Q2 answer A), package-visible, implemented in an io-conditional file over `sherpa_onnx` (never loaded in unit tests) with hand-written fakes in the test suite — the exact discipline of Unit 2's `OnlineRecognizerAdapter` (TEST-U2.2 Q1=A).

Operations:

- `Future<void> initialize(MultilingualSttEngineConfig config)` — create the offline recognizer (model files + threads + decode method) and the Silero VAD detector (threshold, min-silence, min-speech). Throws on any init failure; the engine maps that to `initialize() = false`.
- `void acceptWaveform(List<double> samples)` — feed audio to the VAD; appends to the internal segment buffer while the VAD reports speech.
- `SegmentState get segmentState` — `idle | inProgress | complete`; the engine polls this after each `acceptWaveform` (the VAD's own windowed cadence determines how often `complete` can appear).
- `List<double> currentBuffer()` — the in-flight segment samples (pure read).
- `int bufferedSeconds()` — buffer length in samples, for the cadence and min-buffer checks (Rule 3, Rule 4).
- `Future<SegmentDecodeResult> decode(List<double> samples)` — run the offline model over the given samples (interim or final, same call); returns text, tokens/timestamps if the binding exposes them, and a score if it does (Rule 8). Throws on decode failure (Rule 6).
- `void reset()` — clear the segment buffer after a segment is committed or dropped.
- `void dispose()` — release recognizer + VAD. Idempotent.

`SegmentDecodeResult` and the buffer are **not** part of `zip_core`'s public barrel surface (Q7 answer A) — they exist in the adapter/engine files and are consumed only by the engine and its tests.

## Registration and catalog interaction (Q10, Q13)

- `SherpaModelCatalogNotifier` gains one behavior: the set of engineIds backed by a catalog entry is now tracked, and `deleteModel` unregisters **every** engineId whose last supporting model was removed (the shipped path unregisters `sherpa-onnx`; it generalizes to the set). The new engineId registers when **both** its entries (ASR + VAD) are downloaded — the same registration point the shipped engine uses (app startup / download completion, per the shipped notifier's existing flow).
- `supportedLocales()` — the engine reads `localeIds` from its ASR catalog entry (Q6) and returns them as `SpeechLocale`s; `displayName` is the ARB-backed "Multilingual — on-device".
- Nothing about the download lifecycle, the 100 MB confirmation gate, progress, or cancellation changes (Q13): the two new catalog rows ride the shipped machinery as-is.

## Data flow (unchanged surfaces)

```
audio capture pipeline ──PCM16──▶ feedAudio (engine)
                                     │ float32 convert
                                     ▼
                                OfflineSttAdapter (VAD + buffer + decode)
                                     │
                    interim SttResult (isFinal: false, per cadence)
                    final   SttResult (isFinal: true, on VAD end-of-speech)
                                     ▼
                                onResult ──▶ SttSessionManager ──▶ caption bus ──▶ output targets
```

The audio capture pipeline, `SttSessionManager`, the caption bus, the output targets, and the other engines are untouched. Model download flows through the shipped `SherpaModelManager`/catalog notifier (two new rows), which is the only changed surface in that layer.

## What this unit deliberately does not model

- Word-level interim updates (would need the ADR-005 `SttResult` extension — follow-up unit, would also benefit the streaming engine).
- Hotwords/keyword biasing (the `nemo_transducer` family is hotword-capable; `MultilingualSttEngineConfig` keeps the seam — a `hotwords` file path + score — but v1 ships no hotword source; follow-up unit).
- Per-language model selection (one download, 25 languages, auto-detect; Q5).
- Web (Fallback tier; no offline STT on web in this unit).
