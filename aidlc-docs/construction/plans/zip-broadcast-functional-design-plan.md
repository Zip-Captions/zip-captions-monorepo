# Functional Design Plan — Unit 6: Zip Broadcast App

## Unit Summary

**Stories**: S-10 (Zip Broadcast App UI)

**Package**: `zip_broadcast`

**Prototypes**: Proto-06 (Home), Proto-07 (Recording), Proto-08 (Settings), Proto-09 (Audio Inputs)

---

## Plan Steps

- [ ] Phase A: New domain models
  - [ ] A1: `AudioInputConfig` — per-input composite (deviceId, speakerLabel, colorIndex)
  - [ ] A2: `AudioInputVisualStyle` — colorIndex → resolved Color pair (accent + label)
  - [ ] A3: `ObsConnectionStatus` — enum: `connecting`, `connected`, `disconnected`, `reconnecting`, `error`
  - [ ] A4: `BroadcastSessionState` — multi-engine aggregate (sessionId, perEngineStates, isRecording, isPaused)

- [ ] Phase B: New providers (zip_broadcast)
  - [ ] B1: `ObsConnectionNotifier` — live OBS WebSocket lifecycle: connect/disconnect, expose `ObsConnectionStatus`, trigger on `OutputTargetSettings.obsEnabled` change
  - [ ] B2: `BroadcastRecordingNotifier` — multi-engine recording state machine; replaces single-engine `RecordingStateNotifier` for Zip Broadcast; starts N `PlatformSttEngine` instances (one per `AudioInputConfig`), tags each `SttResult` with `sourceId` before publishing to `CaptionBus`
  - [ ] B3: `AudioLevelProvider` — per-source audio level (0.0–1.0); samples from platform audio service during recording; map keyed by `deviceId`
  - [ ] B4: `BrowserSourceUrlProvider` — derives `http://localhost:{port}/captions` from `OutputTargetSettingsNotifier.state.browserSourcePort`; exposes running status from `BrowserSourceTarget` lifecycle
  - [ ] B5: `AudioInputConfigNotifier` — wraps `AudioInputSettingsNotifier`, adds `colorIndex` and `speakerLabel` per device; persists to SharedPreferences; exposes `List<AudioInputConfig>`

- [ ] Phase C: App shell and navigation
  - [ ] C1: `ZbRouter` — GoRouter with a single `ShellRoute` wrapping all screens; `ZbAppShell(child: child)` is the shell builder; routes: `/` (HomeScreen), `/recording` (RecordingScreen), `/history` (placeholder for future), `/settings` (SettingsScreen), `/audio-inputs` (AudioSourceConfigScreen)
  - [ ] C2: `ZbAppShell` — platform-adaptive shell matching zip_captions pattern: width >768px renders a persistent `NavigationRail` on the left; width ≤768px renders a `Scaffold` with hamburger `AppBar` and `ZbNavDrawer`; shell receives `child` from GoRouter and renders it in `Expanded` beside the rail
  - [ ] C3: `ZbNavRail` — 3 primary rail destinations: Home (`/`), Recording (`/recording`), History (`/history`); Audio Inputs (`/audio-inputs`) accessible as a trailing icon button alongside Settings; Settings icon button navigates to `/settings` via `context.go('/settings')` — not a rail destination (mirrors BR-U5-03/BR-U5-06 from zip_captions)
  - [ ] C4: `ZipBroadcastApp` — replace `home: HomeScreen()` with `routerConfig: zbRouter`; use `MaterialApp.router`
  - [ ] C5: RecordingScreen stop flow — `RecordingScreen` is a GoRoute inside the `ShellRoute` (shell chrome persists); when `BroadcastRecordingNotifier` transitions to stopped, `ref.listen` triggers `context.go('/history')` (same pattern as BR-U5-01 in zip_captions); no modal push, no PopScope guard
  - [ ] C6: Settings drill-down — absolute-positioned `AnimatedSwitcher` within `SettingsScreen` (no Navigator push); back button sets `_SettingsView` enum to `list`; this is contained within the `/settings` GoRoute

- [ ] Phase D: HomeScreen (update)
  - [ ] D1: Start button — enabled when `BroadcastRecordingNotifier` is idle and ≥1 audio input configured; tapping calls `context.go('/recording')` only — `RecordingScreen` starts the session itself in `initState` (mirrors zip_captions HomeScreen pattern)
  - [ ] D2: Status pill — "Ready · N inputs · M targets active" derived from `AudioInputConfigNotifier` count and enabled-target count from `OutputTargetSettingsNotifier`
  - [ ] D3: Output target grid — 5 active target cards (On-Screen, OBS WebSocket, Browser Source, Caption Overlay, Transcripts) each wired to `OutputTargetSettingsNotifier.update()`; OBS card shows connection status sub-label from `ObsConnectionNotifier`; Browser Source card shows port sub-label; plus 1 coming-soon card (Remote Viewers — Phase 2) rendered per Q10
  - [ ] D4: Audio inputs summary — list of `AudioInputConfig` rows (color swatch, device name, speaker label); read-only on Home; taps navigate to AudioInputs screen via nav index

- [ ] Phase E: RecordingScreen (new)
  - [ ] E1: Widget type — `ConsumerStatefulWidget`; local field `bool _showAppearancePanel = false` (mirrors zip_captions BR-U5-09)
  - [ ] E2: `initState` start-on-navigate — `addPostFrameCallback` reads `BroadcastRecordingNotifier` state: `StoppedState` → `clearSession()` then `start()`; `IdleState` → `start()`; recording / paused / reconnecting → leave alone (mirrors zip_captions RecordingScreen initState pattern)
  - [ ] E3: Rail active item — `ZbAppShell` marks Recording as selected when `GoRouterState.matchedLocation == '/recording'`; standard `ZbNavRail` remains visible at desktop widths
  - [ ] E4: Top bar — session timer (elapsed from session start epoch); REC / PAUSED badge; appearance icon button in top bar that toggles `_showAppearancePanel` (Proto-07 places this in the bar rather than as a FAB — intentional divergence from zip_captions which uses `FloatingActionButton.small`)
  - [ ] E5: Status bar — three `StatusPill` widgets: OBS (color-coded dot from `ObsConnectionStatus`), Browser Source (dot-ok when server running), Overlay (dot from overlay toggle state); pills are tappable — OBS pill and overlay pill scroll the right panel to the relevant card
  - [ ] E6: Multi-source audio level row — one level track per `AudioInputConfig`; color matches config's `AudioInputVisualStyle`; driven by `AudioLevelProvider`; hidden when paused
  - [ ] E7: Caption area — `Stack` layout: bottom layer is a `GestureDetector` (tapping anywhere sets `_showAppearancePanel = false`, mirrors BR-U5-10) wrapping `CaptionDisplayWidget`; `AppearancePanel` shown as `Positioned` overlay when `_showAppearancePanel == true`; paused overlay chip (blurred backdrop, Resume button) shown as separate `Positioned` widget when `BroadcastSessionState.isPaused` — Zip Broadcast-specific addition not present in zip_captions
  - [ ] E8: `AppearancePanel` — chip-based selectors for text size, font, scroll direction writing to `DisplaySettingsNotifier`; no Apply button; changes take immediate effect (BR-U5-11); uses chips per Proto-07 rather than `DropdownButton` as in zip_captions
  - [ ] E9: Controls footer (`ZbRecordingControlsBar`) — state-driven rendering: `IdleState` → spinner only (engine initialising, no action buttons); `RecordingActiveState` → Pause + Stop; `PausedState` → Resume + Stop; `ReconnectingState` → spinner + Stop; mirrors zip_captions `RecordingControlsBar` state handling
  - [ ] E10: Stop auto-navigation — `ref.listen` on `BroadcastRecordingNotifier`; on `StoppedState`: call `ref.invalidate(transcriptSessionListProvider)` then `context.go('/history')` (mirrors zip_captions REL-U5.1 pattern exactly)
  - [ ] E11: Right panel (≥860 px) — three active sections: OBS card (status badge from `ObsConnectionNotifier`; host:port detail; "Reconnect" action), Browser Source card (URL text, copy-to-clipboard button), Caption Overlay section (toggle wired to `OutputTargetSettingsNotifier.overlayEnabled`; config sub-section with target display and position from `OverlayConfig`); plus a coming-soon Remote Viewers section rendered per Q10

- [ ] Phase F: SettingsScreen (new)
  - [ ] F1: List view — six category rows: Speech Recognition, Appearance, OBS WebSocket, Output Targets, Audio Inputs, Transcripts & Behaviour; each shows summary sub-label derived from current provider state
  - [ ] F2: Speech detail — STT Engine picker (read from `SttEngineRegistryProvider`, write to `activeEngineIdProvider`); Language picker (from `SpeechLocaleProvider`)
  - [ ] F3: Appearance detail — text size, font, scroll direction chip groups (write to `DisplaySettingsNotifier`); live preview box; Dark Theme toggle (write to `displaySettingsProvider`)
  - [ ] F4: OBS detail — enable toggle (`OutputTargetSettingsNotifier.obsEnabled`); host, port, password fields (`ObsSettingsNotifier.update()`); "Test Connection" button triggers `ObsConnectionNotifier.testConnection()` and shows snackbar result
  - [ ] F5: Output Targets detail — five active toggle rows matching Home screen cards (same provider wiring as D3); plus one coming-soon row (Remote Viewers — Phase 2) rendered per Q10; coming-soon row is not wired to any provider
  - [ ] F6: Audio Inputs detail — single row linking to AudioInputs screen; navigates via `context.go('/audio-inputs')`
  - [ ] F7: Transcripts & Behaviour detail — Save Transcripts toggle (`TranscriptSettingsProvider`); Keep Screen On toggle (`WakeLockSettingsProvider`); Release on Pause toggle (`WakeLockSettingsProvider.releaseOnPause`)

- [ ] Phase G: AudioSourceConfigScreen (new)
  - [ ] G1: Input card list — one card per `AudioInputConfig`; card header: color dot, position number, speaker label title, remove button; card body: source `DropdownButton` (devices from `AudioDeviceServiceProvider`), speaker label `TextField`, color swatch row
  - [ ] G2: Mutually exclusive source enforcement — when device selected in one card, disable that option in all other cards' dropdowns; derived synchronously from current `AudioInputConfigNotifier` state
  - [ ] G3: Add Input button (dashed card) — hidden when all available devices are assigned; calls `AudioInputConfigNotifier.addConfig()`; auto-assigns first free device and next unused color index
  - [ ] G4: Remove input — calls `AudioInputConfigNotifier.removeConfig(deviceId)`; animated card exit (opacity + slide); if removing leaves 0 inputs, show empty-state widget
  - [ ] G5: Color selection — 4 swatches (Blue, Green, Purple, Orange); tapping calls `AudioInputConfigNotifier.setColor(deviceId, colorIndex)`; selected swatch shows border ring

- [ ] Phase H: App-level orchestration (ZipBroadcastApp / AppShell)
  - [ ] H1: Multi-target registration — `ZbAppShell` watches `OutputTargetSettingsNotifier` via `ref.listen` and registers/deregisters enabled targets with `CaptionOutputTargetRegistry` on settings change; initial registration happens in the shell's first build
  - [ ] H2: OBS lifecycle — `ObsConnectionNotifier` watches `OutputTargetSettingsNotifier.obsEnabled`; connects when enabled + settings present; runs reconnect backoff (from Unit 3 design: exp backoff 1 s → 30 s, gives up after 10 min)
  - [ ] H3: Browser source server lifecycle — `BrowserSourceTarget` start/stop triggered by `OutputTargetSettingsNotifier.browserSourceEnabled` change; error surfaced as `SnackBar` via `BrowserSourceStartException`
  - [ ] H4: Caption overlay lifecycle — `CaptionOverlayTarget` open/close driven by `OutputTargetSettingsNotifier.overlayEnabled`; uses `DesktopWindowService` from Unit 3
  - [ ] H5: Wake lock coordination — `WakeLockService` acquisition/release delegated to `BroadcastRecordingNotifier` (same pattern as `RecordingStateNotifier`)

- [ ] Phase I: Business rules (BR-U6-01..N)
  - [ ] I1: Start is disabled unless `BroadcastRecordingNotifier` is idle AND `AudioInputConfigNotifier` has ≥1 device configured
  - [ ] I2: Source exclusivity — a physical audio device may appear in at most one `AudioInputConfig` at a time
  - [ ] I3: Stop auto-navigation — when `BroadcastRecordingNotifier` transitions to stopped, `RecordingScreen` navigates to `/history` via `ref.listen` + `context.go('/history')`; no PopScope guard (mirrors BR-U5-01)
  - [ ] I4: Screen-on constraint — screen must remain on during active captioning (wake lock required); applies to all output target combinations
  - [ ] I5: Coming-soon elements are permanently non-interactive — their toggles are disabled and do not respond to taps; tapping the card/row shows no action; the "Coming soon" label is the only feedback

- [ ] Phase J: Generate artifacts
  - [ ] J1: `domain-entities.md`
  - [ ] J2: `business-logic-model.md`
  - [ ] J3: `business-rules.md`

---

## Questions

**Q1 — Multi-engine recording: new notifier vs extending zip_core**

`RecordingStateNotifier` (zip_core) manages a single engine. Zip Broadcast needs N concurrent engines (one per audio input).

A) New `BroadcastRecordingNotifier` in `zip_broadcast` — completely replaces `RecordingStateNotifier` for this app; manages a `List<_EngineSession>` internally; publishes tagged `SttResultEvent` (with sourceId) to the shared `CaptionBus`; `ZipBroadcastApp` provides this notifier instead of the core one.

B) Extend `RecordingStateNotifier` to support multiple engine slots — add `List<SttEngine>` parameter; break single-engine assumption in `zip_core` (risks regressions in Zip Captions).

C) Keep single `RecordingStateNotifier` for the primary (first) engine; add a separate `SecondaryEngineNotifier` list in `zip_broadcast` for additional inputs — partial duplication, state sync complexity.

[Answer]: A

---

**Q2 — OBS connection state: provider architecture**

`ObsSettingsNotifier` stores config only. The live connection (WebSocket lifecycle, reconnect backoff) needs a separate provider.

A) New `ObsConnectionNotifier` (`keepAlive: true`) in `zip_broadcast` — owns the `ObsWebSocketTarget` instance; watches `OutputTargetSettingsNotifier.obsEnabled` and `ObsSettingsNotifier`; exposes `ObsConnectionStatus`; supports `testConnection()` for Settings screen.

B) `ObsWebSocketTarget` manages its own reconnect loop internally (already does via Unit 3 design); expose status via a `Stream<ObsConnectionStatus>` on the target; UI adapts via `StreamProvider`.

C) `OutputTargetSettingsNotifier` is extended to include live connection status fields alongside config fields — conflates persistence with runtime state.

[Answer]: A

---

**Q3 — App shell navigation strategy**

The prototypes show persistent sidebar with screens swapping in the main area.

A) Custom `AppShell` widget with `IndexedStack` — `_NavIndex` enum; `RecordingScreen` pushed as modal over the shell. No routing package needed but no deep-link support and state managed manually.

B) GoRouter with `ShellRoute` — `ZbAppShell(child: child)` as shell builder; all screens are named `GoRoute`s nested inside; `ZbNavRail` (desktop) and `ZbNavDrawer` (mobile) for chrome; matches the zip_captions architecture exactly (same pattern as `ZcAppShell` / `zcRouter`). `RecordingScreen` is a regular shell route at `/recording`, not a modal push.

C) `NavigatorState`-based page stack for all screens, no persistent shell — sidebar rebuilt per screen.

[Answer]: B

---

**Q4 — CaptionDisplayWidget for multi-source segments**

The shared `CaptionDisplayWidget` from `zip_core` renders a caption buffer. Multi-source needs per-source color bars and labels.

A) `CaptionDisplayWidget` is extended to accept an optional `styleResolver` callback `AudioInputVisualStyle? Function(String sourceId)` — widget calls it per segment; zip_core stays generic; zip_broadcast passes resolver from `AudioInputConfigNotifier`.

B) New `BroadcastCaptionDisplayWidget` in `zip_broadcast` subclasses or duplicates the widget and adds source-aware rendering — avoids touching zip_core but duplicates rendering logic.

C) Rendering is done purely at the widget layer in `RecordingScreen` — `CaptionDisplayWidget` is replaced by a custom `ListView.builder` that reads both the caption buffer and `AudioInputConfigNotifier` — no shared widget abstraction.

[Answer]: A

---

**Q5 — Audio level metering source**

The recording screen shows animated audio level bars per input source.

A) `AudioDeviceService` exposes a `Stream<Map<String, double>>` of RMS levels sampled at ~15 Hz per active device; `AudioLevelProvider` wraps this stream; values reset to 0.0 when paused.

B) Each `PlatformSttEngine` instance emits a level event alongside recognition results; `BroadcastRecordingNotifier` collects and re-emits as a map — couples STT engine to UI metric.

C) UI-only animation — level bars animate on a fixed CSS-like Dart `AnimationController`; no real audio level data is read. Visually active but not wired to actual input levels.

[Answer]: A

---

**Q6 — Settings screen navigation pattern**

Proto-08 shows a list → detail drill-down within a single screen (not Navigator push).

A) Absolute-positioned `AnimatedSwitcher` or `IndexedStack` within `SettingsScreen` — `_SettingsView` enum tracks active view (list, speech, appearance, obs, targets, audio, transcripts); back button sets enum to `list`; no navigation stack involved.

B) `Navigator` push within `SettingsScreen` using a nested `Navigator` widget — adds complexity for a flat 2-level hierarchy.

C) Each Settings detail is a separate named route pushed on the main `Navigator` — back button navigates back via `Navigator.pop`; simpler routing but loses the "slide within the settings area" prototype feel.

[Answer]: A

---

**Q7 — Recording navigation guard**

Navigating away from `RecordingScreen` (sidebar tap or back gesture) while recording is active.

A) `PopScope` (Flutter 3.22+) with `canPop: false` when recording/paused; `onPopInvokedWithResult` shows `AlertDialog` ("Stop captioning? Your session will end."); confirm calls `stop()` then pops.

B) `WillPopScope` (deprecated) — same logic but uses older API.

C) No guard — tapping the sidebar from `RecordingScreen` simply stops the session and navigates without confirmation.

[Answer]: A

---

**Q8 — Multi-target registration timing**

When should output targets be registered with `CaptionOutputTargetRegistry`?

A) Registration happens in `AppShell.initState`; a `ref.listen` on `OutputTargetSettingsNotifier` updates the registry when toggles change; `BroadcastRecordingNotifier.start()` asserts the registry is populated before starting engines.

B) `BroadcastRecordingNotifier.start()` reads `OutputTargetSettingsNotifier` and registers targets fresh on each session start; deregisters on stop — clean per-session lifecycle but forces re-init on every start.

C) `ZipBroadcastApp.build()` calls `WidgetsBinding.instance.addPostFrameCallback` to register targets once on first frame; no dynamic updates while running.

[Answer]: B

---

**Q10 — Visual treatment for Phase 2 coming-soon features**

Remote Viewers (WebRTC) is a Phase 2 feature. It should be visible in the UI but clearly unavailable — appearing in the Home target grid, the Settings > Output Targets list, and the Recording right panel.

A) Disabled card/row with a "Coming soon" chip badge — the card is rendered with reduced opacity; the toggle is absent or replaced by the badge; tapping the card produces no action. Communicates product direction without implying the feature is broken.

B) Hidden entirely until Phase 2 is implemented — no mention of remote viewers in the Phase 1 UI; feature appears only when shipping.

C) Enabled-looking card that shows a "Not yet available" bottom sheet on tap — looks active at first glance, which could confuse users into thinking it should be working.

[Answer]: A

---

**Q9 — AudioInputConfig persistence**

`AudioInputSettingsNotifier` (shell from Unit 5) stores `List<AudioDevice>`. Unit 6 adds `speakerLabel` and `colorIndex` per device.

A) New `AudioInputConfigNotifier` in `zip_broadcast` replaces `AudioInputSettingsNotifier`; stores `List<AudioInputConfig>` (deviceId + name + speakerLabel + colorIndex) as JSON in SharedPreferences under key `zip_broadcast.audioInputConfigs`; the Unit 5 shell provider is removed.

B) `AudioInputSettingsNotifier` is extended to also store `speakerLabel` and `colorIndex` — modifies an existing provider; risks breaking Unit 5 shell assumptions.

C) `AudioInputConfigNotifier` composes `AudioInputSettingsNotifier`; fetches devices from it and stores only the extra fields (speakerLabel, colorIndex) separately — two separate keys in SharedPreferences, merged in the notifier.

[Answer]: A
