# Frontend Components — Unit 8.1: Pop-out Live Captions (S-21)

**Status**: Draft for approval.
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
final Widget? controls;      // rendered as a trailing row inside the list's last item region
```

- Default `null` → byte-for-byte the current rendering at every existing call site (both apps'
  `RecordingScreen`s, the external display's `OverlayWindowBody`, and the widget tests).
- When non-null, appended after the entry list inside the same `ListView` (so it scrolls with the
  captions and never overlaps them), wrapped in a `Padding` that reuses the entry padding. For the
  pop-out's two-line window, `controls` sits in the same column under the two caption lines and the
  geometry accounts for its height (`domain-entities.md` §3.3).
- The widget stays platform-agnostic: it receives a `Widget`, never a callback about pop-outs.

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

## 5. `PopOutBanner` — hint and return (UX-PIP-05)

| Aspect | Specification |
|---|---|
| Where | Main window only, immediately above the caption surface, inside `RecordingScreen`'s column (both apps). |
| Contents | `Text(popOutHint)` = `Captions are displaying in Picture-in-Picture`, plus a `TextButton` labelled `popOutReturn` = `Return to Window` that calls the same toggle. |
| Styling | `colorScheme.secondaryContainer` background, `onSecondaryContainer` text, one line at the app's normal body size; it must not clip at large text sizes (wrapping text, `Row` with `Flexible`). |
| Visibility | `shell.popOutEnabled` **and** the controller's status is `Opening` or `Open`. On `WindowClosed`/`OpenFailed`/`toggleOff`, `popOutEnabled` is already false, so the banner disappears in the same frame as the state change (BR-PIP-03). |
| Test hooks | `Key('popOutBanner')`, `Key('popOutReturn')`. |

## 6. Availability matrix rendering (UX-PIP-03/04, BR-PIP-12/13)

Rendered once, in `PopOutControls`; `PopOutInSurfaceToggle` in the main window reuses the same
computed record:

```
({bool visible, bool enabled, String? reason}) popOutAvailability({
  required ExternalDisplayStatus status,     // controller status
  required RecordingState recording,         // recordingStateNotifier
  required bool engineAvailable,             // registry.listAvailable().isNotEmpty
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