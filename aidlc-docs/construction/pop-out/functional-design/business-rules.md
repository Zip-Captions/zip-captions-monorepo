# Business Rules — Unit 8.1: Pop-out Live Captions (S-21)

**Status**: APPROVED 2026-10-21 by James Petersen (revised after the pre-build review: RQ-1 A / RQ-2 A / RQ-3 A-amended; revision 2 same day).
**Convention**: `BR-PIP-xx` numbers are the contract's own (`pip-ux-parity.md` §8.4). `BR-U8.1-xx`
are this unit's refactor/promotion rules, which the contract does not cover.

---

## Part 1 — The pop-out's user-visible rules

These restate `pip-ux-parity.md` §8.4 in terms of the promoted machinery. Where a rule is
satisfied by shipped Unit 8 behaviour, the mechanism is named instead of being re-specified.

### BR-PIP-01 — One pop-out window
At most one pop-out exists, and it is a distinct window from the external display window.
**Mechanism**: one `OverlayWindowController` per engine, whose `Opening`/`Open` guard refuses a
second `createWindow`; the two modes use **two** controllers in the main engine (one per mode),
because the external display window and the pop-out may be open simultaneously and are separate
windows. Each controller still owns at most one window. `OverlayWindowMode` distinguishes them;
`DesktopMultiWindowService` is per-controller, and the **enumerator is shared** by both controllers
and both window services (one platform observer, owned by the provider, never disposed by a
controller) — see `business-logic-model.md` §4.1 and NFR-R §10.1. Corrected 2026-10-21 (R-m2): the
earlier "each per-controller" sentence contradicted that decision.

**Consequence to verify**: `overlayMethodHandlerInstaller` wraps a **single static**
`DesktopMultiWindow.setMethodHandler` slot. Unit 8's rule "exactly one handler owner" therefore
becomes "one handler dispatcher for both controllers, installed once before the first
`createWindow` of either, uninstalled only when both are disposed." The current installer's
contract (installed by the controller, uninstalled by it) cannot be duplicated across two
controllers without the second installation silently replacing the first. See
`business-logic-model.md` §4.1 for the chosen resolution and `BR-U8.1-04` for its constraint.

### BR-PIP-02 — Toggle is idempotent
A second activation while an open is in progress does nothing.
**Mechanism**: the controller's `open()` returns early when `_status is Opening || _status is
Open` (shipped). No `isOpening` flag is added in the UI (Q5 A). The toggle's onPressed is not
disabled during `Opening`; a press during it is a no-op by the controller, and the control already
shows "Exit Picture in Picture" as soon as the state is `Opening`, so the user gets feedback
without a second window.

### BR-PIP-03 — Closing by any means leaves a coherent state
Closed by the toggle, the OS close button, or an open failure, the main window clears the hint and
resets the toggle.
- Toggle-off: `close(reason: CloseReason.toggleOff)` → `Off` → shell writes `popOutEnabled=false`.
- OS close, primary path: the runner raises `subWindowClosed {windowId}` on a **first-party
  channel registered on the main engine** (not `desktop_multi_window`'s internal window channel,
  which is plugin-private), the main-engine Dart seam delivers it to
  `controller.onNativeWindowClosed(windowId)` (RQ-3 A as amended 2026-10-21, transport corrected
  2026-10-21) → `WindowClosed` → shell writes `popOutEnabled=false` in the same frame. Raised for
  every sub-window including the external display; an id that does not match the open window is
  dropped, which also drops app-initiated closes because `_takeWindow()` nulls the id first.
- OS close, fallback: the `'-1'` window-call seam → `WindowClosed` → shell writes
  `popOutEnabled=false` (shipped, unchanged). Lazy: it fires on the next window call, which may not
  come while paused or idle (R-M6).
- Open failure: `OpenFailed` → shell writes `popOutEnabled=false` and renders `popOutOpenFailed`
  **next to the chrome toggle while the status is `Failed`**, not in the banner (R-M8, corrected
  2026-10-21: the banner is not visible once `popOutEnabled` is false).

**No persistence** (Q10 B), so no settings read-back can contradict what the user sees.

### BR-PIP-04 — Recognition continues uninterrupted
**Mechanism**: the pop-out is a second `CaptionOutputTarget`; adding and removing it from the
registry never touches `RecordingStateNotifier`, the STT session, or the camera-less audio path.
No new rule is needed; the unit's tests assert the recording state is unchanged across
toggle-on / toggle-off.

### BR-PIP-05 — Content is live, not copied
**Mechanism**: `PopOutCaptionTarget.onCaptionEvent` reads `OnScreenCaptionTarget.visibleCaptions`
on every event and pushes a snapshot, exactly as `CaptionOverlayTarget` does. No snapshot is
taken at open time beyond the launch's first frame, which the controller refreshes on the first
event.

### BR-PIP-06 — The content setting applies only while translation is on
**Deferred**: translation is Phase 8. In Phase 2 every snapshot carries
`PopOutContentMode.originalOnly`, and the window renders original captions. The rule is recorded
as satisfied by construction, not claimed as tested.

### BR-PIP-07 — Content setting independent of in-window layout mode
**Deferred** with BR-PIP-06 (§8.8 item 8). The wire field is independent of `DisplaySettings`, so
the Phase 8 implementation cannot couple them accidentally.

### BR-PIP-08 — Split in the pop-out uses the main window's orientation
**Deferred** with BR-PIP-06/07 (§8.8 item 10). The pop-out renders exactly one caption surface
with the main window's `DisplaySettings`, so orientation and scroll direction already mirror it;
the split/bilingual layout is Phase 8's.

### BR-PIP-09 — Live update on setting change
**Mechanism**: every snapshot carries the current `DisplaySettings`, read from the provider on
every caption event (Unit 8's `CaptionOverlayTarget` does this today). The pop-out's
`themeModeSetting` additionally drives its own `MaterialApp`'s `themeMode`, so a theme change
reaches the window on the next frame. Text size, font, scroll direction and max lines reach it
the same way. **No reopen.**

### BR-PIP-10 — No persistence across launches
Q10 B: the popped-out state, size and position are not persisted at all. A relaunch never opens
the pop-out. Remembering size/position (§8.9 "permitted, not required") is not implemented.

### BR-PIP-11 — No caption content in logs or telemetry
**Mechanism**: the promoted controller's logs carry fixed strings plus `runtimeType` (Unit 8's
BR-U8-18 discipline, unchanged). New log sites in this unit: the `WindowConfigurator` failure
(fixed string + `runtimeType`), the shell's pop-out toggles (no logging at all), and
`PopOutCaptionTarget` (no logging). The window entry's "dropped update" warning stays as shipped
and carries no payload.
**Test**: a record-level redaction audit in each app, mirroring Unit 8's, driving toggle-on,
toggle-off, OS-close, open-failure and a caption update through an in-process bus.

### BR-PIP-12 — Window capability and recognition capability are separate gates
**Mechanism**: capability = the controller's `Unsupported` state (which the pinned service derives
from `Platform.isMacOS || isWindows || isLinux`); availability = the session/engine rule in
`domain-entities.md` §3.1. The table there is the normative rendering of this rule.

### BR-PIP-13 — Recognition unavailability is a disabled state, not a hidden one
**Mechanism**: the app's own engine gate (RQ-2 A, corrected 2026-10-21) disables the toggle and
renders `popOutUnavailableNoEngine` next to it — `broadcastEngineAvailableProvider` in Zip Broadcast
(the audio-source/factory path, which `sttEngineRegistryProvider` never feeds) and
`captionsEngineAvailableProvider` (`sttEngineProvider != null`) in Zip Captions. The control is
never hidden for this cause. The earlier "empty registry" rule was unachievable in Zip Broadcast and
would have disabled the pop-out on every machine (R-M1).

### BR-PIP-14 — No feature exists for users who cannot perform speech-to-text
Restated, not implemented: the gate is "is there caption content to show", not "how was it
produced". No manual-text-entry source is added.

---

## Part 2 — Refactor and promotion rules (this unit's own)

### BR-U8.1-01 — The external display must behave exactly as it did before the move
Every Unit 8 test that covers the machinery moves to `zip_core` and must pass with **only import
path changes**. A test that cannot move is reported and stopped on, never deleted or weakened. The
acceptable reasons for a test to change shape are enumerated in `business-logic-model.md` §7, and
each one requires a note in the code summary.

### BR-U8.1-02 — `zip_core` stays platform-agnostic
`desktop_multi_window` is imported only by `_io` files selected through a conditional export. No
`dart:html` anywhere. The two apps never import the plugin directly. `window_manager` is not a
dependency at all (RQ-1 A, 2026-10-21).
**Verification**: `rg -l "package:desktop_multi_window|package:screen_retriever" packages/zip_core/lib`
returns exactly the expected `_io` files (plus their stub/export siblings, which import nothing);
`rg -l` over each app's `lib/` returns nothing; `rg window_manager` over all three packages returns
nothing.

### BR-U8.1-03 — One implementation of the machinery
No controller, codec, mode hierarchy, entry contract, bridge, window service or enumerator exists
in an app after this unit. The only per-app duplicates are the ~60-line caption-bus adapters
(`CaptionOverlayTarget`, `PopOutCaptionTarget`), the toggles, and the ARB keys (Q5 A, Q12 A).

### BR-U8.1-04 — One method-handler owner per engine, across both modes
`DesktopMultiWindow.setMethodHandler` is a single static slot. The promoted installer contract is
narrowed to: **install once per engine before the first window of any mode; uninstall only when no
controller remains.** The controller keeps its `OverlayMethodHandlerInstaller?` seam (so tests can
inject a fake) but production passes an installer **closure bound to that controller's token**
(`OverlayMethodRouter.installerFor(token)`), so the controller's existing `dispose()` call with
`null` removes exactly its own handler. Dispatch is by window id, never by "who recognises the
method" — the handler returns `Future<void>`, so no verdict exists to consult (R-M3). A controller
must still fail closed (`create_failed`) when the installer is `null` (Unit 8 R6), which the router
satisfies by never returning `null` in production.

### BR-U8.1-05 — A window's own settings are applied inside the engine that owns it
Every pop-out window property (floating, decoration, minimum size) is applied from the pop-out
sub-engine's own isolate, through the per-runner `configure` channel, never from the main engine.
The sub-engine passes the window id it was launched with, because the native callback cannot know
it (RQ-1 A, 2026-10-21: `window_manager` was removed for exactly this reason — its macOS
`ensureInitialized` replaces `desktop_multi_window`'s window delegate, R-B2).
**Verification**: `overlayWindowMain` awaits `configure` inside the sub-engine before signalling
ready (once, not twice — R-M9); the main engine never calls it. A Unit 9 manual check confirms the
result (§8.8 item 15).

### BR-U8.1-06 — The sub-engine never initialises app services
`zip_captions`'s `main(List<String> args)` must route the overlay launch **before** Google Fonts
configuration, logging setup, `SharedPreferences`, and `Supabase.initialize`, mirroring
`zip_broadcast`'s shipped ordering. The window is a caption surface, not an app.
**Verification**: a unit test on the launch predicate plus a `main`-shaped test that asserts no
Supabase initialisation happens on the overlay path (a faked `Supabase` call counter, as
`zip_broadcast`'s own `app_test.dart` does if it has one; otherwise an extractable
`runMain(List<String> args, {required Future<void> Function() runApp})` seam).

### BR-U8.1-07 — The pop-out control exists in both apps or the unit is not done
§8.8's "per-app evidence is required" is binding: item 1 in Zip Captions and item 1 in Zip
Broadcast are two separate checks. The unit's code summary carries one row per app per claimed
item.

### BR-U8.1-08 — The codec stays total and versioned
The mode extension does **not** bump `supportedVersion` (the payload is additive and v1 has never
shipped to a receiver that lacks the field — Unit 8 shipped within the same unreleased v2.0 line,
and both senders and receivers change together in one commit). A v1 payload without
`config.mode` still decodes as `ExternalDisplayMode` (backwards-readable), and an unknown mode
token returns `null` (fail closed). Malformed, oversized and unknown-version payloads still
return `null` and never throw.

### BR-U8.1-09 — The window never shows caption text in its title or error pages
The pop-out window carries no title-bar caption text; its `MaterialApp` has no `title` derived
from captions. The `OverlayWindowUnavailableApp` fixed frame remains caption-free.

### BR-U8.1-10 — Deferred items are recorded, not claimed
§8.8 items 8-10 are deferred to Phase 8 (translation). Items 4, 12, 13, 15, 16 and 17 are Unit 9
platform checks per §8.8's own partition. The code summary carries a table with one row per item,
its status (`tested` / `platform-check (Unit 9)` / `deferred (Phase 8)`), and per-app evidence
where §8.8 requires it.

### BR-U8.1-11 — Platform scope is desktop only
macOS, Windows and Linux. Web is excluded: the pop-out control is not shown on web, because the
shipped `DesktopMultiWindowService`'s `isSupported` is false there, so the controller reports
`Unsupported` and UX-PIP-04 hides the control. Document Picture-in-Picture is Phase 5 and nothing
in this unit builds toward it.

### BR-U8.1-12 — Linux always-on-top is the window manager's to enforce
§8.6 requires verification during Infrastructure Design, not an assertion in code.
`gtk_window_set_keep_above` is a hint: under a tiling or otherwise uncooperative WM it may be
ignored. The unit claims the call is made; Unit 9 claims the visible result on a real desktop.
Infrastructure Design records which desktops were reasoned about and what remains a manual check.

---

## Part 3 — Rules that deliberately did **not** change

| Rule | Why untouched |
|---|---|
| Unit 8's BR-U8-01..26 | They describe the external display. Their tests move and must keep passing (BR-U8.1-01). No BR-U8 rule is reworded by this unit. |
| D-1..D-13, B-1..B-9 (PR #37 review) | Binding on Unit 8's shipped behaviour; the promotion preserves them. |
| ADR-006/008 caption bus contract | The pop-out is another `CaptionOutputTarget`; nothing about the bus changes. |
| `CaptionDisplayWidget`'s existing API | Only an optional `controls` parameter is added (Q6 A); the required parameters and rendering behaviour are untouched. |