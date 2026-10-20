# Overnight pipeline — Zip Captions (instantiation of the generic process)

Derived from `kestra/overnight-pipeline-generic.md` (the authoritative process
definition). This file supplies the **Run configuration** and the
**AI-DLC adaptations** the generic template says to make before kickoff, never
mid-run. Where this file and the generic document disagree, this file wins for
this repo; where this file is silent, the generic document governs.

The previous instance of this file (Unit 7, 2026-10-18) is in git history.

## Run configuration

| Key | Value |
|---|---|
| `repo` | `Zip-Captions/zip-captions-monorepo`, remote `origin` (`git@github.com:...`), base branch `develop`, merge style **squash** |
| `units` | **One unit: `external-display` (Unit 8, S-20).** Branch `feature/external-display`, already pushed, **PR #37 already open** against `develop`. Subject: "Unit 8: External Display (S-20)". **Authoritative design input: the review comment on PR #37** (<https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308>, 2026-10-19). Its §1 decisions D-1..D-13 are settled, its §2 B-1..B-9 are required changes, its §3 is the rewrite list, and its §4 is the process list. Plus the A7 items below, which postdate the comment. Other specs: the current artifacts under `aidlc-docs/construction/external-display/`, `aidlc-docs/inception/user-stories/phase2-stories.md` S-20, `aidlc-docs/inception/application-design/phase2-*.md`, and approved Proto-13 (`aidlc-docs/construction/phase2-unit1-prototypes/prototypes/zip-broadcast-external-display.html`). |
| `prior state` | PR #37 is design-only at `d7f5845`. Functional Design, Infrastructure Design and the CG Part 1 plan exist as **PROPOSED** (never approved) and are partly superseded by the review comment. The FD plan's OQ answer table (`6f4eaea`) is superseded. No production code exists for this unit. **No new PR is opened**: the run pushes to `feature/external-display` and updates PR #37's body (A3). |
| `standing file` | `AGENTS.md` at the repo root. "Done means": `melos run analyze` (runs `dart analyze --fatal-infos` per package, **zero warnings and infos**) and `melos run test` (all packages green), plus the pre-push hook `scripts/install-hooks.sh` installs, which blocks a push on any warning/info. |
| `gates` | Every stage: `cd packages/zip_broadcast && dart analyze --fatal-infos && flutter test`; `cd packages/zip_core && dart analyze --fatal-infos && flutter test`; `cd packages/zip_captions && dart analyze --fatal-infos && flutter test`. The last two are regression guards: this unit must not change either package. Code Generation Part 2 additionally runs `cd packages/zip_broadcast && flutter build macos --debug`, which compiles the Swift runner change (compile only, nothing is launched). Windows and Linux runner code is compiled by CI's `build-verify.yml` after the push; **CI must be green** before the run hands off. Run from package roots: melos is not guaranteed on PATH in a fresh subagent. |
| `report format` | AI-DLC artifacts, not a bespoke report. They go under `aidlc-docs/construction/external-display/{functional-design,nfr-requirements,nfr-design,infrastructure-design,code}/`, with one mandatory `handoff-summary.md` per stage (30-50 lines, format in `aidlc-project-rules/construction/stage-handoff.md`). Plans live in `aidlc-docs/construction/plans/`. Every stage's completion entry goes in `aidlc-docs/audit.md`. |
| `external deps` | None. The local Supabase stack and Docker are **not** started; this unit has no backend. The real-backend tests under `test/integration/` stay skipped by default. |
| `device policy` | No emulator, no simulator, no `flutter run`, no launched app. `flutter build macos --debug` is allowed (compile only). No multi-monitor hardware is assumed. Display placement, borderless rendering, the reopen-on-reconnect flow and closing by OS shortcut are **Unit 9 manual checks**. Record them as such; do not claim them verified. A subagent that believes it needs a device or a second display has hit a BLOCKED condition, not a reason to start one. |
| `review grounding` | Primary: the `agentic-code-review` skill (load it and follow it). Secondary: `docs-mcp` for Flutter/Dart library claims. **Plugin claims are checked against package source in the pub cache**, not against documentation: `desktop_multi_window` 0.2.1, and `screen_retriever` 0.2.2 with its federated packages. That is how every defect in the review comment was found. Contracts that override review opinions: the PR #37 review comment (D-1..D-13 and the A7 items are settled; a finding that contradicts one is a fact-check against its stated rationale, not a style opinion); `AGENTS.md` "Boundaries" and "Security-Critical Code"; `docs/04-technical-specification.md` §1-2 and §8-9. Known-defect exclusions: every open Backlog entry in `aidlc-docs/aidlc-state.md` is deliberate, including the three this run adds (native full-screen, per-input caption colour, the pop-out unit). |
| `unit exceptions` | (1) **`zip_core` is consumed as shipped.** Any change there is BLOCKED, not a fix (D-8 keeps the codec in `zip_broadcast`). (2) **Hand-written native runner code on macOS, Windows and Linux is in scope** (D-2). "Native code without a local build to verify it" is not a finding by itself; Windows/Linux are compile-verified by CI, and behaviour is a Unit 9 manual check. (3) **External display is not tied to recognition** (D-5). "The window should close when captioning stops" is not a finding: S-20 AC4 is amended by this run. |
| `review cap` | 3 rounds of the local review loop. **CodeRabbit is requested separately** and does not count against that cap (A6). |
| `ledger path` | `aidlc-docs/overnight-ledger.md` (gitignored; entry format exactly as the generic document defines). |

## AI-DLC adaptations (agreed before kickoff, 2026-10-19)

The generic template assumes a "unit = one build + one PR" shape. AI-DLC units
have mandatory stages with approval gates, so:

### A1 — The pipeline item is the *stage*, not the unit

The build loop runs **once per stage**, serial, in this order:

1. `functional-design` **revision**:
   - Apply the review comment's §1-§3, plus the A7 items.
   - Rewrite the FD plan's answer table as `[Answer]:` entries (A2).
   - Add `frontend-components.md` and the PBT-01 property list.
   - Add a Security Baseline compliance section.
   - Record the Application Design deviations listed in review §3.
   - Make the Inception amendments in A5's list.
2. `nfr-requirements`
3. `nfr-design`
4. `infrastructure-design` **revision**:
   - Add `external-display-infrastructure-design-plan.md`.
   - Rewrite ID-1..ID-7 per B-1..B-6, D-2, D-3 and D-13.
   - Add a compliance section.
5. `code-generation` Part 1: **regenerate** the plan from the revised design (planning only, no production code).
6. `code-generation` Part 2: implementation, tests, l10n, final gates.

Each stage is one build subagent invocation. Each is a separate `BUILD_VERIFIED`
gate (gates run + that stage's artifacts + clean tree) and a separate ledger
entry, so a crash resumes at the next unfinished stage rather than the top of
the unit.

### A2 — Approval gates are pre-approved, with a morning review recorded

**Human decisions.** The design decisions are **not** the run's to make.
James Petersen made them in the PR #37 review comment (2026-10-19) and in A7.
The FD plan records them as `[Answer]:` entries attributed to him, citing the
comment URL. The `6f4eaea` answers are marked superseded.

**Stage approvals.** Stages 1-5 are pre-approved by this run configuration.
Each stage's completion is recorded in `audit.md` with `approved by: run
configuration (.agent/overnight-pipeline.md, 2026-10-19) — subject to morning
review`.

**Stage 5 gate.** Part 2 proceeds only if the regenerated plan is a strict
transcription of the revised design, with no open questions. The review
comment closes every known question. If a stage finds a **genuinely new**
question (one the comment and A7 do not answer):
- record it in the ledger as BLOCKED with the question verbatim,
- commit what is verified,
- push (A3),
- stop.

Never guess an answer to a design question.

**Stage 6.** Code Generation Part 2 is also authorized to run. **The PR is not
merged by the pipeline.** Merge stays a human decision.

### A3 — No new PR; push once, at the end or on BLOCKED

- Commit per stage (the clean-tree gate).
- Push `feature/external-display` once, after Stage 6's `BUILD_VERIFIED`, or
  earlier only on BLOCKED.
- Then rewrite PR #37's body with `gh pr edit 37 --body-file ...`. Today the
  body describes a design-only PR with three open questions. The new body
  carries:
  - the stages completed,
  - the gate output,
  - a pointer to the review comment,
  - the list of Unit 9 manual checks.
- `PREVIOUS_MERGED` is trivially satisfied (Unit 7 merged as PR #36).

### A4 — The review loop reviews the run's work against the review comment

The local review subagent reviews `git diff d7f5845..HEAD`, excluding the
`develop` merge from Step 0. It is told the stage boundaries explicitly, so it
does not treat the design documents as code to review for style. It reviews:
- the revised design against the review comment,
- the implementation against the revised design.

It also checks the high-risk items by reading source, not by reasoning:
- the macOS/Windows frame conversion (B-1/B-2),
- the handshake and error-code discrimination (B-5),
- the runner callbacks (B-3/B-4),
- the codec's malformed-input and size-guard behaviour (B-7).

### A5 — Scope fence for the build subagents

**Allowed:**
- `packages/zip_broadcast/` `lib/`, `test/` and `l10n/`.
- `packages/zip_broadcast/pubspec.yaml`: add `screen_retriever: ^0.2.2` with
  its SECURITY-10 comment, nothing else.
- The `macos/`, `windows/` and `linux/` runners: the window-created callbacks
  for borderless rendering and sub-engine plugin registration, nothing else.
- The root `pubspec.lock`: `screen_retriever` and its four federated entries
  only. Anything else that moves is reported in the PR body, not silently
  committed.
- `packages/zip_broadcast/macos/Podfile.lock`: only the `screen_retriever`
  pod entries that `flutter build macos` adds.
- `aidlc-docs/` per the stages.

**Inception amendments (exactly these):**
- `phase2-stories.md` S-20 AC4 (D-5).
- `phase2-unit-of-work.md`: Unit 8's stage list and its summary-table row
  (FD, NFR-R, NFR-D, ID, CG) (D-10).
- `aidlc-state.md` Backlog:
  - Rewrite the pop-out entry per A7.
  - Add native full-screen (D-3).
  - Add per-input caption colour (D-7).
- The Unit 8 entry and the current-stage line in `aidlc-state.md`.

**Forbidden:**
- Any change to `zip_core`, `zip_captions` or `zip_supabase`.
- `window_manager` (D-13), and any new dependency other than
  `screen_retriever` (a dependency need is BLOCKED).
- `docs/` (including the roadmap).
- The pop-out unit's definition.
- `pip-ux-parity.md` (also on PR #38), `aidlc-docs/v1-parity/`, `spikes/`.
- `opencode.json`.

### A6 — CodeRabbit on the final PR

After the last local review round (or immediately, if the local reviewer
approves on round 1), the orchestrator triggers one CodeRabbit review on the
final PR head and waits for it.
- `aidlc-docs/**` is path-filtered by `.coderabbit.yaml`, so CodeRabbit reviews
  only the `packages/` code. That is expected, not a failure.
- Findings are handled by the same fix-subagent flow, and **CodeRabbit does not
  consume the local review-round cap**.
- If CodeRabbit has not responded within 45 minutes, record it in the ledger
  and finish the run with the PR open and CI green.

Trigger, in order of preference:

1. `gh pr comment 37 --body "@coderabbitai review"`
2. If that produces no review within 45 minutes, record `CODERABBIT: unavailable` in the ledger and the final summary.

The run **must not** request a second CodeRabbit pass (the repo has hit the
"one review per hour" limit before).

### A7 — Unit 8 specifics the subagents must be told

**The review comment is binding.** Treat it as the design input, not
commentary. In particular:
- **D-4 and D-5 replace the old state machine**: no move to the primary
  display, and the window is not tied to recognition.
- **D-9 replaces the ping probe.**
- **B-1/B-2 coordinate conversions:**
  - macOS: y-flip with `cocoaY = primaryFullHeight − top − height`.
  - Windows: **multiply** by that display's `scaleFactor` (not divide).
  - Both live in one pure, unit-tested function inside the io window adapter.
- **B-8:** Proto-13's Top/Bottom caption-position selector, persisted, and an
  opaque surface.

**Pop-out placement (decided 2026-10-19, after the comment).** The pop-out is a
**Phase 2 unit after Unit 8**, reusing Unit 8's window machinery: desktop
native always-on-top plus web Document Picture-in-Picture, toggles, hint and
return, theme, and size. Its translation-dependent parts are **Phase 8
deliverables**: the content setting taking effect, and the layout/translation
controls inside the pop-out (`pip-ux-parity.md` §8.8 item 10). It **blocks the
v2.0 release candidate** (roadmap Phase 6 Definition of Done, PR #38). The
Backlog entry says exactly this, plus "unit definition pending (interactive
Inception session)".

**Coordination with PR #38 (roadmap v0.4).**
- External display output is a v2.0 release-gate item.
- Phase 8 later adds bilingual mode to the external display ("Bilingual mode in
  browser source and external display outputs").
- Unit 8 adds **no** translation fields (YAGNI). The FD records the extension
  path as a forward note:
  - the codec's per-entry `key` **is `CaptionDisplayEntry.entryId`**, the
    segment ID that Phase 8 keys translations by;
  - the codec's `v` field is the version bump Phase 8 will use.

**macOS window-created callback.** `FlutterWindow.swift` assigns
`window.contentViewController` before invoking `onWindowCreatedCallback`, and
AppKit installs the controller's view as the window's content view on that
assignment. So `controller.view.window` is the sub-window inside the callback.
Use the callback directly; do **not** build the `didBecomeKey`/order-on-screen
observer from the current ID-5. Record "borderless applied on macOS" as a Unit 9
manual check.

**Testing:**
- The PBT framework is the in-tree shim `packages/zip_broadcast/test/helpers/pbt.dart`.
  There is no `glados` dependency.
- `fake_async` and `mocktail` are already `zip_broadcast` dev dependencies; use
  `fake_async` for the ready-timeout tests.
- Extend `test/helpers/mock_desktop_window_service.dart` for the new
  `setFrame`/`show` methods (B-6).

**Strings and logging:**
- Strings go in `l10n/arb/app_en.arb`, then run `flutter gen-l10n`; never edit
  the generated Dart l10n files.
- Logs are fixed strings plus an error type, never caption text (BR-U8-18).
- Web is excluded by `DesktopWindowService.isSupported`, never by `kIsWeb`.

**Step 0 (before Stage 1).**
1. Commit this file alone as `chore(agent): Unit 8 overnight run
   configuration`. That is the only `.agent/` change the run makes.
2. `git merge origin/develop` into `feature/external-display`, as a merge
   commit. No rebase and no force-push: the branch backs an open PR.
3. Run the gates. This brings PR #38's roadmap and regenerated `Podfile.lock`
   onto the branch, so this run's lockfile diff is only `screen_retriever`.
4. The `pip-ux-parity.md`/`v1-parity/` files arrive identically from both
   branches and need no action.

**Logs to fix.** `aidlc-docs/audit.md` has no Unit 8 entries. Stage 1 adds:
- the three PROPOSED stages from the earlier run,
- the 2026-10-19 review decisions (D-1..D-13 plus the A7 pop-out placement),
- then each stage of this run as it completes.

`aidlc-state.md`'s current-stage line still says Unit 7 is next for
Documentation Refinement, but Unit 7 merged as PR #36. Correct it.

## Kickoff message

Paste as the entire first message of a fresh session at the repo root:

```
Read .agent/overnight-pipeline.md and execute it from the start, using its Run
configuration section, with kestra/overnight-pipeline-generic.md as the
process definition it instantiates. That document is the ONLY thing you may
read from the Obsidian vault — do not read the rest of the vault, and do not
use the vault for codebase orientation during this run (the PR #37 review
comment and the handoff summaries under
aidlc-docs/construction/external-display/ serve that purpose). This is the
unattended overnight run it defines. Do not ask me questions — the document
contains the assumptions policy.
```

## Kickoff preconditions (orchestrator checks before Step 0)

- **PR #38 is merged to `develop`.** If it is not, do not start: Step 0's merge
  and the lockfile fence both depend on it.
- PR #37 is open, and `feature/external-display` is pushed and matches
  `origin/feature/external-display`.
- `git status --short` on `feature/external-display` shows exactly one line,
  ` M .agent/overnight-pipeline.md` (this file, written in the review session and
  deliberately left uncommitted). Anything else is a precondition failure.
- There is no `aidlc-docs/overnight-ledger.md` entry newer than 30 minutes
  whose `next:` is not `PIPELINE COMPLETE` (`RUN_UNIQUE`).
