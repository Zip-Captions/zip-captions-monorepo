# Handoff: Functional Design -> NFR Requirements
**Unit**: 8.1 Pop-out Live Captions (S-21)
**Date**: 2026-10-21

## Decisions Made
- Q1: `PopOutMode` (field-less) is a sibling of `ExternalDisplayMode`; codec encodes `'popOut'` and decodes both modes. No version bump (BR-U8.1-08).
- Q2: all machinery moves to `zip_core/lib/src/output/overlay/`, exported via a new `overlay.dart` barrel; plugins only in `_io` files behind the existing conditional-export shape.
- Q3: `OverlayConfig`/`OverlayPosition` move to `zip_core`; `zip_broadcast`'s two model files become one-line `export` shims (the only permitted shim).
- Q4/BR-U8.1-05: `AlwaysOnTopInstaller` in `zip_core`'s `_io` runs `windowManager.ensureInitialized()`, `setAlwaysOnTop(true)`, `setResizable(true)`, `setMinimumSize(...)` inside the sub-engine, before ready; failure is caught and never turns into `OpenFailed`.
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
| `AlwaysOnTopInstaller` | NEW seam, `_io`/`_stub` | only file importing `window_manager` |
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
- Test seam for `AlwaysOnTopInstaller`: is a fake sufficient, or does NFR Requirements want a "reports unsupported" variant to model Linux WMs that ignore keep-above? (source: BR-U8.1-12)
- Whether the pop-out's `PopOutCaptionTarget` duplication across the two apps is acceptable under the quality rules, or NFR Requirements wants one shared adapter class taking an injected buffer reader. (source: Q5 A vs BR-U8.1-03)
- How the `zip_captions` main-entry routing (BR-U8.1-06) is proven without initialising Supabase in a test. (source: no existing `main`-shaped test in `zip_captions`)