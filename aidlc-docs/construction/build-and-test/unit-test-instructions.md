# Unit Test Execution

## Run Unit Tests

### 1. Execute All Unit Tests
```bash
# From monorepo root — runs tests in all packages that have a test/ directory
melos exec --no-fail-fast -- flutter test
```

Or with coverage:
```bash
melos run test:coverage --no-select
```

### 2. Review Test Results

| Package | Tests | Status |
|---------|-------|--------|
| zip_core | 313 | Pass |
| zip_captions | 64 | Pass |
| zip_broadcast | 80 | Pass |
| zip_supabase | 0 (no test dir) | N/A |
| **Total** | **457** | **Pass** |

- **Expected**: 457 tests pass, 0 failures
- **Test Coverage**: Not yet measured (deferred pending lcov tooling)
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
   melos exec --no-fail-fast -- flutter test
   ```

### Test Categories

**zip_core (313 tests)**:
- Model unit tests: AppSettings, PauseEvent, RecordingError, SpeechLocale, BroadcastSession, TranscriptChunk
- Abstraction contract tests: SttEngine, AudioManager, OutputTarget (via fakes/mocks)
- Provider tests: BaseSettingsNotifier, SpeechLocaleNotifier, AudioInputConfigNotifier
- Theme tests: AppTheme light/dark, Material 3, text styles, WCAG contrast
- Property-based tests: settings round-trip, settings recovery from corrupt data
- Riverpod notifier tests: side-effect patterns, state transitions

**zip_captions (64 tests)**:
- Widget tests: ZipCaptionsApp renders, HomeScreen renders, RecordingScreen, SettingsScreen
- Provider override tests: STT state, recording state, caption display
- Localization tests: all l10n keys resolve for `en`

**zip_broadcast (80 tests)**:
- Widget tests: ZipBroadcastApp renders, HomeScreen, RecordingScreen, SettingsScreen, ZbRecordingControlsBar, ComingSoonCard
- Provider override tests: BroadcastRecordingNotifier state machine, AudioInputConfig, obsConnectionNotifier
- Localization tests: all l10n keys resolve for `en`
- ICU plural tests: homeStatusSummary with 0 / 1 / N sources
