# Business Logic Model — Unit 8: External Display (S-20)

Flow identifiers are `F-8.n`. They complement Application Design's `F8`
(`phase2-services.md`, "External display (S-20)"), which this unit implements
and does not replace. Where Application Design's one paragraph was silent — the
pop-out mode, the fallback, the close paths — the subsections below settle it.

Types are in `domain-entities.md`; rules are in `business-rules.md`; the
pop-out UX contract is `pip-ux-parity.md` §8 (binding, referenced not copied).

---

## F-8.1: One window component, two modes (source of truth for "not twice")

`pip-ux-parity.md` §8.7 requires a decision between "two modes of one window
component" and "two components sharing a service". The decision is **one
component, two modes**, and it is structural, not stylistic:

```
                 OutputTargetSettings
                 ├─ overlayEnabled   ─┐
                 ├─ externalDisplayId │  external display mode
                 ├─ popOutEnabled    ─┼─ pop-out mode
                 └─ popOutDisplayId  ─┘
                          │
                          ▼
                 OverlayWindowController            (one per app)
                 ├─ owns the single secondary window
                 ├─ owns the single DesktopWindowService
                 ├─ owns the single CaptionOverlaySnapshot stream
                 └─ serialises open/close with an in-progress guard
                          │
                          ▼
                 ZbAppShell._syncOverlay(settings)
                 ├─ registers CaptionOverlayTarget on the registry when
                 │  either mode is on, deregisters when both are off
                 └─ listens to controller events to clear settings
```

A single `CaptionOverlayTarget` instance (already owned by `ZbAppShell`) is
registered on the `CaptionOutputTargetRegistry` if **either** mode is enabled.
It has exactly one subscription to the live caption buffer and therefore one
`captionUpdate` path. The mode is a field on its config, not a second class.

Why this is safe as one window: both modes render the same caption surface with
the same `DisplaySettings` and the same per-input styles; only placement, size
and close semantics differ (table in `domain-entities.md`, `OverlayWindowMode`).
`desktop_multi_window` 0.2.1 supports one `createWindow` at a time per call and
would produce two independent engines for two windows — twice the caption
transport, twice the shutdown surface, and a second animation-capable engine at
60 fps for no user-visible gain.

**Mutual exclusion.** Enabling one mode while the other is open closes the
other first, in the same serialised critical section (BR-U8-01). The settings
model therefore never has both persisted flags `true` for longer than the one
call it takes to flip them, and the "two windows exist" state is unreachable.

**Rejected alternative, recorded so review can check it:** a shared
`DesktopWindowService` with two window classes (`ExternalDisplayWindow` +
`PopOutWindow`) was specified as the fallback shape. It duplicates the caption
snapshot encoder, the close-event handling, and the fallback logic — the exact
duplication §8.7 forbids.

---

## F-8.2: Enumerate displays and select one (S-20 AC1; Proto-13)

1. `ExternalDisplayControls` mounts. `externalDisplayControllerProvider` reads
   `DesktopWindowService.isSupported` (shipped, already injected in
   `CaptionOverlayTarget`).
   - **false** (web, mobile stub) → state `ExternalDisplayUnsupported`; the
     section renders nothing, including no disabled toggle (BR-U8-11).
   - **true** → continue.
2. Start `DisplayEnumerator.changes` and take the first emission (the
   contract guarantees one, `domain-entities.md`).
3. Empty list → `ExternalDisplayNoDisplays`.
4. Non-empty → `ExternalDisplayIdle`; the list renders with `displays` order
   preserved. The selected row is `OutputTargetSettings.externalDisplayId` if
   present in the list, otherwise the first `isPrimary` display, otherwise the
   first element (BR-U8-07). Selection is **not** written to settings merely by
   being displayed — only by an explicit user tap (BR-U8-07).
5. On tap of a different row: persist `externalDisplayId`; if the mode is
   already active, the target is re-opened on the new display in one step
   (close then open inside the critical section; BR-U8-01's re-open branch).

The list updates live while the section is mounted: a new display appears in
the list without a remount; a removed display disappears. If the removed
display was the selection, F-8.5 applies.

---

## F-8.3: Enable / disable external display output (S-20 AC2, AC4)

`ExternalDisplayControls`' toggle writes `overlayEnabled` through
`OutputTargetSettingsNotifier.update(...)`. `ZbAppShell` already listens to that
notifier and calls `_syncOverlay` (`zb_app_shell.dart:85-90,199-201`); this unit
extends `_syncOverlay` rather than adding a second listener.

Enable (`overlayEnabled` false → true, no mode currently open):

1. `ZbAppShell` sees the change and calls the controller, which (in order)
   acquires the open guard, closes any other open mode, resolves the target
   display (F-8.5 step 1's resolution rule), builds `OverlayWindowLaunch`
   (`ExternalDisplayMode`, `OverlayConfig`, the current
   `CaptionOverlaySnapshot`), calls `DesktopWindowService.createWindow(json)`,
   and applies the frame with
   `WindowController.fromWindowId(id).setFrame(bounds)` (and
   `resizable(true)` on macOS — `domain-entities.md` § `DisplayInfo.bounds`
   note; the plugin's `resizable` is macOS-only).
2. `CaptionOverlayTarget` is registered on the registry (the shell's existing
   `_registry.add` path) **after** the window exists, so a failure never leaves
   a registered target pointing at no window.
3. The sub-engine runs `OverlayWindowEntry` → `OverlayWindowApp` → renders the
   snapshot and starts listening for `captionUpdate` (F-8.7).
4. `CaptionOverlayTarget.onCaptionEvent` pushes a fresh snapshot on every
   `SttResultEvent`, debounced per animation frame (F-8.7 step 4). While no
   caption event arrives, no message crosses the boundary.

Disable (true → false):

1. `_syncOverlay`'s existing branch runs: deregister the target, clamp the
   controller, `DesktopWindowService.closeWindow(id)` (the shipped
   `hide()` call is the close), clear controller state, emit no event (a
   caller-initiated close is not a `WindowClosed`).
2. `await hide()` completes before the toggle's future completes; the UI's
   switch reflects the awaited result, not an optimistic guess.

Captioning continues across both transitions untouched: the overlay is a
reader of `OnScreenCaptionTarget`, never a participant in
`BroadcastRecordingNotifier` (AC "works signed-out" and "no account required"
follow from the same fact — no new auth path exists, `business-rules.md`
BR-U8-14).

---

## F-8.4: Live capture into the window (BR-U8-12, BR-PIP-05)

1. `CaptionOverlayTarget.onCaptionEvent(SttResultEvent)` → the existing
   `_isVisible` guard → build `CaptionOverlaySnapshot` from
   `ref.read(onScreenCaptionTargetProvider)`'s `visibleCaptions` split into
   `entries` (final) and `interim` (the trailing non-final entry, already
   rendered at 0.8 opacity by the shipped widget).
2. `styles` is read from `audioInputSettingsProvider` once per target
   activation and refreshed on the same notifier events the recording screen
   watches; `settings` is read from `displaySettingsProvider` on every snapshot
   so a font-size or theme change reaches the window without a reopen.
3. `SessionStateEvent` does **not** produce a snapshot. The window keeps the
   last content, exactly as the main window's `CaptionDisplayWidget` does
   until its buffer is cleared (Phase 1 BR-U3-05). Closing on stop is F-8.6.
4. Only `SttResultEvent` — never `SessionStateEvent` payloads, never `null`.

This is the only producer of `captionUpdate`. The Phase 1 `{'text','isFinal'}`
map is replaced (compatibility note in `domain-entities.md`).

---

## F-8.5: Display disconnect and fallback (S-20 AC5; FR-9.4)

`DisplayEnumerator.changes` is the only trigger. The main engine's controller
is subscribed for the lifetime of the controls provider and for the lifetime of
an open window; a disconnect is handled as follows.

**Step 1 — decide the destination** (pure function, unit-testable):

```
resolveTarget(changed, selectedId, preferredPopOutDisplayId, windowMode) ->
    if changed contains selectedId           -> WindowTarget(selectedId)
    else if any isPrimary                    -> WindowTarget(primaryId)    [fallback]
    else if changed is non-empty             -> WindowTarget(changed.first) [fallback]
    else                                     -> NoDestination

resolveTarget is also used at open time (F-8.3 step 1) with the empty-result
branch replaced by "primary if known, else fail with OpenFailed".
```

**Step 2 — external display mode, window open, selection vanished:**

1. Controller state → `ExternalDisplayLost(displayId)` **and** keeps
   `DeletedDisplayId` for the UI.
2. `CaptionOverlayTarget` emits `DisplayLost(displayId)`; the shell shows the
   Proto-13 disconnected notice (a `SnackBar` in the recording screen's
   Scaffold and the inline banner in `ExternalDisplayControls`; the shell
   posts a `MaterialBanner`-equivalent through the same
   `ScaffoldMessenger` mechanism the existing browser-source failure uses,
   `zb_app_shell.dart:139-147`).
3. If `resolveTarget` returned a destination (BR-U8-06: always the primary
   when one exists), the controller **moves** the window: `setFrame` to the
   destination's bounds in the same critical section, updates
   `externalDisplayId` to the fallback id, and state → `ExternalDisplayActive(
   displayId: fallbackId, isFallback: true)`. One window exists throughout; no
   second window is created, so no orphan is possible.
4. If no destination exists (every display gone), state → `ExternalDisplayLost`
   with no move; the window's position is whatever the platform leaves it at.
   A later display appearance (monitor reconnected) re-enters step 1 and
   restores the user's persisted choice if it is present again (BR-U8-07).

**Step 3 — pop-out mode, window open, its display vanished:** the pop-out is
not tied to a display for correctness, only for its initial centre. It stays
where it is, the mode stays on, and the only change is that a future re-centre
uses the new `resolveTarget` result. No notice is required by §8 for this
path (items 16-17 cover close, not display loss).

**Step 4 — window open, selection vanished, then a second disconnect occurs
before the user acts:** step 2 runs again against the new list. It is
idempotent because the destination resolution is a pure function of the current
list and the current persisted selection.

**Not a trigger:** window focus, window movement, the main window's display
changing. Only `changes` emits.

---

## F-8.6: Close on disable, stop, or OS close (S-20 AC4; UX-PIP; BR-U8-10)

Three close paths, all ending in the same `closeWindow` + released-resources
state, differing only in who initiated it and what is emitted.

| Path | Trigger | Who closes | Emitted | Persisted change |
|---|---|---|---|---|
| A. User disables | Toggle, `overlayEnabled` false | Shell `_syncOverlay` | none | `overlayEnabled = false` |
| B. Captioning stops | `BroadcastRecordingNotifier` reaches `BroadcastStoppedState`, or `clearSession()` reaches idle | Shell listens to the same notifier it already watches (`zb_app_shell.dart:190-193`) | none | `overlayEnabled = false` (external display only) |
| C. OS close button | The sub-window's own close | Platform → controller notices the window is gone | `WindowClosed` | `overlayEnabled = false`, `popOutEnabled = false` |

Path B is the S-20 AC "when the broadcaster disables the output **or stops
captioning**". It is a *settings write*, not a direct window call: the shell
writes `overlayEnabled = false`, and path A does the work. This keeps one close
implementation.

Path C has no reliable cross-platform close callback inside
`desktop_multi_window` 0.2.1: `WindowController` has `show`/`hide`/`close` and
no `onClose`. The controller therefore detects it the way a window manager
does — by the *next* interaction that touches the window (a `captionUpdate`
`invokeMethod` throwing `MissingPluginException`/`PlatformException`, or a
`setFrame`/`close` on a dead id) — and converts that failure into
`WindowClosed`. To make detection timely rather than dependent on the next
caption, the controller schedules a one-shot **presence probe** after each open
and after each closed-window event: `invokeMethod(id, 'ping', null)` handled by
`OverlayWindowEntry` with a constant ack (no payload). The probe is a plugin
round-trip, not a poll loop; it fires once per open and on failure emits
`WindowClosed`. The exact probe cadence is settled in Infrastructure Design
(ID-4) with the platform evidence for Linux.

Whichever path runs, the settled state is checked by one invariant
(BR-U8-15): `popOutEnabled || overlayEnabled` is `false` implies the controller
holds no window id, `CaptionOverlayTarget.isVisible` is `false`, and the target
is not on the registry. The three are asserted together in the shell's dispose
and in the controller's post-close path.

---

## F-8.7: The secondary-window entry point and render loop

Detailed as Infrastructure Design ID-1/ID-2 (entry point) and here for the
logic:

1. The secondary engine starts in the same `main.dart`. `main(List<String>
   args)` checks `args.length >= 3 && args[0] == 'multi_window'` (the plugin's
   documented argument shape) and, if so, calls `overlayWindowMain(args)`
   instead of the app's normal startup. It must **not** initialise Supabase,
   logging handlers for the app, or the broadcast chain in that engine.
2. `overlayWindowMain` decodes `args[2]` as `OverlayWindowLaunch`. A decode
   failure renders a fixed "Window unavailable" frame, logs
   `invalid_window_arguments`, and installs nothing else.
3. `OverlayWindowEntry` wraps `OverlayWindowApp` in a `ProviderScope`
   containing only the providers the render path needs
   (`displaySettingsProvider` seeded from the snapshot, a snapshot
   `StateNotifier`), plus `DesktopMultiWindow.setMethodHandler` for three
   methods: `captionUpdate` (decode a `CaptionOverlaySnapshot`; bad decode is
   logged and ignored, never a crash), `ping` (ack), and nothing else. An
   unknown method returns `null` rather than throwing.
4. Rendering uses the shipped `CaptionDisplayWidget` with the snapshot's
   `entries`/`interim`/`settings`. Per-input styles are applied by the same
   `sourceId` → `AudioInputVisualStyle` rule the recording screen uses,
   reading `styles` from the snapshot instead of the settings provider.
   Contrast is the `AppTheme` surface/onSurface pair, whose AAA ratio is
   already asserted in `zip_core/test/pbt/theme_contrast_test.dart`
   (dark 0xFFDAE3F0 on 0xFF0B141D; light 0xFF0B141D on 0xFFFAFCFF), and the
   overlay adds its own assertion (S-20 AC, NFR-5.1).
5. The window is borderless in the sense S-20 uses: no app chrome, no
   toolbar, no menu; the platform title bar decorations remain as
   `desktop_multi_window` creates them (see Infrastructure Design ID-5 for the
   three platforms' evidence and the macOS option). No hand-written HTML, no
   second Flutter view, no `HtmlElementView` on any platform (binding
   decision, `pip-ux-parity.md` §8.6).

---

## F-8.8: Pop-out mode (UX-PIP-01..11, BR-PIP-01..14, §8.8 items 1-18)

The pop-out is `OverlayWindowMode.PopOutMode` on the same controller. This
section maps the binding contract onto the V2 surface; it does not restate it.

| Contract | In this unit |
|---|---|
| UX-PIP-01 primary toggle | `PopOutToggle` in `ZbAppShell`'s app bar and nav rail (two shells: `ZbNavRail` host and the AppBar host) |
| UX-PIP-02 secondary toggle usable from inside the pop-out | The pop-out renders `PopOutToggle` inside `OverlayWindowApp`; it sends `popOutToggle` to the main engine via `DesktopMultiWindow.invokeMethod(0, 'popOutToggle', null)`, which the main engine handles by toggling the same settings field. This is the only inbound control message in the design. |
| UX-PIP-03 conditions | Platform capable (same `isSupported`), caption surface exists (always true in this app — the recording screen always builds one), session active or already popped out (`BroadcastRecordingNotifier` is `Active`/`Paused`/`Reconnecting`, or `popOutEnabled`) |
| UX-PIP-04 unsupported | `PopOutToggle` returns `SizedBox.shrink()` — no disabled control |
| UX-PIP-05 hint and return | `PopOutHint` in the main window (a `MaterialBanner` in the shell) with a "Return to window" action that disables pop-out; clears on close by any path (BR-PIP-03) |
| UX-PIP-06 content setting | `PipContent` three-way enum persisted in settings (`original`/`translated`/`both`). **Translation does not exist in Phase 2**: the enum, its three labels, and its persistence ship; while translation is off (always, today) the window shows originals (BR-PIP-06) and the setting is stored for the future translation unit. §8.8 item 8 requires "offers all three options", which this satisfies; item 8's "applies only while translation is on" is vacuously true. |
| UX-PIP-07 controls inside pop-out | Orientation toggle, pane swap, translation target select, download progress: **none of these exists in Phase 2**. Phase 1 has a single caption pane (`CaptionDisplayWidget`), one language, no download. §8.8 item 10 lists them as must-function; §8.6/§8.9 do not defer item 10, but the features it names are not in the Phase 2 product. This is a **gap recorded as an open question (OQ-2)**, not silently dropped: the pop-out ships with the toggles that do exist (primary/secondary toggle, theme, content setting), and item 10 is flagged for the unit that adds those controls. |
| UX-PIP-08 drawer | Opening pop-out closes the `ZbNavDrawer` if open (shell's `ScaffoldState.closeDrawer()`) |
| UX-PIP-09 theme | `OverlayWindowApp` reads `settings.themeModeSetting` from each snapshot and applies `AppTheme.light/dark`; live because every snapshot carries it |
| UX-PIP-10 size | 640x320 default, `popOutSize`, resizable with `popOutMinimumSize`; the plugin's default style mask includes `.resizable` on macOS and the Windows/Linux runners are resizable |
| UX-PIP-11 always on top | `desktop_multi_window` 0.2.1 does **not** expose an always-on-top switch. See Infrastructure Design ID-5 (macOS: `NSWindow.level` in our runner; Windows: `SetWindowPos(HWND_TOPMOST)`; Linux: WM hint — needs a native patch or an additional plugin, which is a new dependency and therefore an open question, OQ-1). |
| BR-PIP-01/02 | One window, open guard (F-8.1) |
| BR-PIP-03 | Close by any path → `popOutEnabled = false`, hint cleared (paths A/B/C above) |
| BR-PIP-04 | Pop-out never touches `BroadcastRecordingNotifier` |
| BR-PIP-05 | The snapshot is the live buffer, never a copy taken at open |
| BR-PIP-06/07 | Content setting applied in `OverlayWindowApp` only when translation is active; independent of any in-window layout mode (there is one pane) |
| BR-PIP-08 | Split arrangement: not applicable in Phase 2 (no split mode); when it exists, the pop-out reuses the same settings — recorded for that unit |
| BR-PIP-09 | Live setting update: every snapshot carries `settings` and `content`; no reopen |
| BR-PIP-10 | `popOutEnabled` is persisted but never auto-opened: `main.dart` does not start the controller until the shell mounts and the user has a session (BR-U8-16) |
| BR-PIP-11 | No caption text in logs: BR-U8-18 applies to every path above |
| BR-PIP-12/13/14 | Visibility = capability (UX-PIP-04); disabled + reason = no active session (`PopOutToggle`'s disabled state with tooltip "Start captioning to pop out") |

§8.8 items 1-3, 5-11, 14, 18 are unit-/widget-testable and appear in the Code
Generation test list. Items 4, 12, 13, 15, 16, 17 are manual/Unit 9 per §8.8's
own split; this unit adds *code paths and widget tests* for 12/13/16 where a
fake can observe them, and leaves 15 to Unit 9 with ID-5 recording exactly what
is and is not implemented on each platform.

---

## F-8.9: Web

`DesktopWindowService.isSupported` is `false` on web (shipped stub). F-8.2
step 1 therefore reaches `ExternalDisplayUnsupported` before any enumeration,
and the controls render nothing. `PopOutToggle` renders nothing on web in this
unit. The Document Picture-in-Picture path is **not implemented**: §8.6
permits it and the binding decision states the web mechanism, but S-20 excludes
web from external display and §8.10's AC set is not web-specific; implementing
a separate web rendering pipeline is a phase-sized change with no Phase 2
target. Recorded as OQ-3 (a scope question for the run, not a design
ambiguity), with the gate respected by hard-excluding web in this unit's
tests.

---

## Event → state table (single reference for F-8.5 and F-8.6)

| Current | Event | Next | Side effect |
|---|---|---|---|
| any | `isSupported == false` | `Unsupported` | section hidden |
| `Idle` | toggle on | `Active(null→resolved)` | create window, register |
| `Active` | toggle off | `Idle` | close, deregister |
| `Active` | display list loses selection | `Active(fallback, isFallback)` | `DisplayLost`, `setFrame` |
| `Active` | display list loses selection, list empty | `Lost` | `DisplayLost`, no move |
| `Lost` / `Active(fallback)` | original display returns | `Active(original, false)` | `setFrame` back |
| `Active` | create throws | `Failed` | `OpenFailed`, `overlayEnabled=false` |
| `Active` | OS close detected | `Idle` | `WindowClosed`, `overlayEnabled=false` |
| any | stop captioning | `Idle` | path B |
| `NoDisplays` | first display appears | `Idle` | list renders |