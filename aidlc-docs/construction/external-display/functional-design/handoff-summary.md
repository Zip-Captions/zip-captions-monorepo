# Handoff Summary — Unit 8 External Display: Functional Design -> NFR Requirements

**Stage:** Functional Design (revised) — **2026-10-20**
**Branch:** `feature/external-display` — **PR:** #37 (open)
**Approving input:** PR #37 review comment 2026-10-19 (<https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308>), decisions D-1..D-13.

## What the revision changed
- **D-1:** Pop-out split into its own Phase 2 unit (after Unit 8, blocks v2.0 RC, definition pending). Every pop-out type/rule/mapping removed from this unit; `pip-ux-parity.md` §8 stays the pop-out's binding contract, untouched here.
- **D-2/D-3:** Borderless from the `desktop_multi_window` window-created callback (all 3 runners); window frame = display **work area** (`visiblePosition` + `visibleSize`) via `setFrame`; native full-screen -> Backlog.
- **D-4:** Disconnect = close window + notify + **output stays on** in `WaitingForDisplay` (Cancel offered); auto-reopen on the saved display; saved id never overwritten (BR-U8-07).
- **D-5:** S-20 AC4 amended to "When the broadcaster disables the output, then the window closes and its resources are released". Recognition events change **only** the snapshot `activity` (standby/live/paused), never the window.
- **D-6:** Switch starts off at launch; only `externalDisplayId` + caption position persist.
- **D-7:** Window mirrors the main window's `CaptionDisplayWidget`; per-input colour removed -> Backlog.
- **D-8:** Hand-written versioned snapshot/launch codec in `zip_broadcast`; no `zip_core` change; decode total-on-error; `key` == `entryId`; `sessionId`/`sourceId` never cross.
- **D-9/B-5:** One main-engine method handler (installed before first `createWindow`); `overlayReady` handshake; `overlayReadyTimeout`; only `PlatformException` code `'-1'` = `WindowClosed`; ping probe and D10 removed.
- **D-13:** `window_manager` removed everywhere; `window-manager-security-10.md` deleted.
- **B-1/B-2:** Corrected coordinate facts (screen_retriever 0.2.2 already reports logical top-left on all 3 backends; Windows divides `rcWork` by scale). The one conversion is a pure function in the io window adapter: macOS Cocoa y-flip against the primary full height; Windows multiply by the target display's scale; Linux identity.
- **B-6:** `DesktopWindowService` gains `setFrame`/`show`; open order `createWindow` -> `setFrame` -> `show`; window shows standby until first snapshot.
- **B-8:** Proto-13 Caption Position (Top/Bottom) selector added (persisted `externalDisplayCaptionPosition`); surface opaque (shipped `opacity` 0.9 not applied).
- **B-9:** `OverlayWindowController` is the sole owner of the window; `CaptionOverlayTarget` is a thin delegator + caption-bus adapter.

## State of the artifacts
- `domain-entities.md`, `business-logic-model.md` (state machine T1-T17), `business-rules.md` (BR-U8-01..26, PBT-01 properties FP-1..FP-5), `frontend-components.md` — rewritten/created for D-1..D-13.
- `screen-retriever-security-10.md` — corrected (16 releases; `ScreenRetriever.instance` not deprecated in 0.2.2; ID-3's deprecation claim N/A under the pin — Infrastructure Design must be corrected when re-run per D-10).
- `window-manager-security-10.md` — deleted (D-13).
- Plan: `aidlc-docs/construction/plans/external-display-functional-design-plan.md` rewritten; `6f4eaea` (window_manager) marked superseded; NFR stages added.
- Inception: S-20 AC4 amended; Unit 8 stages = FD, NFR Requirements, NFR Design, Infrastructure Design, Code Generation; Backlog gained pop-out (own unit), native full-screen, per-input caption colour.

## Open items for NFR Requirements
- Non-functional angles for the new surfaces: ready-timeout value and its failure mode (BR-U8-03/23), waiting-state UX cost on hot-plug, frame-conversion correctness on fractional scaling / Wayland (accepted as a Unit 9 manual check), codec size guard sizing, and the "no caption text outside the window" audit across the new paths (BR-U8-18, SECURITY-03).
- Infrastructure Design re-run (D-10) must also fix ID-3's deprecation statement and drop ID-5's `window_manager` references.
- Pop-out unit: definition pending; this unit's machinery is what it reuses (D-1) — NFR scope must not assume pop-out behaviour.
