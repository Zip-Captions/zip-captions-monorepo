# Business Rules: Unit 10, Mobile Platform Readiness (G10)

**Date**: 2026-10-25. Source: the 10 answers in `construction/plans/mobile-platform-readiness-functional-design-plan.md`.

## Engine selection and registration

| ID | Rule | Source |
|---|---|---|
| BR-U10-01 | On iOS and Android, `zip_captions` registers `PlatformSttEngine` as its only real engine. `SherpaOnnxSttEngine` is not registered (needs a model download; parked multilingual unit). | Q1=A |
| BR-U10-02 | Desktop and web register no real engine in this unit. The platform check excludes them explicitly, so a desktop release build never reaches a speech API without its usage key. It still has no engine, but it no longer shows an empty screen: Start Captioning now shows the failure panel (BR-U10-10) with `engineInitFailed` text and no "Open settings". Desktop is recorded as the same defect for a later unit. | Q2=A |
| BR-U10-03 | Registration makes no platform call and does not call `initialize()` or `isAvailable()`. `PlatformSttEngine` is constructed only inside `createPlatformEngine`, so desktop never constructs it. | Q4=A, F3 |
| BR-U10-04 | Availability is discovered once, at Start Captioning, by `SttSessionManager.initialize()`. A `false` or a throw is a start failure (BR-U10-08), not a reason to unregister the engine. | Q4=A |
| BR-U10-05 | `MobileAudioDeviceService` is built before the `ProviderContainer` and passed in the container's overrides for `audioDeviceServiceProvider` on **every** platform (overrides can only be given at container creation). It only claims a system-default input, which is true everywhere, and it removes the `UnimplementedError` the provider throws today. The same instance is passed to `PlatformSttEngine`. | Q3=A |

## The debug fake

| ID | Rule | Source |
|---|---|---|
| BR-U10-06 | `FakeSttEngine` is registered only when `allowDevEngines` is true, and then by this table (first match wins). | Q7=D, Q8=A |
| | `forceFake` → fake only. | |
| | else `hasRealEngine` → real engine only. | |
| | else (desktop or web debug) → fake only, as today (Units 8 and 8.1 were tested with it). | |
| BR-U10-07a | When `allowDevEngines` is false the registry holds exactly the platform engine if `hasRealEngine`, and nothing otherwise (TP-10). | G10 |
| BR-U10-07 | When `allowDevEngines` is false the fake is never registered, whatever `forceFake` says. The call-site inputs are compile-time constants (`kDebugMode`, `bool.fromEnvironment('ZIP_FAKE_STT')`) so a release build strips the fake. The decision lives in `registerSttEngines` so a unit test can pass `false`. | Q8=A |

## Failure behaviour

| ID | Rule | Source |
|---|---|---|
| BR-U10-08 | Every start failure leaves the state at `IdleState`, sets `lastError` to the matching `RecordingErrorFactories` error, acquires no wake lock and publishes no `SessionStateEvent`. Causes and errors: no engine → `engineInitFailed`; mic denied → `permissionDenied`; mic permanently denied (before or after the request) → `permissionPermanentlyDenied`; `initialize()` false or throwing → `engineInitFailed`; `startListening()` false or throwing → `engineStartFailed`. | Q5=C, TP-1 |
| BR-U10-09 | `start()` begins by clearing `lastError`, so a retry shows only the newest failure and a success leaves none. | existing behaviour kept |
| BR-U10-10 | `RecordingScreen` waits for `start()` to finish. If the state is still `IdleState` and `lastError` is non-null, it shows the failure state (E3) instead of the empty caption area. "Open settings" is shown only on iOS and Android, for `micPermanentlyDenied` and `engineInitFailed`, and calls the existing `openMicrophoneSettings()`. It is never shown on desktop or web (no engine to fix on desktop release; on macOS `permission_handler` has no plugin and the call would throw `MissingPluginException`). "Try again" re-runs `start()`. Leaving the screen returns to Home. The controls bar is hidden while the failure panel is shown. | Q5=C, Q6=A |
| BR-U10-11 | The failure messages are the existing factory messages. No new error kind is added (Q6=A). Failure text shown in the UI is localised through the `.arb` source of truth; the kind is detected through the factories, not by retyped strings. | Q6=A |
| BR-U10-11a | The `_handleEngineError` Recording and Reconnecting branches (restart once, then stop; ignored while paused or stopped; user state not overwritten) are unchanged. | TP-2 |

## Continuous listening and the engine error channel (Amendment 01, N9)

BR-U10-15 to BR-U10-25 are defined in `amendment-01-continuous-listening.md` (revision 2): restart on `done` only and once per session, final-first flush on `done` only, errors classified by code (silence, lasting, transient) and never by the `permanent` flag, a cap that silence never counts toward, stop and pause win, `onDevice: true`, logging, session-manager forwarding, mid-session stop notice, listeners assigned directly on the plugin, and the start-race rule (BR-U10-25). `BroadcastRecordingNotifier` drives engines directly and does not receive these errors (record-only, BR-U10-14). BR-U10-11a is extended: the reconnect path must hold with real engine errors arriving (TP-2 extended).

## Logging (SECURITY-03)

| ID | Rule | Source |
|---|---|---|
| BR-U10-12 | No log record on the new path (registration, `MobileAudioDeviceService`, start failure, failure view) contains transcript text. Exceptions are logged as `e.runtimeType`. The existing line at `recording_state_notifier.dart:102` (`$e`) changes to `e.runtimeType`. | Q9=A, F8 |
| BR-U10-13 | A test drives a session with generated transcript text at `Logger.root.level = Level.ALL`, captures every record's message, error and stack trace, and asserts none contains the text. | Q9=A |

## `zip_broadcast` (record only)

| ID | Rule | Source |
|---|---|---|
| BR-U10-14 | `zip_broadcast`'s `sttEngineFactoryProvider` (fake in debug, `UnimplementedError` in release) is not changed. The defect is recorded in this unit's evidence, in `audit.md`, and as a Backlog entry in `aidlc-state.md` that says it is unfixed. | Q10=A |

## Security Compliance (Security Baseline, applicable rules)

| Rule | Status | Note |
|---|---|---|
| SECURITY-03 | Compliant by design | BR-U10-12, BR-U10-13. Transcript text is never logged; failures log types only. |
| SECURITY-09 | Compliant by design | BR-U10-07: the dev fake is compile-time gated out of release. |
| SECURITY-15 | Compliant by design | BR-U10-08: every failure fails closed to `IdleState` with no wake lock; BR-U10-04 handles a throwing `initialize()`. |
| SECURITY-10 | N/A here | No new dependency in Functional Design. NFR Requirements decides any pin changes. |
| 01, 02, 04–08, 11–14 | N/A | No storage, network, endpoint, auth or infrastructure surface. `MobileAudioDeviceService` stores one device id in SharedPreferences (non-sensitive). |

No blocking security findings.
