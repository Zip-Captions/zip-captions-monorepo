# Overnight pipeline — Zip Captions (instantiation of the generic process)

This file instantiates `kestra/overnight-pipeline-generic.md`, the authoritative process definition.
It supplies the **Run configuration** and the **AI-DLC adaptations** that the generic template says
to settle before kickoff, never mid-run. Where this file and the generic document disagree, this
file wins for this repo. Where this file is silent, the generic document governs.

The previous instance of this file (Unit 8, 2026-10-19) is in git history.

## Run configuration

| Key | Value |
|---|---|
| `repo` | `Zip-Captions/zip-captions-monorepo`, remote `origin` (`git@github.com:...`), base branch `develop`, merge style **squash** |
| `units` | **One unit: `pop-out` (Unit 8.1, S-21).** Branch `feature/popout-live-captions`, **local only: never pushed, no PR**. Subject: "Unit 8.1: Pop-out Live Captions (S-21)". See "Binding design inputs" below for the inputs. |
| `prior state` | Functional Design, NFR Requirements and NFR Design are **APPROVED** (owner, 2026-10-21) and committed on the branch (the last Unit 8.1 design commit is `72c7cd8`). They were revised after a pre-build review. Two later owner commits on the branch (`218eba7`, `ad59013`; head `ad59013` before Step 0) park an unrelated unit's design docs under `aidlc-docs/construction/on-device-multilingual-stt/` and its plans. They are **not part of Unit 8.1**. Leave them untouched; they ride along in the PR. Infrastructure Design and Code Generation have **not started**. No production code exists for this unit. PR #40 (`fix/zip-broadcast-runner-callbacks`: Unit 8 runner callback signatures, the Unit 2 Windows `SendAppLinkToInstance` helper, the MSVC coroutine define, and zip_broadcast desktop jobs in `build-verify.yml`) must be **merged to `develop` before kickoff** (see preconditions). The run opens a **new** PR at the end (A3). |
| `standing file` | `AGENTS.md` at the repo root. "Done means": `melos run analyze` (runs `dart analyze --fatal-infos` per package; **zero warnings and infos**) and `melos run test` (all packages green). The pre-push hook that `scripts/install-hooks.sh` installs blocks a push on any warning or info. |
| `gates` | **Every stage**, run from the package roots (melos is not guaranteed on PATH in a fresh subagent): `cd packages/zip_core && dart analyze --fatal-infos && flutter test`, then the same in `packages/zip_broadcast`, then in `packages/zip_captions`. **Code Generation Part 2 adds** `flutter build macos --debug` in **both** `packages/zip_broadcast` and `packages/zip_captions` (compile only; nothing is launched). The Windows and Linux runner code of both apps is compiled by CI's `build-verify.yml`, which builds both apps on all three desktops since PR #40. **CI must be green** before the run hands off. |
| `report format` | AI-DLC artifacts, not a bespoke report. They go under `aidlc-docs/construction/pop-out/{infrastructure-design,code}/`, with one mandatory `handoff-summary.md` per stage (30-50 lines, format in `aidlc-project-rules/construction/stage-handoff.md`). Plans: `aidlc-docs/construction/plans/pop-out-infrastructure-design-plan.md` and `pop-out-code-generation-plan.md`. Every stage's completion entry goes in `aidlc-docs/audit.md`. The code summary carries the BR-U8.1-10 table (one row per `pip-ux-parity.md` §8.8 item: `tested` / `platform-check (Unit 9)` / `deferred (Phase 8)`, **per app** where §8.8 requires it) and the NFR-R §5.1 refactor proof. |
| `external deps` | None. The local Supabase stack and Docker are **not** started; this unit has no backend. The real-backend tests under `test/integration/` stay skipped by default. |
| `device policy` | No emulator, no simulator, no `flutter run`, no launched app. `flutter build macos --debug` is allowed (compile only). No multi-monitor hardware is assumed. Every platform-visible behaviour is a **Unit 9 manual check**; record it as such and never claim it verified (list in A7). A subagent that believes it needs a device or a running window has hit a BLOCKED condition, not a reason to start one. |
| `review grounding` | **Primary**: the `agentic-code-review` skill (load it and follow it). **Secondary**: `docs-mcp` for Flutter/Dart library claims. **Plugin claims are checked against package source in the pub cache, not documentation**: `desktop_multi_window` 0.2.1 and `screen_retriever` 0.2.2 with its federated packages. That is how every defect in the pre-build review was found. **Contracts that override review opinions**: the approved FD/NFR-R/NFR-D; the pre-build review's Resolution lines; the owner's answers RQ-1..RQ-3 and NFR Design D1..L5; `AGENTS.md` "Boundaries" and "Security-Critical Code"; `docs/04-technical-specification.md` §1-2 and §8-9. A finding that contradicts one of these is a fact-check against its stated rationale, not a style opinion. **Known-defect exclusions** (deliberate, not findings): every open Backlog entry in `aidlc-docs/aidlc-state.md`, plus the accepted limitations in NFR-R §4.3 and NFR Design (macOS does not float above another app's full-screen window; Linux keep-above is the WM's to honour; `'-1'` lazy detection where no native close hook exists; chrome-allowance constants unverified until Unit 9; the pop-out opens on the primary display because `mainWindowCentre` is null; runner code is compile-verified only). |
| `unit exceptions` | (1) **`zip_core` is changed by design**: the Unit 8 window machinery is promoted into it. BR-U8.1-01 binds: every moved test passes with import-path edits only, except for the **five** permitted shape changes in FD `business-logic-model.md` §7. A moved test that fails for any other reason is **BLOCKED**, never patched. (2) **Hand-written native code in six runners** (both apps × macOS/Windows/Linux) is in scope. "Native code without a local build" is not a finding by itself. (3) **Unit 8's external display must not regress.** Its borderless styling now comes from `configure(floating: false, decorated: false)`. That is an accepted consequence (NFR Design), not a finding. (4) **No `window_manager`, and no new dependency of any kind.** A dependency need is BLOCKED. |
| `review cap` | 3 rounds of the local review loop. **CodeRabbit is requested separately** and does not count against the cap (A6). |
| `ledger path` | `aidlc-docs/overnight-ledger.md` (gitignored, `.gitignore:84`; entry format exactly as the generic document defines). |

### Binding design inputs (read in this order)

1. `aidlc-docs/construction/pop-out/nfr-design/handoff-summary.md`, then that folder's
   `logical-components.md` and `nfr-design-patterns.md`.
2. `aidlc-docs/construction/pop-out/nfr-requirements/` (all three files).
3. `aidlc-docs/construction/pop-out/functional-design/` (all files).
   `window-manager-security-10.md` is **retired**: read it as history only.
4. `aidlc-docs/construction/plans/pop-out-pre-build-review.md`: findings, Resolution lines, §3a.
5. The answer records: `plans/pop-out-functional-design-plan.md`, the two clarification files,
   `plans/pop-out-nfr-requirements-plan.md`, `plans/pop-out-nfr-design-plan.md` and
   `plans/pop-out-nfr-design-questions.md`.
6. `aidlc-docs/inception/user-stories/phase2-stories.md` S-21, the Unit 8.1 block in
   `aidlc-docs/inception/application-design/phase2-unit-of-work.md`, and `pip-ux-parity.md` §8.
   §8 is the binding UX contract. The approved FD clarification Q9 amends UX-PIP-10 and §8.8
   item 13; that amendment is applied to the file at Documentation Refinement, **not in this run**.

## AI-DLC adaptations (agreed before kickoff, 2026-10-21)

### A1 — The pipeline item is the *stage*, not the unit

The build loop runs **once per stage**, serially, in this order:

1. **`infrastructure-design`**: plan, artifacts and handoff, following
   `.aidlc-rule-details/construction/infrastructure-design.md`. In addition:
   - Settle the NFR Design handoff's **verify-not-assume list**, items 1-6, by reading plugin source
     and the Flutter SDK, never documentation:
     1. A sub-engine Dart message at close time is lost.
     2. macOS: where the close notification is delivered relative to `deinit`.
     3. Windows: the window-proc delegate's ordering against `HandleTopLevelWindowProc`.
     4. **Linux**: `delete-event` vs `"destroy"`, given the plugin's `TRUE`-returning handler.
        **Pre-decided**: if no notification is connectable, Linux degrades to the `'-1'` fallback.
        Record it; do not redesign.
     5. The six runners' callback signatures against the 0.2.1 headers (corrected on `develop`
        by PR #40), and `argv` delivery.
     6. Which Flutter SDK the claims hold for. Local is 3.41.7; CI pins 3.38.7
        (`build-verify.yml`). Every native and Dart API used must exist in **both**.
   - Specify the exact per-runner code: the sub-engine `zip_core/overlay_window_configure`
     handler, and the main-engine `zip_core/overlay_sub_window_events` registration. This includes
     `zip_captions`' three runners, which have no callback today.
   - **Correct the generated-file fence**, a defect found during the kickoff preparation.
     `tech-stack-decisions.md` §3 says the plugin registrants are "generated, not committed". They
     are **tracked**: each app's `macos/Flutter/GeneratedPluginRegistrant.swift`,
     `windows/flutter/generated_plugin_registrant.{cc,h}`, `windows/flutter/generated_plugins.cmake`,
     `linux/flutter/generated_plugin_registrant.{cc,h}` and `linux/flutter/generated_plugins.cmake`.
     Adding `desktop_multi_window` to `zip_captions` (with `screen_retriever` arriving through
     `zip_core`) changes zip_captions' copies. State the exact expected movement per file. Expect
     **no** movement in zip_broadcast's copies, because the plugin graph is unchanged there.
   - Apply the NFR Design handoff's three **open documentation corrections** in place, logged in
     `audit.md`: FD `domain-entities.md` §2.2, the stale `window_manager` line in FD
     `handoff-summary.md`, and `tech-stack-decisions.md` §2's missing main-engine channel
     registration. Also apply the §3 correction above, and correct `tech-stack-decisions.md` §4's
     claim that `fake_async` is "already a dev dependency of all three packages":
     `zip_captions` has neither `fake_async` nor `mocktail` (A7).
2. **`code-generation` Part 1**: the plan only, no production code. It is a strict transcription of
   the approved design plus Infrastructure Design. It contains:
   - TDD-first steps and an exact file table (created / moved / modified / deleted);
   - the moved-file list for the `git diff -M` R100 proof;
   - the explicit test list, including the PBT properties POP-1..POP-6 and POP-8 and the POP-7
     table test;
   - the ARB keys per app;
   - the lockfile and generated-file fence;
   - the gates;
   - self-check tables mapping every S-21 AC and every BR-PIP / BR-U8.1 rule to a step, and every
     §8.8 item to `tested` / `platform-check (Unit 9)` / `deferred (Phase 8)` per app.
3. **`code-generation` Part 2**: implementation, tests, l10n and final gates, following the
   approved plan.

Each stage is one build-subagent invocation. Each is a separate `BUILD_VERIFIED` gate (the gates
run, that stage's artifacts exist, and the tree is clean) and a separate ledger entry. A crash
therefore resumes at the next unfinished stage, not at the top of the unit.

### A2 — Approval gates are pre-approved, with a morning review recorded

**Human decisions** are **not** the run's to make. James Petersen made them in the files listed
under "Binding design inputs". Never re-ask, reinterpret or "improve" them.

**Stage approvals**: Stages 1-2 are pre-approved by this run configuration. Each completion is
recorded in `audit.md` as `approved by: run configuration (.agent/overnight-pipeline.md,
2026-10-21) — subject to morning review`.

**Stage 1 and Stage 2 gates**:
- Infrastructure Design results that contradict a design premise are **recorded**. They change the
  design only where the NFR Design handoff pre-decides the outcome (verify item 4).
- Part 2 proceeds only if the Part 1 plan is a strict transcription with **no open questions**.
- If either stage finds a **genuinely new** question, one the binding inputs do not answer:
  record it in the ledger as BLOCKED with the question verbatim, commit what is verified, push
  (A3), and stop.

Never guess an answer to a design question.

**Stage 3**: Code Generation Part 2 is authorized. **The PR is not merged by the pipeline.**
Merging stays a human decision.

### A3 — One push, one new PR

- Commit per stage (the clean-tree gate).
- Push `feature/popout-live-captions` once: after Stage 3's `BUILD_VERIFIED`, or earlier only on
  BLOCKED (`git push -u origin feature/popout-live-captions`).
- Then open the PR:
  `gh pr create --base develop --head feature/popout-live-captions --title "Unit 8.1: Pop-out Live
  Captions (S-21)"`. Its body carries:
  - the stages completed and the gate output;
  - pointers to the pre-build review and the code summary;
  - the §8.8 evidence table (per app);
  - the Unit 9 manual-check list.
- `PREVIOUS_MERGED` is satisfied by PR #40's merge (a kickoff precondition).

### A4 — The review loop reviews the run's work against the approved design

The local review subagent reviews `git diff <step-0-merge-sha>..HEAD`, using the Step 0 merge
commit recorded in the ledger. Everything up to and including that commit is either `develop` or
the **approved** design (through `72c7cd8`), plus the owner's parked on-device-multilingual-STT doc
commits. Those are contracts or out of scope, not review targets. The reviewer
is told the stage boundaries explicitly, so it does not review the design documents as code for
style. It reviews:
- the Infrastructure Design against the plugin sources and the approved design;
- the implementation against the approved plan.

It checks these high-risk items **by reading source, not by reasoning**:
- **Six runners**:
  - callback signatures match the 0.2.1 headers;
  - **no `RegisterGeneratedPlugins` / generated registrant inside any window-created callback**
    (R-B1);
  - **nothing replaces `desktop_multi_window`'s `NSWindowDelegate`** (R-B2);
  - the Linux close hook's handler order;
  - both channels' argument validation (L5).
- **Router**: dispatch only on non-null `windowIdOf() == fromWindowId` (null never matches); the
  token-bound installer maps `null` to unregister.
- **Controller**:
  - `dispose()` is byte-for-byte unchanged, and the enumerator lease releases a share;
  - the six `_isPopOut` guards are present;
  - the mode is fixed at construction;
  - exactly the seven permitted deviations.
- **Refactor proof**: `git diff -M` shows R100 for every moved file outside the FD
  additive-change table; the three fence greps.
- **R-M7**: `package:zip_core/overlay.dart` is a separate library and is **not** re-exported from
  `zip_core.dart`.
- **R-M4**: the in-surface toggle is outside the scrolling list.
- **Redaction**: no caption text in any log line; one audit test per app.

### A5 — Scope fence for the build subagents

**Allowed:**
- `packages/zip_core/`: `lib/` and `test/` for the files the approved plan lists, the new
  `lib/overlay.dart` library, and `pubspec.yaml`. In `pubspec.yaml`: add `desktop_multi_window:
  ^0.2.1` and `screen_retriever: ^0.2.2`, each with its SECURITY-10 comment, and nothing else.
- `packages/zip_broadcast/`: `lib/`, `test/`, `l10n/`; in `pubspec.yaml`, **remove**
  `screen_retriever` only (`desktop_multi_window` stays at `^0.2.1`, as PR #40 set it).
- `packages/zip_captions/`: `lib/`, `test/`, `l10n/`; in `pubspec.yaml`, **add**
  `desktop_multi_window: ^0.2.1` only.
- **Constraint floor**: all three packages use `desktop_multi_window: ^0.2.1`, matching PR #40.
  The runners are written against 0.2.1's one-argument `WindowCreatedCallback` typedefs. Where the
  approved FD or NFR-R says `^0.2.0` (domain-entities §1.4, tech-stack-decisions §1 and §6),
  Infrastructure Design corrects it to `^0.2.1` and logs the correction. `^0.2.1` still admits any
  later 0.2.x, so the lockfile and CI's build of both apps are what protect the header contract.
- The six runner files, for the window-created callback, the `configure` channel and the main-engine
  close channel only:
  - `packages/{zip_broadcast,zip_captions}/macos/Runner/MainFlutterWindow.swift`
  - `packages/{zip_broadcast,zip_captions}/windows/runner/flutter_window.cpp`, plus its `.h` only
    if the plan requires it
  - `packages/{zip_broadcast,zip_captions}/linux/runner/my_application.cc`
- **Generated files**: exactly the movement Infrastructure Design states, produced by the tool,
  never hand-edited. This covers `freezed`/`riverpod` outputs at their moved paths, the l10n outputs
  from `flutter gen-l10n`, and the plugin registrants above.
- The root `pubspec.lock` and each app's `macos/Podfile.lock`: exactly the movement Infrastructure
  Design states. Expected: `zip_captions`' `Podfile.lock` gains the `desktop_multi_window` and
  `screen_retriever_macos` pods. Anything else that moves is reported in the PR body, never
  silently committed.
- `aidlc-docs/` per the stages.

**Inception amendments (exactly these):**
- The Unit 8.1 entry and the current-stage line in `aidlc-state.md`.
- The Unit 9 scope line in `phase2-unit-of-work.md`: add Unit 8.1's manual checks (A7).

**Forbidden:**
- `packages/zip_supabase/`, and any `zip_core` file the approved plan does not list. The caption bus
  and `CaptionOutputTargetRegistry` are frozen (NFR Design L4).
- `window_manager`, and any dependency not named above.
- `.github/` (CI already builds both apps), `docs/`, `pip-ux-parity.md`, `aidlc-docs/v1-parity/`,
  `spikes/`, `opencode.json`.
- Any `.agent/` change other than Step 0's commit of this file.

### A6 — CodeRabbit on the final PR

After the last local review round (or immediately, if the local reviewer approves on round 1),
the orchestrator triggers one CodeRabbit review on the final PR head and waits for it.
- `aidlc-docs/**` is path-filtered by `.coderabbit.yaml`, so CodeRabbit reviews only `packages/`.
  That is expected, not a failure.
- Findings go through the same fix-subagent flow and **do not consume the local review-round cap**.
- Trigger: `gh pr comment <n> --body "@coderabbitai review"`. If no review arrives within 45
  minutes, record `CODERABBIT: unavailable` in the ledger and the final summary, and finish with
  the PR open and CI green.
- The run **must not** request a second CodeRabbit pass (the repo has hit the "one review per hour"
  limit before).

### A7 — Unit 8.1 specifics the subagents must be told

**The approved design is binding.** In particular:
- RQ-1 A: a first-party per-runner `configure` channel, **no `window_manager`**.
- RQ-2 A: each app's own engine gate. `sttEngineRegistryProvider` is **not** the Zip Broadcast gate.
- RQ-3 A as amended: the native close event goes to the **main** engine as
  `subWindowClosed {windowId}`, with `'-1'` as the fallback.
- NFR Design D1-L5 as recorded, notably:
  - `OverlayWindowHost` owns the router, the enumerator (leased) and the close channel;
  - L4 B: `PopOutCaptionTarget` copies the shipped buffer read; the registry is not touched;
  - L5: channel names `zip_core/overlay_window_configure` and `zip_core/overlay_sub_window_events`.

**Testing:**
- PBT uses the in-tree shim `packages/zip_core/test/helpers/pbt.dart`, which is byte-identical to
  zip_broadcast's. There is no `glados` dependency.
- `fake_async` and `mocktail` are dev dependencies of `zip_core` and `zip_broadcast` **only**.
  `zip_captions`' dev dependencies are `flutter_test`, `build_runner`, `drift`,
  `riverpod_generator` and `very_good_analysis`. Its tests are therefore `testWidgets` with
  `tester.pump(...)` for timing, plus hand-written fakes. The controller-timing tests (ready
  timeout, coalescing, the stateful PBT) live in `zip_core`. Adding a dev dependency to
  `zip_captions` is a dependency change, which is BLOCKED (unit exception 4).
- Hand-written fakes for collaborators that carry behaviour (NFR-R §1.4).

**Strings and logging:**
- Strings go in each app's `l10n/arb/app_en.arb`, then run `flutter gen-l10n`. Never edit the
  generated Dart l10n files. `zip_captions` reads its strings through `ZcStrings`.
- `zip_core` has no ARB: `OverlayWindowUnavailableApp` takes `message`.
- Logs are fixed strings plus an error's `runtimeType`, never caption text (BR-PIP-11).
- Web is excluded by `DesktopWindowService.isSupported`, never by `kIsWeb`.
- Availability tests the three concrete active states, never the `ActiveSessionState` mixin
  (`StoppedState` mixes it in).

**Unit 9 manual checks** (record them; never claim them):
1. The pop-out floats above other apps on each platform, including the macOS full-screen
   limitation and Linux WM behaviour (§8.8 item 15).
2. The pop-out is decorated, resizable and movable, and respects its minimum size on each platform.
3. The chrome-allowance constants, measured against two rendered lines plus the toggle row.
4. An OS close clears the main window's banner and toggle immediately on each platform, or via the
   `'-1'` fallback on Linux if Infrastructure Design recorded the degradation.
5. The external display is still borderless on all three platforms after the `configure` move.
6. Pop-out placement on a multi-monitor desk (primary display, bottom-centre).
7. The in-surface toggle works from inside the pop-out window.
8. Windows and Linux runner behaviour in general (compile-verified only).

**Step 0 (before Stage 1):**
1. Commit this file alone as `chore(agent): Unit 8.1 overnight run configuration`. That is the
   only `.agent/` change the run makes.
2. `git fetch origin && git merge origin/develop` into `feature/popout-live-captions`, as a merge
   commit. This brings in PR #40. Record the merge SHA in the ledger: it is A4's diff base.
3. Run the gates. All three packages must be green before Stage 1. A red gate here is a hard
   blocker: the base is broken, not the unit.
4. The `audit.md` merge may conflict, because both branches appended entries. Resolve it by keeping
   both sides in timestamp order, changing no entry text, and note the resolution in the ledger.

## Kickoff message

Paste this as the entire first message of a fresh session at the repo root:

```
Read .agent/overnight-pipeline.md and execute it from the start, using its Run
configuration section, with kestra/overnight-pipeline-generic.md as the
process definition it instantiates. That document is the ONLY thing you may
read from the Obsidian vault — do not read the rest of the vault, and do not
use the vault for codebase orientation during this run (the approved design
artifacts and handoff summaries under aidlc-docs/construction/pop-out/ serve
that purpose). This is the unattended overnight run it defines. Do not ask me
questions — the document contains the assumptions policy.
```

## Kickoff preconditions (orchestrator checks before Step 0)

- **PR #40 is merged to `develop`** (`gh pr view 40 --json state -q .state` → `MERGED`). If it is
  not, do not start: Step 0's merge, the Windows/Linux runner compile and `PREVIOUS_MERGED` all
  depend on it.
- `feature/popout-live-captions` is checked out, its head is `ad59013`, and it has **no** remote
  branch and **no** PR (`gh pr list --head feature/popout-live-captions` is empty).
- `git status --short` shows exactly these lines, and anything else is a precondition failure:
  - ` M .agent/overnight-pipeline.md`: this file, written before kickoff and deliberately left
    uncommitted;
  - ` M opencode.json`: the owner's local harness permissions (they allow the opencode skills
    directories, which this run needs for `agentic-code-review`).
- **`opencode.json` is a standing local modification for the whole run.** Never stage, commit,
  stash, revert or edit it. Every "clean tree" check in this file and in the generic document means
  `git status --short` showing nothing **except** ` M opencode.json`. Always stage files by explicit
  path, never with `git add -A` or `git add .`.
- `RUN_UNIQUE`: no `aidlc-docs/overnight-ledger.md` entry is newer than 30 minutes with a `next:`
  other than `PIPELINE COMPLETE`.
