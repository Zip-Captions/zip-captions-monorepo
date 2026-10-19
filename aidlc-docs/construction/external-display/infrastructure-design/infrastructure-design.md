# Infrastructure Design — Unit 8: External Display (S-20)

Scope: the secondary-window entry point, the desktop platform window
configuration, and the Phase 1 overlay precedent this unit finishes. Functional
design is `../functional-design/`; this document decides *where* and *with what
platform configuration*, not *what* the feature does.

No server-side or Supabase change. `screen_retriever` is a client plugin; its
record is `../functional-design/screen-retriever-security-10.md`.

---

## ID-1: Secondary-window entry point in `main.dart`

`desktop_multi_window` starts each sub-window as a **fresh Flutter engine running
the app's `main()` with three engine-level launch arguments**. Verified against
the 0.2.1 plugin source in the local pub cache, all three platforms:

| Platform | Evidence |
|---|---|
| macOS | `FlutterWindow.swift`: `project.dartEntrypointArguments = ["multi_window", "\(windowId)", arguments]` |
| Linux | `flutter_window.cc:45`: `const char *entrypoint_args[] = {"multi_window", g_strdup_printf("%ld", id_), args.c_str(), nullptr};` |
| Windows | the same three-argument contract (plugin README, "the arguments of `main` method is a fixed length list") |

Every sub-engine therefore calls `main(args)` with
`args[0] == 'multi_window'`, `args[1] == windowId`, `args[2] == arguments`.

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
`lib/src/output/overlay/overlay_window_entry.dart`, platform-neutral, and returns
before any broadcast startup. What it **must not** do, each for a concrete
reason:

| Not done | Why |
|---|---|
| `Supabase.initialize` | The window has no auth need (BR-U8-14); a second Supabase client in a sub-engine opens a second realtime socket and a second GoTrue refresh loop for a window whose whole purpose is captions |
| `_initLogging()` | The root logger listener is process-wide per engine; duplicating it is harmless but unnecessary, and the overlay's own logging is one `Logger` with fixed strings |
| `GoogleFonts.config.allowRuntimeFetching = false` | Nothing in the overlay fetches fonts; the snapshot carries the settings and the fonts are resolved by `CaptionDisplayWidget` from the app's asset bundle, which the sub-engine shares |
| Blocking startup on a window controller call | The window already exists when `main` runs; blocking on `setFrame` before `runApp` delays the first frame for no gain |

The launch detection is the plugin's own contract, so it is written against the
argument list, not against a platform check:

```dart
bool isOverlayWindowLaunch(List<String> args) =>
    args.length >= 3 && args.first == 'multi_window';
```

Malformed sub-window launch (two arguments, or an undecodable third) is handled
by `overlayWindowMain` per BR-U8-19 (fixed failure frame), never by falling
through into the broadcast startup.

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

Inside `OverlayWindowApp.initState`:

```dart
DesktopMultiWindow.setMethodHandler(_handleWindowCall);
```

| Method | Argument | Handler | Bad input |
|---|---|---|---|
| `captionUpdate` | `String` (JSON `CaptionOverlaySnapshot`) | decode → update the snapshot notifier → return `null` | decode failure: log `caption_update_ignored`, return `null` |
| `ping` | `null` | return `'ok'` | always succeeds |
| anything else | any | return `null` | no throw |

`DesktopMultiWindow` is an io-only import. The import lives in the same
conditional-export pair the shipped `desktop_multi_window_service.dart` already
uses (`_io` / `_stub`), so the widget test build on the host never touches it
and the web build compiles with the stub. The exact split: a thin
`OverlayWindowBridge` interface (`void listen(void Function(String method,
Object? args) onCall)` and `void send(Object? args)`), implemented by
`DesktopMultiWindowBridge` in `_io.dart` and by a no-op `_stub.dart`.

**`popOutToggle` from the pop-out (UX-PIP-02).** The in-window toggle calls
`DesktopMultiWindow.invokeMethod(0, 'popOutToggle', null)`. The main engine's
`main.dart` is not the right place for that handler (it has no providers); the
handler is installed by `ZbAppShell`'s state in `initState` and removed in
`dispose`, through the same bridge. Window id 0 is the main window by the
plugin's documented contract ("0 means the main window", `WindowController`).
This is the only inbound message the main engine accepts, and its argument is
always `null`.

---

## ID-3: `DisplayEnumerator` binding and the plugin import fence

Two files, mirroring the shipped `DesktopWindowService` split exactly:

| File | Content |
|---|---|
| `display_enumerator.dart` | the abstract interface + `DisplayInfo` re-export (platform-neutral) |
| `screen_retriever_display_enumerator.dart` (web-safe factory default) / `_io.dart` (real) / `_stub.dart` (unsupported) | factory: `DisplayEnumerator createDisplayEnumerator()`, selected by `if (dart.library.io)` — the same `if` the shipped stub already uses |

`_io.dart` is the **only** file that imports `package:screen_retriever/...`
(SECURITY-10 §5). `_stub.dart` returns an enumerator that reports no displays and
an empty closed stream, which is what the web build needs and never reaches
(F-8.9 step 1 short-circuits on `isSupported` first).

`ScreenRetrieverDisplayEnumerator`:

- `displays()` → `ScreenRetriever.instance.getAllDisplays()` mapped to
  `DisplayInfo`, preserving platform order.
- `changes` → a `StreamController<List<DisplayInfo>>.broadcast` fed by the
  plugin's `displayChangedNotifier` listener, started on the first Dart listener
  and stopped on the last (or on `dispose()`), plus the first list replayed to
  every new listener (`domain-entities.md` event contract).
- Map `Display.id`, `name`, `visiblePosition` + `visibleSize` → `bounds`,
  `scaleFactor`. `visiblePosition`/`visibleSize` are the work-area-aware
  rectangle; `size` alone can be larger than the visible region on a display
  with a taskbar. This is a deliberate choice: the overlay is a caption surface,
  not a wallpaper, and covering a taskbar is not its job.
- `scaleFactor` is passed through for description only.
- Errors from the plugin call: log a fixed string, do not forward.

**Deprecation surface.** `ScreenRetriever.instance` is the 0.2.x accessor. If
0.2.2's resolution carries a deprecation annotation, the analyzer with
`--fatal-infos` fails (the project has a zero-info rule). Mitigation inside the
one permitted file: use the non-deprecated constructor of
`ScreenRetrieverPlatform.instance` if 0.2.2 exposes one; otherwise this is a
Resolver-time finding and the fallback is to pin the exact 0.2.x that has no
annotation. Decided at verification time in Code Generation Part 2, not guessed
here.

---

## ID-4: Close detection and the presence probe

`desktop_multi_window` 0.2.1 exposes no window-close callback to Dart on any
platform. The platform-side facts, verified in the cached plugin source:

| Platform | What happens on an OS close | Reachable from Dart? |
|---|---|---|
| macOS | `FlutterWindow.windowWillClose` / `windowShouldClose` call `WindowManagerDelegate.onClose(windowId)`, which only removes the id from `MultiWindowManager.windows` (`MultiWindowManager.swift:118-127`). Nothing is sent to the main engine. | no |
| Windows | the plugin's `MultiWindowPlugin` destroys the sub-window (`multi_window_plugin_internal`); no message channel to the main engine. | no |
| Linux | `flutter_window.cc` closes the GTK window and drops the engine. | no |

So F-8.6 path C needs a detection mechanism of our own. **Decision: a probe on
the event channel, not polling and not a second public channel.**

1. Every call to `DesktopMultiWindow.invokeMethod(id, method, args)` goes to
   `mixin.one/flutter_multi_window_channel` and is routed by the platform plugin
   to the *target* engine's `WindowChannel`. If that engine is gone,
   `MultiWindowManager` in 0.2.1 fails the lookup and the call completes with a
   `FlutterError` / `PlatformException` on the caller's future (the plugin's
   `let window = windows[windowId]` guard).
2. The main engine already sends `captionUpdate` on every caption. A thrown
   `captionUpdate` is therefore a liveness signal with no extra traffic, and the
   controller converts it to `WindowClosed` (F-8.6 path C). This covers the
   "user closed it while captioning continued" case at the next caption.
3. For the idle case (closed, no caption flowing), the controller sends one
   `ping` — the same channel, a method the sub-engine handles with a constant
   `'ok'` — on two occasions only: `popOutToggle` handling, and the next time the
   user opens the controls or toggles anything for that mode. There is no timer
   and no periodic probe. The result is that a close while idle is reflected the
   next time the user interacts with the feature.
4. After `WindowClosed` the controller closes the id and stops calling it.

**Linux timing.** The `captionUpdate` path is naturally delayed until a caption
exists, and by then the sub-engine's handler is installed (the engine is
created synchronously in `flutter_window.cc` but the Dart entrypoint's
`runApp` is asynchronous), so no immediate probe is attempted. This is the one
platform-specific timing detail; it is recorded here rather than hidden in code.

**What is not claimed.** A close that happens while idle and that the user never
acts on afterwards is not noticed until the next interaction. §8.8 item 16
("closing by the OS close button leaves the main window coherent") is therefore
met on the next observable event, and §8.8 itself routes item 16 to manual
verification. Recorded as a limitation in the PR body.

---

## ID-5: Platform window configuration

### What `desktop_multi_window` gives us, verified

| Property | macOS | Windows | Linux |
|---|---|---|---|
| Window exists, separate engine | yes | yes | yes |
| `setFrame` | yes | yes | yes |
| Resizable by default | yes (`styleMask` includes `.resizable`) | yes (`WS_THICKFRAME`) | yes |
| Title bar | present (titled + `fullSizeContentView`, title hidden, transparent) | present | present |
| Always on top | **no API** | **no API** | **no API** |
| Close callback to Dart | **no** | **no** | **no** |

"Always on top" and "borderless" are the two things S-20 wants that the plugin
does not expose. Both are runner-level configuration.

### Always-on-top (OQ-1 resolution)

The binding decision says desktop uses a native always-on-top secondary window.
The plugin creates the `NSWindow` / `HWND` / `GtkWindow`; the application can
still adjust it. Implementation choice per platform, with a hard
"no new dependency" constraint:

| Platform | Mechanism | Dependency | Verdict |
|---|---|---|---|
| macOS | In `MainFlutterWindow.swift`, obtain the sub-window through `NSApplication.shared.windows` matched by the window id the plugin passes in the entrypoint (`args[1]`), set `window.level = .floating`. | none | Implement. This is the project's own runner code, small and reviewable. |
| Windows | In `windows/runner`, the existing `FlutterWindow`/`Win32Window` wrapper owns the `HWND`. A sub-window is not created through this wrapper, so the same match-by-title-or-id approach is not available without the plugin's handle. The supported route is `SetWindowPos(hwnd, HWND_TOPMOST, ...)`, but the handle is only reachable from the plugin's native side. Without patching the plugin, the portable option is to skip. | none | **Defer**, recorded. Not attempted by patching a vendored plugin. |
| Linux | GTK window hints (`gtk_window_set_keep_above`) are not exposed; the same handle-inaccessibility applies. Any portable route is a new plugin (e.g. `window_manager`), which is a new dependency under FR-9.5. | would be new | **Do not add.** OQ-1 stands. |

`pip-ux-parity.md` §8.8 itself assigns item 15 (always-on-top) to Unit 9
platform verification. The consequence of this table: macOS ships with it, the
external-display path relies on the window manager's own behaviour for full-screen
placement (a maximised/full-display window is above ordinary windows on all
three platforms without any hint), and the **pop-out's** defining property on
Windows/Linux is not delivered by this unit. That is a launchable gap, it is
recorded as an open question, and it does not block the external-display ACs
(S-20 does not require always-on-top; only §8.8 item 15 does, for the pop-out).

### Borderless

S-20 says "a borderless caption window". The plugins on all three platforms
create a titled window; there is no API to remove the title bar, and
`setTitle`/`setFrame` do not change the style mask. The honest reading, and the
one this unit implements:

- The window carries **no app chrome**: no AppBar, no drawer, no nav, no
  settings, no toolbar. It is the caption surface, edge to edge, on the
  selected display's full bounds.
- The platform title bar remains as the window manager draws it, because removing
  it needs the same native handle access as always-on-top. On macOS it is a
  transparent, title-hidden bar over the content (`fullSizeContentView`), so the
  visual result is effectively borderless; on Windows and Linux it is a thin
  title bar.

Recorded as a limitation and in the PR body. It is not silently reinterpreted as
"frameless" where the platform does not deliver frameless.

### macOS additionally

`Info.plist`/entitlements need no change: the plugin's sub-windows inherit the
app's sandbox and the `com.apple.security.network.server` entitlement the app
already has. `screen_retriever`'s macOS code links only frameworks the runner
already links (`AppKit`), so no `Podfile` change is expected; if `pod install`
adds a line, that is a build-system side effect to report, not to hand-edit.

### Windows / Linux additionally

No manifest, CMake or `my_application.cc` change for the same reason: the plugin
registers itself (`desktop_multi_window_plugin_register_with_registrar`, already
generated into `flutter/generated_plugin_registrant`). A `SetWindowPos` patch is
the only thing that would need a runner edit (ID-5, deferred).

---

## ID-6: The Phase 1 overlay precedent this unit completes

Phase 1 shipped these and nothing else (verified by reading the files):

| Shipped | Finding | This unit |
|---|---|---|
| `CaptionOverlayTarget` with `show`,`hide`,`onCaptionEvent`,`isVisible`,`targetId='caption_overlay'` | No caller of `show()` | Called from the controller (F-8.3) |
| `DesktopWindowService` + io/stub `DesktopMultiWindowService` | `isSupported` = macOS/Windows/Linux; no display, no frame | Unchanged interface; controller adds `setFrame` via `WindowController` |
| `OverlayConfig(targetDisplayId, position, opacity)` | `targetDisplayId` never populated by anything | Replaced by `mode` (`domain-entities.md`) |
| `MainAxisAlignment` `{text,isFinal}` caption payload | Built, sent, and **never received**: no entry point, no handler | Replaced by `CaptionOverlaySnapshot`; `OverlayWindowEntry` receives it |
| `overlayEnabled` persisted + registered by `ZbAppShell._syncOverlay` | Registering a target that never shows anything | Kept; now performs its stated job |
| `macos/Runner` | No sub-window configuration | `MainFlutterWindow.swift` gains the floating-level adjustment for sub-windows (ID-5) |
| Test: `caption_overlay_target_test.dart` (10 cases) | Tests `show/hide/create/invoke` against a mock | Extended: display resolution, snapshot encoding, disconnect re-frame, close invariant |

The precedent this unit follows, stated once: *the Phase 1 output target stays
the single `CaptionOutputTarget` for this surface; every new type is a
collaborator of it or of the shell, never a parallel target.* That is the same
shape Phase 1 used for `BrowserSourceTarget` and OBS.

---

## ID-7: Configuration surface (what a user can set, and where it lives)

| Setting | Where | Default | Persistence |
|---|---|---|---|
| External display output | Proto-13 toggle in `ExternalDisplayControls` (rendered on the recording screen and in Settings > Output Targets) | off | `output.overlayEnabled` (existing key) |
| Selected display | row tap in `ExternalDisplayControls` | primary | `output.externalDisplayId` (new) |
| Pop-out open | app-chrome and in-surface toggle | closed | `output.popOutEnabled` (new; never auto-open, BR-U8-16) |
| Pop-out content | `PipContent` three-way (original/translated/both) | original | `output.pipContent` (new) |

Where `ExternalDisplayControls` renders: Settings > Output Targets (the existing
`OutputTargetsPanel` card, replacing the Phase 1 `settingsCaptionOverlay`
switch with the full Proto-13 section) **and** the recording screen's status
bar area, because S-20's flow starts from the broadcaster actively captioning.
Rendering it in two hosts is the existing pattern (`OutputTargetsPanel` is
shared by Home and Settings). The shell owns the window; the controls own only
settings writes.

---

## Runtime and build footprint

| Item | Effect |
|---|---|
| New dependency | `screen_retriever: ^0.2.2`, plus its four federated sub-packages in `pubspec.lock` |
| New native code in repo | one macOS runner adjustment (`MainFlutterWindow.swift`); no Windows/Linux native edit |
| CI | The existing `build-verify.yml` matrix runs `flutter build` for macOS/Windows/Linux/web; the web leg compiles the stub path (ID-3). No workflow change. |
| Tests | No native stack, no display hardware: fakes only, same as every prior overlay test |
| Server | none |

## Handoff to Code Generation

The plan (Stage 3, Part 1) must list, at minimum: the two model files, the
enumerator trio, the controller, the bridge trio, the entry point, the window
app, the controls widget, the pop-out toggle and hint, the settings additions,
the shell wiring, the macOS runner change, the dependency addition, and one test
file per unit listed in `business-rules.md`'s flow map. The macOS runner change
is the only change outside `lib/` and `test/`.