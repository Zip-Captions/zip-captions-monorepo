# Functional Design Plan — Unit 8: External Display (S-20)

**Unit**: 8 — External Display
**Story**: S-20 (`aidlc-docs/inception/user-stories/phase2-stories.md:508`)
**Package**: `zip_broadcast` (one new dependency, `screen_retriever`)
**Branch**: `feature/external-display` (off `origin/develop` at `99dd5ee`)
**Stages this unit runs**: Functional Design, Infrastructure Design, Code
Generation. NFR Requirements and NFR Design are skipped by the unit definition:
the only NFR is WCAG AAA contrast, covered by the story criteria, BR-U8-20 and
the existing theme.
**Run mode**: unattended overnight. A gate that needs a human answer but whose
answer is derivable from the specs is recorded as an assumption and carried;
a gate whose answer is genuinely unsettled stops that stage and the question
goes to the ledger.

**Inputs read before planning**: `AGENTS.md`, `docs/TDD.md`,
`packages/zip_broadcast/AGENTS.md`, `docs/04-technical-specification.md`
(§1-2, §6, §8), `aidlc-docs/aidlc-state.md`,
`phase2-unit-of-work.md:217`, `phase2-stories.md:508`,
`phase2-components.md` §7-8, `phase2-component-methods.md` §7,
`phase2-services.md` §F8, `aidlc-docs/v1-parity/picture-in-picture-v1-analysis.md`,
`aidlc-docs/construction/output-targets/functional-design/pip-ux-parity.md`,
the shipped overlay code and its tests, and the Phase 1 output-targets
Functional Design as the artifact-shape precedent.

---

## Decisions already fixed (not re-opened)

| Decision | Source |
|---|---|
| `screen_retriever` approved, conditional on SECURITY-10 | run brief, 2026-10-19 |
| Desktop = native always-on-top secondary window via `desktop_multi_window`; web/PWA = Document PiP; no hand-written HTML on non-web | run brief; `pip-ux-parity.md` §8.6 |
| Pop-out and external display share window machinery, not two implementations | run brief; `pip-ux-parity.md` §8.7 |
| Names: `DisplayEnumerator`, `ScreenRetrieverDisplayEnumerator`, `DisplayInfo`, `OverlayWindowEntry`, `OverlayWindowApp`, `ExternalDisplayControls`, `OverlayConfig.targetDisplayId`, `OverlayEvent.DisplayLost` | `phase2-components.md` §7-8, `phase2-component-methods.md` §7 |
| F8 flow (settings → show → `desktop_multi_window` → `invokeMethod('captionUpdate')` → disconnect → hide + `DisplayLost`) | `phase2-services.md` §F8 |
| `OutputTargetSettings.overlayEnabled` already ships and is registered by `ZbAppShell` | shipped code |
| `CaptionOverlayTarget`, `DesktopWindowService`, `DesktopMultiWindowService` (io/stub), `OverlayConfig`, `OverlayPosition` already ship | Phase 1 |

## Decisions this stage makes (recorded so later stages do not re-decide)

| # | Decision | Rationale |
|---|---|---|
| D1 | One window component with a sealed `OverlayWindowMode` (`ExternalDisplayMode`/`PopOutMode`), owned by a new `OverlayWindowController`; `CaptionOverlayTarget` is extended, not duplicated | §8.7's explicit choice; avoids two engines and two caption transports (F-8.1) |
| D2 | `DisplayEnumerator.changes` is a broadcast stream whose first emission is the current list, errors are logged not forwarded, and same-id geometry changes are emitted (`domain-entities.md`) | S-20's disconnect criterion needs a stream that survives a transient platform error |
| D3 | `DisplayInfo` carries `id,label,bounds,scaleFactor,isPrimary`; `bounds` is logical, top-left-origin, and is the window frame verbatim | One coordinate space; no per-platform flip |
| D4 | Disconnect fallback is a **move** (`setFrame`), never a close+recreate; primary preferred; persisted selection updated to the fallback | S-20 "without leaving an orphaned window"; cheap and idempotent |
| D5 | Status is a sealed `ExternalDisplayStatus` derived by one pure `resolveTarget` | Testable without a platform |
| D6 | `OutputTargetSettings` gains `externalDisplayId`, `popOutEnabled`, `popOutDisplayId`; `overlayEnabled` keeps its name and key | Migration-free upgrade of a shipped preference |
| D7 | `CaptionOverlayTarget` pushes a `CaptionOverlaySnapshot` (entries + interim + styles + settings), replacing `{text,isFinal}` | The window needs the broadcaster's settings; a second transport would violate "not twice" |
| D8 | `OverlayEvent` = `DisplayLost` / `WindowClosed` / `OpenFailed` | The UI must tell "window closed" from "display lost" |
| D9 | Stop-captioning closes via a settings write (`overlayEnabled=false`), not a direct call | One close implementation |
| D10 | OS-close detection is a one-shot presence probe after open, not a poll loop | `desktop_multi_window` 0.2.1 has no close callback; probed evidence in ID-4 |
| D11 | Pop-out content setting (`PipContent`: original/translated/both) ships and persists; it changes nothing until translation exists | §8.8 item 8 is satisfiable today; `BR-PIP-06` makes it inert |
| D12 | Web renders no controls; Document PiP is not implemented in this unit | S-20 excludes web; see OQ-3 |

## Open questions (carried to the ledger; not blocking the artifacts)

| # | Question | Conservative resolution taken |
|---|---|---|
| OQ-1 | `desktop_multi_window` 0.2.1 has no always-on-top API. macOS can be done in `MainFlutterWindow.swift`; Windows needs `SetWindowPos(HWND_TOPMOST)` in the runner; Linux needs WM-class handling whose portable form may be a new plugin. | Implement macOS and Windows in the existing runners if Infrastructure Design can do it without a new dependency; if Linux needs one, stop at the dependency gate and record it (FR-9.5, §8.8 item 15 is Unit 9-verified anyway). |
| OQ-2 | §8.8 item 10 names orientation, pane swap, translation target and download progress "inside the pop-out". None exists in Phase 2 (single pane, one language, no download). | Ship the controls that exist; record item 10 as unsatisfiable-until-those-features-exist. Not silently dropped. |
| OQ-3 | §8.6 says the PWA uses Document PiP and §8.8 item 15 is "not separately testable on web" — implying web is in §8.8's scope, while S-20 says web is not offered. | Follow S-20 and the unit definition (web excluded); no web pipeline this unit. |

## Artifacts produced

- `domain-entities.md` — `DisplayInfo`, `DisplayEnumerator`, `OverlayWindowMode`, `OverlayConfig` (modified), `OverlayEvent`, `OutputTargetSettings` (modified), `CaptionOverlaySnapshot`, `OverlayWindowLaunch`, `ExternalDisplayStatus`.
- `business-logic-model.md` — F-8.1 .. F-8.9, the event→state table, and the §8.8 mapping.
- `business-rules.md` — BR-U8-01 .. BR-U8-20 plus the out-of-scope fence.
- `screen-retriever-security-10.md` — the dependency record, including the version check demanded by the run brief. **Result: 0.3.0 requires Dart ^3.13.0 / Flutter >=3.47.0, the monorepo floor is 3.10.0, the environment has Dart 3.11.5 / Flutter 3.41.7 → pin `^0.2.2`; 0.2.x has no `legacy.dart`, so the legacy shim clause does not apply.**
- This plan.

## Self-check against S-20's seven acceptance criteria

| AC | Where satisfied | Testable this unit |
|---|---|---|
| All displays listed, one selectable | F-8.2, BR-U8-05/07/08, `ExternalDisplayStatus` | Yes (fake enumerator) |
| Selected display → borderless window with live captions and broadcaster settings | F-8.3, F-8.4, BR-U8-09/12/13 | Yes (fake service + widget test), borderlessness manual (ID-5) |
| Signed out, unchanged | BR-U8-14 | Yes (no auth read) |
| Disable or stop → window closes, resources released | F-8.6 A/B, BR-U8-02/15/17 | Yes |
| Display disconnected → graceful fallback, no orphan, broadcaster notified | F-8.5, BR-U8-06 | Yes |
| Web → not offered | F-8.9, BR-U8-11 | Yes |
| WCAG AAA 7:1 | BR-U8-20 | Yes |

## Self-check against `pip-ux-parity.md` §8.8's 18 criteria

Items 1-3, 5-11, 14, 18: widget/unit testable, see the F-8.8 mapping table;
each has a named surface. Items 4, 12, 13, 15, 16, 17: §8.8 itself assigns
them to manual/Unit 9 verification; this unit supplies the code paths and
tests wherever a fake can observe them, and ID-5 records the platform limits
verbatim.

## Approval

No human is present. Per the run rules, this stage's artifacts stand as
written, every decision above is recorded, the three open questions are
carried, and the ledger records `FD_PROPOSED` with a pointer here. Code
Generation is gated at its Part 1 plan boundary (Stage 3) as instructed.