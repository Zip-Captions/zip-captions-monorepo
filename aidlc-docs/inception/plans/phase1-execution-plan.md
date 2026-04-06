# Phase 1 Execution Plan — Core Captioning

## Detailed Analysis Summary

### Transformation Scope
- **Transformation Type**: Major feature addition to existing brownfield monorepo
- **Primary Changes**: STT engine system, caption pipeline, transcript storage, audio capture, OBS/browser source integration, caption overlay, full app UIs for both apps
- **Related Components**: zip_core (new interfaces, providers, models), zip_captions (full UI), zip_broadcast (full UI with OBS/browser source/overlay), platform-native code (iOS, Android, macOS, Windows, Linux)

### Change Impact Assessment
- **User-facing changes**: Yes — all deliverables are user-facing (captioning, transcripts, settings, OBS output, overlay)
- **Structural changes**: Yes — new architecture layers (STT engine registry, caption bus, output targets, transcript storage)
- **Data model changes**: Yes — SttResult, SttEngine, CaptionOutputTarget, transcript SQLite schema, multi-input source configuration
- **API changes**: Yes — new public interfaces in zip_core (SttEngine, CaptionBus, CaptionOutputTarget)
- **NFR impact**: Yes — <1s latency, 1-2hr session stability, WCAG AAA, PBT, offline-first, multi-platform

### Component Relationships
```
zip_core (foundation)
  ├── SttEngine interface + registry
  ├── CaptionBus (pub-sub)
  ├── CaptionOutputTarget interface
  ├── TranscriptProvider + SQLite storage
  ├── RecordingState extensions
  └── Audio capture abstraction

zip_captions (personal user app)
  ├── depends on zip_core
  ├── Platform STT via speech_to_text
  ├── On-screen renderer (CaptionOutputTarget)
  ├── Transcript file writer (CaptionOutputTarget)
  └── Full UI (home, recording, settings, history, viewer)

zip_broadcast (broadcaster app)
  ├── depends on zip_core
  ├── Platform STT via speech_to_text
  ├── On-screen renderer (CaptionOutputTarget)
  ├── OBS WebSocket client (CaptionOutputTarget)
  ├── Browser source HTTP server (CaptionOutputTarget)
  ├── Caption overlay (always-on-top window)
  ├── Multi-input audio source management
  └── Full UI (home, recording, settings, audio config)
```

### Risk Assessment
- **Risk Level**: Medium-High
- **Key Risks**: Platform STT availability on Windows/Linux (mitigated by spikes), system audio capture complexity, multi-input STT performance, caption overlay platform differences
- **Rollback Complexity**: Moderate (each unit is independently testable)
- **Testing Complexity**: Complex (multi-platform, PBT, integration milestones)

---

## Phases to Execute

### INCEPTION PHASE
- [x] Workspace Detection — COMPLETE
- [x] Reverse Engineering — SKIPPED (no RE needed; Phase 0 artifacts current)
- [x] Requirements Analysis — COMPLETE (11 FRs, 5 NFR groups, 3 spikes)
- [x] User Stories — COMPLETE (10 feature + 9 prototype + 6 milestones)
- [x] Workflow Planning — IN PROGRESS
- [ ] Application Design — **EXECUTE**
  - **Rationale**: New components (SttEngine implementations, CaptionBus, output targets, TranscriptProvider, AudioCapture, OBS client, browser source server, caption overlay). Component interfaces and dependencies need definition before construction.
- [ ] Units Generation — **EXECUTE**
  - **Rationale**: 10 feature stories + 9 prototype stories need decomposition into sequenced construction units with dependency ordering. Spikes add pre-construction units.

### CONSTRUCTION PHASE (per unit)

Construction stages are assessed per unit. The following is the default assessment — individual units may skip stages that don't apply.

- [ ] Functional Design — **EXECUTE** (per unit, where business logic exists)
  - **Rationale**: STT engine state machine, caption bus subscription model, transcript storage schema, multi-input management, OBS protocol, browser source rendering. Conditional per unit — infrastructure-only units may skip.
- [ ] NFR Requirements — **EXECUTE** (per unit, where NFRs apply)
  - **Rationale**: Performance (<1s latency, 1-2hr stability), security (no transcript leakage), PBT (state machines, round-trips), accessibility (WCAG AAA), platform support tiers.
- [ ] NFR Design — **EXECUTE** (per unit, where NFR Requirements executed)
  - **Rationale**: PBT test patterns, performance test strategies, platform-specific test approaches.
- [ ] Infrastructure Design — **CONDITIONAL**
  - **Rationale**: EXECUTE for browser source server (HTTP server architecture), caption overlay (platform window management). SKIP for most units — existing CI/Supabase sufficient.
- [ ] Code Generation — **EXECUTE** (always, per unit)
- [ ] Build and Test — **EXECUTE** (always, after all units)
- [ ] Documentation Refinement — **EXECUTE** (always, after Build and Test)

### OPERATIONS PHASE
- [ ] Operations — **SKIP** (no deployment in Phase 1; local development only)

---

## Proposed Construction Units

Based on story dependencies and the requirement that spikes complete before construction:

### Pre-Construction: Research Spikes

| Unit | Stories | Description |
|------|---------|-------------|
| Spike 1.1 | — | Windows/Linux STT survey and comparison matrix |
| Spike 1.2 | — | System audio capture feasibility per platform |
| Spike 1.3 | — | Integration PoC for Spike 1.1 recommended engine |

**Sequencing**: Spike 1.1 before Spike 1.3. Spike 1.2 is independent. All spikes complete before Unit 1.

### Construction Units

| Unit | Stories | Package(s) | Construction Stages | Dependencies |
|------|---------|-----------|-------------------|-------------|
| 1: Core Abstractions | S-01, S-03 | zip_core | Functional Design, NFR Req, NFR Design, Code Gen | Spikes complete |
| 2: Platform STT + Audio | S-02, S-06 | zip_core, platform | Functional Design, NFR Req, NFR Design, Code Gen | Unit 1, Spikes 1.1/1.2/1.3 |
| 3: Output Targets | S-04, S-05, S-07, S-08 | zip_core, zip_broadcast | Functional Design, NFR Req, NFR Design, Infra Design (browser source), Code Gen | Unit 1 |
| 4: UI Prototypes | Proto-01..09 | aidlc-docs (HTML/CSS) | Code Gen only | Units 1-3 (need to know what to prototype) |
| 5: Zip Captions App | S-09 | zip_captions | Functional Design, Code Gen | Units 1-3, Proto-01..05 approved |
| 6: Zip Broadcast App | S-10 | zip_broadcast | Functional Design, Infra Design (overlay), Code Gen | Units 1-3, Proto-06..09 approved |
| 7: Integration Milestones | M-S1.1..M-S3.1 | all | Build and Test | Units 1-6 |

### Unit Dependency Graph

```
Spike 1.1 ──► Spike 1.3 ─┐
Spike 1.2 ────────────────┤
                           ▼
                    Unit 1: Core Abstractions
                    (SttEngine, CaptionBus)
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
     Unit 2: STT+Audio  Unit 3: Outputs  (parallel where possible)
              │            │
              └──────┬─────┘
                     ▼
              Unit 4: UI Prototypes
              (HTML/CSS, human review gate)
                     │
              ┌──────┴──────┐
              ▼             ▼
     Unit 5: Zip Captions  Unit 6: Zip Broadcast
              │             │
              └──────┬──────┘
                     ▼
        Unit 7: Integration Milestones
        (Build and Test + Documentation Refinement)
```

**Parallelization**: Units 2 and 3 can run in parallel after Unit 1. Units 5 and 6 can run in parallel after prototypes are approved.

---

## Success Criteria

- **Primary Goal**: Users can open either app, start captioning, and see live captions from their microphone on all Tier 1 platforms
- **Key Deliverables**: All 10 feature stories implemented, all 6 milestones passing, all 9 screen prototypes approved
- **Quality Gates**: 80%+ coverage per package, PBT for all state machines, WCAG AAA contrast, zero lint warnings, all CI checks passing
- **Phase 1 Exit Criteria**: As defined in roadmap and requirements document

---

## Workflow Visualization (Text)

```
Phase 1: INCEPTION
  - Workspace Detection .............. COMPLETE
  - Reverse Engineering .............. SKIPPED
  - Requirements Analysis ............ COMPLETE (11 FRs, 5 NFRs, 3 spikes)
  - User Stories ..................... COMPLETE (10 feature + 9 proto + 6 milestones)
  - Workflow Planning ................ IN PROGRESS
  - Application Design ............... EXECUTE (new components, interfaces)
  - Units Generation ................. EXECUTE (7 units + 3 spikes)

Phase 1: CONSTRUCTION
  - Spikes 1.1, 1.2, 1.3 ........... Pre-construction research
  - Unit 1: Core Abstractions ........ FD + NFR-R + NFR-D + CG
  - Unit 2: Platform STT + Audio ..... FD + NFR-R + NFR-D + CG
  - Unit 3: Output Targets ........... FD + NFR-R + NFR-D + ID + CG
  - Unit 4: UI Prototypes ............ CG (HTML/CSS, human gate)
  - Unit 5: Zip Captions App ......... FD + CG
  - Unit 6: Zip Broadcast App ........ FD + ID + CG
  - Unit 7: Integration + B&T ........ Build and Test + Doc Refinement

Phase 1: OPERATIONS
  - Operations ....................... SKIP (no deployment)
```
