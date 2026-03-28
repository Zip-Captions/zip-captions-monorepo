# Infrastructure Design — Unit 5: CI/CD Pipeline

## Overview

Two GitHub Actions workflows for a Melos-managed Flutter/Dart monorepo. All jobs run on `ubuntu-latest`. Concurrency groups cancel superseded runs. Coverage collected as artifact.

## Tech Stack

| Tool | Role | Decision Rationale |
|---|---|---|
| GitHub Actions | CI platform | Native GitHub integration, no external service, free tier sufficient |
| `ubuntu-latest` | CI runner | Fastest and cheapest; no macOS runner in Phase 0 (iOS builds verified locally in Unit 6) |
| `subosito/flutter-action` | Flutter SDK setup | Most widely used Flutter setup action; supports version pinning and caching |
| `actions/cache` | Pub-cache caching | Reduces `dart pub get` / `flutter pub get` time on subsequent runs |
| Melos | Monorepo orchestration | Already configured in Unit 1; `melos run analyze` and `melos run test` execute across all packages in dependency order |
| `dart pub outdated` | Dependency scanning | Lightweight check for stale dependencies; full CVE scanning (`osv-scanner`) deferred to a later phase |

---

## Workflow 1: `ci.yml` — Analyze & Test

**Trigger**: `pull_request` (all branches), `push` to `main`/`develop`

**Concurrency**: Group by `ci-${{ github.ref }}`, cancel in-progress.

### Job: `ci` (single sequential job)

| Step | Command | Purpose |
|---|---|---|
| Checkout | `actions/checkout@v6.0.2` | Clone repository |
| Setup Flutter | `subosito/flutter-action@v2.23.0` | Install pinned Flutter SDK |
| Restore pub-cache | `actions/cache@v5.0.4` | Cache `~/.pub-cache` across runs |
| Activate Melos | `dart pub global activate melos` | Install Melos CLI |
| Bootstrap | `melos bootstrap` | Resolve all package dependencies |
| Analyze | `melos run analyze` | Lint all packages |
| Test | `melos run test:coverage --no-select` | Run all package tests, collect coverage |
| Upload coverage | `actions/upload-artifact@v7.0.0` | Store lcov files as build artifact |
| Pub outdated | `dart pub outdated` | Report outdated dependencies (informational) |

Single-job approach chosen over parallel jobs: simpler, avoids duplicate Flutter/Melos setup, and the time savings from parallelism are minimal for Phase 0's small codebase.

---

## Workflow 2: `build-verify.yml` — Platform Builds

**Trigger**: `pull_request` to `main`/`develop` only

**Concurrency**: Group by `build-${{ github.ref }}`, cancel in-progress.

### Job: `build-android`

| Step | Command | Purpose |
|---|---|---|
| Checkout | `actions/checkout@v6.0.2` | Clone repository |
| Setup Java | `actions/setup-java@v5.2.0` | Install JDK for Android build |
| Setup Flutter | `subosito/flutter-action@v2.23.0` | Install pinned Flutter SDK |
| Restore pub-cache | `actions/cache@v5.0.4` | Cache pub dependencies |
| Get dependencies | `flutter pub get` | Resolve dependencies for `zip_captions` |
| Build APK | `flutter build apk --debug` | Verify Android build compiles |

**Runner**: `ubuntu-latest` (Android SDK available via `setup-java`)

**Scope**: `zip_captions` only. Build jobs use `flutter pub get` with `working-directory` instead of `melos bootstrap` since each job builds a single package.

### Additional platform jobs (Unit 6)

`build-verify.yml` also includes `build-ios`, `build-macos`, `build-linux`, and `build-windows` jobs targeting `zip_captions`. Each follows the same pattern (checkout, setup Flutter, pub get, build) with platform-specific runners and build commands.

---

## Pinned Versions (SECURITY-10)

### Action Versions

| Action | Version |
|---|---|
| `actions/checkout` | `v6.0.2` |
| `subosito/flutter-action` | `v2.23.0` |
| `actions/cache` | `v5.0.4` |
| `actions/upload-artifact` | `v7.0.0` |
| `actions/setup-java` | `v5.2.0` |

All `uses:` directives pin to specific patch versions (no major-only tags like `@v4`).

### Flutter SDK Version

Pinned to `3.38.7` (latest stable as of March 2026). Defined as a workflow-level `env` variable so all steps reference the same version:

```yaml
env:
  FLUTTER_VERSION: "3.38.7"
```

### Lock File Handling

CI runs `melos bootstrap` which invokes `dart pub get` for each package. Lock files (`pubspec.lock`) are committed to version control. The `--enforce-lockfile` flag is not currently enabled; adding it is a future hardening step.

---

## Caching Strategy

| Cache | Key | Path | Restore Keys |
|---|---|---|---|
| pub-cache | `pub-cache-${{ runner.os }}-${{ hashFiles('**/pubspec.lock') }}` | `~/.pub-cache` | `pub-cache-${{ runner.os }}-` |

- Cache invalidates when any `pubspec.lock` changes
- Partial restore by OS prefix when exact key misses
- No Gradle cache needed (debug APK build is infrequent and fast enough)

---

## Melos Test Scripts

Defined under the `melos:` key in the root `pubspec.yaml` (Melos 7.x convention):

```yaml
test:
  run: melos exec --fail-fast -- flutter test
  description: Run all tests across packages that have a test directory
  packageFilters:
    dirExists: test

test:coverage:
  run: melos exec --fail-fast -- flutter test --coverage
  description: Run all tests with coverage collection (used by CI)
```

CI uses `melos run test:coverage --no-select` (the `--no-select` flag prevents interactive package selection prompts).

---

## Secrets and Permissions

- No secrets required (no deployment, no external services)
- No explicit `permissions:` block set in workflows; relies on repository/org default `GITHUB_TOKEN` permissions. Consider adding explicit `permissions: { contents: read }` as a hardening step.
- No write permissions needed (no PR comments, no deployments)

---

## Security Baseline Compliance

| Rule | Status | Implementation |
|---|---|---|
| SECURITY-10 (Supply Chain) | Compliant | Pinned Flutter SDK, pinned action versions (patch-level), lock files committed to version control |
| SECURITY-13 (Pipeline Access) | Compliant | Branch protection rules documented for main/develop; `ci.yml` triggers on PRs (all branches) and push to main/develop; `build-verify.yml` triggers on PRs to main/develop only |

---

## Workflow Structure Summary

| Workflow | Trigger | Runner | Jobs |
|---|---|---|---|
| `ci.yml` | PR (all branches), push to main/develop | `ubuntu-latest` | analyze, test, pub outdated |
| `build-verify.yml` | PR to main/develop | `ubuntu-latest`, `macos-latest`, `windows-latest` | Android, iOS, macOS, Linux, Windows builds (zip_captions) |
