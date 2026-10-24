# Frontend Components — Unit 8.1: Pop-out Live Captions (S-21)

**Status**: APPROVED 2026-10-21 by James Petersen (revised after the pre-build review: RQ-1 A / RQ-2 A / RQ-3 A-amended; revision 2 same day).
**Authority**: `pip-ux-parity.md` §8.3 is the **sole** specification of both toggles. The approved
Proto-15 contains only a theme toggle; it is not visual authority for this unit and nothing here
is derived from it. Where §8.3 names a V1 label, the label is reproduced verbatim.

---

## 1. Component tree

```
[Zip Broadcast]
ZipBroadcastApp
  MaterialApp.router
    ZbAppShell                          <- modified: owns pop-out target + in-memory flag
      header action  PopOutControls     <- NEW  (UX-PIP-01)
      child: RecordingScreen            <- modified
        PopOutBanner                    <- NEW  (UX-PIP-05, above the caption surface)
        CaptionDisplayWidget(controls: PopOutInSurfaceToggle)   <- widget gains `controls`
        ... existing controls bar, appearance panel ...

[Zip Captions]
ZipCaptionsApp
  MaterialApp.router
    ZcAppShell                          <- modified: ConsumerStatefulWidget, owns target + flag
      header action  PopOutControls     <- NEW
      child: RecordingScreen            <- modified
        PopOutBanner                    <- NEW
        CaptionDisplayWidget(controls: PopOutInSurfaceToggle)
        ... existing controls bar, appearance panel ...

[Pop-out window, both apps, its own engine]
overlayWindowMain(args)
  ProviderScope
    OverlayWindowEntry                  <- promoted; awaits always-on-top, then signals ready
      MaterialApp(theme/darkTheme/themeMode from the live snapshot)
        PopOutWindowBody                <- NEW in zip_core
          CaptionDisplayWidget(entries, settings, controls: PopOutInSurfaceToggle)
```

The pop-out window renders **no** `PopOutBanner` and **no** chrome toggle: UX-PIP-05's hint is
"shown in the main window while popped out", and UX-PIP-01's toggle is the app-chrome control that
cannot exist in a 2-line window. Both modes of exit are reachable from the pop-out through the
in-surface toggle (UX-PIP-02).

---

## 2. `CaptionDisplayWidget` — the one shared change (Q6 A)

Current API (`zip_core/lib/src/widgets/caption_display_widget.dart`):

```
const CaptionDisplayWidget({required List<CaptionDisplayEntry> entries,
                            required DisplaySettings settings, super.key});
```

Change: one optional parameter.

```
final Widget? controls;      // rendered in a fixed row below the scrolling list
```

- Default `null` → byte-for-byte the current rendering at every existing call site (both apps'
  `RecordingScreen`s, the external display's `OverlayWindowBody`, and the widget tests).
- When non-null, the widget's body becomes `Column[Expanded(ListView…), controls]`: the controls sit
  **outside** the scrolling list, in a fixed row at the bottom of the caption container.
- The widget stays platform-agnostic: it receives a `Widget`, never a callback about pop-outs.

**R-M4 resolved (2026-10-21) — the first draft was wrong.** It appended `controls` *inside* the
`ListView`, "after the entry list". That list renders newest-first (`entries[entries.length - 1 - i]`,
`caption_display_widget.dart:84`) and auto-scrolls to the *end of the buffer*
(`:50-52`, `:79-85`), so the last item sits beyond the oldest caption. In a two-line window the
toggle would be scrolled out of view after about two entries, breaking UX-PIP-02 outright; with
`reverse: true` (`:81`) it would be off the top edge instead. Rendering it outside the scrollable
region is what `domain-entities.md` §3.3's geometry ("toggle row + two lines") already assumed.

Rejected: `onTogglePopOut`/`isPoppedOut` parameters (Q6 B) — pop-out semantics inside a shared,
platform-agnostic widget, and two more parameters to keep consistent across four call sites;
a `Stack` overlay at the call sites (Q6 C) — it would not be inside the caption surface (UX-PIP-02
says "inside the caption container") and would collide with the appearance panel.

---

## 3. `PopOutControls` — the chrome toggle (UX-PIP-01)

| Aspect | Specification |
|---|---|
| Placement | App shell header, both layouts: `AppBar.actions` when narrow; a header action in `ZcNavRail`'s and `ZbNavRail`'s header when wide (Q7 A). |
| Icon | `Icons.picture_in_picture_alt` when not popped out; `Icons.picture_in_picture_alt_outlined`-style "filled/exit" pair when popped out. Icon reflects state (UX-PIP-01). |
| Label | Visible text `popOutEnter` = `Picture in Picture`; `popOutExit` = `Exit Picture in Picture`. Not an icon-only button: the contract says "Header button labelled", and a tooltip alone would fail the accessible-name requirement in practice. On the narrow layout the label goes inside the `AppBar`'s actions as a `TextButton.icon`; on the wide-rail layout the same `TextButton.icon` sits under the rail's logo row, spanning the rail width. |
| Enabled | `enabled = sessionActive && engineAvailable` (§3.1 of `domain-entities.md`) |
| Disabled reason | Rendered as visible `Text` (`popOutUnavailableNoSession` / `popOutUnavailableNoEngine`) directly beneath the control, not a tooltip. |
| Hidden | When the controller's status is `Unsupported`. Nothing rendered (UX-PIP-04). |
| onPressed | the shell's `_togglePopOut()`; while `Opening`, pressing is a no-op by the controller (BR-PIP-02). |
| Semantics | `Semantics(button: true, enabled: enabled, label: label, hint: reason)` so a screen reader gets label, state and reason together. |
| Test hook | `Key('popOutToggle')` and `Key('popOutToggleReason')`. |

**Why the shell and not the screen**: the toggle must be reachable from any captioning view (the
contract says "app chrome"), and the shell is where the target and mine-only-in-memory flag live.

## 4. `PopOutInSurfaceToggle` — the in-surface toggle (UX-PIP-02)

| Aspect | Specification |
|---|---|
| Placement | Passed as `CaptionDisplayWidget.controls` in the main window's caption surface **and** the pop-out window's body. Presence in the pop-out is what makes UX-PIP-02's "usable from the pop-out itself" true. |
| Look | `TextButton.icon` with the same two labels and icons as §3, inside a pill container using `colorScheme.surfaceContainerHighest` so it stays legible over captions in both themes. Not disabled by the availability rule in the pop-out (the window only exists because the session is active); in the main window it obeys §3's `enabled`/reason. |
| Action (main window) | `shell._togglePopOut()`. |
| Action (pop-out window) | `bridge.sendPopOutToggle()` → main engine `popOutToggle` → shell's `_togglePopOut()` (business-logic-model §3.3). The sub-engine does not close its own window: the main engine owns the lifecycle, and the close arrives through the normal path. |
| Test hooks | `Key('popOutInSurfaceToggle')`, `Key('popOutInSurfaceToggleWindow')`. |

The sub-engine's toggle widget takes a `VoidCallback`; the fact that it is a bridge call is supplied
by `PopOutWindowBody`'s caller (`OverlayWindowEntry`), so the widget itself is testable in `zip_core`
with a recording callback.

**Amendment — review round 1 (2026-10-23).** Two points of §3 and §4 were contradicted by the
as-built widgets, and this note records the decision that now holds in both apps. It does not change
`pip-ux-parity.md` §8.3, which stays the sole authority on the toggle contract.

1. **§3's disabled reason is visible text in both apps.** `zip_captions` carried the reason only in
   the `Semantics(hint:)` and had no `Key('popOutToggleReason')`, while `zip_broadcast` rendered the
   `Text`; each app's tests locked its own decision in. Finding 2 resolved in favour of §3 as
   written: the reason is a visible `Text` under `Key('popOutToggleReason')` beneath the control,
   in `PopOutChrome` in both apps, and it remains in the semantics hint as well. In the narrow
   layout the line is `Flexible`, `maxLines: 2`, `TextOverflow.ellipsis`, because the `AppBar`'s
   toolbar height cannot grow past its minimum by a second line that wraps at large text sizes.
2. **§4's "in the main window it obeys §3's `enabled`/reason" is now true.** Both shells compute
   `popOutAvailability` once per build and pass `enabled` into `PopOutScope` (a new `available`
   field); each `RecordingScreen` passes it to `PopOutInSurfaceToggle.enabled`. The parameter is
   therefore live in production (finding 3). In the pop-out window the toggle stays `enabled: true`,
   as §4 already said, because the window only exists while a session is active.

## 5. `PopOutBanner` — hint and return (UX-PIP-05)

| Aspect | Specification |
|---|---|
| Where | Main window only, immediately above the caption surface, inside `RecordingScreen`'s column (both apps). |
| Contents | `Text(popOutHint)` = `Captions are displaying in Picture-in-Picture`, plus a `TextButton` labelled `popOutReturn` = `Return to Window` that calls the same toggle. |
| Styling | `colorScheme.secondaryContainer` background, `onSecondaryContainer` text, one line at the app's normal body size; it must not clip at large text sizes (wrapping text, `Row` with `Flexible`). |
| Visibility | `shell.popOutEnabled` **and** the controller's status is `Opening` or `Open`. On `WindowClosed`/`OpenFailed`/`toggleOff`, `popOutEnabled` is already false, so the banner disappears in the same frame as the state change (BR-PIP-03). **R-M6 caveat**: "the same frame" is true for `toggleOff`, `OpenFailed` and a native `subWindowClosed`; it is *not* true of the lazy `'-1'` fallback, which only fires on the next window call. |
| Open-failure copy | **R-M8 resolved**: the banner is a success-and-progress affordance and is never visible while `Failed` (the shell has already cleared `popOutEnabled`). `popOutOpenFailed` renders next to the **chrome toggle**, while the controller's status is `Failed`, and clears when the status next leaves `Failed` — Unit 8's existing pattern for `ExternalDisplayControls`. |
| Test hooks | `Key('popOutBanner')`, `Key('popOutReturn')`. |

**Amendment — fix round 6 (2026-10-23), owner direction (James Petersen).** "During picture in
picture mode, the main caption window should not show the captions, it should show a message that
the captions are currently displayed in an external window, and give the user a button to return
the captions to the main window. This is the UX that currently exists in v1." Applied to **both
apps** (owner's choice, keeping the per-app parity rule). UX-PIP-05 requires the hint and the return
action but is silent on whether the captions stay; this resolves that silence in v1's favour. What
changes in the table above:

1. **Where**: the hint and the return action **replace** the caption surface in `RecordingScreen`'s
   column while `shell.popOutEnabled` is true; they are no longer "immediately above" it. The
   `CaptionDisplayWidget` is not built in the main window while popped out.
2. **Styling**: a centred panel filling the caption surface's space — the exit glyph, `popOutHint`
   as a centred title-sized line, and `popOutReturn` as a filled button. Same
   `secondaryContainer`/`onSecondaryContainer` colours; same keys.
3. **Unchanged**: visibility (`shell.popOutEnabled`), the copy, the return action, the R-M6 caveat,
   R-M8 (failure copy next to the chrome toggle), and the keys. The screen still watches the
   on-screen caption target, because the pop-out's snapshot reads its captions from that target.
4. **Consequence for §4**: the main window's `PopOutInSurfaceToggle` lives in the caption surface,
   so it is not rendered while popped out; the return button and the chrome toggle are the main
   window's ways back.

## 6. Availability matrix rendering (UX-PIP-03/04, BR-PIP-12/13)

Rendered once, in `PopOutControls`; `PopOutInSurfaceToggle` in the main window reuses the same
computed record:

```
({bool visible, bool enabled, String? reason}) popOutAvailability({
  required ExternalDisplayStatus status,     // controller status
  required RecordingState recording,         // recordingStateNotifier
  required bool engineAvailable,             // each app's own gate (domain-entities §3.1)
})
```

Pure, in `zip_core` (`output/overlay/pop_out_availability.dart`), so both apps and tests share it and
the matrix cannot diverge between them. `visible = status is! Unsupported`;
`enabled = sessionActive(recording) && engineAvailable`;
`reason = !engineAvailable ? noEngine : !sessionActive ? noSession : null`.
`sessionActive` = `RecordingActiveState || PausedState || ReconnectingState` (Q8 A).

## 7. `PopOutWindowBody` (pop-out engine)

| Aspect | Specification |
|---|---|
| Surface | Opaque, `colorScheme.surface`, `Scaffold` with no app bar. Safe-area padded. |
| Theme | `MaterialApp(theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: from snapshot)` — a theme change reaches it on the next frame because the snapshot carries `DisplaySettings` (BR-PIP-09). Shares the `_themeModeOf` mapping with `OverlayWindowApp` via one internal helper. |
| Content | `CaptionDisplayWidget(entries: [...entries, ?interim], settings: settings, controls: inSurfaceToggle)`, bottom-anchored, no position selector (the pop-out is bottom-anchored by geometry, not by `CaptionPosition`). |
| Toggle | The body builds the toggle itself: the exit action always (the window is popped out by definition), the filled `Icons.picture_in_picture_alt` glyph, and the exit label. `zip_core` has no ARB, so the shipped English default is `popOutWindowExitLabel` and `PopOutWindowBody.toggleLabel` lets the pumping app pass its localized string (round-1 finding 4). |
| Activity | `standby` renders an empty opaque surface; `live` and `paused` render the buffer (Unit 8's matrix, minus the top/bottom choice). |
| Caption text in chrome | none: no window title derived from captions (BR-U8.1-09). |
| Scroll | `DisplaySettings.scrollDirection` is honoured by the shared widget; the two-line geometry assumes bottom-anchored, newest-visible. |

## 8. Copy inventory

Per §3.2 of `domain-entities.md`: `popOutEnter`, `popOutExit`, `popOutHint`, `popOutReturn`,
`popOutUnavailableNoSession`, `popOutUnavailableNoEngine`, `popOutOpenFailed`. Seven keys per app.
No existing key is renamed or removed. `zip_captions`'s `ZcStrings` gains one getter per key, which
is the app's established mechanism (Unit 7); `zip_broadcast` uses `ZipBroadcastLocalizations`.

## 9. What is deliberately absent

- Any pop-out control on web (BR-U8.1-11): `isSupported` is false → `Unsupported` → nothing renders.
- Any content-setting picker (§8.8 items 8-10, deferred to Phase 8).
- Any orientation/pane-swap/translation/download control inside the pop-out (§8.8 item 10,
  deferred). Those all travel with the bilingual split, which does not exist in Phase 2.
- A draggable divider, per-language windows, a manual caption source (§8.9).
- Window chrome styling beyond `AppTheme` (§8.9).
- Size/position memory (§8.9 "permitted, not required"; Q10 B excludes it entirely).
---

## 7. Scope note — the viewer surface (R-m7, 2026-10-21)

`zip_captions`' `ViewerScreen` also renders `CaptionDisplayWidget`, so it will receive the optional
`controls` parameter and could render a toggle. **The pop-out is out of scope for the viewer in
S-21.** `popOutAvailability` is gated on recording state, and viewer captions do not flow through the
caption bus, so a viewer pop-out would show an empty window. The viewer keeps `controls: null`;
adding it is a future unit's decision, and would need its own rule for what a viewer pop-out mirrors.
