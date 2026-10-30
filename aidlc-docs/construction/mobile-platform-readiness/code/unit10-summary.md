# Unit 10 (Mobile Platform Readiness, S-22): Code Generation Summary

**Status**: COMPLETE for plan Steps 31 and 32, 2026-10-30. Branch `feature/mobile-platform-readiness`, PR #44 to `develop`. The first draft was dated 2026-10-28; this refresh covers Amendments 06 to 08, every review round, and the device passes.
**Plan**: `aidlc-docs/construction/plans/mobile-platform-readiness-code-generation-plan.md`.
**Verification note**:
- **File lists:** `git diff --name-status origin/develop -- packages` and `git status`, 2026-10-30.
- **Test files per property:** `git grep --untracked "TP-<n>"` over `packages/*/test`.
- **Device results:** `evidence/code-generation-qa.md`.

## 1. Purpose and scope

Unit 10 makes Zip Captions capture and caption speech on Android and iOS (S-22, Alpha 1). It covers:
- FR-6.1 and FR-6.3 on mobile;
- NFR-1.1, the physical-device gate;
- NFR-2.1: no audio or transcript leaves the device without opt-in.

**In scope**: `zip_core` and `zip_captions`.

**Engines**:
- **iOS:** `PlatformSttEngine` (speech_to_text 7.3.0), with the Amendment 01 restart loop and the Amendment 02 fail-closed on-device guard.
- **Android:** `SegmentedSpeechEngine` on Android 13 and later (Amendment 03): silent continuous captioning through `EXTRA_SEGMENTED_SESSION`, with a session renewed every 300 s.

**Amendments**:

| Amendment | What it added |
|---|---|
| 04 | A missing-language path: the download action, and instructions on iOS before 26 |
| 05 | A stop after 5 minutes without speech |
| 06 (revisions 1 to 3) | The last phrase is drained for up to 1 s at Stop and Pause. Recovery is re-armed by the first non-empty result. Stop is bounded at 5 s, and abandoned work never touches a new session. Three save outcomes. Results held during a start or a resume. The BR-U10-40 wording fix |
| 07 | One combined notice per stop |
| 08 | iOS segments at a 1.5 s pause inside the running session, trimmed by committed word count. Punctuation and capitals on iOS (`autoPunctuation`, dictation hint) and on Android (`EXTRA_ENABLE_FORMATTING`) |

**Also in scope**: the QA fixes Q-1 to Q-7.

**Stable contracts unchanged**: `SttResult`, `RecordingState`, `RecordingError` and `AudioDeviceService`. `SttEngine` gained only the sibling `SttErrorSource`.

**Not touched**:
- `zip_broadcast` (BR-U10-14, record-only);
- desktop runners and engine registration;
- every `pubspec.yaml`.

## 2. Files created and modified

Source: `git diff --name-status origin/develop -- packages`, plus the working tree, 2026-10-30. Paths are relative to `packages/<package>/`.

Generated files are not listed below:
- **`*.g.dart`, 8 in all.** In `zip_core`, 7:
  - `recording_state_notifier` and `resolved_locale_id_provider`, changed;
  - `device_locales_provider`, `session_stop_reason_provider`, `speech_inactivity_timeout_provider`, `stop_finalise_timeout_provider` and `transcript_save_outcome_provider`, new.

  In `zip_captions`, 1: `language_pack_providers`, new.
- **`*.freezed.dart`, 2 new:** `language_pack_service.freezed.dart` and `stt_error_source.freezed.dart` (Step 29g).

### 2.1 `zip_core` created

- **Constants:**
  - `lib/src/constants/stt_listening_limits.dart`: `SttListeningLimits`, including `segmentedSessionLength`, the restart and early-end caps, `finalResultDrainTimeout` and `iosSegmentPause`;
  - `speech_inactivity.dart`;
  - `stop_finalise_timeout.dart`.
- **Models:** `lib/src/models/transcript_save_result.dart`.
- **STT:**
  - `lib/src/stt/stt_error_source.dart`: `SttEngineError` (freezed), the kinds, and the `SttErrorSource` mixin;
  - `on_device_support_checker.dart`.
- **Engines:**
  - `lib/src/stt/engines/platform_stt_engine_factory.dart`;
  - `segmented_speech_engine.dart` and `segmented_speech_engine_factory.dart`;
  - `segmented_recognizer_bridge.dart`.
- **Services:**
  - `lib/src/services/language_pack/language_pack.dart` and `language_pack_service.dart` (`LanguagePackInfo`, freezed);
  - `lib/src/services/audio/mobile_audio_device_service.dart`.
- **Providers:** `lib/src/providers/device_locales_provider.dart`, `session_stop_reason_provider.dart`, `speech_inactivity_timeout_provider.dart`, `stop_finalise_timeout_provider.dart` and `transcript_save_outcome_provider.dart`.
- **Tests:**
  - `test/constants/stt_listening_limits_test.dart`;
  - `test/stt/stt_error_source_test.dart`;
  - `test/stt/engines/segmented_speech_engine_test.dart`;
  - in `test/services/`: `platform_stt_engine_factory_test.dart`, `platform_stt_engine_loop_test.dart`, `platform_stt_engine_early_events_test.dart`, `platform_stt_engine_segments_test.dart` and `mobile_audio_device_service_test.dart`;
  - `test/services/language_pack/language_pack_service_test.dart`;
  - in `test/providers/`: `recording_state_notifier_unit10_test.dart`, `recording_state_notifier_amendment06_test.dart`, `recording_state_notifier_inactivity_test.dart`, `speech_inactivity_providers_test.dart` and `device_locales_provider_test.dart`;
  - in `test/pbt/`: `inactivity_stop_properties_test.dart`, `locale_resolution_properties_test.dart`, `log_hygiene_properties_test.dart`, `platform_stt_engine_properties_test.dart` and `recording_state_notifier_properties_test.dart`.
- **Test helpers:** `call_log.dart`, `fake_listen_call.dart`, `fake_speech_to_text.dart`, `fake_on_device_checker.dart`, `fake_segmented_recognizer_bridge.dart`, `fake_language_pack_service.dart` and `mock_error_source_stt_engine.dart`.

### 2.2 `zip_core` modified

- **Exports:**
  - `lib/src/constants/constants.dart`, `lib/src/models/models.dart`, `lib/src/stt/stt.dart`, `lib/src/stt/engines/engines.dart`, `lib/src/services/audio/audio.dart`, `lib/src/services/services.dart` and `lib/src/providers/providers.dart`;
  - `lib/src/stt/stt_engine.dart`, which has a doc comment only.
- **`lib/src/stt/engines/platform_stt_engine.dart`:**
  - the guard and listen options;
  - the session loop and the epoch;
  - the early-event hold;
  - the drain;
  - the stop guard after a new start;
  - the Amendment 08 pause commit and trim.
- **`lib/src/models/recording_error_factories.dart`:** `onDeviceRecognitionUnavailable()`.
- **`lib/src/services/stt/stt_session_manager.dart`:** the error listener and the stop-generation guard.
- **`lib/src/providers/recording_state_notifier.dart`:**
  - capture and the race rule;
  - single-flight `_finishSession`, `start()` and `resume()`;
  - the inactivity timer;
  - the Stop bound, and an abandoned finish;
  - held results;
  - recovery re-arming.
- **`lib/src/output/transcript_writer_target.dart` and `lib/src/providers/transcript_writer_target_provider.dart`:**
  - the lazy session row;
  - the ordered write chain;
  - continuity;
  - the three save outcomes;
  - no writes after a failed create.
- **`lib/src/providers/resolved_locale_id_provider.dart`:** Q-3.
- **Tests:** `test/services/platform_stt_engine_test.dart`, `stt_session_manager_test.dart`, `test/integration/transcript_capture_integration_test.dart`, `test/models/recording_error_factories_test.dart`, `test/output/transcript_writer_target_test.dart`, `test/providers/recording_state_notifier_test.dart` and `resolved_locale_id_provider_test.dart`.

### 2.3 `zip_captions` created

- **Services:** `lib/src/services/stt_engine_registration.dart`, `method_channel_on_device_support_checker.dart`, `method_channel_segmented_recognizer_bridge.dart` and `method_channel_language_pack_service.dart`.
- **Providers:** `lib/src/providers/language_pack_providers.dart`.
- **Widgets:** `lib/src/widgets/start_failure_view.dart`, `speech_explainer_gate.dart`, `language_pack_action.dart` and `language_pack_section.dart`.
- **Runner:** `android/app/src/main/kotlin/app/zipcaptions/captions/MainActivity.kt`. This is a rename target; the old `com/zipcaptions/zip_captions/MainActivity.kt` is deleted.
- **Tests:**
  - in `test/services/`: `stt_engine_registration_test.dart`, `method_channel_on_device_support_checker_test.dart`, `method_channel_segmented_recognizer_bridge_test.dart` and `method_channel_language_pack_service_test.dart`;
  - `test/providers/language_pack_providers_test.dart`;
  - in `test/widgets/`: `start_failure_view_test.dart`, `speech_explainer_gate_test.dart`, `language_pack_action_test.dart` and `language_pack_section_test.dart`.
- **Test helpers:**
  - `test/helpers/pbt.dart`, a `cp` of the `zip_core` copy;
  - `fake_language_pack_service.dart`.

### 2.4 `zip_captions` modified

- **`lib/src/bootstrap.dart`:** `@visibleForTesting registerAppSttEngines` (Q-7).
- **`lib/src/screens/recording_screen.dart`:** one notice per stop (Amendment 07).
- **Strings:** `l10n/arb/app_en.arb` and `lib/src/l10n/zc_strings.dart` (`ZcStrings` getters and methods). No generated l10n file changed.
- **Android:** `android/app/src/main/AndroidManifest.xml` and `android/app/build.gradle.kts`.
- **`MainActivity.kt`, as above:**
  - the segmented recogniser;
  - the language-pack calls;
  - `result.success(null)`;
  - the sink cleared on teardown;
  - the Amendment 08 formatting extras.
- **iOS:**
  - `ios/Runner/AppDelegate.swift` and `ios/Runner/Info.plist`;
  - `ios/Runner.xcodeproj/project.pbxproj`: the Runner bundle ID only, now `app.zipcaptions.captions`;
  - `ios/Podfile`: the `PERMISSION_MICROPHONE=1` macro;
  - `ios/Podfile.lock`, regenerated.
- **Tests:** `test/bootstrap_test.dart`, `test/widgets/recording_screen_test.dart`, `test/l10n/zc_strings_test.dart` and `test/helpers/fake_recording_state_notifier.dart`.

### 2.5 Unchanged

- `zip_broadcast`: no file in the diff against `develop`. The untracked `packages/zip_broadcast/android/` and `ios/` folders in the QA worktree are local build output, and are not committed.
- macOS and the other desktop runners.
- `speech_to_text` 7.3.0 and all pubspecs.
- `docs/`.

## 3. Tests by property

Test files were found with `git grep --untracked "TP-<n>"` over `packages/zip_core/test` and `packages/zip_captions/test`. Paths are relative to `packages/`.

Every id is named in a test, except:
- **TP-26 and TP-27:** matched by content;
- **TP-48's Android half:** no test, because the runner's Kotlin has no unit tests. It rests on the device check.

| Property | Subject | Test file(s) |
|---|---|---|
| TP-1 | Notifier failure table, including the engine-error-during-start row | `zip_core/test/providers/recording_state_notifier_unit10_test.dart` |
| TP-2 | Reconnect path via an `SttErrorSource` fake | `zip_core/test/providers/recording_state_notifier_unit10_test.dart` |
| TP-2b | One finalise for any pair of stop triggers | `zip_core/test/providers/recording_state_notifier_unit10_test.dart` (example-based) |
| TP-2c | Stop versus REL-U2.1 recovery interleavings | `zip_core/test/pbt/recording_state_notifier_properties_test.dart`, plus an example case in `recording_state_notifier_unit10_test.dart` |
| TP-3, 4, 5, 10 | Registration: never the fake in release; the debug rules; `createPlatformEngine` only when registered; the release registry | `zip_captions/test/services/stt_engine_registration_test.dart` |
| TP-6, TP-12 | No transcript text in logs. `SttEngineError` carries no payload. Scenarios S1 to S10 cover the segmented path, the language pack, the inactivity stop, held results and the pause commit | `zip_core/test/pbt/log_hygiene_properties_test.dart` |
| TP-7 | `MobileAudioDeviceService` | `zip_core/test/services/mobile_audio_device_service_test.dart` |
| TP-8 | `StartFailureView` classification totality | `zip_captions/test/widgets/start_failure_view_test.dart` |
| TP-9 | `lastError` over start, stop and clear sequences | `zip_core/test/pbt/recording_state_notifier_properties_test.dart` |
| TP-11, 14, 15, 17 | iOS engine loop model; a pending interim delivered as final at most once; the checker before every `listen()`; one lasting error | `zip_core/test/pbt/platform_stt_engine_properties_test.dart` |
| TP-13 | Error code and kind mapping | `zip_core/test/pbt/platform_stt_engine_properties_test.dart`, `zip_core/test/services/stt_session_manager_test.dart` |
| TP-16, TP-20 | A refusal never becomes `engineStartFailed()`; a refused `resume()` | `zip_core/test/providers/recording_state_notifier_unit10_test.dart` |
| TP-18 | `ListenFailedException` handling | `zip_core/test/services/platform_stt_engine_test.dart` |
| TP-19 | Explainer gate (iOS only, once) | `zip_captions/test/widgets/speech_explainer_gate_test.dart` |
| TP-21 to 24 | `SegmentedSpeechEngine`: the model, the code map, segment trimming, and `recreate()` on codes 5 and 11 | `zip_core/test/stt/engines/segmented_speech_engine_test.dart` |
| TP-25 | Locale resolution | `zip_core/test/pbt/locale_resolution_properties_test.dart`, `zip_core/test/providers/resolved_locale_id_provider_test.dart` |
| TP-26, TP-27 | No row without a segment; continuity under resume and recovery | `zip_core/test/output/transcript_writer_target_test.dart` (by content) |
| TP-28 to 31 | Language-pack action, providers, panel, channel and `supportedLocales()` | `zip_captions/test/widgets/language_pack_action_test.dart`, `language_pack_section_test.dart` and `recording_screen_test.dart`; `zip_captions/test/providers/language_pack_providers_test.dart`; `zip_captions/test/services/method_channel_language_pack_service_test.dart`; `zip_core/test/stt/engines/segmented_speech_engine_test.dart` |
| TP-32, TP-33 | Inactivity stop and notice | `zip_core/test/pbt/inactivity_stop_properties_test.dart`, `zip_core/test/providers/recording_state_notifier_inactivity_test.dart`, `zip_captions/test/widgets/recording_screen_test.dart` |
| TP-34 | Drain of the last phrase, both engines (Amendment 06) | `zip_core/test/services/platform_stt_engine_test.dart`, `zip_core/test/stt/engines/segmented_speech_engine_test.dart` |
| TP-35 to 37, 39 to 41 | Drained final before finalise; recovery re-armed; the Stop bound, extended in revision 3; held results; a throwing stop; a throwing pause | `zip_core/test/providers/recording_state_notifier_amendment06_test.dart`. Revision 3's engine cases (TP-37 extended) are in `platform_stt_engine_test.dart` and `segmented_speech_engine_test.dart`, matched by content |
| TP-38 | Save outcome per ending | `zip_core/test/output/transcript_writer_target_test.dart`, `zip_captions/test/widgets/recording_screen_test.dart` |
| TP-42 | Language-pack deadlines and the Android scheduled state | `zip_captions/test/widgets/language_pack_section_test.dart` |
| TP-43 | One notice per stop (Amendment 07) | `zip_captions/test/widgets/recording_screen_test.dart` |
| TP-44 | The Amendment 07 strings | `zip_captions/test/l10n/zc_strings_test.dart` |
| TP-45 to 47 | iOS pause commit, trim by word count with reset detection (revision 2), drain after a commit (Amendment 08) | `zip_core/test/services/platform_stt_engine_segments_test.dart` (TP-45 and TP-46 include a Glados property) |
| TP-48 | Listen options: `onDevice`, `autoPunctuation` and the dictation mode. The Android extras are checked on the device | `zip_core/test/services/platform_stt_engine_segments_test.dart`, `platform_stt_engine_test.dart` |

**Existing tests changed** (named, per the plan's rule):
- the two Phase 1 locale resolver expectations: first-supported was replaced by the en-CA rules;
- the integration case `stop with no results`: now no row at all;
- the lifecycle case `recording event calls createSession`: now the lazy-creation case;
- the `recording_screen_test.dart` Q-1 cases, tightened with the fake's `startGate`;
- the four "queues … after …" notice tests, replaced by TP-43;
- the writer's "a failing write does not block the writes after it", which now fails a save, not the create;
- the listen-options test, extended for Amendment 08.

**Test totals** (2026-10-30, after Step 29k): `zip_core` 1308 passed, 5 skipped; `zip_captions` 443 passed; `zip_broadcast` 195 passed. `dart analyze --fatal-infos` clean in all three.

## 4. Self-check tables (plan section 5, filled in)

**S-22 acceptance criteria**

| Criterion | Delivered by | Verified |
|---|---|---|
| Fresh install, no permission: the OS asks for the microphone (and speech on iOS); once granted, captioning starts | Steps 17 to 26, Groups G and H | **Pixel 6:** prompt, grant, captions with recognised text, segments saved (B0, B1). **iOS Simulator:** explainer, both prompts, captions (A6, A7). A physical iPhone is still open |
| Microphone denied: the permission-denied state, with a way to open settings, and no crash | Steps 14, 15, 20, 22 (TP-1, TP-8) | **Pixel 6:** PASS. Revoke, Don't allow, then the panel with Open settings; grant, then Try again starts captioning. Also passed on the Android emulator |
| Live captions under 1 s | not an emulator claim | Not measured. Captions looked immediate on the Pixel 6, but no latency figure was taken. Physical gate (Step 32) |
| Screen stays on while captioning, with the normal timeout after | existing `WakeLockService` | **Pixel 6:** `Awake` more than 5 minutes after the last touch, `Dozing` about 45 s after Stop (B10). iOS: physical gate |

**Business rules and properties**

| Group | Rules | Tests | Status |
|---|---|---|---|
| Registration and debug fake | BR-U10-01 to 07a | TP-3, 4, 5, 10 | Implemented. The Q-7 fix is confirmed on the Simulator (the real engine ran) |
| Failure behaviour | BR-U10-08 to 11a, 25, 28, 35, 36 | TP-1, 2, 2b, 2c, 9, 16, 20 | Implemented |
| Engine loop and guard (iOS) | BR-U10-15 to 21, 24, 26 to 32 | TP-11, 13, 14, 15, 17, 18 | Implemented; captions on the Simulator |
| Segmented Android engine | BR-U10-37 to 45 | TP-21 to 24 | PASS on the Pixel 6, including the 300 s renewal with one chime and no lost words |
| Session manager and channel | BR-U10-22, 23 | TP-13, 12 | Implemented |
| Logging | BR-U10-12, 13, 21, 49 | TP-6, 12 | Implemented. The phone's app log carried IDs only |
| Disclosure | BR-U10-33, 34 | TP-19; Info.plist | Simulator: the explainer once; Not now returns to Home |
| Audio device | BR-U10-05 | TP-7 | Implemented |
| Language pack | BR-U10-46 to 50 | TP-28 to 31, 42 | Android download PASS on the emulator. iOS download PASS on the Simulator, so A-1 is confirmed |
| Inactivity stop | BR-U10-51 to 54 | TP-32, 33 | PASS on the Pixel 6 and the Simulator |
| Last phrase, recovery, Stop bound, outcomes | BR-U10-55 to 64 | TP-34 to 42 | Last phrase at Stop ×3 and Pause: PASS on both platforms. Recovery and the 5 s bound cannot be provoked on a device, so unit tests only |
| One notice per stop | BR-U10-65 to 67 | TP-43, 44 | PASS on the Pixel 6 and the Simulator for the inactivity and empty-session cases. Error and save-failed cases: tests only |
| Segments and punctuation | BR-U10-68 to 73 | TP-45 to 48 | PASS on the Pixel 6 and the Simulator (Amendment 08 device check) |
| `zip_broadcast` | BR-U10-14 | none | No file in the diff |

**NFR obligations**:
- **Delivered by the steps listed in the plan:** NFR-U10-01 to 03b, 05, 07, 08, 08a and 08b, and PBT-09.
- **Airplane mode** (works offline): PASS on the Pixel 6.
- **Still open for a physical iPhone:** NFR section 8 item 3 (Step 32 below).

## 5. Deviations from the plan's letter

1. **`SttSessionManager` stop-generation guard.** Added during review, so that a stop landing while an initialise or start is awaiting cannot be overtaken by a stale continuation.
   - `stop()` increments `_stopGeneration`.
   - The engine-error recovery captures the generation, and returns `false` if it changed after its awaits.
   - No public API change.
2. **iOS error-code R5 extension.** The iOS codes were read from the 7.3.0 Swift source and classified:
   - lasting: `error_speech_recognizer_request_not_authorized`, `error_assets_not_installed` and `error_speech_recognizer_disabled`;
   - silence: `error_no_match`;
   - everything else: transient.

   The `onDeviceError` string comparison and the missing `return` after its FlutterError (upstream #673) matter only when `supportsOnDeviceRecognition` is false. Their outcome is not recorded in `audit.md`.
3. **`start()` fails closed on any throw.** It goes to `IdleState` with the stage's error, never into recording.
4. **Engine epoch (Step 16a 1a, extended in Step 29e).**
   - The epoch moves on stop, pause and dispose.
   - `startListening()` and `_restart` compare it after each await, so no `listen()` is made after a stop or a pause.
   - A stale restart never cancels a resumed session.
5. **`_runFinish` try/finally.** These always run, inside the 5 s bound (BR-U10-58): `StoppedState`, the `SessionStateEvent` and the wake-lock release.
6. **The reverted TP-11/TP-15 hold-and-interrupt model.** It did not converge. BR-U10-19 is covered by targeted tests instead. The model was shown trustworthy by a mutation check.
7. **D-2 revised from 60 to 5 minutes.** The recogniser rejects values above 300,000 ms. The Pixel 6 accepted 300,000 ms. Its renewal waits for the next pause when speech continues (evidence, observation 1).
8. **Q-7 (iOS engine registration).** `registerSttEngines` takes the typed `TargetPlatform`.
9. **BR-U10-40 wording.** Resolved: corrected 2026-10-29 (Amendment 06 section 5). Silence is never a transient failure, but an early silence end counts under BR-U10-44.
10. **Amendment 06 N7 not done.** A widget test of the non-overlay `runZipCaptions` call needs Supabase, a database and secure storage. It was declined as disproportionate.

## 6. QA findings Q-1 to Q-7

- **Q-1, double start:** the explainer gate is the sole owner of `start()`, and `start()` and `resume()` are single-flight.
- **Q-2, empty transcripts:** the session row is created lazily, so a zero-segment session leaves no row and shows one notice.
- **Q-3, default locale:** explicit choice first, then the phone's languages, then en-CA.
- **Q-4, transcript continuity:** the same session id continues the transcript.
- **Q-5, missing language pack:** Amendment 04's download action.
- **Q-6, `kotlin.Unit` reply:** all replies are `result.success(null)`.
- **Q-7, iOS registration:** a typed `TargetPlatform`. Rule adopted: identifier string comparisons ignore case, and a typed value is preferred.

**Change requests from the device passes, all built:**
- one notice per stop: Amendment 07, from the Android pass;
- iOS segments at pauses, and punctuation on both platforms: Amendment 08, from the iOS pass.

## 7. Review rounds

| Date | Round | Outcome | Plan step |
|---|---|---|---|
| 2026-10-28 | Whole-unit review (code-review, high) | 10 items: 6 fixed test-first (F1 to F6), 3 for the owner (all later resolved by Amendment 06), 1 rejected (D-4) | 29d |
| 2026-10-29 | PR #44 review (a PR comment) | 5 findings fixed, plus a stale-restart cancel found in Opus review | 29e |
| 2026-10-29 | CodeRabbit, first pass | Amendment 06 revisions 1 and 2, plus fixes with no design change. #14, #17 and #18 declined | 29f |
| 2026-10-30 | CodeRabbit, second pass | #17 and #18 accepted (freezed). `languagePackSink` cleared. PR description rewritten | 29g |
| 2026-10-30 | CodeRabbit, full review | Info.plist wording declined, as the approved text. No writes after a failed create. Amendment 06 revision 3 | 29i |
| 2026-10-30 | Device passes | Amendment 07 (Android pass) and Amendment 08 (iOS pass) | 29h, 29j |
| 2026-10-30 | CodeRabbit, incremental review of `9b171cc` (the full review exceeds 100 files) | 7 findings. Fixed: the iOS late cancel during an in-flight start; reset detection (Amendment 08 revision 2); a test assertion; comments. Declined C, D and E with replies | 29k |

## 8. Known gaps

- **Desktop and `zip_broadcast` untouched (BR-U10-14).** `zip_broadcast` doesn't receive `SttErrorSource` errors and doesn't use the inactivity stop (BR-U10-54). Both are Backlog items. G10 stays open for `zip_broadcast`.
- **Android floors differ.** Captioning needs API 33 (D-1), but the app installs from API 24. Below API 33 the user sees the on-device panel.
- **`speech_to_text` stays at 7.3.0.** The upstream fixes (#673/#678) are only in the 7.6.0 betas.
- **The Unit 11 manifest review must cover:**
  - the inherited `INTERNET` permission, and `BLUETOOTH` with `maxSdkVersion` 30;
  - `ACCESS_LOCAL_NETWORK`, which Android 17 shows as "Nearby devices". It was granted on the Pixel 6 and comes from a dependency.

  The release merged manifest was not inspected in this unit.
- **Release privacy gate**: open in the `aidlc-state.md` Backlog.
- **No language selector in the app.** On iOS, the phone's language setting is the only route. This is in the Backlog (`aidlc-state.md`).
- **Amendment 08 limitations, accepted:**
  - the iOS trim works by word count, so if Apple revises a committed word, the boundary can repeat or drop a word;
  - revision 2 detects a reset of the cumulative text, so a rewrite of more than half of the committed words looks like a reset and repeats the phrase;
  - the screen splits at 1.5 s, but the writer merges finals less than 2 s apart;
  - iOS 13 to 15 show no punctuation.
- **A late iOS final can reach the next session.** This happens when it arrives more than 1 s after Stop or Pause, once a new start or a resume has begun. The fix needs a plugin change, so it's in the Backlog (`aidlc-state.md`).
- **iOS sounds not checked.** Android sounds pass BR-U10-43.
- **UI observations, not defects in Unit 10's logic:**
  - the text-size button is very small on the permission-denied panel;
  - a Stop tap twice failed to register on its first press (the cause is unknown);
  - after Back from a transcript on Android, the History list keeps the title "Transcript".
- **Not provokable on a device:** recovery twice, the 5 s Stop bound, the error and save-failed notice combinations, download failure, and the scheduled state. Unit tests only.

## 9. Step 32: Physical-device gate (remaining checks)

**G1 is not closed.** Android is done on a physical phone. iOS has been seen only on the Simulator. James Petersen has no iPhone on hand at this time.

### Android (Pixel 6, Android 17): done

Passed on the device: Steps 6, 6b, 7 and 8, and the 5-minute renewal with one chime and no lost words, which answers Amendment 01 (a) and (b) for the segmented engine. Also passed:
- one sound at Stop (BR-U10-43);
- screen on;
- the inactivity stop;
- airplane mode;
- microphone denied and granted;
- the Amendment 06 last phrase;
- Amendments 07 and 08.

**Still open on Android:**
- an NFR-1.1 latency measurement;
- the language-pack download on a phone (the pack was already installed; it passed on the emulator);
- an unsupported locale refused on a phone (R10).

### iOS (a physical iOS 26 device)

- **NFR section 8 item 3:**
  - Phase 1 exit criterion 1;
  - NFR-1.1 latency;
  - the screen kept on under real power management;
  - on-device availability (NFR-U10-02, 04);
  - the `SIGABRT` watch (NFR-U10-09);
  - airplane mode;
  - an unsupported locale refused;
  - the explainer wording confirmed true.
- **Amendment 01 restart observations on iOS:**
  - (a) any sound on an internal restart;
  - (b) words lost between sessions.

  Each is to be answered "acceptable for Alpha 1?" by James Petersen.
- **Sounds** at Start, Pause, Resume and Stop.
- **Amendment 08 on real hardware:** segments at pauses, and punctuation.
- **Assumption A-1 was confirmed on the iOS 26.0 Simulator.** A device run confirms it on hardware.
