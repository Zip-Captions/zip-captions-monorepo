# AI-DLC State Tracking

## Project Information
- **Project Name**: Zip Captions v2
- **Project Type**: Documentation-Brownfield / Code-Brownfield
- **Phase 0 Start Date**: 2026-03-26T00:00:00Z
- **Phase 1 Start Date**: 2026-03-28T00:00:00Z
- **Phase 2 Start Date**: 2026-07-19T21:00:00Z
- **Current Stage**: CONSTRUCTION Phase 2 — Unit 1 (UI Prototypes) COMPLETE 2026-09-25; next per build order is Spike 2.1, then Unit 2 (Broadcaster Auth). Awaiting human go-ahead to proceed.

## Workspace State
- **Existing Source Code**: Yes — Phase 0 scaffold complete (zip_core models/providers/theme, app shells, Supabase stack, CI/CD)
- **Existing Documentation**: Yes (docs/, AGENTS.md, ARCHITECTURE.md, CONTRIBUTING.md, aidlc-docs/)
- **Reverse Engineering Needed**: No (codebase built by AI-DLC in Phase 0; design artifacts in aidlc-docs/)
- **Workspace Root**: /Users/oblivious/Documents/zip-captions-monorepo

## Code Location Rules
- **Application Code**: Workspace root (NEVER in aidlc-docs/)
- **Documentation**: aidlc-docs/ only
- **Structure patterns**: See code-generation.md Critical Rules

## Extension Configuration

| Extension | Enabled | Decided At |
|---|---|---|
| Security Baseline | Yes — all rules as blocking constraints | Requirements Analysis |
| Property-Based Testing | Yes — full enforcement (all rules) | Requirements Analysis |

## Stage Progress

### INCEPTION PHASE
- [x] Workspace Detection — Documentation-brownfield / code-greenfield; no source code
- [ ] Reverse Engineering — SKIPPED (no source code to analyze)
- [x] Requirements Analysis — COMPLETE; requirements.md generated
- [ ] User Stories — SKIPPED (infrastructure scaffolding; no user-facing features)
- [x] Workflow Planning — COMPLETE; execution-plan.md generated (6 units)
- [x] Application Design — COMPLETE
- [x] Units Generation — COMPLETE

### CONSTRUCTION PHASE
- [x] Unit 1: Monorepo Scaffold — MERGED (PR #2, commit d6c9cd1)
- [x] Unit 2: zip_core Library — COMPLETE (Functional Design, NFR Requirements, NFR Design, Code Generation all done; 81 tests passing)
- [x] Unit 3: App Shells — COMPLETE (Code Generation done; 6 widget tests passing)
- [x] Unit 4: Supabase Local Dev — COMPLETE (NFR Requirements, Infrastructure Design, Code Generation all done)
- [x] Unit 5: CI/CD Pipeline — COMPLETE (NFR Requirements, Infrastructure Design, Code Generation all done)
- [x] Unit 6: Spike 0.1 — COMPLETE (platform scaffolding, macOS builds pass, build-verify.yml, PLATFORM_SETUP.md)
- [x] Build and Test — COMPLETE (87 tests pass, 0 analyze issues, docs generated)
- [x] Documentation Refinement — COMPLETE

### OPERATIONS PHASE
- [x] Operations — SKIPPED (Phase 0 is infrastructure scaffolding; no deployment or production operations)

---

## Phase 1: Core Captioning

### INCEPTION PHASE
- [x] Workspace Detection — Brownfield; Phase 0 scaffold exists; no reverse engineering needed
- [ ] Reverse Engineering — SKIPPED (codebase built by AI-DLC; design artifacts current)
- [x] Requirements Analysis — COMPLETE; phase1-requirements.md generated (11 FRs, 5 NFR groups, 3 spikes; 4 revisions)
- [x] User Stories — COMPLETE; 10 feature stories, 9 prototype stories, 6 milestones; 4 revisions
- [x] Workflow Planning — COMPLETE; 7 construction units + 3 spikes
- [x] Application Design — COMPLETE; 22 new components, 8 modified, 7 service layers; DisplaySettings rename
- [x] Units Generation — COMPLETE; 3 spikes + 7 units; all stories assigned; relaxed spike sequencing

### CONSTRUCTION PHASE
- [x] Spike 1.1: Windows/Linux STT Survey — COMPLETE; Sherpa-ONNX recommended primary, Whisper.cpp secondary
- [x] Spike 1.2: System Audio Capture Feasibility — COMPLETE; custom plugin needed, Core Audio taps (macOS), WASAPI loopback (Windows), PulseAudio monitors (Linux)
- [x] Spike 1.3: STT Integration PoC — COMPLETE; Sherpa-ONNX confirmed viable, OnlineRecognizer API maps to SttEngine contract
- [x] Unit 1: Core Abstractions (S-01, S-03) — FD, NFR-R, NFR-D, CG — COMPLETE (156 tests passing, 0 errors)
- [x] Unit 2: Platform STT + Audio (S-02, S-06) — FD, NFR-R, NFR-D, CG — COMPLETE (247 tests passing, 0 errors)
- [x] Unit 3: Output Targets (S-04, S-05, S-07, S-08) — FD, NFR-R, NFR-D, ID, CG — COMPLETE (all 21 CG steps done; 0 errors, 0 warnings; 7 pre-existing implementation_imports infos)
- [x] Unit 4: UI Prototypes (Proto-01..09) — CG, Human Review Gate, Implementation Design — COMPLETE
- [x] Unit 5: Zip Captions App (S-09) — FD, NFR-R, NFR-D, CG — COMPLETE (merged PR #14)
- [x] Unit 6: Zip Broadcast App (S-10) — FD, NFR-R, NFR-D, ID, CG — COMPLETE (merged PR #15; 80 tests)
- [x] Unit 7: Integration Milestones — Build and Test COMPLETE (457 tests pass, 0 analyze issues); Doc Refinement COMPLETE
- [x] Phase 1 UI/UX Human Review Gate (Zip Broadcast) — COMPLETE 2026-07-07; sign-off PASS after fixing nav Audio Inputs icon, Start-button gating, stuck-disabled-after-stop, duplicate audio-inputs back-stack push, active-route re-navigation, mobile drawer grouping, Appearance chip→select-box conversion (branch `feature/phase1-integration-tests`)
- [x] PR #16 (`feature/phase1-integration-tests` → `develop`) — MERGED 2026-07-19; CodeRabbit CHANGES_REQUESTED (5 findings) and 2 failing CI checks (lint, Windows Build Verify — MSVC toolchain regression, unrelated to PR diff) resolved across 3 follow-up commits (`b12cb51`, `19cf2ca`, `2a5c987`); see `aidlc-docs/construction/plans/unit7-pr16-review-fixes-code-generation-plan.md`

**Phase 1 Construction — FULLY COMPLETE.**

### OPERATIONS PHASE
*(placeholder)*

---

## Phase 2: Broadcasting & Transport

### INCEPTION PHASE
- [x] Workspace Detection — Brownfield; Phase 1 fully merged; caption bus exists; no reverse engineering needed
- [ ] Reverse Engineering — SKIPPED (codebase built by AI-DLC; design artifacts current)
- [x] Requirements Analysis — COMPLETE (approved); phase2-requirements.md (10 FRs, 8 NFR groups, 3 spikes as early construction units)
- [x] User Stories — COMPLETE (approved); phase2-stories.md (10 stories S-11..S-20, 3 security reviews SR-01..03, 6 prototypes Proto-10..15, 4 milestones) + phase2-personas.md (draft S3.6)
- [x] Workflow Planning — COMPLETE (approved); phase2-execution-plan.md (App Design EXECUTE, Units Generation EXECUTE; 3 spikes + 9 preliminary units; Operations SKIP)
- [x] Application Design — COMPLETE (approved); phase2-application-design.md + components, component-methods, services, component-dependency (zip_core-centric; role-specific transports; independent broadcast/captioning lifecycles with optional auto-start)
- [x] Units Generation — COMPLETE (approved); phase2-unit-of-work.md, -dependency.md, -story-map.md (3 spikes + 9 units; SR gates before CG in U2/U3/U4; one PR per unit; spike code throwaway)

**Phase 2 Inception — COMPLETE 2026-09-26.**

### CONSTRUCTION PHASE
- [x] Unit 1: UI Prototypes (Proto-10 through Proto-15) — COMPLETE 2026-09-25 (approved 2026-09-25); all 6 prototypes generated and individually approved. Unblocks Unit 2 (Proto-10), and independently unblocks Unit 8 (Proto-13); Units 6 and 7 still need Unit 5 in addition to their approved prototypes. See `aidlc-docs/construction/phase2-unit1-prototypes/code/unit1-summary.md`.

**Current Stage**: CONSTRUCTION Phase 2 — Unit 1 complete; next per the suggested build order is Spike 2.1, then Unit 2 (Broadcaster Auth). Awaiting human go-ahead to proceed.

#### Backlog (Deferred Scope)
- **Caption attribution / speaker-name prefix on captions**: raised during Proto-12 review 2026-09-25. Phase 1 (S-06) already scopes a per-audio-input `speakerLabel` + visual style (color/indicator) on `AudioInputConfig`, applied by the on-screen renderer (`phase1-services.md` §7). Not yet scoped: whether the speaker label should be *prepended as text* to the caption content itself (e.g. "Teacher: ...") rather than only conveyed via color/indicator, and whether a broadcaster can set a label distinct from the raw input device name specifically for this purpose. Out of scope for Unit 1 (prototypes) and not implemented in `zip-broadcast-dashboard.html`. Revisit at Unit 6 (Zip Broadcast Broadcast UI) Functional Design, since it may touch shared `zip_core` caption rendering (used by both apps), not just zip_broadcast-specific UI.
- **Pop out live captions into a small floating window (Zip Captions viewer)**: raised during Proto-15 review 2026-09-25. Not in S-19's acceptance criteria, FR-7.1–7.6, or `BroadcastViewerScreen`'s component design (`phase2-components.md`), which renders captions inline only. User clarified intent: a small floating/PiP-style caption window, not a full separate app window — closer to browser Picture-in-Picture than to the desktop multi-window overlay Unit 8 builds for broadcasters (`OverlayWindowApp`). Not implemented in `zip-captions-viewer-states.html`. Revisit at Unit 7 (Zip Captions Viewer) Functional Design: if it needs a new dependency (e.g. a PiP/windowing plugin), FR-9.5 requires human approval and a supply-chain justification before it's added; web (browser Document Picture-in-Picture API) and desktop may need different mechanisms.

