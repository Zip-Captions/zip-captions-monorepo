# Infrastructure Design Plan — Unit 8: External Display (S-20)

**Unit**: 8 — External Display
**Prior stage**: NFR Design, complete 2026-10-20 (unattended run; approved by the run configuration, subject to morning review)
**Package**: `zip_broadcast` (one new dependency, `screen_retriever`; `window_manager` **removed** per D-13)
**Branch**: `feature/external-display` (PR #37 open)
**Run mode**: unattended overnight. A gate that needs a human answer but whose answer is derivable from the specs is recorded as an assumption and carried; a gate whose answer is genuinely unsettled stops that stage and the question goes to the ledger.

**Revised 2026-10-20.** This is the Infrastructure Design **re-run** (Stage 4 of the
revised run) required by the PR #37 review comment (2026-10-19,
<https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308>,
decisions D-1..D-13, required changes B-1..B-9) and the follow-up A7 comment
(6282213636). It rewrites the PROPOSED `infrastructure-design.md` (ID-1..ID-7,
committed in `cbb9c79`) in place. Every plugin claim below was re-verified
against the cached package sources on 2026-10-20 — the same method the review
used to find the defects it lists. No open question remains: the review comment
closes every known question, and each `[Answer]:` below cites its source.

## Context: what "infrastructure" means for this unit

This unit has **no cloud, self-hosted, or shared infrastructure**. There is no
backend (the run configuration does not start the Supabase stack), no server,
no deployment environment beyond the desktop apps themselves. The generic
AI-DLC Infrastructure Design categories evaluate as follows, with the
justification the stage rule requires:

| Category | Applicability | Justification |
|---|---|---|
| Deployment Environment | **The runners are the deployment surface** | The unit ships hand-written native code into three desktop runners (macOS Swift, Windows C++, Linux C++). The runner files and hooks are the infrastructure decision — ID-5 names them. |
| Compute Infrastructure | N/A | No compute service, no container, no VM. The apps run on the broadcaster's machine. |
| Storage Infrastructure | N/A | No new store. Persistence is two existing `SharedPreferences` keys plus one new settings key, through the Phase 1 mechanism (FD `domain-entities.md`; NFR Requirements Q6). |
| Messaging Infrastructure | N/A as a service; **decisive as a mechanism** | The only message path is the local `desktop_multi_window` platform channel (two named channels, ID-1/ID-2/ID-4). Its buffering semantics in `dart:ui` `ChannelBuffers` drove the B-5 redesign — ID-4. |
| Networking Infrastructure | N/A | No network in this unit (NFR Requirements Q7: `screen_retriever` and `desktop_multi_window` are both local plugins; the window boundary is a local platform channel). |
| Monitoring Infrastructure | N/A | No metrics/alerting surface; logging is the existing `logging` package with fixed strings (BR-U8-18; NFR Design S1/S2). |
| Shared Infrastructure | N/A | No multi-tenancy or shared service. The one shared artifact is the root `pubspec.lock`, fenced to the `screen_retriever` entries (run configuration A5). |

**Artifact shape.** The stage rule file lists a
`deployment-architecture.md`, but the precedent units in this repo (Unit 3
Broadcast Identity + Signaling, Unit 4 Coturn — both Phase 2) each shipped a
single `infrastructure-design.md` plus `handoff-summary.md`, with no
`deployment-architecture.md`, and this unit has no deployment topology to
diagram. **This re-run follows that precedent:** one revised
`infrastructure-design.md` plus `handoff-summary.md`.

## Planned Steps

- [ ] Q1: the three runner files/hooks the window-created callbacks land in
- [ ] Q2: the sub-engine plugin registration list (B-4)
- [ ] Q3: the frame-conversion placement and shape (B-1/B-2)
- [ ] Q4: close detection and the startup race (B-5/D-9)
- [ ] Q5: window styling scope — borderless vs always-on-top (D-2)
- [ ] Q6: build footprint and lockfile fence
- [ ] Q7: the ID-3 deprecation-hazard correction (review §5)
- [ ] Rewrite `aidlc-docs/construction/external-display/infrastructure-design/infrastructure-design.md` (ID-1..ID-7, build footprint, Security Baseline and PBT compliance sections)
- [ ] Write `aidlc-docs/construction/external-display/infrastructure-design/handoff-summary.md`

## Q1: Where do the window-created callbacks land in the three runners?

Settled by D-2 + B-3, verified against the 0.2.1 plugin source and the plugin's
own example runners (the precedent the plugin itself documents):

- **macOS** — `packages/zip_broadcast/macos/Runner/MainFlutterWindow.swift`, in
  `awakeFromNib` (which already does `RegisterGeneratedPlugins`): call
  `FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in ... }`
  (public static, `FlutterMultiWindowPlugin.swift:28-30`; the callback fires at
  `FlutterWindow.swift:81` **after** `window.contentViewController =
  flutterViewController` at `:75`, so `controller.view.window` is the sub-window
  — A7 item 3 settled this; no `didBecomeKey`/order-on-screen observer). The
  callback body: register the sub-engine's plugins (Q2) and apply the borderless
  `styleMask`. Precedent: the plugin's own example does exactly this in its
  `MainFlutterWindow.swift`.
- **Windows** — `packages/zip_broadcast/windows/runner/flutter_window.cpp`, in
  `OnCreate` (after `RegisterPlugins`, before `SetChildContent`): call
  `DesktopMultiWindowSetWindowCreatedCallback([](void *controller) { ... })`
  (exported at `windows/include/desktop_multi_window/desktop_multi_window_plugin.h:20-21`;
  fired at the plugin's `windows/flutter_window.cc:116-117` **after** the view is
  `SetParent`'d at `:108`, so
  `GetAncestor(reinterpret_cast<flutter::FlutterViewController*>(controller)->view()->GetNativeWindow(), GA_ROOT)`
  yields the top-level `HWND`). Precedent: the plugin's own example
  `flutter_window.cpp:32`.
- **Linux** — `packages/zip_broadcast/linux/runner/my_application.cc`, in
  `my_application_activate` (before the main window is shown): call
  `desktop_multi_window_plugin_set_window_created_callback([](FlPluginRegistry* registry) { ... })`
  (exported at `linux/include/desktop_multi_window/desktop_multi_window_plugin.h:24-27`;
  fired at the plugin's `linux/flutter_window.cc:52-53` with the `FlView` already
  added at `:48-50`, so `gtk_widget_get_toplevel` yields the `GtkWindow`).
  Precedent: the plugin's own example `my_application.cc`.

No CMake, manifest, Podfile, or entitlement change is needed for the callbacks:
the plugin is already in all three generated plugin registrants (verified:
`macos/Flutter/GeneratedPluginRegistrant.swift:9`,
`windows/flutter/generated_plugins.cmake:7`,
`linux/flutter/generated_plugin_registrant.cc:9-20`).

[Answer]: the three files above, at the three hooks above; each callback body = (a) register the Q2 plugin list (empty today, Q2) and (b) apply the ID-5 borderless mechanism for that platform. Source: D-2, B-3, A7 item 3, verified 0.2.1 source.

## Q2: Which plugins does the sub-engine get (B-4)?

B-4: sub-engines get only the plugins registered in the window-created callback
(the plugin's own example runners demonstrate the pattern), and the overlay's
code path touches `google_fonts` (via `path_provider`), "expected".

**Verified against the locked dependency set (2026-10-20), the list is empty:**

- `CaptionDisplayWidget` (zip_core, `lib/src/widgets/caption_display_widget.dart:72`)
  calls `GoogleFonts.getFont`.
- `google_fonts` 6.3.3 (root `pubspec.lock`; transitive via `zip_core`) is a
  **pure Dart package** — its `pubspec.yaml` has no `plugin:` section and the
  package ships no native directories. Its only platform touch is reading system
  font files via `path_provider`'s `getApplicationSupportDirectory()`
  (`lib/src/file_io_desktop_and_mobile.dart:52`).
- The locked `path_provider` federated implementations are all **Dart-only PDM
  plugins** (`dartPluginClass`, FFI; no method channel, no native code):
  `path_provider_foundation` 2.6.0, `path_provider_windows` 2.3.0,
  `path_provider_linux` 2.2.1 (each `pubspec.yaml` declares `dartPluginClass` and
  no native platform entry; no `MethodChannel` anywhere in `lib/`).

So the window-created callback registers **nothing** for the locked set, and the
sub-engine needs no registrar wiring for fonts or paths. The callback is still
installed in all three runners because D-2's borderless mechanism lives there,
and it is the documented place to register a plugin should a future dependency
add native code to the overlay's path. B-4's own instruction — "Confirm by
running the overlay on macOS" — remains a **Unit 9 manual check** (font
rendering in the sub-window), recorded as such, not claimed. This is a
fact-check against B-4's "expected", not a deviation from it: B-4 prescribes
registering *exactly* what the code path touches, and the locked code path
touches no native plugin.

Also fixed by B-4: `overlayWindowMain` mirrors
`GoogleFonts.config.allowRuntimeFetching = false` (main engine: `main.dart:32`)
because the overlay's code path does call `GoogleFonts.getFont` — the old
ID-1's "nothing in the overlay fetches fonts" row is wrong.

[Answer]: empty registration list for the locked dependency set (verified against the 0.2.2/6.3.3/2.x sources in the pub cache); the callback still exists in all three runners for D-2 borderless; macOS font rendering is a Unit 9 manual check. Source: B-4, locked `pubspec.lock`, pub cache sources.

## Q3: Where does the frame conversion live, and what is its shape? (B-1/B-2)

Settled by B-1/B-2 and restated by NFR Design P5 — no open choice:

- `DisplayInfo.bounds` stays **top-left and logical everywhere** (the
  enumerator emits it; the FD owns the model).
- The macOS (`cocoaY = primaryFullHeight − top − height`, primary height from
  `getPrimaryDisplay().size`) and Windows (multiply every edge by the target
  display's `scaleFactor`, 0/missing → 1) conversions live in **one pure
  function inside the io window adapter**:
  `toPlatformFrame(Rect frame, TargetPlatform target, {double?
  primaryFullHeight, double? displayScaleFactor}) → Rect` in
  `desktop_multi_window_service_io.dart` (NFR Design P5's exact signature — the
  only file that may see platform-specific coordinate reasoning).
- Why the conversion is needed at all, verified: `desktop_multi_window`'s
  `setFrame` does **no** coordinate work — macOS builds `NSRect(x: left, y: top,
  …)` and calls `NSWindow.setFrame` (Cocoa bottom-left;
  `FlutterMultiWindowPlugin.swift:54-63` + `FlutterWindow.swift:35-37`);
  Windows calls `MoveWindow` with raw values
  (`windows/base_flutter_window.cc:61-69`) under the `PerMonitorV2` manifest
  (verified in this repo: `windows/runner/runner.exe.manifest:5`), so they are
  physical; Linux `gtk_window_move`/`gtk_window_resize` share the GDK workarea's
  coordinate space with `screen_retriever`'s output, so identity.
- Unit-tested with macOS-shaped, Windows-at-1.5x and mixed-DPI cases (FP-3 /
  PBT-10 named examples).
- `DesktopWindowService` gains `setFrame(int id, Rect frame)` and `show(int id)`
  (B-6), conversion inside the io implementation; open order
  `createWindow` → `setFrame` → `show` (the plugin never shows on create —
  verified all three: macOS `MultiWindowManager.create` `:18-27` returns the id
  without `show()`; Windows constructor ends in `ShowWindow(hwnd, SW_HIDE)`
  (`flutter_window.cc:121`); Linux ends in `gtk_widget_hide`
  (`flutter_window.cc:63`)).

[Answer]: as stated. Source: B-1, B-2, B-6, NFR Design P5, verified 0.2.1/0.2.2 source.

## Q4: Close detection and the startup race? (B-5/D-9)

Settled by B-5/D-9 — the ping probe and D10 are removed; the contract is the
ready handshake plus the error code. Every file:line below verified 2026-10-20:

- **Why `MissingPluginException` was an unreliable close signal:** until the
  sub-engine calls `DesktopMultiWindow.setMethodHandler`, messages to it sit in
  the sub-engine's `dart:ui` `ChannelBuffers` with `kDefaultBufferSize = 1`
  (Flutter 3.41.7 `engine/src/flutter/lib/ui/channel_buffers.dart:319`). Each
  newer message evicts the older, and the evicted one is answered with an empty
  (null) reply (`_dropOverflowMessages`, `:160-168`); a null reply to a typed
  `MethodChannel.invokeMethod` surfaces as `MissingPluginException`
  (`packages/flutter/lib/src/services/platform_channel.dart:351-364`). So a
  window opened during captioning would have been torn down by its own first
  captions. Additionally, on macOS/Windows a pre-handler call never completes at
  all (the handler-not-set paths drop the reply: macOS
  `macos/Classes/WindowChannel.swift:38-46`, Windows
  `windows/window_channel.cc:24-27`), and on Linux it fails with a `'-1'`
  "window channel no handler" error (`linux/window_channel.cc:49-58`).
- **Contract:** (1) the overlay sends `overlayReady` to window `0` right after
  installing its handler; (2) the main engine holds the latest snapshot and
  sends nothing until ready; (3) no ready within `overlayReadyTimeout`
  (named const, 10 s, NFR Design P3) → `OpenFailed(ready_timeout)`; (4) after
  ready, only `PlatformException` with code `'-1'` means `WindowClosed` — the
  same code on all three managers: macOS
  `macos/Classes/MultiWindowManager.swift:37`, Windows
  `windows/multi_window_manager.cc:158` (and `:163` for the channel-missing
  variant), Linux `linux/multi_window_manager.cc:83` (and `:88`); anything else
  is logged as a fixed string and ignored; (5) the main engine has exactly one
  owner of `DesktopMultiWindow.setMethodHandler`, installed before the first
  `createWindow` (NFR Design: the installer const lives in
  `desktop_multi_window_service_io.dart`; `null` uninstalls; uninstalled only in
  `dispose()`).

[Answer]: as stated. Source: B-5, D-9, NFR Design Q3/Q4/Q7, verified 0.2.1 source + Flutter 3.41.7 SDK source.

## Q5: Window styling scope — borderless vs always-on-top? (D-2)

Settled by D-2 and the review's §3: **borderless comes from
`desktop_multi_window`'s window-created callback in all three runners** — no
new dependency, no plugin patch. The per-platform mechanisms (D-2/B-3,
verified):

- **macOS** — set the borderless `styleMask` on the sub-window's `NSWindow`
  (the created mask is
  `[.miniaturizable, .closable, .resizable, .titled, .fullSizeContentView]`,
  `FlutterWindow.swift:68-70`). "Borderless applied on macOS" is a **Unit 9
  manual check**, recorded as such.
- **Windows** — change `GWL_STYLE` (remove
  `WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU`)
  and call `SetWindowPos(..., SWP_FRAMECHANGED)` on the top-level `HWND`.
- **Linux** — `gtk_window_set_decorated(GTK_WINDOW(window), FALSE)`.

**Always-on-top is not a Unit 8 requirement** — dropped. The old ID-5's
always-on-top section (and its `window_manager` analysis) is removed in full
(D-13); the pop-out unit owns its own topmost behaviour (forward note only).
`window_manager` appears nowhere in the revised design.

[Answer]: as stated. Source: D-2, review §3, verified 0.2.1 source.

## Q6: Build footprint and lockfile fence

Settled by the run configuration (A5 scope fence) and the FD SECURITY-10
record (`screen-retriever-security-10.md`, corrected at Stage 1: 16 releases,
`^0.2.2` pin, SDK-floor analysis for why 0.3.0 is excluded):

- The lockfile change is **exactly** `screen_retriever` + its four federated
  entries (`screen_retriever_platform_interface`, `screen_retriever_macos`,
  `screen_retriever_windows`, `screen_retriever_linux`) in the root
  `pubspec.lock`, plus the `screen_retriever` pod entries in
  `packages/zip_broadcast/macos/Podfile.lock` that `flutter build macos` adds
  at Stage 6. Anything else that moves is **reported, not committed silently**.
- No `Podfile` edit by hand; no `Info.plist`/entitlements change (the plugin
  sub-windows inherit the app's sandbox); no Windows manifest or CMake change
  beyond the `flutter_window.cpp` callback (Q1); no Linux CMake change beyond
  the `my_application.cc` callback.
- CI: the existing `build-verify.yml` compiles the Windows and Linux runners
  after the push and **must be green**; `flutter build macos --debug` runs at
  Stage 6 (compile only).

[Answer]: as stated. Source: run configuration A5, FD SECURITY-10 record, CI workflow.

## Q7: What happens to ID-3's deprecation-hazard paragraph? (review §5)

Settled by direct source check: `ScreenRetriever.instance` is **not**
deprecated in 0.2.2 — `screen_retriever/lib/src/screen_retriever.dart:9`
declares `static final ScreenRetriever instance = ScreenRetriever._();` with no
`@Deprecated` annotation (Stage 1 already corrected the SECURITY-10 record
accordingly). The old ID-3's mitigation paragraph ("if 0.2.2's resolution
carries a deprecation annotation…") is therefore **N/A under the `^0.2.2` pin**
and is replaced by a one-sentence statement of that fact, so the revised ID
carries no resolver-time gamble.

[Answer]: as stated. Source: review §5, `screen_retriever-0.2.2` source.

## Open questions

None. The PR #37 review comment and the A7 follow-up close every known
question; every `[Answer]:` above cites its source. If the rewrite surfaces a
genuinely new question, the stage stops as BLOCKED per the run rules.

## Approval

No human is present. Per the run rules (D-11/A2), this stage's artifacts stand
as written, pre-approved by the run configuration; the PR #37 review comment is
the approving input for every D/B item. Subject to morning review.
