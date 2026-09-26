# Unit of Work Plan — Phase 2: Broadcasting & Transport

## Plan Overview

The approved execution plan proposes 3 spikes and 9 construction units. This plan refines those units with component assignments from the Phase 2 Application Design, sets the construction stages for each unit, places the security review gates (SR-01 to SR-03), and maps every story, prototype and milestone to a unit.

Output files use a `phase2-` prefix, matching the Phase 1 convention.

Fill in the letter choice after each `[Answer]:` tag. If none of the options match, choose X and describe your preference.

## Decomposition Steps

- [x] Step 1: Finalize spike definitions (2.1, 2.2, 2.3) with deliverables, exit criteria and the units they feed (per Q2, Q5)
- [x] Step 2: Define Unit 1 (UI Prototypes): Proto-10 to Proto-15, human review gate
- [x] Step 3: Define Unit 2 (Broadcaster Auth): S-15 + SR-01, components, stages
- [x] Step 4: Define Unit 3 (Broadcast Identity + Signaling): S-11, S-13 + SR-02, components, stages
- [x] Step 5: Define Unit 4 (Coturn Infrastructure): S-12 + SR-03, components, stages
- [x] Step 6: Define Unit 5 (WebRTC Transport + Remote Output + Capacity): S-14, S-16, S-18 (per Q4)
- [x] Step 7: Define Unit 6 (Zip Broadcast Broadcast UI): S-17
- [x] Step 8: Define Unit 7 (Zip Captions Viewer): S-19
- [x] Step 9: Define Unit 8 (External Display): S-20
- [x] Step 10: Define Unit 9 (Integration Milestones): M-S2.2, M-S2.3, M-S3.6, M-REG-01, Build and Test, Documentation Refinement
- [x] Step 11: Set construction stages per unit (per Q1) and PR boundaries (per Q3)

## Mandatory Artifacts

- [x] Generate `phase2-unit-of-work.md` with unit definitions and responsibilities
- [x] Generate `phase2-unit-of-work-dependency.md` with dependency matrix
- [x] Generate `phase2-unit-of-work-story-map.md` mapping stories to units
- [x] Validate unit boundaries and dependencies
- [x] Ensure all stories are assigned to units (10 stories, 3 reviews, 6 prototypes, 4 milestones, 3 spikes) — all assigned, each exactly once

---

## Questions

### Question 1 — Construction stage depth for app UI units
In Phase 1 you chose full stages (Functional Design, NFR Requirements, NFR Design, Code Generation) for the app UI units (Phase 1 Q3:C). Phase 2's UI units are Unit 6 (Zip Broadcast broadcast screens) and Unit 7 (Zip Captions viewer). Unit 7 has real NFR content: screen-reader announcements for 8 states, security headers on the web route, and reconnection timing. Unit 6 has less.

A) **Full stages for both** (Phase 1 precedent). **(Recommended)**
B) **Full stages for Unit 7; Functional Design + Code Generation only for Unit 6.** Unit 6's NFRs (latency, fan-out) are already covered by Unit 5.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 2 — Spike sequencing
In Phase 1 you relaxed sequencing so that spikes blocked only the units they inform (Phase 1 Q4:B). In Phase 2, Spike 2.1 informs Units 3 and 5 (presence timeout, viewer cap, fan-out, desktop `flutter_webrtc`). Spike 2.3 informs Unit 4. Spike 2.2 informs no unit (FR-10 only).

A) **Per-unit spike dependencies.** Each unit waits only for the spikes that inform it. Units 1, 2 and 8 can start immediately, and Spike 2.2 runs whenever convenient. **(Recommended)**
B) **Strict.** All three spikes complete before any construction unit starts.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 3 — Pull request boundaries
AGENTS.md says "one unit of work per PR, open the PR before starting the next unit". In practice, Phase 1 bundled Units 3-5 into PR #14.

A) **One PR per unit**, as AGENTS.md states. Spikes each get a docs-only PR containing their report. **(Recommended)**
B) **Bundle small adjacent units** into one PR where they are reviewed together anyway. Proposed bundles: Unit 1 (prototypes) as its own docs PR; Units 6 and 7 together. Everything else is one PR per unit.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 4 — Size of Unit 5
Unit 5 combines the WebRTC transport (S-14), the remote output target and receiver (S-16), and capacity admission (S-18). It is the largest and riskiest unit. It is also the one place where both protocol sides are tested together.

A) **Keep it as one unit.** The transport, wire format, output target and admission are tested together against fakes, and splitting would leave the first half unusable on its own. **(Recommended)**
B) **Split into 5a (S-14 transport + S-18 admission) and 5b (S-16 output target + receiver).** Each PR is smaller, but 5a has no end-to-end caption path until 5b lands.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 5 — Spike code
Spike 2.1 needs a working multi-peer WebRTC harness to measure fan-out, and Spike 2.3 needs a running Coturn. What happens to spike code?

A) **Throwaway.** Spike code lives outside the packages (a spike folder referenced from the spike report) and is never merged into `zip_core`. Unit 5 and Unit 4 are built test-first from their own design (TDD mandate). Reusable findings, such as configuration values and pitfalls, go into the spike report. **(Recommended)**
B) **Seed code.** Spike harness code may be promoted into `zip_core` or the local stack as the starting point for Units 4 and 5, with tests added afterwards.
X) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Instructions

Fill in each `[Answer]:` tag with a letter, plus any context. After the answers are analyzed, you'll be asked to approve the plan before the unit artifacts are generated.
