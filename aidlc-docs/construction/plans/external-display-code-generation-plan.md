# Code Generation Plan — Unit 8: External Display (S-20)

**Prior stages**: Functional Design (`../external-display/functional-design/`,
proposed 2026-10-19T22:32Z) and Infrastructure Design
(`../external-display/infrastructure-design/infrastructure-design.md`, proposed
2026-10-19T22:52Z). Neither had a human approver; both are recorded as
`*_PROPOSED` in the ledger, per the run rules.

**Story**: S-20. **Branch**: `feature/external-display` (off `origin/develop` at
`99dd5ee`). **Package**: `zip_broadcast`.

**Gate status of this plan.** The run instruction makes this plan the hard
approval gate and says Part 2 proceeds in the same run only when the plan is a
*strict transcription of already-approved design with no open questions.* That
precondition is **not met**: the design was not human-approved, and three
questions are open (OQ-1, OQ-2, OQ-3 below). Consistent with the instruction,
this plan is committed and the run stops here. Part 2 is specified step by
step so the next session can execute it after the questions are answered.

---

## Scope

`zip_broadcast` only, plus the root `pubspec.lock` through the approved
dependency. No `zip_core` change: the caption buffer, `CaptionDisplayEntry`,
`DisplaySettings`, `AppTheme` and `CaptionDisplayWidget` are consumed as
shipped.

Out of scope, carried verbatim: always-on-top on Windows/Linux and a truly
frameless window on Windows/Linux (OQ-1, ID-5); UX-PIP-07's controls that do
not exist (OQ-2); the web Document PiP path (OQ-3, F-8.9).

---

## New files (all under `packages/zip_broadcast/lib/src/output/overlay/` unless noted)

| # | File | Contains |
|---|---|---|
| 1 | `display_info.dart` | `DisplayInfo` (freezed) |
| 2 | `display_enumerator.dart` | `abstract interface class DisplayEnumerator` incl. `dispose()`; `resolveTarget(...)` pure helper (also used by the controller) |
| 3 | `screen_retriever_display_enumerator.dart` | conditional export (`_io` when `dart.library.io`, else `_stub`) + `createDisplayEnumerator()` |
| 4 | `screen_retriever_display_enumerator_io.dart` | `ScreenRetrieverDisplayEnumerator`; the **only** `package:screen_retriever/...` import |
| 5 | `screen_retriever_display_enumerator_stub.dart` | empty-list enumerator |
| 6 | `overlay_window_mode.dart` | sealed `OverlayWindowMode` + `ExternalDisplayMode`, `PopOutMode` |
| 7 | `overlay_event.dart` | sealed `OverlayEvent` + `DisplayLost`, `WindowClosed`, `OpenFailed` |
| 8 | `caption_overlay_snapshot.dart` | freezed + JSON `CaptionOverlaySnapshot` |
| 9 | `overlay_window_launch.dart` | freezed model + hand-written `OverlayWindowLaunchCodec` (mode + config + snapshot, `null` on malformed) |
| 10 | `overlay_window_controller.dart` | `OverlayWindowController` (plain class on the shell's `ProviderContainer`): guard, open/close/re-frame, event stream, settings listener, probe |
| 11 | `overlay_window_bridge.dart` | `OverlayWindowBridge` interface + conditional export + `createOverlayWindowBridge()` |
| 12 | `overlay_window_bridge_io.dart` | `DesktopMultiWindowBridge` (only `DesktopMultiWindow` import) |
| 13 | `overlay_window_bridge_stub.dart` | no-op |
| 14 | `overlay_window_entry.dart` | `isOverlayWindowLaunch`, `overlayWindowMain`, `OverlayWindowEntry` |
| 15 | `overlay_window_app.dart` | `OverlayWindowApp` (renders `CaptionDisplayWidget`, applies per-input styles, in-window `PopOutToggle`) |
| 16 | `external_display_status.dart` | sealed `ExternalDisplayStatus` + `deriveExternalDisplayStatus(...)` |
| `lib/src/widgets/` | 17 | `external_display_controls.dart` — Proto-13 section |
| `lib/src/models/` | 18 | `pip_content.dart` — enum `original/translated/both` |
| `lib/src/providers/` | 19 | `external_display_controller_provider.dart` — `@Riverpod(keepAlive: true)` controller/status provider |
| `macos/Runner/` | 20 | `MainFlutterWindow.swift` — sub-window `NSWindow.level = .floating` (ID-5) |

## Modified files

| # | File | Change |
|---|---|---|
| 21 | `pubspec.yaml` | `screen_retriever: ^0.2.2` under dependencies with the SECURITY-10 comment |
| 22 | `pubspec.lock` (root) | resolution entries only |
| 23 | `lib/src/models/overlay_config.dart` | `targetDisplayId` → `mode`; add `popOutSize`, `popOutMinimumSize`; regenerate freezed |
| 24 | `lib/src/models/output_target_settings.dart` | `externalDisplayId`, `popOutEnabled`, `popOutDisplayId`; regenerate |
| 25 | `lib/src/providers/broadcast_providers.dart` | persist/load the three new keys + `output.pipContent` |
| 26 | `lib/src/output/overlay/caption_overlay_target.dart` | own the snapshot stream; `show(mode)`; disconnect re-frame; `events`; `captionUpdate` carries a snapshot; probe-failure → `WindowClosed` |
| 27 | `lib/src/shell/zb_app_shell.dart` | `_syncOverlay` drives the controller; stop-captioning listener (BR-U8-17); `PopOutToggle` in rail/AppBar; `PopOutHint`; `popOutToggle` handler; notice on `DisplayLost`/`OpenFailed` |
| 28 | `lib/main.dart` | `main(List<String> args)` + overlay branch |
| 29 | `l10n/arb/app_en.arb` + generated `src/l10n/*` | the strings in the "Strings" section |
| 30 | `lib/src/widgets/output_targets_panel.dart` | replace the Phase 1 overlay switch with `ExternalDisplayControls` |

## Convention note

New overlay types go in the existing `lib/src/output/overlay/` flat directory,
which already holds seven files; no sub-directory is introduced, matching
Phase 1's layout.

---

## Test list (explicit; written before implementation, per `docs/TDD.md`)

Existing tests to keep green: `test/output/caption_overlay_target_test.dart`
(10 cases), `test/shell/zb_app_shell_test.dart`,
`test/screens/recording_screen_test.dart`, `test/screens/settings_screen_test.dart`,
`test/widgets/*`, `test/app_test.dart`.

| # | File (new unless noted) | Cases |
|---|---|---|
| T1 | `test/output/display_info_test.dart` | equality incl. bounds/scaleFactor; JSON-free model compiles with `Rect` |
| T2 | `test/output/display_enumerator_test.dart` | `resolveTarget`: selection present → itself; absent + primary → primary; absent, no primary, list non-empty → first; empty → null; idempotent under repeated calls; **PBT** (`test/helpers/pbt.dart`, in-tree shim): for any non-empty list, result is always an element of the list (PBT-03 style invariant) |
| T3 | `test/output/overlay_window_mode_test.dart` | exhaustive switch compiles over both variants; `const OverlayConfig()` equals `ExternalDisplayMode()` + defaults; `popOutSize` default 640x320; minimum default 320x180 |
| T4 | `test/output/caption_overlay_snapshot_test.dart` | JSON round-trip: entries (final), interim present/absent, styles map, settings; unicode text round-trips byte-for-byte; no dropped fields; a snapshot is never a `SessionStateEvent` payload (type-level) |
| T5 | `test/output/overlay_window_launch_test.dart` | codec round-trip for both modes; malformed JSON → null; missing `mode` → null; unknown mode string → null; oversized/garbage argument → null, no throw; **PBT**: round-trip property over generated snapshots (`pbt.dart`) |
| T6 | `test/output/screen_retriever_display_enumerator_test.dart` | against a fake platform-source seam: `displays()` preserves order; first listener receives the current list (replay); a same-id list with changed bounds IS emitted while an identical list is NOT; connect and disconnect each emit; a source error logs and does not close the stream; `dispose()` closes and is idempotent; listener add/remove does not leak a second source subscription |
| T7 | `test/output/overlay_window_controller_test.dart` | one-window invariant: second open while open is refused (BR-U8-01); mode switch closes then opens, exactly one `createWindow` per switch; enable external display frames to `DisplayInfo.bounds` exactly; re-resolution on geometry change re-frames; disconnect → single `setFrame` to primary + `DisplayLost` + persisted id updated (BR-U8-06); no destination → `Lost`, no `closeWindow`; create throws → `OpenFailed`, no registry registration, `isVisible` false (BR-U8-03); disable closes once; stop path closes once; `WindowClosed` on a failing `captionUpdate`; closed invariant (BR-U8-15) after every path; `dispose()` closes if open |
| T8 | `test/output/caption_overlay_target_test.dart` (modify) | existing 10 cases re-pointed at `show(mode)`; new: `captionUpdate` payload is a decodable `CaptionOverlaySnapshot` whose `entries` equal the buffer's finals and whose `interim` is the trailing non-final; settings change reaches the next payload without a reopen (BR-U8-12); no `captionUpdate` before `show`; `DisplayLost` surfaces on the target's `events`; close by `hide()` still idempotent |
| T9 | `test/widgets/external_display_controls_test.dart` | Proto-13: list renders all displays in order; selected row from persisted id; fallback to primary when the persisted id is absent; tap persists the id; empty label renders "Display N"; toggle writes `overlayEnabled`; `Unsupported` renders nothing (BR-U8-11); `NoDisplays` disables the toggle; `Lost` shows the disconnected banner; `Failed` shows the failure copy and the toggle is off; **no semantics label or key contains caption text** (BR-U8-18) |
| T10 | `test/output/overlay_window_app_test.dart` | renders the snapshot's entries and interim; applies the snapshot's `DisplaySettings` (font size changes the rendered style); per-source colour from `styles`; AAA contrast assertion computed from the actual `AppTheme.light()/dark()` instances (BR-U8-20); in-window toggle sends `popOutToggle` through the bridge stub; a bad `captionUpdate` is ignored without throwing (BR-U8-19) |
| T11 | `test/output/overlay_window_entry_test.dart` | `isOverlayWindowLaunch` true only for `['multi_window', '1', '{}']`-shaped args, false for `[]`, one arg, non-multi first arg; `overlayWindowMain` with a bad payload builds the failure frame and does not initialise Supabase (asserted by the fake Supabase seam being untouched) |
| T12 | `test/shell/zb_app_shell_test.dart` (extend) | external display on/off drives the controller (fake) register/deregister; stop captioning writes `overlayEnabled=false` (BR-U8-17); pop-out toggle visible only with an active session (UX-PIP-03); absent when `isSupported` false (UX-PIP-04); hint shown while popped out and cleared on `WindowClosed` (BR-PIP-03/05); `popOutToggle` inbound message toggles exactly once |
| T13 | `test/providers/broadcast_providers_test.dart` (extend) | the four new keys persist and reload; an absent `externalDisplayId` stays null; `popOutEnabled` reloads but nothing auto-opens (BR-U8-16 — asserted via the provider, not the shell) |
| T14 | `test/widgets/output_targets_panel_test.dart` (modify) | the card now renders `ExternalDisplayControls`; no Phase 1 switch remains |

PBT use: T2 and T5 only, via the in-tree `test/helpers/pbt.dart` (100 fixed
seeds, no shrinking — the project's Dart PBT decision recorded at Unit 7).

Not testable in this package, recorded for Unit 9: always-on-top (macOS code
only), borderless on Windows/Linux (not implemented), window close by the OS
(T12 covers the code path via a fake; the real close is manual).

---

## Implementation order (Part 2)

1. `pubspec.yaml` + `dart pub get`; confirm the resolved `screen_retriever`
   version is 0.2.x and that `--fatal-infos` stays clean in a scratch import
   (ID-3's deprecation hazard).
2. Write T1, T3, T4, T5 (models + codecs) — failing.
3. Implement files 1, 6, 7, 8, 9; regenerate freezed.
4. Write T2; implement file 2.
5. Write T6; implement files 3-5.
6. Write T11; implement files 11-14 (bridge + entry).
7. Write T7; implement file 10 and the `events`/snapshot additions to 26.
8. Write T10; implement file 15.
9. Write T9, T14; implement files 16, 17 (`lib/src/widgets/`), 30.
10. Write T12, T13; implement files 25, 27, 28, 18, 19.
11. Strings (29); regenerate l10n.
12. macOS runner (20).
13. Re-run T8 against the final target; regenerate freezed for 23/24.
14. Gates, in the run's order, all three packages.
15. Summaries under `aidlc-docs/construction/external-display/code/`.

Commit split: `feat(zip_broadcast):` for implementation steps 2-12 grouped
logically, `test(zip_broadcast):` for the failing-test commits that precede each
group, `docs(aidlc):` for design artifacts.

---

## Strings (ARB keys to add)

`externalDisplayTitle`, `externalDisplayDescription`, `externalDisplayPrimary`,
`externalDisplayDisplayNumber(int index)`, `externalDisplayActiveOn(String
label)`, `externalDisplayFallbackNotice`, `externalDisplayDisconnected(String
label)`, `externalDisplayOpenFailed`, `externalDisplayNoDisplays`,
`externalDisplayUnsupported` (unused in UI, kept for the provider's reasoning
string), `popOutToggleOpen`, `popOutToggleClose`, `popOutDisabledNoSession`,
`popOutHintActive`, `popOutReturnAction`, `popOutContentOriginal`,
`popOutContentTranslated`, `popOutContentBoth`, `overlayWindowUnavailable`.
No string contains caption text.

---

## Open questions that block Part 2

### OQ-1 — Always-on-top and borderless on Windows/Linux

`desktop_multi_window` 0.2.1 creates the native window but exposes no
always-on-top API and no style-mask control, and the native handle is not
reachable from Dart or from the app runners without patching the vendored
plugin. ID-5 implements macOS (`NSWindow.level = .floating`) and does not
attempt Windows/Linux.

- Option A (recommended, conservative): ship external display on all three
  platforms; ship the pop-out without guaranteed always-on-top on
  Windows/Linux; record the gap for Unit 9 / a future dependency decision
  under FR-9.5.
- Option B: add a window-management plugin that exposes always-on-top
  (e.g. `window_manager`) — a new dependency, needs its own SECURITY-10 record
  and may compete with `desktop_multi_window` for the native window.
- Option C: vendor a patched `desktop_multi_window` — rejected in ID-5; it puts
  native code in the repo with no build verification on this machine.

**Needed to proceed**: which of A/B, and whether S-20's "borderless" is satisfied
by "no app chrome, platform title bar retained" (the only implementable reading
without the handle).

### OQ-2 — `pip-ux-parity.md` §8.8 item 10

Item 10 requires the orientation toggle, pane swap, translation target select
and download progress to work inside the pop-out. None of those features exists
in Phase 2 (one pane, one language, no download). F-8.8 records the mapping and
ships the controls that exist.

**Needed to proceed**: confirm item 10 is deferred to the unit that adds those
controls, rather than being a blocker for this unit.

### OQ-3 — Web scope

The binding decision says "Web/PWA uses the browser Document Picture-in-Picture
API", and §8.6 says the PWA "is a release target, not a degraded fallback".
S-20 says external display is not offered on web, and this unit's definition
names no web work. F-8.9 excludes web entirely in this unit; the pop-out control
is hidden there.

**Needed to proceed**: confirm the web Document PiP path is a later unit (and
therefore that the pop-out shipping desktop-only is acceptable), or scope it in.

---

## Self-check against the run brief's Stage 3 gate

> do not proceed to Part 2 in the same run unless the plan is a strict
> transcription of already-approved design with no open questions.

Not strict transcription (design unapproved) and three open questions → stop
after committing this plan. Every step above is ordered and test-listed so the
next session can execute it verbatim once OQ-1..OQ-3 are answered.