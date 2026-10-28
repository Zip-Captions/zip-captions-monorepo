# Domain Entities: Unit 10, Mobile Platform Readiness (G10)

**Date**: 2026-10-25. **Scope**: G10 (app-level speech-recogniser registration, its failure behaviour, and the pieces it needs). Runner configuration (G2, G3, G5, G9) is NFR Requirements material.

**Unchanged contracts**: `SttResult` (AGENTS.md stable contract), `RecordingState` and its variants, `RecordingError`, `AudioDeviceService` interface, `SttEngineRegistry`.

**Amended 2026-10-25 (Amendment 01, N9; awaiting re-approval):** James Petersen approved an additive error channel from engines to `SttSessionManager`, which touches the `SttEngine` stable contract surface. Decided shape (Opus review, R1): a new sibling interface `SttErrorSource` (E5) plus `SttEngineError` (E6) in `zip_core`, so the `SttEngine` interface text and every existing implementer are unchanged. `SttSessionManager` gains the listener registration (its public API is unchanged). `PlatformSttEngine` gains the session loop and `onDevice: true`. See `amendment-01-continuous-listening.md`.

## E5. `SttErrorSource` (new, `zip_core`, Amendment 01)

Capability interface: `void setErrorListener(void Function(SttEngineError)? listener)` (a method, because `very_good_analysis` enables `avoid_setters_without_getters`). An engine that implements it reports lasting errors after `startListening()` succeeded. `SttSessionManager` checks `engine is SttErrorSource`.

## E6. `SttEngineError` and `SttEngineErrorKind` (new, `zip_core`, Amendment 01)

`SttEngineErrorKind`: `recognizerUnavailable`, `onDeviceModelMissing`, `localeUnsupported`, `permissionRevoked`, `restartCapReached`. `SttEngineError` holds only the kind: no free text, so it cannot carry a transcript (SECURITY-03). Mapped to existing `RecordingErrorFactories` (no new factory).

## E1. `registerSttEngines` (registration seam, new, `zip_captions`)

A pure function that decides which engines enter the registry. It makes no platform call.

| Input | Meaning |
|---|---|
| `registry` | the `SttEngineRegistry` to fill |
| `platform` (`TargetPlatform`), `isWeb` | where the app runs |
| `allowDevEngines` | call site passes `kDebugMode` |
| `forceFake` | call site passes `kDebugMode && bool.fromEnvironment('ZIP_FAKE_STT')` (compile-time constant) |
| `createPlatformEngine` | `SttEngine Function()`, called only when the platform engine is to be registered |

Derived: `hasRealEngine = !isWeb && platform ∈ {iOS, android}`. Desktop and web are deliberately excluded (Q2=A): macOS without a speech usage key in `Info.plist` would be killed by the OS at the permission request.

## E2. `MobileAudioDeviceService` (new, `zip_core`)

Implements the existing `AudioDeviceService` interface for iOS and Android. Constructed with `SharedPreferences`.

| Member | Behaviour |
|---|---|
| `listInputDevices()` | always one `AudioDevice(deviceId: 'default', name: 'System default', isDefault: true)`. No enumeration. |
| `setPreferredInputDevice(id)` | stores `id` under `audio.preferredInputDeviceId`. No routing; the OS picks the input. |
| `clearPreferredInputDevice()` | removes the key |
| `currentPreferredDeviceId` | the stored value, `null` for system default |

Bootstrap overrides `audioDeviceServiceProvider` with the same instance given to `PlatformSttEngine`, so the provider no longer throws `UnimplementedError`.

## E3. `StartFailureView` (new view model, `zip_captions`)

Derived from `RecordingStateNotifier.lastError` after `start()` completes. Not stored in any provider.

| Field | Value |
|---|---|
| `kind` | one of `micDenied`, `micPermanentlyDenied`, `engineInitFailed`, `engineStartFailed`, `other`, chosen by comparing `RecordingError.message` and `severity` against the `RecordingErrorFactories` outputs (single source of truth; no retyped strings) |
| `platform` (input) | `TargetPlatform` and `isWeb`, passed to `StartFailureView.from(error, platform:, isWeb:)` |
| `showOpenSettings` | `true` only on iOS and Android (not web), and only for `micPermanentlyDenied` and `engineInitFailed`. On desktop it is always `false`: a release build with `engineInitFailed` has no engine registered, and on macOS `permission_handler` has no plugin, so `openAppSettings()` would throw `MissingPluginException`. |
| `showTryAgain` | `true` for every kind |
| `text` | localised string for the kind; for `other`, the error's own message |

`engineInitFailed` offers Open settings because a denied iOS speech-recognition permission surfaces as that generic failure (F4). A dedicated `Permission.speech` check is deferred to NFR Requirements (Q6).

## E4. `RecordingStateNotifier` change (existing, `zip_core`)

(Amendment 01 adds no `RecordingStateNotifier` change: engine errors arrive through its existing `_handleEngineError`.)

`start()` keeps the `RecordingError` that `SttSessionManager.initialize()` reports through `onError` while `start()` is in progress (today `_handleEngineError` drops it because the state is still `IdleState`). No new state variant, no new field. One log line changes (see BR-U10-12).

## Relationships

```
bootstrap ──► registerSttEngines ──► SttEngineRegistry ◄── sttEngineProvider (first registered = default)
    │                 └─ createPlatformEngine ─► PlatformSttEngine(SpeechToText, E2)
    └─ ProviderContainer overrides audioDeviceServiceProvider = E2 (built first, every platform)
RecordingScreen ─ await start() ─► RecordingStateNotifier.lastError ─► E3 ─► failure state
```
