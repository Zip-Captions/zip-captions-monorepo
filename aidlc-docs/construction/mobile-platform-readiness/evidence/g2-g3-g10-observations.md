# Unit 10 evidence: G2, G3 and G10 observations

**Unit**: Mobile Platform Readiness (S-22, Alpha 1)
**Observed**: 2026-10-24, develop at `84e32b7`, branch `feature/mobile-platform-readiness`
**Mode**: read-and-observe only. No source file was changed to produce this evidence.
**Scope limit**: virtual devices only. Nothing here proves physical-device behaviour (latency, wake lock, recognizer availability on real hardware).

## OQ-MA-1 (iOS speech-recognition consent), partial answer

`xcrun simctl privacy help` on the iPhone 17 Simulator (iOS 26.0, runtime 23A8464) lists these services:
`all, calendar, contacts-limited, contacts, location, location-always, photos-add, photos, media-library, microphone, motion, reminders, siri`.

**No speech-recognition service is listed**, so speech-recognition consent cannot be pre-granted with `simctl privacy grant`. Microphone can be.

Not yet answered: whether `simctl privacy <udid> reset all` brings the speech-recognition prompt back between runs. The prompt only appears when a real engine asks for it (see G10), so this needs a real engine registered. `reset all com.zipcaptions.zipCaptions` itself returned exit code 0.

Status of the OQ-MA-1 row: stays OPEN until the reset behaviour is observed.

## G10 (new): no real recogniser is registered

Source evidence:
- `packages/zip_captions/lib/src/bootstrap.dart:83-85`: `if (kDebugMode) { container.read(sttEngineRegistryProvider).register(FakeSttEngine()); }`. Nothing else registers an engine, so a release build has none.
- `packages/zip_broadcast/lib/src/providers/stt_engine_factory_provider.dart:19-22`: returns `FakeSttEngine()` under `kDebugMode`, otherwise throws `UnimplementedError('sttEngineFactoryProvider must be overridden at app startup.')`. The provider's comment says it is "typically `PlatformSttEngine`". No app startup code overrides it.
- A search of `zip_core/lib`, `zip_captions/lib` and `zip_broadcast/lib` for `PlatformSttEngine` and `SherpaOnnxSttEngine` finds only their own definitions.

Runtime evidence, `Pixel_9_Pro_API_36` (Android 16, API 36, after a wipe-data cold boot), debug build, `RECORD_AUDIO` not granted:
- Before the tap: `dumpsys package com.zipcaptions.zip_captions` shows `android.permission.RECORD_AUDIO: granted=false`. MCP `screenshot` and `get_navigation_stack` show `HomeScreen` at `/`. See `android-01-home-before-tap.png`.
- After tapping Start Captioning (`adb shell input tap`): no permission prompt. `get_navigation_stack` shows `RecordingScreen` at `/recording`. `dumpsys` still shows `granted=false`. See `android-02-recording-after-tap-fake-engine.png`, which shows the text "Hello and welcome to Zip Captions."
- MCP `console_logs` (fetch):
  - `[zip_core.SttSessionManager] Engine fake initialized for locale en-US`
  - `[zip_core.SttSessionManager] Engine fake listening`
  - `[zip_core.RecordingStateNotifier] Session started: <id>`
  - then `TranscriptWriterTarget` and `TranscriptRepository` `saveSegment` lines.
- The log lines carry session and segment ids only, no caption text.

Conclusion: debug captioning runs on a fake engine and never reaches the microphone permission check. G2 and G3 cannot be reproduced through the app until a real engine is registered.

## G3 (re-checked): the manifest finding is partly wrong

Merged debug manifest (`build/app/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml`):
- `android.permission.RECORD_AUDIO` is declared (merged in from a plugin; the source manifest declares none).
- `INTERNET` is declared (from the debug manifest, as G4 says).
- `<queries>` holds only `PROCESS_TEXT`. There is **no** `RecognitionService` entry. This half of G3 holds.
- Not yet checked: the merged release manifest, and which plugin supplies `RECORD_AUDIO`.

## G2 (iOS): not reproduced

Source evidence only: `packages/zip_captions/ios/Podfile` `post_install` sets no `PERMISSION_MICROPHONE=1` macro. The iPhone 17 Simulator build and launch worked (`ios-01-home-launch.png`, MCP connected). Tapping Start Captioning on the Simulator was not possible with the tools available in this session: the MCP has no tap tool and the host has no Accessibility permission for `osascript`. A manual tap was agreed. Even when tapped, the debug build uses the fake engine (G10), so the iOS permission path is not reached either.

## Environment notes

- `Pixel_9_Pro_API_36` had 461 MB free on a 5.8 GB `/data` and rejected the debug APK (`Requested internal only, but not enough space`). With James Petersen's approval it was wiped (`-wipe-data`) and relaunched with `-partition-size 8192`. `dev.educoder.owntone_sync` was removed from that AVD by the wipe.
- The `flutter-agent-lens` MCP exposes `console_logs`, `screenshot` and the other tools only after an app is connected through `connection`.

## Not claimed

Physical iPhone and Android runs (latency under 1 s, screen kept on, recognizer availability) are a later gate in Unit 10 and are not covered by anything here.
