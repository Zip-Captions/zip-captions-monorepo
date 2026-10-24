# Pre-build Review — Unit 8.1 (Pop-out Live Captions, S-21)

**Date**: 2026-10-21
**Requested by**: James Petersen — "review the spec against the project and ensure the plan is
complete and reliable before I trigger the build in a separate session".
**Scope**: Read-only review. Nothing was edited except this file and its `audit.md` entry.
**Reviewed**:
- `aidlc-docs/construction/pop-out/functional-design/*` (FD, approved 2026-10-21)
- `aidlc-docs/construction/pop-out/nfr-requirements/*` (NFR-R, including §10 review decisions; not yet
  recorded as approved)
- the two pop-out plans and their two clarification files in this folder

**Checked against**:
- shipped Unit 8 code in `packages/zip_broadcast`, plus `packages/zip_core` and
  `packages/zip_captions`
- `desktop_multi_window` 0.2.1 sources in the pub cache (`~/.pub-cache/hosted/pub.dev/desktop_multi_window-0.2.1/`)
- `window_manager` 0.5.1 sources from the pub.dev archive
  (`https://pub.dev/api/archives/window_manager-0.5.1.tar.gz`; it is not in the pub cache, because no package
  depends on it yet)
- `.github/workflows/*`

**Verdict: not ready to build.** There are five blockers (R-B1..R-B5), ten major gaps (R-M1..R-M10) and
seven minor items (R-m1..R-m7). Three owner decisions (RQ-1..RQ-3, at the end) must be answered before
the FD and NFR-R can be amended. **Stage effect**: FD and NFR-R need revision. NFR Design,
Infrastructure Design and Code Generation Part 1 have not been started and must not start until
the revision is approved.

Every citation below is a file and line you can open. The next session must re-verify each finding
before acting on it, not take it on trust (`.aidlc-rule-details/common/overconfidence-prevention.md`).

---

## 1. Blockers

### R-B1 — macOS: `RegisterGeneratedPlugins` in the window-created callback hijacks window 0
**Resolution (2026-10-21)**: fixed. RQ-1 A; the callback now registers only the app's own `configure` channel. Tech-stack §2 rewritten with the corrected precedent; NFR-R §4.3's "whole plugin set" limitation withdrawn.
**Spec**: tech-stack-decisions §2 (macOS row) and NFR-R Q1 A register the whole generated plugin set
into the sub-engine from `FlutterMultiWindowPlugin.setOnWindowCreatedCallback`.
**Code fact**: The generated registrant calls `FlutterMultiWindowPlugin.register(with:)`. That
public entry runs `MultiWindowManager.shared.attachMainWindow(window: app.mainFlutterWindow, …)`
with the *sub-engine's* registrar (`desktop_multi_window-0.2.1/macos/Classes/FlutterMultiWindowPlugin.swift:11-23`).
`attachMainWindow` replaces `windows[0]` with a channel on that messenger
(`MultiWindowManager.swift:29-33`).
**Consequence**: After the first sub-window is created, every `invokeMethod(0, …)` (the pop-out's
`overlayReady` and `popOutToggle`, and the external display's `overlayReady`) is delivered back into the
sub-engine instead of the main engine. Every open ends in `ready_timeout`, and Unit 8's shipped
external display stays broken for the rest of the app's life.
**Precedent claim is wrong**: tech-stack §2 says "the plugin's own example registers generated plugins
into the created window's controller". It does not. The examples register **one named plugin** per
callback on all three platforms (`example/macos/Runner/MainFlutterWindow.swift:15-18`,
`example/windows/runner/flutter_window.cpp:32-38`, `example/linux/my_application.cc:65-69`).
**Also**: `RegisterGeneratedPlugins(registry: controller.view)` does not type-check; the registry is the
`FlutterViewController`. The reason given for rejecting Q1 B ("depends on a plugin-internal symbol") is
wrong too: `WindowManagerPlugin` is the same public symbol the generated registrant itself imports.

### R-B2 — macOS: `window_manager` replaces the pop-out window's `NSWindowDelegate`
**Resolution (2026-10-21)**: fixed. RQ-1 A removes the dependency entirely; no delegate is replaced. FD BLM §3.2 records the mechanism and the evidence.
**Spec**: FD BR-U8.1-05 and NFR-R §1.2 call `windowManager.ensureInitialized()` and then
`setAlwaysOnTop(true)` in the sub-engine.
**Code fact**: `ensureInitialized` assigns `windowManager.mainWindow = registrar.view.window`
(`window_manager-0.5.1/macos/window_manager/Sources/window_manager/WindowManagerPlugin.swift:14-18,29-38`).
The setter does `_mainWindow?.delegate = self` (`WindowManager.swift:58-65`).
`desktop_multi_window` uses its own delegate for lifecycle:
- `FlutterWindow` is the delegate (`FlutterWindow.swift:85`);
- `windowWillClose` and `windowShouldClose` call `onClose` (`:102-110`);
- `onClose` does `windows.removeValue` (`MultiWindowManager.swift:123-125`);
- removal is what lets `deinit` call `shutDownEngine()` (`FlutterWindow.swift:91-99`).

**Consequences on macOS once the delegate is replaced**:
1. An OS close never removes the window, so the main engine never gets `'-1'`. The controller stays `Open`
   and the main window's banner and toggle stay "popped out" (BR-PIP-03 broken).
2. A toggle-off `closeWindow(id)` closes the NSWindow but never removes it from `windows`. The sub-engine
   is never shut down, so one Flutter engine leaks per open/close cycle.

**This can't be worked around from Dart**: every macOS `window_manager` method force-unwraps
`_mainWindow`, so `ensureInitialized` is a precondition of the always-on-top call.

### R-B3 — "Decorated and resizable" (Q9 amended) is unachievable with the shipped runner callbacks
**Resolution (2026-10-21)**: fixed. RQ-1 A: the unconditional styling moves into each runner's `configure` handler, which knows the mode. Q9 keeps "decorated and resizable".
**Spec**: FD clarification Q9 (owner amendment), domain-entities §3.3 "Resizable … decorated normally".
Tech-stack §2 adds registration "after the shipped borderless change".
**Code fact**: The zip_broadcast callbacks strip the title bar, frame and resize handles from
**every** sub-window, with no mode check:
- `packages/zip_broadcast/macos/Runner/MainFlutterWindow.swift` (`styleMask.remove([.titled, .closable,
  .miniaturizable, .resizable])`)
- `windows/runner/flutter_window.cpp:32-45` (clears `WS_CAPTION | WS_THICKFRAME | …`)
- `linux/runner/my_application.cc:81-87` (`gtk_window_set_decorated(FALSE)`)

The callback receives only the view controller or registry. It never receives the window's launch
arguments (see the headers below and `FlutterWindow.swift:73-81`), so it can't tell a pop-out from an
external display. `window_manager` can't restore the decoration afterwards:
- macOS `setTitleBarStyle` never re-inserts `.titled` (`WindowManager.swift:379-401`);
- Windows `SetTitleBarStyle` only stores the style string (`windows/window_manager.cpp:914+`).

**Consequence**: Built as specified, the pop-out would have no title bar and no close button, and
couldn't be moved or resized.

### R-B4 — Shipped zip_broadcast Windows/Linux callbacks don't compile, and CI never builds zip_broadcast
**Resolution (2026-10-21)**: deferred by design — this is Unit 8's defect on `develop`, not a Unit 8.1 artifact change. **Still open** as remediation step 0 (own branch: fix the two callback signatures to one argument, add `zip_broadcast` build jobs to `build-verify.yml`, get CI green). FD/NFR-R now state Windows/Linux as compile-checked only.
**Code fact**:
- Windows header: `typedef void (*WindowCreatedCallback)(void *flutter_view_controller);` and
  `DesktopMultiWindowSetWindowCreatedCallback(WindowCreatedCallback callback)`, one argument
  (`desktop_multi_window-0.2.1/windows/include/desktop_multi_window/desktop_multi_window_plugin.h`).
  `packages/zip_broadcast/windows/runner/flutter_window.cpp:32-45` passes three:
  `(flutter_controller_->engine(), [](FlutterDesktopViewControllerRef, void*){…}, nullptr)`.
- Linux header: `typedef void (*WindowCreatedCallback)(FlPluginRegistry *registry);`, one argument
  (`linux/include/desktop_multi_window/desktop_multi_window_plugin.h`).
  `packages/zip_broadcast/linux/runner/my_application.cc:81-87` passes `(view, [](FlView*){…})`.
- `.github/workflows/build-verify.yml` builds `packages/zip_captions` in **every** job (`working-directory:
  packages/zip_captions`). PR #37's green Linux and Windows checks never compiled zip_broadcast.

**Consequence**: Unit 8's "Windows/Linux compile-verified by CI" claim is false. Unit 8.1's verification
plan (NFR-R §1.1 "Runners" row, tech-stack §2 "Verification") relies on the same gap. This is a
defect on `develop`, inherited by Unit 8.1.

### R-B5 — No plan to build from; the run config targets the wrong unit
**Resolution (2026-10-21)**: partially — the artifact-status and state-line items were corrected in this revision; the missing NFR Design / Infrastructure Design / CG Part 1 and the `.agent/overnight-pipeline.md` rewrite remain **open** as remediation steps 3-6.
- NFR Design, Infrastructure Design and the Code Generation Part 1 plan don't exist.
  `phase2-unit-of-work.md`'s stage table requires all three for Unit 8.1 (ID = yes).
- `.agent/overnight-pipeline.md` is still Unit 8's configuration. Its scope fence:
  - forbids any change to `zip_core` and `zip_captions`, and any `window_manager` dependency;
  - forbids `pip-ux-parity.md`;
  - pushes to `feature/external-display` and edits PR #37.

  Kicking it off would either stop as BLOCKED straight away or build in the wrong scope.
- `audit.md` records NFR Requirements as "awaiting explicit NFR Requirements approval"
  (2026-10-21T02:00Z). No approval entry follows, even though the §10 review decisions are committed
  (`6a08033`).
- The `aidlc-state.md` current-stage line still says "next stage is NFR Requirements". Every FD and NFR-R
  artifact header still reads "Draft for approval", including the FD, which is approved.

---

## 2. Major gaps (a builder would have to guess)

### R-M1 — The engine-available gate is wrong for Zip Broadcast
**Resolution (2026-10-21)**: fixed. RQ-2 A. FD `domain-entities.md` §3.1 and BR-PIP-13 rewritten to per-app providers.
FD domain-entities §3.1 and BR-PIP-13 use `sttEngineRegistryProvider.listAvailable().isEmpty`, and
say "in `zip_broadcast` the engine is registered by the STT factory provider". Nothing in
`packages/zip_broadcast/lib` registers into the registry; the app creates engines per source through
`sttEngineFactoryProvider` (`lib/src/providers/stt_engine_factory_provider.dart`). The registry is
therefore always empty in Zip Broadcast, and the toggle would always be disabled with "No speech
recognition engine". `SttEngineRegistry` is also a plain class
(`zip_core/lib/src/services/stt/stt_engine_registry.dart`), so watching it does not rebuild on
`register`/`unregister`, and the sherpa catalog unregisters at runtime. → **RQ-2**.

### R-M2 — NFR-R §10.2's reasoning that a null display id is harmless is false against the code
**Resolution (2026-10-21)**: fixed. NFR-R §10.2's reasoning withdrawn; FD BLM §2 gains the six-guard table; mode fixed at construction.
§10.2 says that leaving `_modeDisplayId` null makes the display-lost branch a no-op for the pop-out. But
`_find(null)` returns the primary or first display
(`zip_broadcast/lib/src/output/overlay/overlay_window_controller.dart:275-281`). With a null id:
- the `Open` branch reframes the pop-out to the primary's full work area on any display event (T15,
  `:225-238`), and closes it through `_handleDisplayLost` when the list is empty;
- the `Opening` branch fails the open with `display_lost` when the list is empty (`:239-243`);
- `_runReady` frames the window to the primary's bounds (`:402-411`);
- `open()` and `_runOpen` go to `NoDisplays` when the list is empty (`:309-314`, `:345-353`).

FD BLM §2's explicit `_isPopOut` guards are required on **all** of these paths. NFR Design must
adopt them and drop §10.2's reasoning.
**Single source of truth for mode**: §10.1 (`createController(mode, …)`, mode known at construction)
and FD §2 (mode read from the config at `open()`) disagree. Recommended: mode at construction.

### R-M3 — The router and installer contract can't be implemented as written
**Resolution (2026-10-21)**: fixed. FD BLM §4.1 rewritten: routing by window id, token-bound installers, provider-owned enumerator.
**Follow-up (2026-10-21, owner)**: the API still could not see the controller's private `_windowId`, and "registration after `createWindow`" contradicted the unchanged install call in `_bootstrap` (`overlay_window_controller.dart:191`). Pinned: `int? get windowId` is a permitted deviation; the installer is called at bootstrap as today; the sentence is deleted; the router dispatches only on a non-null id match, so a controller with no window receives nothing (closing the `:390` hole).
- `OverlayMethodHandler` returns `Future<void>` (`overlay_window_controller.dart:33-36`), so FD BLM §4.1's
  "stop after the first one that recognises the method" can't be implemented.
- The controller's guard `if (_windowId != null && fromWindowId != _windowId) return;` (`:390`) means a
  controller **without** a window accepts messages from any window id.
- `OverlayMethodHandlerInstaller` is `void Function(OverlayMethodHandler?)`, and `dispose()` calls it with
  `null` (`:708`). Called through one shared `router.installer` getter, that `null` can't say which
  handler to remove.
- `dispose()` calls `_enumerator.dispose()` (`:702`). With the enumerator shared (NFR-R §10.1), the first
  controller disposed kills the other controller's display feed.

NFR Design must specify:
- an installer closure bound to each controller's token;
- routing by window id, with the registration point fixed after `createWindow` returns;
- the enumerator owned by the provider, never disposed by a controller.

It must then list these changes as the permitted controller deviations under BR-U8.1-01, alongside the
§2 mode guards and the `popOutToggle` case.

### R-M4 — The in-surface toggle would be scrolled out of view
**Resolution (2026-10-21)**: fixed. FD `frontend-components.md` §2: `Column[Expanded(list), controls]`.
FD frontend-components §2 appends `controls` **inside** the `ListView`, "after the entry list". The
list renders newest first (`entries[entries.length - 1 - i]`) and auto-scrolls to offset 0
(`zip_core/lib/src/widgets/caption_display_widget.dart:47-84`), so the last item sits beyond the oldest
caption. In a two-line pop-out the toggle disappears once there are about two entries, which breaks
UX-PIP-02. With `ScrollDirection.bottomToTop` (`reverse: true`) it ends up off the top edge.
Recommended: render the controls outside the scrolling list (`Column[Expanded(list), controls]`),
which is what domain-entities §3.3's geometry ("toggle row + two lines") already assumes.

### R-M5 — The pop-out frame plumbing is undefined, and the title bar is not in the size
**Resolution (2026-10-21)**: fixed. The shell computes the frame and passes it to `open(config, frame:)`; a per-platform chrome allowance is added and documented as content-size semantics (BLM §3.4).
- `computePopOutFrame` (BLM §3.4) needs `DisplaySettings`, `TextTheme` and the text scaler. The
  controller has none of these, and `PopOutMode` has no fields. Nothing says who computes the frame or
  how it reaches `_runReady`. NFR-R §10.2's "`_openBounds` (the computed frame)" leaves the source of
  `_openBounds` unstated.
- `setFrame` sets the window's **outer** frame. On a decorated window:
  - Windows and Linux: the title bar sits inside the frame;
  - macOS: `desktop_multi_window` creates the window with `.titled, .fullSizeContentView`,
    `titleVisibility = .hidden` and `titlebarAppearsTransparent = true` (`FlutterWindow.swift:68-71,86-88`),
    so content draws under the title bar.

  Either way, "two lines + toggle row" of content gets clipped.

Recommended: the shell computes the frame (it has the build context and `controller.displays`) and
passes it to `open(config, frame:)`. The geometry adds a per-platform title-bar allowance, or the
spec states content-size semantics. This interacts with RQ-1.

### R-M6 — OS-close detection is lazy even where it works
**Resolution (2026-10-21)**: fixed. RQ-3 A as amended: native close notification to the main engine; `'-1'` remains the fallback, and `frontend-components.md` §5's "same frame" claim is now caveated.
**Follow-up (2026-10-21, owner)**: the first implementation of RQ-3 was itself wrong — it had the runner emit on `desktop_multi_window`'s window channel, which is plugin-internal, so the event could also have reached `OverlayMethodRouter`. Re-specified as a first-party channel on the **main** engine (`subWindowClosed {windowId}`) feeding `controller.onNativeWindowClosed(int)`; raised for every sub-window including the external display (a Unit 8 improvement). See BLM §3.2, BR-PIP-03, NFR-R §1.2/§3.1.
The controller learns a window is gone only when its next window call throws `'-1'` while `Open`
(`overlay_window_controller.dart:619-631`); `desktop_multi_window` 0.2.1 sends the main engine no close
event. For a decorated pop-out with a close button, the main window shows "popped out" until the next
`captionUpdate`, which may never come while paused or idle. frontend-components §5's "the banner
disappears in the same frame as the state change" is false on this path. → **RQ-3**.

### R-M7 — Exporting the overlay barrel from `zip_core.dart` is a compile error
**Resolution (2026-10-21)**: fixed. NFR-R §5.2: `package:zip_core/overlay.dart` as a separate library.
NFR-R §5.2 exports the overlay barrel, including `ExternalDisplayStatus` and its `Failed` variant, from
`zip_core.dart`. `zip_core.dart` already exports `Failed` (`ConnectionStatus`,
`zip_core/lib/src/models/connection_status.dart:74`, through `models.dart`), so every importer would get
an ambiguous-export error. The shipped code already works around the collision by aliasing
(`as display_status show Failed`, in 10 zip_broadcast files).
Recommended: a separate public library, `package:zip_core/overlay.dart`, that `zip_core.dart` does not
re-export.

### R-M8 — The open-failure copy has no place to render
**Resolution (2026-10-21)**: fixed. BR-PIP-03 + `frontend-components.md` §5: the copy renders next to the chrome toggle while `Failed`.
BR-PIP-03 and BLM §6 render `popOutOpenFailed` on `OpenFailed` ("banner"). But frontend-components §5
shows `PopOutBanner` only while `popOutEnabled && (Opening || Open)`, and the shell clears
`popOutEnabled` on `OpenFailed`. Specify where the failure text appears and when it clears, for example
next to the chrome toggle while the status is `Failed` (Unit 8's pattern).

### R-M9 — The always-on-top install point is stated two ways
**Resolution (2026-10-21)**: fixed. One statement: BLM §3.2 step 6; `OverlayWindowEntry` no longer awaits anything.
BLM §3.2 awaits `alwaysOnTop.install()` in `overlayWindowMain` (step 6) and then passes
`OverlayWindowEntry(…, alwaysOnTop: null)`. Domain-entities §1.2 and NFR-R §1.2 assertion 1 have
`OverlayWindowEntry` await it before `overlayReady`. Pick one. (This may be moot, depending on RQ-1.)

### R-M10 — The lockfile and generated-file fence is wrong
**Resolution (2026-10-21)**: fixed. Tech-stack §3 rewritten; `screen_retriever_macos` stays in `zip_broadcast`; no `window_manager_*` entries.
`window_manager` 0.5.1 is a single package, not federated. Its pubspec depends on `flutter`,
`path: ^1.8.2` and `screen_retriever: ^0.2.0`, and macOS ships one pod (`macos/window_manager.podspec`).
Tech-stack §3's `window_manager_macos` entries and the security record's "federated entries" don't
exist. zip_broadcast's `Podfile.lock` keeps `screen_retriever_macos`: the plugin still reaches the app
through `zip_core` and `window_manager`, so the row "−`screen_retriever_macos`" is wrong. As written,
the fence would make the build stop on a false "unexpected lockfile movement". (This may be moot,
depending on RQ-1.)

---

## 3. Minor

- **R-m1**: `DesktopWindowService.setBounds(…, {bool center})`
**Resolution (2026-10-21)**: fixed. `DesktopWindowService` gains nothing; `setFrame` serves both modes. duplicates `setFrame`. `center` also
  contradicts bottom-anchoring: macOS `NSWindow.center()` places the window slightly above centre, and
  `desktop_multi_window` maps `center` to it (`FlutterWindow.swift:30-32`). A `setAlwaysOnTop` that
  always throws `UnsupportedError` is dead interface surface. Recommended: add neither; use `setFrame`.
- **R-m2**: BR-PIP-01 says the window service and enumerator are "each per-controller".
**Resolution (2026-10-21)**: fixed. BR-PIP-01 corrected; the enumerator is shared and provider-owned. NFR-R §10.1 and
  BLM §4.1 say they are shared. Fix the stale sentence.
- **R-m3**: `StoppedState` also mixes in `ActiveSessionState`
**Resolution (2026-10-21)**: fixed. `domain-entities.md` §3.1 and the FD revision note require the three concrete states; the CG plan must repeat it. (`zip_core/lib/src/models/recording_state.dart:99`).
  `popOutAvailability` must test the three concrete states (Q8 A), not the mixin. Call this out in the
  CG plan.
- **R-m4**: The callback is mode-blind
**Resolution (2026-10-21)**: fixed. FD BLM §3.2 and BR-U8.1-05 state that the callback is mode-blind and the mode is decided by the Dart-side `configure` call., so anything registered there also lands in the external-display
  sub-engine. Record this against Unit 8's ID-1 "empty plugin list" invariant instead of claiming the
  invariant is intact.
- **R-m5**: `window-manager-security-10.md` still reads "approved for `zip_broadcast`"
**Resolution (2026-10-21)**: fixed. The record is retired in place with the reversal and its evidence; tech-spec §6's row removed., and §5 says
  "never by `zip_core`". Both contradict the approved placement (NFR-R Q2 A: `zip_core` only). Revise it,
  or retire it, depending on RQ-1.
- **R-m6**: CI pins Flutter 3.38.7
**Resolution (2026-10-21)**: recorded. FD revision note lists it as a verify-in-Infrastructure-Design item. (`build-verify.yml`), but Unit 8's ID cites Flutter 3.41.7 SDK sources.
  Confirm which SDK the ID claims were checked against.
- **R-m7**: Zip Captions' `ViewerScreen` also renders `CaptionDisplayWidget`
**Resolution (2026-10-21)**: recorded. FD scope note: viewer pop-out is out of scope for S-21.. The pop-out is gated on
  recording state only, and viewer captions don't flow through the caption bus. Record "viewer pop-out
  out of scope for S-21", or raise it.

## 3a. Re-verification (2026-10-21, second session)

Every finding was re-derived from source before any amendment. Sources: the repo at `6a08033`, the
staged verbatim copies in `/var/folders/.../T/opencode/plugin-src/` (`desktop_multi_window-0.2.1`,
`window_manager-0.5.1`). **All 22 findings reproduce. None withdrawn.**

Two corrections to the review's own text, found while verifying:

| # | Claim as written | Verified fact |
|---|---|---|
| V-1 | R-M7: the `Failed` alias workaround is "in 10 zip_broadcast files" | One file: `overlay_window_controller.dart:13-14`. The collision itself is real (`connection_status.dart:74` is exported through `models.dart:20`), so R-M7's conclusion stands. |
| V-2 | R-m1: `DesktopWindowService.setBounds(…, {bool center})` "duplicates `setFrame`" | The method does not exist in the shipped code; it is **new surface the FD proposes** (`domain-entities.md:51-52`). The finding is valid as a spec defect, not a code defect. It is worse than stated: `business-logic-model.md:100` says "`setBounds` + `center`", which directly contradicts Q9's bottom-anchoring. |

Additional evidence for two findings:

- **R-B1**: `FlutterMultiWindowPlugin.swift:8-23` — `register(with:)` calls `registerInternal` **and**
  `MultiWindowManager.shared.attachMainWindow(window:mainWindowChannel:)`, and
  `MultiWindowManager.swift:29-33` assigns `windows[0] = mainWindow`. The hijack is unconditional.
  The example's `RegisterGeneratedPlugins` (`example/macos/Runner/MainFlutterWindow.swift:13`) runs in
  `awakeFromNib` for the **main** window, outside the callback; the callback itself registers exactly
  one named plugin (`:15-18`). The review's "precedent claim is wrong" holds.
- **R-B2**: `WindowManager.swift:54-63` — `mainWindow`'s setter is `_mainWindow?.delegate = self`.
  `FlutterWindow.swift:85` (`window.delegate = self`) is what that replaces; `:102-110` shows
  `windowWillClose`/`windowShouldClose` are the only `onClose` callers, and
  `MultiWindowManager.swift:123-125` removes on `onClose`. `FlutterWindow`'s `deinit` (`:91-99`) is
  what shuts the engine down. R-B2's two consequences follow directly.
- **R-B4**: headers confirmed — `windows/include/.../desktop_multi_window_plugin.h:20-21` takes one
  `void*`; `linux/include/.../desktop_multi_window_plugin.h:24-27` takes one `FlPluginRegistry*`. The
  repo passes three and two respectively, and `build-verify.yml` has **10** steps all with
  `working-directory: packages/zip_captions` and **zero** `zip_broadcast` references.
- **R-M1**: `sttEngineRegistry` is read in `zip_captions/lib/main.dart:57` (registering a
  `FakeSttEngine`) and nowhere in `zip_broadcast/lib`; `zip_broadcast` builds engines through
  `sttEngineFactoryProvider` (`stt_engine_factory_provider.dart:20-27`). `SttEngineRegistry` is a plain
  class with no `Stream`/`Listenable` (`stt_engine_registry.dart:8-42`), and
  `sherpa_model_catalog_provider.dart:106` calls `unregister` at runtime. R-M1 holds on all three counts.
- **R-M10**: `window_manager-0.5.1/pubspec.yaml:31-32` → `path: ^1.8.2`, `screen_retriever: ^0.2.0`;
  one `macos/window_manager.podspec`, no federation. `zip_broadcast/macos/Podfile.lock:19,99,124` keeps
  `screen_retriever_macos` because the plugin still pulls it in. Both halves of R-M10 hold. Archive
  sha256 confirmed against pub.dev's published value by the staging step.

## 4. Verified correct (no action)

- BLM §7's moved-test list matches `packages/zip_broadcast/test/output/overlay/` exactly.
- `zip_core/test/helpers/pbt.dart` is byte-identical to zip_broadcast's copy, and `zip_core/test/helpers/generators.dart`
  exists, so tech-stack §4's "copied to zip_core" step is a no-op.
- `IdleState`, `RecordingActiveState`, `PausedState`, `ReconnectingState` and `StoppedState` exist as the FD names
  them.
- Registered from the callback, `window_manager` binds to the sub-window on all three platforms:
  - macOS: `registrar.view.window`;
  - Windows: `GetAncestor(view, GA_ROOT)` (`window_manager_plugin.cpp:349`);
  - Linux: the toplevel of the registrar's view.
- On Windows, `window_manager`'s top-level proc delegate runs in `desktop_multi_window` sub-windows: the
  sub-window calls `HandleTopLevelWindowProc` (`desktop_multi_window-0.2.1/windows/flutter_window.cc:151`).
- `window_manager`'s Windows `WM_CLOSE` handler and Linux `delete_event` handler return "don't
  prevent", so they don't block `desktop_multi_window`'s own close handling.
- zip_captions builds on all platforms in CI. zip_captions' `main()` takes no arguments today (FD §4.4 is
  accurate).

---

## 5. Owner decisions

### RQ-1 — How the pop-out gets always-on-top and its own decoration (resolves R-B2, R-B3; affects R-M5, R-M9, R-M10, R-m5)

A) **Native per-engine window channel, drop `window_manager` (recommended).**
- In each app's three runner callbacks:
  - register one small method channel on the new sub-engine, for example
    `configure({floating, decorated, minWidth, minHeight})`;
  - remove the unconditional borderless styling.
- The sub-engine calls `configure` with its mode before `overlayReady`. `ExternalDisplayMode` asks for
  borderless (today's behaviour); `PopOutMode` asks for decorated, floating and a minimum size.
- What it keeps: `desktop_multi_window`'s delegate and teardown stay intact, a dependency is removed, and
  window styling lives in one place per runner.
- Cost: native code in six runners (two apps × three platforms); Windows and Linux are compile-checked
  only (after R-B4's CI fix). The approved SECURITY-10 decision would be retired, and its "three untested
  native implementations" argument re-weighed against R-B2/R-B3.

B) **Keep `window_manager` on Windows and Linux; macOS uses the native channel from A for floating and
decoration.** Mixed mechanisms; the `window_manager` approval stays, narrowed to two platforms.

C) **Amend Q9 to a borderless pop-out.** Keep `window_manager` on Windows and Linux, set the macOS level
natively, and add a drag handle and close control inside the pop-out. Re-amends the owner's Q9 decision.

X) Other (please describe after [Answer]: tag below)

[Answer]:

### RQ-2 — What "speech recognition engine available" means in each app (resolves R-M1)

A) **Whatever already gates that app's Start Captioning control (recommended).** Zip Broadcast: the
audio-source/factory path. Zip Captions: `sttEngineProvider != null`. Each app exposes it as one
watchable provider that `popOutAvailability` reads.
B) Keep the registry check in Zip Captions, and treat the engine as always available in Zip Broadcast (an
active session implies an engine).
C) Drop the engine gate; the session-active check alone decides (BR-PIP-13's disabled state would then
be unreachable, so record it as N/A).
X) Other (please describe after [Answer]: tag below)

[Answer]:

### RQ-3 — Detecting an OS close of the pop-out (resolves R-M6)

A) **Active notification (recommended).** The sub-engine tells the main engine it is closing (over the
existing bridge, as a payload-free `popOutClosed`), raised from the platform close path chosen under
RQ-1. The main engine closes and clears state immediately, and the `'-1'` path stays as the fallback.
B) Accept lazy detection. The state clears on the next window call. Record it as an accepted limitation
and correct frontend-components §5.
X) Other (please describe after [Answer]: tag below)

[Answer]:

---

## 6. Remediation order

0. **Unit 8 defect fix (R-B4), its own branch → `develop`**:
   - correct zip_broadcast's Windows and Linux callback signatures to match the plugin's example;
   - add zip_broadcast macOS, Windows and Linux build jobs to `build-verify.yml`;
   - get CI green;
   - if RQ-1 = A, this branch can instead carry the new mode-aware callbacks.
1. Answer RQ-1..RQ-3 above. Then amend in place, logging each change in `audit.md`:
   - FD: BLM §2, §3.2-3.4, §4.1, §6; domain-entities §1.2, §1.4, §3.1, §3.3; frontend-components §2, §5;
     business-rules BR-PIP-01/03/13 and BR-U8.1-04/05;
   - NFR-R: §1.2, §3.1, §5.2, §10.2; tech-stack-decisions §1-3, §5;
   - the SECURITY-10 record, and the tech-spec §6 row if the dependency decision changes;
   - every handoff summary affected.
2. Get explicit approval of the revised FD and NFR-R, and record both in `audit.md`.
3. NFR Design, then Infrastructure Design. ID must re-verify every runner claim against plugin source:
   callback signatures per platform, `attachMainWindow`, delegate ownership, outer-frame semantics, and
   `argv` delivery to the sub-engine.
4. Code Generation Part 1 plan, with the corrected lockfile fence, explicit gates for all three packages,
   `flutter build macos --debug` for **both** apps, and CI builds of both apps.
5. Rewrite `.agent/overnight-pipeline.md` for Unit 8.1:
   - branch `feature/popout-live-captions`, PR to `develop`;
   - a scope fence that allows `zip_core`, `zip_captions` and both apps' runners;
   - the moved-test rule (BR-U8.1-01);
   - Unit 9 manual checks.
6. Fix the stale `aidlc-state.md` current-stage line and the artifact status headers.
