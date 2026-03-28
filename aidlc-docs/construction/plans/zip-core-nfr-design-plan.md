# NFR Design Plan — Unit 2: zip_core Library

## Stage Overview

NFR Design incorporates the non-functional requirements from `nfr-requirements.md` into concrete design patterns and logical components. For zip_core, this primarily means designing the property-based testing infrastructure (glados generators, stateful model) and the WCAG AAA contrast verification approach.

## Plan

- [x] Step 1: Analyze NFR requirements artifacts
- [x] Step 2: Collect user input on design questions
- [x] Step 3: Generate NFR design patterns artifact
- [x] Step 4: Generate logical components artifact
- [x] Step 5: Present for approval — APPROVED

---

## Questions

### Q1: Glados Generator Scope for AppSettings

`AppSettings` has 5 fields, including 3 enums and an int. For PBT round-trip and recovery tests, we need to generate arbitrary `AppSettings` instances.

**Option A**: Compose generators from individual field generators — one `Arbitrary<T>` per enum/field type, combined into an `Arbitrary<AppSettings>` via `Glados.combine`.

**Option B**: Single monolithic `Arbitrary<AppSettings>` generator that produces the full object directly.

Option A is more reusable (individual enum generators can be used in other tests) and matches the per-field recovery testing strategy.

[Answer]: A

---

### Q2: State Machine Model-Based Testing Approach

PBT-06 requires stateful model-based testing for `RecordingStateNotifier`. This means generating random command sequences and verifying the real notifier matches a simplified model at each step.

**Option A**: Define a `Command` enum (`start`, `pause`, `resume`, `stop`, `clearSession`) and generate random `List<Command>` sequences. Execute each command against both the real notifier and a pure-function model, comparing states step-by-step.

**Option B**: Same as A, but also generate random sequence lengths (bounded, e.g., 1-50 commands) and include edge cases like empty sequences.

**Option C**: Use glados's built-in stateful testing support (if available) to define the model as a state machine specification.

[Answer]: B

---

### Q3: WCAG AAA Contrast Verification Strategy

NFR-U2-05 requires 7:1 contrast ratio for all text-on-surface color pairs. The dark theme pairs are enumerated in the NFR requirements. Light theme pairs need to be derived during code generation.

**Option A**: Implement a `contrastRatio(Color foreground, Color background)` utility function in test code and assert each pair individually. Straightforward and explicit.

**Option B**: Same utility function, but drive it with PBT — generate all text/surface token combinations from the `ColorScheme` and verify the ratio property holds for every pair. More exhaustive but may flag pairs that aren't actually used together.

**Option C**: Hybrid — enumerate the known pairs from the design spec (explicit test), plus a PBT sweep of all `on*` / surface combinations as a safety net.

[Answer]: X (resolved) — Light theme pairs now enumerated in nfr-requirements.md (8 pairs mirroring dark theme). Primary darkened from spec #427EB5 to #1A5A8C for AAA; error set to #A8191F. Verification approach: A (explicit pairs, contrastRatio utility in test code).

---

### Q4: SharedPreferences Mock Strategy for PBT

PBT recovery tests need to generate corrupted SharedPreferences states (missing keys, wrong types, unrecognized enum names).

**Option A**: Use `SharedPreferences.setMockInitialValues()` with generated corrupt data maps. Each PBT run seeds a fresh mock with different corruption patterns.

**Option B**: Create a thin wrapper/interface around SharedPreferences to allow injecting arbitrary test behavior. More flexible but adds an abstraction layer.

Option A aligns with the tech stack decision (no wrapper) and the Flutter testing convention.

[Answer]: A

