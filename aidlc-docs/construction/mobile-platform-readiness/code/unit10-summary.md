# Unit 10 (Mobile Platform Readiness, S-22): Code Generation Summary

**Status**: DRAFT for plan Steps 31 and 32. Branch `feature/mobile-platform-readiness` (local commit `665a595`, not pushed; later work uncommitted). Drafted 2026-10-28 from the plan, the functional-design amendments and `evidence/code-generation-qa.md`.
**Plan**: `aidlc-docs/construction/plans/mobile-platform-readiness-code-generation-plan.md`.
**Verification note**: file lists come from `git diff --name-status 84e32b7 -- packages` and `git status` (2026-10-28); the test file per property comes from `git grep --untracked` over `packages/*/test`; the deviations were checked against the code and `audit.md`. Items still marked "(not verified)" could not be confirmed from those sources.

## 1. Purpose and scope

Unit 10 makes Zip Captions capture and caption speech on Android and iOS (S-22, Alpha 1). It covers FR-6.1 and FR-6.3 on mobile, NFR-1.1 (physical-device gate) and NFR-2.1 (no audio or transcript leaves the device without opt-in).

- **In scope**: `zip_core` and `zip_captions`.
- **iOS**: `PlatformSttEngine` (speech_to_text 7.3.0) with the Amendment 01 restart loop and the Amendment 02 fail-closed on-device guard.
- **Android**: `SegmentedSpeechEngine` on Android 13 and later (Amendment 03), silent continuous captioning through `EXTRA_SEGMENTED_SESSION`.
- **Added by amendment**: a missing-language recovery path (Amendment 04), a 5-minute inactivity stop (Amendment 05), and the QA fixes Q-1 to Q-7.
- **Stable contracts unchanged**: `SttResult`, `RecordingState`, `RecordingError`, `AudioDeviceService`. `SttEngine` gained only the sibling `SttErrorSource`.
- **Not touched**: `zip_broadcast` (BR-U10-14, record-only), desktop runners and engine registration, every `pubspec.yaml`.

## 2. Files created and modified

Source: `git diff --name-status 84e32b7 -- packages` (branch base) plus untracked files from `git status`, 2026-10-28. Paths are relative to `packages/<package>/`. `*.g.dart` files are not listed: 7 generated files changed or created (6 in `zip_core`: `device_locales_provider`, `recording_state_notifier`, `resolved_locale_id_provider`, `transcript_save_outcome_provider`, `session_stop_reason_provider`, `speech_inactivity_timeout_provider`; 1 in `zip_captions`: `language_pack_providers`). No `*.freezed.dart` changed.

### 2.1 `zip_core` created

- `lib/src/constants/stt_listening_limits.dart` (`SttListeningLimits`, `defaultSttListeningLimits`, including `segmentedSessionLength`, the restart cap and the early-end caps), `lib/src/constants/speech_inactivity.dart` (`defaultSpeechInactivityTimeout`, 5 minutes)
- `lib/src/stt/stt_error_source.dart` (`SttEngineError`, kinds, and the `SttErrorSource` mixin), `lib/src/stt/on_device_support_checker.dart`
- `lib/src/stt/engines/platform_stt_engine_factory.dart`
- `lib/src/stt/engines/segmented_speech_engine.dart`, `segmented_speech_engine_factory.dart`, `segmented_recognizer_bridge.dart` (sealed `SegmentedRecognizerEvent` and `SegmentedRecognizerBridge`)
- `lib/src/services/language_pack/language_pack.dart`, `language_pack_service.dart`
- `lib/src/services/audio/mobile_audio_device_service.dart`
- `lib/src/providers/device_locales_provider.dart`, `session_stop_reason_provider.dart`, `speech_inactivity_timeout_provider.dart`, `transcript_save_outcome_provider.dart`
- Tests: `test/constants/stt_listening_limits_test.dart`, `test/stt/stt_error_source_test.dart`, `test/stt/engines/segmented_speech_engine_test.dart`, `test/services/platform_stt_engine_factory_test.dart`, `platform_stt_engine_loop_test.dart`, `platform_stt_engine_early_events_test.dart`, `mobile_audio_device_service_test.dart`, `test/services/language_pack/language_pack_service_test.dart`, `test/providers/recording_state_notifier_unit10_test.dart`, `recording_state_notifier_inactivity_test.dart`, `speech_inactivity_providers_test.dart`, `device_locales_provider_test.dart`, and `test/pbt/` `inactivity_stop_properties_test.dart`, `locale_resolution_properties_test.dart`, `log_hygiene_properties_test.dart`, `platform_stt_engine_properties_test.dart`, `recording_state_notifier_properties_test.dart`
- Test helpers: `fake_speech_to_text.dart`, `fake_on_device_checker.dart`, `fake_segmented_recognizer_bridge.dart`, `fake_language_pack_service.dart`

### 2.2 `zip_core` modified

- `lib/src/constants/constants.dart`, `lib/src/stt/stt.dart`, `lib/src/stt/stt_engine.dart`, `lib/src/stt/engines/engines.dart`, `lib/src/services/audio/audio.dart`, `lib/src/services/services.dart`, `lib/src/providers/providers.dart` (exports and, for `stt_engine.dart`, a doc comment per the plan)
- `lib/src/stt/engines/platform_stt_engine.dart` (guard, listen options, session loop, epoch fix, early-event hold)
- `lib/src/models/recording_error_factories.dart` (`onDeviceRecognitionUnavailable()`)
- `lib/src/services/stt/stt_session_manager.dart` (error listener, stop-generation guard)
- `lib/src/providers/recording_state_notifier.dart` (capture, race rule, single-flight `_finishSession`, single-flight `start()` and `resume()`, inactivity timer)
- `lib/src/output/transcript_writer_target.dart` and `lib/src/providers/transcript_writer_target_provider.dart` (lazy session row, ordered write chain, continuity, save outcome)
- `lib/src/providers/resolved_locale_id_provider.dart` (Q-3)
- Tests: `test/services/platform_stt_engine_test.dart`, `stt_session_manager_test.dart`, `test/helpers/mock_stt_engine.dart`, `test/integration/transcript_capture_integration_test.dart`, `test/models/recording_error_factories_test.dart`, `test/output/transcript_writer_target_test.dart`, `test/providers/resolved_locale_id_provider_test.dart`. `recording_state_notifier_test.dart` is not modified; the notifier tests are in the new `recording_state_notifier_unit10_test.dart`.

### 2.3 `zip_captions` created

- `lib/src/services/stt_engine_registration.dart`, `method_channel_on_device_support_checker.dart`, `method_channel_segmented_recognizer_bridge.dart`, `method_channel_language_pack_service.dart`
- `lib/src/providers/language_pack_providers.dart`
- `lib/src/widgets/start_failure_view.dart`, `speech_explainer_gate.dart`, `language_pack_action.dart`, `language_pack_section.dart`
- `android/app/src/main/kotlin/app/zipcaptions/captions/MainActivity.kt` (a rename target: the old `com/zipcaptions/zip_captions/MainActivity.kt` is deleted)
- Tests: `test/services/stt_engine_registration_test.dart`, `method_channel_on_device_support_checker_test.dart`, `method_channel_segmented_recognizer_bridge_test.dart`, `method_channel_language_pack_service_test.dart`, `test/providers/language_pack_providers_test.dart`, `test/widgets/start_failure_view_test.dart`, `speech_explainer_gate_test.dart`, `language_pack_action_test.dart`, `language_pack_section_test.dart`
- Test helpers: `test/helpers/pbt.dart` (a `cp` of the `zip_core` copy), `fake_language_pack_service.dart`

### 2.4 `zip_captions` modified

- `lib/src/bootstrap.dart` (adds `@visibleForTesting registerAppSttEngines`, Q-7)
- `lib/src/screens/recording_screen.dart`
- `l10n/arb/app_en.arb` and `lib/src/l10n/zc_strings.dart` (`ZcStrings` getters; no generated l10n file changed)
- `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`
- `android/.../MainActivity.kt` as above (segmented recogniser, language-pack calls, `result.success(null)` fix)
- `ios/Runner/AppDelegate.swift`, `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj` (Runner bundle ID only, three lines, now `app.zipcaptions.captions`)
- `ios/Podfile` (adds the `PERMISSION_MICROPHONE=1` macro in `post_install`) and `ios/Podfile.lock` (regenerated: new plugin pods for plugins already in the app, plus the Podfile checksum; not a checksum-only change)
- Tests: `test/bootstrap_test.dart`, `test/widgets/recording_screen_test.dart`, `test/l10n/zc_strings_test.dart`, `test/helpers/fake_recording_state_notifier.dart`. `recording_screen_settings_test.dart` is not modified.

### 2.5 Unchanged

`zip_broadcast` (empty `git diff --stat` at each gate, last recorded 2026-10-27), macOS and other desktop runners, `speech_to_text` 7.3.0 and all pubspecs, `docs/`.

## 3. Tests by property

Test files were found with `git grep --untracked "TP-<n>"` over `packages/zip_core/test` and `packages/zip_captions/test`. Paths are relative to `packages/`. Every id is named in a test except TP-26 and TP-27, which are matched by content.

| Property | Subject | Test file(s) |
|---|---|---|
| TP-1 | Notifier failure table, incl. the engine-error-during-start row | `zip_core/test/providers/recording_state_notifier_unit10_test.dart` |
| TP-2 | Reconnect path via an `SttErrorSource` fake | `zip_core/test/providers/recording_state_notifier_unit10_test.dart` |
| TP-2b | One finalise for any pair of stop triggers | `zip_core/test/providers/recording_state_notifier_unit10_test.dart` (example-based; no PBT file names it) |
| TP-2c | Stop versus REL-U2.1 recovery interleavings | `zip_core/test/pbt/recording_state_notifier_properties_test.dart`; example case in `recording_state_notifier_unit10_test.dart` |
| TP-3 | Fake never registered with `allowDevEngines: false` | `zip_captions/test/services/stt_engine_registration_test.dart` |
| TP-4 | Debug registration rules | `zip_captions/test/services/stt_engine_registration_test.dart` |
| TP-5 | `createPlatformEngine` only when registered | `zip_captions/test/services/stt_engine_registration_test.dart` |
| TP-6 | No transcript text in logs | `zip_core/test/pbt/log_hygiene_properties_test.dart` |
| TP-7 | `MobileAudioDeviceService` | `zip_core/test/services/mobile_audio_device_service_test.dart` |
| TP-8 | `StartFailureView` classification totality | `zip_captions/test/widgets/start_failure_view_test.dart` |
| TP-9 | `lastError` over start, stop, clear sequences | `zip_core/test/pbt/recording_state_notifier_properties_test.dart` |
| TP-10 | Release registry holds exactly the platform engine | `zip_captions/test/services/stt_engine_registration_test.dart` |
| TP-11 | Engine loop stateful model (iOS) | `zip_core/test/pbt/platform_stt_engine_properties_test.dart` |
| TP-12 | `SttEngineError` carries no payload; extended to segmented path, language pack and inactivity logs (S9) | `zip_core/test/pbt/log_hygiene_properties_test.dart` |
| TP-13 | Error code and kind mapping | `zip_core/test/pbt/platform_stt_engine_properties_test.dart`, `zip_core/test/services/stt_session_manager_test.dart` |
| TP-14 | Pending interim delivered as final at most once | `zip_core/test/pbt/platform_stt_engine_properties_test.dart` |
| TP-15 | Checker precedes every `listen()` | `zip_core/test/pbt/platform_stt_engine_properties_test.dart` (shared model with TP-11) |
| TP-16 | Refusal never becomes `engineStartFailed()` | `zip_core/test/providers/recording_state_notifier_unit10_test.dart` |
| TP-17 | False check during a restart gives one lasting error | `zip_core/test/pbt/platform_stt_engine_properties_test.dart` |
| TP-18 | `ListenFailedException` handling | `zip_core/test/services/platform_stt_engine_test.dart` |
| TP-19 | Explainer gate (iOS only, once) | `zip_captions/test/widgets/speech_explainer_gate_test.dart` |
| TP-20 | Refused `resume()` | `zip_core/test/providers/recording_state_notifier_unit10_test.dart` |
| TP-21 | `SegmentedSpeechEngine` stateful model | `zip_core/test/stt/engines/segmented_speech_engine_test.dart` |
| TP-22 | Segmented code map | `zip_core/test/stt/engines/segmented_speech_engine_test.dart` |
| TP-23 | Segments: trim, empty, partials | `zip_core/test/stt/engines/segmented_speech_engine_test.dart` |
| TP-24 | `recreate()` on codes 5 and 11 only | `zip_core/test/stt/engines/segmented_speech_engine_test.dart` |
| TP-25 | Locale resolution | `zip_core/test/pbt/locale_resolution_properties_test.dart`, `zip_core/test/providers/resolved_locale_id_provider_test.dart` |
| TP-26 | No transcript row without a segment; outcome reported | no test names this id; covered by content in `zip_core/test/output/transcript_writer_target_test.dart` (lazy-row case) (by content) |
| TP-27 | Continuity under resume and recovery | no test names this id; covered by content in `zip_core/test/output/transcript_writer_target_test.dart` (same-session continuation cases) (by content) |
| TP-28 | Language pack action and providers | `zip_captions/test/widgets/language_pack_action_test.dart`, `zip_captions/test/providers/language_pack_providers_test.dart` |
| TP-29 | Language pack panel | `zip_captions/test/widgets/language_pack_section_test.dart`, `zip_captions/test/widgets/recording_screen_test.dart` |
| TP-30 | Language pack channel | `zip_captions/test/services/method_channel_language_pack_service_test.dart` |
| TP-31 | `supportedLocales()` | `zip_core/test/stt/engines/segmented_speech_engine_test.dart`, `zip_captions/test/widgets/language_pack_section_test.dart` |
| TP-32 | Inactivity stop | `zip_core/test/pbt/inactivity_stop_properties_test.dart`, `zip_core/test/providers/recording_state_notifier_inactivity_test.dart` |
| TP-33 | Inactivity notice | `zip_captions/test/widgets/recording_screen_test.dart` |

**TP-1 to TP-33, TP-2b, TP-2c**: the plan asked for TP-1 to TP-20; Amendments 03 to 05 added TP-21 to TP-33. **Existing tests changed** (named per the plan's rule): the two prior-Phase-1 locale resolver expectations (first-supported replaced by the en-CA rules); the integration `stop with no results` case (no row at all); the lifecycle `recording event calls createSession` (now the lazy-creation case); `recording_screen_test.dart` Q-1 cases tightened with the fake's `startGate`. The existing test files modified (from the diff) are `platform_stt_engine_test.dart`, `stt_session_manager_test.dart`, `mock_stt_engine.dart`, `transcript_capture_integration_test.dart`, `recording_error_factories_test.dart`, `transcript_writer_target_test.dart`, `resolved_locale_id_provider_test.dart`, `bootstrap_test.dart`, `recording_screen_test.dart`, `zc_strings_test.dart` and `fake_recording_state_notifier.dart`. Which individual cases were changed beyond the four named above: (not verified).

**Test totals** (after the review fixes): `zip_core` 1150 passed, 4 skipped; `zip_captions` 402 passed; `zip_broadcast` 195 passed, no `zip_broadcast` file changed. Previous gate figures, 2026-10-28 (Opus verification of Q-7): `zip_core` 1141 passed, 4 skipped; `zip_captions` 402; `zip_broadcast` 195.

## 4. Self-check tables (plan section 5, filled in)

**S-22 acceptance criteria**

| Criterion | Delivered by | Verified |
|---|---|---|
| Fresh install, no permission: the OS asks for the microphone (and speech on iOS); once granted, captioning starts | Steps 17 to 26, Groups G and H | Android emulator: permission prompt, deny and grant paths PASS. iOS Simulator: explainer, microphone prompt and speech prompt PASS after Q-7. Captioning start with real recognised text: **not demonstrated** on either (see section 8). Physical gate open. |
| Microphone denied: permission-denied state with a way to open settings, no crash | Steps 14, 15, 20, 22 (TP-1, TP-8) | Android emulator PASS (deny once: no Open settings; deny twice: Open settings opens App info; Back returns). Physical gate open. |
| Live captions under 1 s | not an emulator claim | Physical gate only. Not verified. |
| Screen stays on while captioning, normal timeout after | existing `WakeLockService` | Android emulator: `KEEP_SCREEN_ON` 1 while captioning, 0 after Stop and after the inactivity stop (PASS). iOS and real power management: physical gate. |

**Business rules and properties**

| Group | Rules | Tests | Status |
|---|---|---|---|
| Registration and debug fake | BR-U10-01 to 07a | TP-3, 4, 5, 10 | Implemented; Q-7 fix covers the iOS typo (test-level evidence only) |
| Failure behaviour | BR-U10-08 to 11a, 25, 28, 35, 36 | TP-1, 2, 2b, 2c, 9, 16, 20 | Implemented |
| Engine loop and guard (iOS) | BR-U10-15 to 21, 24, 26 to 32 | TP-11, 13, 14, 15, 17, 18 | Implemented; not demonstrated on a device |
| Segmented Android engine | BR-U10-37 to 45 | TP-21 to 24 | Implemented; real-audio behaviour not demonstrated |
| Session manager and channel | BR-U10-22, 23 | TP-13, 12 | Implemented |
| Logging | BR-U10-12, 13, 21, 49 | TP-6, 12 | Implemented; phrase-word greps over VM logs gave 0 matches |
| Disclosure | BR-U10-33, 34 | TP-19; Info.plist | Simulator: explainer once, Not now returns Home (PASS) |
| Audio device | BR-U10-05 | TP-7 | Implemented |
| Language pack | BR-U10-46 to 50 | TP-28 to 31 | Android download PASS on the emulator; iOS A-1 open |
| Inactivity stop | BR-U10-51 to 54 | TP-32, 33 | Android emulator PASS (twice by accident, once by design) |
| `zip_broadcast` | BR-U10-14 | none | Diff-checked empty |

**NFR obligations**: NFR-U10-01 to 03b, 05, 07, 08, 08a, 08b and PBT-09 delivered by the steps listed in the plan. NFR section 8 item 3 and the Amendment 01 restart observations stay open for the device pass.

## 5. Deviations from the plan's letter

1. **`SttSessionManager` stop-generation guard.** Added during review so that a stop that lands while an initialise or start is awaiting cannot be overtaken by a stale continuation. Final shape (checked in `stt_session_manager.dart`): `stop()` increments `_stopGeneration`; the engine-error recovery captures the generation and returns `false` if it changed after the initialise or start awaits. No public API change.
2. **iOS error-code R5 extension.** The Android codes in the locked 7.3.0 source match Amendment 01 section 4.1 exactly. The iOS codes were read from the same version's Swift source and classified: `error_speech_recognizer_request_not_authorized`, `error_assets_not_installed` and `error_speech_recognizer_disabled` are lasting, `error_no_match` is silence, and everything else is transient (audit entry on Part 2 deviations). The comparison of the iOS `onDeviceError` string and the missing `return` after its FlutterError (upstream #673, fix PR #674) is described in the plan but its outcome is not recorded in `audit.md` as found: (not verified). It only matters when `supportsOnDeviceRecognition` is false.
3. **`start()` fails closed on any throw.** `RecordingStateNotifier.start()` catches any thrown object and fails closed to `IdleState` with the stage's error (audit entry on Part 2 deviations), never into recording. The per-stage mapping of each catch to a `RecordingError`: (not verified).
4. **Engine epoch fix (Step 16a 1a).** A new epoch on `_SessionLoop` moves in `stopRequested()`, `pauseRequested()` and `dispose()`. `startListening()` compares it after the device-preference await, after the on-device check (no `listen()` at all) and after the plugin's `listen()` (an already started session is cancelled). A related fix for `resume()` (1b) leaves `StoppedState` with one finalise.
5. **`_runFinish` try/finally (Step 16a 2).** Finalise runs inside `try`; `StoppedState`, the `SessionStateEvent` and the wake-lock release always run in `finally`. The log line carries `e.runtimeType` only.
6. **Reverted TP-11/TP-15 hold-and-interrupt model (Step 16a).** The stateful model was extended with hold-and-interrupt commands to cover BR-U10-19. It did not converge (a model-versus-engine listen-count mismatch on a transient restart) and was reverted to the pre-session model. BR-U10-19 is covered by eight targeted tests in `platform_stt_engine_test.dart`. The reverted model was shown trustworthy by the cap-comparison mutation check (`<` to `<=` in `_countFailureReachedCap` failed the property test; restoring it passed).
7. **D-2 revised from 60 to 5 minutes.** The recogniser rejected 3,600,000 ms ("too high, ignored"), which drops the segmented session. A probe on `ZipCaptions_QA_API_36` found the maximum is exactly 300,000 ms (300 s accepted twice; 301, 360, 420, 600 and 3,600 s rejected). Decided by James Petersen, 2026-10-26. The physical-device pass re-checks the limit.
8. **Q-7 (iOS engine registration).** `registerSttEngines` now takes the typed `TargetPlatform`. See Q-7 below.
9. **Wording conflict, not yet fixed.** BR-U10-40 says silence codes 6 and 7 are "never counted"; BR-U10-44 and D-4 count silence ends that arrive before 90% of the session length as early ends. The design text needs a wording fix. The code follows BR-U10-44.

## 6. QA findings Q-1 to Q-7

- **Q-1 (double start)**: the screen and the explainer gate both called `start()`; fixed by making the gate the sole owner and `start()` and `resume()` single-flight.
- **Q-2 (empty transcripts)**: the session row is now created lazily before the first segment; a zero-segment session leaves nothing and shows one "No speech was recognised" notice.
- **Q-3 (default locale)**: the resolver now follows explicit choice, then the phone's languages, then en-CA, never an arbitrary first supported locale.
- **Q-4 (transcript continuity)**: a republished recording state with the same session id continues the transcript instead of resetting the count and duration.
- **Q-5 (missing language pack)**: the on-device refusal panel offered no way forward; Amendment 04 adds a download action (Android 13+, iOS 26+) and instructions below iOS 26.
- **Q-6 (`kotlin.Unit` reply)**: `result.success(Unit)` could not be encoded by the standard codec, so every Android captions start failed; all replies are now `result.success(null)`.
- **Q-7 (iOS registration)**: `bootstrap.dart` passed `'iOS'` and the registration compared it with `'ios'`, so iOS debug used the dev fake and iOS release registered no engine. Fixed with a typed `TargetPlatform`; rule adopted: identifier string comparisons ignore case, and a typed value is preferred.

## 7. Known gaps

- **Desktop and `zip_broadcast` untouched.** Desktop engine registration and the broadcast recording path are out of scope (BR-U10-14). `zip_broadcast` does not receive `SttErrorSource` errors and does not use the Amendment 05 inactivity stop (BR-U10-54); both are Backlog items.
- **G10 for `zip_broadcast`**: G10 (no real speech recogniser registered in either app) is closed for `zip_captions` on mobile. For `zip_broadcast` it is recorded only and stays open (`aidlc-state.md` Backlog; `phase2-unit-of-work.md` G10 row: "zip_broadcast is recorded only").
- **Android floors differ.** Captioning needs API 33 (D-1); the app installs from API 24 (`flutter.minSdkVersion`). Below API 33 the user sees the on-device panel and no captions.
- **`speech_to_text` stays at 7.3.0.** The upstream fixes (#673/#678) are only in 7.6.0 betas. iOS depends on 7.3.0 behaviour, including the missing `return` after the `onDeviceError` FlutterError.
- **Unit 11 must review the release merged manifest**, including the inherited `INTERNET` permission and `BLUETOOTH` with `maxSdkVersion` 30 (both come from dependencies; the debug merged manifest also carries `USE_BIOMETRIC`, `USE_FINGERPRINT`, `MODIFY_AUDIO_SETTINGS` and `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`). The release manifest itself was not inspected in this unit.
- **Release privacy gate**: the release privacy gate in the `aidlc-state.md` Backlog stays open.
- **Android recognition not demonstrated.** Emulator captions failed four times with the emulator's audio input dying (`pcm_readi` I/O errors, no app error). A run with James speaking into the Mac microphone did recognise text and save a transcript with `segmentCount` 1.
- **iOS Simulator recognition not demonstrated.** Listening started with the real engine and the on-device check true, but no text or error appeared. See the diagnosis in Step 32.
- **Sound at Stop.** James heard what sounded like the start and stop chimes together at Stop (BR-U10-43 expects one).
- **Review observations pending a decision**: a final phrase that arrives after Stop or Pause is dropped by design (BR-U10-42); a successful mid-session recovery does not re-arm the one-recovery rule (Amendment 01 section 3.4); finalising a transcript at Stop has no timeout. These are open questions for James, not defects confirmed by a test.

## 8. Review round (2026-10-28)

- A whole-unit review (code-review, high) found 10 items. Six were confirmed and fixed test-first:
  - **F1**: `SegmentedSpeechEngine` counts codes 5 and 11 before recreating, so a service that keeps dying reaches `restartCapReached`.
  - **F2**: bridge events are dropped until a session has begun since the last start, stop or pause. A late end from a paused session no longer causes a second concurrent start.
  - **F3**: `PlatformSttEngine` holds plugin status, error and result events that arrive while the first start or a resume `listen()` is in flight, and replays them once the session is marked started. Stop, pause and dispose still win.
  - **F4**: `deviceLocalesProvider` rebuilds on a system locale change (`WidgetsBindingObserver.didChangeLocales`).
  - **F5**: `sessionStopReasonNotifierProvider`, `speechInactivityTimeoutProvider`, `languagePackServiceProvider` and `languagePackOsVersionProvider` are `riverpod_generator` providers (AGENTS.md).
  - **F6**: every `// ignore` that Unit 10 added in `lib` code is gone. BR-U10-20's explicit plugin arguments are now pinned by the listen-options test instead; `SttErrorSource` became a mixin; the save-outcome and stop-reason notifiers use setters; the constant is now `defaultSpeechInactivityTimeout`.
- Three items are for James Petersen to decide (listed in the joint QA runbook): a final phrase that arrives after Stop or Pause is dropped (BR-U10-42); the one-recovery rule is not re-armed after a successful recovery (Amendment 01 section 3.4); finalising a transcript at Stop has no timeout.
- One item was rejected: counting silence codes 6 and 7 as early ends is decision D-4 (BR-U10-44). Only BR-U10-40's "never counted" wording needs aligning (see deviation 9).
- Gates after the fixes: `dart analyze --fatal-infos` clean in `zip_core`, `zip_captions` and `zip_broadcast`; `zip_core` 1150 passed, 4 skipped; `zip_captions` 402 passed; `zip_broadcast` 195 passed, and no `zip_broadcast` file changed.

## 9. Step 32: Physical-device gate (remaining checks)

**G1 is not closed.** The emulator and Simulator passes are recorded; nothing below has been seen on a physical device. These need a physical device or James.

### Android (Android 13 or later phone)

- **Step 6** (captions): recognised text on screen, `segmentCount` > 0, en-US (or the expected locale), no SnackBar or toast, no engine error, no extra "Segmented session started" during 20 s of silence. Blocked on the emulator by the audio input failure.
- **Step 6b** (the continuity and renewal run as defined in the Step 30 protocol; exact protocol text: not verified).
- **Step 7** (Stop): a new transcript with `segmentCount` > 0; keep-screen-on flag cleared after Stop. The clearing half passed on the emulator; the transcript half did not.
- **Step 8** (as defined in the Step 30 protocol; exact text: not verified).
- **5-minute renewal chime (D-2)**: with speech continuing past 5 minutes, count the sounds and confirm one chime per renewal and the word gap at each renewal; confirm 300,000 ms is accepted on the phone's recogniser.
- **Stop double-chime observation**: confirm whether Stop sounds once (BR-U10-43) or the start and stop chimes together.
- **NFR section 8 item 3** (`nfr-requirements.md`): physical iPhone and Android phone checks of Phase 1 exit criterion 1, NFR-1.1 latency, screen kept on, on-device availability (NFR-U10-02, 04), the restart behaviour and `restartDelay`, `onDeviceCheckTimeout`, the `SIGABRT` watch (NFR-U10-09), and the privacy checks: airplane mode, an unsupported device or locale refused, Android logs show the on-device recogniser, a no-pack language refused (R10), and the explainer wording confirmed true.
- **Amendment 01 restart observations**: (a) does Android chime on each internal restart, and how often; (b) are words lost between sessions. Each is to be answered "acceptable for Alpha 1?" by James Petersen; a "no" returns to design. On Android, (a) was answered on 2026-10-26: James Petersen did not accept a restart chime, which led to Amendment 03 (the segmented engine) and its sound budget BR-U10-43. What remains on the phone is to confirm BR-U10-43 holds and to answer (b) for the segmented renewal every 5 minutes. On iOS, (a) and (b) are still open.

### iOS (a physical iOS 26 device)

- **Steps 3 to 5**: captions run (recognised text, `segmentCount` > 0, expected locale, no toast); the missing-language panel path; continuous run, pause and resume, silent 10 s and the Amendment 05 stop. Step 3 on the Simulator produced no recognised text and no error; the cause is not established.
- **Assumption A-1**: an `AssetInventory` download makes `supportsOnDeviceRecognition` true for that locale. **Inconclusive on the Simulator** (the property reports true while no recognition model assets are visible there; "iOS 26 Simulator: inconclusive, on-device recognition not demonstrated"). It needs a physical iOS 26 device, where the property, the DictationTranscriber download and real recognition can be observed together.
