# Business Logic Model — Unit 8.1: Pop-out Live Captions (S-21)

**Status**: APPROVED 2026-10-21 by James Petersen (revised after the pre-build review: RQ-1 A / RQ-2 A / RQ-3 A-amended; revision 2 same day).
**Scope**: The promotion of Unit 8's window machinery into `zip_core`, the pop-out's lifecycle, and
the exact per-app wiring. User-visible rules live in `business-rules.md`; types in
`domain-entities.md`; widget structure in `frontend-components.md`.

---

## 1. What the promotion actually moves

The unit definition calls the subject "the window controller and its state machine, the versioned
launch/snapshot codec, the sub-engine entry contract and the `window_manager` registration helper".
Read against the shipped code, that is 23 files, and the "ready handshake" is spread across three
layers. The inventory:

```
zip_broadcast/lib/src/output/overlay/
  overlay_window_controller.dart          -> zip_core  (state machine, T1-T17, resolveOpenDisplay)
  overlay_window_mode.dart                -> zip_core  (+ PopOutMode)
  caption_overlay_codec.dart              -> zip_core  (+ 'popOut' token, contentMode)
  caption_overlay_snapshot.dart           -> zip_core  (+ contentMode)
  overlay_activity.dart                   -> zip_core
  overlay_event.dart                      -> zip_core
  external_display_status.dart            -> zip_core  (name kept)
  desktop_window_service.dart             -> zip_core  (+ setFrame only, no setBounds)
  desktop_multi_window_service.dart       -> zip_core  (export)
  desktop_multi_window_service_io.dart    -> zip_core  (unchanged logic)
  desktop_multi_window_service_stub.dart  -> zip_core  (unchanged)
  overlay_window_bridge.dart              -> zip_core
  overlay_window_bridge_io.dart           -> zip_core
  overlay_window_bridge_stub.dart         -> zip_core
  overlay_window_entry.dart               -> zip_core  (+ alwaysOnTop, pop-out body)
  NOTE: overlay_window_app.dart is in lib/src/widgets/, not overlay/; it moves
        to zip_core/lib/src/widgets/overlay_window_app.dart because
        OverlayWindowEntry builds it (+ injected unavailable copy,
        shared _themeModeOf helper, no ARB dependency).
  display_enumerator.dart                 -> zip_core
  display_info.dart                       -> zip_core
  display_info.freezed.dart               -> zip_core  (regenerated at the new path)
  screen_retriever_display_enumerator.dart-> zip_core
  ..._io.dart                             -> zip_core
  ..._stub.dart                           -> zip_core
  caption_position.dart                   -> stays (external-display-only concept)
  caption_overlay_target.dart             -> stays (app bus adapter; imports updated)

zip_broadcast/lib/src/models/
  overlay_config.dart                     -> zip_core  (freezed; app file becomes a re-export)
  overlay_position.dart                   -> zip_core  (app file becomes a re-export)

new in zip_core:
  output/overlay/window_configurator.dart / _io.dart / _stub.dart   (was always_on_top_installer)
  output/overlay/pop_out_geometry.dart
  output/overlay/overlay.dart              (barrel)
  widgets/pop_out_window_body.dart
```

**The re-export exception (Q3 A)**: `zip_broadcast/lib/src/models/overlay_config.dart` and
`overlay_position.dart` become
`export 'package:zip_core/src/output/overlay/overlay_config.dart';` (and the position equivalent).
`OverlayConfig`'s generated `part` file moves with it, so `overlay_config.freezed.dart` is deleted
from `zip_broadcast` and regenerated in `zip_core`. This is the one shim Q12 A allows: it keeps
`const OverlayConfig()` and `const OverlayPositionTop()` working at every existing call site
(including `x.overlayPosition.dart` test fixtures) without a 40-file import rewrite. It is a
one-line file with no logic and is deleted when its last consumer migrates.

**Why `ExternalDisplayStatus` keeps its name**: see `domain-entities.md` §1.1. The pop-out reuses
the same seven states; the pop-out-specific rendering is `PopOutMode` in the launch, plus the
`Failed` reason mapping below.

---

## 2. The promoted state machine (unchanged behaviour)

`OverlayWindowController`'s transitions are Unit 8's T1-T17 (in
`external-display/functional-design/business-logic-model.md`). They are **not** re-derived here and
**are not modified**. The pop-out inherits every one:

| Event | State change | Pop-out consequence |
|---|---|---|
| construct, platform capable | → `Off` after enumeration | toggle renders (enabled per §3.1 of `domain-entities.md`) |
| construct, platform incapable | → `Unsupported` | toggle not rendered |
| `open()` | → `Opening`, 10 s ready timer | toggle reads "Exit Picture in Picture" |
| `overlayReady` | `setFrame` + `show` → `Open(activity)` | window visible; configuration already applied (3.2) |
| ready timeout | → `Failed(ready_timeout)`, `OpenFailed` | shell clears `popOutEnabled`, banner shows |
| `createWindow` throws | → `Failed(create_failed)`, `OpenFailed` | same |
| `close(toggleOff)` | → `Off` | shell clears `popOutEnabled` |
| window `'-1'` while `Open` | → `Off`, `WindowClosed` | shell clears `popOutEnabled` (BR-PIP-03) |
| `close(dispose)` | → `Off` (or keeps `Failed`) | app shutdown |
| display change while `Open` | re-frames to the display's bounds (T15) | **not applicable**: the pop-out is not framed to the display's work area and does not follow displays (3.4) |
| display lost while `Open` | → `WaitingForDisplay` | **not applicable**: same reason |

**Mode-conditional behaviour, the only additions to the machinery.** Two table rows above are
external-display-only. Rather than a new state, the controller gains one private predicate,
`bool get _isPopOut => _mode is PopOutMode;` and:

- `_onDisplaysChanged`'s `Open` branch: for `PopOutMode`, **skip** the `T15` re-frame and the `T10`
  display-lost transition. A pop-out on a display that disappears is repositioned by the OS, not
  closed: closing it would end the user's pop-out because they unplugged a monitor.
- `_runReady`: for `PopOutMode`, frame with the **shell-computed** geometry (R-M5) rather than the
  display work area. The controller does not call `computePopOutFrame` — it has no `TextTheme`, no
  `DisplaySettings` and no text scaler, and the pop-out has no display to resolve. `open()` gains one
  optional parameter, `Rect? frame`, supplied by the shell for pop-out only; `_runReady` uses it
  verbatim through `setFrame`. External-display behaviour is unchanged (`frame == null`).
- `_runOpen` with a `PopOutMode` config: skip `resolveOpenDisplay` and the
  `WaitingForDisplay`-for-a-saved-display path entirely (no persisted selection exists).
- `open()`'s `persistedDisplayId` parameter is ignored for `PopOutMode` (documented, not an error).

These are the **only** behaviour differences, and each is a guard on a single branch. Unit 8's
external-display branches keep their exact code and tests.

**R-M2 correction (2026-10-21): the guards are required on every path that consults a display, not
just the two transitions above.** NFR-R §10.2 originally claimed that leaving `_modeDisplayId` null
made the display-lost branch inert for a pop-out. That is false: `_find(null)` returns the primary
or the first display (`overlay_window_controller.dart:275-281`), so with a null id:

| Path | Code | Without a guard |
|---|---|---|
| `Open` + display event | `:225-238` (T15) | re-frames the pop-out to the primary's full work area |
| `Open` + empty list | `_handleDisplayLost` | closes the pop-out because a monitor was unplugged |
| `Opening` + empty list | `:239-243` | fails the open with `display_lost` |
| `_runReady` | `:402-411` | frames to the primary's bounds instead of the computed frame |
| `open()` / `_runOpen` | `:309-314`, `:345-353` | `NoDisplays` when the list is empty |

NFR-R §10.2's reasoning is withdrawn. The `_isPopOut` guards are mandatory on all six paths.

**Single source of truth for the mode: construction, not `open()`.** NFR-R §10.1's
`createController(mode, …)` and §2's "mode read from the config at `open()`" disagreed. The mode is
supplied at construction and read from `_mode`; `open()`'s `OverlayConfig.mode` is validated against
it (a mismatch fails the open as `create_failed`), never used to switch behaviour.

---

## 3. Pop-out lifecycle (main engine)

```
            toggle pressed
                 |
                 v
   _popOutEnabled = true            (shell, in-memory; Q10 B)
   registry.add(_popOutTarget)      (so the first snapshot has the buffer)
   target.show(OverlayConfig(mode: PopOutMode()))
                 |
                 v
   controller.open() --- unsupported/off/opening/open -> no-op (BR-PIP-02)
                 |
                 v
   computePopOutFrame(...)  (SHELL: has context, settings, textTheme, textScaler)
   controller.open(config, frame: computed.frame)
   createWindow(encodeLaunch(launch))
                 |
     [sub-engine starts]  (3.2)
                 |
   overlayReady -----> setFrame(frame) ; show() ; Open
                 |
   caption events -> snapshot -> 16 ms coalesced captionUpdate
```

Toggle off: `_popOutEnabled = false`; `registry.remove(target)`; `target.hide()` →
`close(toggleOff)` → window closed. Main window re-registers nothing.

**Why register before showing**: identical to `CaptionOverlayTarget`'s shipped ordering — the
launch's first frame must already contain the live buffer, not an empty one.

**Why in-memory**: Q10 B. There is no settings write on any pop-out path, so BR-PIP-03's coherent
state is a pure function of the controller's status plus the shell's boolean.

### 3.1 Recognition continuity

`PopOutCaptionTarget.onCaptionEvent` folds `SessionStateEvent` into `OverlayActivity` (same mapping
as `CaptionOverlayTarget._activityFor`) and pushes a snapshot. It never calls into
`RecordingStateNotifier`. Adding/removing it is a registry change only.

### 3.2 Pop-out sub-engine startup sequence

The order is the contract (BR-U8.1-05, BR-U8.1-06, BR-PIP-11):

```
1  WidgetsFlutterBinding.ensureInitialized()        (from main)
2  isOverlayWindowLaunch(args) -> true
3  decodeLaunch(args[2])
4  if decode fails: pump OverlayWindowUnavailableApp, return   (never signals ready)
5  GoogleFonts.config.allowRuntimeFetching = false
6  await windowConfigurator.configure(windowId, config)   <-- native channel, own window
7  install bridge handler
8  pump ProviderScope(OverlayWindowEntry(launch, bridge, windowConfigurator: null))
9  OverlayWindowEntry.initState: send('overlayReady')
```

Steps 6 and 7 both precede step 9, so (a) the window already floats and is decorated when it is
shown, and (b) the first `captionUpdate` always finds a handler.

**Why step 6 is a channel call and not a plugin** (RQ-1 A, 2026-10-21): `window_manager` cannot be
used here. Its macOS `ensureInitialized` assigns `windowManager.mainWindow` and the setter does
`_mainWindow?.delegate = self` (`WindowManager.swift:54-63`), which replaces
`desktop_multi_window`'s `FlutterWindow` delegate (`FlutterWindow.swift:85`). That delegate is the
*only* path by which an OS close reaches `onClose` → `windows.removeValue` →
`deinit` → `shutDownEngine()`. Losing it means (i) no `'-1'` to the main engine, so the shell stays
"popped out" forever, and (ii) one leaked Flutter engine per open/close cycle. Registering the whole
generated plugin set instead is worse: `FlutterMultiWindowPlugin.register(with:)` calls
`attachMainWindow`, which overwrites `windows[0]` with the sub-engine's channel
(`FlutterMultiWindowPlugin.swift:8-23`, `MultiWindowManager.swift:29-33`), so every
`invokeMethod(0, …)` — including `overlayReady` — would land back in the sub-engine and **every**
open, Unit 8's included, would end in `ready_timeout`.

The configuration is therefore applied by a small per-runner native channel that the callback
registers on the new sub-engine:

```
channel  zip_/overlay_window_configure            (one name per app)
method   configure({windowId: int, floating: bool, decorated: bool,
                    minWidth: double, minHeight: double})
```

The sub-engine passes the window id it was launched with (`args[1]`), because the native callback
cannot know it otherwise (the plugin's `WindowCreatedCallback` receives only the view
controller/registry — `desktop_multi_window_plugin.h:20-21,24-27`). What the mode implies:

| Mode | `floating` | `decorated` | Effect |
|---|---|---|---|
| `ExternalDisplayMode` | false | false | today's borderless caption surface, unchanged (BR-U8.1-04) |
| `PopOutMode` | true | true | title bar, close button, resize handles, floats above other apps |

`configure` failing is caught inside the configurator: the window still opens, the user may not get
the requested styling, and a fixed string is logged. It must **not** prevent ready, because a failed
cosmetic call must not turn a working pop-out into an `OpenFailed`.

**Per-platform mechanism** (RQ-1 A + RQ-3 as amended by the owner, 2026-10-21). Every hook is
additive: none takes over a `desktop_multi_window` delegate, and none replaces its own handlers.

| Platform | Level / size | Close notification | Evidence |
|---|---|---|---|
| macOS | the `configure` handler sets `NSWindow.level`, the `styleMask`/titlebar properties and `contentMinSize` on the sub-engine's `view.window` | `NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window)` | `FlutterWindow.swift:85` keeps the delegate; `windowWillClose` (`:102-110`) still reaches `onClose` |
| Windows | `SetWindowPos(HWND_TOPMOST)`, style bits for `WS_CAPTION`/`WS_THICKFRAME`, `WM_GETMINMAXINFO` | a top-level window-proc delegate registered on the sub-engine's registrar, handling `WM_CLOSE` | `flutter_window.cc:151` calls `HandleTopLevelWindowProc` **before** its own switch, so a plugin delegate sees the message first and `WM_CLOSE` still reaches the plugin's own `:174` handler |
| Linux | `gtk_window_set_keep_above`, `gtk_window_set_decorated`, `gtk_widget_set_size_request` | `g_signal_connect(window, "delete-event", …)` after the plugin's own connection | `flutter_window.cc:34` already connects `delete-event`; GTK runs handlers in connection order and the plugin's returns `TRUE` after destroying |

**Linux consequence, found at review**: `desktop_multi_window`'s `on_close_clicked` returns `TRUE`
after `gtk_widget_destroy`, so a handler connected *after* it never runs. The close notification must
therefore be connected with `g_signal_connect_after` **and** derive the id from the window it was
given, or be emitted from the `"destroy"` handler (`flutter_window.cc:35-40`), which runs for every
close path including the Dart-initiated one. Infrastructure Design settles which, and must not
assume the handler order is free.

**The close notification goes to the main engine, not from the sub-engine** (owner amendment,
2026-10-21). `desktop_multi_window` tears the sub-engine down inside its own close handling —
macOS `windowWillClose` → `onClose` → `windows.removeValue` → `deinit` → `shutDownEngine()`
(`FlutterWindow.swift:88-99`); Windows `WM_DESTROY` → `Destroy()` (`flutter_window.cc:213-224`);
Linux the `"destroy"` handler → `OnWindowClose`/`OnWindowDestroy`
(`linux/flutter_window.cc:35-40`, `linux/multi_window_manager.cc:146-151`) — so a Dart message sent
from the sub-engine at that moment is likely lost.

**Correction 2026-10-21 (review item 1): the notification cannot reuse
`desktop_multi_window`'s window channel.** That channel is plugin-internal: the macOS
`WindowChannel` class is not `public` (`macos/Classes/WindowChannel.swift:14` — `class
WindowChannel: NSObject, FlutterPlugin`), and Windows/Linux expose only
`include/desktop_multi_window/desktop_multi_window_plugin.h`. A runner therefore cannot emit on the
main engine's window channel, and the event cannot arrive through `DesktopMultiWindow`'s method
handler — so it must **not** flow through `OverlayMethodRouter` or the controller's
`_handleWindowCall`, both of which are fed by that channel.

The transport is instead a **first-party** channel that each app's runner registers on the **main**
engine, in the main-window setup (where the main `FlutterViewController`'s messenger is in hand):

```
channel  zip_/overlay_main_window                 (one name per app)
method   subWindowClosed  {windowId: int}         (payload: the sub-window id only)
```

It is registered for **every** sub-window, the external display included — the same lazy-detection
gap exists in Unit 8, and closing it is recorded as a **Unit 8 improvement, not a change to Unit 8's
states or rules** (the only observable difference is that the external display's shell learns of an
OS close promptly instead of on the next window call; `'-1'` still exists for both modes).

Dart side, in `zip_core` behind the usual conditional export (`sub_window_closed_channel.dart` /
`_io.dart` / `_stub.dart`, injectable fake in tests):

```
abstract class SubWindowClosedChannel {
  Stream<int> get closed;                  // window ids, in arrival order
  void dispose();
}
```

One new public controller entry consumes it:

```
void onNativeWindowClosed(int windowId)
```

It maps to `CloseReason.windowClosed` **when `windowId` matches the open window**, and is dropped
otherwise. App-initiated closes (toggle-off, `dispose`, an open failure) are dropped automatically
because `_takeWindow()` nulls the window id first (`overlay_window_controller.dart:528-533`, called
at `:501`, `:552`, `:560`, `:683`) — the late native event for a window we already closed finds no
matching id. This is a **permitted deviation under BR-U8.1-01**.

The `'-1'` path (`:619-631`) stays as the fallback for everything the native hook does not cover.

**Infrastructure Design must verify, not assume**: that a Dart message from the sub-engine at close
time is lost (the amendment's premise); the macOS notification's delivery point relative to
`deinit`; the Windows delegate's ordering against `HandleTopLevelWindowProc`; and the Linux handler
order above.

### 3.3 The in-surface toggle from the pop-out window

§8.3 UX-PIP-02 requires the in-surface toggle to work **from the pop-out window itself**. The
pop-out's engine has a bridge to window `0` and nothing else. The toggle therefore sends a new
method over the existing bridge:

- sub-engine → `bridge.sendToggle()` → `DesktopMultiWindow.invokeMethod(0, 'popOutToggle', null)`.
- main engine's shared handler → `popOutToggle` → the shell's `_togglePopOut()` (same code path as
  the chrome toggle), and the window closes through the normal `close(toggleOff)` +
  `WindowClosed`/window-teardown path.

`OverlayWindowBridge` gains `void sendPopOutToggle();` (implemented in `_io`, no-op in `_stub`),
and the controller's `_handleWindowCall` gains one case, `'popOutToggle'`, which emits a
`PopOutToggled` `OverlayEvent` that the shell listens for. The controller does not toggle itself:
the toggle decision belongs to the shell (it owns `popOutEnabled`), the same separation Unit 8
uses for `WindowClosed` (controller reports, shell decides).

**Security**: the message carries no payload and is only accepted from the current window id, using
the existing stale-window guard. Nothing about caption text crosses this direction.

### 3.4 Framing (Q9 amended)

`computePopOutFrame` is a pure top-level function in `pop_out_geometry.dart`:

```
({Rect frame, String? displayId}) computePopOutFrame({
  required List<DisplayInfo> displays,
  required Offset? mainWindowCentre,     // null -> fall back to primary
  required DisplaySettings settings,
  required TextTheme textTheme,
  required double textScaler,
})
```

1. Pick the display whose `bounds.contains(mainWindowCentre)`; else the `isPrimary`; else the
   first; else return `(Rect.zero, null)` meaning "no display known, let the platform place it".
2. `size = popOutSize(settings, textTheme, textScaler)` (see `domain-entities.md` §3.3), clamped to
   the display work area.
3. `frame.left = workArea.center.dx - size.width / 2`;
   `frame.top  = workArea.bottom - size.height`.
4. Clamp `left`/`top` inside the work area so a tiny display cannot push the window off-screen.

The window is not reframed later (3.0's table).

**R-M5 resolved (2026-10-21) — who computes the frame.** The **shell** does, because it is the only
component with the inputs: a `BuildContext` (hence `Theme.of(context).textTheme` and
`MediaQuery.textScalerOf(context)`), the resolved `DisplaySettings`, and
`controller.displays`. The controller has none of the three, and for `PopOutMode` there is no
display to resolve. The shell calls `computePopOutFrame(...)` and passes the result into
`controller.open(config, frame: computed.frame)`; `_runReady` uses it via `setFrame`. The controller
never calls the geometry function, so `pop_out_geometry.dart` stays a pure library that both apps
and the tests can drive without a controller.

`mainWindowCentre` is **null in production this unit** (NFR-R §10.3, Q2 C): the function's own
documented fallback picks the primary display, and multi-monitor placement is a Unit 9 platform
check. The parameter exists so a later unit can pass a real centre without changing the function's
shape; passing one now would require a `window_manager`-style geometry call on the open path for
behaviour nobody has yet observed on a real multi-monitor desk.

**R-M5 second half — the title bar is not in the size.** `setFrame` sets the window's **outer**
frame. On a decorated window the title bar is inside that frame on Windows and Linux, and on macOS
`desktop_multi_window` creates the window with `.titled, .fullSizeContentView`,
`titleVisibility = .hidden` and `titlebarAppearsTransparent = true` (`FlutterWindow.swift:68-71,
86-88`), so content draws under it. Either way "two lines + toggle row" of content gets clipped.

The geometry therefore adds an explicit per-platform **chrome allowance** to the requested size on
decorated platforms, and `popOutSize`'s contract is documented as *content* size. The allowance is a
named constant per platform in `pop_out_geometry.dart` with its own table test, not a magic number
inside `computePopOutFrame`; Infrastructure Design verifies the three values against real windows
(Unit 9's manual check records the measured result). The minimum size (320x96) is likewise
interpreted as content size.

**Recorded limitation**: without main-window geometry the pop-out opens bottom-centre of the
primary display. This is a deliberate simplification, not a claim of "on the window's display"; the
function takes the centre so it can be improved without redesign. Unit 9's manual check records
where it actually appears per platform.

---

## 4. Cross-cutting mechanics

### 4.1 The shared method-handler dispatcher (BR-U8.1-04, BR-PIP-01)

`DesktopMultiWindow.setMethodHandler` is one static slot. Two controllers (external display and
pop-out) in one engine need both handlers. The promoted `overlayMethodHandlerInstaller` cannot be
passed to both, because the second call replaces the first.

Resolution, in `zip_core`:

```
class OverlayMethodRouter {
  OverlayHandlerToken register(int? Function() windowIdOf, OverlayMethodHandler handler)
  void unregister(OverlayHandlerToken token)
  OverlayMethodHandlerInstaller installerFor(OverlayHandlerToken token)
}
```

**Pinned shape (review item 2, 2026-10-21).** The earlier draft was unimplementable in two ways:
`windowIdOf` could not see the controller's private `_windowId`, and "registration happens after
`createWindow` returns" contradicted the shipped install call, which runs in `_bootstrap`
(`overlay_window_controller.dart:191` — `_handlerInstaller?.call(_handleWindowCall)`, i.e. before any
window exists). Pinned:

- The controller exposes `int? get windowId` (a permitted deviation under BR-U8.1-01).
- The token-bound installer is called **at bootstrap, as today**. Nothing moves.
- The router dispatches only when `windowIdOf()` is non-null **and** equal to `fromWindowId`;
  **null never matches**, so a controller with no window receives nothing. This closes the
  `:390` hole where `_windowId == null` accepted every message.

**R-M3 corrections (2026-10-21).** The first draft could not be implemented as written. Four facts
in the shipped code force the shape above:

| Problem | Shipped fact | Resolution |
|---|---|---|
| "stop after the first one that recognises the method" is unimplementable | `OverlayMethodHandler` returns `Future<void>`, not `bool` (`overlay_window_controller.dart:33-36`) | The router routes by **window id**, which the handler already receives as `fromWindowId` (`:33-36`, `:388-390`). No handler returns a verdict. |
| A controller without a window accepts any window's message | the guard is `if (_windowId != null && fromWindowId != _windowId) return;` (`:390`) — a `null` window id accepts everything | Routing is the router's job, not the guard's. The router only dispatches to the handler whose registered `windowIdOf()` equals `fromWindowId`, and to exactly one. |
| `installer(null)` cannot say which handler to remove | `OverlayMethodHandlerInstaller` is `void Function(OverlayMethodHandler?)` and `dispose()` calls `_handlerInstaller?.call(null)` (`:708`) | Each controller gets a **closure bound to its own token** via `installerFor(token)`, so its existing `dispose()` call removes exactly itself. Unit 8's signature and call site are unchanged (BR-U8.1-01). |
| Registering before the window exists cannot be routed | the id arrives from `createWindow`'s return value; the installer runs at `_bootstrap` (`:191`) | Registration stays at bootstrap (unchanged). `windowIdOf()` is consulted only at dispatch, by which time the id is set; while it is null, `null never matches`, so the handler is simply dormant. |

- Constructed once per engine (by the provider in the main engine; not at all in the sub-engine).
- First registration installs the static slot with the router's dispatch function; the last
  unregistration clears it. A duplicate `unregister` is a no-op.
- An id that matches no handler is dropped (logged as a fixed string).
- Each controller receives `router.installerFor(token)` as its `handlerInstaller`, so Unit 8's
  fail-closed `null` check still holds (it is never null in production).
- Alternative rejected: a `null` installer for the second controller. It would fail every pop-out
  open closed with `create_failed` — correct-looking and completely wrong.

**Permitted controller deviations (BR-U8.1-01)**, the complete list:

1. The six `_isPopOut` guards (§2).
2. The `'popOutToggle'` case in `_handleWindowCall` (§3.3).
3. `open({Rect? frame})` (§2).
4. Mode fixed at construction (§2).
5. The token-bound installer (§4.1) — signature and call site unchanged.
6. `int? get windowId` (§4.1).
7. `void onNativeWindowClosed(int windowId)` (§3.2) — the native close entry.

Nothing else in the controller changes; every moved test must still pass with import-path edits only.

**The main engine's two controllers**: `overlayWindowControllerProvider` keeps its name and now
also owns the router plus a second, `popOutWindowControllerProvider`-shaped constructor argument
list. Both share the enumerator (one platform observer) and the router, and both are disposed with
the container.

### 4.2 Coalescing and the ready handshake

Unchanged (Unit 8's P1/R3). The pop-out benefits from the same 16 ms cadence and the same held
snapshot on ready.

### 4.3 Own-window settings (BR-U8.1-05)

`WindowConfigurator.configure(windowId, config)` runs in the sub-engine over the per-runner native
channel (§3.2). It replaces the `window_manager`-based installer (RQ-1 A, 2026-10-21): no
`window_manager` dependency, no `ensureInitialized()`, and **no delegate replacement** — which is
what R-B2 was about. The floating level, the decoration and the minimum size are all applied
natively on the window the sub-engine owns.

**R-M9 resolved**: the install point is stated once, in §3.2 step 6 (`overlayWindowMain`), before the
bridge handler and before `OverlayWindowEntry` sends `overlayReady`. `OverlayWindowEntry` receives
`windowConfigurator: null` and does **not** await it — the earlier draft had it both ways
(BLM step 6 *and* domain-entities §1.2).

**R-m1 resolved**: `DesktopWindowService` gains **nothing**. `setBounds(…, {bool center})` and a
throwing `setAlwaysOnTop` are dropped as dead surface; `setFrame` (and the existing
`toPlatformFrame`) serve both modes. `center` also contradicted bottom-anchoring: the plugin's
`center()` maps to `NSWindow.center()`, which is not bottom-anchored (`FlutterWindow.swift:30-32`).

### 4.4 The `zip_captions` main-entry routing (BR-U8.1-06)

`zip_captions/lib/main.dart` today is `void main() async` with no args. It becomes:

```
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isOverlayWindowLaunch(args)) {
    await overlayWindowMain(args);
    return;
  }
  ... existing body unchanged ...
}
```

The three runners already pass argv through to Dart on every platform (macOS via the plugin's
engine creation, Windows/Linux via `dart_entrypoint_arguments`), which Infrastructure Design
verifies requirement-by-requirement.

---

## 5. Where each piece lives (both apps)

| Concern | `zip_broadcast` | `zip_captions` |
|---|---|---|
| Controller ownership | existing provider, extended with the router + a second controller | new provider file, same shape |
| Pop-out target | `PopOutCaptionTarget` next to `CaptionOverlayTarget` | new `PopOutCaptionTarget` |
| Toggle state | shell field `_popOutEnabled` (in-memory) | `popOutNotifierProvider` (in-memory `Notifier<bool>`) |
| Chrome toggle placement | `ZbAppShell` header action | `ZcAppShell` header action |
| Hint | `PopOutBanner` above the caption surface in `RecordingScreen` | same in `RecordingScreen` |
| In-surface toggle | `RecordingScreen` passes `controls:` | `RecordingScreen` passes `controls:` |
| Copy | `l10n/arb/app_en.arb` | `l10n/arb/app_en.arb` + `ZcStrings` |
| Sub-engine entry | existing `main(List<String> args)` | new `main(List<String> args)` |
| Runner registration | existing callbacks gain `window_manager` registration | callbacks added |

`zip_captions` uses a notifier rather than a shell field because its shell is stateless and its
screens are the toggles' siblings; `zip_broadcast` uses a shell field because its shell already
owns the overlay target and the registry, so putting the pop-out anywhere else would create a
second owner of output-target registration.

---

## 6. Failure paths

| Failure | Result |
|---|---|
| Platform unsupported | control hidden; `open()` no-ops; nothing logged |
| No engine registered, session idle | control disabled with reason; no window call |
| `createWindow` throws | `Failed(create_failed)`, `OpenFailed`; shell clears flag; banner |
| ready never arrives (10 s) | `Failed(ready_timeout)`; shell clears flag; banner |
| `setFrame`/`show` throws non-`'-1'` | logged fixed string, ignored (Unit 8 R4) |
| window disappears (`'-1'` while `Open`) | `WindowClosed`; shell clears flag (fallback path) |
| native `subWindowClosed` for the open window | `WindowClosed`; shell clears flag (primary OS-close path, 3.2) |
| native `configure` throws | fixed-string warning; window still opens (3.2) |
| codec decode fails in sub-engine | unavailable frame; never signals ready; main engine times out |
| `popOutToggle` arrives from a stale window | ignored by the existing window-id guard |
| decode of a `captionUpdate` fails | dropped, last frame stays (unit 8 behaviour) |

No path logs caption text. No path leaves a window registered without a state that explains it.

**R-M8 resolved (2026-10-21) — where the open-failure copy renders.** BR-PIP-03 and §6 said the copy
renders "on `OpenFailed` (banner)", but `frontend-components.md` §5 renders `PopOutBanner` only while
`popOutEnabled && (Opening || Open)`, and the shell clears `popOutEnabled` on `OpenFailed`, so the
banner is never visible at that moment. The failure text renders **next to the chrome toggle while
the controller's status is `Failed`**, matching Unit 8's existing pattern for
`ExternalDisplayControls`; it clears when the status next leaves `Failed` (the next open attempt, or
`Off`). The banner stays a *success-and-progress* affordance. Corrected in
`frontend-components.md` §5 and BR-PIP-03.

---

## 7. Tests: move, shape, and the two freedom points

**Move unchanged (import-path change only)** — these must pass verbatim in `zip_core`:

`caption_overlay_codec_test`, `caption_overlay_codec_properties_test`, `display_enumerator_contract_test`,
`display_info_test`, `display_state_machine_properties_test`, `external_display_status_test`,
`overlay_window_controller_test`, `overlay_window_entry_test`, `resolve_open_display_test`,
`resolve_open_display_properties_test`, `to_platform_frame_test`, `to_platform_frame_properties_test`,
`desktop_window_service_io_test`, plus `helpers/{fake_display_enumerator, generators, pbt}`.

**Move with a documented shape change** — exactly these five, and nothing else:

1. `overlay_window_entry_test`'s two `overlayWindowMain` tests reference the app's ARB string
   `'Window unavailable'`. In `zip_core` there is no ARB, so `OverlayWindowUnavailableApp` takes the
   copy as a `required String message` (or `OverlayWindowLabels`) and the test asserts on the
   injected string. This is a required decoupling, not a weakening: the assertion still proves the
   frame renders and ready is never sent.
2. `test/output/caption_overlay_target_test.dart` and `test/widgets/overlay_window_app_test.dart`
   stay in `zip_broadcast` and only have import paths updated (the target is app-level). If
   `OverlayWindowApp` moves to `zip_core` (it must, since `OverlayWindowEntry` builds it), its test
   moves too and its `'Window unavailable'`-style assertions take the injected copy.
3. `helpers/mock_desktop_window_service.dart` needs no new stubs — `DesktopWindowService` gains no
   methods (R-m1). If the move surfaces an unused stub, delete it; do not add one.
4. `helpers/generators.dart`'s overlay generators move to `zip_core/test/helpers/generators.dart`
   (appending to the existing file), and `zip_broadcast` imports them from... **nothing**: an
   app cannot import another package's `test/` directory. So the overlay generators are duplicated
   into `zip_core/test/helpers/overlay_generators.dart`, and `zip_broadcast`'s copy shrinks to the
   generators its own tests still need. This is the one unavoidable test-helper duplication; it is
   test code, has no production cost, and both copies are covered by their own package's suite.

5. **Injecting a `WindowConfigurator` fake into `overlayWindowMain`/`OverlayWindowEntry`** (added
   2026-10-21, review item 3). `overlayWindowMain` and `OverlayWindowEntry` gain the optional
   configurator parameter, so `overlay_window_entry_test`'s launch tests must pass a fake instead of
   letting the platform default run. This is an additive call-site change in the test, not a change
   to what the test asserts.

**New tests** (list finalised in Code Generation Part 1): pop-out mode/codec, geometry, router,
window-configurator fake, pop-out window body, both apps' toggles/banners/availability matrix,
redaction audits, the `zip_captions` main-entry routing, and the native close channel
(`onNativeWindowClosed` matching vs. dropped, plus the `SubWindowClosedChannel` fake).

**Freedom points**: (1) a test may only be re-shaped for the **five** reasons above; (2) if a test
fails after the move and the cause is not one of those five, the work stops and the failure is
reported — not patched into the test.