# Code Generation Plan — Unit 6: Spike 0.1 — Desktop Build Verification

## Unit Context

- **Unit**: Unit 6 — Spike 0.1: Desktop Build Verification
- **Branch**: `feature/phase0-spike-desktop-builds`
- **Target**: `packages/zip_captions/`, `packages/zip_broadcast/`, `docs/`
- **Dependencies**: Unit 3 (app shells must exist)
- **Type**: Research spike — scaffold platform dirs, attempt builds, document results

## Steps

- [x] Step 1: Create worktree and branch
- [x] Step 2: Scaffold platform directories for zip_captions (`flutter create --platforms=android,ios,macos,linux,windows .`)
- [x] Step 3: Scaffold platform directories for zip_broadcast (same)
- [x] Step 4: Attempt macOS build locally for both apps (`flutter build macos`) — BOTH PASS (36.0MB each)
- [x] Step 5: Generate `.github/workflows/build-verify.yml` — workflow_dispatch + PR trigger, builds on macos-latest (macOS + iOS), ubuntu-latest (Linux + Android), windows-latest (Windows) for zip_captions
- [x] Step 6: Document results and create `docs/PLATFORM_SETUP.md`
- [x] Step 7: Present for approval — APPROVED

## Notes

- macOS build tested locally; Linux, Windows, Android, iOS verified via GitHub Actions
- Platform scaffolding generates native project files (Gradle, Xcode, CMake) from Flutter templates
- Build failures are expected findings for a spike — the goal is to document what works and what needs fixing
- `flutter create .` in an existing project adds missing platform dirs without overwriting lib/
- `build-verify.yml` was deferred from Unit 5 — now added here with full platform matrix
