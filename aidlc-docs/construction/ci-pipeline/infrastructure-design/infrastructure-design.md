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
| Test | `melos run test` (with `--coverage`) | Run all package tests, collect coverage |
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
| Bootstrap | `melos bootstrap` | Resolve dependencies |
| Build APK | `flutter build apk --debug` | Verify Android build compiles |

**Runner**: `ubuntu-latest` (Android SDK available via `setup-java`)

**Scope**: `zip_captions` only (per unit-of-work scope). Additional platform build jobs (macOS, Windows, Linux) added in Unit 6.

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

### Lock File Verification

CI runs `dart pub get --enforce-lockfile` (via Melos bootstrap) for each package. Fails the build if lock file would change, forcing developers to commit updated lock files.

---

## Caching Strategy

| Cache | Key | Path | Restore Keys |
|---|---|---|---|
| pub-cache | `pub-cache-${{ runner.os }}-${{ hashFiles('**/pubspec.lock') }}` | `~/.pub-cache` | `pub-cache-${{ runner.os }}-` |

- Cache invalidates when any `pubspec.lock` changes
- Partial restore by OS prefix when exact key misses
- No Gradle cache needed (debug APK build is infrequent and fast enough)

---

## Melos Test Command

The `test` script is defined under the `melos:` key in the root `pubspec.yaml` (Melos 7.x convention):

```yaml
test:
  run: flutter test --coverage
  exec:
    concurrency: 1
  packageFilters:
    flutter: true
    dirExists: test
```

---

## Secrets and Permissions

- No secrets required (no deployment, no external services)
- Default `GITHUB_TOKEN` permissions sufficient (read-only for checkout)
- No write permissions needed (no PR comments, no deployments)

---

## Security Baseline Compliance

| Rule | Status | Implementation |
|---|---|---|
| SECURITY-10 (Supply Chain) | Compliant | Pinned Flutter SDK, pinned action versions (patch-level), lock file check |
| SECURITY-13 (Pipeline Access) | Compliant | Branch protection rules documented for main/develop; CI triggers scoped to PRs and protected branches only |

---

## Workflow Structure Summary

| Workflow | Trigger | Runner | Jobs |
|---|---|---|---|
| `ci.yml` | PR (all branches), push to main/develop | `ubuntu-latest` | analyze, test, pub outdated |
| `build-verify.yml` | PR to main/develop | `ubuntu-latest` | Android APK debug build (zip_captions), plus macOS/Windows/Linux builds (Unit 6) |
