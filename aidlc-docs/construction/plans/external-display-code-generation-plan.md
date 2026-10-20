# Code Generation Plan — Unit 8: External Display (S-20)

**Prior stages**: Functional Design (`../external-display/functional-design/`,
proposed 2026-10-19T22:32Z) and Infrastructure Design
(`../external-display/infrastructure-design/infrastructure-design.md`, proposed
2026-10-19T22:52Z). Neither had a human approver; both are recorded as
`*_PROPOSED` in the ledger, per the run rules.

**Story**: S-20. **Branch**: `feature/external-display` (off `origin/develop` at
`99dd5ee`). **Package**: `zip_broadcast`.

**Gate status of this plan.** The run instruction makes this plan the hard
approval gate and says Part 2 proceeds in the same run only when the plan is a
*strict transcription of already-approved design with no open questions.* The
three open questions (OQ-1, OQ-2, OQ-3) were answered on 2026-10-19 and are
transcribed below with their consequences. The design itself still has no human
approver (recorded `*_PROPOSED`), and OQ-1's answer required a correction to
what it delivers, so Part 2 still waits on a human accepting the design as
revised. This plan is committed and the run stops here.

---

## Scope

`zip_broadcast` only, plus the root `pubspec.lock` through the two approved
dependencies (`screen_retriever`, `window_manager`). No `zip_core` change: the
caption buffer, `CaptionDisplayEntry`, `DisplaySettings`, `AppTheme` and
`CaptionDisplayWidget` are consumed as shipped.

Out of scope, carried verbatim after the OQ answers: always-on-top on
Windows/Linux and a truly frameless window on Windows/Linux (OQ-1 Option B does
not reach the sub-window at this SDK floor; ID-5,
`window-manager-security-10.md` §2); UX-PIP-07's controls that do not exist
(OQ-2, deferred); the web Document PiP path (OQ-3, later unit, F-8.9).

---

## New files (all under `packages/zip_broadcast/lib/src/output/overlay/` unless noted)

| # | File | Contains |
|---|---|---|
| 1 | `display_info.dart` | `DisplayInfo` (freezed) |
| 2 | `display_enumerator.dart` | `abstract interface class DisplayEnumerator` incl. `dispose()`; `resolveTarget(...)` pure helper (also used by the controller) |
| 3 | `screen_retriever_display_enumerator.dart` | conditional export (`_io` when `dart.library.io`, else `_stub`) + `createDisplayEnumerator()`. **No plugin symbol.** |
| 4 | `screen_retriever_display_enumerator_io.dart` | `ScreenRetrieverDisplayEnumerator`; the **only** `package:screen_retriever/...` import (SECURITY-10 §5 item 1). Uses `ScreenRetriever.instance.getAllDisplays()` plus the `ScreenListener` mixin (`onScreenEvent(String)`); no `displayChangedNotifier` exists in 0.2.2. |
| 5 | `screen_retriever_display_enumerator_stub.dart` | empty-list enumerator; **no plugin import**. |
| 6 | `overlay_window_mode.dart` | sealed `OverlayWindowMode` + `ExternalDisplayMode`, `PopOutMode` |
| 7 | `overlay_event.dart` | sealed `OverlayEvent` + `DisplayLost`, `WindowClosed`, `OpenFailed` |
| 8 | `caption_overlay_snapshot.dart` | freezed + JSON `CaptionOverlaySnapshot` |
| 9 | `overlay_window_launch.dart` | freezed model + hand-written `OverlayWindowLaunchCodec` (mode + config + snapshot, `null` on malformed) |
| 10 | `overlay_window_controller.dart` | `OverlayWindowController` (plain class on the shell's `ProviderContainer`): guard, open/close/re-frame, event stream, settings listener, probe |
| 11 | `overlay_window_bridge.dart` | `OverlayWindowBridge` interface + conditional export + `createOverlayWindowBridge()` |
| 12 | `overlay_window_bridge_io.dart` | `DesktopMultiWindowBridge` (only `DesktopMultiWindow` import) |
| 13 | `overlay_window_bridge_stub.dart` | no-op |
| 14 | `overlay_window_entry.dart` | `isOverlayWindowLaunch`, `overlayWindowMain`, `OverlayWindowEntry` |
| 15 | `overlay_window_app.dart` | `OverlayWindowApp` (renders `CaptionDisplayWidget`, applies the snapshot `settings`, in-window `PopOutToggle`; colours resolved from `AppTheme`, no per-source colouring in this unit) |
| 16 | `external_display_status.dart` | sealed `ExternalDisplayStatus` + `deriveExternalDisplayStatus(...)` |
| 17 | `lib/src/widgets/pop_out_toggle.dart` | `PopOutToggle` + `PopOutHint`; one widget, rendered by the shell (rail/AppBar), by `ExternalDisplayControls` (Home + Settings), and by `OverlayWindowApp` |
| `lib/src/widgets/` | 18 | `external_display_controls.dart` — Proto-13 section, including the pop-out toggle row |
| `lib/src/models/` | 19 | `pip_content.dart` — enum `original/translated/both` |
| `lib/src/providers/` | 20 | `external_display_controller_provider.dart` — `@Riverpod(keepAlive: true)` controller/status provider |
| 21 | `desktop_window_decorator.dart` | `abstract interface class DesktopWindowDecorator` (`setAlwaysOnTop`, `setFrameless`) + conditional export + `createDesktopWindowDecorator()`. **No plugin symbol.** |
| 22 | `desktop_window_decorator_io.dart` | `WindowManagerDecorator`; the **only** `package:window_manager/...` import (`window-manager-security-10.md` §5 item 1). Used for the **main** window only; never constructed or called in the sub-engine (§5 item 4). |
| 23 | `desktop_window_decorator_stub.dart` | no-op decorator; **no plugin import**. |
| `macos/Runner/` | 24 | `MainFlutterWindow.swift` — sub-window `NSWindow.level = .floating` (ID-5) |

## Modified files

| # | File | Change |
|---|---|---|
| 25 | `pubspec.yaml` | `screen_retriever: ^0.2.2` and `window_manager: ^0.5.2` under dependencies, each with a SECURITY-10 comment |
| 26 | `pubspec.lock` (root) | resolution entries only (`screen_retriever*`, `window_manager`, `path` if absent) |
| 27 | `lib/src/models/overlay_config.dart` | `targetDisplayId` → `mode`; add `popOutSize`, `popOutMinimumSize`; regenerate freezed. **Recorded deviation from Application Design** (see below). |
| 28 | `lib/src/models/output_target_settings.dart` | `externalDisplayId`, `popOutEnabled`, `popOutDisplayId`, `pipContent`; regenerate |
| 29 | `lib/src/providers/broadcast_providers.dart` | persist/load the four new keys |
| 30 | `lib/src/output/overlay/caption_overlay_target.dart` | own the snapshot stream; `show(mode)`; disconnect re-frame; `events`; `captionUpdate` carries a snapshot; probe-failure → `WindowClosed` |
| 31 | `lib/src/shell/zb_app_shell.dart` | `_syncOverlay` drives the controller; **new** `ref.listen<BroadcastSessionState>` in `initState` for BR-U8-17 (there is none today); `PopOutToggle` in rail/AppBar; `PopOutHint`; `popOutToggle` inbound handler (`setMethodHandler`); notice on `DisplayLost`/`OpenFailed`; construct the decorator for main-window state only |
| 32 | `lib/main.dart` | `main(List<String> args)` + overlay branch |
| 33 | `l10n/arb/app_en.arb` + generated `src/l10n/*` | the strings in the "Strings" section |
| 34 | `lib/src/widgets/output_targets_panel.dart` | replace the Phase 1 overlay switch with `ExternalDisplayControls` (unchanged in structure; the card is shared by Home and Settings already) |

**Deviation from Application Design, recorded.** `phase2-component-methods.md`
§7 fixes `OverlayConfig.targetDisplayId`; this unit replaces that field with a
sealed `OverlayWindowMode mode` (FD `domain-entities.md`). The reason is that
one config type now serves two window intents, so a single nullable
`targetDisplayId` cannot express `PopOutMode`. Source compatibility is
preserved for the only producer (`const OverlayConfig()` in
`CaptionOverlayTarget.show()`), and no other package reads the type. This is a
deliberate, documented departure rather than an oversight; it needs the human's
acknowledgement alongside OQ-1.

## File count

The list is 34 files (24 new, 10 modified). Two changes produced the count: the
pop-out toggle was promoted to its own `lib/src/widgets/pop_out_toggle.dart`
(three hosts, so the shell cannot own Home's copy), 31 files; and OQ-1 Option B
added the three-file `desktop_window_decorator` trio (interface + conditional
export, `_io` adapter, `_stub`), 34 files.

## Convention note

New overlay types go in the existing `lib/src/output/overlay/` flat directory,
which already holds seven files; no sub-directory is introduced, matching
Phase 1's layout.

---

## Test list (explicit; written before implementation, per `docs/TDD.md`)

Existing tests to keep green: `test/output/caption_overlay_target_test.dart`
(10 cases), `test/shell/zb_app_shell_test.dart`,
`test/screens/recording_screen_test.dart`, `test/screens/settings_screen_test.dart`,
`test/widgets/*`, `test/app_test.dart`.

| # | File (new unless noted) | Cases |
|---|---|---|
| T1 | `test/output/display_info_test.dart` | equality incl. bounds/scaleFactor; JSON-free model compiles with `Rect` |
| T2 | `test/output/display_enumerator_test.dart` | `resolveTarget`: selection present → itself; absent + primary → primary; absent, no primary, list non-empty → first; empty → null; idempotent under repeated calls; **PBT** (`test/helpers/pbt.dart`, in-tree shim): for any non-empty list, result is always an element of the list (PBT-03 style invariant) |
| T3 | `test/output/overlay_window_mode_test.dart` | exhaustive switch compiles over both variants; `const OverlayConfig()` equals `ExternalDisplayMode()` + defaults; `popOutSize` default 640x320; minimum default 320x180 |
| T4 | `test/output/caption_overlay_snapshot_test.dart` | JSON round-trip: entries (final), interim present/absent, `sourceColorValues` map (int values), settings; unicode text round-trips byte-for-byte; no dropped fields; a snapshot is never a `SessionStateEvent` payload (type-level) |
| T5 | `test/output/overlay_window_launch_test.dart` | codec round-trip for both modes; malformed JSON → null; missing `mode` → null; unknown mode string → null; oversized/garbage argument → null, no throw; **PBT**: round-trip property over generated snapshots (`pbt.dart`) |
| T6 | `test/output/screen_retriever_display_enumerator_test.dart` | against a fake platform-source seam (a `ScreenListener`-shaped fake, not the plugin): `displays()` preserves order; first listener receives the current list (replay); a same-id list with changed bounds IS emitted while an identical list is NOT; `display-added` and `display-removed` each cause a re-read and an emit; a source error logs and does not close the stream; `dispose()` closes and is idempotent; listener add/remove does not leak a second source subscription; **id normalisation**: empty plugin `id` on Linux falls back to `name`, then `display-<index>`, and duplicated names are suffixed; **Windows scaling**: a 1.5x display shaped like the Windows backend is divided by `scaleFactor` exactly once, on both offset and extent; `scaleFactor == 0` is treated as `1` |
| T7 | `test/output/overlay_window_controller_test.dart` | one-window invariant: second open while open is refused (BR-U8-01); mode switch closes then opens, exactly one `createWindow` per switch; enable external display frames to `DisplayInfo.bounds` exactly; re-resolution on geometry change re-frames; disconnect → single `setFrame` to primary + `DisplayLost` + persisted id updated (BR-U8-06); no destination → `Lost`, no `closeWindow`; create throws → `OpenFailed`, no registry registration, `isVisible` false (BR-U8-03); disable closes once; stop path closes once; `WindowClosed` on a failing `captionUpdate`; closed invariant (BR-U8-15) after every path; `dispose()` closes if open |
| T8 | `test/output/caption_overlay_target_test.dart` (modify) | existing 10 cases re-pointed at `show(mode)`; new: `captionUpdate` payload is a decodable `CaptionOverlaySnapshot` whose `entries` equal the buffer's finals and whose `interim` is the trailing non-final; `sourceColorValues` is derived from `AudioInputConfig.colorIndex` through the **zip_broadcast** style class (assert the accent ARGB), and is absent for a paused placeholder entry; settings change reaches the next payload without a reopen (BR-U8-12); no `captionUpdate` before `show`; `DisplayLost` surfaces on the target's `events`; close by `hide()` still idempotent |
| T9 | `test/widgets/external_display_controls_test.dart` | Proto-13: list renders all displays in order; selected row from persisted id; fallback to primary when the persisted id is absent; tap persists the id; empty label renders "Display N"; toggle writes `overlayEnabled`; `Unsupported` renders nothing (BR-U8-11); `NoDisplays` disables the toggle; `Lost` shows the disconnected banner; `Failed` shows the failure copy and the toggle is off; the section contains a `PopOutToggle` (Home/Settings host); **no semantics label or key contains caption text** (BR-U8-18) |
| T10 | `test/output/overlay_window_app_test.dart` | renders the snapshot's entries and interim; applies the snapshot's `DisplaySettings` (font size changes the rendered style); colours come from `AppTheme` (swap the theme in the snapshot and observe the surface colour change — **no duplicated AAA ratio assertion**; that lives in `zip_core/test/pbt/theme_contrast_test.dart`, BR-U8-20); in-window toggle sends `popOutToggle` through the bridge stub; a bad `captionUpdate` is ignored without throwing (BR-U8-19) |
| T11 | `test/output/overlay_window_entry_test.dart` | `isOverlayWindowLaunch` true only for `['multi_window', '1', '{}']`-shaped args, false for `[]`, one arg, non-multi first arg; `overlayWindowMain` with a bad payload builds the failure frame and does not initialise Supabase (asserted by the fake Supabase seam being untouched) |
| T12 | `test/shell/zb_app_shell_test.dart` (extend) | external display on/off drives the controller (fake) register/deregister; **stop-then-navigate and navigate-then-stop** each write `overlayEnabled=false` exactly once (BR-U8-17; the two orders the existing recording-screen listener cannot express); stopping captioning does **not** clear `popOutEnabled`; pop-out toggle: hidden when `isSupported` false (UX-PIP-04), disabled with the `popOutDisabledNoSession` tooltip when idle and not popped out (UX-PIP-04b), enabled with an active session, and its callback does not fire while disabled; hint shown while popped out and cleared on `WindowClosed` (BR-PIP-03/05); the inbound `popOutToggle` handler accepts `fromWindowId > 0` and ignores `0`, an unknown method, and a non-null argument (BR-U8-18/19) |
| T13 | `test/providers/broadcast_providers_test.dart` (extend) | the four new keys persist and reload; an absent `externalDisplayId` stays null; `popOutEnabled` reloads but nothing auto-opens (BR-U8-16 — asserted via the provider, not the shell) |
| T14 | `test/widgets/output_targets_panel_test.dart` (modify) | the card now renders `ExternalDisplayControls`; no Phase 1 switch remains; the pop-out toggle is reachable from the panel (Home host) |

PBT use: T2 and T5 only, via the in-tree `test/helpers/pbt.dart` (100 fixed
seeds, no shrinking — the project's Dart PBT decision recorded at Unit 7).

| T15 | `test/output/desktop_window_decorator_test.dart` | the factory returns the stub on web/unsupported and the io adapter elsewhere (via the same conditional-seam pattern as the other trios); the adapter maps calls to the package's methods one-to-one against a fake channel; **fence**: `OverlayWindowApp` never constructs or calls the decorator (SECTION: assert the widget tree's dependencies do not include the decorator provider, and that a sub-engine smoke test records zero channel calls) — `window-manager-security-10.md` §5 item 4 |

Not testable in this package, recorded for Unit 9: always-on-top (macOS code
only; and on Windows/Linux not implemented at this SDK floor even with
`window_manager` 0.5.2), borderless on Windows/Linux (not implemented), window
close by the OS (T12 covers the code path via a fake; the real close is
manual).

---

## Implementation order (Part 2)

1. `pubspec.yaml` + `dart pub get`; confirm the resolved `screen_retriever`
   version is 0.2.x, the resolved `window_manager` version is 0.5.x (not 0.6),
   and that `--fatal-infos` stays clean in a scratch import of both plugins
   (ID-3's deprecation hazard; `window-manager-security-10.md` §2 and §5).
2. Write T1, T3, T4, T5 (models + codecs) — failing.
3. Implement files 1, 6, 7, 8, 9; regenerate freezed.
4. Write T2; implement file 2.
5. Write T6; implement files 3-5.
6. Write T11; implement files 11-14 (bridge + entry).
7. Write T7; implement file 10 and the `events`/snapshot additions to 26.
8. Write T10 and the decorator-fence case; implement file 15; implement files
   21-23 and wire the decorator into the shell (file 31) for main-window use
   only.
9. Write T9, T14; implement files 16, 17 (`lib/src/widgets/`), 30.
10. Write T12, T13; implement files 27, 30, 31, 18, 19.
11. Strings (33); regenerate l10n.
12. macOS runner (24).
13. Re-run T8 against the final target; regenerate freezed for 27/28.
14. Gates, in the run's order, all three packages.
15. Summaries under `aidlc-docs/construction/external-display/code/`.

Commit split: `feat(zip_broadcast):` for implementation steps 2-12 grouped
logically, `test(zip_broadcast):` for the failing-test commits that precede each
group, `docs(aidlc):` for design artifacts.

---

## Strings (ARB keys to add)

`externalDisplayTitle`, `externalDisplayDescription`, `externalDisplayPrimary`,
`externalDisplayDisplayNumber(int index)`, `externalDisplayActiveOn(String
label)`, `externalDisplayFallbackNotice`, `externalDisplayDisconnected(String
label)`, `externalDisplayOpenFailed`, `externalDisplayNoDisplays`,
`externalDisplayUnsupported` (unused in UI, kept for the provider's reasoning
string), `popOutToggleOpen`, `popOutToggleClose`, `popOutDisabledNoSession`,
`popOutHintActive`, `popOutReturnAction`, `popOutContentOriginal`,
`popOutContentTranslated`, `popOutContentBoth`, `overlayWindowUnavailable`.
No string contains caption text.

---

## Open questions — answered 2026-10-19

All three were answered by the human after this plan was first committed. The
answers are authoritative and are transcribed below with their consequences.
Where an answer's premise turned out to be factually wrong, that is recorded
rather than papered over.

### OQ-1 — Always-on-top and borderless on Windows/Linux — ANSWERED: Option B

`desktop_multi_window` 0.2.1 creates the native window but exposes no
always-on-top API and no style-mask control **to Dart**. The native side does
have the handle, and the reachable surface differs per platform — this matters
because the earlier draft of this section overstated the blocker:

| Platform | Where the sub-window object lives | Reachable from our runner without vendoring? |
|---|---|---|
| macOS | `FlutterWindow` in the plugin, registered in `MultiWindowManager.windows` | Yes, via the plugin's `onWindowCreatedCallback` plus an order-on-screen observer (ID-5). |
| Windows | `FlutterWindow` owns an `HWND` inside `MultiWindowManager` | `EnumWindows` + `GetWindowThreadProcessId` in our runner can find our own top-level windows and call `SetWindowPos(..., HWND_TOPMOST, ...)`. No plugin handle needed, but it is a heuristic (process-wide enumeration) with no id linkage. |
| Linux | `flutter_window.cc` links the plugin's GTK code into the **runner** binary (`CMakeLists.txt` in the package adds `flutter_window.cc` to the runner target) | The plugin registers itself with the runner's registrar; a runner-side `gtk_window_set_keep_above` would need a reference to the sub-window's `GtkWidget`, which the plugin does not publish either. |

**Answer: Option B — add `window_manager` as a dependency, with its own
SECURITY-10 record.**

**Verified consequence, which changes what Option B delivers.** Option B was
proposed on the assumption that a window-management plugin can address the
sub-window. It cannot at this repo's SDK floor:

- 0.6.0 (repo `main`, not published) is the only version with an API that
  addresses arbitrary windows (`nativeapi` `Window.isAlwaysOnTop`,
  `titleBarStyle`, `isNonActivating`, `setParentWindow`; `legacy.dart` targets
  the current engine's window, which in a sub-engine is the sub-window). It
  requires `sdk ^3.13.0` / `flutter >=3.47.0` and is therefore excluded by the
  same rule that excludes `screen_retriever` 0.3.0.
- 0.5.2 (the newest usable release, `sdk >=3.0.0 <4.0.0`, `flutter >=3.3.0`) is
  single-window: one `MethodChannel('window_manager')`, no window-id parameter
  on any method, native handlers bound to the app's own window. Calling
  `setAlwaysOnTop` from the sub-engine raises the **main** window.
- 0.5.2 already depends on `screen_retriever ^0.2.2`, the pin this unit chose,
  so the two plugins agree by construction.

So Option B is implemented as: pin `window_manager: ^0.5.2`, add the
`window-manager-security-10.md` record, confine it to one adapter with a
platform-neutral interface, and forbid its use from the sub-engine with a
test. macOS always-on-top still ships through the `desktop_multi_window`
callback (unchanged, and the only mechanism that reaches the sub-window);
Windows/Linux sub-window always-on-top remains deferred, now for a verified
reason. The dependency's value at this floor is a maintained main-window
state API plus a recorded upgrade path to 0.6.0 when the SDK floor moves.
This must be stated in the PR body: adding the package does not close
§8.8 item 15 on Windows/Linux.

Borderless is answered by "no app chrome; the platform title bar is retained"
(FD, ID-5 "Borderless"). Option B does not change that either, for the same
reason: 0.5.2 cannot set the sub-window's style mask.

**File-list effect**: `pubspec.yaml` gains `window_manager: ^0.5.2` alongside
`screen_retriever` (file 22); `pubspec.lock` gains the package (file 23); one
new adapter file and its stub/factory are added to the overlay directory; one
test asserts the adapter is never invoked from `OverlayWindowApp`. The file
count is now 34 (24 new, 10 modified); see the revised tables below.

### OQ-2 — `pip-ux-parity.md` §8.8 item 10 — ANSWERED: defer

Item 10 requires the orientation toggle, pane swap, translation target select
and download progress to work inside the pop-out. None of those features exists
in Phase 2 (one pane, one language, no download). F-8.8 records the mapping and
ships the controls that exist.

**Answer: deferred to the unit that adds those controls.** Not a blocker for
Unit 8. §8.8 item 10 stays open in `pip-ux-parity.md` and is not claimed as
met.

### OQ-3 — Web scope — ANSWERED: later unit

The binding decision says "Web/PWA uses the browser Document Picture-in-Picture
API", and §8.6 says the PWA "is a release target, not a degraded fallback".
S-20 says external display is not offered on web, and this unit's definition
names no web work. F-8.9 excludes web entirely in this unit; the pop-out control
is hidden there.

**Answer: the web Document PiP path is a later unit; the pop-out ships
desktop-only and is hidden on web in this unit.** Unchanged from the design.

---

## Self-check against the run brief's Stage 3 gate

> do not proceed to Part 2 in the same run unless the plan is a strict
> transcription of already-approved design with no open questions.

The three open questions are now answered, so the second half of that condition
is met. The first half is **not**: the design stages were never human-approved
(recorded `*_PROPOSED` in the ledger), and OQ-1's answer rests on a premise the
investigation corrected. Part 2 still requires a human to accept the design
(including the corrected Option B consequence) before implementation. Every
step above is ordered and test-listed so that session can execute it verbatim.