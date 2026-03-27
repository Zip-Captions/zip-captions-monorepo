# NFR Requirements — Unit 2: zip_core Library

## NFR-U2-01: Property-Based Testing (PBT-01, PBT-02, PBT-03, PBT-06)

### Testable Properties by Component

#### AppSettings (freezed) + BaseSettingsNotifier

| Property | PBT Category | Description |
|---|---|---|
| Settings round-trip | PBT-02 Round-trip | For any valid `AppSettings`, saving to SharedPreferences and reloading produces an equal `AppSettings` |
| Defaults validity | PBT-03 Invariant | `AppSettings.defaults()` produces values within all defined ranges/enum sets |
| Per-field recovery | PBT-03 Invariant | When any subset of SharedPreferences keys contains corrupt data, the loaded `AppSettings` still has valid values for every field (defaults for corrupt, loaded for valid) |
| Reset idempotence | PBT-04 Idempotence | `reset()` called twice produces the same state as calling it once |

#### RecordingStateNotifier (state machine)

| Property | PBT Category | Description |
|---|---|---|
| Stateful model | PBT-06 Stateful | Random sequences of `start/pause/resume/stop/clearSession` commands applied to both the real notifier and a simplified model produce identical state at each step |
| Invalid transition no-op | PBT-03 Invariant | Any action called from an invalid state leaves the state unchanged |
| Transition determinism | PBT-03 Invariant | The same action from the same state always produces the same next state |

#### LocaleProvider

| Property | PBT Category | Description |
|---|---|---|
| Locale round-trip | PBT-02 Round-trip | `setLocale(locale)` followed by a fresh `build()` returns the same locale |
| Fallback validity | PBT-03 Invariant | `build()` always returns a non-null `Locale` regardless of SharedPreferences state |

#### SpeechLocale (freezed)

| Property | PBT Category | Description |
|---|---|---|
| languageCode extraction | PBT-03 Invariant | For any non-empty `localeId`, `languageCode` returns a non-empty string |
| Equality symmetry | PBT-03 Invariant | `SpeechLocale(a) == SpeechLocale(b)` if and only if `a.toLowerCase() == b.toLowerCase()` |

#### CaptionTextSize enum

| Property | PBT Category | Description |
|---|---|---|
| Complete mapping | PBT-03 Invariant | Every `CaptionTextSize` value resolves to a non-null `TextStyle` from `TextTheme` |

#### AppTheme

| Property | PBT Category | Description |
|---|---|---|
| Contrast compliance | PBT-03 Invariant | All text-on-surface color pairs in both light and dark themes achieve a minimum 7:1 contrast ratio (WCAG AAA) |

### Components with no PBT properties

| Component | Rationale |
|---|---|
| `sttEngineProvider` | Phase 0 stub; throws `UnimplementedError`. No testable logic. |
| `LocaleInfoProvider` | Phase 0 stub; returns empty list. No testable logic. |
| `SpeechLocaleProvider` | Phase 0 stub; returns fixed placeholder. No testable logic. |
| `SttEngine` (interface) | Abstract interface; no implementation to test. |
| `PauseEvent` | Data class; no logic beyond field storage. |
| `RecordingError` | Data class; no logic beyond field storage. |

---

## NFR-U2-02: PBT Framework (PBT-09)

**Framework**: `glados` (Dart)

**Justification**:
- Supports custom generators via `Arbitrary<T>` instances
- Automatic shrinking of failing cases
- Seed-based reproducibility (`Glados.seed()`)
- Integrates with `dart test` / `flutter test` — no separate runner needed
- Pub.dev: actively maintained, compatible with Dart 3

**Integration**:
- Add `glados` as a dev dependency in `packages/zip_core/pubspec.yaml`
- PBT test files in `test/pbt/` directory, separate from example-based tests in `test/`
- CI runs PBT alongside example-based tests via `melos run test`
- On failure, `glados` prints the seed and shrunk minimal input; CI captures this in test output

---

## NFR-U2-03: Provider Test Strategy (PBT-10)

**Unit 2 (zip_core)**: `ProviderContainer`-based unit tests

- Create `ProviderContainer` per test
- Use `SharedPreferences.setMockInitialValues()` to seed test data
- Read providers, call notifier methods, assert state changes
- `mocktail` for mocking any external dependencies
- PBT tests use `glados` with `ProviderContainer` (generated `AppSettings` values round-tripped through the notifier)

**Unit 3+ (app packages)**: `ProviderScope` override-based widget tests

- Wrap widgets in `ProviderScope(overrides: [...])` with mock notifiers
- Verify UI reacts to provider state changes
- Not applicable to Unit 2 (no widgets in zip_core)

**Complementary testing (PBT-10)**:
- Example-based tests pin specific known scenarios (e.g., default settings, specific state transitions, known locale fallback cases)
- PBT tests verify general invariants across generated inputs
- Both live in zip_core's `test/` directory, clearly separated: `test/` for example-based, `test/pbt/` for property-based
- When PBT discovers a failure, the shrunk case is added as a permanent example-based regression test

---

## NFR-U2-04: Security Assessment

### Applicable Rules

| Rule | Status | Assessment |
|---|---|---|
| SECURITY-03 (Application Logging) | Compliant | Transcript logging prohibition established in functional design (SR-01, SR-02, SR-03). RecordingStateNotifier and all transcript-handling code must never log text content. State transitions and operational metrics may be logged at debug level. |
| SECURITY-09 (Hardening) | Compliant | No credentials or secrets in zip_core. SharedPreferences stores user preferences only (scroll direction, text size, font, theme mode). No API keys or tokens. |
| SECURITY-10 (Supply Chain) | Compliant | All dependencies from pub.dev (official registry). Lock files committed. `glados` is a dev-only dependency (not shipped in production). Bundled .ttf fonts sourced from Google Fonts (OFL licensed). |
| SECURITY-15 (Exception Handling) | Compliant | BaseSettingsNotifier uses per-field recovery with fail-safe defaults (BR-05). RecordingStateNotifier uses severity-based error handling — fatal errors halt to safe state, transient errors surface without breaking state machine (BR-03). Invalid state transitions are silently ignored (fail-safe). |

### N/A Rules

| Rule | Reason |
|---|---|
| SECURITY-01 (Encryption at Rest/Transit) | SharedPreferences is local device storage. No encrypted data stores in Phase 0. Phase 3 introduces encrypted transcript storage. |
| SECURITY-02 (Access Logging) | No network intermediaries. |
| SECURITY-04 (HTTP Headers) | No web server. |
| SECURITY-05 (Input Validation) | No API endpoints. Settings values are validated by enum type safety. |
| SECURITY-06 (Least Privilege) | No IAM policies. |
| SECURITY-07 (Network Config) | No network configuration. |
| SECURITY-08 (Access Control) | No authentication in Phase 0. |
| SECURITY-11 (Secure Design) | No security-critical modules in zip_core Phase 0 beyond logging constraint (covered by SECURITY-03). |
| SECURITY-12 (Auth/Credentials) | No auth flows. No hardcoded credentials. |
| SECURITY-13 (Integrity) | No pipeline in this unit (Unit 5). |
| SECURITY-14 (Alerting/Monitoring) | No production deployment. |

---

## NFR-U2-05: Accessibility — WCAG AAA Contrast (Hard NFR)

**Requirement**: `AppTheme` must produce `ColorScheme` values where all text-on-surface color combinations achieve a minimum **7:1 contrast ratio** (WCAG AAA).

**Verification**: Unit tests compute the relative luminance contrast ratio for each text/surface pair in both dark and light themes and assert >= 7.0.

**Color pairs to verify (dark theme)**:

| Text token | Surface token | Expected ratio |
|---|---|---|
| `onSurface` (#DAE3F0) | `surface` (#0B141D) | >= 7:1 |
| `onSurface` (#DAE3F0) | `surfaceContainerLowest` (#060F18) | >= 7:1 |
| `onSurface` (#DAE3F0) | `surfaceContainerHigh` (#222B34) | >= 7:1 |
| `onSurface` (#DAE3F0) | `surfaceContainerHighest` (#2D3640) | >= 7:1 |
| `onPrimary` (#003355) | `primary` (#9ACBFF) | >= 7:1 |
| `onSecondaryContainer` (#B0B9C6) | `secondaryContainer` (#414A54) | >= 7:1 |
| `inverseOnSurface` (#28313B) | `inverseSurface` (#DAE3F0) | >= 7:1 |
| `error` (#FFB4AB) | `surface` (#0B141D) | >= 7:1 |

**Color pairs to verify (light theme)**: Derived from the light theme spec; pairs to be enumerated during Code Generation once the full light `ColorScheme` is defined.

**Typography constraint**: Minimum font weight 500 for text smaller than 14px (from design spec). Enforced by `AppTheme`'s `TextTheme` definition.

---

## NFR-U2-06: Dependency Approvals

### Approved (new)

| Package | Purpose | Justification | Action |
|---|---|---|---|
| `shared_preferences` | Settings and locale persistence | First-party Flutter plugin (Flutter Favorite). Used in PoC. Fundamental to settings architecture. Cross-platform key-value store. | Add to approved list in `docs/04-technical-specification.md` Section 6 |

### Bundled Font Assets (no package dependency)

The 8 v1 caption fonts will be bundled as `.ttf` files in app assets rather than using `google_fonts`. This provides:
- Offline-first availability — fonts always work without network
- No runtime dependency on external font service
- Predictable bundle size (~2-4 MB total for 8 font families)
- All fonts are Google Fonts with OFL (Open Font License) — free to bundle

Fonts are bundled in the **app packages** (zip_captions, zip_broadcast), not in zip_core. zip_core defines the `CaptionFont` enum and resolves font family names; the app packages register the font assets in their `pubspec.yaml`.

**Font files to bundle** (regular + bold weights minimum):
1. Atkinson Hyperlegible (default)
2. Poppins
3. Lexend
4. Raleway
5. Comic Neue
6. Noto Sans
7. Cousine
8. Inconsolata

Inter (UI chrome font) is also bundled as an app asset.

### Existing Approved Dependencies Used

| Package | Already Approved | Used For |
|---|---|---|
| `flutter_riverpod` / `riverpod_generator` | Yes | State management, provider code generation |
| `freezed` / `freezed_annotation` | Yes | Immutable data classes (AppSettings, SpeechLocale) |
| `mocktail` | Yes | Test mocking |
| `very_good_analysis` | Yes | Linting |

### Dev Dependencies (no approval needed)

| Package | Purpose |
|---|---|
| `glados` | PBT framework (PBT-09) |
| `build_runner` | Code generation for riverpod_generator and freezed |
