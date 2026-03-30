# Story Generation Plan — Phase 1: Core Captioning

## Plan Overview

Phase 1 has 3 existing personas (Alex, Jordan, Sam) with defined scenarios in `docs/01-user-personas.md`. This plan converts the Phase 1 requirements (FR-1 through FR-11) into implementable user stories with acceptance criteria.

## Questions

### Question 1
Story breakdown approach. Given that Phase 1 has clear persona scenarios (Alex S1.1-S1.3, Jordan S2.1-S2.2, Sam S3.1) and shared infrastructure (STT engine, caption bus, transcript storage), how should stories be organized?

A) Persona-based: stories grouped by persona, shared infrastructure extracted as enabler stories
B) Feature-based: stories grouped by feature area (STT, caption bus, rendering, transcripts, OBS, audio), each referencing which personas benefit
C) Layered: infrastructure stories first (STT engine, caption bus, storage), then persona-specific UI stories that consume the infrastructure
D) Other (please describe after [Answer]: tag below)

[Answer]: B

### Question 2
Story granularity. Phase 1 has both deep infrastructure (STT engine interface, caption bus, SQLite storage) and user-facing UI (recording screen, settings, transcript viewer). What granularity?

A) Coarse: one story per FR group (e.g., "FR-1: STT Engine Interface and Registry" is one story) — ~11 stories total
B) Medium: break each FR group into 2-4 stories by natural boundaries (e.g., FR-1 splits into interface definition, registry, provider, platform implementation) — ~25-35 stories
C) Fine: one story per testable behavior (e.g., "engine reports available locales", "engine handles pause on platforms without native pause") — ~50+ stories
D) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 3
The existing persona scenarios in `docs/01-user-personas.md` describe end-to-end user journeys (e.g., S1.1 "Alex at a one-on-one conversation"). Should stories map directly to these scenarios, or should they be decomposed into smaller units that compose into the scenarios?

A) Map directly: each scenario becomes an epic, with sub-stories for the individual steps within the scenario
B) Decompose: break scenarios into reusable capability stories (e.g., "start captioning", "configure text size", "save transcript") that compose into multiple scenarios
C) Both: scenario-level acceptance stories as integration milestones, plus decomposed capability stories for implementation
D) Other (please describe after [Answer]: tag below)

[Answer]: C

### Question 4
Acceptance criteria format. What level of detail for acceptance criteria?

A) Given/When/Then (Gherkin-style) for all stories — formal, directly translatable to tests
B) Bullet-point checklist of observable behaviors — less formal, faster to write
C) Given/When/Then for behavior-critical stories (state machine, error handling), bullet-point for UI/configuration stories
D) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 5
Research spikes (1.1, 1.2, 1.3) produce findings that affect subsequent stories. Should spikes be represented as user stories, or kept separate?

A) Separate: spikes are not user stories (no user value directly). They produce spike reports that inform story refinement. Reference them as dependencies only.
B) Include as technical stories: "As a developer, I need to evaluate Windows/Linux STT options so that I can implement the correct engine"
C) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 6
UI design prototype stories (FR-11). How should prototypes relate to implementation stories?

A) Separate prototype stories per screen (e.g., "Prototype: Recording Screen") that block the corresponding implementation stories
B) Prototype is a subtask within each UI implementation story (prototype, review, then implement)
C) One umbrella prototype story per app ("Prototype all Zip Captions screens") that blocks all UI implementation stories for that app
D) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Generation Steps

After questions are answered, execute these steps:

- [x] Step 1: Update `docs/01-user-personas.md` persona references if needed (no persona creation — they exist) — No updates needed; personas are current
- [x] Step 2: Generate epic structure based on chosen breakdown approach — Feature-based with milestones
- [x] Step 3: Generate infrastructure/enabler stories (STT engine, caption bus, storage, audio capture) — S-01 through S-06
- [x] Step 4: Generate Zip Captions UI stories (Alex + Sam personas) — S-09
- [x] Step 5: Generate Zip Broadcast UI stories (Jordan persona) — S-10
- [x] Step 6: Generate OBS WebSocket and browser source stories — S-07, S-08
- [x] Step 7: Generate design prototype stories per chosen approach — Proto-01 through Proto-09
- [x] Step 8: Add acceptance criteria to all stories per chosen format — Given/When/Then for all
- [x] Step 9: Map stories to personas and FR requirements (traceability matrix) — Complete
- [x] Step 10: Identify story dependencies and sequencing — Dependency graph in stories.md
- [x] Step 11: Write stories.md and update personas.md (if needed) — Both generated
- [x] Step 12: Verify INVEST criteria compliance for all stories — Compliance table in stories.md
