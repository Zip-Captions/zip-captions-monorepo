# Infrastructure Design Plan — Unit 5: CI/CD Pipeline

## Context

Unit 5 creates GitHub Actions workflows for a Flutter/Dart monorepo. NFR Requirements are complete — pinned actions, pinned Flutter SDK, lock file verification, branch protection docs, pub outdated check, Android-only build verification.

The infrastructure design maps CI jobs to GitHub Actions runners, defines the job dependency graph, and specifies caching strategy.

## Steps

- [x] Step 1: Review NFR requirements and tech stack decisions
- [x] Step 2: Collect answers to questions below
- [x] Step 3: Generate infrastructure-design.md (job graph, runner specs, caching, secrets)
- [x] Step 4: Generate deployment-architecture.md (workflow trigger flow, branch protection setup)
- [x] Step 5: Present for approval — APPROVED

## Questions

**Q1: Melos activation** — Melos can be activated globally (`dart pub global activate melos`) or run via `dart run melos` from the workspace root. For CI:

- A) Global activate (`dart pub global activate melos`) — standard CI approach, adds to PATH
- B) Use `dart run melos` — no global install needed, uses workspace dependency

[Answer]: A

**Q2: Test coverage reporting** — Should CI collect and report test coverage?

- A) Collect coverage with `--coverage` flag, upload as artifact (no external service)
- B) Collect coverage and report to Codecov or similar
- C) Skip coverage in Phase 0 (add later)

[Answer]: A

**Q3: Concurrency control** — GitHub Actions can cancel in-progress runs when a new push arrives on the same branch/PR.

- A) Enable concurrency groups (cancel in-progress on same PR — saves minutes)
- B) No concurrency control (all runs complete, even if superseded)

[Answer]: A
