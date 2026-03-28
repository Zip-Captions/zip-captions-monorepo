# NFR Requirements — Unit 5: CI/CD Pipeline

## NFR Summary

Unit 5 is a CI/CD infrastructure unit (GitHub Actions workflows, branch protection docs). No Dart code.

---

## NFR-U5-01: Pinned GitHub Actions Versions (SECURITY-10)

**Requirement**: All GitHub Actions use fully pinned version tags. No major-only tags like `@v4`.

**Implementation**:
- All `uses:` directives pin to specific patch versions (e.g., `actions/checkout@v4.2.2`, not `@v4`)
- Documented upgrade procedure for action versions
- Dependabot or manual review for action version updates

**Verification**: `grep 'uses:' .github/workflows/*.yml | grep -v '@v[0-9]\+\.[0-9]\+\.[0-9]\+'` must return zero matches.

---

## NFR-U5-02: Pinned Flutter SDK Version (SECURITY-10)

**Requirement**: Flutter SDK version pinned in all workflow files. No `stable` channel without version pin.

**Implementation**:
- Use `subosito/flutter-action` with explicit `flutter-version` parameter
- Version set to latest stable Flutter SDK as of March 2026
- All workflow files reference the same version (defined as workflow-level env var or input)

**Verification**: All `flutter-version` values in workflow YAML match the pinned version.

---

## NFR-U5-03: Lock File Verification (SECURITY-10)

**Requirement**: CI verifies that `pubspec.lock` files are in sync with `pubspec.yaml`.

**Implementation**:
- CI step runs `dart pub get --enforce-lockfile` (or equivalent) for each package
- Fails the build if lock file would change (forces developers to commit updated lock files)

**Verification**: CI job fails when a `pubspec.yaml` change is pushed without the corresponding `pubspec.lock` update.

---

## NFR-U5-04: Branch Protection (SECURITY-13)

**Requirement**: `main` and `develop` branches require passing CI checks before merge.

**Implementation**:
- Documentation for configuring GitHub branch protection rules
- Required status checks: `analyze`, `test`
- Require PR reviews before merging (documented, not enforced by CI)
- No direct pushes to `main` or `develop`

**Verification**: Documentation covers all required settings. Actual enforcement is configured manually in GitHub Settings.

---

## NFR-U5-05: Dependency Outdated Check

**Requirement**: CI reports outdated dependencies to catch stale or vulnerable packages.

**Implementation**:
- `dart pub outdated` step in CI workflow
- Advisory/informational — does not fail the build (packages may be intentionally held back)
- Output visible in CI job logs for developer review

---

## NFR-U5-06: CI Trigger Scope

**Requirement**: Workflows trigger on PRs and pushes to protected branches only.

**Implementation**:
- `ci.yml`: triggers on `pull_request` (all branches) and `push` to `main`/`develop`
- `build-verify.yml`: triggers on `pull_request` to `main`/`develop` only (build verification for merge candidates)
- No triggers on arbitrary branch pushes (saves CI minutes)

---

## NFR-U5-07: Build Verification Scope

**Requirement**: Android debug build verified in CI. iOS builds deferred to local verification (Spike 0.1).

**Implementation**:
- `build-verify.yml` runs Android APK debug build (`flutter build apk --debug`) for `zip_captions` on `ubuntu-latest`
- iOS build skipped in CI (requires macOS runner, higher cost; verified locally during Unit 6)
- Documented decision to add iOS CI builds in a future phase

---

## Security Baseline Compliance

| Rule | Status | Notes |
|---|---|---|
| SECURITY-10 (Supply Chain) | Compliant | Pinned Flutter SDK, pinned action versions, lock file check |
| SECURITY-13 (Pipeline Access) | Compliant | Branch protection rules documented for main/develop |
