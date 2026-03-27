# Phase 0 — Foundation: Requirements Document

## Intent Analysis

| Field | Value |
|---|---|
| User Request | Initiate Phase 0 (Foundation) for Zip Captions v2 |
| Request Type | New Project (code-greenfield, documentation-brownfield) |
| Scope Estimate | System-wide — monorepo scaffold, multiple packages, CI/CD, tooling |
| Complexity Estimate | Comprehensive — multi-package Flutter monorepo, CI/CD, Supabase local dev, localization, PoC migration |

---

## Source Material

Requirements are derived from:
- `docs/03-roadmap.md` — Phase 0 deliverables and exit criteria (authoritative)
- `docs/04-technical-specification.md` — coding standards, package structure, approved dependencies
- `docs/02-architecture-decisions.md` — ADR-003 (Riverpod), ADR-004 (Supabase), ADR-010 (monorepo), ADR-014 (l10n)
- `AGENTS.md` — in-scope and out-of-scope constraints for Phase 0
- User answers to `requirement-verification-questions.md`

---

## Context: Existing Codebases

### Flutter PoC (`<local-poc-path>`)
- Flutter app using `provider` package (not Riverpod) for state management
- Providers to migrate: `locale_provider`, `recording_provider`, `locale_info_provider`, `settings_provider`
- Services: `speech_recognition_service`, `platform_speech_service`, `speech_service_manager`
- Localization: Flutter l10n with en, es, fr ARB-generated files
- Dependency: `speech_to_text: ^7.3.0`, `shared_preferences: ^2.2.2`

### v1 PWA Monorepo (`<local-v1-path>`)
- NX monorepo (TypeScript / Angular)
- Translation files at `packages/client/src/assets/i18n/` — JSON format
- Languages available: ar, de, en, es, fr, id, it, pl, pt, uk, zh

---

## Functional Requirements

### FR-01: Monorepo Scaffold

**FR-01.1** — Initialize `zip-captions-monorepo/` with Pub Workspaces + Melos.

**FR-01.2** — Create `packages/zip_core/` as an empty Dart shared library with:
- `pubspec.yaml` configured for package dependencies
- Test scaffold (empty test file, correct directory structure)
- `very_good_analysis` linting configured (`analysis_options.yaml`)
- `build_runner` and `riverpod_generator` configured

**FR-01.3** — Create `packages/zip_captions/` as a Flutter app shell targeting:
- iOS, Android, macOS, Windows, Linux, web
- Hello-world level UI (app launches and displays placeholder content)
- Riverpod `ProviderScope` at app root

**FR-01.4** — Create `packages/zip_broadcast/` as a Flutter app shell targeting:
- macOS, Windows, Linux, web
- Hello-world level UI (app launches and displays placeholder content)
- Riverpod `ProviderScope` at app root

**FR-01.5** — Create `packages/zip_supabase/` as a Supabase project scaffold (see FR-04).

**FR-01.6** — Configure `melos.yaml` with the following scripts:
- `bootstrap` — `melos bootstrap` (pub get for all packages)
- `test` — run tests across all packages with per-package isolation
- `analyze` — `flutter analyze` / `dart analyze` across all packages
- `format` — `dart format` across all packages

---

### FR-02: Riverpod Migration

**FR-02.1** — Add `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, and `build_runner` to all applicable packages. Remove `provider` dependency from all packages.

**FR-02.2** — Migrate the following PoC providers from `provider` to `riverpod_generator`-based Riverpod providers, placed in `zip_core`:
- `locale_provider` → `LocaleProvider` (Riverpod notifier, manages selected locale)
- `locale_info_provider` → `LocaleInfoProvider` (Riverpod provider, exposes available locales)
- `settings_provider` → `SettingsProvider` (Riverpod notifier, manages display settings: text size, font, contrast, flow direction)
- `recording_provider` → `RecordingStateProvider` (Riverpod notifier stub — state machine for recording lifecycle: idle/recording/paused/stopped; STT integration deferred to Phase 1)

**FR-02.3** — Create stub providers for core Phase 1 domain objects in `zip_core`:
- `SttEngineProvider` — stub `AsyncNotifierProvider` that returns a `NotImplementedException`; concrete implementation is Phase 1
- Interface placeholder for the caption bus (Phase 1 implementation deferred)

**FR-02.4** — Document Riverpod patterns and conventions in a `RIVERPOD_CONVENTIONS.md` file within `zip_core`.

**FR-02.5** — Migrate `settings_provider` storage from `shared_preferences` to a Riverpod-compatible pattern with `shared_preferences` as the backing store. `shared_preferences` remains an approved dependency.

---

### FR-03: CI/CD Pipeline (GitHub Actions)

**FR-03.1** — Create a GitHub Actions workflow that runs on every pull request and push to `main` and `develop`:
- `dart analyze` / `flutter analyze` across all packages via Melos
- `melos run test` — unit tests across all packages
- Steps run in dependency order (bootstrap → analyze → test)

**FR-03.2** — Build verification targets for Phase 0 CI:
- iOS: `flutter build ios --no-codesign` (simulator build check)
- Android: `flutter build apk --debug` (APK compile check)
- macOS, Windows, Linux, web builds are deferred to local Spike 0.1 verification (not in CI for Phase 0)

**FR-03.3** — Branch protection rules for `main`:
- Require PR before merging
- Require `analyze` and `test` CI checks to pass
- No force pushes to `main` or `develop`

**FR-03.4** — After workflows are created and confirmed passing: add `analyze` and `test` as required status checks in the GitHub branch rulesets for both `main` and `develop` (Settings > Branches / Rules).

**FR-03.5** — CI must use pinned tool versions (specific Flutter SDK version, not `latest`). Lock file (`pubspec.lock`) must be committed to the repository.

---

### FR-04: Supabase Local Development

**FR-04.1** — Create a Docker Compose configuration for the local Supabase stack in `packages/zip_supabase/`:
- Services: Postgres, GoTrue (auth), Storage, Realtime, Edge Functions runtime
- Based on Supabase's official self-hosted Docker Compose template

**FR-04.2** — Create an initial database migration:
- Empty schema (no application tables yet)
- RLS enabled at the database level
- Migration file named following Supabase's sequential timestamp convention

**FR-04.3** — No credentials or secrets committed to the repository. Use `.env` files (gitignored) with `.env.example` templates for all secrets.

**FR-04.4** — Create `packages/zip_supabase/README.md` (or equivalent) documenting:
- How to start the local stack (`docker-compose up`)
- How to seed test data
- How to reset the database
- How to connect from Flutter apps during local development

---

### FR-05: Localization Scaffold

**FR-05.1** — Configure Flutter l10n in `zip_core` with ARB files:
- `l10n.yaml` at the `zip_core` package root
- ARB source directory: `lib/l10n/`
- English (en) as the source language

**FR-05.2** — Import and convert v1 translation files from `<local-v1-assets-path>` (JSON format) to Flutter ARB format for the following languages: ar, de, es, fr, id, it, pl, pt, uk.
- zh is also available but should not be included. the quality of the source file is too low.
- All imported translations are marked with quality tier metadata: `machine-generated` in a comment or metadata field within each ARB file

**FR-05.3** — Identify the ARB string keys needed for Phase 0 app shells (app title, placeholder text) and seed the English ARB with those keys. Non-English ARBs carry forward only the keys that exist in v1; new Phase 0 keys default to the English string.

**FR-05.4** — Both `zip_captions` and `zip_broadcast` apps consume the shared `zip_core` l10n.

---

### FR-06: Research Spike 0.1 — Desktop Build Verification

**FR-06.1** — Verify that `flutter build` succeeds for both `zip_captions` and `zip_broadcast` on:
- macOS (macOS desktop target)
- Windows (Windows desktop target)
- Linux (Linux desktop target)

**FR-06.2** — Document any platform-specific setup requirements discovered (Xcode version, Visual Studio Build Tools, Linux development packages, etc.) in `docs/PLATFORM_SETUP.md` or equivalent.

**FR-06.3** — Identify and document any known build failures or platform-specific limitations that need resolution before Phase 1.

---

### FR-07: Agentic Development Framework (Verify/Complete)

**FR-07.1** — Verify `ai-dlc` is properly configured as a git submodule.

**FR-07.2** — Confirm `.aidlc-rule-details/` directory is present and populated with the rule detail files from the submodule (or a symlink/copy mechanism that works with the tooling).

**FR-07.3** — Verify per-package `AGENTS.md` files exist in all four packages.

---

## Non-Functional Requirements

### NFR-01: Code Quality

**NFR-01.1** — All Dart/Flutter packages must pass `very_good_analysis` with zero warnings.

**NFR-01.2** — No `// ignore` lint suppression directives in hand-written code (only in generated files).

**NFR-01.3** — All imports use package imports (`package:zip_core/...`), never relative imports across packages.

**NFR-01.4** — File naming: `snake_case`. Class naming: `PascalCase`. Variable naming: `camelCase`.

### NFR-02: Testing

**NFR-02.1** — Every package has a `test/` directory with at least one passing test (scaffold test confirming the test runner works).

**NFR-02.2** — TDD workflow is established per `docs/TDD.md`: failing tests are written before implementation in all Construction Phase work.

**NFR-02.3** — A Dart property-based testing framework must be selected and added as a dev dependency in `zip_core`. Recommended: `glados` (supports custom generators, shrinking, seed-based reproducibility). This is required to comply with PBT-09. PBT tests themselves are N/A for Phase 0 scaffolding but the framework must be present.

### NFR-03: Security

**NFR-03.1** — No credentials, API keys, or secrets committed to the repository. Supabase local dev secrets use `.env` files with `.env.example` templates (SECURITY-09, SECURITY-12).

**NFR-03.2** — All dependencies pinned via lock files (`pubspec.lock` committed). Dependency vulnerability scanning step included in CI (SECURITY-10).

**NFR-03.3** — CI/CD pipeline definitions (GitHub Actions YAML) are access-controlled via repository permissions. Branch protection ensures pipeline changes go through PR review (SECURITY-13).

**NFR-03.4** — Transcript content must NEVER appear in logs, debug output, crash reports, or analytics. This constraint is established as an architectural pattern in Phase 0 — logging infrastructure must be designed to exclude payload content from day one (SECURITY-03, AGENTS.md absolute constraint).

**NFR-03.5** — No default Supabase credentials used in any committed configuration file. Service role keys and JWT secrets must not appear in source code (SECURITY-09, SECURITY-12).

### NFR-04: Commit and Branch Conventions

**NFR-04.1** — Conventional Commits format for all commits. Scope with package name: `feat(zip_core): ...`, `chore(ci): ...`.

**NFR-04.2** — All work developed in git worktrees (one per unit), one PR per worktree targeting `develop`.

---

## Phase 0 Exit Criteria

From `docs/03-roadmap.md`:

1. `melos bootstrap` succeeds
2. `melos run test` passes for all packages
3. Both apps launch on at least one platform each (Zip Captions on iOS simulator, Zip Broadcast on macOS)
4. CI workflows pass on a PR and `analyze` + `test` are added as required status checks in `main` and `develop` branch rulesets
5. Supabase local stack starts and accepts connections
6. Riverpod is the sole state management solution — no remaining `provider` dependency

---

## Out of Scope for Phase 0

Per `AGENTS.md`:
- STT engine implementation (Phase 1)
- Caption bus (Phase 1)
- Any UI beyond hello-world app shells
- Broadcasting, transport, auth, encryption (Phases 2–3)
- Entitlements, BLE, translation (Phases 4–5, 8)
- Research Spikes 0.2 (VPS provider) and 0.3 (STT survey) — deferred

---

## Security Compliance Summary (Requirements Stage)

| Rule | Status | Notes |
|---|---|---|
| SECURITY-01 (Encryption at Rest/Transit) | N/A | No data stores defined yet; will apply to Supabase Docker config in construction |
| SECURITY-02 (Access Logging) | N/A | No network intermediaries in Phase 0 scope |
| SECURITY-03 (Application Logging) | Captured as NFR-03.4 | Transcript-exclusion pattern must be established from day one |
| SECURITY-04 (HTTP Headers) | N/A | No web server in Phase 0 |
| SECURITY-05 (Input Validation) | N/A | No API endpoints in Phase 0 |
| SECURITY-06 (Least Privilege) | N/A | No IAM policies in Phase 0 |
| SECURITY-07 (Network Config) | N/A | Local dev only; no production network |
| SECURITY-08 (App Access Control) | N/A | No auth in Phase 0 |
| SECURITY-09 (Hardening) | Compliant | NFR-03.1, NFR-03.5 require no default credentials in committed files |
| SECURITY-10 (Supply Chain) | Compliant | NFR-03.2 requires pinned lock files and vulnerability scanning in CI |
| SECURITY-11 (Secure Design) | N/A | No security-critical modules implemented in Phase 0 |
| SECURITY-12 (Auth & Credentials) | Compliant | NFR-03.1 prohibits hardcoded credentials; no auth flow in Phase 0 |
| SECURITY-13 (Integrity) | Compliant | NFR-03.3 requires CI pipeline access control via branch protection |
| SECURITY-14 (Alerting & Monitoring) | N/A | No production deployment in Phase 0 |
| SECURITY-15 (Exception Handling) | N/A | No production code logic in Phase 0 scaffolding |

---

## PBT Compliance Summary (Requirements Stage)

| Rule | Status | Notes |
|---|---|---|
| PBT-01 (Property Identification) | N/A | No business logic in Phase 0; will apply in Construction Phase per unit |
| PBT-02 through PBT-08 | N/A | No testable business logic in Phase 0 scaffolding |
| PBT-09 (Framework Selection) | Captured as NFR-02.3 | `glados` selected for Dart; must be added as dev dependency |
| PBT-10 (Complementary Testing) | N/A | No complex logic in Phase 0; will apply in Construction Phase |
