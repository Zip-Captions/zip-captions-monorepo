# Infrastructure Design — Unit 8: External Display (S-20)

**Revised 2026-10-20** per the PR #37 review comment (2026-10-19,
<https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308>,
decisions D-1..D-13, required changes B-1..B-9) and the A7 follow-up comment
(6282213636). This revision supersedes the PROPOSED document committed in
`cbb9c79` in its entirety: the `window_manager` analysis (D-13), the ping-probe
close detection (D-9/B-5), the macOS `didBecomeKey` observer (A7 item 3), and
the coordinate claims corrected by B-1/B-2 are all removed or rewritten below.

Scope: the secondary-window entry point, the desktop platform window
configuration, the display enumeration binding, and the Phase 1 overlay
precedent this unit finishes. Functional design is `../functional-design/`; NFR
design is `../nfr-design/`; this document decides *where* and *with what
platform configuration*, not *what* the feature does.

No server-side or Supabase change; no cloud or shared infrastructure of any
kind. `screen_retriever` is a client plugin — its record is
`../functional-design/screen-retriever-security-10.md`. `desktop_multi_window`
already ships (Phase 1). The deployment surface of this unit is the three
desktop runners, named exactly in ID-5.

All plugin citations are against the cached package sources, re-verified
2026-10-20: `desktop_multi_window-0.2.1`, `screen_retriever-0.2.2` with its
federated packages, and the Flutter 3.41.7 SDK source for `ChannelBuffers`.

---

## ID-1: Secondary-window entry point in `main.dart`

`desktop_multi_window` starts each sub-window as a **fresh Flutter engine
running the app's `main` with three engine-level launch arguments**. Verified
against the 0.2.1 plugin source in the local pub cache, all three platforms:

| Platform | Evidence (0.2.1) |
|---|---|
| macOS | `macos/Classes/FlutterWindow.swift:73`: `project.dartEntrypointArguments = ["multi_window", "\(windowId)", arguments]` |
| Windows | `windows/flutter_window.cc:100`: `project.set_dart_entrypoint_arguments({"multi_window", std::to_string(id), std::move(args)})` |
| Linux | `linux/flutter_window.cc:45-46`: `const char *entrypoint_args[] = {"multi_window", g_strdup_printf("%ld", id_), args.c_str(), nullptr};` |

The Dart API documents the same fixed-length contract
(`lib/desktop_multi_window.dart:14-23`). Every sub-engine therefore calls
`main(args)` with `args[0] == 'multi_window'`, `args[1] == windowId`,
`args[2] == arguments`. The three-argument contract holds and is kept.

### Shape

```dart
// packages/zip_broadcast/lib/main.dart
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isOverlayWindowLaunch(args)) {
    await overlayWindowMain(args);
    return;
  }
  ... existing broadcast startup, including GoogleFonts.config and Supabase.initialize ...
}
```

`overlayWindowMain` lives in
`lib/src/output/overlay/overlay_window_entry.dart`, platform-neutral, and
returns before any broadcast startup. What it **must not** do, each for a
concrete reason:

| Not done | Why |
|---|---|
| `Supabase.initialize` | The window has no auth need (BR-U8-14); a second Supabase client in a sub-engine opens a second realtime socket and a second GoTrue refresh loop for a window whose whole purpose is captions |
| `_initLogging()` | The root logger listener is per-engine; the overlay's own logging is one `Logger` with fixed strings (BR-U8-18) |
| Blocking startup on a window controller call | The window exists as an object when `main` runs but the plugin never orders it on screen at create time (ID-5), so blocking on `setFrame` before `runApp` gains nothing; the frame is applied after `createWindow` by the controller (F-8.3, B-6) |

What it **must** do that the old ID-1 got wrong (B-4):

- **Mirror `GoogleFonts.config.allowRuntimeFetching = false`** (the main
  engine sets it at `main.dart:32`). The old document skipped it because
  "nothing in the overlay fetches fonts" — that is false: the overlay renders
  `CaptionDisplayWidget` (zip_core,
  `packages/zip_core/lib/src/widgets/caption_display_widget.dart:72`), which
  calls `GoogleFonts.getFont`.
- **Register exactly the plugins the window-created callback provides** (ID-5).
  For the locked dependency set that list is empty (verified: `google_fonts`
  6.3.3 is a pure Dart package with no `plugin:` section; the locked
  `path_provider` federated implementations — `path_provider_foundation` 2.6.0,
  `path_provider_windows` 2.3.0, `path_provider_linux` 2.2.1 — are Dart-only
  `dartPluginClass` PDM plugins with no method channel). The callback
  registration point still exists in all three runners for D-2's borderless
  work and for any future native plugin on the overlay's path. Font rendering
  in the sub-window is a **Unit 9 manual check** (B-4's "confirm by running"),
  recorded, not claimed.

The launch detection is the plugin's own contract, so it is written against the
argument list, not against a platform check:

```dart
bool isOverlayWindowLaunch(List<String> args) =>
    args.length >= 3 && args.first == 'multi_window';
```

Malformed sub-window launch (fewer than three arguments, or an undecodable
third) is handled by `overlayWindowMain` per BR-U8-19 (fixed "Window
unavailable" failure frame), never by falling through into the broadcast
startup.

`main` gains one parameter. `flutter run` passes an empty list, so the existing
`flutter test` and `flutter analyze` surfaces are unaffected; no test invokes
`main` today.

---

## ID-2: The window's provider scope and method handlers

The secondary engine has no `ProviderScope` from the main engine. `main.dart`
wraps it:

```dart
runApp(ProviderScope(
  overrides: [
    displaySettingsProvider.overrideWith(...seeded from the launch snapshot...),
  ],
  child: const OverlayWindowApp(),
));
```

Inside `OverlayWindowApp.initState`, the sub-engine installs its method
handler **and only then** sends the ready handshake (B-5):

```dart
bridge.listen((method, args) => _handleWindowCall(method, args));
unawaited(DesktopMultiWindow.invokeMethod(0, 'overlayReady', null));
```

| Method (inbound, sub-engine) | Argument | Handler | Bad input |
|---|---|---|---|
| `captionUpdate` | `String` (JSON `CaptionOverlaySnapshot`) | decode → update the snapshot notifier → return `null` | decode failure: log `caption_update_ignored`, return `null` |
| anything else | any | return `null` | no throw |

**The one inbound message is the launch/caption payload — there is no
`popOutToggle` message.** The old ID-2's `popOutToggle` section (in-window
toggle, `fromWindowId > 0` filtering) is removed with the pop-out (D-1).

`DesktopMultiWindow` is an io-only import. The import lives in the same
conditional-export pair the shipped `desktop_multi_window_service.dart`
already uses (`_io` / `_stub`, `desktop_multi_window_service.dart:1-2`), so
the widget-test build on the host never touches it and the web build compiles
with the stub. The exact split (unchanged from the old ID-2, which holds up):
a thin `OverlayWindowBridge` interface
(`void listen(void Function(String method, Object? args) onCall)` and
`void send(Object? args)`), implemented by `DesktopMultiWindowBridge` in
`_io.dart` (over the static `DesktopMultiWindow.setMethodHandler`,
`lib/desktop_multi_window.dart:59-72` — `null` unregisters) and by a no-op
`_stub.dart`.

**One handler owner per engine (B-5):** the main engine installs exactly one
`DesktopMultiWindow.setMethodHandler`, **before the first `createWindow`**
(installer const in `desktop_multi_window_service_io.dart`; the `null`
uninstall happens only in `dispose()` — NFR Design Q7). The sub-engine
installs its own handler on its own channel; the two never contend because the
platform side routes by target window id (`MultiWindowManager.handleMethodCall`
on each platform).

---

## ID-3: `DisplayEnumerator` binding and the plugin import fence

Two files, mirroring the shipped `DesktopWindowService` split exactly:

| File | Content |
|---|---|
| `display_enumerator.dart` | the abstract interface + `DisplayInfo` re-export (platform-neutral) |
| `screen_retriever_display_enumerator.dart` (web-safe factory default) / `_io.dart` (real) / `_stub.dart` (unsupported) | factory: `DisplayEnumerator createDisplayEnumerator()`, selected by `if (dart.library.io)` — the same conditional the shipped `desktop_multi_window_service.dart:1-2` uses |

`_io.dart` is the **only** file that imports `package:screen_retriever/...`
(the single-file plugin import fence, SECURITY-10 §5 — holds up). `_stub.dart`
returns an enumerator that reports no displays and an empty closed stream; the
web build never reaches it (F-8.9 step 1 short-circuits on `isSupported`
first, BR-U8-11).

`ScreenRetrieverDisplayEnumerator`:

- `displays()` → `ScreenRetriever.instance.getAllDisplays()` mapped to
  `DisplayInfo`, preserving platform order.
- `changes` → a `StreamController<List<DisplayInfo>>.broadcast` fed by a
  `ScreenListener` registered with `ScreenRetriever.instance.addListener(...)`
  (`screen_retriever.dart:29-41`; there is no `displayChangedNotifier` —
  verified absent from 0.2.2). The platform event stream starts on the first
  Dart listener and is cancelled on the last (`:30-32`, `:38-40`). The listener
  class overrides `onScreenEvent(String eventName)`
  (`screen_listener.dart:2-4`); the event carries only `display-added` /
  `display-removed`, so **every** event triggers `getAllDisplays()` and a diff
  against the last emitted list — the corrected re-query-and-diff contract
  (holds up). That single path produces the first emission, connect,
  disconnect, rearrangement, and duplicate suppression. The latest list is
  replayed to every new listener (FD event contract).
- Map `Display.id`, `name`, `visiblePosition` + `visibleSize` → `bounds`,
  `scaleFactor`. `visiblePosition`/`visibleSize` are the work-area-aware
  rectangle; `size` alone can be larger than the visible region on a display
  with a taskbar. This is a deliberate choice: the overlay is a caption
  surface, not a wallpaper, and covering a taskbar is not its job — and it is
  what D-3 frames the window to (ID-7).
- **Coordinate provenance (corrected per B-1/B-2).** All three 0.2.2 backends
  already emit **logical top-left** values; the old document's "Windows
  reports physical pixels, divide by `scaleFactor` in the adapter" claim is
  wrong and is removed:
  - **macOS** — `screen_retriever_macos`'s `toDictionary()` takes
    `visiblePosition` from `visibleFrame.topLeft`, an extension that flips
    Cocoa bottom-left to top-left against `NSScreen.screens[0].frame`
    (`ScreenRetrieverMacosPlugin.swift:40-46`); `id` is the `NSScreenNumber`,
    `name` the localized name. That is the plugin's own output being flipped —
    it is not a frame-conversion service for other callers (B-1's first point).
  - **Windows** — `screen_retriever_windows` divides `rcWork` by the monitor's
    scale factor (`dpi / 96`) in the plugin itself
    (`screen_retriever_windows_plugin.cpp:116-124`), so `visiblePosition` /
    `visibleSize` are logical; `id` is the display device's `DeviceID`.
  - **Linux** — `screen_retriever_linux` reports the GDK monitor geometry and
    workarea (`screen_retriever_linux_plugin.cc:49-71`) — the same GDK
    coordinate space `gtk_window_move`/`gtk_window_resize` use, so no
    conversion is ever needed.
  - The one conversion that remains (macOS Cocoa y-flip; Windows physical
    multiply) lives in the io window adapter, not here — ID-5 / B-1-B-2.
- **Linux empty-id normalisation (holds up).** `Display.id` is empty on the
  Linux backend (`screen_retriever_linux_plugin.cc:76` hardcodes `""`), so the
  adapter normalises ids (`id`, else `name`, else `display-<index>`, with a
  suffix for repeated names) as specified in `domain-entities.md`.
- **Event sources, verified:** macOS observes
  `NSApplication.didChangeScreenParametersNotification`
  (`ScreenRetrieverMacosPlugin.swift:81`) but emits only when the screen count
  changes (`:86-93`); Windows emits on `WM_DISPLAYCHANGE` on count change
  (`screen_retriever_windows_plugin.cpp:86-99`);   Linux connects
  `monitor-added`/`monitor-removed` (`screen_retriever_linux_plugin.cc:191-196`).
  A count change is the only event any backend emits, which is exactly why the
  consumer re-queries and diffs instead of trusting the event name.
- `scaleFactor` is passed through for the Windows conversion and for
  description only.
- Errors from the plugin call: log a fixed string, do not forward.

**Deprecation surface (corrected per review §5).** The old document hedged
that "if 0.2.2's resolution carries a deprecation annotation, the analyzer
with `--fatal-infos` fails". That hazard is **N/A under the `^0.2.2` pin**:
`ScreenRetriever.instance` is **not deprecated** in 0.2.2 —
`screen_retriever.dart:9` declares `static final ScreenRetriever instance =
ScreenRetriever._();` with no `@Deprecated` annotation (verified 2026-10-20;
Stage 1 corrected the SECURITY-10 record accordingly). No mitigation, no
resolver-time gamble.

**D-3 record (carried into ID-7).** The window frame is the display's **work
area** — `visiblePosition` + `visibleSize` — applied with `setFrame`; native
full-screen that would cover the taskbar or menu bar is **Backlog**
(`aidlc-docs/aidlc-state.md`, "Native full-screen for the external display
window").

---

## ID-4: Close detection (ready handshake + error code)

`desktop_multi_window` 0.2.1 exposes no window-close callback to Dart on any
platform. The platform-side facts, re-verified in the cached 0.2.1 source:

| Platform | What happens on an OS close | Reaches Dart? |
|---|---|---|
| macOS | `windowWillClose` / `windowShouldClose` call `WindowManagerDelegate.onClose(windowId)`, which only removes the id from `MultiWindowManager.windows` (`macos/Classes/FlutterWindow.swift:103-109` → `macos/Classes/MultiWindowManager.swift:123-125`) | no |
| Windows | `WM_DESTROY` → `OnWindowDestroy` → `windows_.erase(id)` (`windows/flutter_window.cc:164-171` → `windows/multi_window_manager.cc:145-147`) | no |
| Linux | the `destroy` signal → `OnWindowClose`/`OnWindowDestroy` (`linux/flutter_window.cc:35-39`; the manager erases the id at `linux/multi_window_manager.cc:148-150`) | no |

So F-8.6 path C needs a detection mechanism of our own. **Decision (B-5/D-9):
a ready handshake plus the target-not-found error code. The ping probe and
D10 are removed.**

### Why the old probe design was wrong: the `ChannelBuffers` eviction

Until the overlay engine calls `DesktopMultiWindow.setMethodHandler`, it has
no listener on `mixin.one/flutter_multi_window_channel`. Messages arriving on
that channel sit in the sub-engine's `dart:ui` `ChannelBuffers`, whose default
capacity is **1** (`kDefaultBufferSize`, Flutter 3.41.7
`engine/src/flutter/lib/ui/channel_buffers.dart:319`). When a second message
arrives, `_dropOverflowMessages` (`:160-168`) evicts the first and answers it
with an **empty (null) reply** (`message.invoke(null)`, `:164`). On the main engine, a
null reply to a typed `MethodChannel.invokeMethod` surfaces as
`MissingPluginException` (`packages/flutter/lib/src/services/platform_channel.dart:351-364`).
The old F-8.6/ID-4 treated a thrown `captionUpdate` as "window closed", so a
window opened **during captioning** would have been torn down by its own first
captions. Two further facts make sending before ready strictly worse, verified
per backend:

- **macOS** — `WindowChannel.handle` with no Dart handler prints and **never
  calls the result callback** (`macos/Classes/WindowChannel.swift:38-46`):
  the main engine's future never completes.
- **Windows** — same: the handler-not-set branch returns without answering
  (`windows/window_channel.cc:24-27`): the future never completes.
- **Linux** — it answers a `'-1'` "window channel no handler" error
  (`linux/window_channel.cc:49-58`): a second false close signal with the same
  code as a real one.

### The contract

1. **Ready handshake.** The sub-engine installs its method handler, then sends
   `overlayReady` to window `0` (`DesktopMultiWindow.invokeMethod(0,
   'overlayReady', null)`). Window id `0` is the main window on all three
   backends (each manager attaches it under key `0`:
   `macos/Classes/MultiWindowManager.swift:32`,
   `windows/multi_window_manager.cc:87`, `linux/multi_window_manager.cc:73`).
2. **Hold until ready.** The main engine holds the latest snapshot and sends
   **nothing** to the sub-window until `overlayReady` arrives; the held
   snapshot is the first `captionUpdate` (NFR Design Q4).
3. **Timeout.** No `overlayReady` within `overlayReadyTimeout` — named const,
   `const Duration(seconds: 10)` in `overlay_window_controller.dart` (NFR
   Design P3) — fails the open as `OpenFailed(ready_timeout)`; idempotent
   close; a late `overlayReady` is a no-op by construction (NFR Design Q2).
4. **Close signal.** After ready, a window call failing with
   `PlatformException` code **`'-1'`** means `WindowClosed`. The code is the
   same on all three managers, verified 2026-10-20:
   - macOS — `macos/Classes/MultiWindowManager.swift:37`: `result(FlutterError(code: "-1", message: "failed to find target window. …"))`
   - Windows — `windows/multi_window_manager.cc:158`: `result->Error("-1", "target window not found.")` (channel-missing variant at `:163`)
   - Linux — `linux/multi_window_manager.cc:83`: `fl_method_call_respond_error(method_call, "-1", "target window not found.", …)` (channel-missing variant at `:88`)

   **Any other** `PlatformException` (or non-platform error) is logged as a
   fixed string with the error's `runtimeType` and **ignored** — never a
   close, never rethrown (NFR Design Q3, the single `_windowCall` seam).
5. **One handler owner.** The main engine has exactly one owner of
   `DesktopMultiWindow.setMethodHandler`, installed before the first
   `createWindow` (ID-2).
6. **No probe.** The old `ping` method and the old D10 "probe on interaction"
   are removed; there is no timer and no periodic liveness check (BR-U8-04 no
   longer scopes a probe; BR-U8-23 scopes the ready bound instead).

**What is not claimed.** A close that happens while idle and that the user
never acts on afterwards is not noticed until the next post-ready window call
or the next open attempt; closing by OS shortcut is a **Unit 9 manual check**,
recorded as such, and §8.8 item 16 routes to manual verification.

---

## ID-5: Platform window configuration

### What `desktop_multi_window` 0.2.1 gives us, verified

| Property | macOS | Windows | Linux |
|---|---|---|---|
| Window exists, separate engine | yes | yes | yes |
| `setFrame` | yes | yes | yes |
| Window shown at create | **no** (`MultiWindowManager.create`, `MultiWindowManager.swift:18-27`, returns the id without `show()`; `show` = `makeKeyAndOrderFront`, `FlutterWindow.swift:22-25`) | **no** (constructor ends in `ShowWindow(window_handle, SW_HIDE)`, `windows/flutter_window.cc:121`) | **no** (constructor ends in `gtk_widget_hide`, `linux/flutter_window.cc:63`) |
| Window-created callback | **yes** — `FlutterMultiWindowPlugin.setOnWindowCreatedCallback` (public static, `macos/Classes/FlutterMultiWindowPlugin.swift:28-30`), fired inside `FlutterWindow.init` at `:81` | **yes** — `DesktopMultiWindowSetWindowCreatedCallback` (exported, `windows/include/desktop_multi_window/desktop_multi_window_plugin.h:20-21`), fired at `windows/flutter_window.cc:116-117` | **yes** — `desktop_multi_window_plugin_set_window_created_callback` (exported, `linux/include/desktop_multi_window/desktop_multi_window_plugin.h:24-27`), fired at `linux/flutter_window.cc:52-53` |
| Borderless API | **no** — set in the callback (below) | **no** — set in the callback (below) | **no** — set in the callback (below) |
| Always-on-top API | **no** | **no** | **no** |
| Close callback to Dart | no | no | no |

### Borderless (D-2) — the window-created callback in all three runners

**Borderless comes from `desktop_multi_window`'s window-created callback in
all three runners. No new dependency, no plugin patch.** Always-on-top is **not
a Unit 8 requirement** (dropped; the pop-out unit owns its own topmost
behaviour — forward note only, D-1). The old ID-5's always-on-top section and
every `window_manager` reference are removed (D-13).

**macOS.** `FlutterWindow.swift` assigns `window.contentViewController`
(`:75`) **before** invoking `onWindowCreatedCallback` (`:81`), and AppKit
installs the controller's view as the window's content view on that
assignment — so **`controller.view.window` is the sub-window inside the
callback** (A7 item 3 settled this: use the callback directly; the old
`didBecomeKey`/order-on-screen observer is **not** built). Inside the
callback, set the borderless `styleMask` on that `NSWindow` (the created mask
is `[.miniaturizable, .closable, .resizable, .titled, .fullSizeContentView]`,
`FlutterWindow.swift:68-70`; remove `.titled`, `.closable`,
`.miniaturizable`, `.resizable`). "Borderless applied on macOS" is a **Unit 9
manual check**, recorded as such, not claimed.

**Windows.** The window-created hook exists (the old document's "no equivalent
public hook" was wrong, B-3):
`DesktopMultiWindowSetWindowCreatedCallback(void* flutter_view_controller)`
(`desktop_multi_window_plugin.h:20-21`), called at
`windows/flutter_window.cc:116-117` **after** the view is `SetParent`'d to the
top-level window (`:108`), so
`GetAncestor(view->GetNativeWindow(), GA_ROOT)` on the cast
`flutter::FlutterViewController*` yields the top-level `HWND`. Borderless:
change `GWL_STYLE` (remove `WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX |
WS_MAXIMIZEBOX | WS_SYSMENU`) and call
`SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED)`.

**Linux.** The hook exists (the old document's "nothing like
`onWindowCreatedCallback`" was wrong, B-3):
`desktop_multi_window_plugin_set_window_created_callback(FlPluginRegistry*)`
(`desktop_multi_window_plugin.h:24-27`), called at
`linux/flutter_window.cc:52-53` with the `FlView` already added to the
top-level window (`:48-50`), so `gtk_widget_get_toplevel` yields the
`GtkWindow`. Borderless: `gtk_window_set_decorated(GTK_WINDOW(window), FALSE)`.

**Callback applies to every sub-window** it is installed for — fine while
there is one kind (external display); the pop-out unit will need a mode-aware
variant (forward note only, D-1).

**Plugin registration in the callback (B-4).** The callback is also the only
place the sub-engine gets plugins (ID-1). For the locked dependency set the
list is **empty** — verified: `google_fonts` 6.3.3 has no native plugin, and
the locked `path_provider` federations (foundation 2.6.0, windows 2.3.0,
linux 2.2.1) are Dart-only PDM plugins. The registration call therefore
registers nothing today; the mechanism and the callback stay, and a future
native plugin on the overlay's path is added here.

### Frame conversion placement (B-1/B-2)

`DisplayInfo.bounds` stays **top-left and logical everywhere**. The conversions
live in **one pure function inside the io window adapter** —
`toPlatformFrame(Rect frame, TargetPlatform target, {double?
primaryFullHeight, double? displayScaleFactor}) → Rect` in
`desktop_multi_window_service_io.dart` (NFR Design P5's exact shape) — because
`desktop_multi_window`'s `setFrame` does no coordinate work itself:

- **macOS** — the plugin builds `NSRect(x: left, y: top, width, height)` and
  calls `NSWindow.setFrame`, which uses **Cocoa bottom-left** coordinates
  (`macos/Classes/FlutterMultiWindowPlugin.swift:54-63` +
  `macos/Classes/FlutterWindow.swift:35-37`). Convert with
  `cocoaY = primaryFullHeight − top − height`, taking the primary **full**
  height from `getPrimaryDisplay().size` — the same reference the
  `screen_retriever` macOS backend itself flips against
  (`ScreenRetrieverMacosPlugin.swift:40-46` uses
  `NSScreen.screens[0].frame`).
- **Windows** — the plugin calls `MoveWindow` with **raw** values
  (`windows/base_flutter_window.cc:61-69`); under the `PerMonitorV2` manifest
  (verified in this repo: `packages/zip_broadcast/windows/runner/runner.exe.manifest:5`)
  those are **physical** pixels. Multiply every edge by the **target
  display's own** `scaleFactor` (0/missing → 1) — not divide (B-2). Mixed-DPI
  safe because each display's logical values come from that display's own
  monitor scale (`screen_retriever_windows_plugin.cpp:116-124`).
- **Linux** — identity: `gtk_window_move`/`gtk_window_resize`
  (`linux/base_flutter_window.cc:23-29`) share the GDK coordinate space of
  `screen_retriever`'s workarea output. No conversion.

Unit-tested with macOS-shaped, Windows-at-1.5x, and mixed-DPI cases (FP-3 /
PBT-10 named examples; the pure function takes the platform inputs as
arguments, so no platform code is exercised in the test).

### The exact runner files Stage 6 touches (design only here)

| Runner file | Change | Precedent |
|---|---|---|
| `packages/zip_broadcast/macos/Runner/MainFlutterWindow.swift` | in `awakeFromNib`: `FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in … }` — borderless `styleMask` on `controller.view.window`; (Q2 plugin list: empty today) | the plugin's own example `MainFlutterWindow.swift` |
| `packages/zip_broadcast/windows/runner/flutter_window.cpp` | in `OnCreate` (after `RegisterPlugins`, before `SetChildContent`): `DesktopMultiWindowSetWindowCreatedCallback([](void *controller) { … })` — cast to `flutter::FlutterViewController*`, `GetAncestor(…view()->GetNativeWindow(), GA_ROOT)`, borderless `GWL_STYLE` + `SetWindowPos(… SWP_FRAMECHANGED)`; include `desktop_multi_window/desktop_multi_window_plugin.h` | the plugin's own example `flutter_window.cpp:32` |
| `packages/zip_broadcast/linux/runner/my_application.cc` | in `my_application_activate` (before the main window shows): `desktop_multi_window_plugin_set_window_created_callback([](FlPluginRegistry *registry) { … })` — `gtk_widget_get_toplevel`, `gtk_window_set_decorated(…, FALSE)`; include `desktop_multi_window/desktop_multi_window_plugin.h` | the plugin's own example `my_application.cc` |

The callbacks are process-global (the plugin's file-static function pointer),
set once at main-window startup, and fire for every later sub-window.

### macOS additionally

`Info.plist`/entitlements need no change: the plugin's sub-windows inherit the
app's sandbox. `screen_retriever`'s macOS code links only frameworks the
runner already links (`AppKit`), so no hand-edited `Podfile` change is
expected; the `screen_retriever` pod entries that `flutter build macos` adds
to `macos/Podfile.lock` are build-system output (ID "Build footprint").

### Windows / Linux additionally

No manifest, CMake, or registration change: `desktop_multi_window` is already
in all three generated plugin registrants (verified:
`macos/Flutter/GeneratedPluginRegistrant.swift:9`,
`windows/flutter/generated_plugins.cmake:7`,
`linux/flutter/generated_plugin_registrant.cc:9-20`), and the callback
export is part of that already-linked plugin.

---

## ID-6: The Phase 1 overlay precedent this unit completes

Phase 1 shipped these and nothing else (verified by reading the files):

| Shipped | Finding | This unit |
|---|---|---|
| `CaptionOverlayTarget` with `show`, `hide`, `onCaptionEvent`, `isVisible`, `targetId = 'caption_overlay'` (`lib/src/output/overlay/caption_overlay_target.dart:16-108`) | No caller of `show()` | Called from the controller (F-8.3); per B-9 reduced to a thin delegator (`show`/`hide`/`events`) + caption-bus adapter |
| `DesktopWindowService` + io/stub `DesktopMultiWindowService` (`desktop_window_service.dart:6-18`, conditional export `desktop_multi_window_service.dart:1-2`) | `isSupported` = macOS/Windows/Linux; no display, no frame | Interface gains `setFrame(int id, Rect frame)` and `show(int id)` (B-6); conversion inside the io implementation (ID-5); open order `createWindow` → `setFrame` → `show` |
| `OverlayConfig(targetDisplayId, position, opacity)` (`lib/src/models/overlay_config.dart:8-22`) | `targetDisplayId` never populated by anything | `targetDisplayId` replaced by `mode` (`domain-entities.md`; deviation recorded); `position` carries the persisted caption position (ID-7); `opacity` kept but **never applied** (B-8 opaque surface) |
| The Phase 1 caption payload — a plain-JSON `{'text', 'isFinal'}` map sent per caption (`caption_overlay_target.dart:80`) | Built, sent, and **never received**: no entry point, no handler | Replaced by the versioned `CaptionOverlaySnapshot` (B-7); `OverlayWindowApp` receives it |
| `overlayEnabled` persisted + registered by `ZbAppShell._syncOverlay` (`zb_app_shell.dart:90`, key `output.overlayEnabled` at `broadcast_providers.dart:100`) | Registering a target that never shows anything | Kept; now performs its stated job |
| `macos/Runner` / `windows/runner` / `linux/runner` | No sub-window configuration | Each gains the window-created callback (ID-5 table) |
| Test: `caption_overlay_target_test.dart` (10 cases) | Tests `show/hide/create/invoke` against a mock | Extended: display resolution, snapshot encoding, reframe, close invariant |

The precedent this unit follows, stated once: *the Phase 1 output target stays
the single `CaptionOutputTarget` for this surface; every new type is a
collaborator of it or of the shell, never a parallel target.* That is the same
shape Phase 1 used for `BrowserSourceTarget` and OBS.

---

## ID-7: Configuration surface (what a user can set, and where it lives)

| Setting | Where | Default | Persistence |
|---|---|---|---|
| External display output | Proto-13 toggle in `ExternalDisplayControls` (rendered on the recording screen and in Settings > Output Targets) | **off at every launch** (D-6 — the switch is never restored; the settings loader forces `overlayEnabled = false`) | `output.overlayEnabled` (existing key, `broadcast_providers.dart:100`) |
| Selected display | row tap in `ExternalDisplayControls` | primary | `output.externalDisplayId` (new; **never overwritten** — BR-U8-07) |
| Caption position (Top/Bottom) | Proto-13 Caption Position selector (`zip-broadcast-external-display.html:153-156`); carried in the launch config via `OverlayConfig.position` (`top` → `OverlayPositionTop`, `bottom` → `OverlayPositionBottom`; `custom` not offerable) | `bottom` (`CaptionPosition.bottom`, `domain-entities.md`) | `output.externalDisplayCaptionPosition` (new key, new `OutputTargetSettings` field; B-8 — persisted, tested in T9) |

Where `ExternalDisplayControls` renders: Settings > Output Targets (the
existing `OutputTargetsPanel` card at `output_targets_panel.dart:90-95`,
replacing the Phase 1 `settingsCaptionOverlay` switch with the full Proto-13
section) **and** the recording screen's status bar area, because S-20's flow
starts from the broadcaster actively captioning. Rendering it in two hosts is
the existing pattern (`OutputTargetsPanel` is shared by Home and Settings).
The shell owns the window; the controls own only settings writes.

**D-3 record.** The window frame is the selected display's **work area** —
`visiblePosition` + `visibleSize` — applied with `setFrame` (ID-5). Native
full-screen (covering the taskbar/menu bar) is a **Backlog** item
(`aidlc-docs/aidlc-state.md`), not a configuration option.

---

## Build footprint

| Item | Effect |
|---|---|
| New dependency | `screen_retriever: ^0.2.2` only, with its SECURITY-10 comment in `pubspec.yaml` (record: `../functional-design/screen-retriever-security-10.md`). `window_manager` is **not** added (D-13). |
| Lockfile change | Exactly `screen_retriever` + its four federated entries (`screen_retriever_platform_interface`, `screen_retriever_macos`, `screen_retriever_windows`, `screen_retriever_linux`) in the root `pubspec.lock`, plus the `screen_retriever` pod entries in `packages/zip_broadcast/macos/Podfile.lock` that `flutter build macos` adds at Code Generation Part 2. **Anything else that moves is reported, not committed silently** (run configuration A5). |
| New native code in repo | Three runner files, one callback each (ID-5 table): `macos/Runner/MainFlutterWindow.swift`, `windows/runner/flutter_window.cpp`, `linux/runner/my_application.cc`. No CMake, manifest, Podfile, or entitlement edits. |
| CI | The existing `build-verify.yml` matrix compiles the Windows and Linux runners after the push and **must be green**; the web leg compiles the stub path (ID-3); `flutter build macos --debug` runs at Code Generation Part 2 (compile only, nothing launched). No workflow change. |
| Tests | No native stack, no display hardware: fakes only (`MockDesktopWindowService`, `FakeDisplayEnumerator`, `fakeAsync`), same as every prior overlay test. Placement, borderless rendering, hot-plug, OS-close, and sub-engine font rendering are **Unit 9 manual checks**, recorded, not claimed. |
| Server | none |

## Security Baseline compliance

Consistent with the Stage 1-3 verdicts (7 Compliant, 8 N/A, 0 non-compliant);
the infrastructure additions below are the ID-specific evidence.

| Rule | Status | Note |
|---|---|---|
| SECURITY-01 (Encryption at rest/transit) | N/A | No new store; persistence is existing settings keys (two existing, one new) via the Phase 1 mechanism — opaque display id and UI preferences, no transcript data. No network in this unit. |
| SECURITY-02 (Access logging on intermediaries) | N/A | No route, gateway, or network intermediary. No backend, no network at all. |
| SECURITY-03 (Application-level logging) | Compliant | The native callbacks log nothing (they set a style; there is no failure path that carries user data). All Dart-side logging is the existing `logging` package, fixed strings plus error type, never caption text (BR-U8-18; NFR Design S1/S2). |
| SECURITY-04 (HTTP security headers) | N/A this unit | No HTML-serving endpoint. Web is excluded by `DesktopWindowService.isSupported` (BR-U8-11); the web scaffold and its headers remain deferred to Phase 5. |
| SECURITY-05 (Input validation) | Compliant | The untrusted-input boundary is the versioned codec (BR-U8-24, B-7) plus the three-argument launch contract (ID-1) — both total-on-error. The native callbacks accept only values computed by the Dart side (no input parsing in the runner). |
| SECURITY-06 (Least privilege) | N/A | No IAM policy, role, or database privilege. |
| SECURITY-07 (Network configuration) | N/A | No network configuration of any kind. |
| SECURITY-08 (Application-level access control) | Compliant (BR-U8-14) | Signed-out-only by design; no auth read in the main or sub engine (ID-1); no new auth call path. |
| SECURITY-09 (Hardening) | Compliant | Failures surface only as fixed `ExternalDisplayStatus` variants with fixed copy; no exception message, stack trace, or platform detail reaches the UI; the switch starts off at launch (D-6); the window has no chrome (ID-5: borderless, no app UI) so there is no in-window control to abuse. |
| SECURITY-10 (Supply chain) | Compliant | Exactly one new dependency, pinned `^0.2.2`, single-file import fence (ID-3), lockfile change fenced to the five `screen_retriever*` entries (Build footprint); `window_manager` removed (D-13). |
| SECURITY-11 (Secure design, rate limiting) | Compliant | No public-facing endpoint. Misuse designed out: pre-ready messages are never sent (ID-4, which removes the `ChannelBuffers` eviction as a false close signal); a second concurrent open is structurally refused (BR-U8-01); a lost display closes and releases (BR-U8-22); oversized payloads are rejected by the size guard (BR-U8-24). |
| SECURITY-12 (Auth/credential management) | N/A | Manages no credential. |
| SECURITY-13 (Data integrity) | N/A | No persisted table beyond the three settings keys; the wire shape is versioned (`v`) and the decode is total, so an engine mismatch degrades to `OpenFailed`, never a partial render. |
| SECURITY-14 (Alerting/monitoring) | N/A | Standing project-wide Backlog item as every prior unit; no new security-relevant event. |
| SECURITY-15 (Exception handling/fail-safe defaults) | Compliant | Every window call goes through the one `_windowCall` seam (code `'-1'` → `WindowClosed`; anything else fixed-string + ignored, ID-4); the ready timeout is the catch-all for a dead or stuck sub-engine (fail-closed to `Failed`/`Off`); every release step is caught individually with the terminal transition last (NFR Design R1). |

No blocking security findings.

## PBT compliance

Consistent with the Stage 1-3 verdicts (10 Compliant/planned, 0 N/A). The
infrastructure facts that pin the PBT work:

| Rule | Status | Note |
|---|---|---|
| PBT-01 (Property identification) | Compliant | FP-1..FP-5 in FD `business-rules.md`; the frame-conversion property (FP-3) is now anchored to a named, pure, single-location function (ID-5 / NFR Design P5). |
| PBT-02 (Round-trip) | Compliant (planned) | FP-1: snapshot/launch codec round-trip. |
| PBT-03 (Invariant) | Compliant (planned) | FP-2 (total-on-error), FP-4 (`resolveOpenDisplay`), FP-5 (state-machine closure, `fakeAsync`). |
| PBT-04 (Idempotence) | Compliant (planned) | Close/release idempotence inside FP-5's sequences and once directly. |
| PBT-05 (Oracle) | Compliant (planned) | FP-3 verifies `toPlatformFrame` against the B-1/B-2 reference rules (the review comment is the oracle); the pure-function shape (platform inputs as arguments) is what makes the oracle checkable without platform code. |
| PBT-06 (Stateful) | Compliant (planned) | FP-5: the T1-T17 machine on the real controller over fakes, checked after every command. |
| PBT-07 (Generator quality) | Compliant (planned) | Domain generators per NFR Design Q9, including logical frames + platform inputs for FP-3. |
| PBT-08 (Shrinking/reproducibility) | Compliant, with a recorded limit | In-tree shim, fixed seeds 0..99, no shrinking — hand-reduced counterexamples pinned as example tests. |
| PBT-09 (Framework selection) | Compliant | The in-tree `test/helpers/pbt.dart` shim; no framework package added. |
| PBT-10 (Complementary testing) | Compliant (planned) | The named example cases that pin the platform facts: the macOS negative-Cocoa-y flip, Windows at 1.5x, the mixed-DPI setup, the three close paths, the `overlayReady` timeout, the `'-1'`-vs-ignored discrimination. |

No blocking PBT findings.

## Handoff to Code Generation

`handoff-summary.md` (same directory) carries the ID-specific capture: the
resource names, the configuration keys, the exact runner files and hooks, the
platform-channel names, and the build constraints that affect generated code.
The Stage 5 plan must be a strict transcription of this revised design (the
Stage 5 gate), with the superseded plan's `window_manager` files (T15,
`desktop_window_decorator`) and in-unit pop-out files removed.
