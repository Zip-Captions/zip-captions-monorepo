# Domain Entities — On-Device Multilingual STT

Shapes as fixed at this stage. `zip_core` conventions: freezed for state/model classes, `riverpod_generator` for providers, one public class per file, barrel-exported.

## `MultilingualSttEngineConfig` (new, freezed — Q7 answer A)

The one new **public** domain entity of this unit. Injected into `MultilingualSttEngine` (and the adapter's `initialize`); persisted with the other engine settings if the NFR stage so decides. This is the seam the NFR stage tunes and the future hotwords/Whistle units reuse.

```dart
@freezed
class MultilingualSttEngineConfig {
  // Model files (resolved from the catalog entries' localPath at initialize).
  required String modelDirectory;   // extracted ASR model directory
  required String vadModelPath;     // silero_vad.onnx

  // Runtime.
  required int numThreads;                    // NFR stage sets per device class
  required String decodingMethod;             // e.g. 'greedy_search' (verify against pub-cache source)

  // VAD (Silero).
  required double vadThreshold;               // NFR stage
  required Duration vadMinSilenceDuration;    // NFR stage
  required Duration vadMinSpeechDuration;     // NFR stage (also Rule 7's flush threshold)

  // Simulated-streaming cadence (Rule 3, Rule 4) — NFR stage sets the values.
  required Duration interimCadence;           // new audio before the next interim decode
  required Duration maxSegmentDuration;       // force-cut; null-equivalent via a very large value if the binding lacks a native max
  required Duration minBufferForFirstInterim; // gate on the first interim

  // Forward seam (no v1 consumer; Rule: v1 ships no hotword source).
  String? hotwordsFile;
  double hotwordsScore;                       // default 1.5, the sherpa default
}
```

Name is a proposal; final naming settles at Code Generation. The exact VAD/decode config fields are verified against the pub-cache `sherpa_onnx` source at Code Generation Part 1 (the project's plugin-claim verification convention) — the C++ `SileroVadModelConfig`/`OfflineRecognizerConfig` dumps in the indexed docs are the reference shape.

## `SherpaModelCatalogEntry` extension (existing, additive — Q6 answer A, Rule 11)

Current shipped shape (`packages/zip_core/lib/src/models/sherpa_model_catalog.dart`, verified by reading): `modelId`, `displayName`, `primaryLocaleId` (required String), `downloadSizeBytes`, `downloadUrl`, `sha256Checksum`. The catalog **response envelope carries `schemaVersion` (default 1)** — the extension therefore adds only **optional** fields so existing v1 catalogs parse unchanged:

```dart
// Additive, all optional for schema-1 compatibility:
@Default([]) List<String> localeIds;   // locales served by this download; the multilingual
                                       // entry lists all 25. primaryLocaleId stays required
                                       // (first locale) until existing consumers migrate.
SherpaModelKind? kind;                 // model family discriminator (below)
String? engineId;                      // which SttEngine this entry participates in (below)
```

- `primaryLocaleId` remains required in v1 of this unit (existing consumers — `SherpaOnnxSttEngine.supportedLocales()`, the catalog UI — read it; the new engine reads `localeIds` natively, falling back to `[primaryLocaleId]` when the list is empty, which covers all existing rows).
- `engineId` grouping is what makes Rule 1 data-driven: entries are grouped by `engineId`; an engine is registered iff **all** entries sharing its `engineId` are downloaded, and deleting any one of them unregisters it. The shipped streaming rows carry `engineId: 'sherpa-onnx'` (added to the catalog data at the Infrastructure Design stage, not hardcoded in Dart); the new ASR row and the VAD row both carry the new engine's `engineId`; a `null` `engineId` in a v1 catalog parses as the legacy streaming behavior.
- The two new rows: the Parakeet TDT 0.6B v3 int8 entry (`localeIds` = the 25 languages, `kind: offlineTransducer`, `downloadSizeBytes` ≈ 640 MB — trips the shipped 100 MB confirmation gate automatically) and the `silero_vad.onnx` entry (`localeIds: []`, `kind: vad`, ≈ 2 MB, no confirmation).

## `SherpaModelKind` (new enum)

```dart
enum SherpaModelKind {
  streaming,          // the shipped OnlineRecognizer family (existing rows, explicit)
  offlineTransducer,  // Parakeet TDT family (encoder/decoder/joiner/tokens)
  offlineCtc,         // single-file CTC (Nemo CTC, zipformer-ctc, Omnilingual — future rows)
  offlineWhisper,     // Whisper ONNX (future rows)
  vad,                // Silero VAD support model (no locales)
}
```

The engine builds its recognizer config from `kind` + file layout (the offline-transducer file set is encoder/decoder/joiner/tokens; the exact per-kind file layout is verified against the pub-cache source at Code Generation Part 1). Kinds without a shipping row exist so a later model is a catalog row addition, not a code change (OQ-3).

## `SherpaModelInfo` (existing, unchanged)

`{ catalogEntry, isDownloaded, localPath? }` — the merged catalog + filesystem view the engine consumes: it resolves each of its two entries through `SherpaModelManager` and uses `localPath` for `modelDirectory` / `vadModelPath` (Rule 9 — no network in the engine).

## Engine identity (new engine, Q1 answer A)

| Field | Value |
|---|---|
| class | `MultilingualSttEngine` (name proposal; final at CG) |
| `engineId` | `multilingual-onnx` (name proposal) |
| `displayName` | "Multilingual — on-device" (ARB-backed) |
| `requiresNetwork` | `false` |
| `requiresDownload` | `true` |
| `requiresMicrophone` | `true` |
| `supportedLocales()` | the ASR entry's `localeIds` as `SpeechLocale`s (Rule 5) |

## `OfflineSttAdapter` (new interface — Q2 answer A)

Package-visible (not barrel-exported as a public API surface beyond what the engine and tests need). The operations and the single-segment VAD state (`SegmentState { idle, inProgress, complete }`) are fixed in business-logic-model.md. Real implementation in an io-conditional file over `sherpa_onnx`; hand-written fakes in the test suite; the native library is never loaded in a unit test (the `OnlineRecognizerAdapter` discipline, TEST-U2.2 Q1=A).

## Internal types (Q7 answer A — **not** part of the public barrel surface)

- `SegmentDecodeResult` — the adapter's decode return: `text`, `tokens`/`timestamps` (if the binding exposes them for `nemo_transducer`), `score` (nullable). Consumed only by the engine (Rule 8's confidence mapping) and its tests.
- The in-flight segment buffer (float32 samples + start offset) — owned by the adapter's VAD state; the engine reads it via `currentBuffer()`/`bufferedSeconds()`. Never named outside the adapter/engine files.

## `SttResult` (existing, unchanged — Rule 12, ADR-005 boundary)

Mapping (verbatim from business-rules.md Rule 12): `text` = model transcript with its own punctuation/capitalization; `isFinal` = false (interim) / true (final, flush, or best-effort commit); `timestamp` = now (interim) / segment end (final); `sourceId` = the engine's `engineId`; `confidence` = the binding's score if exposed, else `1`; `speakerTag` = unset. **No word-timestamp field is added** — the ADR-005 extension is a follow-up unit decision.
