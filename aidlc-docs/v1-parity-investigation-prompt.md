# Prompt: V1 Feature Investigation for Two V2 Roadmap Inputs

Run this prompt in a fresh session opened in `/Users/oblivious/Documents/zip-captions`.

---

## Your Task

You are investigating the **V1 implementation** of two features in this repository so that a separate V2 project (a Flutter/Dart monorepo) can plan feature parity and roadmap placement. You will not modify any V1 code. You will produce two analysis documents and write them into the V2 repository.

The two features are:

1. **Picture-in-Picture (PiP)**
2. **Live translation**

Both exist in V1 (release branch `release/v0.5.0`, currently checked out). Investigate what is actually implemented, not what is described in V1 docs as aspirational.

## Required Reading Order

1. `git log --oneline -20` and `git status` — establish the baseline you are describing.
2. `release_notes.md` — what was claimed for the release.
3. `docs/` — any design or task docs covering these features.
4. `packages/` — actual source. This is authoritative. Docs may be stale or aspirational.
5. For translation specifically, also compare against branch `feature/on-device-translation` (`git log origin/develop..feature/on-device-translation --oneline`, `git diff`). State clearly whether that branch is merged into `release/v0.5.0`, unmerged, dead, or superseded, with evidence.

Use `git log -S` / `git log --follow` and `git blame` where they help establish when and why something was built.

## Scope Constraint

**Sender/consumer application features only.** Do not investigate any casting-receiver functionality. Do not investigate server-side-only capabilities unless they are required for the two features above.

## For Each Feature, Establish

- **What it does from the user's point of view.** Concrete behaviour, not marketing description.
- **Where the implementation lives.** File paths, package names, entry points. Quote the key signatures and the actual mechanism.
- **Platform coverage.** Which platforms it works on, and how the implementation differs per platform (browser API vs. native window vs. OS-level).
- **Constraints and limitations.** What it does not handle. Known TODOs, hacks, feature flags, disabled paths.
- **Dependencies.** Libraries and platform APIs it relies on, with versions from the relevant `package.json`.
- **Data flow.** How caption text reaches the PiP surface or the translation engine.
- **Test coverage.** What is actually tested versus untested.
- **Observability.** Any logging, telemetry, or error reporting around it (and whether caption content leaks into logs — this matters because the V2 project forbids that).

For PiP specifically, determine:
- Is it browser Document Picture-in-Picture, a dedicated always-on-top OS window, an Electron `alwaysOnTop` window, or something else entirely?
- How is the caption content delivered into the PiP surface?
- What happens when the feature is unsupported on the current platform or browser?
- Is it user-toggleable, persisted across sessions, or automatic?

For live translation specifically, determine:
- Which translation backend(s) are used (cloud API, on-device model, browser API, wrapper around something else).
- Whether translation is streaming/incremental or whole-utterance.
- How language detection happens, and what the language-selection UX is.
- Whether source text and translated text are both displayed, and in what arrangement.
- What happens on backend failure, timeout, or unsupported language pair.
- Whether translation state is persisted, per-session, or ephemeral.
- Whether any disclaimer about translation accuracy is shown, and whether it can be dismissed.

## Output: Exactly Two Files

Write these two files into the **V2 repository**:

- `/Users/oblivious/Documents/zip-captions-monorepo/aidlc-docs/v1-parity/picture-in-picture-v1-analysis.md`
- `/Users/oblivious/Documents/zip-captions-monorepo/aidlc-docs/v1-parity/live-translation-v1-analysis.md`

Write them with the `Write` tool using absolute paths. Do not write anywhere else. Do not create a `v1-parity` directory in this V1 repository.

If the parent directory does not exist, create it first with `mkdir -p /Users/oblivious/Documents/zip-captions-monorepo/aidlc-docs/v1-parity`.

Directory access to that path may prompt for permission. If a tool call is refused on permission grounds, stop and report the refusal in your final message rather than trying an alternative write location.

## Required File Structure

Use this structure in both files. Omit a section only if it is genuinely not applicable, and say so rather than leaving it blank.

```markdown
# V1 <Feature> Analysis

**Date**: YYYY-MM-DD
**V1 baseline**: branch, commit SHA, describe it as `<sha> (<branch>)`
**V1 version**: from release_notes.md or package.json
**Purpose**: V1 implementation description to inform V2 feature parity.

---

## Executive Summary

Three to six sentences. What the feature actually is, whether it is production quality or a prototype, and the single most important fact a V2 planner needs.

---

## User-Facing Behaviour

What the user sees and can do. Steps to reach the feature. Toggle points. Persistence.

---

## Implementation

### Location

| Package | File | Role |
|---|---|---|

### Mechanism

Narrative description of how it works, with the key code excerpts quoted (short, relevant only).

### Platform Coverage

| Platform | Supported | Mechanism | Notes |
|---|---|---|---|

---

## Dependencies

| Dependency | Version | Purpose |
|---|---|---|

---

## Data Flow

How caption text or audio reaches the surface/engine. A short numbered sequence is fine.

---

## Constraints and Limitations

Bulleted. Include known TODOs, disabled paths, platform gaps, and anything the V1 team worked around.

---

## Test Coverage

What is tested, at what level, and what is not.

---

## Observability and Privacy

Logging and telemetry around the feature. State explicitly whether caption or transcript content can appear in logs or off-device telemetry.

---

## Implications for V2 Parity

Bulleted. What a V2 equivalent must reproduce for parity, what V1 behaviour should not be carried forward, and what is V2-specific (for example, desktop window management where V1 was web-only). Flag anything that would need a research spike or a new dependency.

---

## Evidence

Bulleted list of the exact files and commands you used, so the claims can be re-checked.
```

## Rules

- Every claim about behaviour must be traceable to a file path or a command output. Put those in **Evidence**.
- Distinguish clearly between "implemented and shipped", "implemented but disabled", "branch-only", and "documented but never built". This distinction is the main value of the exercise.
- Do not speculate about V2 design. State V1 facts and list parity implications; leave architecture to the V2 project.
- Do not modify, revert, checkout, or stash anything in this repository. Read-only investigation.
- Do not install dependencies.
- No emojis anywhere. English only.
- If the two features turn out to share infrastructure (for example a common caption rendering surface), say so in both documents rather than duplicating the explanation silently.

## Final Message

When both files are written, reply with:

1. The two absolute file paths.
2. The V1 commit SHA you analysed.
3. A three-sentence summary per feature.
4. Anything you could not determine, and why.