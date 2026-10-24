# Infrastructure Design Plan — Unit 8.1: Pop-out Live Captions (S-21)

**Unit**: 8.1 — Pop-out Live Captions (PiP)
**Prior stage**: NFR Design, APPROVED 2026-10-21 by James Petersen (`aidlc-docs/construction/pop-out/nfr-design/`)
**Packages**: `zip_core` (two new dependencies, both behind the `_io` fence), `zip_broadcast` (one dependency removed), `zip_captions` (one dependency added)
**Branch**: `feature/popout-live-captions` (local only; no PR in this run)
**Run mode**: unattended per `.agent/overnight-pipeline.md` (A1 stage 1, A2, A5, A7). There is no human to answer an `[Answer]:` tag, so the stage rule's question step is discharged by the run configuration: every question this stage could ask is either already answered by the approved design, adjudicated in the run task, or — if genuinely new — a ledger BLOCKED entry. No such question was found (see "Open questions").

**Revision note.** This is the first Infrastructure Design artifact for Unit 8.1. It follows the structural precedent of `aidlc-docs/construction/external-display/infrastructure-design/` (one `infrastructure-design.md` + `handoff-summary.md`, no `deployment-architecture.md`; justification below), and applies the run configuration's corrected expectation for the generated plugin registrants (A1 item 3's "no movement in `zip_broadcast`" is factually wrong — see ID-4).

## Context: what "infrastructure" means for this unit

There is **no cloud, self-hosted, CI or shared infrastructure** in this unit. No backend, no Docker, no Supabase, no new endpoint. The deployment surface is three desktop runners per app (six files), the two platform-channel contracts they implement, and the dependency graph that decides which plugin each sub-engine can reach. The generic AI-DLC categories evaluate as follows:

| Category | Applicability | Justification |
|---|---|---|
| Deployment Environment | **The six runners are the deployment surface** | Hand-written native code lands in `packages/{zip_broadcast,zip_captions}/{macos/Runner/MainFlutterWindow.swift, windows/runner/flutter_window.cpp, linux/runner/my_application.cc}`. ID-2 names the exact insertion points and bodies. |
| Compute Infrastructure | N/A | No compute service. Each pop-out is a Flutter engine inside the user's app process. |
| Storage Infrastructure | N/A | Q10 B: no persistence of pop-out state, size or position. No store added. |
| Messaging Infrastructure | N/A as a service; **decisive as a mechanism** | Three local platform channels: the plugin's two (`mixin.one/flutter_multi_window`, `mixin.one/flutter_multi_window_channel`) and the two first-party channels (`zip_core/overlay_window_configure`, `zip_core/overlay_sub_window_events`). Their reliability at close time is the whole subject of verify items 1-4. |
| Networking Infrastructure | N/A | No network. `desktop_multi_window` and `screen_retriever` are local plugins. |
| Monitoring Infrastructure | N/A | Existing `package:logging`, fixed strings (BR-PIP-11). Nothing new. |
| Shared Infrastructure | N/A | Root `pubspec.lock` (workspace) and each app's `macos/Podfile.lock` are the only shared artifacts, and both are fenced in ID-5. |

**Artifact shape.** Single `infrastructure-design.md` + `handoff-summary.md`; no `deployment-architecture.md`. Precedent: Units 3, 4, 5, 6, 7 and 8 each shipped that shape, and this unit has no deployment topology to diagram.

---

## Planned steps

- [x] Step 1 — Read the binding inputs in the run configuration's order (NFR Design handoff + patterns + logical components; NFR Requirements all three; Functional Design all files; pre-build review; answer records; S-21 / Unit 8.1 / §8).
- [x] Step 2 — Settle the NFR Design handoff's verify-not-assume list, items 1-6, against plugin source and the Flutter SDK (never documentation). Evidence table: `infrastructure-design.md` §2; every claim carries `file:line`.
- [x] Step 3 — Item 4's pre-decided branch: decide `delete-event` vs `"destroy"` on Linux from source. Result: `"destroy"` is connectable and is the only hook that runs on every close path; the `'-1'` degradation is **not** triggered, and stays only as the generic fallback.
- [x] Step 4 — Specify the per-runner code: the sub-engine `zip_core/overlay_window_configure` handler (ID-2a, all six runners, including the three `zip_captions` runners that have no callback today) and the main-engine `zip_core/overlay_sub_window_events` registration (ID-2b). Includes the per-runner native close-id map (macOS `NSWindow` → id, Windows `HWND` → id, Linux `GtkWidget*` → id).
- [x] Step 5 — Nail `zip_captions` entry routing (ID-1): `main(List<String> args)` → `runZipCaptions(args, {runApp, isWeb})` → overlay branch returns before Supabase, SharedPreferences, logging and GoogleFonts.
- [x] Step 6 — Correct the generated-file fence (ID-4): the registrants are **tracked**, and the movement is the one the dependency graph implies, per file, per app, per platform.
- [x] Step 7 — Apply the NFR Design handoff's three open documentation corrections in place, plus the §3 fence correction and the §4 `fake_async` correction, each logged in `audit.md` (Step 8).
- [x] Step 8 — Record the stage completion in `audit.md` (approval line exactly as the run configuration prescribes) and update `aidlc-docs/aidlc-state.md` (Unit 8.1 entry + both current-stage lines).
- [x] Step 9 — Gates: `dart analyze --fatal-infos` then `flutter test` in `packages/zip_core`, `packages/zip_broadcast`, `packages/zip_captions`.
- [x] Step 10 — Handoff summary (`handoff-summary.md`, 30-50 lines, `aidlc-project-rules/construction/stage-handoff.md` format) and the ledger entry.

## Questions: why none were asked

The stage rule says to ask when there is any ambiguity. This run has no human (A2), and the approved design plus the task's four adjudicated decisions settle every ambiguity this stage touches:

| Question the stage could ask | Settled by |
|---|---|
| Where does the close notification live natively, and how does it know the window id? | FD BLM §3.2 ("the sub-engine passes the window id it was launched with (`args[1]`), because the native callback cannot know it otherwise"); adjudication D2 fixes the per-runner map. |
| macOS / Windows / Linux: which hook? | Adjudication D2, derived from the plugin source re-verified here (ID-3). |
| Does Linux fall back to `'-1'`? | A1 item 4's condition ("if no notification is connectable") is false: `"destroy"` is connectable (ID-3c). Recorded, not redesigned. |
| Which channel names? | NFR Design L5: `zip_core/overlay_window_configure`, `zip_core/overlay_sub_window_events`. |
| Where in `zip_captions` does the overlay branch go? | Adjudication D1 + the NFR-R clarification answer A recorded in `audit.md` (`runZipCaptions` seam). |
| Which registrant files move, and how? | Adjudication D4 + the pubspec graph. A1 item 3's "no movement in `zip_broadcast`" is a factual error, corrected in ID-4 and logged. |
| Which SDK? | Flutter 3.41.7 local, 3.38.7 CI; the claims are restricted to APIs present in both (ID-2f). |

**Open questions: none.** No ledger BLOCKED entry was needed.