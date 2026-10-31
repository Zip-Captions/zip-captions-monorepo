# Functional Design Amendment 02: fail-closed on-device recognition (privacy)

**Unit**: 10, Mobile Platform Readiness (S-22). **Date**: 2026-10-25. **Revision**: 2 (after the Opus review of the same day). **Status**: APPROVED by James Petersen, 2026-10-25, with two points applied on approval: (1) BR-U10-35 also covers the user's `stop()`, which finalises and stops through the same exactly-once routine (otherwise a Stop tap during the error branch's awaiting finalise would finalise twice and TP-2b, which includes user stop, would fail); (2) the spelling convention is **British English** for all user-facing strings, matching `zip_broadcast/l10n/arb/app_en.arb` ("Behaviour" at line 168, "Colour" at lines 287 and 291), covering the `.arb` text and `NSSpeechRecognitionUsageDescription`.
**Amendment 01 stands.** This amendment narrows three of its rules (BR-U10-15 on what triggers a restart, BR-U10-18, and the section 3.3 mapping of `onDeviceModelMissing`) and extends TP-2; each change is named in section 8.
**Decision recorded**: James Petersen, 2026-10-25: keep `PlatformSttEngine` and make it truly fail closed. Apple's speech-recognition dialog stays, with the app's own explanation. Alpha 1 is internal testers only. Before any external release there is a gate on whether Sherpa-ONNX (prompt-free) becomes the mobile default (section 10). Option C (a native iOS 26 on-device API) is dropped: it still needs speech-recognition authorisation and is iOS 26 only.
**Review decisions applied (Opus, 2026-10-25):** R6 runner method channels (checker timeout is a named constant, value set in NFR Requirements); R7 the new factory; R8 no message matching (every retry is checked, so a throw is transient); R9 tightened wording; R10 device-level Android check accepted, with a device-pass step. Three must-fix items: finalise exactly once, first-error-wins for `start()`'s own assignment, and a refused `resume()`.

## 1. Why `onDevice: true` alone is not enough (corrected analysis)

Read from `speech_to_text` 7.3.0 source on 2026-10-25 (James Petersen reports the same in 7.4.0; that version was not read):

| Fact | Evidence |
|---|---|
| **iOS does not refuse.** When `onDevice` is true and `supportsOnDeviceRecognition` is false, the plugin replies with a `FlutterError` (`onDeviceError`) and **does not `return`**; it goes on to build the audio engine and a recognition request. Apple honours `requiresOnDeviceRecognition` only when on-device recognition is supported, so otherwise the task runs on Apple's servers until our failure path cancels it. A brief leak, not a refusal. | `SpeechToTextPlugin.swift:495-503` and `:545-546`. Confirmed at Code Generation. |
| **Android falls back silently.** `createOnDeviceSpeechRecognizer` is used only when `SDK_INT >= S` (31) and `isOnDeviceRecognitionAvailable` is true. Otherwise the default recogniser is used and no error is reported. | `SpeechToTextPlugin.kt:593-601` |
| **No pre-check is exposed.** The plugin reads `supportsOnDeviceRecognition` internally (`onDeviceStatus`) and never hands it to Dart. | `SpeechToTextPlugin.swift:338` |
| **The Dart layer drops the error code.** `listen()` turns a `PlatformException` into `ListenFailedException(e.message, e.details, e.stacktrace)`. Because the code is lost and the message is English text we do not control, this design does **not** classify a throw by its wording (section 4). | `speech_to_text.dart:491-493` |
| **SDK levels.** Both `SpeechRecognizer.createOnDeviceSpeechRecognizer` and `SpeechRecognizer.isOnDeviceRecognitionAvailable` are `since="31"`. | `android-36/data/api-versions.xml` |

The earlier throwaway runs set no `onDevice` at all (`evidence/q3-throwaway-check.md`, privacy correction). So the product must check support itself, before every `listen()`, and refuse when it fails.

## 2. Scope

1. An on-device support check before **every** `listen()`, including the engine's own restarts (section 3).
2. Refusal when unsupported, at start, during a restart and on resume (section 4).
3. Treating a `listen()` that throws as transient and always cancelling it (section 4).
4. A session is finalised and stopped exactly once (BR-U10-35).
5. A disclosure explainer before Apple's prompt, and a rewritten `NSSpeechRecognitionUsageDescription` (section 6).
6. Testable properties (section 9).

Not in scope: Sherpa-ONNX as default (a gate, section 10), desktop, `zip_broadcast`, `SttResult`, `RecordingState`, and the `SttEngine` interface beyond Amendment 01's approved channel.

## 3. Supplying the check

The plugin offers no check, so the app supplies one.

### 3.1 Decided shape (R6)

```dart
/// True only if on-device recognition is supported for [localeId] right now.
typedef OnDeviceSupportChecker = Future<bool> Function(String localeId);
```

- `PlatformSttEngine` takes it as a **required** constructor parameter (so a build cannot forget it). `zip_core` stays free of platform code. The `SttEngine` interface is untouched. This **changes the `PlatformSttEngine` constructor and its tests**.
- The implementation, `MethodChannelOnDeviceSupportChecker`, lives in `zip_captions` and talks to a small method channel in the two runners. Channel `app.zipcaptions/speech_support`, method `isOnDeviceSupported`, argument `localeId`.
  - **iOS** (Swift, in the Runner): `SFSpeechRecognizer(locale: Locale(identifier: …))?.supportsOnDeviceRecognition ?? false`. The locale mapping must be the same one the plugin applies to its recogniser (`getLocale(localeStr)`, `SpeechToTextPlugin.swift:361`), or the check could pass for a different locale than the listen uses. Verified at Code Generation.
  - **Android** (Kotlin, in `MainActivity` or a small class): `Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)`. Below API 31 counts as unsupported. The check is device-level, not language-level; a missing language pack fails closed at listen time (section 3.3).
  - **Any exception, `MissingPluginException`, `PlatformException` or timeout in the checker returns `false`** (fail closed). The timeout is a named constant, `onDeviceCheckTimeout`, whose value NFR Requirements sets. Desktop and web register no real engine, so the channel is never called there.
- The plugin's `androidIntentLookup` option must **never** be set: with it the plugin builds the default recogniser regardless of `onDevice` (`SpeechToTextPlugin.kt:577-582`).

### 3.2 Alternatives considered

- **A first-party plugin package** (e.g. `packages/zip_speech_support`) exposing the same checker to both apps. More reusable, but a new package and a new first-party dependency (SECURITY-10). Not chosen; revisit when `zip_broadcast` needs it.
- **An upstream change to `speech_to_text`.** Not ours to start; see section 10.

### 3.3 Known limits

- The check and the `listen()` are two calls, so support could change between them (for example a model removed). Because every retry is checked again (BR-U10-26), the next attempt refuses and that becomes the lasting error; BR-U10-31 cancels the attempt that slipped through.
- **The Android check is device-level only (R10, accepted).** `createOnDeviceSpeechRecognizer` is on-device only, so a language with no pack fails closed as a lasting error (`error_language_unavailable`, Amendment 01), not as online recognition. A device-pass step covers it (section 11).

## 4. Rules

| ID | Rule |
|---|---|
| BR-U10-26 | **Check before every `listen()`.** Every call to the plugin's `listen()` is immediately preceded by a call to the checker for that session's locale, and happens only if it returned `true`. This covers the first start, an internal restart (BR-U10-15), the restart in `resume()`, and `SttSessionManager`'s REL-U2.1 restart. The result is never cached across listens. |
| BR-U10-27 | **Refuse when unsupported.** A `false` result means no `listen()` call. Inside a `startListening()` call the engine reports `SttEngineError(onDeviceModelMissing)` through the error listener and returns `false`. Consequences by caller: at **start**, `start()` ends at `IdleState` and `RecordingScreen` shows the failure panel with the on-device message (section 5); during an **internal restart**, it is a lasting error, reported once, and the engine enters `failed` (BR-U10-18); during the **REL-U2.1 restart** and on **resume**, see BR-U10-35 and BR-U10-36. |
| BR-U10-28 | **First error wins during `start()`, in both places it is set.** (a) The Q5 wrapper in `RecordingStateNotifier.start()` keeps the first `RecordingError` reported through `onError` and ignores later ones. (b) `start()`'s own assignment at the `startListening()`-returned-`false` branch (`recording_state_notifier.dart:98`, `_lastError = RecordingErrorFactories.engineStartFailed()`) sets the error **only if none has been captured**. Without (b) the generic error would overwrite the on-device one. |
| BR-U10-29 | **Checker failure fails closed.** An exception or timeout from the checker is `false` (section 3.1). It is logged as the boolean only. |
| BR-U10-30 | **A `listen()` that throws is transient.** The engine does not look at the exception's message or type beyond catching it. It is counted as a failed attempt under BR-U10-17 (it counts toward the cap). During an internal restart no session exists, so no `done` will follow: the throw itself is the session end and, if the cap is not reached, the next attempt is scheduled after `restartDelay` and **is checked again first** (BR-U10-26). If on-device support has gone, that check refuses and the refusal is the lasting `onDeviceModelMissing`. At start, a throw makes `startListening()` return `false` as today. This is the one exception to "restart on `done` only" in BR-U10-15. No wording of the plugin's English error text is matched anywhere. |
| BR-U10-31 | **Cancel on any throw.** On **any** `ListenFailedException`, the engine calls `cancel()` on the plugin immediately, before anything else, because on iOS the plugin keeps going after replying with an error (section 1). A plugin **report** of an on-device failure through the error listener (the string iOS sends is confirmed at Code Generation) is also cancelled immediately and is lasting (`onDeviceModelMissing`). |
| BR-U10-32 | **Android intent lookup is never enabled** (section 3.1). A test asserts the engine never passes `androidIntentLookup`. |
| BR-U10-33 | **Disclosure explainer (iOS).** Before the first speech-permission request, a one-time explainer is shown (section 6). `start()` is never called on iOS until it has been acknowledged. |
| BR-U10-34 | **The app's own permission text** (`NSSpeechRecognitionUsageDescription`) is rewritten (section 6). |
| BR-U10-35 | **A session is finalised and stopped exactly once.** There is one internal routine that finalises the transcript, moves to `StoppedState`, publishes the `SessionStateEvent` and releases the wake lock, and it runs at most once per session: a flag set on entry makes any second call a no-op, and `start()` and `clearSession()` reset it. Every path that stops a session uses it: **both branches of `_handleEngineError`, the recovery future's failure and exception branches** (`recording_state_notifier.dart:236-243` and `:255-282`), **and the user's `stop()`** (approval point 1: a Stop tap while the error branch is still awaiting its finalise must not finalise a second time). **Why:** a refusal reported during the REL-U2.1 restart arrives while the state is `Reconnecting` with `_hasAttemptedRestart` already true, so the "error after restart attempt" branch begins finalise-and-stop; then `handleEngineError` returns `false`, and the recovery future resumes while that first finalise is still awaiting, still sees `ReconnectingState`, and would finalise and stop again (a double transcript finalisation and two `StoppedState` events). |
| BR-U10-36 | **A refused `resume()` stops the session.** While `resume()` is in progress, the notifier keeps the first error reported through `onError` (as `start()` does, BR-U10-28), instead of dropping it because the state is `Paused`. If `resume()` returns `false` and an error was captured, the session is treated like a restart refusal: it is stopped through the exactly-once routine (BR-U10-35), `lastError` is set to the captured error, and the BR-U10-23 notice is shown. A `resume()` that returns `false` with no captured error behaves as today (logged, stays `Paused`). Otherwise the user would stay in `Paused`, getting the same silent result on every tap. |

## 5. Failure message and view

- **New `RecordingErrorFactories.onDeviceRecognitionUnavailable()`**, used for `SttEngineErrorKind.onDeviceModelMissing`. **Reason a new one is needed:** `engineRequiresModelDownload()` says "A speech model must be downloaded before use", which is wrong for a device or locale that has no on-device support at all (nothing to download) and does not tell the user that the app refused on privacy grounds; `engineInitFailed()` and `engineStartFailed()` are generic and say nothing about why. This **changes the `onDeviceModelMissing` row of Amendment 01 section 3.3** from `engineRequiresModelDownload()` to the new factory.
- `StartFailureView` gets a kind `onDeviceUnavailable`: `showTryAgain` true, **`showOpenSettings` false** (app settings cannot enable an on-device model). The same classification feeds the mid-session notice (BR-U10-23).

## 6. Disclosure (iOS)

### 6.1 Explainer before Apple's prompt

- A dialog in `zip_captions`, shown on iOS only, once, before the first call to `start()`. Components: `SpeechExplainerGate` (decides) and the dialog. State in `SharedPreferences` (`onboarding.speechExplainerSeen`), set only when the user continues. "Not now" returns to Home with nothing requested.
- Android shows no explainer: its microphone dialog carries no third-party-processing text.

### 6.2 Wording (provisional until the airplane-mode device check passes)

The wording makes only claims Zip Captions controls and avoids absolute claims that the iOS plugin's bug window (section 1) could make false.

| `.arb` key | Text |
|---|---|
| `speechExplainerTitle` | Before your device asks for permission |
| `speechExplainerBody` | Zip Captions recognises speech on this device and doesn't send your audio anywhere. Next, iOS asks for microphone and speech recognition access. Apple's speech recognition message says speech data is sent to Apple. That's Apple's standard wording for every app. Zip Captions only captions when on-device recognition is available. |
| `speechExplainerContinue` / `speechExplainerNotNow` | Continue / Not now |
| `NSSpeechRecognitionUsageDescription` (Info.plist, the app's text shown with Apple's paragraph) | Zip Captions recognises speech on this device to show captions. It doesn't send your audio anywhere. |

Spelling: **British English** for all user-facing strings, matching `zip_broadcast/l10n/arb/app_en.arb` ("Behaviour", "Colour"). This covers the `.arb` text and `NSSpeechRecognitionUsageDescription`, and is recorded in the NFR maintainability section (decided on approval; the earlier "no precedent" finding looked only at `zip_captions` and `zip_core`). `Info.plist` text is not part of the `.arb` files and is English-only until an `InfoPlist.strings` per locale is added, which is out of scope and recorded as a limitation.

### 6.3 Failure text (`.arb`)

| Key | Text |
|---|---|
| `onDeviceUnavailableTitle` | On-device captions aren't available |
| `onDeviceUnavailableBody` | This device or language doesn't support on-device speech recognition, so Zip Captions didn't start. |

The earlier sentence "Your audio was not sent anywhere" is removed: the iOS plugin's missing `return` (section 1) could make it untrue. All strings go through `l10n/arb/app_en.arb` and `flutter gen-l10n`; generated files are never edited by hand.

## 7. Flow 6. Every `listen()` is checked

```
start / resume / internal restart / REL-U2.1 restart
  └─ checker(localeId)            (exception or timeout → false, within onDeviceCheckTimeout)
       ├─ false ── no listen() ── report onDeviceModelMissing through the error listener, return false
       │             ├─ start ............ IdleState + failure panel (first error wins, BR-U10-28)
       │             ├─ internal restart . lasting error once → failed
       │             ├─ REL-U2.1 restart . lasting error; the session is stopped ONCE (BR-U10-35)
       │             └─ resume ........... session stopped ONCE + notice (BR-U10-36)
       └─ true ─── listen(onDevice: true)
                    ├─ ok ........................► Flow 5 (Amendment 01)
                    └─ throws ListenFailedException
                         ├─ cancel() immediately
                         └─ transient: counts toward the cap; the retry runs the checker first,
                            and a lost on-device capability becomes the lasting refusal above
```

## 8. Changes to Amendment 01 and other documents

- **BR-U10-15:** restart is still driven by `done`, with the one named exception of a `listen()` that throws during a restart (BR-U10-30).
- **BR-U10-18:** the lasting set gains "the on-device check refused" and a plugin report of an on-device failure through the error listener. (An earlier draft also listed a thrown exception with on-device wording; that is removed, R8.)
- **Section 3.3 mapping:** `onDeviceModelMissing` → `onDeviceRecognitionUnavailable()` instead of `engineRequiresModelDownload()`.
- **TP-2 (extended again):** a refusal during the REL-U2.1 restart produces exactly one finalise and one `StoppedState` event (TP-2b below).
- **TP-8 and TP-13:** `StartFailureView` and the kind mapping include the new kind (`showOpenSettings` false for it).
- **TP-11:** the command set gains checker results (`true`, `false`, throws), `listen()` throwing, and resume.
- **Components added** to `domain-entities.md`: E7 `OnDeviceSupportChecker` and `MethodChannelOnDeviceSupportChecker` (with the two runner implementations), E8 `SpeechExplainerGate`. **`PlatformSttEngine`'s constructor changes.** `RecordingStateNotifier` also gains the exactly-once stop routine (BR-U10-35), the first-error-wins assignment (BR-U10-28) and the resume capture (BR-U10-36); none changes a public API or `RecordingState`.

## 9. Testable properties (PBT-01)

| ID | Category | Property |
|---|---|---|
| **TP-15** | Stateful (PBT-06), extends TP-11 | Over random command sequences with checker results (`true`, `false`, throws) and `listen()` outcomes (ok, throws): **every `listen()` call is immediately preceded by a checker call for the same locale that returned `true`**, and `listen()` is never called otherwise. The checker is never skipped for a restart, a resume or an outer REL-U2.1 restart, and its result is never reused. |
| **TP-16** | Invariant, table-driven | A `false` or throwing check **at start** → state `IdleState`, `lastError` equals `onDeviceRecognitionUnavailable()` (never `engineStartFailed()`), no wake lock, no `SessionStateEvent`, the failure panel shown, `showOpenSettings` false. **Rows include the `startListening()`-returned-`false` branch at `:98`**, which must set `lastError` only if none was captured (BR-U10-28 b), and the order in which the engine error and the generic failure arrive. |
| **TP-17** | Invariant | A `false` check during a restart, or a plugin-reported on-device failure, reports **exactly one** lasting `SttEngineError` and enters `failed` with no further `listen()`. A throwing `listen()` is **transient**: it counts toward the cap, and the next attempt is preceded by the checker; if that returns `false`, exactly one lasting error is reported. |
| **TP-18** | Invariant | After **any** `ListenFailedException`, `cancel()` is called before anything else, **whatever the exception's message**, and the failure is classified transient (no message matching: a test with arbitrary generated messages shows the same behaviour for all of them). |
| **TP-19** | Invariant (ordering) | On iOS, `start()` is never called before the explainer was acknowledged; once acknowledged (flag set) it is not shown again; "Not now" sets no flag and requests nothing. |
| **TP-2b** | Invariant (regression, extends TP-2) | A refusal (`false` check) during the REL-U2.1 restart produces **one** transcript finalisation, **one** `StoppedState` `SessionStateEvent`, and one wake-lock release; the recovery future's later `false` result does not repeat them. The same exactly-once property holds for every pair of stop triggers (error branch, recovery failure, recovery exception, user stop) in any order. |
| **TP-20** | Invariant, table-driven | A refused `resume()` (check `false`) → the session is stopped once (finalised once, `StoppedState`, wake lock released), `lastError` is `onDeviceRecognitionUnavailable()`, and the notice is shown. A `resume()` that returns `false` **without** a captured error stays `Paused` as before. |
| **TP-8 (extended)** | Invariant | `StartFailureView` classification is total over every error including the new kind; `showOpenSettings` is true only on iOS and Android for `micPermanentlyDenied` and `engineInitFailed`, never for `onDeviceUnavailable`. |
| **TP-12 (extended)** | Invariant (SECURITY-03) | No log record on the new path (checker, refusal, throw handling, finalise routine) contains transcript text; the checker logs only its boolean. |

Example-based pins (PBT-10): iOS unsupported → refusal text; Android API 30 → unsupported; checker throws or times out → refusal; the engine never passes `androidIntentLookup`; a `ListenFailedException` with an arbitrary message is cancelled and transient.

## 10. Known upstream defect, and the release gate

- **Upstream defect (recorded, not filed):** `speech_to_text` 7.3.0 (and, per James Petersen, 7.4.0) replies with `onDeviceError` on iOS without returning, so recognition starts anyway (`SpeechToTextPlugin.swift:495-503`); and its Dart layer drops the platform error code when it wraps a failure in `ListenFailedException`. Our checker makes the first unreachable in normal use; BR-U10-31 covers the window. **Nothing is filed upstream; James Petersen decides that.**
- **Release gate (goes into the `aidlc-state.md` Backlog after approval):** before any release beyond internal testers, decide whether Sherpa-ONNX (prompt-free; the parked on-device unit) becomes the mobile default, and prepare the app-store privacy answers (Unit 11) from Apple's dialog wording and this design.

## 11. NFR Requirements updates (applied after this amendment is approved)

- Mark NFR-U10-03 **decided**, citing Phase 1 NFR-2.1 and the mobile Alex scenario; set the value of `onDeviceCheckTimeout`.
- Device-pass verification: on a **physical iPhone and Android phone, captioning works in airplane mode** ("works without an internet connection"); on a device or locale without on-device support the app refuses with the failure panel; the Android logs show the on-device recogniser, not `Online recognizer`. **Add (R10):** switch to a language with no on-device pack and expect a refusal or the lasting error, not online recognition.
- Record that the emulator and Simulator runs of the throwaway check were not on-device (no `onDevice` was set); the evidence file already says so.
- Add the Backlog gate and the app-store privacy item (Unit 11).
- Record the upstream defect as known, unfiled.

## 12. Compliance of the amendment

| Rule | Status |
|---|---|
| SECURITY-03 | Compliant by design: boolean-only logging for the checker; no transcript in new logs (TP-12 extended) |
| SECURITY-09 | Compliant by design: unsupported means refuse, never a default recogniser; `androidIntentLookup` forbidden (BR-U10-32); no coupling to the plugin's error text |
| SECURITY-11 | Misuse considered: a user switching to a locale with no on-device model is refused, not silently sent to a server |
| SECURITY-15 | Compliant by design: checker failure, `listen()` throw and plugin error all fail closed; cancel on any throw; the session stops exactly once (BR-U10-35) so no path double-finalises or strands the user in `Paused` (BR-U10-36) |
| SECURITY-10 | No new package; a first-party plugin package was considered and not chosen |
| PBT-01, 03, 06 | TP-15 (stateful), TP-16 to TP-20, TP-2b and the extended TP-8, TP-12 |

No blocking findings.

## 13. Decisions

- **R6** runner method channels, `onDeviceCheckTimeout` named and set in NFR Requirements: decided. **R7** new factory: decided. **R8** no message matching; a throw is transient and always cancelled: decided. **R9** wording as in section 6.2, provisional until the airplane-mode check: decided. **R10** device-level Android check with a device-pass step: decided.
- **Decided on approval:** British English for all user-facing strings (section 6.2); BR-U10-35 also covers `stop()`.
