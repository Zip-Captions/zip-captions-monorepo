# NFR Requirements Plan — Unit 2: zip_core Library

## Plan Overview

This plan assesses non-functional requirements for the zip_core library: testing strategy (PBT framework, provider mocking, stateful testing), security constraints (transcript logging prohibition, logging framework), dependency approvals, and accessibility compliance.

Most NFR decisions are already constrained by the inception Requirements document (NFR-01 through NFR-04) and the enabled extensions (Security Baseline, Property-Based Testing). This stage formalizes those into unit-level NFR requirements and resolves the remaining open decisions.

---

## Steps

- [x] Step 1: Collect user input on open NFR questions
- [x] Step 2: PBT-09 — Formalize framework selection (`glados`) and document integration with `dart test`
- [x] Step 3: PBT-01 — Identify testable properties for all zip_core components (from functional design)
- [x] Step 4: Define provider test strategy — mocking SharedPreferences, Riverpod testing patterns
- [x] Step 5: Assess SECURITY rules applicable to Unit 2
- [x] Step 6: Assess accessibility requirements (WCAG AAA from design spec)
- [x] Step 7: Resolve dependency approvals (bundled .ttf fonts, shared_preferences added to approved list)
- [x] Step 8: Generate NFR artifacts (nfr-requirements.md, tech-stack-decisions.md)

---

## Questions

Please answer each question by filling in the letter choice after the [Answer]: tag.

### Question 1
The `google_fonts` package is needed to provide the 8 v1 caption fonts cross-platform. It is not on the approved dependency list. An alternative is bundling `.ttf` files directly as app assets (no runtime dependency, but requires manual font file management and increases app bundle size by ~2-4 MB). Which approach do you approve?

A) Approve `google_fonts` as a new dependency — runtime font fetching with caching; smaller initial bundle; requires network on first use per font
B) Bundle `.ttf` files as assets — offline-first; larger bundle; no new dependency; fonts always available
C) Other (please describe after [Answer]: tag below)

[Answer]: B

### Question 2
`shared_preferences` is used extensively in the functional design for settings and locale persistence but is not listed in the approved dependencies (`docs/04-technical-specification.md` Section 6). The PoC uses it. Should it be formally added to the approved list?

A) Yes — add `shared_preferences` to the approved dependency list (it is fundamental to the settings architecture)
B) It is implicitly approved via PoC precedent — no doc change needed, just use it
C) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 3
The Monolith Editorial design spec targets WCAG AAA (7:1 contrast ratio) for text. Should this be formalized as a hard NFR for Unit 2's `AppTheme` implementation, or is it guidance for future UI work?

A) Hard NFR — `AppTheme` must produce `ColorScheme` values that achieve 7:1 contrast ratios for all text-on-surface combinations; verified in tests
B) Guidance — aim for 7:1 but enforce 4.5:1 (WCAG AA) as the hard minimum; document AAA as a goal
C) Other (please describe after [Answer]: tag below)

[Answer]: A

### Question 4
For provider testing, `mocktail` (approved dependency) will be used for mocking. SharedPreferences can be tested using Flutter's `SharedPreferences.setMockInitialValues()` method which is designed for testing. Is there a preference for how Riverpod providers should be tested?

A) Use `ProviderContainer` directly in tests (create a container, read/watch providers, assert state changes) — standard Riverpod testing pattern
B) Use `ProviderScope` overrides in widget tests (wrap widgets in `ProviderScope` with mock overrides) — closer to integration testing
C) Both — unit tests use `ProviderContainer`, widget tests use `ProviderScope` overrides
D) Other (please describe after [Answer]: tag below)

[Answer]: C

