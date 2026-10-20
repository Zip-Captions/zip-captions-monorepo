# Functional Design Plan — Unit 8: External Display (S-20)

**Unit**: 8 — External Display
**Story**: S-20 (`aidlc-docs/inception/user-stories/phase2-stories.md:508`, AC4 amended 2026-10-19)
**Package**: `zip_broadcast` (one new dependency, `screen_retriever`; `window_manager` **removed**)
**Branch**: `feature/external-display` (off `origin/develop` at `99dd5ee`)
**Stages this unit runs**: Functional Design, NFR Requirements, NFR Design,
Infrastructure Design, Code Generation. (NFR Requirements and NFR Design are
**not** skipped — D-10 runs them; the earlier "NFR skipped by the unit
definition" note is withdrawn.)
**Run mode**: unattended overnight. A gate that needs a human answer but whose
answer is derivable from the specs is recorded as an assumption and carried;
a gate whose answer is genuinely unsettled stops that stage and the question
goes to the ledger.

**Revised 2026-10-20** for the PR #37 review comment (2026-10-19,
<https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308>).
This revision supersedes the 2026-10-19 plan in its entirety: the in-unit
pop-out design (old D1/D11, OQ-2, OQ-3), the `window_manager` decision (OQ-1
Option B, commit `6f4eaea` — **superseded**), and the disconnect-fallback
behaviour (old D4) are all replaced by the review decisions below.

---

## Review decisions (authoritative — James Petersen, 2026-10-19)

Source for every row: <https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308>

| # | Decision | [Answer] (authoritative) |
|---|---|---|
| D-1 | **Scope.** Pop-out is split out of Unit 8 into its own Phase 2 unit after Unit 8, reusing Unit 8's window machinery; it blocks the v2.0 RC. Its UX contract stays in `pip-ux-parity.md` §8 (untouched by this unit); unit definition pending. | Unit 8 = external display only. Every pop-out type, rule, mapping and ARB key removed from this unit's artifacts. |
| D-2 | **Borderless.** Set from the `desktop_multi_window` window-created callback in all three runners — no `window_manager`. | OQ-1 Option B (`window_manager`, `6f4eaea`) **superseded**. `window-manager-security-10.md` deleted. |
| D-3 | **Frame.** Window frame = the display's **work area** (`visiblePosition` + `visibleSize`), applied with `setFrame`. Native full-screen is Backlog. | `BR-U8-09`; frame conversion in `domain-entities.md`. |
| D-4 | **Disconnect.** Close the window, notify, **output stays on** in a waiting state with **Cancel**; auto-reopen when the saved display reappears; the saved display id is never overwritten (BR-U8-07 stays). | `BR-U8-22`; state `WaitingForDisplay`. Supersedes old D4 (fallback move) and BR-U8-06. |
| D-5 | **Stop.** S-20 AC4 amended: "When the broadcaster disables the output, then the window closes and its resources are released." Recognition events (start/pause/resume/stop) change **only** the `activity` value, never open/close the window. | AC4 amended in `phase2-stories.md`; `BR-U8-17` replaced; `OverlayActivity`. |
| D-6 | **Launch.** The switch starts off at launch; only the selected display id (plus caption position) persists. | `BR-U8-21`; settings loader forces `overlayEnabled = false`. |
| D-7 | **Mirroring.** The window mirrors the main window (`recording_screen.dart:131`); `sourceColorValues`/per-input styles removed; per-input colour -> Backlog. | `BR-U8-13`, `BR-U8-25`; no `zip_core` widget change. |
| D-8 | **Codec.** Hand-written versioned snapshot codec in `zip_broadcast` (precedent `SignalingCodec`/`CaptionWireCodec`); **no** `zip_core` change. | `BR-U8-24`; `domain-entities.md` "Snapshot and launch codecs". |
| D-9 | **Close detection.** Ready handshake + error code `'-1'`. The ping probe and old D10 are removed. | `BR-U8-04`, `BR-U8-23`. |
| D-10 | **Stages.** Run NFR Requirements and NFR Design. | Stages line above; unit-of-work doc updated. |
| D-11 | **Run.** Unattended overnight run. | This plan's run mode. |
| D-12 | **Inception.** Amendments applied as a split: S-20 AC4, Unit 8 stages, Backlog entries. | Applied in `phase2-stories.md`, `phase2-unit-of-work.md`, `aidlc-state.md`. |
| D-13 | **Dependency.** `window_manager` removed; delete `window-manager-security-10.md`. | Done in this revision. |

## Required changes applied (B-1 .. B-9)

| # | Change | Where |
|---|---|---|
| B-1 | Corrected coordinate facts: `screen_retriever` 0.2.2 reports logical top-left on **all three** backends (Windows divides `rcWork` by scale in the plugin itself — the old "adapter must divide" claim was wrong). The one conversion is a pure function in the io window adapter: macOS Cocoa y-flip against the primary **full** height (`getPrimaryDisplay().size`); Windows multiply by the target display's `scaleFactor`; Linux identity. | `domain-entities.md` "Frame conversion" |
| B-2 | Windows conversion multiplies by **that display's own** scale factor (mixed-DPI safe). | same |
| B-5 | Handshake: the sub-engine sends `overlayReady` to window 0 after installing its handler; the main engine holds the latest snapshot and sends nothing until ready; timeout -> `OpenFailed`; only `PlatformException` code `'-1'` means `WindowClosed`; exactly one `DesktopMultiWindow.setMethodHandler`, installed before the first `createWindow`; ping probe and old D10 removed. | `BR-U8-23`, `BR-U8-04`, `business-logic-model.md` §2/§6 |
| B-6 | `DesktopWindowService` gains `setFrame(int id, Rect frame)` and `show(int id)`; open order `createWindow` -> `setFrame` -> `show`; the window shows standby until the first snapshot. | `domain-entities.md`, `BR-U8-09` |
| B-7 | Codec spec: shape `{v:1, activity, entries:[{key,text,isFinal}], interim, settings:{...}}`; enums by name; decode `null` on malformed/unknown version/unknown enum; UTF-8 byte-length size guard; `sessionId`/`sourceId` never cross (placeholder rebuild); `OverlayWindowLaunch={v,config,snapshot}` with one `mode` source; PBT round-trip + malformed. | `BR-U8-24`, FP-1/FP-2 |
| B-8 | Proto-13 **Caption Position** (Top/Bottom) selector: persisted `externalDisplayCaptionPosition`, in the launch config, tested (T9); **opaque** surface (shipped `OverlayConfig.opacity` 0.9 **not** applied). | `BR-U8-26`, `frontend-components.md` |
| B-9 | Ownership: `OverlayWindowController` is the sole owner of the window; `CaptionOverlayTarget` keeps `show`/`hide`/`events` as thin delegators and acts as the caption-bus adapter. | `domain-entities.md` |

## Decisions already fixed (not re-opened)

| Decision | Source |
|---|---|
| `screen_retriever` approved, conditional on SECURITY-10 | run brief, 2026-10-19; `screen-retriever-security-10.md` (corrected this revision) |
| Desktop = native secondary window via `desktop_multi_window`; web not offered (S-20); no hand-written HTML on non-web | run brief; S-20; `pip-ux-parity.md` §8.6 (binding on the pop-out unit) |
| Names: `DisplayEnumerator`, `ScreenRetrieverDisplayEnumerator`, `DisplayInfo`, `OverlayWindowEntry`, `OverlayWindowApp`, `ExternalDisplayControls`, `OverlayEvent.DisplayLost` | `phase2-components.md` §7-8, `phase2-component-methods.md` §7 |
| `OutputTargetSettings.overlayEnabled` already ships and is registered by `ZbAppShell` | shipped code |
| `CaptionOverlayTarget`, `DesktopWindowService`, `DesktopMultiWindowService` (io/stub), `OverlayConfig`, `OverlayPosition` already ship | Phase 1 |

Superseded fixed items: `OverlayConfig.targetDisplayId` (replaced by `mode` —
deviation recorded below) and "pop-out and external display share window
machinery in this unit" (D-1 defers the pop-out; the machinery-sharing
constraint now binds the *pop-out unit*).

## Open questions — resolved

| # | Question | Status |
|---|---|---|
| OQ-1 | `window_manager` Option B (commit `6f4eaea`) for always-on-top. | **SUPERSEDED** by D-2/D-13 (2026-10-19): borderless from the window-created callback; `window_manager` not added; `window-manager-security-10.md` deleted. Always-on-top beyond the plugin's shipped behaviour is out of scope (fence table in `business-rules.md`). |
| OQ-2 | §8.8 item 10 (orientation/pane swap/translation/download "inside the pop-out"). | **Moves to the pop-out unit** (D-1); not satisfied, deferred, and not claimed here. |
| OQ-3 | Web Document PiP. | **Moves to the pop-out unit** (D-1); S-20's web exclusion stands for this unit via capability (BR-U8-11). |

## Artifacts produced (this revision)

- `domain-entities.md` — `DisplayInfo`, frame conversion, `DisplayEnumerator`, `OverlayWindowMode`, `OverlayConfig` (modified), `DesktopWindowService` (modified), `OverlayEvent`, `OutputTargetSettings` (modified), `CaptionPosition`, `OverlayActivity`, `CaptionOverlaySnapshot`, snapshot/launch codecs, `ExternalDisplayStatus`, `OverlayWindowController`.
- `business-logic-model.md` — flows §1-§9, the state machine (T1-T17), A7 forward notes.
- `business-rules.md` — BR-U8-01..26 (10/16 removed, 17 replaced, 21-26 added), PBT-01 properties FP-1..FP-5, out-of-scope fence.
- `frontend-components.md` — `ExternalDisplayControls` (all seven statuses), `OverlayWindowApp` (standby/live/paused).
- `screen-retriever-security-10.md` — corrected: 16 releases (not 18); `ScreenRetriever.instance` not deprecated in 0.2.2, so Infrastructure Design ID-3's deprecation claim is N/A under the pin and must be fixed when ID is re-run.
- `window-manager-security-10.md` — **deleted** (D-13).
- `handoff-summary.md` — Functional Design -> NFR Requirements.
- This plan.

## Application Design deviations (recorded, approved by the PR #37 review)

| Application Design item | Deviation | Why |
|---|---|---|
| `OverlayConfig.targetDisplayId` (fixed name) | Replaced by `OverlayConfig.mode` (`ExternalDisplayMode({displayId})`) | D-1 keeps the mode hierarchy extensible for the pop-out unit while shipping one variant; `displayId` moves to `OutputTargetSettings.externalDisplayId` as the persisted source of truth (D-4). |
| `OverlayConfig` field list | `popOutSize`/`popOutMinimumSize` never added; `opacity` kept but not applied (B-8) | D-1, D-7. |
| F8 flow "disconnect -> hide + `DisplayLost`" | Disconnect -> close + `WaitingForDisplay` (output stays on, D-4); `DisplayLost` still emitted | D-4. |
| `OverlayEvent` set | `OpenFailed` added (with `reason`) | D-9/B-5: a failed open is a distinct observable state. |

## Self-check against S-20's seven acceptance criteria (AC4 as amended)

| AC | Where satisfied | Testable this unit |
|---|---|---|
| All displays listed, one selectable | `ExternalDisplayControls`, BR-U8-05/07/08 | Yes (fake enumerator) |
| Selected display -> borderless window with live captions and broadcaster settings | flows §2-§3, BR-U8-09/12/13/25/26 | Yes (fake service + widget tests); borderlessness/frame manual (Infrastructure Design) |
| Signed out, unchanged | BR-U8-14 | Yes (no auth read) |
| **Disable the output -> window closes, resources released** (amended; stop is `standby`, BR-U8-17) | flows §5/§6, BR-U8-02/15/17 | Yes |
| Display disconnected -> graceful, no orphan, broadcaster notified | flow §5, BR-U8-22 | Yes (fake enumerator event sequence) |
| Web -> not offered | BR-U8-11, `Unsupported` | Yes (stub) |
| WCAG AAA 7:1 | BR-U8-20 (wiring test; ratio asserted once in `zip_core`) | Yes (widget test) |

## `pip-ux-parity.md` §8.8 self-check

§8.8 is the **pop-out** unit's binding checklist (D-1). This unit satisfies
nothing of it and claims nothing of it; the checklist is carried unchanged for
that unit. The one overlap — the shared window machinery — is constrained by
D-1 ("not twice"): this unit's `OverlayWindowMode`/controller/codec are the
reused surface.

## Security Compliance (SECURITY-01..15)

| Rule | Status | Note |
|---|---|---|
| SECURITY-01 | N/A | No new data store; settings persistence is the shipped preferences store. |
| SECURITY-02 | N/A | No network intermediary introduced. |
| SECURITY-03 | Compliant | All unit logging is fixed strings + error type; no caption text, no display labels in logs (BR-U8-18). |
| SECURITY-04 | N/A | No HTML-serving endpoint. |
| SECURITY-05 | Compliant | Window input (launch arg, `captionUpdate`) validated by total-on-error decode with a byte-length bound (BR-U8-24, BR-U8-19); settings writes are typed freezed fields. |
| SECURITY-06 | N/A | No IAM policies. |
| SECURITY-07 | N/A | No network configuration. |
| SECURITY-08 | Compliant (BR-U8-14) | Output is signed-out-only by design; no auth path introduced. |
| SECURITY-09 | Compliant | Failure paths render fixed generic copy; `OpenFailed.reason` is a code, never shown raw (BR-U8-03, `frontend-components.md`). |
| SECURITY-10 | Compliant | One new dependency, pinned `^0.2.2`, one-import fence, lockfile change bounded to five entries (`screen-retriever-security-10.md`); `window_manager` removed (D-13). |
| SECURITY-11 | Compliant | Single capability gate (BR-U8-11); single codec (BR-U8-24); single window owner (B-9); abuse considered: sub-engine crash (ready timeout), hot-plug churn (coalesced `changes`), oversized payload (size guard). |
| SECURITY-12 | N/A | No credential handling. |
| SECURITY-13 | Compliant | Deserialization is the versioned codec, total-on-error, never throws (BR-U8-24, BR-U8-19). |
| SECURITY-14 | N/A | Local desktop app; no security-event alerting surface added. |
| SECURITY-15 | Compliant | Every external call (createWindow/setFrame/show/close/invokeMethod, plugin events) has explicit error handling; fail-closed to `Failed`/`Off` (BR-U8-03); resources released on every close path (BR-U8-02/15). |

## PBT-01 compliance

Properties identified and documented: FP-1 (round-trip, PBT-02), FP-2
(total-on-error invariant, PBT-03), FP-3 (frame conversion, PBT-05/PBT-03),
FP-4 (open resolution, PBT-03), FP-5 (state machine closure, PBT-03) — in
`business-rules.md`. Carried into Code Generation as test requirements.
Components without properties are marked with rationale (same file).

## Approval

No human is present. Per the run rules (D-11), this stage's artifacts stand as
written; the PR #37 review comment is the approving input for every
D/B item; the ledger records this revision. Code Generation remains gated at
its Part 1 plan boundary. Subject to morning review.
