# Units of Work — Zip Captions v2, Phase 0

## Overview

Phase 0 decomposes into 6 units of work. Each unit is developed in an isolated git worktree, produces one PR targeting `develop`, and is self-contained within the scope listed below.

---

## Unit 1: Monorepo Scaffold

**Branch**: `feature/phase0-monorepo-scaffold`
**Worktree**: `.worktrees/monorepo-scaffold`

### Scope
- Root `melos.yaml` with `bootstrap`, `test`, `analyze`, `format` scripts
- Root `pubspec.yaml` configured as a Pub Workspace listing all 4 packages
- Package directory stubs: `packages/zip_core/`, `packages/zip_captions/`, `packages/zip_broadcast/`, `packages/zip_supabase/`
- Each package gets: `pubspec.yaml` (correct name, description, dependencies), `analysis_options.yaml` (`very_good_analysis`), empty `lib/` and `test/` directory structure
- `.gitignore` additions for Dart/Flutter build artifacts
- Root `README.md` updated with monorepo setup instructions (how to run `melos bootstrap`)

### Out of Scope
- Any Dart source code (providers, models, screens)
- CI/CD configuration
- Docker/Supabase configuration

### Construction Stages
| Stage | Decision |
|---|---|
| Functional Design | SKIP — no business logic |
| NFR Requirements | SKIP — code quality enforced by `very_good_analysis` in pubspec; no additional NFRs |
| NFR Design | SKIP |
| Infrastructure Design | SKIP |
| Code Generation | EXECUTE |

### Worktree Commands
```bash
git worktree add .worktrees/monorepo-scaffold -b feature/phase0-monorepo-scaffold
cd .worktrees/monorepo-scaffold
# ... develop ...
# PR targeting develop
git worktree remove .worktrees/monorepo-scaffold
git branch -d feature/phase0-monorepo-scaffold
```

### Exit Criteria
- `melos bootstrap` succeeds
- `dart analyze` passes on all packages (empty packages, no warnings)
- All 4 package directories exist with correct `pubspec.yaml` and linting config

---

## Unit 2: zip_core Library

**Branch**: `feature/phase0-zip-core`
**Worktree**: `.worktrees/zip-core`
**Depends on**: Unit 1 merged to `develop`

### Scope
- `LocaleProvider` (full implementation, SharedPreferences persistence)
- `LocaleInfoProvider` (stub returning empty list)
- `BaseSettingsNotifier` (abstract, full implementation — scroll direction, text size, font family, contrast mode, max visible lines; SharedPreferences persistence)
- `RecordingStateNotifier` (state machine — idle/recording/paused/stopped — stub; no STT wiring)
- `sttEngineProvider` (stub, throws `UnimplementedError`)
- `SttEngine` abstract interface (method signatures only)
- `AppSettings` (freezed data class)
- `RecordingState` (sealed class)
- `SpeechLocale` (freezed data class)
- `AppTheme` (Material 3 light + dark `ThemeData` factory)
- `zip_core.dart` barrel export
- `glados` dev dependency (PBT-09)
- ARB files: `app_en.arb` with Phase 0 shared string keys; non-English ARBs (ar, de, es, fr, id, it, pl, pt, uk) imported and converted from v1 JSON, tagged `machine-generated`
- `l10n.yaml` configured for zip_core
- Unit tests for all implemented components

### Out of Scope
- `ZipCaptionsSettingsNotifier` / `ZipBroadcastSettingsNotifier` (live in their respective app packages — Unit 3)
- App-specific ARB files
- Actual STT engine implementation (Phase 1)
- Caption bus (Phase 1)

### Construction Stages
| Stage | Decision |
|---|---|
| Functional Design | EXECUTE — `RecordingStateNotifier` state machine and `BaseSettingsNotifier` persistence model need detailed design |
| NFR Requirements | EXECUTE — PBT framework selection (`glados`); provider test strategy; security: no transcript logging |
| NFR Design | EXECUTE — integrate PBT into provider tests; specify `glados` generators for `AppSettings` |
| Infrastructure Design | SKIP — no infrastructure services |
| Code Generation | EXECUTE |

### Worktree Commands
```bash
git worktree add .worktrees/zip-core -b feature/phase0-zip-core
cd .worktrees/zip-core
```

### Exit Criteria
- `melos run analyze` passes on `zip_core` (zero `very_good_analysis` warnings)
- `melos run test` passes on `zip_core`
- `dart pub publish --dry-run` passes (package is publish-ready, even though `publish_to: none`)
- No `provider` dependency anywhere in `zip_core`
- `glados` present in `zip_core` dev dependencies
- All non-English ARB files present and tagged `machine-generated`

---

## Unit 3: App Shells

**Branch**: `feature/phase0-app-shells`
**Worktree**: `.worktrees/app-shells`
**Depends on**: Unit 1 merged; Unit 2 merged

### Scope
- `packages/zip_captions/`: `main.dart`, `app.dart` (`ZipCaptionsApp` — `ConsumerWidget` with `ProviderScope`, `MaterialApp` using `AppTheme`, `ZipCaptionsLocalizations`), `HomeScreen` (hello-world), `ZipCaptionsSettingsNotifier`, `lib/l10n/app_en.arb` (app-specific strings: app name, placeholder labels)
- `packages/zip_broadcast/`: same structure — `ZipBroadcastApp`, `HomeScreen`, `ZipBroadcastSettingsNotifier`, `lib/l10n/app_en.arb`
- Both apps: `ProviderScope` at root, consume `zip_core` providers and theme
- Widget tests for both app shells

### Out of Scope
- Any actual UI beyond hello-world home screen
- Navigation beyond the home screen
- Platform-specific configuration (entitlements, `AndroidManifest.xml` changes beyond defaults)

### Construction Stages
| Stage | Decision |
|---|---|
| Functional Design | SKIP — hello-world shell; no business logic |
| NFR Requirements | SKIP — NFRs already established by Unit 2 |
| NFR Design | SKIP |
| Infrastructure Design | SKIP |
| Code Generation | EXECUTE |

### Worktree Commands
```bash
git worktree add .worktrees/app-shells -b feature/phase0-app-shells
cd .worktrees/app-shells
```

### Exit Criteria
- `flutter run` launches `zip_captions` on iOS simulator (shows home screen)
- `flutter run` launches `zip_broadcast` on macOS (shows home screen)
- `melos run test` passes for both app packages
- No `provider` dependency in either app package

---

## Unit 4: Supabase Local Dev

**Branch**: `feature/phase0-supabase-local-dev`
**Worktree**: `.worktrees/supabase`
**Depends on**: Unit 1 merged

### Scope
- `packages/zip_supabase/docker-compose.yml` — local Supabase stack (Postgres, GoTrue, Storage, Realtime, Edge Functions runtime); based on official Supabase self-hosted template
- `packages/zip_supabase/supabase/config.toml` — Supabase CLI config for local dev
- `packages/zip_supabase/migrations/20260326000000_initial.sql` — empty schema; `ALTER DATABASE postgres SET "app.settings.jwt_secret" TO '...';` placeholder; RLS-enabling statement
- `packages/zip_supabase/.env.example` — all required environment variable names with placeholder values and descriptions; `.env` gitignored
- `packages/zip_supabase/README.md` — local dev setup: prerequisites, `docker-compose up`, reset, seed, Flutter connection config
- No Dart code

### Out of Scope
- Any application database tables or schemas (Phase 1+)
- Edge Functions (Phase 2+)
- Seed data scripts (beyond documenting how to add them)

### Construction Stages
| Stage | Decision |
|---|---|
| Functional Design | SKIP — empty schema; no application logic |
| NFR Requirements | EXECUTE — SECURITY-09/12: no secrets committed; SECURITY-01: local Postgres TLS note; SECURITY-10: pinned Docker image versions |
| NFR Design | SKIP |
| Infrastructure Design | EXECUTE — Docker Compose service definitions, port mapping, volume mounts, health checks |
| Code Generation | EXECUTE |

### Worktree Commands
```bash
git worktree add .worktrees/supabase -b feature/phase0-supabase-local-dev
cd .worktrees/supabase
```

### Exit Criteria
- `docker-compose up` starts without errors
- Supabase Studio accessible at `http://localhost:54323` (or configured port)
- Postgres accepts connections on configured port
- No secrets or credentials present in any committed file
- All Docker image versions pinned (no `latest` tags)

---

## Unit 5: CI/CD Pipeline

**Branch**: `feature/phase0-ci-pipeline`
**Worktree**: `.worktrees/ci`
**Depends on**: Units 1, 2, 3, and 4 merged to `develop`

### Scope
- `.github/workflows/ci.yml` — triggered on PRs and pushes to `main`/`develop`; jobs: `analyze` (melos run analyze) and `test` (melos run test); Flutter SDK version pinned
- `.github/workflows/build-verify.yml` — iOS debug build (`flutter build ios --no-codesign`) and Android APK (`flutter build apk --debug`) for `zip_captions` only (both are mobile-first per Q4 in requirements)
- Branch protection documentation (instructions to configure required status checks in GitHub Settings → Branches for `main` and `develop`)
- `pubspec.lock` verification step in CI (fail if lock file is out of sync)
- Dependency vulnerability scan step (using `dart pub outdated --mode=null-safety` or `osv-scanner` if available)

### Out of Scope
- macOS/Windows/Linux build jobs (Spike 0.1 is local verification, not CI)
- Deployment or release workflows (Phase 6)
- Code signing configuration

### Construction Stages
| Stage | Decision |
|---|---|
| Functional Design | SKIP — no business logic |
| NFR Requirements | EXECUTE — SECURITY-10: pinned Flutter SDK, pinned action versions, lock file check; SECURITY-13: pipeline access control via branch protection |
| NFR Design | SKIP |
| Infrastructure Design | EXECUTE — GitHub Actions job graph, runner selection (`ubuntu-latest`, `macos-latest`), caching (`pub-cache`) |
| Code Generation | EXECUTE |

### Worktree Commands
```bash
git worktree add .worktrees/ci -b feature/phase0-ci-pipeline
cd .worktrees/ci
```

### Exit Criteria
- `analyze` and `test` jobs pass on a PR against `develop`
- iOS and Android builds complete without errors
- All GitHub Actions versions pinned (e.g., `actions/checkout@v4.2.2`, not `@v4`)
- Flutter SDK version pinned in workflow YAML
- `main` and `develop` branch protection rules documented (status checks: `analyze`, `test`)

---

## Unit 6: Spike 0.1 — Desktop Build Verification

**Branch**: `feature/phase0-spike-desktop-builds`
**Worktree**: `.worktrees/spike-desktop`
**Depends on**: Unit 3 merged (app shells must exist to build)

### Scope
- Manually run `flutter build macos`, `flutter build windows`, `flutter build linux` for both `zip_captions` and `zip_broadcast`
- Document results: success, failure, required platform setup, known issues
- Create `docs/PLATFORM_SETUP.md` with setup instructions for macOS, Windows, Linux development environments
- Log any blockers that would affect Phase 1 work on desktop

### Out of Scope
- Fixing platform build failures beyond what's needed for the hello-world shell
- Adding desktop platform CI jobs (deferred)

### Construction Stages
| Stage | Decision |
|---|---|
| Functional Design | SKIP — research spike |
| NFR Requirements | SKIP |
| NFR Design | SKIP |
| Infrastructure Design | SKIP |
| Code Generation | EXECUTE — produces `docs/PLATFORM_SETUP.md` |

### Worktree Commands
```bash
git worktree add .worktrees/spike-desktop -b feature/phase0-spike-desktop-builds
cd .worktrees/spike-desktop
```

### Exit Criteria
- Build result for each platform (macOS, Windows, Linux) documented for both apps
- `docs/PLATFORM_SETUP.md` created with prerequisites per platform
- Any build blockers logged as GitHub Issues for follow-up

---

## Code Organization Strategy (Greenfield)

All application code lives in the workspace root under `packages/`. Documentation and AI-DLC artifacts live in `aidlc-docs/`. No application code in `aidlc-docs/`.

```
zip-captions-monorepo/         ← workspace root
  packages/
    zip_core/lib/src/          ← all Dart source in src/; barrel export at lib/zip_core.dart
    zip_captions/lib/          ← Flutter app source
    zip_broadcast/lib/         ← Flutter app source
    zip_supabase/              ← infrastructure only (no lib/)
  .github/workflows/           ← CI/CD
  docs/                        ← project specification documents
  aidlc-docs/                  ← AI-DLC documentation (never application code)
```
