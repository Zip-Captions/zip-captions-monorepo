# Phase 0 Requirements Verification Questions

Please answer each question by filling in the letter choice after the `[Answer]:` tag.
If none of the options match your needs, choose the last option (Other/X) and describe your preference.
Let me know when you're done.

---

## Question 1
The roadmap mentions "migrate the existing Flutter PoC into the new architecture." Is there an existing Flutter PoC codebase to migrate from?

A) Yes — there is an existing Flutter PoC in a separate repo or directory (provide location after [Answer] if so)
B) No — starting from scratch; the "PoC migration" means adopting the v2 architecture patterns, not literally porting code
C) Partially — there are some reference files or snippets worth carrying forward, but no full PoC to migrate
X) Other (please describe after [Answer]: tag below)

[Answer]: A) Yes, at the path `<local-poc-path>`

---

## Question 2
The roadmap lists three research spikes for Phase 0:
- Spike 0.1: Flutter desktop builds verification
- Spike 0.2: VPS provider selection for self-hosted Supabase + Coturn
- Spike 0.3: On-device realtime STT survey

Should these spikes be included as deliverables within this Phase 0 inception/construction scope?

A) Yes — all three spikes should be included as work items in Phase 0
B) Partially — include Spike 0.1 only (desktop build verification is a blocker; VPS and STT research can happen later)
C) No — exclude all spikes from this scope; Phase 0 is monorepo + CI/CD + app shells only
X) Other (please describe which spikes to include after [Answer]: tag below)

[Answer]: B)

---

## Question 3
Which CI/CD platform should be used for the pipeline?

A) GitHub Actions (as stated in the roadmap)
B) GitLab CI
C) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Question 4
For build verification in CI (compile check across all target platforms), what is the initial target set?

A) Mobile first — iOS and Android only for Phase 0 CI
B) Mobile + macOS desktop — iOS, Android, and macOS
C) All platforms in CI from day one — iOS, Android, macOS, Windows, Linux, web (may require self-hosted runners for Windows/Linux)
D) Compile checks are deferred; Phase 0 CI covers only lint, analyze, and test
X) Other (please describe after [Answer]: tag below)

[Answer]: A)

---

## Question 5
For Riverpod migration (ADR-003): the roadmap says "migrate existing PoC providers (speech service, settings) to Riverpod equivalents." Since there may be no PoC to migrate, what is the Riverpod scope for Phase 0?

A) Scaffold only — set up riverpod_generator + build_runner, establish patterns/conventions, no actual providers yet
B) Include placeholder providers — create stub providers for the core domain objects (speech service, settings) that Phase 1 will fill in
C) Full Riverpod setup with conventions documented and at least one working example provider
X) Other (please describe after [Answer]: tag below)

[Answer]: X) Create stub providers for the core domain objects, and migrate existing PoC providers where possible.

---

## Question 6
For the localization scaffold (ADR-014): the roadmap lists 9 languages to import from v1 (ar, de, es, fr, id, it, pl, pt, uk). Are the v1 ARB/translation files available in this monorepo or accessible somewhere to import?

A) Yes — the v1 translation files are accessible and should be imported into Phase 0
B) No — create the ARB scaffold with English source only; non-English translations are deferred
C) Import placeholder/stub ARB files for the listed languages with empty or machine-translated strings
X) Other (please describe after [Answer]: tag below)

[Answer]: X) No, but there is an entire v1 monorepo for the PWA that includes all the translations. That project is at `<local-v1-path>`

---

## Question 7
## Question: Security Extensions
Should security extension rules be enforced for this project?

A) Yes — enforce all SECURITY rules as blocking constraints (recommended for production-grade applications)
B) No — skip all SECURITY rules (suitable for PoCs, prototypes, and experimental projects)
X) Other (please describe after [Answer]: tag below)

[Answer]: A) Always enforce security rules as blocking constraints.

---

## Question 8
## Question: Property-Based Testing Extension
Should property-based testing (PBT) rules be enforced for this project?

A) Yes — enforce all PBT rules as blocking constraints (recommended for projects with business logic, data transformations, serialization, or stateful components)
B) Partial — enforce PBT rules only for pure functions and serialization round-trips (suitable for projects with limited algorithmic complexity)
C) No — skip all PBT rules (suitable for simple CRUD applications, UI-only projects, or thin integration layers with no significant business logic)
X) Other (please describe after [Answer]: tag below)

[Answer]: A)
