# Handoff: Functional Design -> NFR Requirements
**Unit**: 8.1 Pop-out Live Captions (S-21)
**Date**: 2026-10-21

## Decisions Made
- Q1: `PopOutMode` (field-less) is a sibling of `ExternalDisplayMode`; codec encodes `'popOut'` and decodes both modes. No version bump (BR-U8.1-08).
- Q2: all machinery moves to `zip_core/lib/src/output/overlay/`, exported via a new `overlay.dart` barrel; plugins only in `_io` files behind the existing conditional-export shape.
- Q3: `OverlayConfig`/`OverlayPosition` move to `zip_core`; `zip_broadcast`'s two model files become one-line `export` shims (the only permitted shim).
- Q4/BR-U8.1-05 (**amended 2026-10-21, RQ-1 A**): `WindowConfigurator` in `zip_core`'s `_io` calls a first-party per-runner `configure` method channel inside the sub-engine, before ready, applying floating + decoration + minimum size; failure is caught and never turns into `OpenFailed`. `window_manager` is **not** a dependency. The OS-close notification is raised **natively in the runner** to the **main** engine as `subWindowClosed {windowId}` on a first-party channel (see Revision 2 — revision 1's `popOutClosed` on the plugin's window channel was not implementable); `'-1'` remains the fallback.
- Q5: idempotence is the controller's `Opening`/`Open` guard; no UI flag. One thin `PopOutCaptionTarget` per app.
- Q6: `CaptionDisplayWidget` gains an optional `Widget? controls`, default `null`.
- Q7: chrome toggle in both app shells (AppBar action narrow, rail header wide), in-surface toggle via `controls`, hint as an inline banner above the caption surface.
- Q8: active = `RecordingActiveState`/`PausedState`/`ReconnectingState`; engine-unavailable = empty `SttEngineRegistry`. Two disabled reasons, both visible text.
- Q9 (amended by the project owner, 2026-10-21): default geometry = 75% of the active display's work-area width, height = two rendered caption lines plus the toggle row, bottom-anchored, min 320x96, resizable, decorated. **This amends `pip-ux-parity.md` UX-PIP-10 and §8.8 item 13** — the Documentation Refinement stage must apply that amendment with the owner's name and date.
- Q10: no persistence of pop-out state, size or position.
- Q11: claim §8.8 1-7, 11-14, 16-18; record 8-10 deferred (Phase 8/translation) and 4/12/13/15/16/17 as Unit 9 platform checks.
- Q12: delete `zip_broadcast`'s moved files; rewrite imports.

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
| `OverlayWindowController` | moved, unchanged + `_isPopOut` guards | must not gain a second window; two controllers per main engine, one per mode |
| `OverlayMethodRouter` | NEW | one `setMethodHandler` slot across both controllers (BR-U8.1-04) |
| `PopOutMode` | NEW sealed sibling | codec token `'popOut'`, no fields |
| `PopOutContentMode` | NEW enum on `CaptionOverlaySnapshot` | wire-only in this unit; picker deferred to Phase 8 |
| `PopOutGeometry` / `computePopOutFrame` | NEW pure functions | Q9 amended numbers; text-scaler aware |
| `WindowConfigurator` | NEW seam, `_io`/`_stub` | first-party `configure` channel; no plugin import |
| `popOutAvailability` | NEW pure function in `zip_core` | single source of the UX-PIP-03 matrix |
| `PopOutWindowBody` | NEW widget in `zip_core` | no ARB dependency; injected copy |
| `OverlayWindowUnavailableApp` | changed | takes the unavailable copy as a parameter (removes the last ARB dependency from `zip_core`) |
| `OverlayWindowBridge.sendPopOutToggle` | NEW method | `'popOutToggle'` to window 0; main engine routes to the shell |

## Constraints
- `zip_core` gains `desktop_multi_window`, `screen_retriever`, `window_manager`; the apps declare only `desktop_multi_window` (and `zip_broadcast` may drop `screen_retriever`). NFR Requirements must decide whether the apps keep direct `window_manager` declarations (design says no: no Dart call site).
- No new native code; runner edits are callbacks/registration only.
- Caption text never in logs; the promoted code already honours this and new sites must too.
- Deferred, not claimed: §8.8 8-10; `PopOutContentMode` picker; size/position memory; web.
- The `pip-ux-parity.md` UX-PIP-10 amendment is pending Documentation Refinement, not this unit's code.

## Open Questions for Next Stage
- Test seam for the window configurator: is a fake sufficient, or does NFR Requirements want a "reports unsupported" variant to model Linux WMs that ignore keep-above? (source: BR-U8.1-12) — **resolved**: a fake that can be told to throw, per NFR-R §1.2; the WM-ignores-keep-above case is a Unit 9 platform check, not a test double.
- Whether the pop-out's `PopOutCaptionTarget` duplication across the two apps is acceptable under the quality rules, or NFR Requirements wants one shared adapter class taking an injected buffer reader. (source: Q5 A vs BR-U8.1-03)
- How the `zip_captions` main-entry routing (BR-U8.1-06) is proven without initialising Supabase in a test. (source: no existing `main`-shaped test in `zip_captions`)
---

## Revision 2026-10-21 (post pre-build review)

FD and NFR-R were amended in place after the owner answered RQ-1 A / RQ-2 A / RQ-3 A (amended).
This section supersedes anything above that contradicts it.

### Decisions changed
- **No `window_manager`.** Pop-out window properties are applied by a first-party `configure`
  method channel registered in the existing `desktop_multi_window` window-created callback on each
  runner. Rationale: R-B2 (delegate replacement kills OS-close detection and leaks an engine) and
  R-B3 (the plugin cannot restore decoration). `RegisterGeneratedPlugins` in the callback is
  forbidden (R-B1). SECURITY-10 record retired; no tech-spec §6 row added.
- **Engine gate**: each app's own Start-Captioning gate, not `sttEngineRegistryProvider` (R-M1).
- **Close detection**: native, in the runner, delivered to the **main** engine (RQ-3 amended).

### Constraints for NFR Design (do not re-derive)
- Mode is fixed at construction; `open(config, frame:)` takes the shell-computed frame (R-M5).
- Six `_isPopOut` display guards are mandatory (R-M2); NFR-R §10.2's "null id is inert" is withdrawn.
- Router routes by window id with token-bound installers (R-M3); handler returns `Future<void>`, so
  "stop after the first that recognises" does not exist.
- `controls` renders **outside** the scrolling list (R-M4).
- Failure copy renders next to the chrome toggle while `Failed`, not in the banner (R-M8).
- Overlay barrel is `package:zip_core/overlay.dart`, **not** re-exported from `zip_core.dart` (R-M7).
- `_bootstrap` must not require a display for `PopOutMode`; `StoppedState` also mixes
  `ActiveSessionState`, so `popOutAvailability` tests the three concrete states (R-m3).

### Claims to verify in Infrastructure Design, not assume
- That a Dart message from the sub-engine at close time is lost.
- macOS notification delivery point relative to `deinit`; Windows delegate ordering against
  `HandleTopLevelWindowProc`; Linux `delete-event` handler order (the plugin's handler returns `TRUE`
  after destroying, so a later connection never runs).
- Every runner callback signature and the sub-engine `argv` delivery (`["multi_window", id, args]`).
- Flutter SDK version: CI pins 3.38.7, while Unit 8's ID cited 3.41.7 (R-m6).

## Revision 2 — 2026-10-21 (owner request changes)

Supersedes the RQ-3 transport in Revision 1 and pins the router API.

1. **Close transport (was wrong).** `desktop_multi_window`'s window channel is plugin-internal
   (macOS `WindowChannel` is not `public`; Windows/Linux expose only the plugin header), so a runner
   cannot emit on the main engine's window channel and the event cannot reach
   `OverlayMethodRouter`/`_handleWindowCall`. Now: each runner registers a first-party channel on the
   **main** engine (`subWindowClosed {windowId}`); a `zip_core` `SubWindowClosedChannel` seam
   (`_io`/`_stub`, injectable) feeds one new public entry `controller.onNativeWindowClosed(int)`,
   which maps to `CloseReason.windowClosed` on an id match and drops otherwise. Raised for every
   sub-window including the external display (Unit 8 improvement, not a state change). App-initiated
   closes are dropped by the id check (`_takeWindow()` nulls the id first, `:528-533`). Permitted
   deviation under BR-U8.1-01.
2. **Router API pinned.** `windowIdOf` returns `int?`; the controller exposes `int? get windowId`
   (permitted deviation); the token-bound installer is still called at `_bootstrap` (`:191`) — the
   "register after `createWindow`" sentence is deleted; the router dispatches only when
   `windowIdOf() != null && windowIdOf() == fromWindowId`, so null never matches.
3. **Minor.** `ExternalDisplayMode` → `configure(floating: false, decorated: false)` is pinned, and
   Unit 8's borderless surface is recorded as depending on `configure` succeeding (failure = decorated
   external display, cosmetic, logged). BLM §7 gains a fifth permitted test-shape reason (injecting a
   `WindowConfigurator` fake). The garbled macOS row in BLM §3.2 is fixed.

Permitted controller deviations are now a numbered list of seven (BLM §4.1).

## APPROVED — 2026-10-21

The Functional Design (this document and the four FD artifacts, revision 2) was **approved by James
Petersen on 2026-10-21** after the pre-build review and its two revision rounds. NFR Requirements was
approved in the same act.

**Next stage: NFR Design — NOT STARTED.**

### Open item carried into NFR Design

- **`SubWindowClosedChannel` registration order.** The main-engine Dart seam holds a live
  `MethodChannel` handler for the app's lifetime. NFR Design must state exactly *where* it is
  registered relative to `WidgetsFlutterBinding.ensureInitialized()` and the app's own startup work,
  who owns its lifetime, and that it is `dispose()`d with the container. It must also confirm it is
  registered **before** the first sub-window can be created, since a window could otherwise close
  before the channel is listening.

### Other items NFR Design inherits (not open questions, constraints)

Every constraint in "Revision 2026-10-21" and "Revision 2 — 2026-10-21" above, plus the FD's
verify-not-assume list for Infrastructure Design (per-platform hook behaviour, the lost-Dart-message
premise, the Linux handler order, runner signatures and `argv` delivery, and R-m6's SDK question).
