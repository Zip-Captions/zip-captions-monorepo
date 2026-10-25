# On-Device ASR Model Survey (Hugging Face candidates) — 2026-10-25

**Status**: Research note. Not a spike report: nothing here was run or measured by the project. All figures are vendor-published or third-party and are flagged as such. Feeds Spike 1.4 (Q8) and the revision proposal in `../on-device-multilingual-stt/execution-plan.md`.

**Question**: can Hugging Face ASR models, starting with `nvidia/nemotron-3.5-asr-streaming-0.6b` and `mistralai/Voxtral-Mini-4B-Realtime-2602`, become on-device `SttEngine` implementations?

## Verdict

| Model | Verdict | One-line reason |
|---|---|---|
| Nemotron 3.5 ASR Streaming 0.6B | **Strong candidate** | Officially supported by sherpa-onnx as a true streaming transducer; fits the existing `SherpaOnnxSttEngine` path |
| Voxtral Mini 4B Realtime | **Not viable now** | ~4B parameters, ~9 GB BF16, GPU/vLLM-oriented; no sherpa, ONNX or GGUF runtime found |

## Nemotron 3.5 ASR Streaming 0.6B (NVIDIA, OpenMDW-1.1)

- Architecture: 24-layer cache-aware FastConformer encoder, RNN-T decoder, language-ID prompt. Chunk sizes 80/160/320/560/1120 ms. Punctuation and capitalisation. Derived from the English Nemotron streaming model.
- Languages: 40 locales. Transcription-ready (19): English, Spanish, French, Italian, Portuguese, Dutch, German, Turkish, Russian, Arabic, Hindi, Japanese, Korean, Vietnamese, Ukrainian. Broad-coverage (13), including Polish, Swedish, Czech, Danish, Finnish, Croatian, Slovak, Mandarin, Hungarian, Romanian, Estonian, Bulgarian, Norwegian Bokmål. Adaptation-ready (8) need fine-tuning. Indonesian is not listed.
- sherpa-onnx support (indexed sherpa-onnx docs, page `nemo/nemotron-streaming`): int8 builds dated 2026-06-11 (multilingual) and 2026-04-25 (English). Builds listed at 80/160/560/1120 ms; the card also lists 320 ms. Size at 560 ms: encoder ~627 MB, decoder ~14 MB, joiner ~9.1 MB, about 650 MB total. Language is set per stream (`SetOption("language", ...)`), empty or `auto` detects; sherpa strips the `<en-US>`-style tags in auto mode. Prebuilt Android APKs exist, including QNN builds for Snapdragon.
- Version notes: sherpa-onnx 1.13.5 release notes list the Nemotron re-export; 1.13.6 fixes greedy decoding for NeMo streaming transducers. A third-party desktop app reports it needs ≥ 1.13.4 for accurate decoding. The project lockfile resolves `sherpa_onnx` 1.12.36; the local pub cache also holds 1.13.8, where Dart `OnlineStream.setOption` exists.
- Speed: the sherpa doc run for the English sibling reports RTF 0.16 on one thread (hardware not stated). No phone benchmark found. An arXiv paper reports ONNX CPU numbers for a compact English variant (int8 RTFx 7.25, batch 1), desktop-class only.
- FLEURS WER from the model card (vendor-published, text-normalisation caveats), LangID, 80 ms → 1.12 s: en 9.4 → 7.9, de 9.8 → 8.3, fr 11.0 → 9.0, es 4.9 → 4.1, it 5.2 → 4.3, nl 14.0 → 11.5, pl 19.9 → 15.2, pt 6.3 → 5.5, uk 15.7 → 13.1, ar 13.2 → 12.0.
- Compared with Parakeet TDT v3 (spike-1.4-plan.md, vendor, offline, CC-BY-4.0): lower published WER for nl 7.5, pl 7.3, de 5.0, but chunk-decoded rather than streaming. Different test protocols; not directly comparable.
- License: OpenMDW-1.1; the card says "ready for commercial use". **The license text was not read.** Exit item in Spike 1.4 (7a).
- Risks: ~650 MB download and unmeasured phone RAM/thermals; sherpa's Flutter README says the iOS example must be built from source (unresolved); Dutch and Polish are weaker than Parakeet's published figures.

## Voxtral Mini 4B Realtime 2602 (Mistral, Apache-2.0)

- ~3.4B-parameter LM plus ~970M causal audio encoder, ~4B total, BF16 safetensors (~9 GB). Configurable transcription delay 240 ms to 2.4 s (480 ms recommended). 13 languages. FLEURS average WER 8.72% at 480 ms (vendor).
- Runtimes: vLLM (recommended), Transformers ≥ 5.2.0; ExecuTorch listed as untested. Card asks for ≥ 16 GB GPU memory in BF16. Community ports exist: a pure-C implementation (`antirez/voxtral.c`, Metal backend; secondary sources report ~2.5× real time on an M3 Max, unverified), MLX, Rust. No sherpa-onnx, ONNX or GGUF/llama.cpp support found.
- Fit: not viable on phones; marginal on 16 GB+ Apple Silicon; would need a custom FFI runtime per platform. Revisit if a quantised GGUF/ONNX runtime with Flutter bindings appears.

## Other candidates (brief)

| Candidate | Notes |
|---|---|
| Whistle (Cactus, 16.9 MB, 7 languages, Apache-2.0) | Already in Spike 1.4 (Q1–Q6). Custom FFI. |
| Moonshine v2 streaming (tiny/small/medium, MIT) | Small, CPU-only, launched Feb 2026; per-language models; GGUF builds target a different runtime (transcribe.cpp). Hallucination warning on the model card. |
| Parakeet EOU 120M via FluidAudio / `fluidaudio_dart` | CoreML on the Apple Neural Engine, streaming, English only, iOS 17+ / macOS 14+, wrapper pre-1.0. App minimum is iOS 13. |
| Apple SpeechAnalyzer (iOS 26+) | Platform API without the ~1-minute `SFSpeechRecognizer` session limit (secondary sources); iOS 26 only. Belongs to the platform-engine path (Unit 10 area). |
| Kyutai STT 1B (en/fr) | MLX/Rust only. Skip. |

## Repo findings that apply to any sherpa model (read 2026-10-25, working tree of an in-progress session; re-verify against `develop`)

- `SttEngine` needs no interface change for a new engine; engines register by id in `SttEngineRegistry`.
- `SherpaOnnxSttEngine` is a scaffold: `initialize()` is a placeholder, `feedAudio(pcm16)` has no caller.
- No raw PCM capture exists: `record: ^5.1.2` is declared in `zip_core` but not imported. A shared capture service (16 kHz mono PCM16) is a prerequisite for any sherpa engine.
- No real engine is registered in either app (gap G10, Unit 10 is addressing it for `PlatformSttEngine`).

## Sources

- https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b
- https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602
- https://k2-fsa.github.io/sherpa/onnx/nemo/nemotron-streaming.html (via docs-mcp `sherpa-onnx` index)
- https://github.com/k2-fsa/sherpa-onnx/releases (v1.13.5, v1.13.6 notes, via search results)
- https://pub.dev/packages/sherpa_onnx
- https://arxiv.org/pdf/2604.14493
- https://openwhispr.com/blog/local-streaming-speech-to-text (third-party)
- https://github.com/antirez/voxtral.c (via secondary write-ups)
- https://github.com/FluidInference/FluidAudio, https://pub.dev/packages/fluidaudio_dart
- https://petewarden.com/2026/02/13/announcing-moonshine-voice/
