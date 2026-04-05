# Spike 1.1 Report: Windows/Linux STT Survey

**Date**: 2026-03-29
**Status**: Complete
**Scope**: Survey all viable STT options for Windows and Linux desktop platforms. Prioritize real-time capabilities with offline functionality.

---

## Executive Summary

Linux has **no platform-native STT API** — every solution requires bundling an external engine. Windows has `Windows.Media.SpeechRecognition` (WinRT) accessible via the `speech_to_text` Flutter package, but its accuracy is moderate and below modern neural models.

Three on-device engines emerged as viable for real-time captioning: **Sherpa-ONNX**, **Whisper.cpp**, and **Vosk**. Of these, **Sherpa-ONNX is the recommended primary engine** for both platforms due to its official Flutter package with Windows + Linux support, native streaming architecture, low latency, small model sizes, and active maintenance.

---

## Platform-Native APIs

### Windows

| API | Accuracy | Streaming | Offline | Flutter Integration | Status |
|-----|----------|-----------|---------|-------------------|--------|
| **SAPI 5** (legacy COM) | Low | Yes, with partials | Yes | High effort (COM/FFI) | Legacy, not improving |
| **WinRT SpeechRecognition** | Moderate | Yes, with partials | Yes (with language packs) | Low (`speech_to_text` pkg) | Active (Windows updates) |
| **Azure Speech SDK** | Excellent | Yes | Cloud-only (embedded requires commercial license) | Medium-high (C++ FFI) | Active, commercial |

**WinRT** is the only practical platform-native option on Windows. Accessible via the `speech_to_text` Flutter package. Accuracy is the main concern — below Apple Speech and modern neural models.

### Linux

| API | Status |
|-----|--------|
| PulseAudio / PipeWire | Audio transport only — NOT speech recognition |
| GNOME / KDE | No built-in STT API. GNOME 45+ has experimental "Speech Provider" but not stable |
| IBus / Fcitx | Input method frameworks, not viable for captioning |

**Linux has no usable platform-native STT API.** Every Linux STT solution requires bundling an external engine. The `speech_to_text` Flutter package does not support Linux.

---

## On-Device STT Engines

### Sherpa-ONNX (k2-fsa)

| Attribute | Detail |
|-----------|--------|
| **Architecture** | ONNX Runtime inference. Streaming transducer (Zipformer), Paraformer, CTC, and Whisper ONNX models |
| **Accuracy** | Very good. Streaming Zipformer models competitive with Whisper `small`. Can also run Whisper ONNX for higher accuracy |
| **Streaming** | Native. True token-level streaming with partial results (50-200ms latency) |
| **Languages** | 15+ with pre-trained streaming models. 99 via Whisper ONNX path |
| **Offline** | Fully offline after model download |
| **Model size** | Streaming transducer: 10-80MB. Whisper ONNX: same as whisper.cpp |
| **Resource usage** | Very light. 100-300MB RAM for streaming models. Runs on low-end hardware |
| **Flutter package** | **`sherpa_onnx` on pub.dev — official, supports Windows + Linux + macOS + iOS + Android** |
| **Integration effort** | **Low.** Pre-built native libraries. Import package, download model, call streaming API |
| **License** | Apache 2.0 |
| **Maintenance** | Very active. Frequent releases, strong academic backing (Kaldi/k2 team) |

### Whisper.cpp

| Attribute | Detail |
|-----------|--------|
| **Architecture** | C/C++ port of OpenAI Whisper. Batch/segment model, not natively streaming. Includes `whisper-stream` example with sliding window and VAD modes |
| **Accuracy** | Excellent. Best open-source accuracy. ~5% WER (medium+), ~7-8% (small), ~12% (tiny) on LibriSpeech |
| **Streaming** | Pseudo-streaming via sliding window (2-5s chunks). Custom partial-results logic required. `whisper-stream` provides sliding window and VAD modes but live streaming can be 5-7x slower than batch on some hardware |
| **Languages** | 99 languages in every multilingual model |
| **Offline** | Fully offline after model download |
| **Model size** | tiny: 75MB, base: 150MB, small: 500MB, medium: 1.5GB, **large-v3-turbo: 1.6GB**, large-v3: 3GB. See model variants below |
| **Resource usage** | Heavy. CPU-intensive during inference. RAM: model size + 200-500MB. Benefits from AVX2/AVX-512, GPU (CUDA/Vulkan/DirectML) |
| **Flutter package** | No official package. Community packages (`whisper_dart`, `whisper_flutter_new`) exist but not production-ready for desktop |
| **Integration effort** | **Medium-high.** Custom FFI to C API. Must build streaming layer, VAD, result stitching |
| **License** | MIT (code and model weights) |
| **Maintenance** | Very active. One of the most active C++ ML projects |

#### Whisper Model Variants (Turbo and Distilled)

Two newer model variants significantly change the Whisper.cpp performance profile:

**Large-v3-Turbo** (OpenAI, supported natively in whisper.cpp):
- 809M parameters (vs 1,550M for large-v3) — decoder layers reduced from 32 to 4
- GGML file size: **1.6GB** (vs ~3GB for large-v3) — roughly half the size
- **~6x faster** than large-v3 at near-equivalent accuracy (within 1% WER of large-v2)
- Fully multilingual (99 languages), same as standard Whisper models
- RTFx of ~216x on optimized hardware — fast enough that chunk-based real-time is viable on modern desktop CPUs
- Minor accuracy degradation on some languages (Thai, Cantonese) vs large-v3, but matches large-v2 quality overall
- **Key implication for live captioning**: With turbo, processing a 3-5s audio chunk can complete in well under 1 second on a modern CPU, potentially bringing whisper.cpp streaming latency into the 500ms-1.5s range (down from 1-3s with standard models)

**Distil-Whisper** (Hugging Face, GGML conversion available):
- `distil-large-v3`: 756M parameters — 50% smaller than large-v3
- **6.3x faster** than large-v3, within 1-1.5% WER on out-of-distribution audio
- GGML format available at `distil-whisper/distil-large-v3-ggml` on Hugging Face
- whisper.cpp support is present but **chunk-based transcription strategy is not fully implemented** — may have sub-optimal quality vs Python distil-whisper
- **Primarily English** — the base `distil-large-v3` is English-focused. Multilingual distilled variants exist for specific languages (e.g., German) but there is no single multilingual distilled model matching Whisper's 99-language coverage
- `distil-small.en` achieves ~2x real-time on mobile hardware (Samsung S24 Ultra)
- **Key limitation**: English-centric. Not suitable as a general multilingual engine. whisper.cpp integration quality is provisional

**Impact on assessment**: Large-v3-turbo is the most significant development — it brings near-large-v3 accuracy at dramatically lower latency and half the model size, while retaining full multilingual support. For Zip Captions, large-v3-turbo makes whisper.cpp a more competitive option for real-time captioning than previously assessed, particularly for users who prioritize accuracy and language breadth over minimum latency. Distil-Whisper is less relevant due to its English focus and provisional whisper.cpp support.

### Vosk

| Attribute | Detail |
|-----------|--------|
| **Architecture** | Kaldi-based CTC/TDNN models. Designed from the ground up for streaming |
| **Accuracy** | Good but below Whisper and Sherpa-ONNX. ~10-15% WER. Weaker on accents and noise |
| **Streaming** | Native. Designed for real-time — partial results at 100-300ms. Best streaming design of any offline engine |
| **Languages** | ~20 languages with pre-trained models |
| **Offline** | Fully offline after model download |
| **Model size** | Small: 50MB, Large: 1-2GB |
| **Resource usage** | Very light. 100-500MB RAM. Designed for embedded/mobile |
| **Flutter package** | `vosk_flutter` on pub.dev — primarily Android/iOS. Windows/Linux support unclear, likely requires custom FFI |
| **Integration effort** | **Medium.** C API exists. Custom FFI bindings needed for Windows/Linux Flutter |
| **License** | Apache 2.0 |
| **Maintenance** | Moderate. Stable but development pace has slowed |

### Not Recommended

| Engine | Reason |
|--------|--------|
| **Coqui STT** (DeepSpeech) | Company shut down late 2023. Archived, no maintenance |
| **PocketSphinx / CMU Sphinx** | Accuracy insufficient for captioning by modern standards |
| **Faster-Whisper / WhisperX** | Python ecosystem — impractical for Flutter integration |
| **Silero STT** | Limited language support, lower accuracy. Silero VAD useful as preprocessing only |

---

## Comparison Matrix

| Criteria | WinRT (speech_to_text) | Sherpa-ONNX | Whisper.cpp | Vosk |
|----------|----------------------|-------------|-------------|------|
| **Windows support** | Yes | Yes (pub.dev pkg) | Yes (custom FFI) | Yes (custom FFI) |
| **Linux support** | **No** | Yes (pub.dev pkg) | Yes (custom FFI) | Yes (custom FFI) |
| **Real-time streaming** | Yes (native) | Yes (native) | Pseudo (chunked) | Yes (native) |
| **Partial results** | Built-in | Built-in | Custom logic needed | Built-in |
| **Accuracy** | Moderate | Very good | Excellent | Good |
| **Latency (partials)** | Low | 50-200ms | 500ms-1.5s (turbo), 1-3s (standard) | 100-300ms |
| **Languages** | 20-30 | 15-99 (model dep.) | 99 | ~20 |
| **Fully offline** | Yes (with packs) | Yes | Yes | Yes |
| **Model size (streaming)** | N/A (OS built-in) | 10-80MB | 75MB-1.6GB (turbo practical range) | 50MB-2GB |
| **RAM usage** | Low | 100-300MB | 200MB-2GB | 100-500MB |
| **Flutter pkg (desktop)** | `speech_to_text` | `sherpa_onnx` (official) | None (community, mobile) | `vosk_flutter` (mobile) |
| **Integration effort** | Low | **Low** | Medium-high | Medium |
| **License** | Proprietary (free) | Apache 2.0 | MIT | Apache 2.0 |
| **Maintenance** | Active (MS) | Very active | Very active | Moderate |

### Weighted Scoring (for live captioning use case)

Weights: Streaming (25%), Accuracy (20%), Integration effort (20%), Offline (15%), Resource usage (10%), Language breadth (10%)

| Engine | Streaming | Accuracy | Integration | Offline | Resources | Languages | **Total** |
|--------|-----------|----------|-------------|---------|-----------|-----------|-----------|
| **Sherpa-ONNX** | 25 | 16 | 20 | 15 | 9 | 7 | **92** |
| **Whisper.cpp (turbo)** | 18 | 20 | 10 | 15 | 7 | 10 | **80** |
| **Vosk** | 25 | 12 | 14 | 15 | 9 | 6 | **81** |
| **WinRT** | 22 | 10 | 20 | 12 | 10 | 7 | **81** |
| **Whisper.cpp (standard)** | 12 | 20 | 10 | 15 | 5 | 10 | **72** |

**Note**: Whisper.cpp with large-v3-turbo scores significantly higher than standard Whisper models due to the ~6x speed improvement bringing chunk latency closer to real-time. It still scores below Sherpa-ONNX due to the non-native streaming architecture and higher integration effort, but the gap has narrowed considerably.

---

## Recommendation

### Primary: Sherpa-ONNX

**Sherpa-ONNX is recommended as the primary on-device STT engine for Windows and Linux.** Rationale:

1. **Only option with an official Flutter package supporting both Windows and Linux** — lowest integration effort
2. **Native streaming** with partial results maps directly to `SttEngine` / `SttResult` contract (ADR-005)
3. **Smallest streaming model sizes** (10-80MB) — fast download, low storage impact
4. **Very low resource usage** — compatible with running alongside OBS (Jordan's use case, NFR-1.3)
5. **Apache 2.0 license** — no restrictions
6. **Very active maintenance** with academic backing

### Secondary: Whisper.cpp (with large-v3-turbo)

**Whisper.cpp is recommended as an optional high-accuracy engine, particularly with the large-v3-turbo model.** Rationale:

1. Best raw accuracy among all open-source options
2. 99 languages with no separate downloads — broadest language coverage
3. **Large-v3-turbo dramatically improves viability**: 809M params (vs 1,550M), 1.6GB model (vs 3GB), ~6x faster than large-v3, near large-v2 accuracy. Chunk-based latency drops to 500ms-1.5s range on modern CPUs
4. Suitable for users who prefer accuracy and language breadth over minimum latency
5. Non-streaming architecture remains a limitation but is much more manageable with turbo-class models
6. **Distil-Whisper** (`distil-large-v3`) offers 6.3x speedup but is primarily English-only and has provisional whisper.cpp support — not recommended as a general engine

### Fallback: Platform-native via `speech_to_text`

**`speech_to_text` (WinRT) serves as the zero-download fallback on Windows.** Works immediately without model download. Not available on Linux.

### Not recommended as primary: Vosk

Vosk has excellent streaming design but lower accuracy than Sherpa-ONNX, less active maintenance, and no official Flutter desktop package. Sherpa-ONNX supersedes it on all dimensions except streaming latency (where both are excellent).

---

## Recommended Engine Strategy for Phase 1

| Platform | Default Engine | Additional Engines |
|----------|---------------|-------------------|
| iOS | `PlatformSttEngine` (Apple Speech via `speech_to_text`) | — |
| Android | `PlatformSttEngine` (Google on-device via `speech_to_text`) | — |
| macOS | `PlatformSttEngine` (Apple Speech via `speech_to_text`) | `SherpaOnnxSttEngine` (optional) |
| Windows | `PlatformSttEngine` (WinRT via `speech_to_text`) | `SherpaOnnxSttEngine` (recommended download) |
| Linux | `SherpaOnnxSttEngine` (default — no platform-native option) | `WhisperSttEngine` (optional high-accuracy) |
| Web | `PlatformSttEngine` (Web Speech API via `speech_to_text`, best-effort) | — |

This satisfies the Phase 1 exit criterion: "At least two STT engine options available on at least one platform (e.g., platform-native + Whisper on macOS)."

---

## Spike 1.3 Recommendation

Based on these findings, **Spike 1.3 should focus on Sherpa-ONNX** (not Whisper.cpp as originally considered):

1. Integrate the `sherpa_onnx` Flutter package on Windows or Linux
2. Test with a streaming transducer model (e.g., English Zipformer)
3. Validate: initialization, start/stop, pause/resume semantics, locale selection, `SttResult` output
4. Measure: real-world accuracy, latency for partial results, memory usage, model download size
5. Confirm that the engine can implement the full `SttEngine` interface contract

A secondary Whisper.cpp FFI investigation can be scoped as an optional extension of Spike 1.3 or deferred to construction Unit 2 if time allows.

---

## Caveats

This research is based on training data through May 2025. Before finalizing implementation decisions, verify:

1. Current `sherpa_onnx` Flutter package version and stability on pub.dev
2. Current `speech_to_text` Windows support maturity
3. Whether new Flutter STT packages have emerged
4. Whisper.cpp streaming improvements since mid-2025
5. Sherpa-ONNX model availability for target languages
