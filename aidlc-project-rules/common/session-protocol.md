# Session Protocol — Project Override

**Purpose**: Reduce token overhead at session start by suppressing unnecessary startup
loads and deferring common rule files until they are actually needed.

**Overrides**: `common/session-continuity.md`, `common/welcome-message.md`
**Augments**: Startup loading mandated by `core-workflow.md`

---

## Rule 1: Welcome Message Suppression

When `aidlc-docs/aidlc-state.md` exists and contains at least one completed stage,
**skip** loading `common/welcome-message.md`. This session is a continuation of an
existing workflow, not a new start.

---

## Rule 2: Lean Session Resume

When `aidlc-state.md` exists and shows a specific in-progress unit and stage, replace
the full mandatory common file battery with the following:

**Load immediately:**
- `aidlc-docs/aidlc-state.md`
- The current unit's handoff summaries (see `construction/stage-handoff.md`)
- The current stage's rule file from `.aidlc-rule-details/construction/`

**Load on demand — defer until the situation requires it:**

| File | Load when |
|---|---|
| `common/process-overview.md` | User asks about overall workflow structure |
| `common/question-format-guide.md` | About to ask structured questions |
| `common/terminology.md` | A term is ambiguous in context |
| `common/error-handling.md` | An error or unexpected state occurs |
| `common/workflow-changes.md` | A workflow change or stage skip is requested |
| `common/ascii-diagram-standards.md` | About to create a diagram |

**Load when the current stage makes them applicable:**
- Extension rule files (security-baseline, property-based-testing) — load at the first
  stage where they impose constraints (Functional Design or NFR Requirements), then
  keep in context for all subsequent stages in the unit.

---

## Rule 3: Vault-First Codebase Orientation

Before reading any source file or `docs/` document to understand a component:

1. Check whether `~/Documents/ai-dlc-vault/_vault_index.md` has been read this session.
   If not, read it now using the `obsidian-mcp` `read_note` tool.
2. Find and read the vault note for the relevant package or file using `search_notes`
   (keyword search), `search_by_tag` (e.g. `dart`, `directory`, `documentation`),
   or `read_note` (direct path lookup).
3. Only open the source file directly when making changes or when the vault note
   does not answer the specific question.

This rule does not apply when the file has been modified in the current session or in
the most recent PR — for recently changed files, prefer the source.
