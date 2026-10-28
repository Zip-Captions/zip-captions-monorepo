# Logical Components: Unit 10, Mobile Platform Readiness (S-22, Alpha 1)

**Date**: 2026-10-25. **Status**: drafted on the proposed answers in `plans/mobile-platform-readiness-nfr-design-plan.md`, awaiting the NFR Design approval gate. Paths are where Code Generation will put things; **no file has been created or changed**.
Patterns referenced as P1 to P11 are in `nfr-design-patterns.md`.

## 1. `zip_core` (new or changed)

| Component | Path | Kind | Responsibility | Pattern |
|---|---|---|---|---|
| `SttErrorSource`, `SttEngineError`, `SttEngineErrorKind` | `lib/src/stt/stt_error_source.dart`, exported by `stt.dart` | new | Additive error channel: `void setErrorListener(void Function(SttEngineError)? listener)`; kind-only payload (no free text) | P5 |
| `OnDeviceSupportChecker` | `lib/src/stt/on_device_support_checker.dart` | new typedef | `Future<bool> Function(String localeId)` | P1, P10 |
| `SttListeningLimits`, `defaultSttListeningLimits` | `lib/src/constants/stt_listening_limits.dart`, exported by `constants.dart` | new | `restartCap = 3`, `immediateFailureWindow = 2 s`, `restartDelay = 250 ms`, `onDeviceCheckTimeout = 2 s` | P2 |
| `PlatformSttEngine` | `lib/src/stt/engines/platform_stt_engine.dart` | changed | Implements `SttEngine` and `SttErrorSource`; new required `onDeviceSupportChecker`; optional `limits` and `now`; private `_SessionLoop`; `_onDeviceAllowed`; assigns `_stt.statusListener`/`errorListener` after `initialize()`; listens with `SpeechListenOptions(onDevice: true, partialResults: true, cancelOnError: false)`; cancel on any `ListenFailedException` | P1, P2, P7 |
| `createPlatformSttEngine` | `lib/src/stt/engines/platform_stt_engine_factory.dart`, exported by `engines.dart` | new | Builds `PlatformSttEngine` with `SpeechToText()` so the plugin is declared only in `zip_core` | P5 |
| `MobileAudioDeviceService` | `lib/src/services/audio/mobile_audio_device_service.dart` | new | One system-default device; stores `audio.preferredInputDeviceId` in `SharedPreferences`; no routing | FD E2 |
| `RecordingErrorFactories.onDeviceRecognitionUnavailable()` | `lib/src/models/recording_error_factories.dart` | changed | The new refusal message (reason in Amendment 02, section 5) | P9 |
| `SttSessionManager` | `lib/src/services/stt/stt_session_manager.dart` | changed | Registers the error listener when the engine is an `SttErrorSource`, forwards each error once through the existing `onError` using the kind mapping, clears it in `dispose()`; no public API change | P5 |
| `RecordingStateNotifier` | `lib/src/providers/recording_state_notifier.dart` | changed | `_finishSession` single-flight routine used by every stop path including `stop()`, called **synchronously at `stop()`'s entry**, whose first step is `_sessionManager.stop()`, with the recovery future checking `_finishing != null` first and stopping the manager again, and `_handleEngineError` ignoring errors once `_finishing` is set (P4 a to d, TP-2c); operation-scoped capture in `start()` and `resume()`; `start()`'s direct assignment only if none captured; race rule; refused-resume rule; `$e` log line becomes `e.runtimeType`. No new state, field on `RecordingState`, or public method | P3, P4, P7 |

## 2. `zip_captions` (new or changed)

| Component | Path | Kind | Responsibility | Pattern |
|---|---|---|---|---|
| `registerSttEngines` | `lib/src/services/stt_engine_registration.dart` | new | Pure registration decision (platform, `allowDevEngines`, `forceFake`, `createPlatformEngine` closure) | P6 |
| `MethodChannelOnDeviceSupportChecker` | `lib/src/services/method_channel_on_device_support_checker.dart` | new | Thin call on channel `app.zipcaptions/speech_support`, method `isOnDeviceSupported`, argument `localeId`; the engine owns the timeout and exception handling | P1, P10 |
| `StartFailureView` and the failure panel | `lib/src/widgets/start_failure_view.dart` | new | Classification through the factories plus the panel (Try again, Open settings on iOS and Android only, Back) | P9 |
| `SpeechExplainerGate` and the dialog | `lib/src/widgets/speech_explainer_gate.dart` | new | iOS one-time explainer; `SharedPreferences` flag `onboarding.speechExplainerSeen` | P8 |
| `RecordingScreen` | `lib/src/screens/recording_screen.dart` | changed | Consults the gate, awaits `start()`, shows the failure panel, hides `RecordingControlsBar` while it shows, shows the mid-session notice on leaving for History | P8, P9 |
| `bootstrap.dart` (`runZipCaptions`) | `lib/src/bootstrap.dart` | changed | Builds `MobileAudioDeviceService` and the checker before the `ProviderContainer`; overrides `audioDeviceServiceProvider` on every platform; calls `registerSttEngines` with `createPlatformSttEngine` | P5, P6 |
| Strings | `l10n/arb/app_en.arb` (then `flutter gen-l10n`) | changed | `speechExplainer*`, `onDeviceUnavailable*`, failure and notice strings; **British English** | P8, P9 |
| Tests | `test/pbt/`, `test/helpers/pbt.dart` (copied shim) | new | Placement in P11 | P11 |

## 3. Runners (platform code, no new package)

| Component | Path | Kind | Responsibility |
|---|---|---|---|
| iOS channel | `ios/Runner/AppDelegate.swift` | changed | In `didInitializeImplicitFlutterEngine(_:)`, create `FlutterMethodChannel(name: "app.zipcaptions/speech_support", binaryMessenger: engineBridge.applicationRegistrar.messenger())` (Flutter's "Migrate AppDelegate" step 2 in the UIScene delegate breaking-change page and the platform-channels guide; matches `FlutterEngine.h:466-471` in the local SDK); unknown methods return not-implemented, which the Dart side already treats as unsupported; `isOnDeviceSupported` returns `SFSpeechRecognizer(locale: …)?.supportsOnDeviceRecognition ?? false`, with the same locale mapping as the plugin (`getLocale`). No new `.swift` file, so no `project.pbxproj` edit |
| Android channel | `android/app/src/main/kotlin/…/MainActivity.kt` | changed | Override `configureFlutterEngine`, call `super`, then `MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.zipcaptions/speech_support")`; unknown methods return not-implemented (treated as unsupported on the Dart side); returns `Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)` |
| Android manifest | `android/app/src/main/AndroidManifest.xml` | changed | Explicit `RECORD_AUDIO`, `<queries>` for `android.speech.RecognitionService`, `android:label="Zip Captions"`; no `INTERNET` |
| Android identity | `android/app/build.gradle.kts` and `MainActivity.kt` location | changed | `applicationId` and `namespace` `app.zipcaptions.captions`; `MainActivity.kt` relocated to match |
| iOS identity and permissions | `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`, `ios/Podfile` | changed | `PRODUCT_BUNDLE_IDENTIFIER = app.zipcaptions.captions` for the Runner target only (not `RunnerTests`); `CFBundleDisplayName` "Zip Captions"; rewritten `NSSpeechRecognitionUsageDescription` (British English); `PERMISSION_MICROPHONE=1` in `post_install` |

## 4. Dependencies and wiring

```
bootstrap ──► MobileAudioDeviceService(prefs) ──► ProviderContainer(overrides: audioDeviceServiceProvider, ...)
          ──► MethodChannelOnDeviceSupportChecker ─┐
          ──► registerSttEngines(... createPlatformEngine: () =>
                createPlatformSttEngine(checker, deviceService)) ──► SttEngineRegistry
sttEngineProvider (first registered) ──► RecordingStateNotifier ──► SttSessionManager ──► engine (SttEngine + SttErrorSource)
engine ─ onDeviceSupportChecker(locale) ─► channel ─► runner (Swift / Kotlin)
engine ─ setErrorListener(_forward) ◄── SttSessionManager ──► onError ──► RecordingStateNotifier (_captured / _handleEngineError)
```

No new package; `speech_to_text` 7.3.0, `permission_handler` and their locked versions are unchanged.

## 5. Rejected alternatives

| Alternative | Why not |
|---|---|
| Separate public `ContinuousListeningController` with a plugin adapter | A public type and an adapter nobody else needs; revisit if the engine file passes about 400 lines |
| `package:clock` for session length | Adds a runtime dependency (`clock` is dev-only today) |
| A boolean flag for exactly-once stop | A Stop tap could return before the first finalise completes |
| Caching the on-device check | Reopens the window the check exists to close |
| Timeout only inside the channel wrapper | A custom or fake checker could hang a listen |
| New `.swift` file for the iOS channel | Needs a `project.pbxproj` edit |
| Declaring `speech_to_text` in `zip_captions` | Two declaration points for the plugin the design is pinned to |
| A first-party plugin package for the checker | New package and dependency; replaced later by the plugin's own `has_on_device_support` |
| Circuit breaker, queue, cache, rate limiter | No fit; the restart cap is the only failure budget |

## 6. Items to confirm at Code Generation (not design blockers)

- *(Settled in the Opus review, 2026-10-25, and removed from this list: the iOS channel API, now stated in section 3; and the existing `stop()` sequence, now described in P4 with the rewiring rules.)*
- The iOS locale mapping used by the checker versus the plugin's `getLocale`; the string iOS sends for `onDeviceError` through the error listener; the iOS missing-`return` behaviour in 7.3.0.
- Android error-code strings and the iOS equivalents against the locked source (R5).
- Whether `PlatformSttEngine.dispose()` is also reached by `SttSessionManager.dispose()` in every path (listener cleanup).
