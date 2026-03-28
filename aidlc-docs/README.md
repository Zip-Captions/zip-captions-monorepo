# AI-DLC Documentation Artifacts

Design and process artifacts generated during the AI-DLC inception and construction phases for Zip Captions v2 (Phase 0). These documents capture domain modeling, design rationale, architecture decisions, and trade-offs that informed the implementation.

**Last refinement**: 2026-03-28

---

## State and Audit

| Document | Description |
|---|---|
| [aidlc-state.md](aidlc-state.md) | AI-DLC workflow progress tracker |
| [audit.md](audit.md) | Interaction log with timestamps and outcomes |

## Inception

### Requirements

| Document | Description |
|---|---|
| [requirements.md](inception/requirements/requirements.md) | Phase 0 functional and non-functional requirements |

### Application Design

| Document | Description |
|---|---|
| [application-design.md](inception/application-design/application-design.md) | High-level application architecture |
| [components.md](inception/application-design/components.md) | Component catalog with responsibilities |
| [component-methods.md](inception/application-design/component-methods.md) | Public API surface per component |
| [component-dependency.md](inception/application-design/component-dependency.md) | Inter-component dependency graph |
| [services.md](inception/application-design/services.md) | Service layer design |
| [unit-of-work.md](inception/application-design/unit-of-work.md) | Construction units definition |
| [unit-of-work-dependency.md](inception/application-design/unit-of-work-dependency.md) | Unit execution ordering and dependencies |
| [unit-of-work-story-map.md](inception/application-design/unit-of-work-story-map.md) | Story-to-unit mapping |

## Construction

### zip_core (Unit 2)

| Document | Description |
|---|---|
| [domain-entities.md](construction/zip-core/functional-design/domain-entities.md) | Enums, freezed classes, sealed classes, abstract interfaces |
| [business-rules.md](construction/zip-core/functional-design/business-rules.md) | BR-01 through BR-12: state machine rules, persistence, locale, theme |
| [business-logic-model.md](construction/zip-core/functional-design/business-logic-model.md) | State machine transitions, settings persistence, locale management, theme colors |
| [nfr-design-patterns.md](construction/zip-core/nfr-design/nfr-design-patterns.md) | PBT patterns, WCAG AAA contrast, testing stack, security assessment, dependencies |
| [logical-components.md](construction/zip-core/nfr-design/logical-components.md) | Test infrastructure: generators, state machine model, contrast utils, prefs helpers |

### CI/CD Pipeline (Unit 5)

| Document | Description |
|---|---|
| [infrastructure-design.md](construction/ci-pipeline/infrastructure-design/infrastructure-design.md) | Workflow design, action versions, caching, Flutter SDK pinning, security compliance |
| [deployment-architecture.md](construction/ci-pipeline/infrastructure-design/deployment-architecture.md) | Trigger flows, branch protection setup, architecture diagrams |

### Supabase Local Dev (Unit 4)

| Document | Description |
|---|---|
| [infrastructure-design.md](construction/zip-supabase/infrastructure-design/infrastructure-design.md) | Docker Compose services, port mapping, environment variables, security compliance |
| [deployment-architecture.md](construction/zip-supabase/infrastructure-design/deployment-architecture.md) | Network topology, developer workflow, request flow diagrams |

### Build and Test

| Document | Description |
|---|---|
| [build-and-test-summary.md](construction/build-and-test/build-and-test-summary.md) | Phase 0 build/test results: 87 tests, 0 analyze issues |
| [build-instructions.md](construction/build-and-test/build-instructions.md) | Prerequisites and build steps for the monorepo |
| [unit-test-instructions.md](construction/build-and-test/unit-test-instructions.md) | Test execution guide per package |

## Other

| Document | Description |
|---|---|
| [notebooklm-prompt.md](notebooklm-prompt.md) | NotebookLM video explainer prompt |
| [notebooklm-supplemental.md](notebooklm-supplemental.md) | Supplemental briefing for NotebookLM |
