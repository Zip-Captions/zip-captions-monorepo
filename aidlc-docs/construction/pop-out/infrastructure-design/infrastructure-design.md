# Infrastructure Design — Unit 8.1: Pop-out Live Captions (S-21)

**Status**: APPROVED by the run configuration (`.agent/overnight-pipeline.md`, 2026-10-21), subject to morning review.
**Branch**: `feature/popout-live-captions`
**Prior stages**: Functional Design, NFR Requirements and NFR Design, all APPROVED 2026-10-21 by James Petersen.
**Plan**: `aidlc-docs/construction/plans/pop-out-infrastructure-design-plan.md`

Scope: the six desktop runners (two apps x three platforms), the two first-party platform channels they implement, the `zip_captions` entry routing, the dependency graph and the generated-file movement. This document decides **where the native code goes, what it does, and which plugin reaches which engine**. It does not re-derive the feature, the state machine or the test plan; those are binding from the prior stages.

Every plugin claim below is against package source, never documentation:

- `desktop_multi_window` 0.2.1 — `~/.pub-cache/hosted/pub.dev/desktop_multi_window-0.2.1/`
- `screen_retriever` 0.2.2 with `screen_retriever_platform_interface`, `_macos`, `_windows`, `_linux` 0.2.2
- Flutter SDK: local 3.41.7 (`/opt/homebrew/share/flutter`, `bin/cache/flutter.version.json`); CI pins 3.38.7 (`.github/workflows/build-verify.yml:27`)

The local copies used for reading were staged read-only under `/var/folders/.../T/opencode/id-src/`, byte-identical to the pub cache (the working tree was not modified; `git status --short` shows only the standing ` M opencode.json`).

---

## 1. Component -> infrastructure map

| Logical component (NFR Design) | Infrastructure it needs | Where this document fixes it |
|---|---|---|
| `OverlayWindowHost` + `overlayWindowHost` provider | One Dart provider; no native artefact | Nothing new. Lives in `zip_core`, main engine only. |
| `SubWindowClosedChannel` (`_io`/`_stub`) | A `MethodChannel` on the **main** engine's messenger, plus a native emitter in every runner | ID-2b (registration), ID-3 (native emit, per platform) |
| `WindowConfigurator` (`_io`/`_stub`) | A `MethodChannel` on the **sub-engine's** messenger, plus a native handler in every runner | ID-2a (handler), ID-3 (native apply, per platform) |
| `OverlayMethodRouter` | The plugin's existing `setMethodHandler` slot | Unchanged from Unit 8; one owner per engine (BR-U8.1-04) |
| `DisplayEnumerator` / `ScreenRetrieverDisplayEnumerator` | `screen_retriever` 0.2.2 must be in `zip_core`'s dependency graph and therefore in each app's build | ID-5 (dependency graph), ID-4 (registrants) |
| `runZipCaptions` bootstrap seam | Dart only; the ordering is the infrastructure constraint | ID-1 |
| Runner `configure` + close handlers | Six native files, no new source files | ID-2, ID-3 |
| `desktop_multi_window` | One dependency in `zip_core` + `zip_captions`, already in `zip_broadcast` | ID-5 |

No server-side, Supabase, container or CI change in this unit. CI already builds both apps on all three desktops (PR #40), which is what compiles the Windows and Linux runners; that is the only verification they get (A7 items 7-8 of the Unit 9 list).

---

## 2. The verify-not-assume list, settled (NFR Design handoff items 1-6)

The NFR Design handoff (lines 41-51) and `nfr-design-patterns.md` §7 carry six claims. Each is answered below from source. **None contradicts a design premise except item 4, where the handoff pre-decided the outcome** (A1): the Linux notification **is** connectable, so the `'-1'` degradation is **not** triggered.

### 2.1 Item 1 — A Dart message from the sub-engine at close time is lost: **CONFIRMED**

The plugin tears its own close path apart before any Dart code could run, and each backend destroys the engine inside the same handler that would have been the only chance to emit:

| Platform | Evidence |
|---|---|
| macOS | `windowWillClose` → `delegate?.onClose(windowId:)` (`macos/Classes/FlutterWindow.swift:103-105`) → `MultiWindowManager.onClose` → `windows.removeValue(forKey:)` (`macos/Classes/MultiWindowManager.swift:123-125`). Removal drops the last `windows` reference; `deinit` then runs `window.contentViewController = nil` and `flutterViewController.engine.shutDownEngine()` (`FlutterWindow.swift:91-99`). |
| Windows | `WM_CLOSE` → `callback->OnWindowClose(id_)` (`windows/flutter_window.cc:174-179`), then `DefWindowProc` continues the default close, which posts `WM_DESTROY`; `WM_DESTROY` → `Destroy()` → `flutter_controller_ = nullptr` (`windows/flutter_window.cc:164-173`, `:213-224`). The view controller destructor shuts the engine down. |
| Linux | `"destroy"` → `callback->OnWindowClose(id_)` then `OnWindowDestroy(id_)` (`linux/flutter_window.cc:35-41`) → `windows_.erase(id)` (`linux/multi_window_manager.cc:149-151`), which destroys the `FlutterWindow` and its `FlView`/`FlDartProject`. |

Two independent reasons make a sub-engine Dart message useless even before teardown:

1. **The receiving side is a MethodChannel call, and the caller is the dying process' own engine.** A message sent at that instant races the engine shutdown it is issued from; the plugin offers no ordering guarantee (no flush hook on any backend).
2. **Delivery to the main engine requires the plugin's window channel, which a runner cannot use** — it is plugin-internal (`macos/Classes/WindowChannel.swift:14` — `class WindowChannel`, not `public`) and Windows/Linux expose only `include/desktop_multi_window/desktop_multi_window_plugin.h`. There is no public emit path at all, which is why the design uses a first-party channel (RQ-3 A as amended).

**Consequence**: the close event must be raised natively, in the runner's native close hook, addressed to the **main engine's** messenger (ID-2b, ID-3). This is the premise RQ-3's amendment rests on, and it holds.

### 2.2 Item 2 — macOS: where the close notification is delivered relative to `deinit`: **before deinit, from a `willClose` notification**

`window.delegate = self` is assigned in `FlutterWindow.init` (`macos/Classes/FlutterWindow.swift:85`) and the class implements `windowWillClose` / `windowShouldClose` (`:102-110`). That delegate is the only path to `onClose` → `removeValue` → `deinit`. Therefore:

```
NSWindow closing
  -> NSWindow.willCloseNotification  (AppKit posts it as the close begins)
       -> FlutterWindow.windowWillClose  -> FlutterWindow's delegate  -> windows.removeValue
       -> *our observer on the same notification*     <- runs here, same notification pass
  -> window released -> FlutterWindow.deinit -> engine.shutDownEngine()
```

An `NSNotificationCenter` observer registered with `addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil, using:)` is called during the same notification delivery as the window's delegate method. AppKit posts `NSWindowWillCloseNotification` **before** the window is released, and `deinit` only runs after the last reference to the `FlutterWindow` goes — which happens in the delegate's `onClose` handler (`MultiWindowManager.swift:123-125`), i.e. **after** all observers of that notification have run (a delegate callback cannot deallocate the observer's `object` mid-post; AppKit holds the `window` for the duration of the post).

**Consequence**: the observer is a reliable place to emit `subWindowClosed`, and it does not displace `desktop_multi_window`'s delegate (R-B2) because a notification observer is additive. The observer must be removed when the window goes away, which is naturally scoped: it is registered per created window, and its token is dropped when the runner's weak map entry is cleared.

**Scope note**: the observer fires for `NSWindow.willCloseNotification` on the window object it was registered for, so the id comes from the per-runner map (ID-3a) keyed by that exact `NSWindow` — no guessing.

### 2.3 Item 3 — Windows: the window-proc delegate's ordering against `HandleTopLevelWindowProc`: **the delegate sees the message first**

The sub-window's window class is registered by the plugin with its own `WndProc` (`windows/flutter_window.cc:25-42`, `:83`, `:132-145`), and that proc does:

```
LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT message, ...) {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);   // :150-151
    if (result) return *result;                                                        // :152-154
  }
  ...
  case WM_CLOSE: callback->OnWindowClose(id_); break;                                  // :174-179
```

`FlutterViewController::HandleTopLevelWindowProc` on Windows runs every delegate registered with `PluginRegistrarWindows::RegisterTopLevelWindowProcDelegate` **before** returning, and returns a value only if a delegate returned one. So a delegate registered on the **sub-engine's** `PluginRegistrarWindows` sees `WM_CLOSE` before the plugin's own `WM_CLOSE` branch, and before `WM_DESTROY` tears the engine down.

How the runner obtains that registrar: the window-created callback receives `void*` which is the plugin's `flutter::FlutterViewController*` (`windows/include/desktop_multi_window/desktop_multi_window_plugin.h:20`, invoked with `flutter_controller_.get()` at `windows/flutter_window.cc:116-117`). From it, `controller->engine()->GetRegistrarForPlugin("…")` is the plugin's own idiom (`windows/flutter_window.cc:111-114`).

**Evidence limitation, stated not hidden**: `flutter_windows.h` (the header declaring `RegisterTopLevelWindowProcDelegate` and `flutter::PluginRegistrarWindows`) is not present on this macOS host and is not published on `api.flutter.dev`; the evidence for the delegate API is the plugin's own call site (`windows/flutter_window.cc:150-153`), the `GetRegistrarForPlugin` idiom at `:111-114`, and the fact that the class is used as `PluginRegistrarWindows` in the plugin's own Windows sources (`windows/desktop_multi_window_plugin.cpp:4-5`, `:30-44`). **CI compilation is the check** (`build-verify.yml` builds `zip_broadcast` and `zip_captions` on Windows). This is A7's "runner code is compile-verified only" accepted limitation, recorded rather than claimed.

### 2.4 Item 4 — Linux: `delete-event` vs `"destroy"`, given the plugin's `TRUE`-returning handler: **`"destroy"`; the `'-1'` degradation is NOT triggered**

The plugin connects two handlers at construction, in this order (`linux/flutter_window.cc:34-41`):

```c
g_signal_connect(G_OBJECT(window_), "delete-event", G_CALLBACK(on_close_clicked), NULL);   // :34
g_signal_connect(window_, "destroy", G_CALLBACK(+[](GtkWidget*, gpointer arg) { ... }), this); // :35-41
```

and `on_close_clicked` is:

```c
gboolean on_close_clicked(GtkWidget *widget, GdkEvent *event, gpointer user_data) {
    gtk_widget_destroy(widget);
    return TRUE;                       // :18-21
}
```

`TRUE` from a `delete-event` handler **stops emission of the signal** — GTK does not call the remaining handlers connected to `delete-event`, and it does not run the default handler. So:

- **`delete-event` connected with `g_signal_connect` after the plugin's handler never runs** on the title-bar close path.
- **`g_signal_connect_after` on `delete-event` also never runs**, because `_after` handlers are still part of the same signal emission, which `TRUE` aborted. (This corrects FD BLM §3.2's earlier "connect with `g_signal_connect_after`" suggestion, which the FD itself flagged as needing ID's decision.)
- **`"destroy"` is a different signal, and it runs on every destroy path**: the title-bar close (`on_close_clicked` → `gtk_widget_destroy`), an app-initiated `closeWindow(id)` (`MultiWindowManager::Close` → `FlutterWindow::Close`, the plugin's own `gtk_widget_destroy` path), and any WM-initiated destruction. The plugin's own `"destroy"` handler is proof that the signal reaches a connected callback at the moment the window dies (`linux/flutter_window.cc:35-41`).

**Therefore a notification IS connectable on Linux** — with `g_signal_connect(window, "destroy", …)`, which is what the plugin itself does. A1 item 4's condition ("if no notification is connectable, Linux degrades to the `'-1'` fallback") is **false**, so:

- Linux emits `subWindowClosed` like the other two platforms;
- `'-1'` remains **only** the generic fallback it already is for every mode (FD BLM §3.2, BR-PIP-03), and the design is unaffected;
- **Unit 9 manual check 4** ("or via the `'-1'` fallback on Linux **if** Infrastructure Design recorded the degradation") is recorded as: **degradation not recorded**, so the Linux expectation is the same-frame close, subject to the same WM caveats as §8.8 item 15.

**Ordering caveat, recorded**: our `"destroy"` handler runs in the same emission as the plugin's own (`:35-41`), in connection order — the plugin's first, ours second. By the time ours runs, the plugin has already called `OnWindowClose`/`OnWindowDestroy` (`multi_window_manager.cc:146-151` → `windows_.erase(id)`), so the plugin's `FlutterWindow` is being destroyed. Our handler must therefore **not** touch the plugin's object graph; it reads only our own map (`GTK_WINDOW` → `windowId`) and sends on our own channel. Both are independent of the plugin's lifetime. This is why the map (ID-3c) is keyed by the `GtkWindow*` and not by the plugin's window id.

### 2.5 Item 5 — The six runners' callback signatures against the 0.2.1 headers, and `argv` delivery: **verified**

**Signatures (0.2.1 headers, authoritative):**

| Platform | Declared type | Evidence |
|---|---|---|
| macOS | `public typealias OnWindowCreatedCallback = (FlutterViewController) -> Void`; `setOnWindowCreatedCallback(_:)` | `macos/Classes/FlutterMultiWindowPlugin.swift:25-30`; invoked `onWindowCreatedCallback?(flutterViewController)` at `macos/Classes/FlutterWindow.swift:81` |
| Windows | `typedef void (*WindowCreatedCallback)(void *flutter_view_controller);` | `windows/include/desktop_multi_window/desktop_multi_window_plugin.h:20`; invoked `_g_window_created_callback(flutter_controller_.get())` at `windows/flutter_window.cc:116-117` — a `flutter::FlutterViewController*` |
| Linux | `typedef void (*WindowCreatedCallback)(FlPluginRegistry *registry);` | `linux/include/desktop_multi_window/desktop_multi_window_plugin.h:24`; invoked `_g_window_created_callback(FL_PLUGIN_REGISTRY(fl_view))` at `linux/flutter_window.cc:52-53` — the **sub-window's** registry |

**Against the repo (PR #40 fixed R-B4 on `develop`; `d522c4c` is the merge):**

| Runner | Today | Verdict |
|---|---|---|
| `zip_broadcast/macos/Runner/MainFlutterWindow.swift:17-20` | `FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in … }` | signature correct; body is the unconditional borderless strip that Unit 8.1 replaces |
| `zip_broadcast/windows/runner/flutter_window.cpp:32-46` | `DesktopMultiWindowSetWindowCreatedCallback([](void* controller) { … })` | one argument (PR #40), correct |
| `zip_broadcast/linux/runner/my_application.cc:81-91` | `desktop_multi_window_plugin_set_window_created_callback([](FlPluginRegistry* registry) { … })` | one argument (PR #40), correct |
| `zip_captions/macos/Runner/MainFlutterWindow.swift` | **no callback** | gains one (ID-2a) |
| `zip_captions/windows/runner/flutter_window.cpp` | **no callback** | gains one (ID-2a) |
| `zip_captions/linux/runner/my_application.cc` | **no callback** | gains one (ID-2a) |

**`argv` delivery to the sub-engine entry:** verified on all three, and it is the shape `isOverlayWindowLaunch` already assumes (`args.length >= 3 && args.first == 'multi_window'`).

| Platform | Evidence |
|---|---|
| macOS | `project.dartEntrypointArguments = ["multi_window", "\(windowId)", arguments]` — `macos/Classes/FlutterWindow.swift:73` |
| Windows | `project.set_dart_entrypoint_arguments({"multi_window", std::to_string(id), std::move(args)})` — `windows/flutter_window.cc:100` |
| Linux | `const char *entrypoint_args[] = {"multi_window", g_strdup_printf("%ld", id_), args.c_str(), nullptr}; fl_dart_project_set_dart_entrypoint_arguments(project, …)` — `linux/flutter_window.cc:45-46` |

`args[1]` is the window id as a string on all three; `args[2]` is the encoded launch. The sub-engine reads the id from `args[1]`, which is why `configure`'s `windowId` argument is trustworthy for the close tag (NFR Design L1) and why the native side needs no `argv` access of its own (ID-3).

### 2.6 Item 6 — Which Flutter SDK: **3.41.7 local, 3.38.7 CI; every API used exists in both**

- Local: `flutter --version` → `3.41.7` (framework `cc0734ac71`, Dart `3.11.5`); `/opt/homebrew/share/flutter/bin/cache/flutter.version.json` agrees.
- CI: `.github/workflows/build-verify.yml:27` → `FLUTTER_VERSION: "3.38.7"`, used by every job (`:47`, `:78`, `:113`, `:153`, `:188`).

APIs this unit uses, and their availability in both:

| API | Source (local SDK) | Both versions? |
|---|---|---|
| `MethodChannel(name)`, `invokeMethod<T>`, `setMethodCallHandler` | `packages/flutter/lib/src/services/platform_channel.dart:292`, `:587` | Yes — present since Flutter 1.x; neither 3.38 nor 3.41 deprecates any of them (no `@Deprecated` on the class or the three members). |
| `MethodCall(method, [arguments])` | `packages/flutter/lib/src/services/message_codec.dart:35` | Yes |
| `WidgetsFlutterBinding.ensureInitialized()` | long-standing; used today by `zip_captions/lib/main.dart:31` and `zip_broadcast/lib/main.dart:30` | Yes |
| `runApp(Widget)` | long-standing; used today | Yes |
| `Ref.onDispose`, `Provider`, `keepAlive` (Riverpod 2.x, already locked) | not an SDK API; the lockfile pins Riverpod and does not change | Yes — `flutter pub get` unchanged by this unit's design |
| `process.platform` / `Platform.isMacOS` etc. (used by existing code, not new here) | `dart:io` | Yes |

One platform-symbol caveat, recorded: the Windows embedding symbols (`HandleTopLevelWindowProc`, `RegisterTopLevelWindowProcDelegate`, `flutter::PluginRegistrarWindows`) live in `flutter_windows.h`, which is generated per build target and is **not** on this macOS host. Their availability in 3.41.7 is evidenced by the plugin compiling against them (`desktop_multi_window-0.2.1/windows/desktop_multi_window_plugin.cpp:4-5`, `windows/flutter_window.cc:150-153`); their availability in 3.38.7 follows from the same plugin version being resolved by both apps under the pinned SDK in CI, and is **verified by CI compilation, not locally**. No other native symbol this unit introduces is absent from either SDK: `NSNotificationCenter`, `NSWindow`, `PluginRegistrarWindows::RegisterTopLevelWindowProcDelegate`, `g_signal_connect`, `gtk_window_set_keep_above`, `gtk_window_set_decorated`, `gtk_window_set_resizable`, `gtk_widget_set_size_request`, `SetWindowPos`, `GetWindowLongPtr`/`SetWindowLongPtr`, `WM_GETMINMAXINFO` are all OS APIs or Flutter-plugin-API symbols that have existed since long before 3.38.

**Design consequence of item 6**: the Dart side of this unit must not use anything newer than 3.38's API surface. The only SDK-adjacent API the design could have used is `MethodChannel.setMethodCallHandler` plus `OptionalMethodChannel`; both are in 3.38. Nothing in the approved design reaches past that.

---

## 3. The native close-id map (per runner)

The FD establishes the constraint (BLM §3.2): *"The sub-engine passes the window id it was launched with (`args[1]`), because the native callback cannot know it otherwise (the plugin's `WindowCreatedCallback` receives only the view controller/registry)"*. Verified: the macOS callback receives a `FlutterViewController`, Windows a `void*` controller, Linux an `FlPluginRegistry` — **none carries the window id**, and `argv` is not exposed by any callback. By the same constraint, the **close** hook cannot know the id either.

Therefore each runner keeps a per-run map from the **native window handle** to the **`windowId`**, populated when `configure` arrives (the first moment the id is known natively) and read at close:

| Platform | Map key | Populated in | Read in |
|---|---|---|---|
| macOS | `NSWindow` (`ObjectIdentifier(window)`) | the `configure` handler, using the window the channel was created for (`controller.view.window`) | the `NSWindow.willCloseNotification` observer, using `window` from the notification |
| Windows | `HWND` (top-level, `GetAncestor(view, GA_ROOT)`) | the `configure` handler, same window | the window-proc delegate's `WM_CLOSE` branch, using `hwnd` |
| Linux | `GtkWidget*`/`GtkWindow*` (toplevel) | the `configure` handler, same window | the `"destroy"` handler, using the widget being destroyed |

Properties that make the map safe:

- **One entry per window per process.** A sub-engine hosts exactly one window, but the map is process-global like the plugin's own callback (`_g_window_created_callback`), so it is keyed by handle rather than by a singleton slot.
- **Written once, before any close is possible**: `configure` is awaited before `overlayReady` (FD BLM §3.2 step 6), and the controller only calls `close()`/reaches the window after `Open`. A close that arrives before `configure` therefore has no id — the runner then emits nothing, and `'-1'` covers it. This is the same fallback the design already names, and it is unreachable in practice.
- **Rejected alternative**: deriving the id from the plugin's order of creation (`g_next_id_`) or from `getAllSubWindowIds()`. Both are plugin-internal/racy (`MultiWindowManager` is a private singleton per platform), and neither survives a Dart-initiated close followed by a fresh open.
- **Rejected alternative**: sending the id from Dart at close time. That is exactly the message item 1 shows is lost.

Entries are removed when the close fires (or, on macOS, when the notification token is torn down), so the map never outlives its window.

---

## 4. The per-runner code

### 4a. Sub-engine: `zip_core/overlay_window_configure` handler

Registered **inside the existing window-created callback**, on the sub-engine's own registrar/messenger. One channel name for both apps (NFR Design L5). The handler validates allowlist-by-type and answers a fixed error on rejection (`nfr-design-patterns.md` §3.1).

Common shape (macOS shown; the others differ only in the registrar call and the apply body):

```
// inside the window-created callback, before/around the existing styling
let channel = FlutterMethodChannel(
  name: "zip_core/overlay_window_configure",
  binaryMessenger: controller.registrar(forPlugin: "ZipCoreOverlayWindow").messenger)
channel.setMethodCallHandler { call, result in
  guard call.method == "configure" else { result(FlutterMethodNotImplemented); return }
  guard let args = call.arguments as? [String: Any],
        let windowId = args["windowId"] as? Int, windowId >= 0,
        let floating = args["floating"] as? Bool,
        let decorated = args["decorated"] as? Bool,
        let minWidth = args["minWidth"] as? Double, minWidth.isFinite, minWidth >= 0,
        let minHeight = args["minHeight"] as? Double, minHeight.isFinite, minHeight >= 0
  else { result(FlutterError(code: "configure_invalid", message: nil, details: nil)); return }
  guard let window = controller.view.window else {
    result(FlutterError(code: "configure_invalid", message: nil, details: nil)); return
  }
  ... apply + record map entry ...
  result(nil)
}
```

**macOS apply** (all on `controller.view.window`):

| Field | Code |
|---|---|
| `floating` | `window.level = floating ? .floating : .normal` |
| `decorated` | `floating` (i.e. `decorated`) → `window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])`; else `styleMask.remove([.titled, .closable, .miniaturizable, .resizable])` |
| `minWidth`/`minHeight` | `window.contentMinSize = NSSize(width: minWidth, height: minHeight)` |
| map | `registry[ObjectIdentifier(window)] = windowId` |

- The decoration bits are the plugin's own creation mask minus what Unit 8 strips (`.titled, .closable, .miniaturizable, .resizable`; `macos/Classes/FlutterWindow.swift:68-71`), so `decorated: true` restores exactly the decoration the plugin created, and `decorated: false` reproduces Unit 8's shipped borderless window bit-for-bit.
- `titleVisibility = .hidden` and `titlebarAppearsTransparent = true` stay as the plugin set them (`:87-88`); the title bar therefore has no text, which also satisfies BR-U8.1-09.
- The `configure` handler runs **before** `overlayReady`, and the window is not shown until `show()` (the plugin never shows on create — `MultiWindowManager.swift:18-27`), so the styling is applied before the first visible frame. No flicker path, no re-layout after show.

**Windows apply** (on `HWND hwnd = GetAncestor(controller->view()->GetNativeWindow(), GA_ROOT)`):

| Field | Code |
|---|---|
| `floating` | `SetWindowPos(hwnd, HWND_TOPMOST, 0,0,0,0, SWP_NOMOVE|SWP_NOSIZE|SWP_NOACTIVATE)`; else `HWND_NOTOPMOST` |
| `decorated` | add/remove `WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU` on `GWL_STYLE`, then `SetWindowPos(hwnd, nullptr, 0,0,0,0, SWP_NOMOVE|SWP_NOSIZE|SWP_NOZORDER|SWP_FRAMECHANGED)` |
| `minWidth`/`minHeight` | stored in the runner's per-window struct; answered in the window-proc delegate's `WM_GETMINMAXINFO` branch (`ptMinTrackSize`) |
| map | `registry[hwnd] = windowId` |

The style bits are the complement of Unit 8's strip (`packages/zip_broadcast/windows/runner/flutter_window.cpp:41-42`), so `decorated: false` is byte-identical to shipped behaviour.

**Linux apply** (on `GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(FL_VIEW(registry)))`):

| Field | Code |
|---|---|
| `floating` | `gtk_window_set_keep_above(GTK_WINDOW(toplevel), floating)` |
| `decorated` | `gtk_window_set_decorated(GTK_WINDOW(toplevel), decorated)` (never `gtk_window_set_resizable(FALSE)`: the pop-out must be resizable) |
| `minWidth`/`minHeight` | `gtk_widget_set_size_request(toplevel, minWidth, minHeight)` |
| map | `registry[GTK_WINDOW(toplevel)] = windowId` |

### 4b. Main engine: `zip_core/overlay_sub_window_events` registration

Registered **once, in the main-window setup** of each runner, on the **main engine's** messenger. Emits `subWindowClosed` from the platform close hook (ID-3).

```
Darwin  (MainFlutterWindow.awakeFromNib, after RegisterGeneratedPlugins):
  let channel = FlutterMethodChannel(name: "zip_core/overlay_sub_window_events",
                                     binaryMessenger: flutterViewController.engine.binaryMessenger)
  // channel retained for the app's lifetime as a stored property on the window / runner
  // on close: channel.invokeMethod("subWindowClosed", arguments: ["windowId": id])

Windows (FlutterWindow::OnCreate, after RegisterPlugins):
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "zip_core/overlay_sub_window_events",
      &flutter::StandardMethodCodec::GetInstance());
  // retained as a member; on WM_CLOSE (delegate):
  //   channel->InvokeMethod("subWindowClosed",
  //       std::make_unique<flutter::EncodableValue>(
  //           flutter::EncodableMap{{EncodableValue("windowId"), EncodableValue(id)}}), nullptr);

Linux (my_application_activate, after fl_register_plugins):
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(fl_plugin_registry_get_registrar_for_plugin(
          FL_PLUGIN_REGISTRY(view), "zip_core_overlay")),
      "zip_core/overlay_sub_window_events", FL_METHOD_CODEC(codec));
  // retained (g_object_ref) as a static/runner-owned pointer; on "destroy":
  //   g_autoptr(FlValue) args = fl_value_new_map();
  //   fl_value_set_string_take(args, "windowId", fl_value_new_int(id));
  //   fl_method_channel_invoke_method(channel, "subWindowClosed", args, nullptr, nullptr, nullptr);
```

Notes that make the placement correct rather than merely plausible:

- **Main engine only.** The overlay-launch branch of `main` returns before any host exists (NFR Design D1 note), and the runner registers this channel on the **main** `FlutterViewController`/engine, so the sub-engine never has a listener for it. That matches FD BLM §3.2 ("nothing on the sub-engine path").
- **The main engine's messenger must exist at registration time.** On macOS `awakeFromNib` runs before `main.dart`'s `runApp`, and `flutterViewController.engine.binaryMessenger` is valid as soon as the controller is created (the generated registrant already uses `flutterViewController` there, `packages/{zip_broadcast,zip_captions}/macos/Runner/MainFlutterWindow.swift:11`). On Windows `OnCreate` is after the controller's engine is created (`flutter_controller_->engine()`, `packages/zip_broadcast/windows/runner/flutter_window.cpp:26-29`). On Linux `fl_register_plugins(FL_PLUGIN_REGISTRY(view))` has already created the engine (`packages/zip_broadcast/linux/runner/my_application.cc:78`). Registering **after** the binding exists on the Dart side is not required for a native→Dart invoke: a `MethodChannel` invoke from native is answered by whatever Dart handler is installed at delivery time, and the Dart handler is installed by `OverlayWindowHost` before any controller can create a window (NFR Design D1 corrected). A message that somehow arrived earlier would be buffered by `ChannelBuffers` (capacity 1), which is the same eviction behaviour Unit 8 documented — and it is unreachable, because no window can exist before the host is built.
- **Fire-and-forget result.** `invokeMethod`/`InvokeMethod(..., nullptr)` with a null result callback: the native side must not block the close path on a Dart reply, because the sub-engine's teardown may already be destroying the main-thread post queue's counterpart (§2.1). On Windows and macOS the call is posted to the platform task runner and answered asynchronously; Linux's `fl_method_channel_invoke_method` with a null callback is the plugin's own fire-and-forget idiom (`linux/window_channel.cc:83-96` uses a real callback because it must relay a reply; we do not).
- **No payload beyond `windowId`.** The map value is an `int`; `windowId` is never interpolated into a log line (nfr-design-patterns §3.2).
- **Validation stays on the Dart side** (`SubWindowClosedChannel._io`: method must be exactly `subWindowClosed`, argument a map with a single non-negative `int` `windowId`, else dropped silently). The native side is a boundary and sends only what this table shows.

### 4c. The per-runner close hook, concretely

**macOS** (`MainFlutterWindow.awakeFromNib`, inside the window-created callback): for each created window, register

```
NotificationCenter.default.addObserver(
  forName: NSWindow.willCloseNotification, object: window, queue: nil) { note in
    guard let w = note.object as? NSWindow,
          let id = closeIds[ObjectIdentifier(w)] else { return }
    closeIds.removeValue(forKey: ObjectIdentifier(w))
    mainChannel.invokeMethod("subWindowClosed", arguments: ["windowId": id])
}
```

Ordering relative to the plugin: the notification is posted as the close begins, the plugin's delegate runs from the same post, and our observer runs during it (§2.2). **Nothing replaces `window.delegate`** (R-B2). The observer token is stored alongside the map entry so it can be removed when the entry is cleared.

**Windows** (delegate registered on the sub-engine's registrar, from the window-created callback):

```
auto registrar = flutter::PluginRegistrarManager::GetInstance()
    ->GetRegistrar<flutter::PluginRegistrarWindows>(
        controller->engine()->GetRegistrarForPlugin("ZipCoreOverlayWindow"));
registrar->RegisterTopLevelWindowProcDelegate(
  [](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) -> std::optional<LRESULT> {
    switch (message) {
      case WM_GETMINMAXINFO:  // apply the stored minWidth/minHeight for this hwnd
      case WM_CLOSE: {        // emit before the plugin's own branch (ordering: §2.3)
        auto it = closeIds.find(hwnd);
        if (it != closeIds.end()) {
          int64_t id = it->second; closeIds.erase(it);
          mainChannel->InvokeMethod("subWindowClosed", makeWindowIdMap(id), nullptr);
        }
        return std::nullopt;  // never swallow: the plugin's own close must still run
      }
      default: return std::nullopt;
    }
  });
```

Returns `std::nullopt` in every branch so `desktop_multi_window`'s `WM_CLOSE` → `OnWindowClose` and its `WM_DESTROY` → `Destroy()` still run exactly as shipped. **Nothing replaces the plugin's `WndProc`**: the delegate is additive, which is the whole reason it is registered on the registrar rather than by subclassing.

**Linux** (`my_application_activate`, inside the window-created callback, on the sub-window's toplevel):

```
g_signal_connect(toplevel, "destroy", G_CALLBACK(+[](GtkWidget* widget, gpointer data) {
  auto* self = static_cast<RunnerCloseState*>(data);
  auto it = self->close_ids.find(GTK_WINDOW(widget));
  if (it == self->close_ids.end()) return;
  int64_t id = it->second;
  self->close_ids.erase(it);
  self->emit_sub_window_closed(id);   // fire-and-forget on the main-engine channel
}), &closeState);
```

Connected **after** the plugin's own `"destroy"` handler in connection order, but on a signal that is not aborted (§2.4), so it runs on every destroy path. It touches only `close_ids` and the main-engine channel, never the plugin's `FlutterWindow` (which is already being destroyed).

### 4d. Why `configure` must precede `overlayReady` (infrastructure reason, not restated design)

The map entry is written by `configure`. The close hook reads it. A window closed before `configure` would emit nothing. Because `overlayWindowMain` awaits `configure` (step 6) before installing the bridge (step 7) and before `OverlayWindowEntry` sends `overlayReady` (step 9), and because the main engine only calls `show()` after ready, **no window that the user can see and close has an empty map entry**. The one theoretical gap — a close between window creation and `configure` — is a window the plugin created hidden (`ShowWindow(SW_HIDE)` / `gtk_widget_hide` / `orderOut` never called) and which therefore has no close button to press. The `'-1'` fallback covers even that.

---

## 5. `zip_captions` entry routing (ID-1)

`runZipCaptions(args, {runApp, isWeb})` in `zip_captions/lib/src/bootstrap.dart` is the **authoritative** routing object. It is the NFR-R clarification answer A recorded in `audit.md` ("extract `runZipCaptions` bootstrap seam in `zip_captions` and test it") and carried at `nfr-requirements.md:28`, `nfr-requirements/handoff-summary.md:18,27` and `nfr-design/logical-components.md:47`. FD BLM §4.4's inline `if (isOverlayWindowLaunch(args))` snippet is the **body** of that function, not an alternative to it.

Two objects, in this order, and both are pinned:

```
zip_captions/lib/main.dart
  Future<void> main(List<String> args) => runZipCaptions(args);

zip_captions/lib/src/bootstrap.dart
  Future<void> runZipCaptions(List<String> args, {Future<void> Function(Widget)? runApp, bool isWeb = kIsWeb}) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (isOverlayWindowLaunch(args)) {
      await overlayWindowMain(args);
      return;                        // <-- BEFORE Supabase, SharedPreferences, logging, GoogleFonts
    }
    GoogleFonts.config.allowRuntimeFetching = false;
    _initLogging();
    final prefs = await SharedPreferences.getInstance();
    await Supabase.initialize(...);   // unchanged from main.dart:39-47
    ... existing body unchanged ...
  }
```

Pinned facts:

1. **`main` takes `List<String> args` and delegates.** `main.dart` today is `void main() async` with no args (`packages/zip_captions/lib/main.dart:30`); it gains the parameter and becomes a one-line delegate. The three runners already pass `argv` through: macOS via the plugin's `dart_entrypoint_arguments` only for **sub** engines — the **main** engine's args come from the Flutter embedding's own `main` invocation, which passes an empty list under `flutter run` and the OS argv in a release bundle. For the main window this is irrelevant to the routing decision (the predicate is false on an empty list). For the sub-engine, `argv` is `["multi_window", id, payload]` (§2.5), so the predicate is true.
2. **The overlay branch returns before** `GoogleFonts.config.allowRuntimeFetching`, `_initLogging()`, `SharedPreferences.getInstance()`, `Supabase.initialize(...)`, the `ProviderContainer`, the debug `FakeSttEngine` registration, and the transcript pre-warm (`main.dart:32-63`). Each of those is observable in a test (a recording `runApp` and a throwing/faked Supabase), which is how BR-U8.1-06 is proven.
3. **`overlayWindowMain` is `zip_core`'s** (promoted, with the `WindowConfigurator` parameter). `runZipCaptions` does not construct a `ProviderContainer`, a Supabase client or a prefs instance on the overlay path.
4. **`isWeb` is a parameter**, defaulting to `kIsWeb`, so the seam is testable without a web build. It is used only where today's body branches on `kIsWeb` (`main.dart:42`), not to gate the pop-out (BR-U8.1-11: web is excluded by `DesktopWindowService.isSupported`).
5. **`runApp` is a parameter** with the real `runApp` as its default, so the seam's test can record what was pumped without a widget binding.

`zip_broadcast` keeps its inline `main(List<String> args)` branch (`packages/zip_broadcast/lib/main.dart:29-36`): the design's seam exists for the app that has no such structure, and rewriting the app that already has it would change shipped code for no behavioural gain (BR-U8.1-01 spirit). This asymmetry is recorded, not a defect.

---

## 6. Generated-file fence: the registrants are tracked, and this is the movement

`tech-stack-decisions.md` §3 said the registrants are "Generated, not committed". **They are tracked** (`git ls-files`): each app has

```
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.{cc,h}
windows/flutter/generated_plugins.cmake
linux/flutter/generated_plugin_registrant.{cc,h}
linux/flutter/generated_plugins.cmake
```

`flutter pub get` / a build regenerates them, and the diff lands in the commit. The run configuration's A1 item 3 said to expect **no** movement in `zip_broadcast`'s copies "because the plugin graph is unchanged there". **That is factually wrong**: A5 removes `screen_retriever` from `zip_broadcast/pubspec.yaml`, and `screen_retriever` is a native plugin on all three platforms (`screen_retriever_macos/pubspec.yaml:25` → `ScreenRetrieverMacosPlugin`; `screen_retriever_windows/pubspec.yaml:25` → `ScreenRetrieverWindowsPluginCApi`; `screen_retriever_linux/pubspec.yaml:25` → `ScreenRetrieverLinuxPlugin`). So `zip_broadcast` **loses** `screen_retriever_*` from its registrants, and `zip_captions` **gains** both `desktop_multi_window` and `screen_retriever_*` (the latter arriving transitively through `zip_core`, exactly as `tech-stack-decisions.md` §1 explains).

Verified tracked state today, and the movement Code Generation must produce:

| File | Today (verified) | Expected after | Why |
|---|---|---|---|
| `zip_broadcast/macos/Flutter/GeneratedPluginRegistrant.swift` | `import screen_retriever_macos` (`:14`), `ScreenRetrieverMacosPlugin.register(...)` (`:28`) | **both lines removed** | app drops its own `screen_retriever` declaration; nothing else in its graph pulls it |
| `zip_broadcast/windows/flutter/generated_plugin_registrant.cc` | `#include <screen_retriever_windows/...>` (`:15`), register call in `RegisterPlugins` | **include + register call removed** | same |
| `zip_broadcast/windows/flutter/generated_plugins.cmake` | `screen_retriever_windows` (`:12`) | **entry removed** | same |
| `zip_broadcast/linux/flutter/generated_plugin_registrant.cc` | `#include <screen_retriever_linux/...>` (`:14`), `ScreenRetrieverLinuxPluginRegister...` block (`:34-36`) | **include + block removed** | same |
| `zip_broadcast/linux/flutter/generated_plugins.cmake` | `screen_retriever_linux` (`:11`) | **entry removed** | same |
| `zip_captions/macos/Flutter/GeneratedPluginRegistrant.swift` | no `desktop_multi_window`, no `screen_retriever` | **adds** `import desktop_multi_window` + `FlutterMultiWindowPlugin.register(...)`, and `import screen_retriever_macos` + `ScreenRetrieverMacosPlugin.register(...)` | new direct dep + new transitive dep |
| `zip_captions/windows/flutter/generated_plugin_registrant.cc` | neither present | **adds** both includes and both register calls | same |
| `zip_captions/windows/flutter/generated_plugins.cmake` | neither present (list is `app_links`, `file_selector_windows`, `flutter_secure_storage_windows`, `flutter_webrtc`, `local_auth_windows`, `permission_handler_windows`, `record_windows`, `share_plus`, `speech_to_text_windows`, `sqlite3_flutter_libs`, `url_launcher_windows`) | **adds** `desktop_multi_window` and `screen_retriever_windows` (alphabetical position, tool-determined) | same |
| `zip_captions/linux/flutter/generated_plugin_registrant.cc` | neither present | **adds** both includes and both register blocks | same |
| `zip_captions/linux/flutter/generated_plugins.cmake` | neither present (`file_selector_linux`, `flutter_secure_storage_linux`, `flutter_webrtc`, `gtk`, `record_linux`, `sqlite3_flutter_libs`, `url_launcher_linux`) | **adds** `desktop_multi_window` and `screen_retriever_linux` | same |

The `.h` registrants change only if the tool rewrites them; they hold no plugin list, so no content change is expected beyond a possible regeneration timestamp — none of them has one.

**Rules for Code Generation:**

1. These ten files are **produced by the tool** (`flutter pub get` plus any build), never hand-edited. A hand edit is a defect even if the content matches.
2. The movement **must equal the table**. Anything else — a new plugin appearing, a different plugin disappearing — is reported in the PR body, not committed silently (A5's fence rule).
3. `desktop_multi_window` is **not** removed from `zip_broadcast`'s registrant: its runners include the plugin's headers directly and the app keeps the declaration (`tech-stack-decisions.md` §1).
4. Ordering within `FLUTTER_PLUGIN_LIST` is the tool's; reviews must not "alphabetise" it.

**Also in the fence** (`tech-stack-decisions.md` §3, unchanged): `pubspec.lock` (workspace) — no movement expected, because `desktop_multi_window`, `screen_retriever` and its federated packages are already locked (verified in `.dart_tool/package_config.json`: `desktop_multi_window` 0.2.1, `screen_retriever` 0.2.2 and all four federated 0.2.2 entries are resolved); `packages/zip_broadcast/macos/Podfile.lock` — `screen_retriever_macos` **stays** (the plugin still reaches the app through `zip_core`, so the pod is still linked even though the app drops its own declaration); `packages/zip_captions/macos/Podfile.lock` — **gains** `desktop_multi_window` and `screen_retriever_macos`.

---

## 7. Dependency graph and versions (the `^0.2.1` correction)

| Package | Dependency | Change | Version (corrected) | Note |
|---|---|---|---|---|
| `zip_core` | `desktop_multi_window` | new | **`^0.2.1`** | SECURITY-10 comment required. `tech-stack-decisions.md` §1 and §6 and FD `domain-entities.md` §1.4 say `^0.2.0`; **corrected to `^0.2.1` here** per A5's constraint floor (matching PR #40's pin), logged in `audit.md`. `^0.2.1` still admits later 0.2.x; the lockfile and CI's builds protect the header contract. |
| `zip_core` | `screen_retriever` | new | `^0.2.2` | Already the pin in `zip_broadcast`; unchanged by this unit. |
| `zip_broadcast` | `desktop_multi_window` | unchanged | `^0.2.1` | PR #40's pin (`packages/zip_broadcast/pubspec.yaml:20`). |
| `zip_broadcast` | `screen_retriever` | **removed** | — | A5: `packages/zip_broadcast/pubspec.yaml:50` is deleted. The plugin still reaches the app through `zip_core` (hence the registrant movement in §6 and the `Podfile.lock` row). |
| `zip_captions` | `desktop_multi_window` | new | **`^0.2.1`** | SECURITY-10 comment required. FD `domain-entities.md` §1.4 says `^0.2.0`: corrected, logged. |
| `zip_captions` | `screen_retriever` | not declared | — | Arrives through `zip_core`; SECURITY-10 forbids unused declarations. |
| any | `window_manager` | **not added** | — | RQ-1 A. Present nowhere in the repo (verified: no `window_manager` in any pubspec or lockfile). |

Why `zip_captions` still needs its **own** `desktop_multi_window` declaration, given that `zip_core` depends on it:

- its runners include the plugin's headers directly (`windows/include/desktop_multi_window/...`, the Mac `import desktop_multi_window`, the Linux `#include <desktop_multi_window/...>`), and the declaration documents that coupling — the same argument `tech-stack-decisions.md` §1 makes for `zip_broadcast`;
- it keeps the native plugin in `zip_captions`' own registrant even if a future refactor gives `zip_core` a conditional export that stops importing the plugin on some platform (the fence is what would change first, not the app).

**No new dev dependency** (A7): `zip_captions` has neither `fake_async` nor `mocktail` (verified: `packages/zip_captions/pubspec.yaml` has no `dev_dependencies` entry for either; `flutter_test`, `build_runner`, `drift`, `riverpod_generator`, `very_good_analysis` only). Its tests are `testWidgets` + `tester.pump`; controller-timing tests live in `zip_core`. Adding a dev dependency is BLOCKED (unit exception 4), and this design requires none.

---

## 8. Swift Package Manager and CocoaPods, per app

Both apps' macOS runners use `import <plugin>` in Swift (the generated registrant), which works under either CocoaPods or SPM because the generated registrant is what `flutter build macos` emits for the resolved toolchain. Nothing in this unit changes the management choice; the `Podfile.lock` rows in §6 are what identifies CocoaPods in this repo today. The `desktop_multi_window` macOS podspec and the `screen_retriever_macos` podship declare their module names, which is why the generated registrant's `import` lines match the plugin names in §6.

**Windows and Linux**: no CMake, manifest or `Podfile` edit. Both plugins are already `pluginClass`-declared per platform and are added to the app's generated list by `flutter pub get` (§6). The runners only *call* the symbols the plugin exports (`DesktopMultiWindowSetWindowCreatedCallback`, `desktop_multi_window_plugin_set_window_created_callback`) and use the Flutter embedding API for the registrar. `zip_captions`' Windows runner currently includes only `flutter/generated_plugin_registrant.h` (`packages/zip_captions/windows/runner/flutter_window.cpp:5`); it gains `#include <desktop_multi_window/desktop_multi_window_plugin.h>`, exactly as `zip_broadcast`'s does (`packages/zip_broadcast/windows/runner/flutter_window.cpp:5`). The Linux runner gains `#include <desktop_multi_window/desktop_multi_window_plugin.h>` (`packages/zip_captions/linux/runner/my_application.cc` currently includes neither; `zip_broadcast`'s includes it at `:8`).

**macOS `zip_captions`** gains `import desktop_multi_window` in `MainFlutterWindow.swift` (currently absent; `zip_broadcast`'s has it at `:3`).

---

## 9. Registration points, per file, with the existing code they must not disturb

| File | Existing (must stay) | Added |
|---|---|---|
| `zip_broadcast/macos/Runner/MainFlutterWindow.swift` | `RegisterGeneratedPlugins(registry: flutterViewController)` (`:12`); `super.awakeFromNib()` (`:22`) | replace the unconditional `styleMask.remove` (`:17-20`) with the `configure` channel + `willClose` observer + main-engine channel; keep the callback registration itself |
| `zip_captions/macos/Runner/MainFlutterWindow.swift` | `RegisterGeneratedPlugins` (`:11`), `super.awakeFromNib()` (`:13`) | new window-created callback; `import desktop_multi_window`; main-engine close channel |
| `zip_broadcast/windows/runner/flutter_window.cpp` | `RegisterPlugins` (`:29`); `WM_FONTCHANGE` branch (`:84-88`) | replace the styling body (`:31-46`) with `configure` + delegate; main-engine channel in `OnCreate` |
| `zip_captions/windows/runner/flutter_window.cpp` | `RegisterPlugins` (`:27`); `SetChildContent` (`:28`); `WM_FONTCHANGE` branch (`:64-68`) | new window-created callback; main-engine channel; same delegate shape |
| `zip_broadcast/linux/runner/my_application.cc` | `fl_register_plugins` (`:78`); header bar setup | replace the styling body (`:80-91`) with `configure` + `"destroy"` hook; main-engine channel |
| `zip_captions/linux/runner/my_application.cc` | `fl_register_plugins` (`:76`) | new window-created callback; `"destroy"` hook; main-engine channel |

Constraints carried into these files (A5, A7, A4):

- **No `RegisterGeneratedPlugins` / `RegisterGeneratedPlugins`-equivalent inside any window-created callback** (R-B1). The callback registers exactly one named channel (`zip_core/overlay_window_configure`) via the sub-engine's registrar; if any plugin registration is ever needed there it must be a **named** plugin, never the generated all-or-nothing registrant.
- **Nothing replaces `desktop_multi_window`'s `NSWindowDelegate`** (R-B2); the macOS close hook is a notification observer, not a delegate.
- **The Linux close hook is a `"destroy"` handler**, not `delete-event` + `_after` (§2.4).
- **Both channels validate their arguments** (L5): `configure` allowlist-by-type with `FlutterError('configure_invalid')`; `subWindowClosed` on the Dart side with silent drop.
- **The runner styling bodies are not mode-blind any more.** Unit 8 stripped decoration unconditionally; Unit 8.1 moves all styling into `configure`, so the external display still gets `floating: false, decorated: false` (BR-U8.1-04, the pinned consequence) and the pop-out gets `true, true` — from the same code, chosen by Dart.
- **Runners log nothing** (no caption data, no arguments). A `configure_invalid` reply carries no field values.

---

## 10. What this stage does not change

- **No controller deviation is added.** The seven permitted deviations (FD BLM §4.1) are unchanged; this stage adds native wiring only.
- **No new Dart class beyond the planned set.** The map lives in the runner's native state, not in Dart. `WindowConfigurator` and `SubWindowClosedChannel` keep the shapes NFR Design fixed (L5 names, L5 validation).
- **The caption bus and `CaptionOutputTargetRegistry` are untouched** (NFR Design L4 B).
- **No dependency beyond §7.** No `window_manager` (RQ-1 A), no new dev dependency (A7), no CI change (PR #40's matrix already builds both apps on all three desktops).
- **The chrome-allowance constants are not touched** (P3 correction: estimates, Unit 9 measures them).

## 11. Verification this stage can and cannot do

| Claim | How it is (or will be) verified | Status here |
|---|---|---|
| Dart API and channel contracts | `dart analyze --fatal-infos` + `flutter test` in all three packages | **Run in this stage** (Step 9) — docs-only change, so they must stay green |
| macOS native code compiles | `flutter build macos --debug` | Code Generation Part 2 (A1 stage 3 gate) |
| Windows native code compiles | CI `build-verify.yml` Windows jobs for both apps | Code Generation Part 2's push, then CI |
| Linux native code compiles | CI `build-verify.yml` Linux jobs for both apps | same |
| Pop-out floats, is decorated/resizable/movable, min size honoured | Unit 9 manual checks 1-3 | **Not claimed** |
| The OS close clears the banner and toggle immediately | Unit 9 manual check 4 | **Not claimed**; degradation **not** recorded (§2.4) |
| The external display is still borderless after the `configure` move | Unit 9 manual check 5 | **Not claimed** |
| Multi-monitor placement | Unit 9 manual check 6 | **Not claimed** |
| `window.delegate` is not displaced, and no generated registrant is called from a callback | A4 review reads the runners | Review stage |

## 12. Security Baseline compliance (this stage's additions)

Inherits NFR Requirements §4.2 (8 Compliant, 6 N/A, 0 non-compliant) and NFR Design §6.1. This stage adds:

| Rule | Status | Basis |
|---|---|---|
| SECURITY-03 logging | Compliant | Both new bound-aries log fixed strings only; runner code logs nothing; `windowId` never interpolated (§4b) |
| SECURITY-05 input validation | Compliant | `configure` allowlist-by-type with range checks and a fixed `FlutterError('configure_invalid')`; `subWindowClosed` allowlist-by-shape on the Dart side, silent drop |
| SECURITY-10 supply chain | Compliant | No new third-party package: two already-vetted plugins re-declared/re-homed; `window_manager` absent; pins `^0.2.1`/`^0.2.2`; registrant fence exact (§6) |
| SECURITY-11 secure design | Compliant | One owner per engine-wide resource; the close channel is main-engine only, the configure channel is sub-engine only — two channels by direction, not by app |
| SECURITY-15 exception handling | Compliant | Native close emits are fire-and-forget (no blocking the close path); `configure` rejection is answered, never thrown into the plugin; the Dart configurator catches |
| SECURITY-01, -02, -04, -06, -07, -08, -09, -12, -13, -14 | As NFR Requirements §4.2 | No store, no network, no auth, no IAM, no new endpoint; web out of scope |

No blocking security finding. No area on `AGENTS.md`'s pre-approval list is touched.

## 13. PBT compliance

Inherits NFR Requirements §8 and NFR Design §6.2 — unchanged. This stage adds no property, because the native map and the two native hooks have no Dart surface to generate inputs for; the behaviour they enable (`onNativeWindowClosed` matching vs dropped) is already covered by the `FakeSubWindowClosedChannel` tests and POP-5's `windowGone` command.

## 14. Handoff to Code Generation, and the morning-review list

`handoff-summary.md` carries the code-generation-relevant extract: the six files and their insertion points, the two channel names and payload shapes, the per-runner map, the registrant movement, the dependency edits, the `runZipCaptions` shape, and the gates.

Items for the morning review, in addition to the run configuration's own list:

1. **`zip_broadcast`'s registrants DO move** (they lose `screen_retriever_*` on all three platforms). A1 item 3 said they would not; the reason is A5's `screen_retriever` removal from that app's pubspec. This is recorded here, in `audit.md` and in the ledger.
2. **Linux does not degrade to `'-1'`.** `"destroy"` is connectable and is the only hook that runs on every close path; `delete-event` (even with `_after`) is aborted by the plugin's `TRUE`. Unit 9 check 4 should be read as "same-frame close on Linux too", with the WM caveat.
3. **The `^0.2.0` -> `^0.2.1` correction** in three approved artifacts (FD `domain-entities.md` §1.4, `tech-stack-decisions.md` §1 and §6), applied here as a correction and logged, per A5's constraint floor.
4. **`zip_broadcast` keeps an inline `main` branch** rather than using `runZipCaptions`; only `zip_captions` gains the seam. Recorded, deliberate.
5. **Windows evidence is compile-only** and the `flutter_windows.h` symbols are evidenced by the plugin's call site, not by a local SDK header (§2.3, §2.6).