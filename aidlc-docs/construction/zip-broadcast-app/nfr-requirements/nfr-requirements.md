# NFR Requirements — Unit 6: Zip Broadcast App

**Unit**: Unit 6: Zip Broadcast App (S-10)
**Stage**: NFR Requirements
**Status**: COMPLETE

---

## FD Updates Required

Three FD decisions are revised by the NFR assessment below and must be reflected in
implementation:

| Rule / Component | Original FD | Revised |
|---|---|---|
| B2 `BroadcastRecordingNotifier` start | No failure isolation specified for multi-engine init | **Superseded by REL-U6.1** — if engine K fails to initialize, remaining K-1 engines continue; failed input is flagged; recording proceeds with reduced inputs (NFR-DQ1=B) |
| F4 OBS password `TextField` | No obscureText constraint | **Add**: `obscureText: true` on the password field; password must never appear in logs (SEC-U6.2) |
| D3 / E11 / F5 coming-soon elements | Inline rendering at each call site | **Add**: `ComingSoonCard` extracted as a reusable widget within `zip_broadcast`; all three sites use it (MAINT-U6.1, NFR-DQ3=A) |

---

## Design Questions

| # | Question | Options | Answer |
|---|----------|---------|--------|
| NFR-DQ1 | Multi-engine partial failure behaviour | A = abort all engines if any single init fails; B = continue with remaining engines, mark failed input with error state | **B** |
| NFR-DQ2 | OBS test-connection timeout | A = 5 s hard timeout; B = 10 s; C = user-configurable | **A** |
| NFR-DQ3 | `ComingSoonCard` widget scope | A = `zip_broadcast` only (never shared across apps); B = `zip_core` (anticipating Phase 2 reuse) | **A** |

---

## 1. Performance

### PERF-U6.1: Audio Level Metering — 15 Hz Sampling, Pause Reset

`AudioDeviceService` must emit audio level values at no more than 15 Hz per device (one
sample per ~67 ms). The `AudioLevelProvider` must reset all values to `0.0` when
`BroadcastRecordingNotifier` transitions to `PausedState`, and resume live values when
it transitions back to `RecordingActiveState`.

**Rationale**: Faster sampling (e.g., 60 Hz) provides no perceptible UX benefit for a
level bar visualization, while increasing widget rebuild rate four-fold for every active
input. 15 Hz matches the flutter_sound / record package's practical minimum polling
interval and aligns with what the eye can track for a smoothly animated bar.

**Implementation**: `AudioDeviceService.levelStream` throttles using a fixed-interval
`Timer.periodic` (67 ms). `AudioLevelProvider` is a `StreamProvider.autoDispose` wrapping
this stream; it emits `Map<String, double>` keyed by `deviceId`. The RecordingScreen
`AudioLevelRow` widget rebuilds only when the map changes — widgets for inactive devices
hold `0.0`.

**Verification**: Integration test — mock `AudioDeviceService` emitting at 100 Hz; assert
`AudioLevelProvider` only notifies listeners at ≤15 Hz over a 1-second window.

---

### PERF-U6.2: CaptionDisplayWidget — Post-Frame Callback Auto-Scroll

The multi-source `CaptionDisplayWidget` (extended per Q4) must follow the same post-frame
callback auto-scroll constraint as zip_captions (PERF-U5.3). Any call to
`scrollController.animateTo()` or `scrollController.jumpTo()` triggered by a new caption
event must be scheduled via `WidgetsBinding.instance.addPostFrameCallback`.

**Verification**: Inherited from PERF-U5.3; no new test required. The constraint applies
identically to the `styleResolver` extension path — the scroll trigger is unaffected by
source-aware rendering.

---

### PERF-U6.3: AudioSourceConfigScreen — Device Dropdown Lazy Population

The device `DropdownButton` in each `AudioInputConfig` card must build its items lazily.
`AudioDeviceServiceProvider` is read once when the screen enters view; the item list is
not reconstructed on every card rebuild. If the device count is large (>20 devices), the
dropdown uses `DropdownMenuItem` with keys to avoid redundant equality checks.

**No test required** — this is a structural constraint enforced by code review.

---

## 2. Security

### SEC-U6.1: No Transcript or Caption Text in Broadcast Layer Logs (SECURITY-03 Extension)

Extends the SECURITY-03 constraint to all Unit 6 components. No widget, screen, notifier,
or provider in `zip_broadcast` may include the following in log output, debug assertions,
or exception messages:

- `SttResult.text` or any derived caption text
- `TranscriptSegment.text` or `TranscriptSession.title`
- Audio device names that could serve as user identifiers
- Speaker labels entered in `AudioSourceConfigScreen`

**Permitted in logs**: `sessionId`, engine IDs, device IDs (not names), `ObsConnectionStatus`
values, widget lifecycle events (e.g., `RecordingScreen.initState`), error types.

**Verification**: Code review of all `debugPrint`, `log()`, and `Logger` call sites in
Unit 6 files. Mandatory review item in Code Generation — cannot be automated.

---

### SEC-U6.2: OBS Password Field — `obscureText: true` (FD Update)

The OBS password `TextField` in the Settings > OBS WebSocket detail view must use
`obscureText: true`. The password value must never appear in any log call, including
connection error messages.

**Implementation**: `F4` OBS detail `TextField` for password gets `obscureText: true` and
an accompanying visibility-toggle `IconButton` (standard eye icon). Connection error
logging must reference only `ObsConnectionStatus` values and error types — never the
password string.

**Verification**: Widget test — render the OBS Settings detail panel; assert the password
field widget has `obscureText == true`.

---

## 3. Reliability

### REL-U6.1: Multi-Engine Partial Failure Isolation (NFR-DQ1=B, FD Update)

`BroadcastRecordingNotifier.start()` must tolerate individual engine initialization
failures without aborting the entire session.

**Behaviour**:
- For each `AudioInputConfig`, `BroadcastRecordingNotifier` attempts
  `PlatformSttEngine.initialize()` and `startListening()` independently.
- If engine K fails to initialize or start, the remaining K-1 engines continue to start
  unaffected.
- `BroadcastSessionState` carries a `perEngineStates` map; the failed engine's entry is
  set to an `engineError` state.
- The Recording screen's audio level row for the failed input shows a red/error indicator
  rather than a level bar.
- If **all** engines fail, the entire session is aborted (transition back to `IdleState`
  with `RecordingError.engineInitFailed`).

**Rationale**: A single misconfigured or disconnected device should not block all other
inputs. The user may have physically unplugged one mic; the remaining inputs are valid.

**Verification**: Unit test — provide a `BroadcastRecordingNotifier` with two mock engines
where engine 1 throws on `initialize()` and engine 2 succeeds; assert `isRecording == true`
with `perEngineStates[engine1] == engineError` and `perEngineStates[engine2] == active`.

---

### REL-U6.2: Browser Source Port Conflict — SnackBar Error, No Crash

If the browser source server fails to bind to the configured port (port already in use or
permission denied), `BrowserSourceTarget.start()` must throw a `BrowserSourceStartException`
that `ZbAppShell` catches and displays as a `SnackBar`. The app must remain in a usable
state — captioning continues with other targets active.

**Implementation**: `H3` in the FD specifies this flow. The SnackBar message includes the
port number and a hint to change it in Settings. The browser source toggle in `OutputTargetSettingsNotifier`
is set back to `false` after the error so the Home screen reflects the actual state.

**Verification**: Widget test — mock `BrowserSourceTarget.start()` to throw
`BrowserSourceStartException`; assert a SnackBar is shown and
`OutputTargetSettingsNotifier.browserSourceEnabled` is reset to `false`.

---

### REL-U6.3: OBS Connection Status Latency and Test-Connection Timeout (NFR-DQ2=A)

**Status update latency**: The `ObsConnectionStatus` value exposed by `ObsConnectionNotifier`
must update within ≤1 s of the underlying WebSocket state change (connected, disconnected,
error). This matches the reconnect backoff design from Unit 3 (first retry at 1 s).

**Test-connection timeout**: The "Test Connection" button in Settings > OBS WebSocket must
apply a 5-second hard timeout. If no acknowledgement is received within 5 s, the snackbar
shows "Connection timed out." `ObsConnectionNotifier.testConnection()` uses
`Future.any([connect(), Future.delayed(Duration(seconds: 5))])` or equivalent.

**Verification**:
- Unit test for status latency: mock WebSocket disconnect event; assert
  `ObsConnectionNotifier.state` transitions to `disconnected` within 1 s.
- Unit test for timeout: mock OBS that never responds; assert `testConnection()` resolves
  with a timeout error within 5 s (use fake timers).

---

### REL-U6.4: Session List Invalidation on Stop (mirrors REL-U5.1)

`RecordingScreen`'s `ref.listen` handler for `BroadcastRecordingNotifier` must call
`ref.invalidate(transcriptSessionListProvider)` **before** `context.go('/history')` on
`StoppedState`. This is identical to the zip_captions REL-U5.1 requirement and is carried
forward here as a first-class reliability constraint for Unit 6.

**Verification**: Widget test — stub `BroadcastRecordingNotifier` to emit `StoppedState`;
assert `transcriptSessionListProvider` is invalidated and navigation occurs to `/history`.

---

### REL-U6.5: Navigation Guard — `PopScope` AlertDialog When Recording Active

`RecordingScreen` must wrap its body in a `PopScope` with `canPop: false` while
`BroadcastSessionState.isRecording == true` or `isPaused == true`. Any back gesture or
sidebar tap during an active session must show an `AlertDialog` ("Stop captioning? Your
session will end.") with Cancel and Stop actions.

- **Cancel**: dismisses the dialog; session continues.
- **Stop**: calls `broadcastRecordingNotifier.stop()`, awaits completion, then
  `context.go('/history')`. The `ref.listen` flow (REL-U6.4) handles invalidation.

**Rationale**: Zip Broadcast users may have OBS and browser source active. An accidental
navigation tap would silently terminate all output targets, which is a higher-consequence
mistake than in zip_captions.

**Note**: Q7 in the FD selected option A (`PopScope`). This NFR formalises the dialog
wording and the stop-then-navigate flow.

**Verification**: Widget test — render RecordingScreen with active session; simulate
Android back gesture; assert `AlertDialog` appears; tap Stop; assert session stopped and
navigation to `/history`.

**Future phase**: A caption pop-out window (Phase 2) is the planned mitigation for this UX friction. When the pop-out is active, this guard must be relaxed to allow free navigation without a confirmation dialog. See Phase 1 unit-of-work — "Phase 2 — Known Deferred Features."

---

## 4. Accessibility

### ACC-U6.1: StatusPill — Screen Reader Semantic Labels

Each `StatusPill` on the Recording screen must wrap its content in a `Semantics` widget
providing a `label` that fully describes the status without relying on color alone.

| Pill | Label examples |
|------|---------------|
| OBS | `"OBS: connected"`, `"OBS: disconnected"`, `"OBS: reconnecting"`, `"OBS: error"` |
| Browser Source | `"Browser Source: running"`, `"Browser Source: stopped"` |
| Caption Overlay | `"Caption Overlay: active"`, `"Caption Overlay: inactive"` |

Color dots are decorative; they must set `Semantics(excludeSemantics: true)` on the
colored `Container` and let the parent `Semantics` label carry all meaning.

**Verification**: Widget test — render each StatusPill variant; assert `SemanticsNode` text
matches the expected label string.

---

### ACC-U6.2: Coming-Soon Elements — Announced as Unavailable

`ComingSoonCard` and any coming-soon row in Settings must carry a `Semantics` label that
announces the item as unavailable. The label must combine the feature name with "not yet
available" so screen reader users understand they cannot interact with it.

Example label: `"Remote Viewers — not yet available"`.

`Semantics(button: false, enabled: false, label: ...)` prevents screen readers from
implying the element is tappable.

**Verification**: Widget test — render `ComingSoonCard` with label "Remote Viewers"; assert
`SemanticsNode` has `enabled == false` and label contains "not yet available".

---

### ACC-U6.3: Audio Level Bars — Decorative Exclusion

Audio level bar widgets (`AudioLevelRow`) are decorative animations that convey no
information a screen reader user requires beyond what `StatusPill` already announces.
Each bar must be wrapped in `Semantics(excludeSemantics: true)` to prevent TalkBack /
VoiceOver from announcing raw numeric values.

**Verification**: Code review only — not automatable by widget test.

---

## 5. Testing

### TEST-U6.1: Screen Widget Tests with ProviderScope Overrides

Each of the 4 screens is covered by at least one widget test. Tests use
`ProviderScope(overrides: [...])` to replace relevant providers with stubs.

**Coverage targets**:

| Screen | Tests |
|--------|-------|
| HomeScreen | Idle state (Start enabled ≥1 input, disabled 0 inputs), output target card renders, OBS status sub-label |
| RecordingScreen | Controls per `BroadcastSessionState`; AppearancePanel toggle; PopScope dialog on back; auto-nav on `StoppedState`; StatusPill labels |
| SettingsScreen | All 6 category rows render; OBS password field `obscureText`; coming-soon row disabled |
| AudioSourceConfigScreen | Card renders per config; add-input button hidden when all devices assigned; color selection border ring; remove animation |

---

### TEST-U6.2: `BroadcastRecordingNotifier` — Unit Tests

Tests target the notifier using `ProviderContainer` with mock engines.

| Test | Assertion |
|------|-----------|
| All engines initialize → `isRecording == true` | `BroadcastSessionState.isRecording` |
| One engine fails init → remaining continue | `perEngineStates[bad] == engineError`, `isRecording == true` |
| All engines fail → `IdleState` + `RecordingError` | Session aborted; `lastError` set |
| Stop → all engines receive `stopListening()` | Mock engine `stopListening` called for each |
| Pause → all engines pause | All mock engines `pause()` called |
| Resume → all engines resume | All mock engines `resume()` called |
| `SttResult` tagged with `sourceId` before bus publish | `CaptionBus` receives `SttResultEvent` with matching `sourceId` |

---

### TEST-U6.3: `ObsConnectionNotifier` — Unit Tests

| Test | Assertion |
|------|-----------|
| Enable OBS → connect called | `ObsWebSocketTarget.connect()` invoked |
| WebSocket disconnect → status `disconnected` | `ObsConnectionNotifier.state == disconnected` |
| `testConnection()` success → returns `connected` | Result status `connected` |
| `testConnection()` timeout (5 s fake timer) → returns `error` | Result status `error` within 5 s |
| Disable OBS while connected → disconnect called | `ObsWebSocketTarget.disconnect()` invoked |

---

### TEST-U6.4: `AudioInputConfigNotifier` — Unit Tests

| Test | Assertion |
|------|-----------|
| Add first config → config list length 1 | `state.length == 1` |
| Add second config → auto-assigns next unused color | `state[1].colorIndex != state[0].colorIndex` |
| Remove config → list shrinks | `state.length` decreases |
| Set color → config updated | `state.firstWhere(id).colorIndex == newIndex` |
| Source exclusivity — device assigned to config A is not offered in config B's dropdown | Dropdown items for B exclude device already in A |
| Persist → SharedPreferences key written | SharedPreferences mock receives write call |

---

### TEST-U6.5: Navigation Tests

Navigation tested via `MaterialApp.router` with real `GoRouter` instance and
`ProviderScope` overrides.

| Test | Assertion |
|------|-----------|
| HomeScreen Start button → `/recording` | Route changes to `/recording` |
| RecordingScreen `StoppedState` → `/history` | Route changes to `/history` |
| Settings icon tap → `/settings` | Route changes to `/settings` |
| Audio Inputs trailing button → `/audio-inputs` | Route changes to `/audio-inputs` |
| Recording PopScope back → AlertDialog shown | Dialog renders; Cancel leaves route unchanged |
| PopScope Stop action → `/history` | Route changes to `/history` after stop |

---

## 6. Maintainability

### MAINT-U6.1: `ComingSoonCard` — Reusable Widget in `zip_broadcast` (NFR-DQ3=A, FD Update)

The coming-soon visual treatment (disabled card, reduced opacity, "Coming soon" chip badge,
ACC-U6.2 semantics) must be extracted into a `ComingSoonCard` widget in
`packages/zip_broadcast/lib/src/widgets/coming_soon_card.dart`. All three FD call sites
(D3 Home target grid, E11 Recording right panel, F5 Settings Output Targets list) must use
this widget. Inline repetition is not permitted.

**Scope**: `zip_broadcast` only (NFR-DQ3=A). `zip_core` is not modified; Phase 2 reuse,
if needed, can migrate the widget at that time without breaking the current contract.

---

### MAINT-U6.2: Logger Naming Convention

All `Logger` instances in `zip_broadcast` Unit 6 files must follow the
`'zip_broadcast.{ClassName}'` naming convention (e.g., `Logger('zip_broadcast.BroadcastRecordingNotifier')`).
This matches the `zip_core` convention (`'zip_core.{ClassName}'`) and ensures log filtering
by package prefix works consistently.

**Verification**: Code review — grep for `Logger(` in `zip_broadcast` sources; assert all
names start with `'zip_broadcast.'`.

---

### MAINT-U6.3: `go_router` Version Alignment

`zip_broadcast/pubspec.yaml` must pin `go_router` to `^14.0.0`, matching `zip_captions`.
Misaligned major versions would produce two incompatible `GoRouter` types in the dependency
graph.

---

### MAINT-U6.4: `BroadcastRecordingNotifier` Scope Isolation

`BroadcastRecordingNotifier` must not import from `zip_captions`. It may import:
- `zip_core` (engine interfaces, CaptionBus, models)
- `zip_broadcast` providers (AudioInputConfigNotifier, OutputTargetSettingsNotifier)

If code-sharing with `RecordingStateNotifier` is desired in a future unit, extract to
`zip_core` at that time. For now, duplication of the state machine skeleton is acceptable
given the multi-engine divergence.

---

## Tech Stack Decisions

| Package | Version | Location | Purpose |
|---------|---------|----------|---------|
| `go_router` | `^14.0.0` | `zip_broadcast` | ShellRoute routing (matches zip_captions) |
| `shared_preferences` | existing | `zip_broadcast` | `AudioInputConfigNotifier` JSON persistence |

No new packages are required for Unit 6. All other dependencies (`web_socket_channel`,
`shelf`, etc.) are already pulled in by Unit 3 output targets.

---

## Extension Compliance Summary

| Rule | Status | Notes |
|------|--------|-------|
| SECURITY-03 (no transcript text in logs) | **Compliant** | SEC-U6.1 enforces for all Unit 6 components; SEC-U6.2 extends to OBS password |
| PERF-U5.3 (post-frame callback auto-scroll) | **Inherited** | CaptionDisplayWidget scroll constraint unchanged by styleResolver extension |
| REL-U5.1 (session list invalidation) | **Carried forward** | REL-U6.4 formalises identical requirement for Zip Broadcast |
| REL-U2.1 (auto-restart) | **Inherited** | `BroadcastRecordingNotifier` must implement equivalent one-attempt restart per engine |
| BR-U5-03 / BR-U5-06 (Settings not a rail destination) | **Inherited** | ZbNavRail follows same constraint; Settings accessible via trailing icon button only |
