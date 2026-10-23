# Handoff: Code Generation -> Build and Test (Unit 9) / Documentation Refinement

**Unit**: pop-out (Unit 8.1, S-21)
**Date**: 2026-10-22/23 (unattended run; approved by the run configuration per
`.agent/overnight-pipeline.md`, subject to morning review)
**Branch**: `feature/popout-live-captions`, not pushed
**Full detail**: `aidlc-docs/construction/pop-out/code/summary.md`

## State at handoff

- Plan steps 1-27 are committed (16 commits, `416ed5f` … `03b1622`).
- Steps 28-29 (the six runners) are **written and compiled for macOS** but the
  working tree change is left for the orchestrator to commit, together with this
  document: `git status --short` shows the six runner files plus
  `packages/zip_captions/macos/Podfile.lock` and
  `packages/zip_core/lib/src/providers/providers.dart` (the barrel export of
  `overlay_window_host_provider.dart` — applied with the promotion but never
  staged; it is in-fence and belongs in the step 11-13 commit's spirit, so fold it
  into the runner commit and note it).
- `zip_captions/macos/Podfile.lock` moved for the first time since Phase 1
  (`fce6c8e`): it was stale on `develop` and `flutter build macos` regenerated
  it. The diff adds `desktop_multi_window` and `screen_retriever_macos` (this
  unit's declared dependency) and also `app_links`, `flutter_secure_storage_macos`,
  `flutter_webrtc`, `local_auth_darwin`, `url_launcher_macos`, `WebRTC-SDK` — all
  of which were already in `pubspec.yaml` before this unit. That is a lockfile
  catch-up, not a dependency change; the morning review should confirm it is
  acceptable to commit the catch-up here rather than as a separate chore.
- Tree otherwise clean apart from the standing ` M opencode.json` (never staged,
  never reverted).

## Gates run (from each package root)

| Command | `zip_core` | `zip_broadcast` | `zip_captions` |
|---|---|---|---|
| `dart analyze --fatal-infos lib test` | clean | clean | clean |
| `flutter test` | 914 pass / 4 skip | 177 pass | 174 pass |
| `flutter build macos --debug` | n/a | built | built |

Windows and Linux compile in CI only; nothing here claims their runtime
behaviour.

## What changed in the shape of an approved design (read these first)

Seven departures are recorded with their reasons in `summary.md` §"Where the
implementation departs from the plan's letter". The two a reviewer should look at
before anything else:

1. **The chrome toggle's disabled reason is a semantics hint, not a line of text
   under the control.** FD frontend-components §3/§6 ask for visible text. It
   overflows the narrow layout's `AppBar` by 8 px (the control) and 319 px (the
   toolbar), on the 375x812 test surface. The control is one line in both
   layouts and the reason is the accessible hint; the in-surface toggle inside
   the caption surface carries visible copy.
2. **`PopOutInSurfaceToggle` in the main window is always enabled.** FD §4 says
   it obeys the availability rule there. It cannot: the rule is
   `sessionActive && engineAvailable`, and the shell's flag gates the window, not
   the toggle — gating the only entry point on the flag would disable it
   permanently.

## For Unit 9 (manual checks, still unclaimed)

1. The pop-out floats above normal windows.
2. It is decorated, resizable and movable.
3. Its minimum size (200x120 window, 320x96 content policy) is honoured.
4. The OS close button clears the banner and the toggle in the same frame — on
   macOS, Windows and Linux (Linux does **not** degrade to the `'-1'` fallback).
5. The external display window is still borderless after styling moved into
   `configure`.
6. Multi-monitor placement behaves.
7. `window.delegate` is intact and no generated registrant runs inside a window
   callback (code review, not a manual run).
8. The chrome allowance constants (44 px toggle row, 8 px padding) are estimates;
   measure them.

## For Documentation Refinement

- `pip-ux-parity.md` §8.8 item 13 and UX-PIP-10: the Q9 amendment (75% of the
  work-area width, two rendered lines plus the toggle row, bottom-anchored,
  min 320x96, decorated, resizable) still needs applying with the owner's name and
  date — carried from Functional Design.
- `pip-ux-parity.md` §8.4: BR-PIP-13's mechanism sentence should name the
  `Semantics(hint:)` rendering the code now uses, not "next to it".
- FD frontend-components §3 (disabled reason), §4 (in-surface enablement) and §6
  ("rendered once, in `PopOutControls`") need the two corrections above.
- `tech-stack-decisions.md` §3/§4 corrections from Infrastructure Design are
  already applied; the registrant movement is real (`zip_broadcast` lost
  `screen_retriever_*`, `zip_captions` gained both) and the generated files were
  produced by the tools, never edited.
- `aidlc-state.md`'s Unit 8.1 narrative still carries the superseded
  `window_manager` prose; the "Known stale prose" note covers it.

## Open items

- The `OverlayWindowHost`/`overlay_window_host_provider.dart` export in
  `providers.dart` is unstaged (see above).
- No `pod install` was run for `zip_broadcast`; its `Podfile.lock` did not change
  and its build succeeded, so nothing is pending.
- Nothing is BLOCKED.