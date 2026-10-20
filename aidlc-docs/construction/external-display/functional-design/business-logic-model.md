# Business Logic Model — Unit 8: External Display (S-20)

**Revised 2026-10-20** per the PR #37 review comment (2026-10-19,
<https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308>).

What this unit's logic does, in order:

1. **Enumerate** connected displays once (capability + list) and watch for
   changes.
2. **Persist** the selected display id (and only that id, plus the switch and
   caption position) across launches — but never the *on* state (D-6).
3. **Open one window** on the chosen display's **work area** (D-3), sized to
   it, via the `createWindow` → `setFrame` → `show` sequence (B-6), with the
   platform frame conversion done by the io window adapter (B-1/B-2).
4. **Handshake** with the sub-engine (`overlayReady`) before treating the
   window as open (D-9); fail the open on timeout.
5. **Stream captions** into that window as the same `CaptionDisplayWidget` the
   main window uses (D-7), carrying an `activity` value selected by the
   recognition state (D-5).
6. **Handle the display disappearing** — close the window, keep the output
   on, wait, and reopen when the saved display returns (D-4).

---

## 1. Display enumeration and selection

**When `ExternalDisplayControls` is mounted** (or the shell first builds its
output panel), the `DisplayEnumerator` is created once and its `displays()`
result is cached.

- The first `displays()` call is the **capability probe**: if it throws, or if
  the platform stub's `isSupported` is false, the controls render nothing
  (S-20 web exclusion; BR-U8-11).
- An empty list is **not** an error — it renders "No displays detected" and
  disables the toggle (BR-U8-12).
- Selection defaults to the primary display (BR-U8-01) until the broadcaster
  picks one; the pick is persisted as `externalDisplayId` (BR-U8-07).
- `display-<index>`-normalised ids (Linux) are never persisted *as a label* —
  only the `id` string is, so a rename degrades to "waiting", never a crash.

## 2. Switch on — open the window

The switch is the *only* thing that opens the window (D-4). Toggling it on
while state is `Off` (or `WaitingForDisplay`, via Cancel-then-toggle-on):

1. `ExternalDisplayStatus` → `Opening`.
2. The controller serialises: if an open is already in progress, the toggle is
   a no-op (BR-U8-01) — no second window, no duplicate id.
3. `createWindow` with the `OverlayWindowLaunch` argument. A throw → `Failed`
   (`reason = create_failed`), `overlayEnabled` reverts to `false` (BR-U8-03).
4. The sub-engine decodes the launch. On success it installs its caption
   handler and sends `overlayReady` back through the main engine's method
   handler. On decode failure it renders "Window unavailable" and does **not**
   send ready (so step 5 times out, not hangs).
5. The controller waits for `overlayReady` up to `overlayReadyTimeout` (a
   named constant, ~10 s). On receipt → `Open`. On timeout → `Failed`
   (`reason = ready_timeout`), the (possibly half-open) window is closed,
   `overlayEnabled` reverts to `false` (BR-U8-03).
6. On `Open`, the controller sends the **latest held snapshot** immediately —
   the window shows the current caption content (or standby) without waiting
   for the next recognition event. Until the first snapshot renders, the
   window shows the standby surface.

`show` (from the plugin) is called after `setFrame`, so the first visible
frame is already on the target display at work-area size (B-6).

## 3. Caption streaming

While `Open`:

- `CaptionOverlayTarget.onCaptionEvent` builds the snapshot and the controller
  pushes it (`captionUpdate`), debounced per animation frame (BR-U8-09).
- The sub-engine applies the entries to its buffer/interim and the shipped
  `CaptionDisplayWidget` renders them (D-7 — the main window's widget,
  unmodified, per `recording_screen.dart:131`).
- `DisplaySettings` changes (font, size, scroll, theme, max lines) flow in the
  snapshot's `settings` and re-render live (BR-U8-12).

## 4. Recognition state — activity only (D-5)

Recognition start / pause / resume / stop change **only** the snapshot's
`activity` value. They **never** open or close the window (D-5, BR-U8-17).

| Recognition state | `activity` | Effect in the window |
|---|---|---|
| idle / stopped | `standby` | theme background, no text; stop clears captions (buffer emptied by the existing stop→idle path) |
| active | `live` | final entries + interim, as the main window |
| paused | `paused` | last captions stay; the `__pause__` marker row shows |
| reconnecting (broadcast transport) | `live` | recognition itself is not paused |

There is no "start paused". `BroadcastRecordingNotifier` is not modified.

## 5. Display disappears (D-4)

When `changes` shows the selected display is gone while `Open`:

1. The controller **closes the window** and releases it (BR-U8-02).
2. Emits `DisplayLost`; state → `WaitingForDisplay(savedId)`.
3. **`overlayEnabled` stays `true`** — the output remains on. The Proto-13
   disconnected notice shows with "waiting for display" status.
4. When `changes` shows a display with the saved id returns → the controller
   re-opens the window on it (same open sequence, §2) → `Open`.
5. **Cancel** (in the waiting state) switches the output **off**: `overlayEnabled = false`,
   state → `Off`. The saved id is **not** overwritten or cleared (BR-U8-07).

## 6. Switch off / window closed by user

- Switch off while `Open` or `WaitingForDisplay`: close the window (if open),
  release it, `overlayEnabled = false`, state → `Off` (S-20 AC4, D-5: "the
  window closes and its resources are released").
- If the broadcaster (or the OS) **closes the window itself**: after the ready
  handshake, a `PlatformException` with code `'-1'` from any
  `invokeMethod`/`setFrame`/`closeWindow` is the *only* close signal (D-9).
  The controller emits `WindowClosed`; the shell's existing `_syncOverlay`
  path clears `overlayEnabled` and deregisters the target (BR-U8-15). There is
  no ping/keep-alive probe.

## 7. Display rearrangement (window stays open)

When `changes` reports the same id with different `bounds`/`isPrimary` while
`Open`: the controller calls `setFrame` to the new work area (BR-U8-09). No
close/reopen; the handshake is not repeated (the window id is unchanged).

## 8. Launch

- The switch **always starts off** (D-6). The settings loader forces
  `overlayEnabled = false` at load; only `externalDisplayId` and
  `externalDisplayCaptionPosition` are honoured from the stored values.
- No window is opened at launch. The window opens only on an explicit switch
  on (§2) or on a saved display reappearing while waiting (§5.4).

## 9. Single-instance invariant

Exactly one external display window at a time (BR-U8-01). The controller's
open guard plus the single `windowId` field make a second window structurally
impossible. The one `DesktopMultiWindow.setMethodHandler` installed by the
controller (before the first `createWindow`) is the only handler on the main
engine (B-5).

---

## State machine

`ExternalDisplayStatus` transitions. `C` = controller, `S` = settings
notifier (shell), `UI` = controls.

```
                    +-------------+
        (launch)    |             |  toggle on
   +--------------->|     Off     |-----------+
   |                |             |           v
   |                +-------------+      +----------+  ready ok   +--------+
   |                       ^       |     |          |------------>|        |
   |                       |       |     | Opening  |             |  Open  |
   |                       |       +     |          |             | (act)  |
   |        create_failed  |             +----------+             +--------+
   |      or ready_timeout |                    ^  |                       |
   |                       v             close  |  |  display reappears    |
   |                +-------------------+       |  +----------+           |
   |                |        Failed       |     +-----------|            |
   |                +-------------------+   re-open on      |  display gone
   |                       ^                     toggle on  v            v
   |                       |                   (Off)   +---------------+
   |                       +----------------------------|WaitingFor-  |
   |                                                     | Display    |
   |                                                     +---------------+
   |                                                           ^
   +---------------------------+-------------------------------+
                     Cancel (off)          Cancel / toggle off -> Off
```

Plus the terminal-ish `Unsupported` (rendered before any of the above — the
section is absent) and `NoDisplays` (a sub-view of `Off` where the toggle is
disabled).

| # | From | Event | Guard | To | Side effects |
|---|---|---|---|---|---|
| T1 | (init) | capability check | stub / `isSupported` false | `Unsupported` | section hidden; no further logic |
| T2 | `Unsupported` | — | — | (stays) | no toggle, no window, no persistence |
| T3 | `Unsupported`/any | first `displays()` = [] | — | `NoDisplays` | "No displays detected"; toggle disabled |
| T4 | `NoDisplays` | `changes` adds a display | — | `Off` | list populates; toggle re-enabled; primary pre-selected |
| T5 | `Off` | toggle on | not `Opening` | `Opening` | `overlayEnabled = true`; `createWindow` |
| T6 | `Opening` | `createWindow` throws | — | `Failed(create_failed)` | close (idempotent); `overlayEnabled = false` |
| T7 | `Opening` | `overlayReady` | within `overlayReadyTimeout` | `Open` | `setFrame`; `show`; send held snapshot |
| T8 | `Opening` | timeout / sub-engine no-ready | — | `Failed(ready_timeout)` | close window; `overlayEnabled = false` |
| T9 | `Open` | recognition event | — | `Open` (new `activity`) | update snapshot `activity` only (BR-U8-17) |
| T10 | `Open` | `changes`: selected id gone | — | `WaitingForDisplay` | close window; emit `DisplayLost`; `overlayEnabled` stays `true` |
| T11 | `WaitingForDisplay` | `changes`: saved id back | — | `Opening` → `Open` | re-open on the saved display |
| T12 | `WaitingForDisplay` | Cancel | — | `Off` | `overlayEnabled = false`; saved id **kept** (BR-U8-07) |
| T13 | `Open`/`WaitingForDisplay` | toggle off | — | `Off` | close window (if open); `overlayEnabled = false` |
| T14 | `Open` | `WindowClosed` (`'-1'`) | post-ready | `Off` | shell `_syncOverlay` clears `overlayEnabled`; deregister target (BR-U8-15) |
| T15 | `Open` | `changes`: same id, new bounds | — | `Open` | `setFrame` to new work area (BR-U8-09); no re-handshake |
| T16 | `Failed` | toggle on | — | `Opening` | retry open (T5 path) |
| T17 | any | `changes` | no change (coalesced) | (stays) | no emission (BR-U8-05) |

`activity` is an attribute of `Open`, not a state of its own (D-5): recognition
events move within `Open`, never across the `Open` boundary.

---

## A7 forward notes (binding constraints on later units)

These are **not** implemented by this unit; they are recorded here so later
units do not re-decide them:

1. **Pop-out** is its own Phase 2 unit after Unit 8, **blocking the v2.0 RC**.
   It reuses this unit's window machinery (D-1): the `OverlayWindowMode`
   hierarchy gains a pop-out variant, the codec `v` is bumped, and
   `OverlayConfig`/`OverlayWindowLaunch` gain the pop-out's size fields. Its
   UX contract stays in `pip-ux-parity.md` §8 (this unit does not edit or move
   it). The pop-out's unit definition is **pending** and is not written here.
2. **Codec `v` is the version field Phase 8 (bilingual) will bump.** Unit 8 adds
   **no** translation fields (YAGNI). `key` == `CaptionDisplayEntry.entryId`,
   which is the segment ID Phase 8 keys translations by.
3. **Per-input caption colour** (the removed `sourceColorValues`) is Backlog —
   D-7. When it lands, it extends the snapshot's `settings`, not the window
   machinery.
4. **Native full-screen** of the external display is Backlog — D-3. The
   work-area frame is the full-screen stand-in for this unit.
