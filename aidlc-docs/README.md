# AI-DLC Documentation Artifacts

Design and process artifacts generated during the AI-DLC inception and construction phases for Zip Captions v2. These documents capture domain modeling, design rationale, architecture decisions, and trade-offs that informed the implementation.

**Last refinement**: 2026-04-04

---

## State and Audit

| Document | Description |
|---|---|
| [aidlc-state.md](aidlc-state.md) | AI-DLC workflow progress tracker |
| [audit.md](audit.md) | Interaction log with timestamps and outcomes |

---

## Phase 0 — Foundation

### Inception

| Document | Description |
|---|---|
| [requirements.md](inception/requirements/requirements.md) | Phase 0 functional and non-functional requirements |
| [application-design.md](inception/application-design/application-design.md) | High-level application architecture |
| [components.md](inception/application-design/components.md) | Component catalog with responsibilities |
| [component-methods.md](inception/application-design/component-methods.md) | Public API surface per component |
| [component-dependency.md](inception/application-design/component-dependency.md) | Inter-component dependency graph |
| [services.md](inception/application-design/services.md) | Service layer design |
| [unit-of-work.md](inception/application-design/unit-of-work.md) | Construction units definition |
| [unit-of-work-dependency.md](inception/application-design/unit-of-work-dependency.md) | Unit execution ordering and dependencies |
| [unit-of-work-story-map.md](inception/application-design/unit-of-work-story-map.md) | Story-to-unit mapping |

### Construction

#### zip_core Library

| Document | Description |
|---|---|
| [domain-entities.md](construction/zip-core/functional-design/domain-entities.md) | Enums, freezed classes, sealed classes, abstract interfaces |
| [business-rules.md](construction/zip-core/functional-design/business-rules.md) | BR-01 through BR-12: state machine rules, persistence, locale, theme |
| [business-logic-model.md](construction/zip-core/functional-design/business-logic-model.md) | State machine transitions, settings persistence, locale management, theme colors |
| [nfr-design-patterns.md](construction/zip-core/nfr-design/nfr-design-patterns.md) | PBT patterns, WCAG AAA contrast, testing stack, security assessment, dependencies |
| [logical-components.md](construction/zip-core/nfr-design/logical-components.md) | Test infrastructure: generators, state machine model, contrast utils, prefs helpers |

#### CI/CD Pipeline

| Document | Description |
|---|---|
| [infrastructure-design.md](construction/ci-pipeline/infrastructure-design/infrastructure-design.md) | Workflow design, action versions, caching, Flutter SDK pinning, security compliance |
| [deployment-architecture.md](construction/ci-pipeline/infrastructure-design/deployment-architecture.md) | Trigger flows, branch protection setup, architecture diagrams |

#### Supabase Local Dev

| Document | Description |
|---|---|
| [infrastructure-design.md](construction/zip-supabase/infrastructure-design/infrastructure-design.md) | Docker Compose services, port mapping, environment variables, security compliance |
| [deployment-architecture.md](construction/zip-supabase/infrastructure-design/deployment-architecture.md) | Network topology, developer workflow, request flow diagrams |

#### Build and Test

| Document | Description |
|---|---|
| [build-and-test-summary.md](construction/build-and-test/build-and-test-summary.md) | Phase 0 build/test results: 87 tests, 0 analyze issues |
| [build-instructions.md](construction/build-and-test/build-instructions.md) | Prerequisites and build steps for the monorepo |
| [unit-test-instructions.md](construction/build-and-test/unit-test-instructions.md) | Test execution guide per package |

---

## Phase 1 — Core Captioning

### Inception

| Document | Description |
|---|---|
| [phase1-requirements.md](inception/requirements/phase1-requirements.md) | Phase 1 functional requirements (11 FRs, 5 NFR groups, 3 spikes) |
| [phase1-requirement-verification-questions.md](inception/requirements/phase1-requirement-verification-questions.md) | Clarification Q&A for Phase 1 requirements |
| [personas.md](inception/user-stories/personas.md) | User personas |
| [stories.md](inception/user-stories/stories.md) | Phase 1 user stories (10 feature, 9 prototype, 6 milestones) |
| [phase1-application-design.md](inception/application-design/phase1-application-design.md) | Phase 1 component architecture |
| [phase1-components.md](inception/application-design/phase1-components.md) | 22 new components, 8 modified |
| [phase1-component-methods.md](inception/application-design/phase1-component-methods.md) | Public API surface for Phase 1 components |
| [phase1-component-dependency.md](inception/application-design/phase1-component-dependency.md) | Phase 1 inter-component dependency graph |
| [phase1-services.md](inception/application-design/phase1-services.md) | Phase 1 service layer design |
| [phase1-unit-of-work.md](inception/application-design/phase1-unit-of-work.md) | Phase 1 construction units (3 spikes + 7 units) |
| [phase1-unit-of-work-dependency.md](inception/application-design/phase1-unit-of-work-dependency.md) | Phase 1 unit ordering and dependencies |
| [phase1-unit-of-work-story-map.md](inception/application-design/phase1-unit-of-work-story-map.md) | Phase 1 story-to-unit mapping |

### Construction

#### Spikes

| Document | Description |
|---|---|
| [spike-1.1-report.md](construction/spikes/spike-1.1-report.md) | Windows/Linux STT survey — Sherpa-ONNX recommended primary, Whisper.cpp secondary |
| [spike-1.2-report.md](construction/spikes/spike-1.2-report.md) | System audio capture feasibility — custom plugin needed per platform |
| [spike-1.3-report.md](construction/spikes/spike-1.3-report.md) | STT integration PoC — Sherpa-ONNX confirmed viable, OnlineRecognizer API maps to SttEngine |

#### Unit 1: Core Abstractions (S-01, S-03)

| Document | Description |
|---|---|
| [domain-entities.md](construction/core-abstractions/functional-design/domain-entities.md) | SttEngine, CaptionBus, RecordingState, SttResult, SpeechLocale, DisplaySettings rename |
| [business-rules.md](construction/core-abstractions/functional-design/business-rules.md) | Business rules for STT engine contract, caption bus, recording state machine |
| [business-logic-model.md](construction/core-abstractions/functional-design/business-logic-model.md) | STT session lifecycle, caption bus flow, state machine transitions |
| [nfr-design-patterns.md](construction/core-abstractions/nfr-design/nfr-design-patterns.md) | Registry pattern, PBT state machine model, test seam strategy |
| [logical-components.md](construction/core-abstractions/nfr-design/logical-components.md) | Component map, test infrastructure (mocks, generators, state model) |
| [nfr-requirements.md](construction/core-abstractions/nfr-requirements/nfr-requirements.md) | NFR requirements: reliability, testability, security, performance |
| [tech-stack-decisions.md](construction/core-abstractions/nfr-requirements/tech-stack-decisions.md) | Dependency decisions and rationale |
| [code-summary.md](construction/core-abstractions/code/code-summary.md) | Implementation summary: 156 tests passing, files created and modified |

#### Unit 2: Platform STT + Audio (S-02, S-06)

| Document | Description |
|---|---|
| [domain-entities.md](construction/platform-stt-audio/functional-design/domain-entities.md) | AudioDevice, WakeLockSettings, SherpaModel* models, RecordingErrorFactories |
| [business-rules.md](construction/platform-stt-audio/functional-design/business-rules.md) | BR-U2-01 through BR-U2-43: engine selection, permission, locale, wake lock, catalog, download |
| [business-logic-model.md](construction/platform-stt-audio/functional-design/business-logic-model.md) | AudioDeviceService, WakeLockService, SttSessionManager, engine implementations, provider chain |
| [nfr-design-patterns.md](construction/platform-stt-audio/nfr-design/nfr-design-patterns.md) | Crash recovery, OnlineRecognizerAdapter, download resume, caching, integrity verification, confirmation gate |
| [logical-components.md](construction/platform-stt-audio/nfr-design/logical-components.md) | Component map, test infrastructure (mocks, fixtures, generators, DioAdapter) |
| [nfr-requirements.md](construction/platform-stt-audio/nfr-requirements/nfr-requirements.md) | NFR requirements: reliability, testability, security, performance, usability |
| [tech-stack-decisions.md](construction/platform-stt-audio/nfr-requirements/tech-stack-decisions.md) | Dependency decisions: sherpa_onnx, speech_to_text, record, dio, archive, crypto, wakelock_plus |
| [code-summary.md](construction/platform-stt-audio/code/code-summary.md) | Implementation summary: 247 tests passing, files created and modified |

---

## Other

| Document | Description |
|---|---|
| [notebooklm-prompt.md](notebooklm-prompt.md) | NotebookLM video explainer prompt |
| [notebooklm-supplemental.md](notebooklm-supplemental.md) | Supplemental briefing for NotebookLM |
