# Documentation Refinement

**Purpose**: Refine AI-DLC working documents into lasting reference material and update project documentation with design decisions, supplemental resources, and architectural changes discovered during construction.

## Prerequisites
- Build and Test stage must be complete
- All construction artifacts exist in `aidlc-docs/`
- Project reference documentation exists in `docs/`

---

## Overview

During inception and construction, AI-DLC generates working documents — plans with checkboxes, clarification questions, draft designs, and audit logs. These capture valuable design rationale, domain modeling decisions, and architectural choices that would otherwise be lost.

This stage transforms that raw material into clean, reusable reference documentation and propagates relevant changes back into the project's `docs/` directory.

**This stage runs once after Build and Test completes (not per-unit).**

---

## Step 1: Inventory Working Documents

Scan the full `aidlc-docs/` tree and categorize each file:

| Category | Description | Action |
|---|---|---|
| **Design artifacts** | Domain entities, business rules, business logic models, component designs, NFR patterns | Clean up and preserve |
| **Plans** | Checkbox-tracked execution plans, clarification questions | Extract any unresolved decisions, then archive or remove |
| **State/audit** | `aidlc-state.md`, `audit.md` | Preserve as-is (historical record) |
| **Build/test instructions** | Build steps, test execution guides | Preserve if project-specific; remove if generic/templated |

Present the inventory to the user with a proposed action for each file before proceeding.

**Wait for Explicit Approval**: User must confirm the proposed actions before cleanup begins.

---

## Step 2: Clean Up Design Artifacts

For each design artifact being preserved:

1. **Remove workflow scaffolding** — strip checkbox syntax (`- [x]`, `- [ ]`), plan step numbers, "Step N:" prefixes, and AI-DLC stage headers that are only meaningful during execution
2. **Consolidate related content** — if multiple files cover the same topic (e.g., a plan file and its output artifact), merge the useful content into a single document
3. **Normalize structure** — ensure each document has:
   - A clear title and purpose statement
   - Consistent heading levels
   - Cross-references to related documents (use relative paths)
4. **Preserve design rationale** — keep "why" explanations, trade-off discussions, and rejected alternatives. These are the most valuable parts of the working documents
5. **Remove stale content** — delete sections that were superseded during construction (e.g., an initial design that was revised after clarification questions)

---

## Step 3: Propagate Changes to Project Documentation

Review the refined artifacts against the project's existing documentation in `docs/` and identify:

1. **New supplemental resources** — design documents, domain models, or component specifications that should be referenced from existing docs
2. **Design changes** — architectural decisions or interface changes made during construction that update or extend existing ADRs or specifications
3. **Corrections** — requirements or constraints in `docs/` that were found to be incomplete or inaccurate during construction

For each identified change:
- Present the specific proposed update (file, section, change) to the user
- **Wait for Explicit Approval** before modifying any file in `docs/`

**CRITICAL**: Do not modify files in `docs/` without explicit per-change approval. These are controlled specification documents.

---

## Step 4: Organize aidlc-docs Directory

After cleanup, ensure the `aidlc-docs/` directory is well-organized for future reference:

1. **Remove empty directories** left after consolidation
2. **Add or update `aidlc-docs/README.md`** with:
   - A brief description of what this directory contains
   - A table of contents listing each preserved document with a one-line summary
   - The date of the last refinement pass
3. **Verify all internal cross-references** still resolve after any file moves or consolidations

---

## Step 5: Update State Tracking

Update `aidlc-docs/aidlc-state.md`:
- Mark Documentation Refinement stage as complete
- Update current status

---

## Step 6: Present Results to User

Present a summary:

```
Documentation Refinement Complete

**Artifacts preserved**: [count] design documents cleaned and retained
**Artifacts archived/removed**: [count] plan/scaffold files
**Project docs updated**: [count] changes propagated to docs/
**aidlc-docs/README.md**: [Created/Updated]

Review the cleaned artifacts in aidlc-docs/ and confirm they are ready to commit.

**Ready to proceed to Operations stage?**
```

---

## Step 7: Log Interaction

**MANDATORY**: Log the stage completion in `aidlc-docs/audit.md`:

```markdown
## Documentation Refinement Stage
**Timestamp**: [ISO timestamp]
**Artifacts Preserved**: [list]
**Artifacts Removed**: [list]
**Project Docs Updated**: [list of changes to docs/]
**Status**: Complete

---
```
