# Unit 1: Monorepo Scaffold — Code Generation Plan

## Unit Context

**Branch**: `feature/phase0-monorepo-scaffold`
**Worktree**: `.worktrees/monorepo-scaffold`
**Workspace root**: `<workspace-root>`
**Application code target**: workspace root (all files go here, never in `aidlc-docs/`)

**Dependencies**: none (Unit 1 is the root of the dependency graph)

**Requirements implemented by this unit**:
- FR-01.1 Pub Workspaces + Melos root configuration
- FR-01.2 `zip_core` package stub (pubspec, analysis_options — code added in Unit 2)
- FR-01.6 `melos.yaml` scripts (bootstrap, test, analyze, format)
- FR-03.5 `pubspec.lock` committed (fix .gitignore; lock files committed per NFR-03.2)
- FR-07.1 Verify `ai-dlc` git submodule configured
- FR-07.2 Verify `.aidlc-rule-details/` present and populated
- FR-07.3 Verify per-package `AGENTS.md` files present
- NFR-01.1 `very_good_analysis` configured in all packages
- NFR-02.1 Test scaffold present with at least one passing test per package
- NFR-04.1 Conventional Commits format (commit messages)
- NFR-04.2 Git worktrees, one PR per unit

**Security / PBT compliance**:
- SECURITY-09: No secrets committed — no credentials exist in scaffold files (N/A; no secrets in scope)
- SECURITY-10: Pinned tool versions — Flutter SDK pin deferred to Unit 5 (CI); melos version pinned in root pubspec
- All other SECURITY / PBT rules: N/A for scaffold-only unit (no logic, no data handling, no tests of business logic)

---

## Generation Steps

### Step 1: Fix `.gitignore` — remove global `pubspec.lock` ignore, add per-package exceptions
- [x] Remove `pubspec.lock` from root `.gitignore` (currently ignores all lock files — violates FR-03.5 / NFR-03.2)
- [x] Add `packages/zip_core/pubspec.lock` to `.gitignore` (Dart library: lock not committed per Dart conventions)
- [x] Keep lock files committed for app packages (`zip_captions`, `zip_broadcast`) and root
- [x] **File**: `.gitignore`

### Step 2: Create root `melos.yaml`
- [x] Define workspace with `packages` glob pointing to all 4 packages
- [x] Scripts: `bootstrap`, `test` (`flutter test` / `dart test` per package), `analyze` (`dart analyze`), `format` (`dart format`)
- [x] Pin `melos` version constraint
- [x] **File**: `melos.yaml`

### Step 3: Create root `pubspec.yaml` (Pub Workspace)
- [x] `name: zip_captions_workspace`
- [x] `publish_to: none`
- [x] Declare as Pub Workspace listing all 4 package paths
- [x] Pin `melos` as dev dependency
- [x] **File**: `pubspec.yaml`

### Step 4: Create `packages/zip_core/pubspec.yaml`
- [x] `name: zip_core`, `publish_to: none`, Dart SDK constraint `>=3.6.0 <4.0.0`
- [x] No runtime dependencies (all added in Unit 2)
- [x] Dev dependencies: `very_good_analysis`
- [x] **File**: `packages/zip_core/pubspec.yaml`

### Step 5: Create `packages/zip_core/analysis_options.yaml`
- [x] Include `package:very_good_analysis/analysis_options.yaml`
- [x] **File**: `packages/zip_core/analysis_options.yaml`

### Step 6: Create `packages/zip_core/lib/zip_core.dart` (empty barrel)
- [x] Single-line library declaration with a placeholder comment (no exports yet — added in Unit 2)
- [x] **File**: `packages/zip_core/lib/zip_core.dart`

### Step 7: Create `packages/zip_core/test/zip_core_test.dart` (scaffold test)
- [x] One passing placeholder test (`expect(true, isTrue)`) to satisfy NFR-02.1
- [x] **File**: `packages/zip_core/test/zip_core_test.dart`

### Step 8: Create `packages/zip_captions/pubspec.yaml`
- [x] `name: zip_captions`, Flutter app, SDK constraints matching `zip_core`
- [x] No runtime dependencies beyond Flutter SDK (all added in Unit 3)
- [x] Dev dependencies: `very_good_analysis`, `flutter_test`
- [x] **File**: `packages/zip_captions/pubspec.yaml`

### Step 9: Create `packages/zip_captions/analysis_options.yaml`
- [x] Include `package:very_good_analysis/analysis_options.yaml`
- [x] **File**: `packages/zip_captions/analysis_options.yaml`

### Step 10: Create `packages/zip_captions/lib/main.dart` (minimal stub)
- [x] Minimal `main()` calling `runApp` with a placeholder `MaterialApp` — enough for `dart analyze` to pass
- [x] **File**: `packages/zip_captions/lib/main.dart`

### Step 11: Create `packages/zip_captions/test/widget_test.dart` (scaffold test)
- [x] One passing placeholder widget test to satisfy NFR-02.1
- [x] **File**: `packages/zip_captions/test/widget_test.dart`

### Step 12: Create `packages/zip_broadcast/pubspec.yaml`
- [x] Same structure as `zip_captions` with `name: zip_broadcast`
- [x] **File**: `packages/zip_broadcast/pubspec.yaml`

### Step 13: Create `packages/zip_broadcast/analysis_options.yaml`
- [x] Include `package:very_good_analysis/analysis_options.yaml`
- [x] **File**: `packages/zip_broadcast/analysis_options.yaml`

### Step 14: Create `packages/zip_broadcast/lib/main.dart` (minimal stub)
- [x] Same pattern as `zip_captions` stub
- [x] **File**: `packages/zip_broadcast/lib/main.dart`

### Step 15: Create `packages/zip_broadcast/test/widget_test.dart` (scaffold test)
- [x] One passing placeholder widget test to satisfy NFR-02.1
- [x] **File**: `packages/zip_broadcast/test/widget_test.dart`

### Step 16: Create `packages/zip_supabase/pubspec.yaml` (minimal stub)
- [x] `name: zip_supabase`, `publish_to: none`, Dart SDK constraint (no lib/, infrastructure only)
- [x] No dependencies (no Dart code in this package)
- [x] **File**: `packages/zip_supabase/pubspec.yaml`

### Step 17: Verify FR-07 requirements (read-only check, no files to generate)
- [x] Confirm `ai-dlc` submodule is configured (`.gitmodules` exists referencing `ai-dlc/`) — FR-07.1
- [x] Confirm `.aidlc-rule-details/` directory exists — FR-07.2
- [x] Confirm per-package `AGENTS.md` files are present in all 4 packages — FR-07.3
- [x] Log findings; no files written if all pass

### Step 18: Update `README.md` with monorepo setup instructions
- [x] Add "Getting Started" section with `melos bootstrap` instructions
- [x] Add prerequisites: Flutter SDK version, Dart SDK, Melos install command
- [x] **File**: `README.md` (update existing)

---

## Exit Criteria (from unit-of-work.md)

- `melos bootstrap` succeeds
- `dart analyze` passes on all packages (empty packages, no warnings)
- All 4 package directories have correct `pubspec.yaml` and `analysis_options.yaml`

---

## Notes

- `zip_supabase` has no `lib/` or `test/` — it is infrastructure-only (no Dart source per Unit 4 decision)
- `pubspec.lock` for `zip_core` (Dart library) is not committed per Dart library conventions; app package lock files are committed
- Stub `main.dart` files in app packages are intentionally minimal — all real app code is Unit 3 scope
- Generated code files (`.g.dart`, `.freezed.dart`) are NOT added to `.gitignore` (already correctly absent from it)
