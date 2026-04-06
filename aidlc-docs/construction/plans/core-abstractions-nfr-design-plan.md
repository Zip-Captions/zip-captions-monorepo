# NFR Design Plan — Unit 1: Core Abstractions

## Unit Context

**Unit**: Unit 1 — Core Abstractions
**NFR Requirements**: Complete (performance, reliability, security, testing, maintainability)
**Key NFR Decisions**: glados for PBT, uuid for session IDs, logging package for structured logs, 20 events/sec bus throughput target

## Plan Checklist

- [x] Step 1: Design glados PBT test patterns and custom Arbitrary generators
- [x] Step 2: Design MockSttEngine test helper
- [x] Step 3: Design logging pattern (Logger per component, naming convention)
- [x] Step 4: Design CaptionBus throughput test approach
- [x] Step 5: Design error isolation test pattern
- [x] Step 6: Generate NFR design artifacts

## Applicability Assessment

Unit 1 is a pure Dart library. No infrastructure components, deployment patterns, or scalability concerns.

| NFR Design Category | Applicable | Rationale |
|--------------------|-----------|-----------|
| Resilience Patterns | No | In-process error isolation only (already designed in FD) |
| Scalability Patterns | No | No distributed components |
| Performance Patterns | Minimal | Bus throughput test pattern only |
| Security Patterns | No | Security is a code review constraint, not a design pattern |
| Logical Components | No | No infrastructure components |
| Test Patterns | Yes | Primary focus: PBT generators, mock engine, test organization |

## Questions

Please answer the following questions to help refine the NFR design.

## Question 1
The glados PBT tests need custom `Arbitrary<T>` generators for domain types (SttResult, RecordingState transitions, DisplaySettings, etc.). Where should these generators live?

A) In a shared `test/helpers/generators.dart` file — all generators in one place, reusable across test files
B) Co-located with each test file — each PBT test file defines its own generators inline. Less sharing but more self-contained
C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 2
The MockSttEngine needs to simulate async behavior (startListening returns a Future, onResult callback fires over time). How should the mock handle timing?

A) Synchronous by default — all futures complete immediately, onResult fires synchronously when test code calls a trigger method like `emitResult(SttResult)`. Tests control timing explicitly
B) Configurable delay — mock accepts an optional Duration for simulating realistic async behavior. Default is synchronous (Duration.zero)
C) Other (please describe after [Answer]: tag below)

[Answer]: C - the default duration should be brief but asynchronous (e.g. 100ms)
