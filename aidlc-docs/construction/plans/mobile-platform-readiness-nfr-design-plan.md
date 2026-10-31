# NFR Design Plan: Unit 10, Mobile Platform Readiness (S-22, Alpha 1)

**Stage**: Construction, NFR Design (Phase 2). NFR Requirements approved 2026-10-25 by James Petersen (with three corrections); Functional Design, Amendment 01 and Amendment 02 approved the same day.
**Input**: `nfr-requirements/handoff-summary.md`, `nfr-requirements/nfr-requirements.md`, `tech-stack-decisions.md`, `functional-design/` (including both amendments).
**How the answers below were produced:** per the hand-off James Petersen approved, every question carries a **proposed answer marked "(proposed by Sonnet, awaiting James Petersen)"**, and the artifacts are generated on that basis. He confirms or changes the answers at the NFR Design approval gate. Nothing here is approved yet.
**Constraints carried forward**: `SttResult`, `RecordingState`, `RecordingError` and the `AudioDeviceService` interface unchanged; `SttEngine` extended only by the approved additive `SttErrorSource` channel; no source file is changed in this stage; nothing registered locally; stay on `speech_to_text` 7.3.0; no new package.

**Opus review of the gate summary (2026-10-25):** recommends confirming Q1 to Q12 as proposed; James Petersen confirms at the gate. The review also settled the iOS channel API (`engineBridge.applicationRegistrar.messenger()`) and the existing `stop()` sequence, and required a fix (P4 rules a to d and a new property TP-2c: Stop must win against the REL-U2.1 recovery), applied to the drafts the same day. Q4's proposed answer stands, with the added rules.

## Plan checklist

- [x] Step 1. Analyse the NFR Requirements and the Functional Design (both amendments)
- [x] Step 2. Create this plan
- [x] Step 3. Generate questions with proposed answers (below)
- [ ] Step 4. James Petersen confirms or changes the answers (at the gate)
- [x] Step 5. Generate `nfr-design/nfr-design-patterns.md` and `nfr-design/logical-components.md` on the proposed answers
- [x] Step 6. Write `nfr-design/handoff-summary.md` (for Code Generation)
- [ ] Step 7. Present the completion message and **stop at the approval gate**. Do not approve, do not tick in `aidlc-state.md`, do not start Code Generation.
- [ ] Step 8. After approval only: log it in `audit.md`, tick NFR Design in `aidlc-state.md`

## Facts from the code read that shape the questions (2026-10-25)

| # | Fact | Evidence |
|---|---|---|
| D1 | `clock` and `fake_async` are **dev** dependencies of `zip_core` (`clock` is not used in `lib/`). A runtime use of `package:clock` would add a runtime dependency. | `zip_core/pubspec.yaml` lines 80-84; no `package:clock` under `lib/` |
| D2 | There is a precedent for tunable numbers: one `const defaultBroadcastLimits` in `zip_core/lib/src/constants/`, "a one-file change, not a design change". | `broadcast_limits_default.dart` |
| D3 | iOS uses the implicit Flutter engine: `AppDelegate` conforms to `FlutterImplicitEngineDelegate` and registers plugins in `didInitializeImplicitFlutterEngine(_:)`. There is no `FlutterViewController` to hang a channel on, and adding a new `.swift` file needs a `project.pbxproj` edit. | `ios/Runner/AppDelegate.swift` |
| D4 | Android has a single `MainActivity.kt` (package `com.zipcaptions.zip_captions`, relocating with the namespace change). | `android/app/src/main/kotlin/...` |
| D5 | `zip_captions` reads strings through `zcStringsProvider` (`ZcStrings`), generated from `l10n/arb/app_en.arb`. | `home_screen.dart`, `l10n/zc_strings.dart` |
| D6 | `zip_captions/lib/src/services/` already holds platform-conditional services; `widgets/` holds the recording controls bar. | directory listing |

---

## Questions

Each question lists the category, the options, and the proposed answer. Edit the `[Answer]:` line to change it.

## Question 1 (Resilience: where the restart loop lives)
Amendment 01's session loop (restart on `done`, error classes, cap, flush) and Amendment 02's check-before-listen are about ten rules. Where do they live?

A) Inside `PlatformSttEngine`, as a private `_SessionLoop` class in the same file, driven by the injected `SpeechToText`, checker, clock function and `fake_async` timers in tests. No extra public type.
B) A separate public, pure-Dart `ContinuousListeningController` behind a narrow plugin adapter interface, with `PlatformSttEngine` as a thin wrapper.
C) Other (describe after [Answer]: tag below)

[Answer]: A (proposed by Sonnet, awaiting James Petersen). The plugin is already mockable through its constructor and public listener fields, `fake_async` fakes `Timer`, and B adds a public type and an adapter nobody else needs. Revisit if the engine file passes about 400 lines.

## Question 2 (Resilience: time source for `immediateFailureWindow`)
BR-U10-17 compares a session's length to `immediateFailureWindow`.

A) An injected `DateTime Function() now` constructor parameter, defaulting to `DateTime.now`; tests pass a controllable function.
B) `package:clock`'s `clock.now()`, which `fake_async` also fakes. It would move `clock` from dev to runtime dependencies (SECURITY-10 note).
C) Other (describe after [Answer]: tag below)

[Answer]: A (proposed by Sonnet, awaiting James Petersen). Avoids a runtime dependency (D1) and keeps the engine's inputs explicit.

## Question 3 (Resilience: the tunable numbers)
Where do `restartCap`, `immediateFailureWindow`, `restartDelay` and `onDeviceCheckTimeout` live?

A) One `const` record type `SttListeningLimits` and `defaultSttListeningLimits` in `zip_core/lib/src/constants/`, passed to the engine through an optional constructor parameter, following the `defaultBroadcastLimits` precedent (D2). Device-pass changes are one-file edits.
B) Private constants in the engine file.
C) Other (describe after [Answer]: tag below)

[Answer]: A (proposed by Sonnet, awaiting James Petersen). Values: `restartCap = 3`, `immediateFailureWindow = 2 s`, `restartDelay = 250 ms`, `onDeviceCheckTimeout = 2 s`, all confirmed or changed at the device pass.

## Question 4 (Resilience: exactly-once stop)
BR-U10-35 needs one routine that finalises, stops and releases once. How is "once" enforced?

A) A single `Future<void>? _finishing` field in `RecordingStateNotifier`: the first caller starts the routine and stores its future; every later caller (engine error, recovery failure or exception, refused resume, user `stop()`) returns that same future, so a user stop awaits the in-flight finalise instead of racing it. `start()` and `clearSession()` reset it.
B) A boolean flag set on entry; later callers return immediately without awaiting.
C) Other (describe after [Answer]: tag below)

[Answer]: A (proposed by Sonnet, awaiting James Petersen). A boolean (B) would let a Stop tap return while the first finalise is still awaiting, so the UI could navigate away mid-finalise.

## Question 5 (Resilience: capturing the first error during `start()` and `resume()`)
BR-U10-28 and BR-U10-36 need "the first error reported while this operation runs".

A) An operation-scoped capture: a nullable `RecordingError? _captured` and a `bool _capturing` set for the duration of `start()` or `resume()`, written by the `onError` wrapper only when `_captured` is null; `start()`'s direct `engineStartFailed()` assignment checks it. Cleared when the operation ends.
B) A `Completer<RecordingError>` per operation.
C) Other (describe after [Answer]: tag below)

[Answer]: A (proposed by Sonnet, awaiting James Petersen). Simple, synchronous and easy to table-test (TP-16, TP-20).

## Question 6 (Resilience and security: the checker guard)
Where are the checker's failure modes (exception, `MissingPluginException`, timeout) turned into `false`?

A) In the **engine**: it wraps every call to any injected checker in `try`/`catch` plus `Future.timeout(limits.onDeviceCheckTimeout)`, so a custom or faulty checker cannot hang or crash a listen. `MethodChannelOnDeviceSupportChecker` stays a thin channel call.
B) In `MethodChannelOnDeviceSupportChecker` only.
C) Other (describe after [Answer]: tag below)

[Answer]: A (proposed by Sonnet, awaiting James Petersen). One enforcement point, covered by one test for every checker, including fakes.

## Question 7 (Performance)
The check adds a method-channel hop before each `listen()`, including the restart gap between sessions.

A) No caching and no prefetch (BR-U10-26). The hop is a local boolean query and overlaps `restartDelay`; its cost and any lost words are observed at the device pass (the Amendment 01 restart observations).
B) Cache the result for a short window.
C) Other (describe after [Answer]: tag below)

[Answer]: A (proposed by Sonnet, awaiting James Petersen). Caching would reopen the window the check exists to close.

## Question 8 (Security: log hygiene)
How is SECURITY-03 enforced on the new path (engine loop, checker, refusal, finalise routine)?

A) Every new `Logger` call uses an enum name, a boolean or `e.runtimeType`, never an interpolated exception or result; one test at `Logger.root.level = Level.ALL` drives generated transcripts through the whole path and asserts no record contains them (TP-6, TP-12). No new lint rule.
B) Add a custom lint.
C) Other (describe after [Answer]: tag below)

[Answer]: A (proposed by Sonnet, awaiting James Petersen). Matches earlier units; a custom lint is out of proportion for one unit.

## Question 9 (Logical components: iOS and Android channel code)
Where do the Swift and Kotlin parts of `MethodChannelOnDeviceSupportChecker` live?

A) **iOS:** inside `AppDelegate.swift`'s `didInitializeImplicitFlutterEngine(_:)`, registering the channel on the engine bridge's messenger (D3), so no `project.pbxproj` edit is needed; the exact bridge API is confirmed at Code Generation. **Android:** in `MainActivity.kt` (`configureFlutterEngine`). Each is a few lines with no new file.
B) New `SpeechSupportChannel.swift` and `.kt` files (cleaner, but the Swift file needs a `pbxproj` change).
C) Other (describe after [Answer]: tag below)

[Answer]: A (proposed by Sonnet, awaiting James Petersen). Fewest generated-file edits; moves to a plugin's own `has_on_device_support` when a stable 7.6.0 ships (the upgrade path).

## Question 10 (Logical components: the `zip_core` factory, confirming correction 3)
NFR Requirements prefers a `zip_core` factory that builds `PlatformSttEngine` over declaring `speech_to_text` in `zip_captions`. Shape?

A) `PlatformSttEngine createPlatformSttEngine({required OnDeviceSupportChecker onDeviceSupportChecker, required AudioDeviceService deviceService})` in `zip_core/lib/src/stt/engines/`, exported from the barrel; it constructs `SpeechToText()` itself, so `zip_captions/pubspec.yaml` is unchanged and `speech_to_text` stays declared only in `zip_core`.
B) Declare `speech_to_text` in `zip_captions`.
C) Other (describe after [Answer]: tag below)

[Answer]: A (proposed by Sonnet, awaiting James Petersen). Confirms the correction. The engine's own constructor still takes a `SpeechToText` for tests.

## Question 11 (Logical components: where the new `zip_captions` pieces sit)
A) `lib/src/services/stt_engine_registration.dart` (`registerSttEngines`), `lib/src/services/method_channel_on_device_support_checker.dart`, `lib/src/widgets/start_failure_view.dart` (the view model and the panel), `lib/src/widgets/speech_explainer_gate.dart`; strings through the existing `ZcStrings` (D5); `bootstrap.dart` builds `MobileAudioDeviceService` and the checker before the `ProviderContainer`.
B) A new `lib/src/stt/` folder for all of them.
C) Other (describe after [Answer]: tag below)

[Answer]: A (proposed by Sonnet, awaiting James Petersen). Follows the existing `services/` and `widgets/` split (D6).

## Question 12 (Testing structure)
A) Property tests in `zip_core/test/pbt/` (TP-1, 2, 2b, 9, 11, 13 to 15, 17, 18, 20, 12) and in `zip_captions/test/pbt/` (TP-3, 4, 5, 8, 10, 16, 19), using the shim copied to `zip_captions/test/helpers/pbt.dart`; example-based tests beside each class; hand-written fakes for `SpeechToText`, `OnDeviceSupportChecker`, `SttErrorSource` and `AudioDeviceService` (the existing `zip_core/test/helpers/mock_audio_device_service.dart` is reused); `fake_async` for the restart timers.
B) Other.

[Answer]: A (proposed by Sonnet, awaiting James Petersen).

---

## Categories evaluated and found not applicable (with reason)

- **Scalability patterns**: a single-user local captioning session; no load, queue or growth dimension.
- **Circuit breaker, queue, cache, rate limiter**: none apply. The bounded restart cap is the only failure-budget mechanism, and a cache is explicitly rejected (Question 7).
- **Infrastructure components**: none (no backend, no new package, no CI change in this unit).
