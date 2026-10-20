# Frontend Components — Unit 8: External Display (S-20)

**Revised 2026-10-20** per the PR #37 review comment (2026-10-19,
<https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308>).
Two components: the controls in the main window and the window's own root.
Both are `zip_broadcast`; the caption widget inside the window is the shipped
`zip_core` `CaptionDisplayWidget`, unmodified (D-7).

---

## 1. `ExternalDisplayControls` (new, main window)

A section widget embedded in the shipped `OutputTargetsPanel`
(`packages/zip_broadcast/lib/src/widgets/output_targets_panel.dart`), mounted
wherever that panel is (`home_screen.dart:65`, `settings_screen.dart:417`,
`broadcast_screen.dart:130`). It renders from `ExternalDisplayStatus`
(`domain-entities.md`) and the display list; every interaction writes through
the `OutputTargetSettings` notifier or goes to the
`OverlayWindowController`.

**Capability gate first.** If the status is `Unsupported` (web, or
`DesktopWindowService.isSupported` false — BR-U8-11), the widget renders
**nothing** (S-20: "external display output is not offered"). There is no
disabled placeholder.

### Render by status

| Status | Render (Proto-13 terms) |
|---|---|
| `Unsupported` | (nothing — section absent) |
| `NoDisplays` | Section label "External Display"; body "No displays detected"; no rows, no selector, no toggle. Re-populates automatically when `changes` adds a display (T4). |
| `Off` | "Available Displays" list: one row per `DisplayInfo` — icon, `label` (or "Display N" fallback, BR-U8-08), meta line (`W × H` from `bounds`, "· primary" when `isPrimary`, "· selected" marker on the persisted/primary default selection); a **row toggle**. Below: "Caption Position" selector — two buttons, **Bottom** / **Top** (B-8), reflecting `externalDisplayCaptionPosition`, persisted on change. No window preview content. |
| `Opening` | Same as `Off` with the selected row's toggle on and an "opening" affordance on that row; the window itself shows the standby surface (B-6: visible only after `show`). |
| `Open` | Selected row highlighted (Proto-13 `display-row.active`), toggle on, "Active" pill on the row, meta line `W × H · connected`. Caption Position selector stays live (changing it updates the open window's `position` in the next snapshot without a reopen — BR-U8-12). The preview area shows the placeholder caption text as in the prototype when `activity` is `live`, and empty otherwise. |
| `WaitingForDisplay` | Proto-13 disconnected banner: "The <display label> was disconnected — captioning continues, but the external display output has stopped." plus a **"waiting for display"** status line and a **Cancel** button (D-4). The row toggle is off, the row meta reads "· disconnected", the "Active" pill is hidden. Cancel → controller `Cancel` (T12): output off, saved id kept (BR-U8-07). |
| `Failed` | Fixed-copy failure banner under the list (create failed / could not start), the toggle off. No raw reason in the copy — `reason` is a code, not shown (BR-U8-18). Re-toggling retries (T16). |

### Interactions

| Interaction | Writes | Notes |
|---|---|---|
| Row toggle on (a display row) | `externalDisplayId = row.id` + `overlayEnabled = true` (one settings write, then the controller opens) | Toggling a *different* row while `Open` is a switch: the controller closes the current window and opens on the new display, serialised by the open guard (BR-U8-01). Selection by *tap* on the row (not the toggle) only sets `externalDisplayId` — BR-U8-07: only explicit user action writes settings. |
| Row toggle off (the active row) | `overlayEnabled = false` | Closes the window and releases it (S-20 AC4, BR-U8-02). Recognition is untouched (BR-U8-17). |
| Caption Position button (Top/Bottom) | `externalDisplayCaptionPosition` | Persisted (B-8); applied via the launch config for the next open and via the snapshot's `settings`/`position` for the open window. |
| Cancel (waiting) | `overlayEnabled = false` | D-4. `externalDisplayId` is **not** cleared (BR-U8-07). |

**Copy.** All user-facing strings are new ARB keys (English source only, per
the project's localization convention); the prototype's strings are the source
of the English copy ("Available Displays", "No displays detected", "Caption
Position", "Top"/"Bottom", the disconnected banner, "waiting for display",
"Cancel", the failure banner, "Active"). The preview area from the prototype
is **not** a live rendering path — it is a static preview placeholder; live
captions appear in the actual window. (The prototype's per-row toggle is
therefore the single output's toggle, expressed per row: exactly one row can
be on at a time, matching BR-U8-01.)

---

## 2. `OverlayWindowApp` (new, sub-engine entry)

The root widget of the secondary window. `OverlayWindowEntry` (the
sub-engine's `main`-equivalent, `domain-entities.md`) decodes `args[2]` with
the launch codec and builds it.

### Build

1. Decode the launch. Failure → the fixed **"Window unavailable"** frame
   (BR-U8-19): a centered, fixed-copy surface on the `AppTheme` background.
   No `overlayReady` is sent, so the main engine times out to `OpenFailed`
   (BR-U8-03).
2. Success → install the window's caption handler (`captionUpdate`), send
   `overlayReady` to window 0 **after** the handler is installed (B-5/D-9),
   then render the first snapshot from the launch (the window shows the
   standby surface until this — B-6).

### Render by `OverlayActivity` (D-5)

The surface is **opaque** (BR-U8-26) and takes its colours from `AppTheme`
`surface`/`onSurface` (BR-U8-20 — no literals, no repeated contrast
assertion). The caption block sits at the snapshot's `position` (top/bottom,
BR-U8-26).

| `activity` | Render |
|---|---|
| `standby` | Theme background only, no text. (Stop cleared the source buffer — BR-U8-17.) |
| `live` | The shipped `CaptionDisplayWidget` fed by the decoded entries + interim (D-7, BR-U8-25): final lines at full opacity, the interim line at 0.8, scroll direction / font / size / max lines from the snapshot's `settings`. |
| `paused` | Same as `live` over the frozen buffer; the `__pause__` marker row renders exactly as the main window does (it travels as a buffer entry, BR-U8-25). |

`captionUpdate` messages are decoded with the snapshot codec; a `null` decode
is dropped (BR-U8-19) and the window keeps its last good frame. The window
never renders a caption it failed to decode, and it never logs one
(BR-U8-18).

**Theme.** The snapshot carries `settings.themeModeSetting`; the window's
`ThemeMode` follows it, so the BR-U8-20 wiring test (dark → light swap
observes the surface colour change) exercises exactly this path.

---

## 3. What is NOT a component of this unit

- **The pop-out** (mode, toggle, content setting, resize, `PipContent`) —
  D-1: own unit, own components, reusing this unit's window machinery.
- **A second caption widget** — D-7: the window reuses
  `CaptionDisplayWidget`; per-input colour is Backlog.
- **`window_manager`** — D-13: removed; the borderless flag is set from the
  `desktop_multi_window` window-created callback in all three runners
  (D-2, settled in Infrastructure Design), and `window-manager-security-10.md`
  is deleted with this revision.
