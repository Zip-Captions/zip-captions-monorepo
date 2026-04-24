# Code Summary — Unit 6: Zip Broadcast App

## Stories Implemented

- **S-10**: Zip Broadcast App UI — multi-engine recording, OBS WebSocket output, browser source output, audio input configuration, platform-adaptive shell with GoRouter, RecordingScreen, SettingsScreen, and AudioSourceConfigScreen.

## Verification Results

| Check | Result |
|-------|--------|
| `build_runner build` | No new outputs (all .g.dart files committed from prior stages) |
| `dart analyze` (zip_broadcast) | 0 errors, 0 warnings |
| `flutter test packages/zip_broadcast` | 80 tests passed, 0 failures |

## Files Created

### Models (`packages/zip_broadcast/lib/src/models/`)

| File | Type | Purpose |
|------|------|---------|
| `audio_input_config.dart` | freezed | Per-input composite: deviceId, name, speakerLabel, colorIndex |
| `audio_input_visual_style.dart` | plain Dart | colorIndex → resolved Color pair (accent + label); 4 named styles |
| `broadcast_session_state.dart` | sealed/freezed | Multi-engine aggregate: Idle, Active, Paused, Stopped, Reconnecting; `perEngineStates` map |
| `obs_connection_status.dart` | enum | connecting, connected, disconnected, reconnecting, error |

### Providers (`packages/zip_broadcast/lib/src/providers/`)

| File | Type | Purpose |
|------|------|---------|
| `broadcast_recording_notifier.dart` | keepAlive notifier | Multi-engine state machine; start/pause/resume/stop/clearSession; partial-failure tolerance (REL-U6.1) |
| `obs_connection_notifier.dart` | keepAlive notifier | Live OBS WebSocket lifecycle; `ref.listen` on obsEnabled (FD H2); exposes `ObsConnectionStatus` |
| `obs_web_socket_target.dart` | keepAlive provider + impl | `_ObsWebSocketTargetImpl`: connect/disconnect, exp backoff 1s→30s, 10-min give-up; re-created on settings change via `ref.watch` |
| `audio_input_config_notifier.dart` | keepAlive notifier | `List<AudioInputConfig>` with SharedPreferences JSON persistence; async deferred load pattern |
| `audio_level_provider.dart` | auto-dispose provider | Per-source RMS level map `Map<String, double>`; placeholder returns empty map; overridden in tests |
| `browser_source_url_provider.dart` | auto-dispose provider | Derives `http://localhost:{port}/captions` from OutputTargetSettingsNotifier |
| `stt_engine_factory_provider.dart` | auto-dispose provider | Per-deviceId factory: creates `PlatformSttEngine` instance keyed by deviceId |
| `settings_notifier.dart` | keepAlive notifier | `DisplaySettingsNotifier` with keyPrefix `zip_broadcast`; `displaySettingsProvider` hand-written (not @riverpod) |

### Screens (`packages/zip_broadcast/lib/src/screens/`)

| File | Purpose |
|------|---------|
| `home_screen.dart` | Start button (enabled when idle + ≥1 input), status pill, output target grid with OBS status sub-label, audio inputs summary |
| `recording_screen.dart` | `ConsumerStatefulWidget`; start-on-navigate in `initState`; session timer, REC/PAUSED badge, multi-source audio level row, appearance panel overlay, paused overlay chip, `ZbRecordingControlsBar`, stop auto-navigation to `/history` |
| `settings_screen.dart` | `_SettingsView` enum drill-down; 6 categories: Speech, Appearance, OBS, Output Targets, Audio Inputs, Transcripts; AnimatedSwitcher within single route |
| `audio_source_config_screen.dart` | Per-config card list; device dropdown (mutually exclusive enforcement); speaker label field; color swatch row; add/remove with animation |

### Shell & Navigation (`packages/zip_broadcast/lib/src/shell/`, `routing/`)

| File | Purpose |
|------|---------|
| `zb_router.dart` | GoRouter with single `ShellRoute`; routes: `/`, `/recording`, `/history`, `/settings`, `/audio-inputs` |
| `zb_app_shell.dart` | Platform-adaptive: `ZbNavRail` (>768 px) or hamburger + `ZbNavDrawer` (≤768 px); watches `OutputTargetSettingsNotifier` via `ref.listen` for target registration (FD H1) |
| `zb_nav_rail.dart` | 3 primary destinations + Settings icon button; mirrors zip_captions `ZcNavRail` pattern |
| `zb_nav_drawer.dart` | Mobile drawer with same destinations |

### Widgets (`packages/zip_broadcast/lib/src/widgets/`)

| File | Purpose |
|------|---------|
| `status_pill.dart` | Colour-coded dot + label; used for OBS, Browser Source, Overlay status (bug fix: removed duplicate `attributedLabel` from `Semantics`) |
| `coming_soon_card.dart` | Disabled card with "Coming soon" chip; used for Remote Viewers Phase 2 slot (BR-U6-I5) |
| `zb_recording_controls_bar.dart` | State-driven footer: spinner (initialising) / Pause+Stop (active) / Resume+Stop (paused) / spinner+Stop (reconnecting) |
| `audio_level_row.dart` | Animated RMS level bars; one track per `AudioInputConfig`; color from `AudioInputVisualStyle`; hidden when paused |
| `appearance_panel.dart` | Chip selectors for text size, font, scroll direction; writes to `DisplaySettingsNotifier`; immediate effect |

### App Entry (`packages/zip_broadcast/lib/src/`)

| File | Change |
|------|--------|
| `app.dart` | Replaced `home: HomeScreen()` with `routerConfig: zbRouter`; `MaterialApp.router` |

### Test Helpers (`packages/zip_broadcast/test/helpers/`)

| File | Purpose |
|------|---------|
| `fake_services.dart` | `FakeWakeLockService` — no-op implementation of `WakeLockService` for provider unit tests |
| `fake_notifiers.dart` | `FakePausedBroadcastRecordingNotifier`, `FakeConnectedObsConnectionNotifier`, `FakeTwoInputAudioInputConfigNotifier` (+ existing fakes from earlier stages) |
| `zb_test_harness.dart` | `buildZbApp(prefs:, overrides:)` — adds `prefs` param for `sharedPreferencesProvider`, `InkRipple.splashFactory` to suppress shader failures |
| `pbt.dart` | Property generators for `AudioInputConfig`, `BroadcastSessionState` |

### Test Files (`packages/zip_broadcast/test/`)

| File | Type | Tests |
|------|------|-------|
| `providers/broadcast_recording_notifier_test.dart` | unit + PBT | 9: state machine transitions, partial failure, all-engines-fail, PBT invariants P1–P3 |
| `providers/obs_connection_notifier_test.dart` | unit | 5: connect on enable, disconnect on disable, status updates, fireImmediately, timeout |
| `providers/audio_input_config_notifier_test.dart` | unit + PBT | 6: add/remove/update, JSON round-trip PBT P4 |
| `screens/home_screen_test.dart` | widget | 6: start button enabled/disabled, status pill, target grid, audio summary |
| `screens/recording_screen_test.dart` | widget | 6: start-on-navigate, controls bar states, stop auto-navigation |
| `screens/settings_screen_test.dart` | widget | 6: category list, drill-down, back navigation |
| `screens/audio_source_config_screen_test.dart` | widget | 6: card list, add/remove, device exclusivity |
| `widgets/coming_soon_card_test.dart` | widget | 4: renders badge, toggle absent, tap no-op, accessibility |

## Files Modified

| File | Change |
|------|--------|
| `lib/src/app.dart` | GoRouter wiring; `MaterialApp.router` |
| `lib/src/providers/broadcast_providers.g.dart` | Regenerated for new providers |
| `lib/src/output/browser_source/browser_source_target.dart` | Minor interface alignment |
| `lib/src/widgets/status_pill.dart` | Bug fix: removed duplicate `attributedLabel` from `Semantics` (Flutter assertion violation) |
| `pubspec.yaml` | Added `obs_websocket`, `clock`, `uuid` dependencies |
| `test/helpers/fake_notifiers.dart` | Added 4 new fake notifier classes |
| `test/helpers/zb_test_harness.dart` | `prefs` param, `InkRipple.splashFactory`, merged overrides list |

## Dependencies Added

| Package | Version | Scope | Purpose |
|---------|---------|-------|---------|
| `obs_websocket` | ^4.0.0 | runtime | OBS WebSocket v5 protocol client |
| `clock` | ^1.1.1 | runtime | Mockable `Clock` for backoff timeout tests |
| `uuid` | ^4.5.1 | runtime | Session ID generation (also used in zip_core) |

## Architecture Notes

- **Multi-engine fan-out**: `BroadcastRecordingNotifier.start()` uses `Future.wait()` to initialise engines in parallel. Partial failure is tolerated — recording continues with any engines that succeeded; only falls back to `BroadcastIdleState(lastError:)` if all fail (REL-U6.1, P1–P3).
- **`ref.listen` in `build()` for connection management**: `ObsConnectionNotifier` uses `ref.listen(…, fireImmediately: true)` on `obsEnabled` inside `build()` to connect/disconnect the WebSocket target reactively. This is the correct Riverpod pattern for stateful notifiers — not the reactive-side-effect anti-pattern. See `RIVERPOD_CONVENTIONS.md`.
- **Async deferred load with future fence**: `AudioInputConfigNotifier` returns a synchronous default from `build()` and fires `_loadFuture = _loadAsync()` immediately. All mutating methods await `_loadFuture` before proceeding, preventing races between startup load and immediate mutations. See `RIVERPOD_CONVENTIONS.md`.
- **`obsWebSocketTargetProvider` re-creation on settings change**: A keepAlive functional provider that `ref.watch`es `ObsSettingsNotifier` and returns a new `_ObsWebSocketTargetImpl` on each change; `ref.onDispose(impl.dispose)` handles cleanup. This keeps connection lifecycle bound to settings without manual tear-down in the notifier.
- **Source exclusivity**: Device exclusivity in `AudioSourceConfigScreen` is enforced at the widget layer by deriving a `usedDeviceIds` set from `AudioInputConfigNotifier` state and disabling those options in all other dropdowns (BR-U6-I2).
- **Coming-soon pattern**: `ComingSoonCard` renders with reduced opacity and a "Coming soon" chip; the toggle is absent; `IgnorePointer` wraps the card content to ensure no action on tap (BR-U6-I5, Q10=A).
- **Security (SECURITY-03)**: No caption text in logs — only session IDs, device IDs, error types, and state transitions.
