# Unit 8.1 — Pop-out Live Captions (S-21): Code Generation Summary

**Status**: Code Generation complete on branch `feature/popout-live-captions`
(2026-10-22/23, unattended run — approved by the run configuration per
`.agent/overnight-pipeline.md`, subject to morning review). No push.

**Plan executed**: `aidlc-docs/construction/plans/pop-out-code-generation-plan.md`,
steps 1-30. Commits, in order:

| Step | Commit | Scope |
|---|---|---|
| 1-10 | `416ed5f` … `f62de72` | the contracts in `zip_core` (deps, config, generators, router, lease, close channel, configurator, geometry, availability, barrel) |
| 11 | `465cad7` | the promotion: 23 production + 13 test files + helper into `zip_core` (BR-U8.1-01) |
| 12-13 | inside `465cad7` | the five permitted shape changes and the seven controller deviations |
| 11-18 | `d1cf311` | `zip_broadcast` reads the machinery from `zip_core` |
| 23 | `5474ff9` | the seven broadcast ARB keys |
| 19 | `20f080f` | the engine gate and the pop-out providers |
| 20 | `a9c7681` | `PopOutCaptionTarget` |
| 21-22 | `2e9a7be` | the controls, the in-surface toggle and the banner |
| 22 | `5137551` | the shell, the rail and the recording screen |
| 24 | `f23453b` | `runZipCaptions` and the one-line `main` |
| 25-26 | `704b10d` | the captions target, controls, banner, strings and scope |
| 27 | `03b1622` | the captions shell, rail, recording screen, viewer scope note and eight strings |
| 28-29 | working tree, uncommitted at handoff | the six runners |

## What now exists

**`zip_core`** (one implementation for both apps):

- `lib/overlay.dart` — the pop-out/external-display surface. Deliberately **not**
  re-exported from `zip_core.dart`: both export a `Failed` (R-M7), so consumers
  import `zip_core.dart` with `hide Failed`.
- `src/output/overlay/` — the promoted controller, codec, snapshot, modes,
  events, bridges, router, lease, enumerator and its two factories, the
  `WindowConfigurator` and `SubWindowClosedChannel` triplets, `pop_out_geometry`,
  `pop_out_availability`, and `OverlayWindowHost` (one router, one enumerator,
  one close channel per engine).
- `src/widgets/` — `PopOutWindowBody`, `CaptionDisplayWidget.controls`, and the
  in-surface toggle placement that keeps the control outside the scroll area
  (R-M4).
- `src/providers/overlay_window_host_provider.dart` — `@Riverpod(keepAlive: true)`.

**`zip_broadcast`**: `broadcastEngineAvailableProvider`,
`popOutWindowControllerProvider`, `popOutStatusProvider`, `popOutEventsProvider`,
`popOutFrameFor`, `PopOutCaptionTarget`, `PopOutControls`, `PopOutInSurfaceToggle`,
`PopOutBanner`, `PopOutChrome`, `PopOutScope`, the rail's `headerAction`, the
shell's flag/events/toggle/dispose, the recording screen's banner and controls,
seven ARB keys.

**`zip_captions`**: `runZipCaptions(args, {runApp, isWeb})` with the overlay
branch before every app service (BR-U8.1-06), `captionsEngineAvailableProvider`,
the same providers/target/controls/banner/scope, `ZcAppShell` as a
`ConsumerStatefulWidget`, `ZcNavRail.headerAction`, the recording screen's
banner and controls, and eight ARB keys behind `ZcStrings`.

**Runners**: both apps' macOS (`configure` handler + `NSWindow.willCloseNotification`
observer + main-engine close channel), Windows (`configure` handler +
`RegisterTopLevelWindowProcDelegate` + main-engine close channel), and Linux
(`configure` handler + `"destroy"` hook + main-engine close channel). No
`RegisterGeneratedPlugins` runs inside any window-created callback (R-B1); no
`window.delegate` or plugin `WndProc` is replaced (R-B2).

## Where the implementation departs from the plan's letter

Each is recorded here because code generation may not silently reinterpret an
approved design. None changes a business rule, a wire shape, a test obligation or
a frozen contract.

1. **The chrome toggle's disabled reason is a semantics hint, not painted
   text.** FD frontend-components §3 asks for the reason "rendered as visible
   `Text` directly beneath the control", and §6 for the availability matrix to be
   rendered "once, in `PopOutControls`". That is unimplementable in the narrow
   layout: on a 375x812 test surface the stacked `Column` overflowed by 8 px
   inside the fixed-height `AppBar`, and `AppBar.actions` itself overflowed by
   319 px because `TextButton.icon` cannot shrink below its intrinsic width.
   The control therefore renders **one line in both layouts**, elides when the
   slot is tight, and carries the reason in `Semantics(hint:)`; the in-surface
   toggle inside the caption surface is where visible text has room. This is
   also why `PopOutChrome` exists as a thin wrapper: it computes the reasoning
   once and hands the hint down.
2. **`PopOutInSurfaceToggle` in the main window is always enabled.** FD
   frontend-components §4 says it "obeys §3's enabled/reason" in the main
   window. In practice the shell's flag is false until the window opens, so
   gating the toggle on the flag would make the control unusable — the only
   entry point would be permanently disabled. It is enabled whenever it is
   rendered; the chrome control carries the availability rule.
3. **The caption shell builds its chrome only once the ARB has loaded.** The
   pop-out widgets read copy through `PopOutScope`, which needs a non-null
   `ZcStrings`. While `zcStringsProvider` is still loading the shell renders the
   routed child alone, as it effectively did before (the title was the only
   consumer). Widget tests must override `zcStringsProvider`; three existing
   suites now do.
4. **The `PopOutScope` `InheritedWidget` was added to both apps.** The plan has
   the shell own the flag and the target, and the screens read them; with the
   screens below the shell in the tree, an `InheritedWidget` is the mechanism that
   keeps the flag out of the provider container (Q10 B). It also carries the
   copy, which replaces the `PopOutControls` "passed through `ZcStrings`"
   wording with an equivalent that works inside a `StatelessWidget`.
5. **`dsplayListProvider` was added to `zip_captions`** (the broadcast app
   already had one): the shell's geometry needs the controller's display list,
   and `popOutFrameFor` takes it as a parameter (R-M5).
6. **`zip_captions`' `fake_async` absence shaped its target test.** Z21/Z25 use
   `await Future.delayed` on real timers rather than `fakeAsync`, because adding
   `fake_async` to that app would be a new dev dependency (A7 forbids it without
   approval).
7. **The Windows/Linux runners compile in CI only.** Neither was built on this
   host; macOS was compiled for both apps. Nothing in this unit claims Windows or
   Linux runtime behaviour.

## Evidence per app (`pip-ux-parity.md` §8.8 item, both apps required)

| Item | `zip_broadcast` | `zip_captions` |
|---|---|---|
| 1 chrome toggle, two labels, state | `B31` `pop_out_controls_test.dart` | `Z22` `pop_out_controls_test.dart` |
| 2 in-surface toggle drives the same path | `B30` `pop_out_shell_test.dart` | `Z24` `pop_out_shell_test.dart` |
| 3 visibility rule | `B31` | `Z22` |
| 4 recognition continues | `B33` `pop_out_caption_target_test.dart` | `Z21` `test/output/overlay/pop_out_caption_target_test.dart` |
| 5 content is live | `B33` | `Z21` |
| 6 no engine → disabled with reason | `B31` + `B30` | `Z22` + `Z24` |
| 7 hint banner + return, clears on close | `B32` `pop_out_banner_test.dart`, `B30` | `Z23` `pop_out_banner_test.dart`, `Z24` |
| 11 drawer closes | `B30` (rail/drawer assertion) | `Z24` |
| 14 double toggle | `B30` | `Z24` |
| 18 no caption text in logs | the target logs nothing; `zip_core`'s fixed-string logs (`N-10`) | `Z25` `pop_out_redaction_test.dart` |
| bootstrap never starts app services | — (inline branch, shipped) | `Z20` `test/bootstrap_test.dart` |
| viewer has no pop-out control | — | `Z26` `viewer_screen_test.dart` |

Items 8-10 stay deferred to Phase 8 (translation-dependent), per the approved
partition.

## Gates

| Gate | Result |
|---|---|
| `dart analyze --fatal-infos lib test` — `zip_core` | clean |
| `flutter test` — `zip_core` | 914 passed, 4 skipped |
| `dart analyze --fatal-infos lib test` — `zip_broadcast` | clean |
| `flutter test` — `zip_broadcast` | 177 passed |
| `dart analyze --fatal-infos lib test` — `zip_captions` | clean |
| `flutter test` — `zip_captions` | 174 passed |
| `flutter build macos --debug` — `zip_broadcast` | built |
| `flutter build macos --debug` — `zip_captions` | built |
| Windows / Linux compile | CI only (not claimed here) |
| Fence: no `desktop_multi_window`/`screen_retriever` import in either app's `lib/` | none |
| Fence: `window_manager` absent | absent (the only mentions are the fence test and GTK's own `get_window_manager_name`) |
| Fence: `zip_core.dart` does not export `overlay.dart` | holds |

## What Unit 9 must still check by hand

The eight manual checks in the plan §7 (float, decoration, resize/move, min size,
OS-close promptness, external display still borderless, multi-monitor placement,
`window.delegate` intact) are unverified here by design.