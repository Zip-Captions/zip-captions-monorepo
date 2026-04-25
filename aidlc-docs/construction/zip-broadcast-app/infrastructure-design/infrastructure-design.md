# Infrastructure Design — Unit 6: Zip Broadcast App

**Unit**: Unit 6: Zip Broadcast App (S-10)
**Stage**: Infrastructure Design
**Status**: COMPLETE

---

## Overview

Unit 6 introduces three categories of infrastructure not present in earlier units:

1. **Overlay window sub-process** — `CaptionOverlayTarget` opens a second Flutter window in a separate process using `desktop_multi_window`; the main app communicates with it via platform channels.
2. **App shell orchestration** — `ZbAppShell` owns all output target instances and wires them into `CaptionOutputTargetRegistry` in response to `OutputTargetSettingsNotifier` toggle changes.
3. **Persistent provider graph** — six `keepAlive` providers form the broadcast runtime; their dependency order determines shutdown safety.

macOS is the primary target platform. Windows and Linux support is governed by the same `DesktopWindowService` abstraction; no platform-specific code outside that abstraction is needed.

---

## Tech Stack

| Package | Version | Location | Purpose |
|---------|---------|----------|---------|
| `desktop_multi_window` | `^0.7.0` | `zip_broadcast` | Spawns child Flutter window process; bidirectional platform-channel IPC |
| `go_router` | `^14.0.0` | `zip_broadcast` | `ShellRoute` + named routes; version-pinned to match `zip_captions` (MAINT-U6.3) |
| `shared_preferences` | existing | `zip_broadcast` | `AudioInputConfigNotifier` JSON persistence; `OutputTargetSettingsNotifier` toggle persistence |
| `flutter_secure_storage` | existing | `zip_broadcast` | OBS password storage (SEC-U6.2) |
| `riverpod_annotation` | existing | `zip_broadcast` | `keepAlive` provider graph (matches `zip_core` / `zip_captions` pattern) |

---

## Provider Graph

The broadcast runtime is entirely `keepAlive` — providers persist for the app lifetime and are never auto-disposed. `autoDispose` is reserved for `AudioLevelProvider` and `BrowserSourceUrlProvider`, which are safe to drop between recording sessions.

```
captionBusProvider (keepAlive, zip_core)
  └─► captionOutputTargetRegistryProvider (keepAlive, zip_core)
        │   [targets added/removed at runtime by ZbAppShell]
        ├── OnScreenCaptionTarget
        ├── ObsWebSocketTarget ──────────────── obsSettingsNotifierProvider (keepAlive)
        ├── BrowserSourceTarget
        ├── CaptionOverlayTarget
        └── TranscriptWriterTarget

outputTargetSettingsNotifierProvider (keepAlive) ── SharedPreferences
obsSettingsNotifierProvider (keepAlive) ─────────── SharedPreferences + FlutterSecureStorage

broadcastRecordingNotifierProvider (keepAlive)
  ├── reads: audioInputConfigNotifierProvider
  ├── reads: captionBusProvider
  └── reads: sttEngineFactoryProvider (zip_core)

obsConnectionNotifierProvider (keepAlive)
  ├── reads: obsSettingsNotifierProvider
  └── reads: outputTargetSettingsNotifierProvider

audioInputConfigNotifierProvider (keepAlive) ────── SharedPreferences

audioLevelProvider (autoDispose) ─────────────────── AudioDeviceService.levelStream
browserSourceUrlProvider (autoDispose)
  └── reads: outputTargetSettingsNotifierProvider
```

**Disposal order** (app shutdown, ZbAppShell.dispose):

1. `broadcastRecordingNotifierProvider` — stops all engines and session
2. `obsConnectionNotifierProvider` — disconnects WebSocket
3. `captionOutputTargetRegistryProvider` — calls `dispose()` on all registered targets (closes overlay window, stops browser source server, etc.)
4. `captionBusProvider` — safe to close last; registry has already unsubscribed

The `ref.onDispose` callbacks registered in each provider's `build()` method enforce this order automatically when the `ProviderContainer` is disposed.

---

## Overlay Window Architecture

### Sub-Process Model

`desktop_multi_window` spawns the overlay as a **second Flutter engine** inside the same macOS application bundle. The OS presents it as a separate native window but it shares the same binary and asset bundle.

```
zip_broadcast.app
├── main window (Flutter engine #1)
│   ├── ZbAppShell (owns CaptionOverlayTarget)
│   └── [all app UI and providers]
└── overlay window (Flutter engine #2, created on demand)
    └── CaptionOverlayWindow widget tree
        ├── receives 'updateConfig' via WindowController.setMethodCallHandler
        └── receives 'captionUpdate' via WindowController.setMethodCallHandler
```

Engine #2 has **no shared state** with engine #1. It receives data exclusively through platform-channel method calls originating from `CaptionOverlayTarget.onCaptionEvent()` and `CaptionOverlayTarget.show()`.

### `DesktopWindowService` Abstraction

`CaptionOverlayTarget` depends on `DesktopWindowService`, never on `desktop_multi_window` directly. The conditional export in `desktop_multi_window_service.dart` selects the correct implementation at compile time:

```
dart.library.io present?
  YES → DesktopMultiWindowService (production; macOS/Windows/Linux)
  NO  → DesktopMultiWindowService stub (web/mobile; isSupported = false, all methods throw UnsupportedError)
```

No runtime `Platform.isWeb` or `kIsWeb` checks appear at call sites. The `isSupported` guard in `CaptionOverlayTarget.show()` and `CaptionOverlayTarget.onCaptionEvent()` is the only platform branch needed.

### `CaptionOverlayTarget` Lifecycle State Machine

```
           show(config)                     show(config)
[idle] ─────────────────► [visible] ──────────────────► [visible]
                            │   invokeMethod('updateConfig', ...)
                            │
                     hide() │ or dispose()
                            ▼
                          [idle]
                  closeWindow(windowId)
```

| State | `_windowId` | `_isVisible` |
|-------|-------------|--------------|
| idle | `null` | `false` |
| visible | non-null `int` | `true` |

**`show(config)` — idle → visible**: `createWindow(jsonConfig)` is called once. The returned `windowId` is stored. Subsequent calls to `show()` on a visible window skip `createWindow` and instead call `invokeMethod('updateConfig', jsonConfig)`.

**`hide()` / `dispose()` — visible → idle**: `closeWindow(windowId)` is called; `_windowId` is cleared; `_isVisible` is set to `false`. `dispose()` delegates to `hide()`, matching the `CaptionOutputTarget` contract.

**`onCaptionEvent`**: fires only when `_isVisible == true`. Non-`SttResultEvent` events (e.g. `SessionStateEvent`) are silently dropped — the overlay renders only live caption text, not session lifecycle transitions.

### Platform-Channel Message Protocol

All IPC between the main window and the overlay window is JSON-encoded strings passed through the `desktop_multi_window` platform channel.

#### `createWindow` / `invokeMethod('updateConfig', ...)` — `OverlayConfig` encoding

```json
{
  "targetDisplayId": "NSScreen-uuid-or-null",
  "position": {
    "type": "bottom"          // "top" | "bottom" | "custom"
    // "x": 120.0,            // present only for "custom"
    // "y": 480.0
  },
  "opacity": 0.9
}
```

`targetDisplayId` is `null` when no display is specified (overlay defaults to the main screen).

#### `invokeMethod('captionUpdate', ...)` — `SttResult` encoding

```json
{
  "text": "Hello world",
  "isFinal": false
}
```

The overlay widget tree reads `isFinal` to decide whether to render the interim text in a different style (e.g. italicised). Caption content is never logged in the main window or the overlay window (SEC-U6.1, SECURITY-03).

### macOS Platform Constraints

| Constraint | Detail |
|-----------|--------|
| **Minimum macOS version** | 10.15 (Catalina) — required by `desktop_multi_window` `NSPanel`/`NSWindow` APIs |
| **Sandbox entitlements** | No additional entitlements needed; the overlay window lives inside the same app sandbox as the main window |
| **Window level** | The overlay window is created as a floating `NSPanel` above normal windows but below the system menu bar; this is the `desktop_multi_window` default |
| **Screen recording permission** | Not required — the overlay is a native window rendered by the OS compositor, not a screen capture |
| **Display targeting** | `targetDisplayId` maps to an `NSScreen` identifier; `nil` defaults to `NSScreen.mainScreen` |
| **Accessibility** | The overlay window exposes standard `NSAccessibility` attributes; VoiceOver can read caption text |

Windows and Linux inherit the same `DesktopMultiWindowService` implementation. No Unit 6 work targets those platforms; the guard `isSupported` ensures a no-op on any platform where `desktop_multi_window` cannot open a window.

---

## Output Target Registry Wiring

### Target Instance Ownership

All five output targets are instantiated once per app lifetime in `ZbAppShell` as private fields. They are not created inside providers — they are plain Dart objects owned by the shell widget, which is also app-lifetime (the `ShellRoute` builder is never rebuilt):

```dart
class _ZbAppShellState extends ConsumerState<ZbAppShell> {
  late final OnScreenCaptionTarget _onScreenTarget;
  late final ObsWebSocketTarget _obsTarget;
  late final BrowserSourceTarget _browserSourceTarget;
  late final CaptionOverlayTarget _overlayTarget;
  late final TranscriptWriterTarget _transcriptTarget;
  // ...
}
```

`CaptionOverlayTarget` receives no constructor arguments in production — it defaults to `DesktopMultiWindowService()` via the conditional export. For widget tests, `MockDesktopWindowService` can be injected.

### Registration Lifecycle — `ref.listen` on `OutputTargetSettingsNotifier`

`ZbAppShell.initState` registers a `ref.listen` on `outputTargetSettingsNotifierProvider`. On every settings change, the listener diffs the previous and next `OutputTargetSettings` and makes exactly the add/remove calls that changed:

```
OutputTargetSettings.overlayEnabled: false → true
  → registry.add(_overlayTarget)
  → _overlayTarget.show(currentConfig)

OutputTargetSettings.overlayEnabled: true → false
  → registry.remove(_overlayTarget)        ← calls _overlayTarget.dispose() → hide()
```

The initial registration (first `build`) reads the persisted settings synchronously from the notifier's current state and registers all enabled targets in `initState` via a `WidgetsBinding.instance.addPostFrameCallback`.

**Design note — Q8 reconciliation**: The FD plan answers Q8 as option B (registration per recording session), but the Phase H item H1 specifies AppShell-driven registration with toggle-change reactivity. Infrastructure Design resolves this in favour of H1 (AppShell registration). Option B would force `BroadcastRecordingNotifier` to know about platform targets — a violation of the `zip_core` boundary (MAINT-U6.4). Option A (AppShell) keeps the notifier unaware of target instances.

### Registry Fan-out Constraints (inherited from Unit 1)

- `CaptionOutputTargetRegistry` subscribes to `CaptionBus.stream` lazily — only when the first target is added (Q5=B from Unit 1 NFR).
- A thrown exception in any target's `onCaptionEvent` is caught and logged with `runtimeType` only; other targets are unaffected (REL-U1.1, SECURITY-03).
- `registry.activeTargets` returns an unmodifiable set; `ZbAppShell` never reads it — all management is done via `add` / `remove`.

---

## App Shell Orchestration

`ZbAppShell` (`lib/src/shell/zb_app_shell.dart`) is the single orchestration point for all output target and connection lifecycles. It is a `ConsumerStatefulWidget` mounted by the `ShellRoute` builder in `zbRouter`.

### H1: Multi-Target Registration

See "Registration Lifecycle" above. All five targets follow the same `OutputTargetSettings` boolean → `registry.add` / `registry.remove` pattern. `OnScreenCaptionTarget` and `TranscriptWriterTarget` are always registered (their toggles default to `true`).

### H2: OBS Lifecycle

`ObsConnectionNotifier` (keepAlive) self-manages the WebSocket connection. `ZbAppShell` does not call `connect()` / `disconnect()` directly. The notifier watches `outputTargetSettingsNotifierProvider` via `ref.listen` in its own `build()`:

```
obsEnabled: false → true  +  host/port/password present
  → ObsConnectionNotifier.connect()
  → exponential backoff (1 s → 2 s → 4 s … 30 s cap, 10 min give-up)

obsEnabled: true → false
  → ObsConnectionNotifier.disconnect()
```

`ZbAppShell` registers `_obsTarget` with the registry when `obsEnabled == true`, and removes it when `false`. The target instance forwards caption events to the live WebSocket managed by `ObsConnectionNotifier`.

### H3: Browser Source Lifecycle

`BrowserSourceTarget.start()` / `stop()` are called by `ZbAppShell`'s `ref.listen` handler for `outputTargetSettingsNotifierProvider.select((s) => s.browserSourceEnabled)`. If `start()` throws `BrowserSourceStartException`, the shell:

1. Catches the exception.
2. Shows a `SnackBar`: "Browser source failed to start on port {port}. Change it in Settings."
3. Calls `outputTargetSettingsNotifier.update(settings.copyWith(browserSourceEnabled: false))` to reset the toggle.

Registry add/remove mirrors the enable/disable toggle, same as all other targets.

### H4: Caption Overlay Lifecycle

`_overlayTarget.show(config)` is called by `ZbAppShell` when `overlayEnabled` transitions `false → true`. `config` is derived from `OutputTargetSettingsNotifier.state` at the time of the call:

```dart
final config = OverlayConfig(
  targetDisplayId: state.overlayDisplayId,   // nullable; null = main screen
  position: state.overlayPosition,           // OverlayPositionBottom() default
  opacity: state.overlayOpacity,             // 0.9 default
);
await _overlayTarget.show(config);
```

When `overlayEnabled` transitions `true → false`, `registry.remove(_overlayTarget)` triggers `_overlayTarget.dispose()` which calls `hide()`, closing the child window.

**Config updates while visible**: If `OverlayConfig` fields change while the overlay is already open (user changes position or opacity in RecordingScreen right panel), `ZbAppShell`'s listener calls `_overlayTarget.show(newConfig)` again. `CaptionOverlayTarget.show()` detects `_isVisible == true` and emits `invokeMethod('updateConfig', ...)` without reopening the window.

### H5: Wake Lock

`BroadcastRecordingNotifier.start()` acquires the wake lock via `WakeLockService.acquire()`. `stop()` releases it. No `ZbAppShell` involvement — same pattern as `RecordingStateNotifier` in `zip_captions`.

---

## Security Compliance

| NFR | Rule | Status | Implementation |
|-----|------|--------|----------------|
| SEC-U6.1 | SECURITY-03 extension | Compliant | `CaptionOverlayTarget` logs only windowId integers and error types; `result.text` is never logged; the overlay child window has no logger |
| SEC-U6.2 | OBS password `obscureText` | Compliant | `ObsSettingsNotifier` stores password in `FlutterSecureStorage`; `TextField` uses `obscureText: true`; password never appears in `ObsConnectionNotifier` log output |
| REL-U6.2 | Browser source port conflict | Compliant | `BrowserSourceStartException` caught in ZbAppShell; SnackBar shown; toggle reset to `false` |
| REL-U6.3 | OBS test-connection timeout | Compliant | `ObsConnectionNotifier.testConnection()` uses 5 s `Future.timeout`; result reported via SnackBar |
| MAINT-U6.2 | Logger naming | Compliant | All `Logger` instances in Unit 6 files use `'zip_broadcast.{ClassName}'` prefix |
| MAINT-U6.3 | `go_router` version | Compliant | `zip_broadcast/pubspec.yaml` pins `go_router: ^14.0.0` |
| MAINT-U6.4 | `BroadcastRecordingNotifier` scope | Compliant | Notifier imports only `zip_core` and `zip_broadcast`; no `zip_captions` imports; target registration handled by ZbAppShell (H1) |
