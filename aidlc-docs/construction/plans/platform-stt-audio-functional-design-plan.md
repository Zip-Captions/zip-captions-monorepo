# Functional Design Plan — Unit 2: Platform STT + Audio

## Unit Context

**Stories**: S-02 (Platform-Native STT), S-06 (Audio Capture)
**Package**: zip_core (+ zip_broadcast for AudioInputSettingsProvider)
**Dependencies**: Unit 1 complete (SttEngine interface, CaptionBus, handleSttResult public on RecordingStateNotifier), Spike 1.1 (Sherpa-ONNX recommended), Spike 1.2 (system audio — mic only in Unit 2), Spike 1.3 (Sherpa-ONNX confirmed viable)

## Plan Steps

- [x] Step 1: Decide SherpaOnnxSttEngine scope (Q1)
- [x] Step 2: Decide audio device enumeration strategy (Q2)
- [x] Step 3: Decide RecordingStateNotifier wiring pattern (Q3)
- [x] Step 4: Decide wake lock location (Q4)
- [x] Step 5: Decide multi-input scope for Unit 2 (Q5)
- [x] Step 6: Decide permission denial state surfacing (Q6)
- [x] Step 7: Decide LocaleInfoProvider active-engine update mechanism (Q7)
- [x] Step 8: Generate domain-entities.md
- [x] Step 9: Generate business-logic-model.md
- [x] Step 10: Generate business-rules.md

---

## Questions

Please answer each question by filling in the letter after `[Answer]:`.
If no option matches, choose the last option (Other) and describe your preference.

---

## Question 1
**SherpaOnnxSttEngine scope in Unit 2**

The unit-of-work component list names only `PlatformSttEngine`, but S-02 acceptance criteria state that Tier 2 platforms (Windows/Linux) must reflect Spike 1.1 findings — which recommend Sherpa-ONNX as primary. Should `SherpaOnnxSttEngine` be implemented in Unit 2?

A) Yes — implement full `SherpaOnnxSttEngine` in Unit 2 (OnlineRecognizer feed/decode loop, model management: download, storage, locale mapping from on-disk models)

B) Yes — implement `SherpaOnnxSttEngine` skeleton in Unit 2 (engine registers, passes isAvailable/supportedLocales, but defer model download management to a later unit or separate design stage)

C) No — defer `SherpaOnnxSttEngine` entirely; Unit 2 delivers only `PlatformSttEngine` (Tier 2 platforms fall back to speech_to_text WinRT/nothing on Linux for now)

D) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 2
**Audio device enumeration for external microphone support**

S-06 requires: "Given an external microphone is connected (USB or Bluetooth), When the user opens the audio source selector, Then the external microphone appears in the list." The `speech_to_text` package does not expose hardware audio device selection — it uses whatever the OS routes to the default mic input. How should external microphone enumeration work?

A) Use `speech_to_text`'s `locales()` for locale selection only; external device routing is left to the OS (user selects the default device in system settings). No in-app device picker for Unit 2 — just locale selection. Enumerate devices in Unit 6 if needed for system audio.

B) Add a lightweight platform channel in Unit 2 to list available audio input devices (leveraging AVAudioSession on iOS/macOS, AudioManager on Android, WASAPI device enumeration on Windows, PulseAudio on Linux). Expose as `AudioDeviceService` in zip_core.

C) Use the `record` package (or similar) alongside `speech_to_text` — `record` exposes `listInputDevices()` on desktop. Use it for enumeration only; still feed audio to `speech_to_text` for recognition.

D) Other (please describe after [Answer]: tag below)

[Answer]: D - Use a package that can enumerate audio input devices and provide the option to set the device input, which will then integrate with the `speech_to_text` package.

---

## Question 3
**RecordingStateNotifier engine wiring pattern**

Unit 1 left `SttEngineProvider` throwing `UnimplementedError` and made `handleSttResult` public, with a comment "wired in Unit 2." What is the correct wiring pattern?

A) `RecordingStateNotifier.start()` reads the current engine from `SttEngineRegistryProvider` (selecting the default engine), calls `initialize()`, then `startListening(localeId: ..., onResult: handleSttResult)`. The notifier holds a reference to the active engine and calls `stopListening()` / `pause()` / `resume()` on state transitions.

B) Introduce a new `SttSessionManager` service in zip_core that owns the lifecycle: initialize → startListening → pause/resume/stop → dispose. `RecordingStateNotifier` delegates to `SttSessionManager` rather than calling the engine directly. `SttSessionManager` is a keepAlive provider.

C) `SttEngineProvider` (currently `UnimplementedError`) is completed in Unit 2 to return the active engine from the registry. `RecordingStateNotifier` reads from `SttEngineProvider` (existing ref.watch pattern already present) and wires the callback in its `start()` method.

D) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 4
**Wake lock location and ownership**

S-04 and S-06 both reference wake lock behavior: screen stays awake during captioning, with a user-configurable "release on pause" setting. Where should the `wakelock_plus` integration live?

A) In `zip_core` as a `WakeLockService` (plain Dart class, not a provider) — called by `RecordingStateNotifier` on state transitions (start → acquire, stop → release, pause → conditional release based on `TranscriptSettingsProvider` or a new `WakeLockSettingsProvider`).

B) In `zip_core` as a Riverpod provider (`WakeLockNotifier`) that observes `RecordingStateNotifier` state and manages the lock automatically, with the "release on pause" setting read from `DisplaySettings` or a separate provider.

C) In each app package (`zip_captions`, `zip_broadcast`) — the apps are responsible for requesting and releasing wake locks through their own providers, keeping zip_core platform-agnostic.

D) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 5
**Multi-input scope for Unit 2**

The unit-of-work lists `AudioInputSettingsProvider` (in zip_broadcast) and "Multi-input audio management" as Unit 2 components. Spike 1.2 confirmed system audio is out of scope for Unit 2 (microphone only). What multi-input work should Unit 2 deliver?

A) Full multi-input: `AudioInputSettingsProvider` in zip_broadcast (persist multiple `AudioInputConfig` entries), wire each config to its own `SttEngine` instance in a new `MultiInputSessionManager`, test with 2 simultaneous mic inputs. Single-input in zip_captions uses the same infrastructure at count=1.

B) Multi-input infrastructure in zip_core only: `AudioInputSettingsProvider` provider shell in zip_broadcast (CRUD for configs, defaulting to a single mic input), but the multi-SttEngine wiring (multiple simultaneous engine instances) is deferred to Unit 5/6 (app construction). Unit 2 validates single-engine wiring end-to-end.

C) Single-input only for Unit 2: defer `AudioInputSettingsProvider` and all multi-input work to Unit 6 (Zip Broadcast). Unit 2 proves a single PlatformSttEngine flows through RecordingStateNotifier → CaptionBus → targets correctly.

D) Other (please describe after [Answer]: tag below)

[Answer]: B

---

## Question 6
**Microphone permission denial — state surfacing**

S-06 requires: "Given microphone permission is denied, When captioning is attempted, Then the app shows a clear message explaining that microphone access is required and how to enable it." How should permission denial surface through the architecture?

A) Add a `permissionDenied` variant to `RecordingError` (already used in `RecordingState`). `PlatformSttEngine.initialize()` returns `false` when permission is denied; `RecordingStateNotifier.start()` checks `initialize()` return and transitions to `RecordingState.error(RecordingError.permissionDenied)`. The UI reads `RecordingState` and renders the message.

B) Add a separate `PermissionState` model and `PermissionNotifier` provider in zip_core. The notifier checks and requests microphone permission independently of `RecordingStateNotifier`. The UI observes `PermissionState` to show the permission message before the start flow.

C) Permission handling stays entirely inside `PlatformSttEngine` — if permission is denied, `startListening()` fails, the `onResult` callback never fires, and the error bubbles up as a generic `RecordingError.engineError`. Permission-specific messaging is left to the app layer (post-MVP).

D) Other (please describe after [Answer]: tag below)

[Answer]: A - the user should not be prompted for permission until it is required at time of init if a check indicates it is not yet granted, and when handling a permission denied exception.

---

## Question 7
**LocaleInfoProvider — active engine update mechanism**

Unit 1 updated `LocaleInfoProvider` with a comment that it should read `supportedLocales` from the active `SttEngine` (via `SttEngineProvider`) in Unit 2. The current `SttEngineProvider` throws `UnimplementedError`. How should the active-engine lookup work after Unit 2?

A) `LocaleInfoProvider` uses `ref.watch(sttEngineRegistryProvider)` and reads `registry.defaultEngine?.supportedLocales`. When the user changes the active engine (engine selection UI, Unit 5/6), the registry updates and `LocaleInfoProvider` rebuilds automatically.

B) Add an `activeEngineIdProvider` (a `StateProvider<String?>`) that holds the user's selected engine ID. `LocaleInfoProvider` watches `activeEngineIdProvider` and fetches `supportedLocales` from the corresponding engine. Engine selection persists via SharedPreferences (similar to other settings).

C) `LocaleInfoProvider` calls `SttEngineProvider.ref.watch(...)` directly — once `SttEngineProvider` is completed in Unit 2 (returns the default engine), `LocaleInfoProvider` simply calls `engine.supportedLocales` on whatever `SttEngineProvider` currently returns.

D) Other (please describe after [Answer]: tag below)

[Answer]: B - if provider ID changes and supported locale is no longer available, logic must handle both when provider supports non-locale language configuration, or if locale is required, should use the default for the provider-language combination, or if missing, throw an exception.
