# Code Generation Plan — Unit 5: CI/CD Pipeline

## Unit Context

- **Unit**: Unit 5 — CI/CD Pipeline
- **Branch**: `feature/phase0-ci-pipeline`
- **Target**: `.github/workflows/` and `docs/`
- **Dependencies**: Units 1-4 (monorepo scaffold, zip_core, app shells, supabase)
- **Type**: Infrastructure only — no Dart code, no business logic

## Design Artifacts

- NFR Requirements: `aidlc-docs/construction/ci-pipeline/nfr-requirements/`
- Infrastructure Design: `aidlc-docs/construction/ci-pipeline/infrastructure-design/`

## Steps

- [x] Step 1: Create worktree and branch
- [x] Step 2: Generate `.github/workflows/ci.yml` — analyze + test + coverage upload + pub outdated, pinned Flutter 3.38.7, pinned action versions, concurrency groups
- [x] ~~Step 3: Generate `.github/workflows/build-verify.yml`~~ — REMOVED: app shells lack android/ scaffolding; deferred until platform builds are set up
- [x] Step 4: Update `pubspec.yaml` — add melos scripts including `test:coverage` (melos 7.x reads scripts from pubspec.yaml, not melos.yaml)
- [x] Step 5: Generate `docs/BRANCH_PROTECTION.md` — setup instructions for main/develop branch protection rules
- [x] Step 6: Validate NFR compliance (all actions pinned to patch versions, Flutter SDK pinned, concurrency groups set)
- [x] Step 7: Present for approval — APPROVED

## File Summary

| File | Purpose |
|---|---|
| `.github/workflows/ci.yml` | Analyze, test, coverage, pub outdated |
| `.github/workflows/build-verify.yml` | Android APK debug build verification |
| `pubspec.yaml` | Melos scripts including test:coverage (melos 7.x) |
| `docs/BRANCH_PROTECTION.md` | Branch protection setup documentation |

## Pinned Versions

| Component | Version |
|---|---|
| Flutter SDK | `3.38.7` (matches local dev) |
| `actions/checkout` | `v4.3.1` |
| `actions/cache` | `v4.3.0` |
| `actions/upload-artifact` | `v4.6.2` |
| `actions/setup-java` | `v4.8.0` |
| `subosito/flutter-action` | `v2.23.0` |

## Notes

- No Dart code generated (CI infrastructure only)
- No unit tests (workflow validation happens during Build and Test phase by running a PR)
- Single-job approach for ci.yml (simpler than parallel jobs for small codebase)
- iOS build skipped per Q2:C decision
