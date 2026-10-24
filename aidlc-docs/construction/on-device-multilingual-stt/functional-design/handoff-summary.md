# Handoff: Functional Design -> NFR Requirements
**Unit**: on-device-multilingual-stt
**Date**: 2026-10-20

## Decisions Made
- New `SttEngine` (`multilingual-onnx`, class `MultilingualSttEngine` — names settle at CG) using sherpa-onnx **simulated streaming**: VAD segments + periodic interim re-decodes of the whole buffer + final decode at VAD end-of-speech. (Q1)
- One `OfflineSttAdapter` seam (mirrors `OnlineRecognizerAdapter`); fakes in unit tests, native lib never loaded in tests. (Q2)
- One in-progress segment slot; interims replace the trailing line, exactly one final commits it; no caption-pipeline changes. (Q3)
- Interim cadence, max-segment force-cut, min-buffer-for-first-interim, and all VAD/decode params are `MultilingualSttEngineConfig` fields whose **values are set at the NFR stage from Spike 1.4 Q7 measurements** (interim update latency at 1 s / 2 s cadences over 5/10/20 s utterances, final latency vs the < 1 s budget, peak RAM, RTF 1 vs 4 threads). (Q4)
- Auto-detect only in v1; `localeId` ignored for decoding; `supportedLocales()` = the catalog entry's `localeIds`. (Q5)
- Catalog entry extended additively (optional `localeIds`, `kind`, `engineId`) for schema-1 compat; engine registered iff all entries sharing its `engineId` are downloaded; deleting any unregisters. (Q6, Q10)
- Fail-soft: init failure -> unavailable; interim failure -> drop update; final failure -> best-effort commit (last good interim or drop). `pause()` discards buffer; `stopListening()` flushes only >= minSpeechDuration. (Q9)

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
| `MultilingualSttEngineConfig` | new freezed, public | The only new public entity; NFR pins every runtime value (threads, VAD params, cadence, max segment, min buffer) |
| `MultilingualSttEngine` | new `SttEngine` impl | `SttResult` contract fixed (Rule 12); ADR-005 boundary untouched; no word timestamps |
| `OfflineSttAdapter` | new interface (package-visible) | `initialize / acceptWaveform / segmentState / currentBuffer / bufferedSeconds / decode / reset / dispose` |
| `SherpaModelCatalogEntry` | existing, +3 optional fields | schema-1 compatible; `primaryLocaleId` stays required |
| `SherpaModelKind` | new enum | `streaming / offlineTransducer / offlineCtc / offlineWhisper / vad` |
| `SegmentDecodeResult`, segment buffer | internal | never barrel-exported (Q7) |

## Constraints
- SECURITY-03: no transcript text in logs/metrics/crash reports **including native error messages** (log the type, not the message); record-level redaction audit test required in the suite. (Rule 8)
- Engine never touches the network; paths only via `SherpaModelManager`. (Rule 9)
- At most one segment and one decode in flight; cadence ticks skipped, not queued. (Rules 2, 3)
- No changes to: `SttEngine`/`SttResult` interfaces, audio pipeline, `SttSessionManager`, caption bus, other engines, download lifecycle. (Rules 10, 12, Q13)
- No UI surfaces in this unit (verified: no picker/catalog UI in either app yet); row contracts + 4 ARB keys + `main.dart` registration only.
- CG Parts 1+2 hard-gated on the Spike 1.4 report (OQ-2); NFR may proceed on vendor-flagged data.

## Open Questions for Next Stage
- Exact param values: `interimCadence`, `maxSegmentDuration`, `minBufferForFirstInterim`, `vadThreshold`, `vadMinSilenceDuration`, `numThreads` per device class — from Spike 1.4 Q7 data. (source: Q4 defers numbers to NFR)
- Whether `initialize()` OOM on low-RAM devices needs an NFR degradation rule (e.g. report unavailable below a memory floor). (source: Rule 6 lists OOM as an init failure; threshold unset)
- Whether `numThreads`/cadence differ per platform (mobile vs desktop) — NFR decides, config already carries per-instance values. (source: Q7 config is injectable by design)
- Verify against pub-cache source at CG Part 1: exact `SileroVadModelConfig`/`OfflineRecognizerConfig` field names, whether the binding exposes a per-language force for `nemo_transducer` (Q5 follow-up), and whether a native max-segment exists or the force-cut must be engine-side. (source: plugin-claim verification convention)
