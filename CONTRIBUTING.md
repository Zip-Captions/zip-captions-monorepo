# Contributing Guide

> How we work. For humans and AI agents alike.

**Last Updated:** 2026-03-26

---

## 1. Development Flow

Every piece of work begins with an AI-DLC inception session. Requirements come directly from the `docs/` directory — there is no separate story authoring step.

```
Intent / Roadmap Item --> AI-DLC Inception --> Approved Design --> Worktree + Construction --> PR --> Merged
```

| Transition | Who | What happens |
|---|---|---|
| Intent --> Inception | Human or Agent | State intent (`Using AI-DLC, ...`) or ask agent to determine next feature; agent guides through requirements and design — human approves each phase gate |
| Inception --> Approved Design | **Human only** | Human approves the final inception stage (workflow plan, application design, units) |
| Approved Design --> Worktree | Agent | Agent creates an isolated git worktree and feature branch for the unit |
| Worktree --> Tests Written | Agent | Agent runs AI-DLC Construction Phase, gets human approval on code generation plan, writes failing tests, commits |
| Tests Written --> Implemented | Agent (autonomous) | Agent implements until all tests pass |
| Implemented --> PR Open | Agent | Agent opens PR from the worktree branch targeting `develop` |
| PR Open --> Merged | **Human only** | Human reviews and merges; worktree cleaned up after merge |

**AI-DLC Inception is a collaborative phase** — the agent proposes, the human approves at each stage gate. **Construction is largely autonomous** once the code generation plan is approved, subject to the stop conditions in Section 5.

---

## 2. Git Worktrees

Each unit of work is developed in an isolated git worktree. This keeps the main workspace clean and allows parallel work on multiple units without interference.

### Creating a Worktree

After AI-DLC inception is approved, create a worktree from the monorepo root:

```bash
git worktree add ../zip-captions-<feature-name> -b feature/<feature-name>
```

This creates a sibling directory containing a full, independent working copy on a fresh branch.

### Working in a Worktree

```bash
cd ../zip-captions-<feature-name>
melos bootstrap               # Install dependencies in the worktree
# Run the AI-DLC construction phase here
melos run test                # Tests, analysis, and generation all work normally
melos run analyze
```

### Completing a Worktree

Open the PR from the feature branch targeting `develop`, then after it merges:

```bash
git worktree remove ../zip-captions-<feature-name>
git branch -d feature/<feature-name>
```

### Listing Active Worktrees

```bash
git worktree list
```

### Naming Convention

| Branch type | Pattern |
|---|---|
| Feature | `feature/<description>` |
| Spike | `spike/<description>` |
| Bug fix | `fix/<description>` |

Worktree directory: `../zip-captions-<description>` (sibling to the monorepo root)

### Dependencies Between Units

A unit can begin construction if all its dependencies are **fully defined** — their interfaces documented in the inception artifacts. Dependencies do not need to be implemented first; mock their interfaces based on the approved design.

---

## 3. Submodule Maintenance

The `ai-dlc/` directory is a git submodule tracking [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows). Keep it up to date so that AI-DLC rules and templates reflect the latest upstream changes.

### Updating the Submodule

From the monorepo root:

```bash
git submodule update --remote ai-dlc
```

If the submodule pointer changed, commit the update:

```bash
git add ai-dlc
git commit -m "chore: update ai-dlc submodule to latest"
```

### When to Update

- **Before starting a new AI-DLC inception session** — ensures you are working with the latest workflow rules
- **After cloning or pulling** — run `git submodule update --init` to initialize or sync the submodule
- **Periodically** — check for upstream updates at least once per development cycle

### Troubleshooting

If the submodule directory is empty after a clone:

```bash
git submodule init
git submodule update
```

If you see a detached HEAD warning inside `ai-dlc/`, that is normal — submodules pin to a specific commit.

---

## 4. Branching Strategy (Gitflow)

| Branch | Purpose | Created from | Merges into |
|---|---|---|---|
| `main` | Stable, production-ready code. Protected. | — | — |
| `develop` | Integration branch. All feature work merges here. | `main` | `main` (via release) |
| `feature/<story-id>-short-name` | One story's work. | `develop` | `develop` |
| `spike/<spike-id>-short-name` | Research/investigation. | `develop` | `develop` |
| `fix/<description>` | Bug fixes. | `develop` | `develop` |
| `release/v<version>` | Release stabilization. | `develop` | `main` + `develop` |
| `hotfix/<description>` | Emergency production fix. | `main` | `main` + `develop` |

**Rules:**
- Every story gets its own feature branch
- PRs target `develop`, not `main`
- No direct commits to `main` or `develop`
- Delete feature branches after merge

**Agent instructions:**
```bash
git checkout develop
git pull origin develop
git checkout -b feature/P0-US-001-short-name
# ... work ...
# Open PR targeting develop
```

---

## 5. Commit Messages

Agents must use Conventional Commits, scoped with the package name:

```
feat(zip_core): add SttEngine abstract class
test(zip_core): add failing tests for P0-US-003
fix(zip_captions): handle microphone permission denial on iOS
docs: update architecture with transport flow
chore(zip_broadcast): update dependencies
refactor(zip_core): extract audio capture pipeline
```

Humans: Conventional Commits preferred but freeform acceptable.

Melos uses Conventional Commits for automated versioning and changelogs.

---

## 6. Story Lifecycle

AI-DLC inception phase gates are the primary points where the agent pauses for human approval — requirements, user stories, workflow plan, application design, and the code generation plan each require an explicit approval before the agent proceeds.

Within the Construction Phase, agents should also stop and ask when:

### When Agents Should Stop and Ask

- An acceptance criterion contradicts a spec doc or seems untestable
- Implementation requires changing a contract defined in "Boundaries" in AGENTS.md
- A dependency story's interface is unclear or undefined
- The feature scope is too large for a single PR (raise during AI-DLC inception — the Units Generation stage will split it)
- A technical decision with multiple valid approaches needs human input
- The work touches security-critical code (see AGENTS.md, Security-Critical Code section)

### When Agents Should NOT Stop

- Choosing between implementation approaches that do not affect external contracts
- Adding internal helper functions or utilities
- Refactoring existing code (as long as existing tests pass)
- Fixing minor test failures they understand

---

## 7. Code Review

### Automated Checks (CI)

- [ ] `melos run analyze` passes (zero warnings)
- [ ] `melos run test` passes (all packages)
- [ ] Coverage threshold met (80%+ per package)
- [ ] No secrets, credentials, or PII in the code
- [ ] No out-of-scope features

### Human Review Focus

- **Story alignment:** Does the implementation satisfy the acceptance criteria?
- **Test quality:** Are tests meaningful? Do they cover edge cases?
- **Spec compliance:** Does the code follow the patterns in `docs/04-technical-specification.md`?
- **Security:** Does any transcript content leak into logs, analytics, or error reports?
- **Dependencies:** Were any new packages added? Are they justified?
- **Package boundaries:** Does `zip_core` contain any Flutter UI code? Do the apps import from each other?

### Extra Scrutiny for Agent-Generated Code

- Dependency additions
- Platform channel implementations
- Encryption/auth code
- Supabase RLS policies

---

## 8. Integration Testing Strategy

### Tier 1: Contract Tests (Automated, No External Dependencies)

Verify that one package's output matches what another package expects. Use shared fixture files in `test-fixtures/` that both packages' test suites reference.

### Tier 2: Simulated End-to-End (Automated)

Chain the full pipeline in a single test with Supabase and external services mocked.

### Tier 3: Smoke Test (Manual, Pre-Release)

Run against local Supabase Docker Compose. Documented checklist covering critical user flows per phase exit criteria.

### Tier 4: Full Integration CI (When Justified)

Automated tests against staging Supabase. Invest in this when Phase 2 (broadcasting) is stable.

---

*This document is the authoritative guide for how development proceeds. Read it before starting work.*
