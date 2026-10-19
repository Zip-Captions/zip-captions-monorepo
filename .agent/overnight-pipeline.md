# Overnight pipeline — Zip Captions (instantiation of the generic process)

Derived from `kestra/overnight-pipeline-generic.md` (the authoritative process
definition). This file supplies the **Run configuration** and the
**AI-DLC adaptations** the generic template says to make before kickoff, never
mid-run. Where this file and the generic document disagree, this file wins for
this repo; where this file is silent, the generic document governs.

## Run configuration

| Key | Value |
|---|---|
| `repo` | `Zip-Captions/zip-captions-monorepo`, remote `origin` (`git@github.com:...`), base branch `develop`, merge style **squash** |
| `units` | **One unit: `zip-captions-viewer` (Unit 7, S-19).** Branch `feature/zip-captions-viewer`, already created off `develop` at `63f7d42`. Spec: `aidlc-docs/construction/zip-captions-viewer/functional-design/` (approved 2026-10-18) plus `aidlc-docs/inception/user-stories/phase2-stories.md` S-19 and `aidlc-docs/inception/application-design/phase2-*.md`. Subject: "Unit 7: Zip Captions Viewer (S-19)". |
| `prior state` | The Functional Design stage commit (`docs(zip-captions-viewer): functional design (S-19)`) is already on the branch and pushed. **No PR may be opened at Step 0**: the branch carries only docs, and Code Generation has not run. The PR is opened after the last build step of this unit (see Adaptations, A3). |
| `standing file` | `AGENTS.md` at the repo root. "Done means": `melos run analyze` (runs `dart analyze --fatal-infos` per package, **zero warnings and infos**) and `melos run test` (all packages green), plus the pre-push hook `scripts/install-hooks.sh` installs, which blocks a push on any warning/info. |
| `gates` | `cd packages/zip_core && dart analyze --fatal-infos`, `cd packages/zip_captions && flutter test`, `cd packages/zip_core && flutter test`. Run from the package roots: melos is not guaranteed on PATH in a fresh subagent, and the two packages are the only ones this unit touches. |
| `report format` | AI-DLC artifacts, not a bespoke report: `aidlc-docs/construction/zip-captions-viewer/{nfr-requirements,nfr-design}/` and `aidlc-docs/construction/zip-captions-viewer/code/` summaries, plus one mandatory `handoff-summary.md` per stage (30-50 lines, format in `aidlc-project-rules/construction/stage-handoff.md`). The plan files live in `aidlc-docs/construction/plans/`. Every stage's completion entry goes in `aidlc-docs/audit.md`. |
| `external deps` | None required. The local Supabase stack and Docker are **not** started by the run: this unit's tests are all fake-backed (the Unit 5/6 precedent). The real-backend tests under `test/integration/` are `@Tags(['integration-supabase'])` and skipped by default; the run must not enable them. |
| `device policy` | **Not applicable for this run.** Unit 7's deliverables are docs, `zip_core` logic, and `zip_captions` widget tests. No emulator, no simulator, no `flutter run`. If a build subagent believes it needs a device, that is a BLOCKED condition, not a reason to start one. |
| `review grounding` | Primary: the `agentic-code-review` skill (load it, follow it). Secondary: `docs-mcp` for Flutter/Dart library claims, `ai-dlc-vault` via `obsidian_*` tools for codebase orientation. Contracts that override review opinions: `AGENTS.md` "Boundaries" and "Security-Critical Code" sections, `docs/04-technical-specification.md` Sections 1-2 (code style) and 8-9 (transcript-content and RLS constraints). Known-defect exclusions: every open Backlog entry in `aidlc-docs/aidlc-state.md` is deliberate and must not be re-reported (pop-out PiP, accessibility pass for the Broadcast UI dashboard, Windows/Linux OAuth, crash SDK, Coturn sizing, `BroadcastLimits` interim values). |
| `unit exceptions` | Unit 7 touches two things the repo flags: (1) `ConnectFailure` is an **additive-only** extension — a review finding that proposes changing the four existing variants is a blocker, not a suggestion; (2) `OnScreenCaptionTarget` is constructed with `repository: null` by design (remote captions never persisted) — "this should save transcripts" is not a finding. Neither exempts the unit from review or merge. |
| `review cap` | 3 rounds of the local review loop per unit. **CodeRabbit is requested separately** and is not counted against that cap (see A6). |
| `ledger path` | `aidlc-docs/overnight-ledger.md` (gitignored; entry format exactly as the generic document defines). |

## AI-DLC adaptations (agreed before kickoff, 2026-10-18)

The generic template assumes a "unit = one build + one PR" shape. AI-DLC units
have mandatory stages with approval gates, so:

### A1 — The pipeline item is the *stage*, not the unit

The build loop runs **once per stage**, serial, in this order:

1. `nfr-requirements`
2. `nfr-design`
3. `code-generation` Part 1 (planning only — no production code)
4. `code-generation` Part 2 (implementation, tests, l10n, final gates)

Each stage is one build subagent invocation. Each is a separate `BUILD_VERIFIED`
gate (gates run + that stage's artifacts + clean tree) and a separate ledger
entry, so a crash resumes at the next unfinished stage rather than the top of
the unit.

### A2 — Approval gates are pre-approved, with a morning review recorded

Stages 1-3 normally wait for an explicit human approval. For this run the
approval is **pre-granted by the run configuration** and each stage's completion
is recorded in `audit.md` with `approved by: run configuration
(.agent/overnight-pipeline.md, 2026-10-18) — subject to morning review` instead
of a user quote. The final summary lists every stage for the morning pass.

Stage 4 (Code Generation Part 2) is also authorized to run. **The PR is not
merged by the pipeline.** Merge stays a human decision, matching every prior
unit in this repo.

### A3 — One PR per unit, opened after the last build stage

`gh pr create --base develop --head feature/zip-captions-viewer` runs once,
after Code Generation Part 2's `BUILD_VERIFIED`. The PR body carries the
command summary, a pointer to `aidlc-docs/construction/zip-captions-viewer/`,
and the list of stages completed. `PREVIOUS_MERGED` is trivially satisfied (the
prior unit, Unit 6, is merged as `bc19984`).

### A4 — The review loop reviews the whole branch diff, not a unit-sized diff

The local review subagent reviews `gh pr diff`, which after this run is the
Functional Design commit plus four stages of work. It is told the stage
boundaries explicitly so it does not treat the design documents as code to
review for style, and so it reviews the *implementation against the approved
design* rather than re-litigating approved decisions (Q1-Q10 and the 14
business rules are settled; a finding that contradicts one is a fact-check
against that decision's rationale, not a style opinion).

### A5 — Scope fence for the build subagents

Each stage subagent is told: only files this stage's plan names, only packages
`zip_core` and `zip_captions`, no new dependencies (the FD approved zero; a
dependency need is BLOCKED), no changes to `docs/` (spec documents are
Documentation Refinement's job, with per-change approval), and no touching
`packages/zip_broadcast/macos/Podfile.lock` (a pre-existing unrelated dirty
file — the orchestrator leaves it alone and it must never be staged).

### A6 — CodeRabbit on the final PR

After the last local review round (or immediately, if the local reviewer
approves on round 1), the orchestrator triggers one CodeRabbit review on the
final PR head and waits for it. Findings are handled by the same fix subagent
flow, and **CodeRabbit does not consume the local review-round cap**. If
CodeRabbit has not responded within 45 minutes, record it in the ledger and
finish the run with the PR open and CI green — a pending automated review is
not a blocker for handing the PR to a human.

Trigger, in order of preference:

1. `gh pr comment <n> --body "@coderabbitai review"`
2. `gh pr edit` adding the `coderabbitai` reviewer, if the app is configured on the repo
3. If neither produces a review within 45 minutes, record `CODERABBIT: unavailable` in the ledger and the final summary.

The run **must not** request a second CodeRabbit pass (the repo hit the
"one review per hour" limit during Unit 6).

### A7 — Unit 7 specifics the subagents must be told

- **Web is deferred.** The two S-19 web acceptance criteria are recorded as
  deferred to Phase 5 in `aidlc-state.md`. Do not scaffold `web/`, do not add a
  web CI job, do not add security headers. Platform-neutrality still applies:
  no `dart:io` in the viewer path.
- **`broadcastBaseUrl` is scheduled work.** `BroadcastLink.baseUrl` becomes
  `String.fromEnvironment('BROADCAST_BASE_URL', defaultValue:
  'https://zipcaptions.app/b/')` following `supabase_config.dart` /
  `turn_config.dart`. `parseInput` stays host-agnostic.
- **PBT framework is the in-tree shim.** There is no `glados` dependency.
  `test/helpers/pbt.dart` provides `Generator<T>`, `any`, and
  `Glados<T>(gen).test(desc, async (value) {...})` (100 seeded trials).
  NFR Requirements records this as the PBT-09 decision rather than
  re-selecting `glados`.
- **The three 2026-10-18 corrections are binding**: `connect()` throw →
  `CannotConnect(IceFailed)`; window expiry with no status emission →
  `CannotConnect(ResolutionFailed)`; `_ViewerResources` non-null except
  `Idle`/`InvalidInput`. Rule 14 (no notifier-owned retry loop) is binding.
- **Fix the stale `Findings` list**: `aidlc-docs/audit.md` currently ends at the
  Unit 6 merge. Code Generation Part 2 must add the Unit 7 entries.

## Kickoff message

Paste as the entire first message of a fresh session at the repo root:

```
Read .agent/overnight-pipeline.md and execute it from the start, using its Run
configuration section, with kestra/overnight-pipeline-generic.md as the
process definition it instantiates. This is the unattended overnight run it
defines. Do not ask me questions — the document contains the assumptions
policy.
```

## Kickoff preconditions (orchestrator checks before Step 0)

- `git status --short` shows only `M packages/zip_broadcast/macos/Podfile.lock`
  (pre-existing, unrelated, never staged).
- The branch's first commit is the Functional Design commit and it is pushed.
- No `aidlc-docs/overnight-ledger.md` newer than 30 minutes with a `next:` that
  is not `PIPELINE COMPLETE` (`RUN_UNIQUE`).