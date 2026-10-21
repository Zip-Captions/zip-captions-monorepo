# Spike 1.4 Plan: On-Device STT Engine Evaluation — Cactus Whistle vs. Sherpa-ONNX

**Date**: 2026-10-20
**Status**: DRAFT — pending human approval before execution
**Depends on**: Spike 1.1 (Windows/Linux STT survey — Sherpa-ONNX recommended primary), Spike 1.3 (Sherpa-ONNX integration PoC — confirmed viable)
**Related**: Phase 1 STT work (`SherpaOnnxSttEngine` scaffold in `zip_core`), ADR-005 (pluggable STT engines), roadmap Phase 8 translation spikes (latency budget context)

---

## Scope

Evaluate **Cactus Compute's Whistle** ([HuggingFace](https://huggingface.co/Cactus-Compute/whistle), [GitHub](https://github.com/cactus-compute/needle), Apache-2.0) as a candidate `SttEngine` implementation (`WhistleSttEngine`) for the on-device, private, offline engine tier — and measure it head-to-head against the existing Sherpa-ONNX path on low-spec hardware.

Whistle is a 16.9 MB, 2-bit-quantized, CPU-only streaming ASR model covering 7 languages (en, de, fr, es, it, nl, pl) in a single `.cact` file, run by Cactus's C++ engine (prebuilt per-platform static libraries + a C API, plus a WASM build for browsers). This spike answers whether it is viable as a user-selectable offline engine, specifically for **low-spec hardware** and **web (PWA fallback)**.

This is a research spike: measurement code is throwaway (branch `spike/1.4-*`, never merged, per Q5:A convention). No changes to `SttEngine`, `SttResult`, or the caption bus. No production code.

---

## Background (findings already in hand, not re-tested here)

From pre-spike research (2026-10-20, vendor-published data only — nothing below is measured):

- **Whistle**: 16.9 MB single file; 7 languages with auto-detect or forced; streaming via two-pass agreement (committed text is stable); per-word timestamps (80 ms resolution); keyword biasing (vendor reports B-WER 18.43 → 4.46 with a 100-word list; mechanism is an Aho-Corasick automaton, same family as sherpa-onnx hotwords); decoder depth ladder 2–8 selectable at load (vendor M4 Pro: depth 8 = 4.75 WER @ 1,182 tok/s, depth 2 = 7.66 WER @ 2,557 tok/s — note the ladder is decoder-only: the 8-block encoder runs at every depth); 11.1 ms TTFT per 10 s pass on M4 Pro; C API: `needle_load`, `needle_transcribe`, `needle_stream_transcribe_process`, `needle_stream_transcribe_stop`, `needle_embed`.
- **Vendor-published WER** (full test splits, Whisper normalizers): LibriSpeech test-clean 4.31, test-other 10.49, SPGISpeech 7.65, Earnings-22 19.01, AMI 26.07 / cleaned 22.87, TED-LIUM 7.61, FLEURS 7-lang avg 21.4, MLS 24.9. Comparison set: Whisper base (145.3 MB) and Moonshine tiny v2 (41.9 MB).
- **Built-in silence gate**: the engine measures clip loudness before decoding and returns an empty transcript below threshold without entering beam search — no external VAD is needed for silence/noise, though the vendor still recommends a VAD or wake word in front of always-on mics (music can still produce text).
- **Fine-tuning path for new languages**: LoRA adapters, base frozen, merged to a new `.cact`. Vendor example: Brazilian Portuguese from ~10 h of FLEURS went 106.2% → 30.5% WER and was detected correctly; unseen scripts (Cyrillic, Arabic, CJK) need far more data. This is a route to languages beyond the 7 (e.g., pt, uk) if the project ever wants them from this engine.
- **Telemetry — mostly resolved, one verification left**: the vendor's Python docs state the anonymous usage counts (function name, package version, OS, random install id — never prompts, outputs, or data) live in the Python package layer, switchable via `NEEDLE_TELEMETRY=0` / `DO_NOT_TRACK=1`; the Whistle launch post states the C++ engine "reads no environment variables" and is deterministic, and the devices guide states of the native folders "nothing in it phones home." The GitHub README's "telemetry is turned on in the binary" line most plausibly refers to the CLI runner, not `libneedle.a`. Q1 below still verifies the linked-library path at the network level before any further investment, but the prior has shifted from "open question" to "expected clean."
- **Sherpa-ONNX baseline**: official Flutter package, streaming Zipformer models, integration scaffold already in `zip_core` (`SherpaOnnxSttEngine` + `OnlineRecognizerAdapter` seam). Streaming pretrained models exist mainly for en/zh/fr/ko/bn/ru — **not** for de/es/it/nl/pl. The offline model zoo is much broader than the streaming one (full findings in the next section): Parakeet TDT 0.6B v3 (25 European languages, ~640 MB int8), Omnilingual ASR 300M (1600+ languages, 348 MB int8), per-language NeMo/Moonshine v2 models, Whisper ONNX, and a medical-English model (MedASR). The Flutter package exposes `OfflineRecognizer` + `VoiceActivityDetector`, so all of these are reachable from `zip_core` with a VAD-chunked "simulated streaming" path.
- **Project constraints**: transcripts never leave the device (SECURITY-03); < 1 s perceived latency exit criterion (Phase 1); web is a Fallback-tier platform with no viable offline STT today.

---

## Sherpa-ONNX Language Coverage — Findings (2026-10-20)

Answer to the parallel question "how do we support the languages we want with sherpa_onnx", from the indexed sherpa-onnx docs (https://k2-fsa.github.io/sherpa/onnx/index.html) plus the sherpa-onnx model list. Target languages for v1 (7): en, de, fr, es, it, nl, pl — with ar, id, pt, uk as v1 UI languages currently with no on-device path.

**Streaming models (the current `SherpaOnnxSttEngine` path) cannot cover the gap.** Pretrained streaming Zipformer models exist for en, zh, fr, ko, bn, ru, ja only. No community icefall streaming models exist for de/es/it/nl/pl (checked HuggingFace). So the language strategy must use sherpa-onnx's **offline model zoo with Silero VAD chunking** — the same "speech recognition from a microphone with VAD" pattern sherpa-onnx documents for every offline family, all reachable via the `OfflineRecognizer` + `VoiceActivityDetector` classes already in the `sherpa_onnx` Flutter package.

### Candidate models for the 7 target languages

| Model | Languages | Size (int8) | Evidence | Streaming mode | Hotwords | License |
|---|---|---|---|---|---|---|
| **Parakeet TDT 0.6B v3** (`sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8`) | 25 European, incl. all 7 + pt/uk; auto-detect | ~640 MB (enc 622 M + dec 12 M + joiner 6.1 M) | FLEURS WER: de 5.04, es 3.45, fr 5.15, it 3.00, nl 7.48, pl 7.31, en 4.85 (better than Whistle's 21.4 7-lang avg); punctuation + capitalization; word timestamps | VAD-chunked (pseudo-streaming); Android APK exists as proof | Yes (transducer model, `modified_beam_search`) | CC-BY-4.0 (upstream nemo) |
| **Omnilingual ASR 300M** (`sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-int8-2025-11-12`) | 1600+ — covers all 7 + ar/id/pt/uk/zh | 348 MB | Broadest coverage; per-language quality not published by sherpa; Dart + WASM npm examples exist | VAD-chunked; mic + VAD variant published | No (CTC) | **Verify** — facebookresearch/omnilingual-asr license (project has premium features; non-commercial license would disqualify) |
| **NeMo fast-conformer CTC 10-lang** (`sherpa-onnx-nemo-fast-conformer-ctc-be-de-en-es-fr-hr-it-pl-ru-uk-20k`) | de, en, es, fr, it, pl, ru, uk, hr (+be) — missing nl | not recorded | Exists in the published model list | VAD-chunked | No (CTC) | Verify (NeMo license) |
| **Whisper ONNX** (tiny → large-v3, 99 langs) | All of them, at any size | 75 MB (tiny) → 1.6 GB (large-v3) | tiny.en has a documented "RTF on Raspberry Pi 4 Model B" section (number not captured) | VAD-chunked | No | MIT (openai) |
| **Moonshine v2** (quantized per-language base models: ar, es, uk, en, zh, ja, ko, vi) | 8 langs — useful for ar/es/uk only | per-language (small) | Published 2026-02-27, 8-bit; Android APKs; full API matrix | VAD-chunked | No | Verify (canvasecurity) |
| Per-language NeMo fastconformer hybrids (de, pt) | 1 lang each | ~large | `sherpa-onnx-nemo-stt_de_fastconformer_hybrid_large_pc-int8` (+ transducer variant) | VAD-chunked | transducer variant yes | Verify |
| **MedASR** (`sherpa-onnx-medasr-ctc-en-int8-2025-12-25`) | English medical | not recorded | Medical-domain English — directly relevant to the medical-vocabulary persona | VAD-chunked | No | Verify |

### Performance reference point (vendor, same architecture)

Parakeet v2 RTF on RK3588 (Cortex-A76, 4 cores — a better device than Pi 5's A76): 0.220 @ 1 thread, 0.142 @ 2, 0.118 @ 3, 0.088 @ 4. That means ~0.9–2.2 s of decode per 1 s of audio depending on thread count — VAD-chunked latency budget needs verification on the actual target (Q7).

### Recommendation (to be validated by Q7)

- **Parakeet TDT 0.6B v3 int8 is the recommended Sherpa-side answer for de/es/it/nl/pl** (and fr, en as a quality option): it covers every v1 target language in one download, auto-detects language, emits word timestamps + punctuation, supports hotwords (transducer), has the best published WER of the candidates, and the existing `sherpa_onnx` Flutter package already exposes the required classes. Integration shape: extend the on-device engine path with an `OfflineRecognizer` + Silero VAD "sentence" mode (utterance → recognize → emit final) — this is a new code path in `zip_core`, not an interface change (ADR-005 boundary untouched).
- **Omnilingual 300M is the fallback for the long tail** (ar/id/pt/uk/zh and beyond) **if its license permits commercial use**; otherwise Whisper ONNX small (MIT) is the permissive broad-coverage fallback at the cost of quality and size.
- **Whistle remains the size/low-spec champion** (16.9 MB vs 348–640 MB) — the two engines are complementary, not competing, which is the premise of the head-to-head in this spike.

---

## Questions to Answer

| # | Question | Drives |
|---|----------|--------|
| Q1 | Is the `libneedle.a` library path (the path we would link via `dart:ffi`, not the CLI runner) network-silent and deterministic? | Go/no-go for Whistle in this project |
| Q2 | On a low-spec target device, does Whistle (depth 8 / 4 / 2) meet the < 1 s perceived-latency budget for live captioning, and what are its WER, RTF, and peak RAM? | "Runs well on low-spec hardware" claim; depth default per device class |
| Q3 | How does Whistle compare to Sherpa-ONNX on the same device, same audio, for (a) English streaming captioning and (b) a second language (French)? | Engine picker roles; which is the default on-device engine |
| Q4 | Does keyword biasing materially improve domain-vocabulary accuracy (medical/technical terms) on the target device, at what cost to other words? | Whether a "frequent words" setting is worth building |
| Q5 | Is a minimal `dart:ffi` binding to the Whistle C API tractable on one platform (macOS or Linux), including the streaming call sequence? | Integration-effort estimate for a future `WhistleSttEngine` unit |
| Q6 | Does the WASM build (`needle.js` + `needle.wasm`) transcribe mic audio in a real browser at usable latency, with what memory footprint? | Whether web offline STT is a credible Fallback-tier feature |
| Q7 | Is Parakeet TDT 0.6B v3 (the recommended Sherpa-side multilingual model) viable on the target device in VAD-chunked mode — per-utterance latency, WER (fr + en minimum), peak RAM, thread-count sensitivity? | The Sherpa multilingual strategy; whether "offline + VAD sentence mode" is a real engine-picker option |

---

## Exit Criteria

The spike is complete when:

1. Q1 is answered with evidence (network-level observation of the library path, or a clear determination that the runner and library share the behavior), and a verdict is recorded.
2. Q2 is answered with measurements from at least one low-spec ARM device (target: Raspberry Pi 5; fallback: oldest available ARM laptop/phone), at depths 8, 4, and 2: first-word latency, RTF, peak RAM, per-pass time on the streaming path.
3. Q3 is answered with a same-device, same-audio comparison table (Whistle vs. Sherpa-ONNX, English + French) including WER and latency.
4. Q4 is answered with before/after WER on a domain-vocabulary audio set with a keyword list (≥ 50 words) vs. without.
5. Q5 is answered with a working minimal FFI transcript on one desktop platform (or a documented blocker).
6. Q6 is answered with a browser mic-capture run (or a documented blocker, e.g. permission/sandbox limits).
7. Q7 is answered with a Parakeet TDT 0.6B v3 VAD-chunked run on the target device (latency, WER fr+en, peak RAM, 1 vs 4 threads), or a documented blocker (e.g. download/size limits on the device).
8. A report is written to `aidlc-docs/construction/spikes/spike-1.4-report.md` with: measurement tables, a recommendation on (a) whether `WhistleSttEngine` should be scheduled as a unit, (b) its role in the engine picker, (c) depth defaults per device class, and (d) follow-ups (VAD/endpointing design, model-download management, `SttResult` word-timestamp extension decision).

---

## Methodology

### Hardware

| Role | Device | Why |
|---|---|---|
| Low-spec target | Raspberry Pi 5 (ARM64, linux-arm64 build) | Cheapest realistic always-on captioning box (S2.5 remote-captioning-machine context); `linux-arm64` folder exists for Whistle and for `sherpa_onnx` |
| Reference | Maintainer's current laptop (macOS, Apple Silicon) | Baseline sanity; vendor numbers to validate against |

If the Pi 5 is unavailable, the fallback target is the oldest ARM device in the maintainer's possession, and the report must state the substitution.

### Audio set

~10–20 clips, ~30–60 s each, with reference transcripts (Whisper-normalized scoring):

- **English clean**: 4–6 clips (single speaker, calm room; include one lecture-style and one conversational pair)
- **French clean**: 3–4 clips (covers the Québec/auditorium personas; source: existing test fixtures in `test-fixtures/` if sufficient, else recorded)
- **Domain vocabulary**: 2–3 clips containing medical/technical terms (names, drug names, procedure words); the keyword list for Q4 is derived from these terms plus ~50 common names
- **Adversarial**: 1–2 noisy-background clips (optional; informative, not gating)

Audio must be 16 kHz mono PCM16 (both engines consume this). No test audio may be shared with any vendor service — all runs are local and offline (this also serves Q1: the low-spec runs happen on a machine that can be fully air-gapped, so any observed network activity during a library-linked run is by definition suspicious).

### Whistle runs

- `needle build --platform linux-arm64` (and `macos-arm64` for reference) + `needle download whistle`
- Batch mode: `needle --model whistle.cact --audio clip.wav --audio-word-timestamps` at `--audio-depth` 8 / 4 / 2
- Streaming mode: `--audio-stream` on a mic or a piped real-time stream, recording per-pass `pass_ms`, committed vs. pending text timing, and first-word latency
- Keyword runs: same clips with and without a `--audio-keywords`-equivalent list (verify exact flag name at run time; the Python API uses `keywords=[...]`)
- WER scored with the Whisper normalizer (use the reference scorer from the `whisper` python package or an equivalent normalization table)
- Record the engine's self-reported `ttft_ms`, `decode_tps`, `peak_ram_mb` (reported per response where available; otherwise `peak`/`/usr/bin/time -v`)

### Sherpa-ONNX runs

- Official `sherpa_onnx` package (or the project's existing `OnlineRecognizerAdapter` path) with the streaming English Zipformer model (the largest int8 streaming en model available)
- Same clips, same device, same metrics: first-word latency, RTF, peak RAM, WER
- For the French comparison: use whatever streaming option exists (per the pre-spike survey, none for fr beyond `shaojieli/sherpa-onnx-streaming-zipformer-fr-2023-04-14`); if that model is unusable on the target, use the best available fr option and flag the streaming gap explicitly — that gap is itself a finding for the engine-picker design
- **Q7 — Parakeet TDT 0.6B v3 int8 in VAD-chunked mode** (via the `OfflineRecognizer` + `VoiceActivityDetector` classes of the `sherpa_onnx` package, mirroring the documented "mic + VAD" pattern): run the same English + French clips as VAD-segmented utterances on the target; measure per-utterance decode time, first-word (i.e., end-of-utterance) latency vs. the < 1 s budget, peak RAM, and RTF at 1 vs 4 threads. This validates the recommended Sherpa multilingual path from the findings section; it is a **separate data track** from the streaming A/B (Q3) and does not replace it

### Q1 telemetry procedure

1. Run the library-linked path (a tiny C test program linking `libneedle.a`, or the FFI probe from Q5 — whichever exists first) on the air-gapped target.
2. Observe at the network level: `tcpdump` on all interfaces, plus a DNS/firewall drop-all rule; confirm zero outbound attempts during load, transcribe, and stream.
3. Repeat with the stock `needle` CLI runner for comparison (expected: telemetry behavior per README; this characterizes which component the README statement refers to).
4. If the library path shows outbound activity: record it, then re-run with source build (repo is Apache-2.0) with telemetry compiled out, and re-test. Verdict is on the path we would actually ship.

### Q5 FFI probe (one platform only)

- Minimal Dart package: `dart:ffi` binding for `needle_load` + `needle_transcribe` + `needle_stream_transcribe_process`/`stop`, linking the platform `libneedle.a`
- Success = transcribe one clip and one short stream from Dart on macOS or Linux and print result shape (text, language, ttft, decode tps, word timestamps)
- No `SttEngine` implementation in this spike — the probe is a feasibility + effort estimate only

### Q6 WASM probe

- Standalone HTML page loading `needle.js` + `needle.wasm` + `whistle.cact` from the published `wasm` folder
- `getUserMedia` mic capture at 16 kHz, feed to the streaming API, measure first-word latency and JS heap / WASM memory in Chrome and Safari
- Document any browser permission or audio-sandbox blockers verbatim

### Measurement hygiene

- 3 runs per configuration, median reported (vendor did 100-run medians for depth table; 3 is a spike, state the confidence)
- Record exact model file hashes, engine version, OS, and firmware in the report
- Never log transcript text anywhere in the harness output (SECURITY-03) — log only metrics and per-word error counts, not words. (The reference transcripts themselves live in the throwaway spike branch only, with the caveat noted in the report; if they contain real names/medical terms from recordings, prefer synthetic domain-vocabulary scripts read aloud.)

---

## Deliverables

1. `aidlc-docs/construction/spikes/spike-1.4-report.md` — measurement tables, verdicts per Q, recommendation section
2. Throwaway harness on `spike/1.4-on-device-stt-eval` (never merged): measurement scripts, FFI probe, WASM page
3. Recommendation to the project (in the report):
   - `WhistleSttEngine` unit: schedule / hold / drop, with integration-effort estimate (FFI bindings × ~6 platforms + WASM path + model download management)
   - Engine-picker roles: default on-device engine per platform; Whistle's label and settings surface (depth = "quality vs speed")
   - Depth defaults per device class
   - Follow-up list: VAD/endpointing design, `SttResult` word-timestamp extension (ADR-005 boundary — discussion required), web offline STT scope decision, Sherpa-ONNX multilingual strategy (from the parallel investigation)

## Risks and Open Questions

- **Telemetry** — vendor docs now point at the Python package layer (no data ever, opt-out env vars) and state the C++ engine is deterministic and the native folders "phone home" to nothing; Q1 confirms this at the network level on the exact path we would link. Worst case, a source build is required, which adds an engineering burden to the recommendation.
- **Single low-spec device** — one Pi-class data point may not generalize to low-end phones; the report will flag this and, if results are close to the 1 s budget, recommend a phone confirmation run.
- **Vendor benchmark conditions** — published WER numbers use vendor harnesses; our WER on the same published test splits (LibriSpeech test-clean, FLEURS fr subset) will validate the direction even if not the exact values.
- **Streaming UX gap** — Whistle has no built-in utterance endpointing (it has a silence gate and sentence-based windowing, but no endpoint rules like sherpa-onnx's); if first-word latency is fine but segmentation behavior is poor for live captions, the integration needs a VAD/endpointing layer (scope note for the future unit).
- **Spike budget** — seven questions is a lot for one spike. If time is short, priority order is Q1 → Q2 → Q3 → Q7 → Q4 → Q5 → Q6; Q6 (WASM) can be descoped to "runs in browser, latency not measured" without invalidating the core verdict, and Q7 can be run on the reference machine only if the target's RAM cannot hold a ~640 MB model (the RK3588 RTF numbers then stand as the low-spec estimate, flagged as such).

## Out of Scope

- Implementing `WhistleSttEngine` (that is a construction unit, gated on this spike)
- Any modification to `SttEngine`, `SttResult`, caption bus, or `docs/` (roadmap entry happens via Documentation Refinement after approval)
- Needle (the text-model sibling) beyond noting it shares the runtime
- Cloud STT providers, translation engines, and Phase 8 work
