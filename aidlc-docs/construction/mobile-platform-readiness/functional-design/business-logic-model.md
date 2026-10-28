# Business Logic Model: Unit 10, Mobile Platform Readiness (G10)

**Date**: 2026-10-25. Entities: `domain-entities.md`. Rules: `business-rules.md`.

## Flow 1. Bootstrap registration (`runZipCaptions`)

1. Build `MobileAudioDeviceService(prefs)` first. Overrides can only be passed when the `ProviderContainer` is created, so the service must exist before it.
2. Build the `ProviderContainer` with its overrides: `sharedPreferencesProvider`, `supabaseClientProvider` as today, plus `audioDeviceServiceProvider` overridden with the service, on every platform (BR-U10-05).
3. Call `registerSttEngines(registry, platform, isWeb, allowDevEngines: kDebugMode, forceFake: kDebugMode && fromEnvironment('ZIP_FAKE_STT'), createPlatformEngine: () => PlatformSttEngine(stt: SpeechToText(), deviceService: audioService))`.
4. Select per BR-U10-06 / BR-U10-07:

| Mode | Platform | Flag | Registered |
|---|---|---|---|
| release/profile | iOS, Android | n/a | `PlatformSttEngine` |
| release/profile | desktop, web | n/a | nothing (as today) |
| debug | iOS, Android | off | `PlatformSttEngine` |
| debug | iOS, Android | `ZIP_FAKE_STT=true` | `FakeSttEngine` |
| debug | desktop, web | any | `FakeSttEngine` (as today) |

No platform channel is touched here. The existing pre-warm of the transcript repository follows unchanged.

## Flow 2. Start Captioning

```
RecordingScreen.initState ─ await notifier.start()
 start(): clear lastError
  ├─ sttEngineProvider == null ............ lastError = engineInitFailed          ─┐
  ├─ SttSessionManager.initialize()                                                │
  │    ├─ engine requires mic: permission check                                    │
  │    │    granted ........................ continue                               │
  │    │    permanently denied ............. permissionPermanentlyDenied ─────────┤
  │    │    denied after request ........... permissionDenied ───────────────────┤
  │    └─ engine.initialize() false/throws . engineInitFailed ─────────────────────┤
  ├─ startListening() false/throws ......... engineStartFailed (+ stop) ───────────┤
  ├─ startListening() true, but an engine error was captured while start() ran
  │                                           that error, session manager stopped ─┤   (BR-U10-25)
  │                                                                               ▼
  │                                       state stays IdleState, lastError kept,
  │                                       no wake lock, no SessionStateEvent
  └─ success: state = recording, SessionStateEvent, wake lock acquired
 screen: state still Idle and lastError != null ⇒ failure state (Flow 3)
```

The change in `zip_core` is only the `start()` wrapper around `onError`: while `start()` is in progress it stores the reported error in `lastError`; once `start()` has completed, errors still go to `_handleEngineError` (TP-2 unchanged).

## Flow 3. Failure state (`zip_captions` `RecordingScreen`)

| `lastError` kind | Text | Open settings | Try again |
|---|---|---|---|
| `micDenied` | microphone access was denied | no | yes |
| `micPermanentlyDenied` | access is blocked; enable it in system settings | iOS and Android only | yes |
| `engineInitFailed` | speech recognition could not start | iOS and Android only (covers iOS speech-recognition denial, F4) | yes |
| `engineStartFailed` | speech recognition did not start | no | yes |
| other | the error's message | no | yes |

"Open settings" is shown only on iOS and Android. On a desktop release build `engineInitFailed` means no engine is registered, so system settings fix nothing. On macOS `permission_handler` has no plugin (no entry in `zip_captions/macos`), so `openAppSettings()` would throw `MissingPluginException`. `StartFailureView` therefore takes the platform as an input.

Open settings → `openMicrophoneSettings()`. Try again → clear the failure and call `start()` again. Back → Home. The screen never crashes on a failed start (S-22 AC2). While the failure panel is shown, the controls bar is hidden (`frontend-components.md`), because it shows a progress indicator whenever the state is `IdleState`.

## Flow 4. `MobileAudioDeviceService`

`PlatformSttEngine.startListening` reads `currentPreferredDeviceId`; when non-null it calls `setPreferredInputDevice`, which here only re-stores the same id. The OS chooses the input. No other behaviour.

## Flow 5. Continuous listening (Amendment 01, N9)

`PlatformSttEngine` restarts `listen()` internally on the plugin's `done` status (once per session end), classifies plugin errors by code (silence, lasting, transient), reports lasting errors and the cap through `SttErrorSource.setErrorListener` to `SttSessionManager` and on to `_handleEngineError`, and listens with `onDevice: true`. The full flow, rules BR-U10-15..25 and properties TP-11..TP-14, extended TP-2 and the new TP-1 row are in `amendment-01-continuous-listening.md` (revision 2). Flow 2 is unchanged except that `SttSessionManager.initialize()` also registers the error listener for engines that are an `SttErrorSource`.

## Not in this stage

`Permission.speech` handling, `Info.plist`/Podfile flags, `RECORD_AUDIO` and `<queries>` entries, recogniser availability per platform, signing, and OQ-MA-1 are NFR Requirements. Desktop engine registration and the `zip_broadcast` fix are out of scope.

## Testable Properties (PBT-01)

| ID | Category | Property | Component |
|---|---|---|---|
| **TP-1** | Invariant (table-driven, example-based per row) | Every start failure leaves its error in `lastError`. For each cause below, after `start()`: state is `IdleState`, `lastError` equals the error that cause maps to (compared through the factories), no wake lock is acquired, no `SessionStateEvent` is published. One case per row so a missing case fails by name. | `RecordingStateNotifier` (`zip_core/test`) |
| | | No engine registered (`sttEngineProvider` null) → `engineInitFailed()` | |
| | | Microphone permission denied → `permissionDenied()` | |
| | | Microphone permanently denied (before or after the request) → `permissionPermanentlyDenied()` | |
| | | `initialize()` returns `false` → `engineInitFailed()` | |
| | | `initialize()` throws → `engineInitFailed()` | |
| | | `startListening()` returns `false` or throws → `engineStartFailed()` | |
| | | **An engine error arrives while `start()` is still running, after `startListening()` returned `true`** (Amendment 01, BR-U10-25) → the mapped error; additionally `stop` was called on the session manager | |
| **TP-2** | Invariant (regression) | The engine-error and reconnect path is unchanged. An engine error while recording moves to `ReconnectingState`; a successful restart returns to `RecordingActiveState` with `lastError` cleared. A failed restart, or a second error after one attempt, moves to `StoppedState`, finalises the transcript and releases the wake lock. An error while paused or stopped is ignored. If the user stops during recovery, their state is not overwritten. Where existing tests already cover a bullet, Code Generation names the test instead of duplicating it. | `RecordingStateNotifier` (`zip_core/test`) |
| TP-3 | Invariant | For all `(platform, isWeb, forceFake)` with `allowDevEngines = false`, the fake is never registered. | `registerSttEngines` |
| TP-4 | Invariant | For all inputs with `allowDevEngines = true`, `forceFake = false` and `hasRealEngine = true`, `defaultEngine` is the platform engine and the fake is absent. With `forceFake = true`, the registry holds only the fake. | `registerSttEngines` |
| **TP-10** | Invariant | **The real engine is registered.** For all `(platform, isWeb)` with `allowDevEngines = false` (and any `forceFake`), the registry holds exactly the platform engine when `hasRealEngine`, and nothing otherwise. TP-3 and TP-5 alone would pass if nothing were ever registered; this property is the G10 guarantee. An example-based test pins iOS and Android release → exactly `engineId == 'platform'` (PBT-10). | `registerSttEngines` |
| TP-5 | Invariant | `registerSttEngines` never calls `createPlatformEngine` unless the platform engine is to be registered (desktop and web never construct it). | `registerSttEngines` |
| TP-6 | Invariant (SECURITY-03) | For any generated transcript text, no log record (message, error, stack trace) emitted during a session contains it. The generator yields structured, distinctive strings (≥ 8 characters, Unicode and punctuation included), not single characters, so a substring hit is meaningful (PBT-07). Plus one example-based test with a fixed phrase (PBT-10). | session path, `Logger.root.level = Level.ALL` |
| TP-7 | Round-trip / idempotence | `MobileAudioDeviceService`: after `setPreferredInputDevice(id)`, `currentPreferredDeviceId == id`; after `clearPreferredInputDevice()` it is `null`; clearing twice equals clearing once; `listInputDevices()` always returns exactly one device, and it is the default. | `MobileAudioDeviceService` |
| TP-8 | Invariant | `StartFailureView` classification is total and deterministic over every `RecordingErrorFactories` error and every platform. `showOpenSettings` is true exactly when the platform is iOS or Android and the kind is `micPermanentlyDenied` or `engineInitFailed`; on any other platform it is always false. | `StartFailureView` |
| TP-9 | Stateful (PBT-06) | Over random sequences of failing and succeeding `start()` / `stop()` / `clearSession()` calls, **with no engine errors injected** (`_handleEngineError` also sets `lastError` during recording, which TP-2 covers), checked against a model: after each call, `lastError` is non-null only when the last `start()` failed and state is `IdleState`; a later success clears it; a later failure replaces it. | `RecordingStateNotifier` |

**Amendment 01 adds** TP-11 (stateful model of the engine session loop), TP-12 (no transcript in error payloads or logs), TP-13 (error-kind mapping), TP-14 (final-first flush) and extends TP-2 for real engine errors. Definitions: `amendment-01-continuous-listening.md` section 6.

PBT framework: the repo's Dart-3 shim (`test/helpers/pbt.dart`), copied into `zip_captions/test/helpers/` for the `zip_captions` properties (NFR Q10=C). The shim runs fixed seeds 0 to 99, has no shrinking and prints no seed; that is the deviation earlier units accepted.

## PBT Compliance (Functional Design stage)

| Rule | Status |
|---|---|
| PBT-01 | Compliant: properties above, by component |
| PBT-02 | TP-7 (set/current round trip) |
| PBT-03 | TP-1, TP-3, TP-4, TP-5, TP-8, TP-10 |
| PBT-04 | TP-7 (clear idempotent) |
| PBT-05 | N/A: no reference implementation |
| PBT-06 | TP-9 |
| PBT-07 to PBT-10 | Code Generation / NFR Requirements obligations (generators in TP-6, TP-9; shim supplies seed and shrinking; TP-1 and TP-2 are example-based per PBT-10) |

No blocking PBT findings.
