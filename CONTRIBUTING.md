# Contributing Guide

> How we work. For humans and AI agents alike.

**Last Updated:** 2026-03-26

---

## 1. Development Flow

Every piece of work follows this path:

```
Idea --> Story (Draft) --> Story (Ready) --> Tests Written --> Implemented --> PR Open --> Merged
```

| Transition | Who | What happens |
|---|---|---|
| Idea --> Draft | Human + Agent | Collaboratively write the story using `docs/STORY_TEMPLATE.md` |
| Draft --> Ready | **Human only** | Human reviews story, creates GitHub Issue with `status:ready` label |
| Ready --> Tests Written | Agent (autonomous) | Agent claims story via script, writes failing tests, commits |
| Tests Written --> Implemented | Agent (autonomous) | Agent writes code until tests pass |
| Implemented --> PR Open | Agent (autonomous) | Agent opens PR, updates status to "In Review" via script |
| PR Open --> Merged | **Human only** | Human reviews and merges, moves to Done |

**Agents operate autonomously between the two human gates.** Once a story is Ready, an agent can take it to a PR without waiting — unless it encounters a decision that changes the acceptance criteria or a boundary defined in `AGENTS.md`.

---

## 2. Task Tracking (GitHub Projects)

GitHub Projects is the single source of truth for task state. It is branch-independent — all agents and humans see the same live view regardless of which branch they are on.

### Board Columns

| Column | Meaning | Who moves items here |
|---|---|---|
| Backlog | Story exists, not yet approved | Human |
| Ready | Approved, available for agents | Human |
| In Progress | Claimed by an agent | Agent (via `claim-story.sh`) |
| Tests Written | Failing tests committed | Agent (via `update-status.sh`) |
| In Review | PR open | Agent (via `update-status.sh`) |
| Done | PR merged | Human |

### Agent Workflow Scripts

Agents interact with GitHub Projects via wrapper scripts in `scripts/`. These scripts use a scoped PAT that only allows issue and project updates — no code push, no admin access. See `scripts/README.md` for setup.

```bash
./scripts/list-available.sh              # Find stories ready for work
./scripts/claim-story.sh P0-US-001       # Claim and start working
./scripts/update-status.sh P0-US-001 "Tests Written"   # Update progress
./scripts/update-status.sh P0-US-001 "In Review"        # PR opened
```

### Labels

Status (used by the scripts):
- `status:ready`, `status:in-progress`, `status:tests-written`, `status:in-review`

Phase:
- `phase:0`, `phase:1`, `phase:2`, `phase:3`, `phase:4`, `phase:5`, `phase:6`, `phase:7`, `phase:8`

Package:
- `pkg:zip-core`, `pkg:zip-captions`, `pkg:zip-broadcast`, `pkg:zip-supabase`

Type:
- `type:story`, `type:spike`, `type:bug`

### Dependencies

A story can be started if all its dependencies are **fully defined** (status Ready or beyond). Dependencies do NOT need to be implemented — mock their interfaces based on their defined acceptance criteria.

---

## 3. Branching Strategy (Gitflow)

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

## 4. Commit Messages

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

## 5. Story Lifecycle

### When Agents Should Stop and Ask

- An acceptance criterion contradicts a spec doc or seems untestable
- Implementation requires changing a contract defined in "Boundaries" in AGENTS.md
- A dependency story's interface is unclear or undefined
- The story scope is too large for a single PR (suggest splitting)
- A technical decision with multiple valid approaches needs human input
- The work touches security-critical code (see AGENTS.md, Security-Critical Code section)

### When Agents Should NOT Stop

- Choosing between implementation approaches that don't affect external contracts
- Adding internal helper functions or utilities
- Refactoring existing code (as long as existing tests pass)
- Fixing minor test failures they understand

---

## 6. Code Review

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

## 7. Integration Testing Strategy

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
