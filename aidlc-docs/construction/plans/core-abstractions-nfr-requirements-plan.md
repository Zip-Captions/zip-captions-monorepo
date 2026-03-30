# NFR Requirements Plan — Unit 1: Core Abstractions

## Unit Context

**Unit**: Unit 1 — Core Abstractions
**Stories**: S-01 (STT Engine Interface and Registry), S-03 (Caption Bus)
**Package**: zip_core (+ rename in zip_captions, zip_broadcast)
**Functional Design**: Complete (3 artifacts: domain-entities, business-logic-model, business-rules)

## Plan Checklist

- [x] Step 1: Assess performance requirements for CaptionBus throughput and state machine transitions
- [x] Step 2: Assess reliability requirements for error isolation and bus lifecycle
- [x] Step 3: Assess security requirements (SECURITY-03 compliance verification)
- [x] Step 4: Assess testing requirements (PBT strategy, coverage targets, mock engine approach)
- [x] Step 5: Assess maintainability requirements (API stability, extension points)
- [x] Step 6: Make tech stack decisions (uuid package, logging approach)
- [x] Step 7: Generate NFR requirements artifacts

## Applicability Assessment

Unit 1 is a pure Dart library layer with no UI, no network, no database, and no platform channels. Many NFR categories are not applicable:

| NFR Category | Applicable | Rationale |
|-------------|-----------|-----------|
| Performance | Partial | Bus throughput matters; no latency-sensitive I/O |
| Scalability | No | In-process pub-sub; no distributed concerns |
| Availability | No | No deployment; runs in-process |
| Security | Yes | SECURITY-03 (no transcript logging) |
| Reliability | Yes | Error isolation, bus lifecycle, state machine integrity |
| Testing | Yes | PBT properties, mock engine patterns, coverage |
| Maintainability | Partial | API stability for downstream units |
| Usability/Accessibility | No | No UI in Unit 1 |

## Questions

Please answer the following questions to help refine the NFR requirements.

## Question 1
The CaptionBus throughput determines how many events per second can flow from STT engines to output targets. For live captioning, interim results arrive frequently (every 50-200ms from Sherpa-ONNX). What throughput target should we design for?

A) 20 events/sec — sufficient for single-input with interim results every 50ms
B) 100 events/sec — headroom for multi-input (Zip Broadcast with 4-5 simultaneous inputs at 20 events/sec each)
C) No explicit throughput target — the broadcast StreamController is in-process and effectively unbounded for this use case. Focus testing on correctness, not throughput
D) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 2
For PBT test generation: Dart's main PBT options are `glados` (lightweight, pure Dart generators) and custom generators using `dart:math` Random. Which approach should Unit 1 use?

A) Use `glados` package — provides `Arbitrary<T>` generators, shrinking, and a test runner. Well-maintained, idiomatic Dart PBT
B) Custom generators with `dart:math` — lighter dependency, but no shrinking support. Generate random inputs manually in standard `test()` blocks
C) Use `fast_check` package — another Dart PBT option with property-based testing primitives
D) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 3
The `uuid` package is needed for generating sessionId in RecordingStateNotifier. This is a new dependency for zip_core. Should we:

A) Add `uuid` package dependency to zip_core — standard, well-maintained package (1000+ pub points)
B) Use a lightweight alternative: `DateTime.now().microsecondsSinceEpoch.toRadixString(36)` combined with a random suffix — avoids adding a dependency for a single use
C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 4
For logging in Unit 1 components (CaptionOutputTargetRegistry error handler, BaseSettingsNotifier), the Phase 0 code uses `dart:developer` `log()`. Should Unit 1 continue with this or introduce a structured logging package?

A) Continue with `dart:developer` `log()` — consistent with Phase 0, no new dependency. Sufficient for a client-side Flutter app where logs go to the debug console
B) Introduce `logging` package (dart:core team) — adds log levels, named loggers, and structured output. Better for filtering and future log aggregation
C) Other (please describe after [Answer]: tag below)

[Answer]: B
