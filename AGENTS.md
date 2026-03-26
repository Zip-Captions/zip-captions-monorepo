# Zip Captions v2 — Agent Instructions

## Project

Zip Captions is a free, open-source accessibility tool providing real-time speech-to-text captioning. Two Flutter apps (Zip Captions for personal users, Zip Broadcast for broadcasters) share a `zip_core` library in a Melos-managed monorepo. Self-hosted Supabase backend with zero-knowledge transcript encryption.

## Architecture

Read these docs before making changes to any component:

- `ARCHITECTURE.md` — System overview, component map, communication paths, data flows. Start here to understand what the system is and where to find details.
- `CONTRIBUTING.md` — Development workflow: branching, task tracking, code review
- `docs/TDD.md` — Test-driven development process (mandatory for all code changes)
- `docs/TEST_SETUP.md` — Test infrastructure: how to write and run tests per package
- `docs/STORY_TEMPLATE.md` — Template for creating user stories

Detailed specifications (read the relevant sections, not all of them):

- `docs/01-user-personas.md` — User personas, scenarios, free/premium matrices. Read when you need to understand WHY a feature exists.
- `docs/02-architecture-decisions.md` — 14 ADRs. Read when you need to understand WHY the system is designed this way.
- `docs/03-roadmap.md` — Phased development plan. Read when you need to understand WHEN something is built and what its dependencies are.
- `docs/04-technical-specification.md` — Coding standards, patterns, constraints. **Read before writing any code.**

Per-package instructions (read when working in that package):

- `packages/zip_core/AGENTS.md`
- `packages/zip_captions/AGENTS.md`
- `packages/zip_broadcast/AGENTS.md`
- `packages/zip_supabase/AGENTS.md`

## Project Structure

```
zip-captions-monorepo/
  packages/
    zip_core/        — Dart shared library (STT, audio, caption bus, encryption, models, BLE, transport)
    zip_captions/    — Flutter personal user app (iOS, Android, macOS, Windows, Linux, web)
    zip_broadcast/   — Flutter broadcaster app (macOS, Windows, Linux, web)
    zip_supabase/    — Supabase Edge Functions (TypeScript/Deno) + Postgres migrations
  docs/              — Specification documents
  scripts/           — Agent workflow scripts (claim stories, update status)
  stories/           — User stories organized by phase
  test-fixtures/     — Shared test data for cross-package contract tests
  ai-dlc/            — Agentic dev template (git submodule, reference only)
```

## Critical Constraints

- **Transcript content must never appear in logs, telemetry, crash reports, analytics, or any data sent off-device** (except encrypted sync to Supabase Storage). This is an absolute, non-negotiable constraint. See `docs/04-technical-specification.md` Section 8.
- **Encryption keys never leave the device** except via explicit user-initiated transfer (P2P, QR, hardware key). See ADR-006.
- **All Supabase tables must have Row Level Security policies.** No table without RLS. See `docs/04-technical-specification.md` Section 9.
- **Server-side relay infrastructure (TURN, Supabase Realtime) must never log, store, or inspect caption payloads.** Zero-retention for data in transit. See ADR-006.
- **Devices without authentication (no PIN, no biometrics) cannot save transcripts.** Enforced in code, not just policy. See `docs/01-user-personas.md`, Device Security Requirements.
- **No Google STUN dependency.** All ICE infrastructure is self-hosted via Coturn. See ADR-011.
- **Translation disclaimer is non-dismissible.** All translated text must display: "Source language: [detected]. Translation may be inaccurate." Always visible when translation is active. See ADR-013.
- **No emojis anywhere in the codebase** — not in comments, commits, PR descriptions, docs, or string literals.
- **English only** — all code, comments, names, docs, commits. UI strings are externalized via ARB files.

## Code Style

- **Dart/Flutter:** `very_good_analysis` linting, zero warnings. `snake_case` files, `PascalCase` classes, `camelCase` variables. Package imports only (`package:zip_core/...`), never relative. All providers via `riverpod_generator`. `freezed` for state classes. `mocktail` for test mocking. See `docs/04-technical-specification.md` Sections 1-2 for full details.
- **TypeScript/Deno (Edge Functions):** `kebab-case` function files. Validate JWT on all authenticated endpoints. Return structured JSON errors. See `docs/04-technical-specification.md` Section 9.
- **SQL (Migrations):** `snake_case` table and column names. Tables are plural. All tables have `id` (UUID), `created_at`, `updated_at`. Forward-only migrations. See `docs/04-technical-specification.md` Section 9.
- **Commits (agents):** Conventional Commits required. Scope with package name: `feat(zip_core): add SttEngine interface`. See `docs/04-technical-specification.md` Section 7.

## Boundaries — Do Not Modify Without Discussion

These are stable contracts. Changing any of these requires updating multiple documents and components simultaneously. **Stop and ask before modifying:**

- `SttEngine` abstract class interface (`zip_core`) — defined in ADR-005
- `SttResult` model fields (`zip_core`) — defined in ADR-005
- `TranslationEngine` abstract class interface (`zip_core`) — defined in ADR-013
- Caption bus stream contract (`zip_core`) — defined in ADR-008
- BLE service UUID and characteristic format (`zip_core`) — defined in ADR-007
- Supabase table names, column names, and RLS policies (`zip_supabase`) — defined in `docs/04-technical-specification.md` Section 9
- Supabase Realtime channel naming convention — defined in `docs/04-technical-specification.md` Section 9
- Encryption algorithm and key storage mechanism — defined in ADR-006
- Stable broadcast URL format (`zipcaptions.app/b/{broadcast_id}`) — defined in ADR-011

## Security-Critical Code — Pre-Approval Required

The following areas require human review of the **approach** BEFORE implementation begins. Do not write code in these areas without a human-approved plan:

- Encryption key generation, storage, transfer, or derivation
- AES-256-GCM encryption/decryption implementation
- Supabase RLS policy definitions
- OAuth authentication flows
- Device security posture detection
- Server-side log configuration (must exclude payloads)
- Any code that handles raw transcript content for sync/backup

## Current Scope

**Phase 0 — Foundation.** See `docs/03-roadmap.md` Phase 0 for full deliverables.

In scope:
- Monorepo scaffold with Melos
- App shells for Zip Captions (all platforms) and Zip Broadcast (desktop + web)
- Riverpod setup with `riverpod_generator` and `build_runner`
- Supabase local development environment (Docker Compose)
- CI/CD pipeline (lint, analyze, test across all packages)
- Localization scaffold (ARB files, English source, v1 translations imported)
- `zip_core` empty package with pubspec, test scaffold, linting

Out of scope for Phase 0:
- STT engine implementation (Phase 1)
- Caption bus (Phase 1)
- Any UI beyond hello-world app shells
- Broadcasting, transport, auth, encryption (Phases 2-3)
- Entitlements, BLE, translation (Phases 4-5, 8)

## Task Discovery and Workflow

Agents discover and manage work via GitHub Projects using the wrapper scripts in `scripts/`.

### Finding Work

```bash
./scripts/list-available.sh
```

### Claiming a Story

```bash
./scripts/claim-story.sh P0-US-001
```

### Updating Status

```bash
./scripts/update-status.sh P0-US-001 "Tests Written"
./scripts/update-status.sh P0-US-001 "In Review"
```

### Workflow

1. Run `./scripts/list-available.sh` to find work
2. Pick the top-priority story in your package scope
3. Run `./scripts/claim-story.sh <story-id>` to claim it
4. Create your feature branch: `git checkout -b feature/<story-id>-short-name`
5. Read the story file in `stories/` and the linked spec docs
6. Write failing tests per the acceptance criteria
7. Run `./scripts/update-status.sh <story-id> "Tests Written"`
8. Implement until tests pass
9. Run all tests: `melos run test`
10. Run analysis: `melos run analyze`
11. Open a PR targeting `develop`
12. Run `./scripts/update-status.sh <story-id> "In Review"`

### Rules

- Only pick up stories with `status:ready` label
- Never work on a story assigned to someone else
- One story per feature branch, one PR per story
- If blocked, stop and document the blocker as a comment on the GitHub issue
- Do not set a story to "Ready" or "Done" — those transitions are human-only
- Do not modify files outside the assigned package without explicit story scope
- Do not add dependencies not on the approved list (see `docs/04-technical-specification.md` Section 6) without human approval
- Do not modify security-critical code without human review of the approach BEFORE implementation
- Do not modify any spec document in `docs/`
- Do not bypass linting rules with `// ignore` comments (except generated files)
