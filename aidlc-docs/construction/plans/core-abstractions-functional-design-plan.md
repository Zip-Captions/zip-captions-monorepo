# Functional Design Plan — Unit 1: Core Abstractions

## Unit Context

**Unit**: Unit 1 — Core Abstractions
**Stories**: S-01 (STT Engine Interface and Registry), S-03 (Caption Bus)
**Package**: zip_core (+ rename in zip_captions, zip_broadcast)
**Construction Stages**: FD, NFR-R, NFR-D, CG

## Plan Checklist

- [x] Step 1: Analyze existing Phase 0 components and identify deltas
- [x] Step 2: Design SttResult model with freezed schema
- [x] Step 3: Design CaptionEvent sealed class hierarchy
- [x] Step 4: Design SttEngine abstract interface (update from Phase 0)
- [x] Step 5: Design SttEngineRegistry service class
- [x] Step 6: Design CaptionBus service class
- [x] Step 7: Design CaptionOutputTarget abstract interface
- [x] Step 8: Design CaptionOutputTargetRegistry service class
- [x] Step 9: Design DisplaySettings rename (from AppSettings) across all packages
- [x] Step 10: Design RecordingState model update (add currentSegment, sessionId)
- [x] Step 11: Design RecordingStateNotifier update (wire to SttEngine + CaptionBus)
- [x] Step 12: Design provider layer (SttEngineRegistryProvider, CaptionBusProvider, etc.)
- [x] Step 13: Design LocaleInfoProvider update (read from active SttEngine)
- [x] Step 14: Identify PBT testable properties per component (PBT-01)
- [x] Step 15: Validate security compliance (SECURITY-03: no transcript logging)
- [x] Step 16: Generate functional design artifacts

## Questions

Please answer the following questions to help refine the functional design.

## Question 1
The SttEngine Phase 0 interface uses separate `onInterimResult(String)` and `onFinalResult(String)` callbacks. The Phase 1 design replaces these with a single `onResult(SttResult)` callback where `SttResult.isFinal` distinguishes interim from final. This is a breaking change to the SttEngine interface. How should we handle existing Phase 0 test code that references the old callback signatures?

A) Update all existing tests to the new signature immediately as part of Unit 1 (clean break)
B) Add a compatibility adapter in the test helpers that maps old callbacks to the new SttResult pattern, then migrate tests gradually
C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 2
The CaptionBus uses a broadcast `StreamController<CaptionEvent>`. When the CaptionOutputTargetRegistry subscribes and fans out to individual targets, should an error in one target's `onCaptionEvent` handler be handled by:

A) Try-catch per target in the registry's listener — log the error, skip the failed target, continue to the next target (fire-and-forget per target)
B) Try-catch per target with a configurable error callback on the registry — allows the app layer to decide how to handle target errors (e.g., disable the target, show UI notification)
C) Try-catch per target with automatic target removal after N consecutive failures — self-healing behavior
D) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 3
The `RecordingState` model is currently a sealed class with `idle`, `recording`, `paused`, `stopped` variants. Phase 1 adds `currentSegment` (the in-progress text) and `sessionId` fields. How should these be added to the sealed class?

A) Add fields to each variant that needs them — `RecordingActiveState(String currentSegment, String sessionId)`, `PausedState(String sessionId)`, `StoppedState(String sessionId)` — keeping `IdleState` clean with no fields
B) Create a shared base mixin/class with `sessionId` and `currentSegment?` that all non-idle variants extend, so common fields are defined once
C) Keep RecordingState minimal (no new fields). Instead, expose `currentSegment` and `sessionId` as separate providers that the RecordingStateNotifier manages alongside the state
D) Other (please describe after [Answer]: tag below)

[Answer]: B

## Question 4
The `SttEngineProvider` currently throws `UnimplementedError`. In Phase 1 it should provide the active engine. Since Unit 1 doesn't include `PlatformSttEngine` (that's Unit 2), the provider needs to work without a concrete engine implementation. What should it do?

A) Return `null` (change type to `SttEngine?`) — the provider returns null until Unit 2 registers concrete engines, and consumers check for null
B) Depend on `SttEngineRegistryProvider` and return `registry.defaultEngine` — still null-safe but expressed through the registry. Returns null until engines are registered in Unit 2
C) Keep throwing `UnimplementedError` until Unit 2 — Unit 1 tests use mock engines directly
D) Other (please describe after [Answer]: tag below)

[Answer]: C

## Question 5
The `CaptionOutputTargetRegistry` subscribes to the `CaptionBus` stream and fans out events to registered targets. Should the registry subscribe eagerly (at construction time) or lazily (on first target registration)?

A) Eagerly — subscribe to the bus stream in the constructor. Simple and predictable. Events before any target is registered are simply ignored
B) Lazily — subscribe to the bus stream only when the first target is added via `add()`. No subscription overhead if no targets are ever added. Unsubscribe when last target is removed
C) Other (please describe after [Answer]: tag below)

[Answer]: B

## Question 6
For the `DisplaySettings` rename: the existing `AppSettings` class, `BaseSettingsNotifier`, SharedPreferences key prefix, and app-level subclasses all need updating. Should the SharedPreferences key prefix also change (which would reset existing user settings on update)?

A) Change the key prefix from `app_settings` to `display_settings` — clean break, users lose saved settings (acceptable in Phase 1 development since there are no production users yet)
B) Keep the old `app_settings` key prefix for storage compatibility — only rename the Dart class names and file names, preserving any saved preferences
C) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question 7
The `SttEngine` interface from Application Design includes `supportedLocales` as `Future<List<SpeechLocale>> get supportedLocales`. The existing Phase 0 interface uses `Future<List<SpeechLocale>> getAvailableLocales()` (a method, not a getter). Which signature should we use?

A) Future getter: `Future<List<SpeechLocale>> get supportedLocales` — consistent with properties like `engineId` and `displayName`, reads like a property even though it's async
B) Method: `Future<List<SpeechLocale>> supportedLocales()` — consistent with `isAvailable()` and `initialize()` which are also async methods
C) Keep the existing Phase 0 name: `Future<List<SpeechLocale>> getAvailableLocales()` — no rename needed, preserves backward compatibility
D) Other (please describe after [Answer]: tag below)

[Answer]: B
