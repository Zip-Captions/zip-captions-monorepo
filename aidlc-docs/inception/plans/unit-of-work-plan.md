# Unit of Work Plan — Phase 1: Core Captioning

## Plan Overview

Phase 1 has a proposed unit structure from the execution plan (7 construction units + 3 research spikes). This plan refines those units with precise component assignments from the Application Design, defines construction stages per unit, and maps all stories.

## Decomposition Steps

- [x] Step 1: Finalize spike definitions with deliverables and exit criteria
- [x] Step 2: Define Unit 1 (Core Abstractions) — components, construction stages, acceptance
- [x] Step 3: Define Unit 2 (Platform STT + Audio) — components, construction stages, acceptance
- [x] Step 4: Define Unit 3 (Output Targets) — components, construction stages, acceptance
- [x] Step 5: Define Unit 4 (UI Prototypes) — HTML/CSS prototypes, human review gate
- [x] Step 6: Define Unit 5 (Zip Captions App) — screens, wiring, construction stages
- [x] Step 7: Define Unit 6 (Zip Broadcast App) — screens, wiring, construction stages
- [x] Step 8: Define Unit 7 (Integration Milestones) — Build and Test + Documentation Refinement

## Mandatory Artifacts

- [x] Generate `phase1-unit-of-work.md` with unit definitions and responsibilities
- [x] Generate `phase1-unit-of-work-dependency.md` with dependency matrix
- [x] Generate `phase1-unit-of-work-story-map.md` mapping stories to units
- [x] Validate unit boundaries and dependencies
- [x] Ensure all stories are assigned to units (10/10 feature, 9/9 prototype, 6/6 milestones, 3/3 spikes)

---

## Questions

### Question 1 — DisplaySettings Rename Timing

The Application Design renames `AppSettings` to `DisplaySettings` and renames the settings notifier subclasses. When should this rename happen?

A) **Unit 1 (Core Abstractions)**: Since Unit 1 defines core abstractions, include the rename as part of that unit's code generation. All subsequent units use the new name from the start.
B) **Separate pre-construction refactor**: Before any Phase 1 unit starts, do a standalone rename PR. Units start with the rename already merged.
C) **Defer**: Keep `AppSettings` name through Phase 1 construction and rename in a later cleanup phase.

[Answer]: A

### Question 2 — Transcript Storage Unit Assignment

The TranscriptRepository (drift/SQLite) and TranscriptWriterTarget are tightly coupled. The execution plan places them in different units:
- Unit 1 (Core Abstractions): includes CaptionBus, CaptionOutputTarget interface
- Unit 3 (Output Targets): includes output target implementations

Should transcript storage go in Unit 1 (with the core models/repository) or Unit 3 (with the TranscriptWriterTarget implementation)?

A) **Unit 1**: TranscriptRepository, TranscriptDatabase, TranscriptSession, TranscriptSegment all in Unit 1 alongside the core models and CaptionBus. Unit 3 adds TranscriptWriterTarget that uses the repository.
B) **Unit 3**: All transcript components (repository, database, models, writer target) together in Unit 3. Unit 1 only has the abstract CaptionOutputTarget interface.
C) **Split**: Models (TranscriptSession, TranscriptSegment) in Unit 1. Repository + Database + WriterTarget in Unit 3.

[Answer]: B

### Question 3 — Construction Stage Depth for App UI Units

Units 5 (Zip Captions App) and 6 (Zip Broadcast App) are primarily UI wiring — connecting existing components (from Units 1-3) to screens (designed in Unit 4 prototypes). How deep should their construction stages go?

A) **Code Generation only**: Prototypes provide the design. Components exist from Units 1-3. The app units just wire them together. Skip Functional Design, NFR Requirements, and NFR Design.
B) **Functional Design + Code Generation**: Include Functional Design to define screen-level state management, navigation flow, and widget-to-provider wiring. Skip NFR stages (NFRs covered by component-level units).
C) **Full stages**: Include Functional Design, NFR Requirements (app-level performance, accessibility), NFR Design, and Code Generation.

[Answer]: C

### Question 4 — Spike Sequencing Strictness

The execution plan requires all spikes to complete before Unit 1. In practice, Spike 1.2 (system audio capture) only affects Unit 2 (Platform STT + Audio) and doesn't block core abstractions. Should spike sequencing be relaxed?

A) **Strict**: All 3 spikes complete before any construction unit starts. Ensures all research informs all design decisions.
B) **Relaxed**: Spike 1.1 and 1.3 must complete before Unit 1 (they inform STT engine design). Spike 1.2 can run in parallel with Unit 1 since it only affects Unit 2.
C) **Fully parallel**: Spikes run in parallel with construction where no direct dependency exists. Each unit lists its specific spike dependencies.

[Answer]: B

---

## Instructions

Please fill in each `[Answer]:` tag with your choice and any additional context. You can edit the file directly or respond here.
