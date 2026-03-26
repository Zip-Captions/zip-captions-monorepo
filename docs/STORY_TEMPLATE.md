# Story Template

> Copy this file to create a new user story. Replace all placeholder text. Delete this block.
>
> **Naming convention:** `P<phase>-US-<number>` -- e.g., P0-US-001, P1-US-003, P2-US-001
> **File location:** `stories/phase-<N>/P<N>-US-<NNN>-short-description.md`
> **GitHub Issue:** Create a matching issue with the story ID as the title prefix.

---

# P0-US-XXX: [Title -- short, action-oriented]

**Phase:** [0 / 1 / 2 / ...]
**Package(s):** [zip_core / zip_captions / zip_broadcast / zip_supabase / multiple]
**Priority:** [P0 critical / P1 high / P2 medium / P3 low]
**Status:** [ ] Draft --> [ ] Ready --> [ ] In Progress --> [ ] Tests Written --> [ ] Implemented --> [ ] Merged

---

## User Story

**As a** [developer / user / broadcaster / attendee],
**I want to** [action or capability],
**So that** [benefit or outcome].

## Context

[Why this story exists. What problem it solves. Links to relevant ADRs, persona scenarios, or spec sections. Dependencies on other stories.]

**Relevant specs:**
- ADR-XXX: [title] (in `docs/02-architecture-decisions.md`)
- Scenario S1.X: [title] (in `docs/01-user-personas.md`)
- Tech spec Section X: [title] (in `docs/04-technical-specification.md`)
- Roadmap Phase X: [title] (in `docs/03-roadmap.md`)

## Acceptance Criteria

- [ ] **AC-1:** [Specific, testable outcome]
- [ ] **AC-2:** [Specific, testable outcome]
- [ ] **AC-3:** [Error case or edge case]
- [ ] **AC-4:** [Boundary condition]

## Test Coverage

| AC | Test File | Test Type | Description |
|---|---|---|---|
| AC-1 | `packages/zip_core/test/src/.../..._test.dart` | Unit | [What the test verifies] |
| AC-2 | `packages/zip_core/test/src/.../..._test.dart` | Unit | [What the test verifies] |
| AC-3 | `packages/zip_core/test/src/.../..._test.dart` | Unit | [What the test verifies] |
| AC-4 | `packages/zip_captions/test/src/.../..._test.dart` | Widget | [What the test verifies] |

Test types: Unit, Widget, Integration, Contract, Manual

## Dependencies

- [P0-US-XXX: Story this depends on] (must be defined, not necessarily implemented)
- [Technical prerequisite]

## Notes

[Design decisions, open questions, implementation hints. Delete if empty.]

---

## Checklist (for PR)

- [ ] All acceptance criteria have corresponding tests
- [ ] All tests pass (`melos run test`)
- [ ] Static analysis passes (`melos run analyze`)
- [ ] No unrelated changes included
- [ ] Story status updated (via `./scripts/update-status.sh`)
- [ ] Spec docs updated if behavior changed
- [ ] No new dependencies added without human approval
- [ ] Generated code committed (`melos run generate`)
