# Fix Round 6 — Unit 8.1 Pop-out: working instructions

**Date**: 2026-10-23
**For**: the session that fixes the runtime review findings. This file is the complete brief; the
handoff prompt can be one line long.
**Companion**: `pop-out-review-round-6.md` in this folder is the findings document (what is wrong,
the evidence, the code paths, the done-criteria). This file is how to do the work. Where the two
disagree, the findings document wins and this file is wrong.

---

## 1. State of the working directory, exactly as it was handed over

Verified immediately before writing this file.

| Item | Value |
|---|---|
| Repo root | `/Users/oblivious/Documents/zip-captions-monorepo` |
| Current branch | `feature/popout-live-captions`, checked out, tracking `origin/feature/popout-live-captions` |
| HEAD | `a010cef` — `docs(pop-out): record runtime review round 6 findings for unit 8.1` |
| Remote | `origin/feature/popout-live-captions` is at `a010cef`, in sync with local |
| `develop` | `8d15af3` (the base of PR #41) |
| Uncommitted | ` M opencode.json` only — a long-standing local edit, never staged, never reverted, not ours. Leave it alone. |
| Untracked | none |
| PR | #41, open, blocked, target `develop` |
| Worktrees | none beyond the main one |

Branch history for context, newest first:

```
a010cef docs(pop-out): record runtime review round 6 findings for unit 8.1
7f27fa8 docs(pop-out): record review round 5 fixes
7394eca fix(zip_captions,zip_broadcast): remove the macOS close observer before the id guard
```

The two commits behind `a010cef` are the review-round history of this unit; `a010cef` touched only
this folder. Nothing else is in flight on this branch.

**Gates as of the handoff** (from each package root, run by the previous session):

| Command | `zip_core` | `zip_broadcast` | `zip_captions` |
|---|---|---|---|
| `dart analyze --fatal-infos lib test` | clean | clean | clean |
| `flutter test` | 914 pass / 4 skip | 177 pass | 174 pass |
| `flutter build macos --debug` | n/a | built | built |

Windows and Linux compile in CI only. Baseline test counts: any new tests are additions to these
numbers, and a drop means something was deleted.

---

## 2. What to read, in order

1. `pop-out-review-round-6.md` (this folder) — all five findings.
2. `../pop-out/code/summary.md` — what was built and the seven recorded departures from the design.
3. `../pop-out/code/handoff-summary.md` — the code-generation handoff; note the working-tree paragraph,
   which describes files that were unstaged at that handoff. Those are now committed; the paragraph is
   history, not a to-do.
4. The PR #41 comment thread, three comments posted 2026-10-23: runtime evidence table, interactive
   follow-up table, "Changes required before this PR merges".
5. `AGENTS.md`, and `docs/04-technical-specification.md` §1-2 if you are writing Dart. `docs/TDD.md`
   governs the test-first rule.

Do not load the whole `aidlc-docs/construction/pop-out/` tree. The findings document cites the
specific sections you need.

---

## 3. Non-negotiable constraints

- **Re-verify each finding against source before acting.** The findings document marks R6-1's two
  causes as candidates and says to discriminate them first. Do not fix a symptom the evidence does not
  support. `overconfidence-prevention.md` applies.
- **TDD first.** Every fix starts with the failing test named in that finding's done-criteria, failing
  for the right reason, then the fix. No production change without a preceding red test.
- **This is a defect round inside Unit 8.1, not a new unit.** No new unit, no new story. Amend Unit
  8.1's design documents only where a finding proves the *design* wrong rather than the code, and stop
  for approval before doing so.
- **Do not touch `docs/`.** That happens in Documentation Refinement with per-change approval.
- **Do not touch the contracts in AGENTS.md's Boundaries section** (`SttEngine`, `SttResult`,
  `TranslationEngine`, caption bus, BLE identifiers, Supabase schema/RLS, encryption mechanism,
  broadcast URL format) without stopping to ask.
- **The nav-rail placement is not automatically a defect.** Read
  `../pop-out/functional-design/frontend-components.md` §3 first. If the rail is the specified chrome,
  fix size, alignment and overflow only; if it is not, moving the control is a design change that needs
  approval.
- **Logging stays payload-free.** Fixed strings and an error's `runtimeType` at most (BR-U8-18).
  R6-5's console routing is debug-only.
- **No emojis, English only, conventional commits scoped to the package**,
  e.g. `fix(zip_core): route overlay failure codes to the shell`.
- **Commit on this branch. Do not push and do not open a PR unless asked.**

---

## 4. Execution order, and why

The order is chosen so you never build the same diagnostic twice. Do not reorder without a reason you
can state.

### Step 1 — R6-5, diagnostics

Route the overlay controller's fixed log strings to the platform console in debug builds, with a test
that the wiring exists in debug and is absent in release. This comes first because R6-1 cannot be
discriminated without it: the `'overlay ready timeout'` line the controller already writes never
reaches `flutter run` today.

Touches: `zip_core/lib/src/providers/overlay_window_host_provider.dart` (the host is built with no
logger), `zip_core/lib/src/output/overlay/overlay_window_host.dart` (the `_child` derivation), and the
`log` seam already present on `OverlayWindowController` and both apps' controller construction.

Acceptance: a debug `flutter run` of either app prints the controller's fixed strings; a test asserts
present-in-debug, absent-in-release; no payload text appears.

### Step 2 — R6-2, availability

Settle the disagreement as a pure-function-versus-second-source-of-truth question, which needs no
window. Write the widget test that drives start -> stop -> Home and reads the availability twice
across a provider rebuild *first*; if it cannot reproduce the two different reads, instrument the
running app to capture `controller.status` and the recording state at both reads, then fix.

Suspect, not yet proven: `popOutStatusProvider` (`zip_captions/lib/src/providers/pop_out_providers.dart:46-51`)
is autoDispose over a broadcast `statusChanges`, so a re-subscription can lose the current value.
The fix direction is to make the current status replayed on subscribe by construction, or to drop the
stream from the decision path in `zc_app_shell.dart:200-201`.

Acceptance: identical state yields identical availability on every read and after every rebuild; no
session means `enabled == false` and the no-session reason string present; a test pins both.

### Step 3 — R6-1, the pop-out that never opens

Discriminate the candidates **before** changing code, using:

1. the controller's log lines from step 1;
2. the full window list (`CGWindowListCopyWindowInfo`, all windows, all screens) at 500 ms intervals
   with window ids and frames, to see whether a second window is ever created and whether it is the
   sub-engine's;
3. the sub-engine's own `flutter:` output, which `flutter run` interleaves with the main isolate's.

Candidate 1: the round-5 R-B1 runner change (`7f27fa8`, `7394eca`) registers only the app's own
`configure` channel in the window-created callback, so the sub-engine's `overlayReady` arrives through
a channel that is no longer installed and is dropped. Candidate 2: the sub-engine entrypoint never
reaches the ready call. The `1x1` offscreen helper window does not distinguish them.

Then fix, and re-run A2 with the gates.

Acceptance: pressing the chrome toggle creates one visible pop-out window within the 10 s budget; the
banner appears; the window shows live captions and its own exit toggle works; `OpenFailed` is either
gone or surfaced per R6-3. A3-A9 then become runnable and must be run.

### Step 4 — R6-3, no reason on failure

`OpenFailed(code)` already reaches the shell (`zc_app_shell.dart:64-72`) and the code is discarded.
Surface a fixed per-code string (`create_failed`, `ready_timeout`) in ARB, English plus the existing
translation set, shown through whatever error surface the design already prescribes; if none does, add
the rule first and get it approved before wiring it.

Acceptance: a widget test drives `OpenFailed` through the shell, asserts the string appears, and
asserts it clears on the next successful open. No transcript text in the string.

### Step 5 — R6-4, the flash

Make platform capability a synchronous input to the availability rule so no control is ever built on a
platform that cannot host a sub-window, keeping the async `Unsupported` path only for runtime failure.

Acceptance: a widget test builds the shell with the status undefined and an active session on an
unsupported platform and asserts the control is never built — absent on the first frame, not absent
after a pump.

---

## 5. Verification to run before reporting

Gates, from each package root:

```
dart analyze --fatal-infos lib test   # clean in all three
flutter test                          # zip_core >= 914+new / 4 skip, zip_broadcast >= 177, zip_captions >= 174
flutter build macos --debug           # both apps
```

Runtime, the checks the earlier comments recorded as FAIL or BLOCKED:

| Check | Platform | Needs |
|---|---|---|
| A2-A9, B1-B4 | macOS, both apps | Accessibility granted to the terminal running the agent for A7/B4; launch zip_captions with `--dart-define=SUPABASE_URL=http://127.0.0.1:1` if the local Supabase stack is not running. Never install on or touch the physical Pixel 6 (`25071FDF600953`). |
| C3 | iOS simulator and Android emulator | a fresh launch, then Start Captioning; watch the first frames |

If Accessibility is not granted, record those checks BLOCKED again rather than guessing, and say so.
Evidence capture that worked last round: the VM-service inspector for widget trees, `simctl io` /
`adb exec-out screencap` for screenshots, `CGWindowListCopyWindowInfo` for windows, and `adb shell
input tap` for Android taps (`simctl` has no tap; iOS taps were done by a human).

---

## 6. Reporting

Per finding: the cause it turned out to be, what changed, the test that pins it, and the before/after
runtime observation. Update the PR #41 thread with those results. If a finding proves wrong or is not
reproducible, say so plainly with the evidence; do not silently drop it.

Do not commit this file's edits as part of a code fix; this folder records handoffs, so its changes
belong in their own `docs(pop-out):` commit.