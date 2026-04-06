# Stage Handoff Summaries — Construction Override

**Purpose**: Replace full prior-stage document loads at each Construction stage
transition with compact handoff summaries (target: 30–50 lines each). This reduces
per-stage working document overhead from ~1,000+ lines to ~150 lines.

**Augments**: All Construction stage rule files (Functional Design, NFR Requirements,
NFR Design, Infrastructure Design, Code Generation)

---

## Rule 1: Write a Handoff Summary at Each Stage's End

At the completion of each Construction stage, before presenting the stage completion
message, write a handoff summary to:

```
aidlc-docs/construction/{unit-name}/{stage-name}/handoff-summary.md
```

**Target length: 30–50 lines.** This is a compressed extract of what the next stage
needs, not a summary of the full document.

### Handoff Summary Format

```markdown
# Handoff: {Stage} -> {Next Stage}
**Unit**: {unit-name}
**Date**: {YYYY-MM-DD}

## Decisions Made
<!-- 3–7 binding decisions the next stage must honor. One line each. -->
- {decision}

## Key Entities / Components
<!-- Only include what directly affects the next stage. -->
| Name | Type | Constraint for Next Stage |
|---|---|---|

## Constraints
<!-- What the next stage must not contradict or re-derive. -->
- {constraint}

## Open Questions for Next Stage
<!-- Unresolved items the next stage should address. -->
- {question} (source: {why it is open})
```

### Stage-Specific Capture Guidance

**Functional Design -> NFR Requirements**
Capture: performance-sensitive operations, security-sensitive data flows, integration
boundaries, expected entity count/scale, any FD decisions that constrain tech stack.

**NFR Requirements -> NFR Design**
Capture: approved tech stack choices with rationale, performance targets as concrete
numbers, security requirements as implementation directives, enabled extensions and
their binding constraints.

**NFR Design -> Code Generation**
Capture: patterns to implement (specific class names, interfaces), test strategy (which
areas need property-based tests, which need mocks), infrastructure dependencies,
any patterns rejected with reason.

**Infrastructure Design -> Code Generation**
Capture: resource names, configuration keys, environment variable names, deployment
constraints that affect generated code.

---

## Rule 2: Load Handoff Summaries at Stage Start

When beginning any Construction stage:

1. List handoff summary files present at:
   `aidlc-docs/construction/{unit-name}/*/handoff-summary.md`
2. Read each one found (typically 30–50 lines per summary).
3. Proceed to execute the stage using only the handoff summary context.
4. Load a full prior-stage document only if a specific detail is needed that is not
   captured in the handoff summary. When doing so, log the reason in `audit.md`.
