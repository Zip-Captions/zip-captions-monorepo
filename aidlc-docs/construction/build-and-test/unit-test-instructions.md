# Unit Test Execution

## Run Unit Tests

### 1. Execute All Unit Tests
```bash
# From monorepo root — runs tests in all packages that have a test/ directory
melos run test --no-select
```

Or with coverage:
```bash
melos run test:coverage --no-select
```

### 2. Review Test Results

| Package | Tests | Status |
|---------|-------|--------|
| zip_core | 81 | Pass |
| zip_captions | 3 | Pass |
| zip_broadcast | 3 | Pass |
| zip_supabase | 0 (no test dir) | N/A |
| **Total** | **87** | **Pass** |

- **Expected**: 87 tests pass, 0 failures
- **Test Coverage**: Not yet measured (coverage tooling deferred to Phase 1)
- **Test Report Location**: Printed to stdout; coverage files at `packages/*/coverage/lcov.info`

### 3. Fix Failing Tests
If tests fail:
1. Review the failing test output — Melos prints the package name and test file
2. Run the failing package individually for faster iteration:
   ```bash
   cd packages/zip_core
   flutter test test/path/to/failing_test.dart
   ```
3. Fix the code or test, then re-run the full suite to confirm no regressions:
   ```bash
   melos run test --no-select
   ```

### Test Categories

**zip_core (81 tests)**:
- Model unit tests: AppSettings, PauseEvent, RecordingError, SpeechLocale
- Enum unit tests: ScrollDirection, CaptionTextSize, CaptionFont, ThemeModeSetting
- Provider tests: BaseSettingsNotifier, SpeechLocaleNotifier
- Theme tests: AppTheme light/dark, Material 3, text styles, WCAG contrast
- Property-based tests: settings round-trip, settings recovery from corrupt data

**zip_captions (3 tests)**:
- Widget tests: ZipCaptionsApp renders, HomeScreen renders, displays title

**zip_broadcast (3 tests)**:
- Widget tests: ZipBroadcastApp renders, HomeScreen renders, displays title
