# Infrastructure Design — Unit 5: CI/CD Pipeline

## Overview

Two GitHub Actions workflows for a Melos-managed Flutter/Dart monorepo. All jobs run on `ubuntu-latest`. Concurrency groups cancel superseded runs. Coverage collected as artifact.

---

## Workflow 1: `ci.yml` — Analyze & Test

**Trigger**: `pull_request` (all branches), `push` to `main`/`develop`

**Concurrency**: Group by `ci-${{ github.ref }}`, cancel in-progress.

### Job Graph

```
┌──────────────┐
│   setup       │  Checkout, Flutter SDK, pub-cache restore, melos bootstrap
└──────┬───────┘
       │
  ┌────┴────┐
  │         │
  ▼         ▼
┌──────┐  ┌──────┐
│analyze│  │ test │  Run in parallel after setup
└──────┘  └──┬───┘
              │
              ▼
         ┌─────────┐
         │ coverage │  Upload lcov as artifact
         └─────────┘
```

**Note**: `analyze` and `test` can be parallel jobs that both depend on `setup`, or sequential steps within a single job. Single-job approach is simpler and avoids re-running Flutter setup twice.

**Recommended**: Single job with sequential steps (setup → analyze → test → coverage upload → pub outdated). Simpler, avoids duplicate Flutter/Melos setup, and the time savings from parallelism are minimal for Phase 0's small codebase.

### Job: `ci`

| Step | Command | Purpose |
|---|---|---|
| Checkout | `actions/checkout@v4.2.2` | Clone repository |
| Setup Flutter | `subosito/flutter-action@v2.18.0` | Install pinned Flutter SDK |
| Restore pub-cache | `actions/cache@v4.2.3` | Cache `~/.pub-cache` across runs |
| Activate Melos | `dart pub global activate melos` | Install Melos CLI |
| Bootstrap | `melos bootstrap` | Resolve all package dependencies |
| Analyze | `melos run analyze` | Lint all packages |
| Test | `melos run test` (with `--coverage`) | Run all package tests, collect coverage |
| Upload coverage | `actions/upload-artifact@v4.6.1` | Store lcov files as build artifact |
| Pub outdated | `dart pub outdated` | Report outdated dependencies (informational) |

### Action Versions (Pinned — SECURITY-10)

| Action | Version |
|---|---|
| `actions/checkout` | `v4.2.2` |
| `subosito/flutter-action` | `v2.18.0` |
| `actions/cache` | `v4.2.3` |
| `actions/upload-artifact` | `v4.6.1` |

**Note**: Exact versions will be verified against latest stable releases at code generation time.

---

## Workflow 2: `build-verify.yml` — Android Build

**Trigger**: `pull_request` to `main`/`develop` only

**Concurrency**: Group by `build-${{ github.ref }}`, cancel in-progress.

### Job: `build-android`

| Step | Command | Purpose |
|---|---|---|
| Checkout | `actions/checkout@v4.2.2` | Clone repository |
| Setup Java | `actions/setup-java@v4.6.0` | Install JDK for Android build |
| Setup Flutter | `subosito/flutter-action@v2.18.0` | Install pinned Flutter SDK |
| Restore pub-cache | `actions/cache@v4.2.3` | Cache pub dependencies |
| Bootstrap | `melos bootstrap` | Resolve dependencies |
| Build APK | `flutter build apk --debug` | Verify Android build compiles |

**Runner**: `ubuntu-latest` (Android SDK available via `setup-java`)

**Scope**: `zip_captions` only (per unit-of-work scope).

---

## Caching Strategy

| Cache | Key | Path | Restore Keys |
|---|---|---|---|
| pub-cache | `pub-cache-${{ runner.os }}-${{ hashFiles('**/pubspec.lock') }}` | `~/.pub-cache` | `pub-cache-${{ runner.os }}-` |

- Cache invalidates when any `pubspec.lock` changes
- Partial restore by OS prefix when exact key misses
- No Gradle cache needed (debug APK build is infrequent and fast enough)

---

## Flutter SDK Version

**Decision**: Pin to latest stable Flutter SDK as of March 2026. The exact version will be determined at code generation time by checking https://docs.flutter.dev/release/archive.

Defined as an `env` variable at workflow level so all steps reference the same version:
```yaml
env:
  FLUTTER_VERSION: "3.29.2"  # determined at generation time
```

---

## Melos Test Command

The existing `melos.yaml` defines `test` script. For coverage, the command needs `--coverage`:

```yaml
test:
  run: flutter test --coverage
  exec:
    concurrency: 1
  packageFilters:
    flutter: true
    dirExists: test
```

If the current melos config doesn't include `--coverage`, it will be updated during code generation.

---

## Secrets and Permissions

- No secrets required (no deployment, no external services)
- Default `GITHUB_TOKEN` permissions sufficient (read-only for checkout)
- No write permissions needed (no PR comments, no deployments)
