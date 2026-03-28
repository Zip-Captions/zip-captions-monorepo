# NFR Requirements Plan — Unit 5: CI/CD Pipeline

## Context

Unit 5 creates GitHub Actions workflows: `ci.yml` (analyze + test on PRs) and `build-verify.yml` (iOS/Android debug builds). Plus branch protection documentation. No Dart code. No business logic (Functional Design was SKIP).

The security requirements are pre-identified from inception:
- **SECURITY-10**: Pinned Flutter SDK version, pinned GitHub Actions versions (no `@v4` — must use `@v4.x.x`), lock file verification
- **SECURITY-13**: Pipeline access control via branch protection rules for `main` and `develop`

## Steps

- [x] Step 1: Review Unit 5 scope from unit-of-work.md
- [x] Step 2: Assess NFR categories for applicability
- [x] Step 3: Collect answers to questions below
- [x] Step 4: Generate NFR requirements artifact
- [x] Step 5: Generate tech stack decisions artifact
- [x] Step 6: Present for approval — APPROVED

## Questions

**Q1: Flutter SDK version** — Which Flutter SDK version should be pinned in CI workflows?

- A) Use the latest stable Flutter SDK as of March 2026 (I'll determine the specific version)
- B) Use a specific version you have in mind

[Answer]: A

**Q2: GitHub Actions runner for iOS builds** — iOS builds require macOS. GitHub-hosted `macos-latest` runners are available but cost more minutes than `ubuntu-latest`.

- A) Use `macos-latest` for iOS builds (standard, higher cost per minute)
- B) Use `macos-13` or another specific pinned macOS version
- C) Skip iOS builds in CI for now (run locally only during Spike 0.1)

[Answer]: C

**Q3: Dependency vulnerability scanning** — The unit scope mentions `osv-scanner` or `dart pub outdated`. For Phase 0:

- A) Include `osv-scanner` as a CI step (Google's open-source vulnerability scanner, checks against OSV database)
- B) Use `dart pub outdated` only (lighter, checks for outdated packages but not CVEs)
- C) Skip vulnerability scanning for Phase 0 (add in a later phase)

[Answer]: B

**Q4: CI trigger scope** — The workflows trigger on PRs and pushes to `main`/`develop`. Should they also run on push to feature branches?

- A) PRs + pushes to `main`/`develop` only (standard — PRs cover feature branch validation)
- B) Also trigger on push to any branch (catches issues before PR creation, but uses more CI minutes)

[Answer]: A
