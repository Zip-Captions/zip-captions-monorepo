# Build Instructions

## Prerequisites
- **Build Tool**: Flutter SDK 3.38.7+ / Dart SDK 3.8+
- **Dependencies**: Melos 7.5.0+ (`dart pub global activate melos`)
- **Environment Variables**: None required for build
- **System Requirements**: macOS 13+, 8 GB RAM, 10 GB disk (includes Flutter SDK + caches)

## Build Steps

### 1. Install Dependencies
```bash
# From monorepo root
dart pub global activate melos
melos bootstrap
```

### 2. Configure Environment
```bash
# No environment configuration needed for Phase 0.
# Flutter SDK must be on PATH.
flutter doctor
```

### 3. Build All Units
```bash
# Static analysis (zero issues required)
melos run analyze

# Verify all packages resolve
melos exec -- dart pub get
```

Phase 0 does not produce deployment artifacts. The "build" is validated by
static analysis passing across all four packages:

| Package | Type | Analyze Status |
|---------|------|---------------|
| zip_core | Library | No issues found |
| zip_captions | App | No issues found |
| zip_broadcast | App | No issues found |
| zip_supabase | Infrastructure | No issues found |

### 4. Verify Build Success
- **Expected Output**: `No issues found!` from each package's `dart analyze --fatal-infos`
- **Build Artifacts**: No compiled artifacts in Phase 0 (scaffold only)
- **Common Warnings**: None expected; `--fatal-infos` treats all warnings as errors

## Troubleshooting

### Build Fails with Dependency Errors
- **Cause**: Melos bootstrap not run, or pub cache stale
- **Solution**:
  ```bash
  melos clean
  melos bootstrap
  ```

### Build Fails with Analysis Errors
- **Cause**: Lint rule violation or type error
- **Solution**:
  ```bash
  # See exact issues
  melos run analyze
  # Auto-fix formatting
  melos run format
  ```

### Melos "No scripts defined" Error
- **Cause**: Melos 7.x reads scripts from `pubspec.yaml` under the `melos:` key, not from `melos.yaml`
- **Solution**: Ensure the root `pubspec.yaml` contains the `melos: scripts:` section
