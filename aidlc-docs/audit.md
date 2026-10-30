# AI-DLC Audit Log

## Workflow Initiation
**Timestamp**: 2026-03-26T00:00:00Z
**User Input**: "using ai-dlc, i would like to initiate phase 0"
**AI Response**: Started AI-DLC workflow. Displaying welcome message, proceeding with Workspace Detection.
**Context**: New workflow session initiated for Zip Captions v2 Phase 0.

---

## INCEPTION - Workspace Detection
**Timestamp**: 2026-03-26T00:00:01Z
**User Input**: (none - automatic stage)
**AI Response**: Scanned workspace. Found documentation-brownfield / code-greenfield project. No source code in packages. Comprehensive docs exist in docs/. Skipping Reverse Engineering. Proceeding to Requirements Analysis.
**Context**: Workspace Detection complete.

---

## INCEPTION - Requirements Analysis (Step 6: Clarifying Questions)
**Timestamp**: 2026-03-26T00:00:02Z
**User Input**: (none - proceeding automatically from Workspace Detection)
**AI Response**: Created requirement-verification-questions.md with 8 questions (6 project-specific + 2 extension opt-ins). Awaiting user answers before generating requirements document.
**Context**: Requirements Analysis - awaiting gate clearance.

---

## INCEPTION - Requirements Analysis (Gate Cleared)
**Timestamp**: 2026-03-26T00:01:00Z
**User Input**: "done"
**AI Response**: Read user answers. No contradictions detected. Loaded security-baseline.md (SECURITY-01 through SECURITY-15, all blocking) and property-based-testing.md (PBT-01 through PBT-10, full enforcement). Scanned PoC at <local-poc-path> — 4 providers (locale, recording, locale_info, settings) using provider package. Scanned v1 translations at <local-v1-assets-path> — 11 JSON files (ar, de, en, es, fr, id, it, pl, pt, uk, zh). Generated requirements.md with 7 FRs, 4 NFR groups, security and PBT compliance summaries.
**Context**: Requirements Analysis complete. Presenting for approval.

---

## INCEPTION - Requirements Analysis (Approval)
**Timestamp**: 2026-03-26T00:02:00Z
**User Input**: "approve and continue" (also updated FR-05.2 to exclude zh — quality of source file too low)
**AI Response**: Requirements approved. zh excluded from localization imports. Proceeding to Workflow Planning.
**Context**: Requirements Analysis stage complete.

---

## INCEPTION - Workflow Planning (Start)
**Timestamp**: 2026-03-26T00:02:01Z
**User Input**: (none — automatic stage)
**AI Response**: Loaded workflow-planning.md and content-validation.md. Analysing scope and determining phase execution decisions. Generating execution-plan.md.
**Context**: Workflow Planning in progress.

---

## INCEPTION - Workflow Planning (Approval)
**Timestamp**: 2026-03-26T00:03:00Z
**User Input**: "approve and continue"
**AI Response**: Workflow plan approved. Proceeding to Application Design.
**Context**: Workflow Planning stage complete. 6 units identified.

---

## INCEPTION - Application Design
**Timestamp**: 2026-03-26T00:04:00Z
**User Input**: "done, let's continue" (Q1: B, Q2: B, Q3: A, Q4: A)
**AI Response**: Read answers. No ambiguities. Generated components.md, component-methods.md, services.md, component-dependency.md, application-design.md. Key decisions: shared BaseSettingsNotifier with per-app key-prefixed subclasses; zip_core l10n for shared strings, per-app ARB for app-specific strings; shared AppTheme in zip_core; zip_supabase infrastructure-only (no Dart). Security note logged: RecordingStateNotifier must not log transcript text.
**Context**: Application Design complete. Awaiting approval.

---

## INCEPTION - Application Design (Approval)
**Timestamp**: 2026-03-26T00:05:00Z
**User Input**: "approve and continue"
**AI Response**: Application Design approved. Proceeding to Units Generation. All 6 units are fully defined from the execution plan — no clarifying questions required.
**Context**: Application Design stage complete.

---

## INCEPTION - Units Generation
**Timestamp**: 2026-03-26T00:06:00Z
**User Input**: (none — no questions required; proceeded directly to generation)
**AI Response**: Generated unit-of-work.md (6 units with scope, construction stages, worktree commands), unit-of-work-dependency.md (dependency matrix, sequencing, integration checkpoints), unit-of-work-story-map.md (all 27 FRs and 14 NFRs assigned to units). All Phase 0 exit criteria mapped.
**Context**: Units Generation complete. INCEPTION PHASE complete. Awaiting approval to proceed to CONSTRUCTION PHASE.

---

## CONSTRUCTION - Unit 1 Worktree Path Correction
**Timestamp**: 2026-03-26T00:07:00Z
**User Input**: "There's something incorrect about the ai-dlc instructions, the agent just created `zip-captions-monorepo-scaffold` directory in the parent directory of this project. That's not okay, that's too far up the document tree, and outside the scope of this workspace."
**AI Response**: Removed incorrectly placed worktree. Updated all 6 worktree paths in unit-of-work.md from `../zip-captions-<name>` to `.worktrees/<name>` (inside project root). Added `.worktrees/` to root `.gitignore`. Recreated worktree at `.worktrees/monorepo-scaffold`.
**Context**: Worktree path corrected. Proceeding with Unit 1 Code Generation Part 1.

---

## CONSTRUCTION - Unit 1: Monorepo Scaffold — Code Generation Plan (Approval Request)
**Timestamp**: 2026-03-26T00:08:00Z
**User Input**: "yes, continue"
**AI Response**: Created worktree at `.worktrees/monorepo-scaffold` on branch `feature/phase0-monorepo-scaffold`. Generated code generation plan at `aidlc-docs/construction/plans/monorepo-scaffold-code-generation-plan.md` (18 steps). Presenting plan for approval.
**Context**: Awaiting user approval of Unit 1 code generation plan before proceeding to Part 2 (generation).

---

## CONSTRUCTION - Unit 1: Monorepo Scaffold — Code Generation Plan (Approved)
**Timestamp**: 2026-03-26T00:09:00Z
**User Input**: "approve and continue"
**AI Response**: Plan approved. Proceeding to Part 2 (generation).
**Context**: Executing 18-step code generation plan.

---

## CONSTRUCTION - Unit 1: Monorepo Scaffold — Code Generation Complete
**Timestamp**: 2026-03-26T00:10:00Z
**User Input**: (none — automatic generation)
**AI Response**: All 18 steps executed. Created: melos.yaml, pubspec.yaml (root, Pub Workspace), packages/zip_core/{pubspec.yaml,analysis_options.yaml,lib/zip_core.dart,test/zip_core_test.dart}, packages/zip_captions/{pubspec.yaml,analysis_options.yaml,lib/main.dart,test/widget_test.dart}, packages/zip_broadcast/{pubspec.yaml,analysis_options.yaml,lib/main.dart,test/widget_test.dart}, packages/zip_supabase/pubspec.yaml. Modified: .gitignore (pubspec.lock policy), README.md (Getting Started section). Verified: FR-07.1/07.2/07.3 all pass. All plan checkboxes marked complete.
**Context**: Unit 1 code generation complete. Awaiting review and PR creation.

---

## Session Resumption
**Timestamp**: 2026-03-26T18:00:00Z
**User Input**: "Using AI-DLC, determine the next feature to build for Zip Captions"
**AI Response**: Detected existing session. Unit 1 (Monorepo Scaffold) confirmed merged as PR #2 (commit d6c9cd1). Updated aidlc-state.md. Presenting session continuity status and next-unit recommendation.
**Context**: Session resumption. INCEPTION complete. Unit 1 merged. Units 2-6 pending.

---

## Session Resumption — User Choice
**Timestamp**: 2026-03-26T18:01:00Z
**User Input**: "a"
**AI Response**: User selected Option A: Begin Unit 2 (zip_core Library). Proceeding to Functional Design stage for Unit 2.
**Context**: CONSTRUCTION - Unit 2 starting. First stage: Functional Design.

---

## CONSTRUCTION - Unit 2: Functional Design (Questions)
**Timestamp**: 2026-03-26T18:02:00Z
**User Input**: (questions created; user asked for elaboration on Q2 and Q3 before answering)
**AI Response**: Created zip-core-functional-design-plan.md with 8 questions. Provided detailed tradeoff analysis for Q2 (error handling) and Q3 (text size). Updated Q3 to CaptionTextSize enum after discussion.
**Context**: Functional Design Step 1 — collecting user input.

---

## CONSTRUCTION - Unit 2: Functional Design (Answers Received)
**Timestamp**: 2026-03-27T00:00:00Z
**User Input**: Q1:B (separate SpeechLocaleProvider), Q2:D (errors separate with severity), Q3:A (CaptionTextSize enum to TextTheme), Q4:D (rename to ThemeModeSetting: system/dark/light), Q5:D (v1 fonts cross-platform, google_fonts), Q6:A (abstract getter for keyPrefix), Q7:C (per-field fallback with debug warning), Q8:D (Monolith Editorial design spec for dark+light themes; user answers override spec conflicts e.g. font restrictions)
**AI Response**: Detected Q6 unanswered and 2 contradictions (Inter sole typeface vs v1 fonts; dark-only spec vs system/dark/light modes). Created clarification-questions.md. User could not open clarification file; updated Q8 answer in original plan to resolve both contradictions ("prioritize my answers to questions" + provided light theme spec). Q6 answered as A after recommendation.
**Context**: All questions resolved. Proceeding to artifact generation.

---

## CONSTRUCTION - Unit 2: Functional Design (Artifacts Generated)
**Timestamp**: 2026-03-27T00:01:00Z
**User Input**: (none — generation phase)
**AI Response**: Generated 3 artifacts: domain-entities.md (6 enums, 3 freezed classes, 1 sealed class, 1 abstract interface), business-logic-model.md (RecordingStateNotifier state machine, BaseSettingsNotifier persistence, LocaleProvider, SpeechLocaleProvider, LocaleInfoProvider, sttEngineProvider, AppTheme), business-rules.md (10 business rules + 3 security rules). Key design changes from Application Design: ContrastMode renamed to ThemeModeSetting; textSize (double) replaced by CaptionTextSize enum; fontFamily (String) replaced by CaptionFont enum; SpeechLocaleProvider added as new component. google_fonts flagged for dependency approval.
**Context**: Functional Design artifacts complete. Presenting for approval.

---

## CONSTRUCTION - Unit 2: Functional Design (Change Request 1 — Pause/Resume)
**Timestamp**: 2026-03-27T00:02:00Z
**User Input**: "Request changes - the state machine needs to be able to move from paused to playing without a stop and clear, in the case that a user wants to temporarily omit a fragment of audio from a capture session. Pauses should be recorded in transcript exports. Requirements must reflect that going forward."
**AI Response**: Pause/resume was already a valid transition but not emphasized as a core workflow. Updated all 3 artifacts: added PauseEvent model (domain-entities), added "Core Workflow: Pause/Resume for Audio Omission" section (business-logic-model), added BR-02 pause tracking rule (business-rules). Pauses produce PauseEvent records included in transcript exports.
**Context**: Functional Design revision 1.

---

## CONSTRUCTION - Unit 2: Functional Design (Change Request 2 — SpeechLocale format)
**Timestamp**: 2026-03-27T00:03:00Z
**User Input**: "request changes: update 4: speech locale provider - STT locales do not all use language + region, some do not offer it, some offer it as an optional setting, and some require a language and region."
**AI Response**: Updated SpeechLocale model to treat localeId as opaque key (not assumed language-region). Updated SpeechLocaleProvider responsibility to document three engine patterns. Added languageCode computed property for fallback matching.
**Context**: Functional Design revision 2.

---

## CONSTRUCTION - Unit 2: Functional Design (Change Request 3 — Locale selection flow)
**Timestamp**: 2026-03-27T00:04:00Z
**User Input**: "Request changes: locale provider selection needs to be either a one- or two-step process of selection language first, then region if there are more than one region avaiable from which to select"
**AI Response**: Added language-first selection flow to SpeechLocaleProvider: availableLanguages and regionsForLanguage(). Added BR-07 (Speech Locale Selection Flow). Auto-selects sole variant when only one region exists.
**Context**: Functional Design revision 3.

---

## CONSTRUCTION - Unit 2: Functional Design (Approved)
**Timestamp**: 2026-03-27T00:05:00Z
**User Input**: "continue to next step"
**AI Response**: Functional Design approved after 3 revisions. Proceeding to NFR Requirements.
**Context**: Functional Design stage complete. Next: NFR Requirements.

---

## CONSTRUCTION - Unit 2: NFR Requirements (Questions)
**Timestamp**: 2026-03-27T00:06:00Z
**User Input**: (questions created)
**AI Response**: Created zip-core-nfr-requirements-plan.md with 4 questions. User asked about shared_preferences nature (Flutter first-party plugin) and Q4 rationale (ProviderContainer vs ProviderScope tradeoffs).
**Context**: NFR Requirements Step 1 — collecting user input.

---

## CONSTRUCTION - Unit 2: NFR Requirements (Answers Received)
**Timestamp**: 2026-03-27T00:07:00Z
**User Input**: Q1:B (bundle .ttf assets, offline-first), Q2:A (add shared_preferences to approved list), Q3:A (hard NFR for WCAG AAA 7:1 contrast), Q4:C (both ProviderContainer unit tests and ProviderScope widget tests)
**AI Response**: No contradictions. Generated nfr-requirements.md (6 NFR sections: PBT property identification for all components, PBT-09 framework selection, provider test strategy, security assessment, WCAG AAA contrast hard NFR, dependency approvals) and tech-stack-decisions.md (testing stack, state management, data modeling, persistence, fonts, code quality, decisions log).
**Context**: NFR Requirements artifacts complete. Presenting for approval.

---

## CONSTRUCTION - Unit 2: NFR Requirements (Approved)
**Timestamp**: 2026-03-27T00:08:00Z
**User Input**: "continue to next stage"
**AI Response**: NFR Requirements approved. Proceeding to NFR Design.
**Context**: NFR Requirements stage complete. Next: NFR Design.

---

## CONSTRUCTION - Unit 2: NFR Design (Questions)
**Timestamp**: 2026-03-27T00:09:00Z
**User Input**: (questions created)
**AI Response**: Created zip-core-nfr-design-plan.md with 4 questions covering glados generator composition, state machine model-based testing, WCAG AAA contrast verification strategy, and SharedPreferences mock strategy.
**Context**: NFR Design Step 2 -- collecting user input.

---

## CONSTRUCTION - Unit 2: NFR Design (Answers Received + Light Theme Expansion)
**Timestamp**: 2026-03-27T00:10:00Z
**User Input**: Q1:A (composed per-field generators), Q2:B (variable-length command sequences 0-50), Q3:X (enumerate light theme pairs first, consistent approach), Q4:A (SharedPreferences.setMockInitialValues)
**AI Response**: Q3 required backtracking to NFR Requirements. Light theme spec had only 4 seed tokens vs dark theme's 13 Material 3 tokens. Expanded light theme ColorScheme in business-logic-model.md (14 tokens). Key adjustments: primary darkened from spec #427EB5 to #1A5A8C (mid-tone cannot achieve AAA with any text color), error set to #A8191F (standard Material red fails AAA on light surfaces). Enumerated 8 light theme contrast pairs in nfr-requirements.md NFR-U2-05. Generated nfr-design-patterns.md (5 patterns) and logical-components.md (4 logical components + test file map).
**Context**: NFR Design artifacts complete. Presenting for approval.

---

## CONSTRUCTION - Unit 2: NFR Design (Approved)
**Timestamp**: 2026-03-27T00:11:00Z
**User Input**: "approve and continue"
**AI Response**: NFR Design approved. Proceeding to Code Generation.
**Context**: NFR Design stage complete. Next: Code Generation (Part 1: implementation plan with test list).

---

## CONSTRUCTION - Unit 2: Code Generation Part 1 (Plan Created)
**Timestamp**: 2026-03-27T00:12:00Z
**User Input**: (automatic — plan generated after NFR Design approval)
**AI Response**: Created zip-core-code-generation-plan.md with 25 steps. Feature-based file organization (models/, providers/, stt/, theme/). TDD approach: test helpers and tests written before/alongside implementation. 13 FR/NFR requirements traced. 6 PBT test files, 6 example-based test files, 4 test helper modules. L10n scaffold with 10 ARB files (1 English source + 9 v1 imports). Riverpod conventions doc (FR-02.4).
**Context**: Code Generation Part 1 complete. Awaiting approval before Part 2 (generation).

---

## CONSTRUCTION - Unit 2: Code Generation Part 2 (Generation Complete)
**Timestamp**: 2026-03-27T01:30:00Z
**User Input**: "approve and continue" (approved plan, proceed to Part 2)
**AI Response**: Executed all 25 steps of the code generation plan. Results:
- **Production code**: 5 models (enums.dart, app_settings.dart, speech_locale.dart, recording_error.dart, pause_event.dart, recording_state.dart), 1 abstract interface (stt_engine.dart), 6 providers (base_settings_notifier.dart, locale_provider.dart, speech_locale_provider.dart, locale_info_provider.dart, recording_state_notifier.dart, stt_engine_provider.dart), 1 theme (app_theme.dart), barrel exports, generated .freezed.dart and .g.dart files
- **Test code**: 81 tests all passing — 17 model/theme tests, 34 provider tests, 25 PBT tests (5 PBT suites × 100 inputs each + 5 deterministic PBT tests), 16 WCAG AAA contrast tests (8 dark + 8 light)
- **Test infrastructure**: 4 helper modules (generators.dart, recording_state_model.dart, contrast_utils.dart, prefs_helpers.dart)
- **l10n scaffold**: l10n.yaml + 10 ARB files (English source + 9 non-English stubs tagged machine-generated). V1 translation import deferred — source files not available in repo.
- **Documentation**: docs/RIVERPOD_CONVENTIONS.md (FR-02.4)
- **Verification**: dart analyze zero errors/warnings (info only), no provider dependency, glados in dev deps, placeholder test removed
- **Fixes during generation**: glados version (^1.2.1→^1.1.7), inverseOnSurface naming, dark theme onSecondaryContainer AAA adjustment (#B0B9C6→#E0E8F2), Color API deprecation (.red→.r), pubspec sorting, library directive, SharedPreferences corruption model fix for int fields
**Context**: Code Generation COMPLETE. All 25 plan steps checked. Ready for approval.

---

## CONSTRUCTION - Unit 2: Code Generation Approval
**Timestamp**: 2026-03-27T02:00:00Z
**User Input**: "accept and continue"
**AI Response**: Code Generation stage accepted. Per core-workflow.md, Build and Test is a cross-unit stage that executes after ALL units complete Code Generation. Unit 2 construction is complete through Code Generation. Next per execution plan: Unit 3 (App Shells) construction begins with Functional Design.
**Context**: Unit 2 Code Generation accepted. Proceeding to Unit 3.

---

## CONSTRUCTION - Unit 3: Code Generation Part 1 (Plan Created)
**Timestamp**: 2026-03-27T02:10:00Z
**User Input**: (automatic — plan generated; Unit 3 skips all design stages per unit-of-work.md)
**AI Response**: Created app-shells-code-generation-plan.md with 12 steps. Both zip_captions and zip_broadcast: ProviderScope + MaterialApp with AppTheme, ConsumerWidget HomeScreen, app-specific SettingsNotifier (BaseSettingsNotifier subclass), app-specific l10n ARBs, widget tests. 7 FR/NFR requirements traced.
**Context**: Code Generation Part 1 complete. Awaiting approval before Part 2 (generation).

---

## CONSTRUCTION - Unit 3: Code Generation Part 1 Approval
**Timestamp**: 2026-03-27T02:15:00Z
**User Input**: "approve and proceed"
**AI Response**: Plan approved. Proceeding to Code Generation Part 2 (generation).
**Context**: Executing 12-step plan for both app shells.

---

## CONSTRUCTION - Unit 3: Code Generation Part 2 (Generation Complete)
**Timestamp**: 2026-03-27T02:30:00Z
**User Input**: "approve and proceed"
**AI Response**: Executed all 12 steps. Results:
- **zip_captions**: main.dart with ProviderScope + SharedPreferences override, ZipCaptionsApp (ConsumerWidget + MaterialApp + AppTheme), HomeScreen, ZipCaptionsSettingsNotifier (hand-written NotifierProvider, keyPrefix 'zip_captions'), app-specific l10n scaffold, 3 widget tests passing
- **zip_broadcast**: identical structure — ZipBroadcastApp, ZipBroadcastSettingsNotifier (keyPrefix 'zip_broadcast'), 3 widget tests passing
- **Fix**: BaseSettingsNotifier subclasses cannot use @riverpod annotation (riverpod_generator requires build method in annotated class). Used hand-written NotifierProvider instead, consistent with RIVERPOD_CONVENTIONS.md exception for abstract base patterns.
- **Verification**: dart analyze zero errors/warnings (info only), 6 total widget tests passing, no provider dependency, zip_core consumed via path dependency
**Context**: Code Generation COMPLETE. Awaiting approval.

---

## CONSTRUCTION - Unit 3: Code Generation Approval
**Timestamp**: 2026-03-27T02:35:00Z
**User Input**: "approve"
**AI Response**: Unit 3 Code Generation accepted. Proceeding to Unit 4 (Supabase Local Dev).
**Context**: Unit 3 complete. Unit 4 stages: NFR Requirements → Infrastructure Design → Code Generation.

---

## CONSTRUCTION - Unit 4: NFR Requirements (Questions + Answers)
**Timestamp**: 2026-03-27T02:40:00Z
**User Input**: Q1:A (latest stable Supabase release), Q2:A (standard ports), Q3:A (document local-only TLS exception), Q4:A (persistent named volumes)
**AI Response**: No ambiguities. Generated nfr-requirements.md (5 NFRs: no secrets, pinned images, TLS exception, persistent volumes, standard ports) and tech-stack-decisions.md (Docker Compose v2, Supabase self-hosted, .env pattern, PostgreSQL 15.x).
**Context**: NFR Requirements COMPLETE. Next: Infrastructure Design.

---

## CONSTRUCTION - Unit 4: NFR Requirements Approval
**Timestamp**: 2026-03-27T03:00:00Z
**User Input**: "approve and continue"
**AI Response**: NFR Requirements approved. Proceeding to Infrastructure Design stage.
**Context**: Unit 4 NFR Requirements stage approved.

---

## CONSTRUCTION - Unit 4: Infrastructure Design (Questions + Answers)
**Timestamp**: 2026-03-27T03:10:00Z
**User Input**: Q1:A (raw Docker Compose), Q2:A (health checks with dependency ordering), Q3:A (include Edge Functions runtime), Q4:A (include Studio)
**AI Response**: Generated infrastructure-design.md (9 services with pinned image tags, dependency graph, health checks, port mapping, env vars) and deployment-architecture.md (local-only architecture diagram, developer workflow, request flow, file structure).
**Context**: Infrastructure Design artifacts generated. Awaiting approval.

---

## CONSTRUCTION - Unit 4: Infrastructure Design Approval
**Timestamp**: 2026-03-27T03:30:00Z
**User Input**: "approve and continue"
**AI Response**: Infrastructure Design approved. Proceeding to Code Generation stage.
**Context**: Unit 4 Infrastructure Design stage approved. Next: Code Generation.

---

## CONSTRUCTION - Unit 4: Code Generation Plan Approval
**Timestamp**: 2026-03-27T03:45:00Z
**User Input**: "approve"
**AI Response**: Code Generation plan approved. Proceeding to generation.
**Context**: 9-step plan for infrastructure files. No Dart code, no tests.

---

## CONSTRUCTION - Unit 4: Code Generation Approval
**Timestamp**: 2026-03-27T04:00:00Z
**User Input**: "approve and continue"
**AI Response**: Code Generation approved. Unit 4 complete. Proceeding to Unit 5: CI/CD Pipeline.
**Context**: Unit 4 all stages complete. Generated: docker-compose.yml (9 services), kong.yml, .env.example, config.toml, initial migration, README. All NFR checks passed.

---

## CONSTRUCTION - Unit 5: NFR Requirements (Questions + Answers)
**Timestamp**: 2026-03-27T04:15:00Z
**User Input**: Q1:A (latest stable Flutter SDK), Q2:C (skip iOS builds in CI — local only in Spike 0.1), Q3:B (dart pub outdated only), Q4:A (PRs + main/develop triggers only)
**AI Response**: Generated nfr-requirements.md (7 NFRs: pinned actions, pinned Flutter SDK, lock file check, branch protection docs, pub outdated, trigger scope, Android-only build verify) and tech-stack-decisions.md (GitHub Actions, ubuntu-latest, subosito/flutter-action, Melos orchestration, pub-cache caching).
**Context**: NFR Requirements artifacts generated. Awaiting approval. Next: Infrastructure Design.

---

## CONSTRUCTION - Unit 5: NFR Requirements Approval
**Timestamp**: 2026-03-27T04:30:00Z
**User Input**: "continue"
**AI Response**: NFR Requirements approved. Proceeding to Infrastructure Design stage.
**Context**: Unit 5 NFR Requirements stage approved.

---

## CONSTRUCTION - Unit 5: Infrastructure Design (Questions + Answers)
**Timestamp**: 2026-03-27T04:45:00Z
**User Input**: Q1:A (global activate melos), Q2:A (collect coverage as artifact), Q3:A (concurrency groups, cancel in-progress)
**AI Response**: Generated infrastructure-design.md (single-job ci.yml with sequential steps, build-verify.yml for Android APK, pub-cache caching, pinned action versions) and deployment-architecture.md (trigger flow, branch protection setup for main/develop).
**Context**: Infrastructure Design artifacts generated. Awaiting approval.

---

## CONSTRUCTION - Unit 5: Infrastructure Design Approval
**Timestamp**: 2026-03-27T05:00:00Z
**User Input**: "approve and continue"
**AI Response**: Infrastructure Design approved. Proceeding to Code Generation stage.
**Context**: Unit 5 Infrastructure Design stage approved. Next: Code Generation.

---

## CONSTRUCTION - Unit 5: Code Generation Plan Approval
**Timestamp**: 2026-03-27T05:15:00Z
**User Input**: "approve and continue"
**AI Response**: Code Generation plan approved. Proceeding to generation.
**Context**: 7-step plan for CI workflow files. Flutter 3.38.7 pinned.

---

## CONSTRUCTION - Unit 5: Code Generation Approval
**Timestamp**: 2026-03-27T05:45:00Z
**User Input**: "approve and continue"
**AI Response**: Code Generation approved. Unit 5 complete. Proceeding to Unit 6: Spike 0.1.
**Context**: Unit 5 all stages complete. Generated: ci.yml, pubspec.yaml melos scripts, BRANCH_PROTECTION.md. build-verify.yml deferred (no android/ scaffolding). Local validation: 81 tests pass with coverage, analyze correctly catches issues. Melos 7.x discovery: scripts must be in pubspec.yaml.

---

## CONSTRUCTION - Unit 6: Code Generation Plan Approval
**Timestamp**: 2026-03-27T06:00:00Z
**User Input**: "approve and continue"
**AI Response**: Code Generation plan approved. Proceeding to generation.
**Context**: 7-step plan. Scaffold platforms, macOS build locally, build-verify.yml with platform matrix via GitHub Actions, PLATFORM_SETUP.md.

---

## CONSTRUCTION - Unit 6: Code Generation Approval
**Timestamp**: 2026-03-27T06:30:00Z
**User Input**: "approve and proceed"
**AI Response**: Code Generation approved. Unit 6 complete. All 6 units done. Proceeding to Build and Test.
**Context**: Unit 6 complete. macOS builds pass for both apps. Platform scaffolding + build-verify.yml + PLATFORM_SETUP.md generated. All 6 construction units now complete — entering cross-unit Build and Test.

---

## Build and Test Stage
**Timestamp**: 2026-03-27T07:00:00Z
**Build Status**: Success
**Test Status**: Pass (87/87)
**Static Analysis**: Pass (0 issues across 4 packages)
**Issues Resolved**: 12 lint issues fixed (6 public_member_api_docs, 2 avoid_equals_and_hash_code_on_mutable_classes, 2 avoid_catches_without_on_clauses, 1 use_setters_to_change_properties, 1 avoid_redundant_argument_values) + Melos 7.x script location fix + interactive prompt fix
**Files Generated**:
- aidlc-docs/construction/build-and-test/build-instructions.md
- aidlc-docs/construction/build-and-test/unit-test-instructions.md
- aidlc-docs/construction/build-and-test/build-and-test-summary.md

---

## Documentation Refinement Stage
**Timestamp**: 2026-03-28T00:00:00Z
**Artifacts Preserved**: 19 design documents cleaned and retained across inception and construction
**Artifacts Removed**:
- 17 plan/scaffold files (3 inception plans, 13 construction plans, 1 requirement-verification-questions)
- 6 NFR requirement files merged into design docs (ci-pipeline, zip-core, zip-supabase nfr-requirements/ directories)
- 4 empty directories (zip-captions, zip-broadcast, inception/plans, construction/plans)
**Project Docs Updated**:
- docs/04-technical-specification.md: added `shared_preferences` to approved deps, clarified freezed vs sealed class usage, documented hand-written NotifierProvider exception (v0.1 → v0.2)
**Design Doc Updates**:
- CI pipeline infrastructure-design.md: updated action versions to match shipped code (checkout v6.0.2, cache v5.0.4, upload-artifact v7.0.0, setup-java v5.2.0, flutter-action v2.23.0), Flutter SDK 3.38.7, merged tech stack and NFR content
- zip-core nfr-design-patterns.md: consolidated NFR requirements, tech stack decisions, PBT properties, security assessment, and dependency approvals into single design reference
- zip-supabase infrastructure-design.md: merged tech stack decisions and NFR compliance into design doc
**Created**: aidlc-docs/README.md (table of contents for all preserved artifacts)
**Status**: Complete

---

## Operations Stage
**Timestamp**: 2026-03-28T01:00:00Z
**Decision**: SKIPPED — Phase 0 is infrastructure scaffolding with no deployment targets or production operations. The Operations stage rule is a placeholder for future phases that include deployment, monitoring, and maintenance workflows.
**Status**: Phase 0 AI-DLC workflow complete

---

## Phase 1: Core Captioning — Workflow Initiation
**Timestamp**: 2026-03-28T02:00:00Z
**User Input**: "let's start phase 1 if we're ready"
**AI Response**: Started Phase 1 AI-DLC workflow. Displayed welcome message. Loaded common rules (content-validation, question-format-guide, session-continuity, process-overview). No extension opt-in files found; Security Baseline and Property-Based Testing carried forward from Phase 0 (enabled). Proceeding with Workspace Detection.
**Context**: Phase 1 inception initiated for Core Captioning scope.

---

## INCEPTION - Workspace Detection (Phase 1)
**Timestamp**: 2026-03-28T02:00:01Z
**User Input**: (none — automatic stage)
**AI Response**: Scanned workspace. Brownfield: Phase 0 scaffold complete (zip_core with models/providers/theme/87 tests, app shells, Supabase stack, CI/CD pipeline). No reverse engineering artifacts but not needed — codebase built by AI-DLC with design artifacts in aidlc-docs/. Updated aidlc-state.md for Phase 1 tracking. Proceeding to Requirements Analysis.
**Context**: Workspace Detection complete. Next: Requirements Analysis.

---

## INCEPTION - Requirements Analysis (Phase 1): Questions Created
**Timestamp**: 2026-03-28T02:01:00Z
**User Input**: (none — automatic from Workspace Detection)
**AI Response**: Created phase1-requirement-verification-questions.md with 12 questions covering: scope boundaries (OBS/BLE timing), spike strategy, STT package selection, output targets, transcript storage, audio capture scope, platform priority, wake lock behavior, state architecture, pause semantics, web target.
**Context**: Requirements Analysis Step 6 — awaiting user answers.

---

## INCEPTION - Requirements Analysis (Phase 1): Answers Received
**Timestamp**: 2026-03-28T02:02:00Z
**User Input**: "done"
**AI Response**: Read all 12 answers. No contradictions detected. Key decisions: Q1:A (OBS+browser source in Phase 1, independent of broadcast viewing — docs update needed), Q2:A (defer BLE to Phase 5), Q3:A (spikes before construction), Q4:A (speech_to_text package), Q5:C (all 4 output targets), Q6:A (SQLite — new transcript search story needed), Q7:C (full system audio investigation), Q8:A (iOS+Android+macOS first), Q9:C (wake lock release on pause as user setting), Q10:A (separate TranscriptProvider — independent error states), Q11:A (transparent pause fallback — semantic distinction from stop), Q12:B (web best-effort). Generated phase1-requirements.md with 10 FRs, 5 NFR groups, 3 research spikes, 2 doc update items.
**Context**: Requirements Analysis complete. Presenting for approval.

---

## INCEPTION - Requirements Analysis (Phase 1): Change Request 1
**Timestamp**: 2026-03-28T02:03:00Z
**User Input**: "Phase 1 needs to include a design prototype and review stage as well for all UI"
**AI Response**: Added FR-11 (UI Design Prototypes) with 5 sub-requirements. All UI screens for both apps require design prototypes reviewed and approved before implementation. Prototype gate covers: home, recording, settings, session history, transcript viewer (Zip Captions); home, recording, settings, audio source selection (Zip Broadcast). Must demonstrate light/dark themes, text customization, responsive layout.
**Context**: Requirements revision 1. Re-presenting for approval.

---

## INCEPTION - Requirements Analysis (Phase 1): Prototype Format Clarification
**Timestamp**: 2026-03-28T02:04:00Z
**User Input**: "how will the agent present the ui prototype?" / "yes, html prototypes are fine"
**AI Response**: Updated FR-11.5 to specify HTML/CSS prototype format (standalone files, browser-viewable, theme toggle). Added FR-11.6 specifying prototype file location in aidlc-docs/construction/{unit-name}/prototypes/.
**Context**: Requirements revision 2.

---

## INCEPTION - Requirements Analysis (Phase 1): Spike 1.1 Rewrite
**Timestamp**: 2026-03-28T02:05:00Z
**User Input**: "Research spike 1.1 predetermines the solution rather than indicating that research into the most performant solution would be warranted. Do not predetermine a solution in a research spike, include information as options only"
**AI Response**: Rewrote Spike 1.1 to survey all viable options (platform-native APIs, on-device models like Whisper.cpp/Vosk/Sherpa-ONNX, third-party packages) with a comparison matrix. No predetermined solution — recommendation follows from evaluation.
**Context**: Requirements revision 3.

---

## INCEPTION - Requirements Analysis (Phase 1): Spike 1.3 Rewrite
**Timestamp**: 2026-03-28T02:06:00Z
**User Input**: "Spike 1.3 needs to reflect a dive into the solution from spike 1.1 rather than whisper.cpp"
**AI Response**: Rewrote Spike 1.3 to depend on Spike 1.1's recommendation. Now a PoC integration of whatever engine Spike 1.1 selects, validating SttEngine interface compatibility, accuracy, latency, and resource usage.
**Context**: Requirements revision 4.

---

## INCEPTION - Requirements Analysis (Phase 1): FTS5 Clarification
**Timestamp**: 2026-03-28T02:07:00Z
**User Input**: User asked about postgres-like vector search for transcripts. After discussion of sqlite-vec vs FTS5 options: "Let's keep it constrained to the FTS5 approach"
**AI Response**: Updated FR-5.3 to specify SQLite FTS5 with BM25 ranking for transcript search.
**Context**: Requirements revision 5.

---

## INCEPTION - Requirements Analysis (Phase 1): Approved
**Timestamp**: 2026-03-28T02:08:00Z
**User Input**: "approve and continue"
**AI Response**: Requirements approved after 5 revisions. Proceeding to User Stories assessment.
**Context**: Requirements Analysis stage complete. Next: User Stories.

---

## INCEPTION - User Stories (Phase 1): Assessment
**Timestamp**: 2026-03-28T02:09:00Z
**User Input**: (none — automatic assessment)
**AI Response**: Assessment: EXECUTE. High Priority criteria met: new user features, multi-persona system (Alex/Jordan/Sam), complex business logic, user experience changes. Created user-stories-assessment.md and story-generation-plan.md with 6 questions.
**Context**: User Stories Part 1 (Planning) — awaiting answers.

---

## INCEPTION - User Stories (Phase 1): Answers Received
**Timestamp**: 2026-03-28T02:10:00Z
**User Input**: "done"
**AI Response**: Read all 6 answers. No contradictions. Q1:B (feature-based), Q2:A (coarse ~11 stories), Q3:C (both capability + scenario milestones), Q4:A (Given/When/Then all stories), Q5:A (spikes separate), Q6:A (separate prototype stories per screen, blocking).
**Context**: Plan analysis complete. Presenting for approval.

---

## INCEPTION - User Stories (Phase 1): Plan Approved
**Timestamp**: 2026-03-28T02:11:00Z
**User Input**: "approve and continue"
**AI Response**: Story generation plan approved. Proceeding to Part 2 (Generation).
**Context**: Executing 12-step story generation plan.

---

## INCEPTION - User Stories (Phase 1): Generation Complete
**Timestamp**: 2026-03-28T02:15:00Z
**User Input**: "proceed"
**AI Response**: Executed all 12 steps. Generated stories.md (10 feature stories + 9 prototype stories + 6 scenario milestones) and personas.md (Phase 1 persona coverage map). Feature stories: S-01 (STT Interface), S-02 (Platform STT), S-03 (Caption Bus), S-04 (Rendering), S-05 (Transcripts), S-06 (Audio Capture), S-07 (OBS), S-08 (Browser Source), S-09 (Zip Captions UI), S-10 (Zip Broadcast UI). Prototypes: Proto-01 through Proto-09 (one per screen, blocking implementation). Milestones: M-S1.1, M-S1.2, M-S1.3, M-S2.1, M-S2.2, M-S3.1. Traceability matrix and dependency graph included. INVEST compliance verified.
**Context**: User Stories Part 2 (Generation) complete. Presenting for approval.

---

## INCEPTION - User Stories (Phase 1): Change Request 1
**Timestamp**: 2026-03-29T00:01:00Z
**User Input**: "the user stories need to incorporate the user enabling transcript capture as an optional setting - a user may or may not want to retain a record of the session, and they should be able to adjust the settings accordingly."
**AI Response**: Updated S-05 (transcript capture conditional on setting), S-09 (settings includes transcript toggle, stop behavior depends on setting), S-10 (settings includes transcript toggle).
**Context**: Revision 1.

---

## INCEPTION - User Stories (Phase 1): Change Request 2
**Timestamp**: 2026-03-29T00:02:00Z
**User Input**: "When a user is using zip broadcast, they may want to use multiple input sources, each with its own associated speaker. The application should support multiple active inputs, and they should be able to be configured to render visually distinct results on screen."
**AI Response**: Updated S-01 (SttResult source identifier), S-03 (multi-source bus), S-04 (per-source visual distinction), S-06 (multiple simultaneous inputs with speaker labels and styles), S-10 (multi-input configuration UI), Proto-07 (multi-source rendering), Proto-09 (renamed to Audio Source Configuration with multi-input interface), M-S2.2 (multi-input classroom scenario).
**Context**: Revision 2.

---

## INCEPTION - User Stories (Phase 1): Change Request 3
**Timestamp**: 2026-03-29T00:03:00Z
**User Input**: "for story S-08, we need to ensure that most recent two lines of text are visible in the browser source, and they do not move position as the text changes, so that the browser source URL can be easily used with a fixed viewport where the captions are rendered."
**AI Response**: Updated S-08 with fixed-position two-line rendering for browser source viewport.
**Context**: Revision 3.

---

## INCEPTION - User Stories (Phase 1): Change Request 4
**Timestamp**: 2026-03-29T00:04:00Z
**User Input**: "In M-S2.2, Jordan should be able to overlay the captions onto an arbitrary screen, either as the browser source (for when there are no visuals that are required to be displayed in the classroom on the big screen), or as an overlay on top of an arbitrary screen that's shown on the projector (a mirror of the computer's screen, attached as a second display, or laid over a specific application such as a browser tab showing text, audio, or video)."
**AI Response**: Updated M-S2.2 with two display modes (standalone browser source and transparent overlay). Added caption overlay capability to S-10 and Proto-07. Overlay features: always-on-top, click-through, target display selection, configurable position. Flagged distinction from S3.5 premium overlay (personal use) vs broadcaster overlay (audience accessibility).
**Context**: Revision 4.

---

## INCEPTION - User Stories (Phase 1): Approved
**Timestamp**: 2026-03-29T00:05:00Z
**User Input**: "approve and continue"
**AI Response**: User Stories approved after 4 revisions. Proceeding to Workflow Planning.
**Context**: User Stories stage complete. Next: Workflow Planning.

---

## INCEPTION - Workflow Planning (Phase 1)
**Timestamp**: 2026-03-29T00:06:00Z
**User Input**: (automatic from User Stories approval)
**AI Response**: Generated phase1-execution-plan.md. Risk: Medium-High. 7 construction units + 3 pre-construction spikes. Inception remaining: Application Design + Units Generation. Construction per-unit: FD/NFR-R/NFR-D conditional, Infrastructure Design for browser source and overlay, Code Gen always. Parallelization: Units 2+3 after Unit 1; Units 5+6 after prototypes. Integration milestones as final verification.
**Context**: Workflow Planning complete. Presenting for approval.

---

## INCEPTION - Workflow Planning (Phase 1): Approved
**Timestamp**: 2026-03-29T00:07:00Z
**User Input**: "approve and continue"
**AI Response**: Workflow Planning approved. Proceeding to Application Design.
**Context**: Workflow Planning stage complete. Next: Application Design.

---

## INCEPTION - Application Design (Phase 1): Questions Created
**Timestamp**: 2026-03-29T00:08:00Z
**User Input**: (automatic from Workflow Planning approval)
**AI Response**: Created application-design-plan.md with 9 design steps + 6 mandatory artifacts + 9 questions covering: CaptionBus implementation pattern, output target lifecycle, SQLite package selection, browser source HTTP server, caption overlay window management, multi-input audio model, output target package location, OBS WebSocket package, settings architecture extension.
**Context**: Application Design Step 4 — awaiting user answers.

---

## INCEPTION - Application Design (Phase 1): Answers Received
**Timestamp**: 2026-03-29T01:00:00Z
**User Input**: Q1:B (standalone service class), Q2:B (registry-managed), Q3:B (drift ORM), Q4:A (shelf), Q5:C (spike-dependent), Q6:A (list-based provider), Q7:B (interface + shared in zip_core, broadcast-only in zip_broadcast), Q8:B (web_socket_channel + custom protocol), Q9:B (separate providers per concern — rename AppSettings to something descriptive of its category)
**AI Response**: All answers clear and unambiguous. User requested AppSettings be renamed to reflect its actual scope. User selected "DisplaySettings" after considering DisplaySettings/AppearanceSettings/UiSettings options. Generated 4 design artifacts: phase1-components.md, phase1-component-methods.md, phase1-services.md, phase1-component-dependency.md, and consolidated phase1-application-design.md.
**Context**: Application Design artifacts generated. Presenting for approval.

---

## INCEPTION - Application Design (Phase 1): Approved
**Timestamp**: 2026-03-29T01:30:00Z
**User Input**: "approve and continue"
**AI Response**: Application Design approved. Proceeding to Units Generation.
**Context**: Application Design stage complete. Next: Units Generation.

---

## INCEPTION - Units Generation (Phase 1): Questions Created
**Timestamp**: 2026-03-29T01:35:00Z
**User Input**: (automatic from Application Design approval)
**AI Response**: Created unit-of-work-plan.md with 8 decomposition steps + 5 mandatory artifacts + 4 questions covering: DisplaySettings rename timing, transcript storage unit assignment, app UI construction stage depth, spike sequencing strictness.
**Context**: Units Generation Part 1 (Planning) — awaiting user answers.

---

## INCEPTION - Units Generation (Phase 1): Answers Received
**Timestamp**: 2026-03-29T02:00:00Z
**User Input**: Q1:A (rename in Unit 1), Q2:B (all transcript components in Unit 3), Q3:C (full stages for app UI units), Q4:B (relaxed — Spike 1.2 parallel with Unit 1). User asked about Q3 rationale; confirmed full stages are appropriate for app-level performance and accessibility requirements.
**AI Response**: All answers clear. Generated 3 unit artifacts: phase1-unit-of-work.md (3 spikes + 7 units with components, construction stages, acceptance criteria), phase1-unit-of-work-dependency.md (dependency graph, matrix, parallelization opportunities, critical path), phase1-unit-of-work-story-map.md (10/10 feature stories, 9/9 prototypes, 6/6 milestones, 3/3 spikes — all assigned, no gaps).
**Context**: Units Generation artifacts complete. Presenting for approval.

---

## INCEPTION - Units Generation (Phase 1): Approved
**Timestamp**: 2026-03-29T02:15:00Z
**User Input**: "approve and continue" (user also added "Prioritize real-time capabilities with offline functionality" to Spike 1.1 scope)
**AI Response**: Units Generation approved. INCEPTION PHASE COMPLETE. Proceeding to CONSTRUCTION PHASE.
**Context**: All inception stages complete. Phase 1 construction begins with pre-construction research spikes.

---

## CONSTRUCTION - Spike 1.1: Windows/Linux STT Survey
**Timestamp**: 2026-03-29T02:30:00Z
**User Input**: "proceed"
**AI Response**: Researched all viable STT options for Windows and Linux. Evaluated: platform-native APIs (SAPI 5, WinRT SpeechRecognition, Azure Speech SDK — Windows only; no Linux native API), on-device models (Sherpa-ONNX, Whisper.cpp, Vosk, Coqui/DeepSpeech, PocketSphinx, Silero), Flutter packages (speech_to_text, sherpa_onnx, vosk_flutter, whisper_dart). Produced comparison matrix with weighted scoring. **Recommendation: Sherpa-ONNX as primary** (official Flutter package for Windows+Linux, native streaming, low latency, small models, Apache 2.0). Whisper.cpp as secondary high-accuracy option. speech_to_text/WinRT as zero-download Windows fallback. Spike 1.3 should focus on Sherpa-ONNX integration (not Whisper.cpp).
**Context**: Spike 1.1 complete. Report at aidlc-docs/construction/spikes/spike-1.1-report.md.

---

## CONSTRUCTION - Spike 1.1: Whisper.cpp Turbo/Distil Update
**Timestamp**: 2026-03-29T03:00:00Z
**User Input**: "Research Large-v3-Turbo and Distil-Whisper models in regards to whisper.cpp and update the spike doc with any relevant changes"
**AI Response**: Researched Large-v3-Turbo (809M params, 1.6GB GGML, ~6x faster than large-v3, 99 languages, near large-v2 accuracy) and Distil-Whisper (756M params, 6.3x faster, primarily English-only, provisional whisper.cpp support). Updated spike-1.1-report.md: added "Whisper Model Variants" subsection, revised comparison matrix (latency and model size rows), added Whisper.cpp (turbo) scoring at 80 (up from 72), updated secondary recommendation to emphasize turbo model. Turbo significantly improves Whisper.cpp viability but Sherpa-ONNX remains the primary recommendation.
**Context**: Spike 1.1 report updated with turbo/distil findings.

---

## CONSTRUCTION - Spike 1.3: STT Integration PoC
**Timestamp**: 2026-03-29T03:30:00Z
**User Input**: "I had another agent create spike 1.3, I want you to review the work and extend it with your own information"
**AI Response**: Reviewed other agent's draft — found it inadequate (generic implementation plan, no actual PoC findings, inaccurate details like "Coordinate with ML team" and "isolated memory regions"). Completely rewrote the report with actual research: evaluated `sherpa_onnx` Flutter package (pub.dev, platforms, FFI-based), documented OnlineRecognizer streaming API (acceptWaveform → decode → getResult → isEndpoint → reset), mapped all 11 SttEngine interface methods to sherpa_onnx API, confirmed native pause/resume support, documented available streaming Zipformer models (20-180MB int8), defined implementation architecture, assessed risks. **Verdict: Sherpa-ONNX confirmed viable for implementing SherpaOnnxSttEngine.**
**Context**: Spike 1.3 complete. Report at aidlc-docs/construction/spikes/spike-1.3-report.md.

---

## CONSTRUCTION - Unit 1: Core Abstractions — Functional Design (Questions)
**Timestamp**: 2026-03-29T04:00:00Z
**User Input**: (automatic — proceeding from Spike 1.3 completion)
**AI Response**: Created functional design plan at aidlc-docs/construction/plans/core-abstractions-functional-design-plan.md with 16 plan steps and 7 questions covering: SttEngine callback migration (Q1), CaptionOutputTargetRegistry error isolation (Q2), RecordingState field extension approach (Q3), SttEngineProvider Unit 1 behavior (Q4), registry subscription timing (Q5), DisplaySettings key prefix rename (Q6), supportedLocales signature (Q7).
**Context**: Unit 1 Functional Design — question creation.

---

## CONSTRUCTION - Unit 1: Core Abstractions — Functional Design (Answers)
**Timestamp**: 2026-03-29T04:15:00Z
**User Input**: Q1:A, Q2:A, Q3:B, Q4:C, Q5:B, Q6:A, Q7:B. User asked for tradeoff analysis on Q2 and Q7 before answering.
**AI Response**: All 7 answers received, no contradictions detected. Generated 3 functional design artifacts: domain-entities.md (SttResult, CaptionEvent, AudioInputConfig, AudioInputVisualStyle, RecordingState update, DisplaySettings rename), business-logic-model.md (SttEngine interface delta, SttEngineRegistry, CaptionBus, CaptionOutputTarget, CaptionOutputTargetRegistry, RecordingStateNotifier update, provider layer, TranscriptSettingsProvider), business-rules.md (14 business rules, 2 security rules, PBT testable properties per component, extension compliance summary).
**Context**: Unit 1 Functional Design — artifacts generated, awaiting approval.

---

## CONSTRUCTION - Unit 1: Core Abstractions — Functional Design (Approval)
**Timestamp**: 2026-03-29T04:30:00Z
**User Input**: "approve and continue"
**AI Response**: Functional Design approved. Proceeding to NFR Requirements stage.
**Context**: Unit 1 Functional Design — COMPLETE. Moving to NFR Requirements.

---

## CONSTRUCTION - Unit 1: Core Abstractions — NFR Requirements (Questions + Answers)
**Timestamp**: 2026-03-29T04:45:00Z
**User Input**: Q1:A (20 events/sec throughput), Q2:A (glados PBT), Q3:A (uuid package), Q4:B (logging package)
**AI Response**: Created NFR requirements plan with 4 questions. All answered, no contradictions. Generated 2 artifacts: nfr-requirements.md (5 NFR groups: performance, reliability, security, testing, maintainability; 11 requirements total), tech-stack-decisions.md (3 new dependencies: uuid, logging, glados; logger naming convention; migration plan for dart:developer to logging).
**Context**: Unit 1 NFR Requirements — artifacts generated, awaiting approval.

---

## CONSTRUCTION - Unit 1: Core Abstractions — NFR Requirements (Approval)
**Timestamp**: 2026-03-29T05:00:00Z
**User Input**: "proceed"
**AI Response**: NFR Requirements approved. Proceeding to NFR Design stage.
**Context**: Unit 1 NFR Requirements — COMPLETE. Moving to NFR Design.

---

## CONSTRUCTION - Unit 1: Core Abstractions — NFR Design (Questions + Answers)
**Timestamp**: 2026-03-30T00:00:00Z
**User Input**: Q1:A (shared generators file), Q2:C (default brief async delay ~100ms)
**AI Response**: Created NFR design plan with 2 questions. All answered, no contradictions. Generated 2 artifacts: nfr-design-patterns.md (5 patterns: glados PBT with ArbitraryT generators, MockSttEngine with 100ms default async delay and emitResult trigger, logging pattern with Logger per component, bus throughput sanity test, error isolation test with CollectingTarget/ThrowingTarget helpers), logical-components.md (test infrastructure map, runtime component diagram, dependency summary).
**Context**: Unit 1 NFR Design — artifacts generated, awaiting approval.

---

## CONSTRUCTION - Unit 1: Core Abstractions — NFR Design (Approval)
**Timestamp**: 2026-03-30T00:30:00Z
**User Input**: "approve and continue"
**AI Response**: NFR Design approved. Proceeding to Code Generation.
**Context**: Unit 1 NFR Design — COMPLETE.

---

## CONSTRUCTION - Unit 1: Core Abstractions — Code Generation Part 1 (Plan)
**Timestamp**: 2026-03-30T00:45:00Z
**User Input**: (automatic — plan creation)
**AI Response**: Created code generation plan with 45 steps across 11 phases (A-K). Covers: dependency additions, DisplaySettings rename, new models (SttResult, AudioInputConfig, CaptionEvent), SttEngine interface update, new services (SttEngineRegistry, CaptionBus, CaptionOutputTarget, CaptionOutputTargetRegistry), RecordingState/Notifier updates, new providers, test helpers (MockSttEngine, test targets), 8 example-based test files, 6 PBT test files, build/analyze/test verification.
**Context**: Unit 1 Code Generation Part 1 — plan created, awaiting approval.

---

## CONSTRUCTION - Spike 1.2: System Audio Capture Feasibility (Complete)
**Timestamp**: 2026-03-30T03:00:00Z
**User Input**: "Let's do spike 1.2"
**AI Response**: Spike 1.2 complete. System audio capture is feasible on all three platforms. Custom Flutter plugin (`zip_audio_capture`) needed with per-platform native implementations: Core Audio taps (macOS 14.2+), WASAPI loopback (Windows), PulseAudio monitor sources (Linux). No existing Flutter package meets requirements.
**Context**: Spike 1.2 — COMPLETE. Report at `aidlc-docs/construction/spikes/spike-1.2-report.md`. Unblocks Unit 6 (Zip Broadcast).

---

## CONSTRUCTION - Unit 1: Core Abstractions — Code Generation Part 2 (Complete)
**Timestamp**: 2026-03-30T02:00:00Z
**AI Response**: Code Generation Part 2 complete. All 45 steps executed.
**Context**: Unit 1 Code Generation — COMPLETE.
- 26 files generated by build_runner (freezed + riverpod)
- 0 analyzer errors across all 3 packages (57 infos in zip_core, style only)
- 156 tests passing (unit + PBT)
- New: 3 models, 4 services, 4 providers, 2 test helpers, 8 unit test files, 4 PBT test files
- Modified: RecordingState (ActiveSessionState mixin), RecordingStateNotifier (CaptionBus, sessionId, handleSttResult), SttEngine (Phase 1 interface)

---

## CONSTRUCTION - Unit 1: Core Abstractions — Code Generation Part 1 (Approval)
**Timestamp**: 2026-03-30T01:00:00Z
**User Input**: "approve and continue"
**AI Response**: Code generation plan approved. Beginning Part 2 (Generation).
**Context**: Unit 1 Code Generation Part 1 — COMPLETE. Starting Part 2.

---

## CONSTRUCTION - Unit 1: Core Abstractions — NFR Design (Approval)
**Timestamp**: 2026-03-30T00:15:00Z
**User Input**: "approve and continue"
**AI Response**: NFR Design approved. Proceeding to Code Generation stage.
**Context**: Unit 1 NFR Design — COMPLETE. Moving to Code Generation.

---

## CONSTRUCTION - Unit 2: Platform STT + Audio — Session Resume
**Timestamp**: 2026-03-31T00:00:00Z
**User Input**: "Using ai-dlc, I want to continue with the current phase of work, defined in aidlc-docs/construction/implementation/audio-capture-plan.md"
**AI Response**: Session resumed. Loaded aidlc-state.md (Unit 2: Platform STT + Audio is next). Loaded spike reports (1.1, 1.2, 1.3), Unit 1 code summary, phase1-unit-of-work.md, phase1-unit-of-work-story-map.md, component methods, stories S-02 and S-06. audio-capture-plan.md noted (generic pre-AI-DLC document; AI-DLC functional design proceeds from unit-of-work and spike artifacts). Extensions: Security Baseline (enabled), Property-Based Testing (enabled). Proceeding to Functional Design for Unit 2.
**Context**: Unit 2 Functional Design — starting.

---

## CONSTRUCTION - Unit 2: Platform STT + Audio — Functional Design (Approval)
**Timestamp**: 2026-03-31T12:00:00Z
**User Input**: "approve and continue"
**AI Response**: Functional Design approved. Three artifacts complete: domain-entities.md (AudioDevice, SherpaModelCatalogResponse, SherpaModelCatalogEntry, SherpaModelInfo, SherpaModelDownloadProgress, WakeLockSettings, RecordingError factories including permissionDenied/permissionPermanentlyDenied/engineRequiresModelDownload/engineInitFailed/engineStartFailed/localeNotSupported), business-logic-model.md (AudioDeviceService, WakeLockService, SttSessionManager, PlatformSttEngine, SherpaOnnxSttEngine, SherpaModelManager, SherpaModelCatalogNotifier with stale-while-revalidate, RecordingStateNotifier updates, locale resolution chain, AudioInputSettingsProvider shell, full provider map), business-rules.md (BR-U2-01..43 covering engine selection, permission re-trigger flow, locale fallback, wake lock, model download, catalog API contract with aggressive caching policy). Proceeding to NFR Requirements.
**Context**: Unit 2 Functional Design — COMPLETE. Moving to NFR Requirements.

---

## CONSTRUCTION - Unit 2: Platform STT + Audio — NFR Requirements (Questions + Answers)
**Timestamp**: 2026-04-02T00:00:00Z
**User Input**: Q1:A (record package), Q2:B (dio), Q3:A (.tar.bz2 with archive package), Q4:A (≤500ms latency), Q5:B (warn >100MB), Q6:C (resume if CDN supports, fallback restart), Q7:B (one auto-restart attempt), Q8:A (no cert pinning), Q9:B (no background captioning — consent constraint), Q10:C (static JSON on CDN), Q11:B (pre-recorded PCM fixtures), Q12:B (mock SpeechToText + mock OnlineRecognizer bindings)
**AI Response**: All 12 answers received, no contradictions. Generated nfr-requirements.md (7 NFR groups: performance, reliability, security, usability, testing, maintainability, availability; 20 requirements total).
**Context**: Unit 2 NFR Requirements — artifacts generated, awaiting approval.

---

## CONSTRUCTION - Unit 2: Platform STT + Audio — NFR Requirements (Approval)
**Timestamp**: 2026-04-02T01:00:00Z
**User Input**: "approve and continue" (from previous session)
**AI Response**: NFR Requirements approved. Proceeding to NFR Design stage.
**Context**: Unit 2 NFR Requirements — COMPLETE. Moving to NFR Design.

---

## CONSTRUCTION - Unit 2: Platform STT + Audio — NFR Design (Questions + Answers)
**Timestamp**: 2026-04-03T00:00:00Z
**User Input**: Q1:A (minimal OnlineRecognizerAdapter — 6 pass-through methods), Q2:B (new RecordingState.reconnecting variant), Q3:B (file-based catalog cache), Q4:A (http_mock_adapter), Q5:A (abstract WakeLockService interface — wakelock_plus uses static API, cannot inject), Q6:B (PBT for domain types + state machine extensions)
**AI Response**: All 6 answers received. Q5 changed from initial B to A after investigating wakelock_plus API (entirely static methods — cannot inject an instance). Generated 2 artifacts: nfr-design-patterns.md (11 patterns: engine crash recovery with reconnecting state, OnlineRecognizerAdapter seam, PlatformSttEngine SpeechToText injection, dio download resume with Range headers, stale-while-revalidate CatalogCache file-based, SHA-256 archive integrity, large download confirmation gate, WakeLockService abstract interface, permission handler mock, PBT generators + state machine extensions, logging extension), logical-components.md (runtime component map, 10 test infrastructure components, dependency summary, extension compliance).
**Context**: Unit 2 NFR Design — artifacts generated, awaiting approval.

---

## CONSTRUCTION - Unit 2: Platform STT + Audio — NFR Design (Approval)
**Timestamp**: 2026-04-03T01:00:00Z
**User Input**: "approve and continue"
**AI Response**: NFR Design approved. Proceeding to Code Generation stage.
**Context**: Unit 2 NFR Design — COMPLETE. Moving to Code Generation.

---

## CONSTRUCTION - Unit 2: Platform STT + Audio — Code Generation Part 1 (Plan)
**Timestamp**: 2026-04-03T02:00:00Z
**User Input**: (automatic — plan creation)
**AI Response**: Created code generation plan with 74 steps across 13 phases (A-M). Covers: 9 new runtime deps + 1 dev dep, 6 freezed models, RecordingState.reconnecting variant, RecordingErrorFactories, 3 abstract interfaces (AudioDeviceService, WakeLockService, OnlineRecognizerAdapter), 5 service implementations (WakelockPlusService, SherpaOnlineRecognizerAdapter, CatalogCache, SherpaModelManager, SttSessionManager), 2 STT engines (PlatformSttEngine, SherpaOnnxSttEngine), 13 new/updated providers, zip_broadcast shell, 6 test mocks + fixtures + PBT generators, 17 example-based test files, 5 PBT test files, build/analyze/test.
**Context**: Unit 2 Code Generation Part 1 — plan created, awaiting approval.

---

## CONSTRUCTION - Unit 2: Platform STT + Audio — Code Generation Part 1 (Approval)
**Timestamp**: 2026-04-03T02:30:00Z
**User Input**: "approve and continue"
**AI Response**: Code generation plan approved. Beginning Part 2 (Generation).
**Context**: Unit 2 Code Generation Part 1 — COMPLETE. Starting Part 2.

---

## Documentation Refinement — Unit 2: Platform STT + Audio
**Timestamp**: 2026-04-04T00:00:00Z
**Artifacts Preserved**: 7 design documents cleaned and retained (functional-design: domain-entities, business-rules, business-logic-model; nfr-design: logical-components, nfr-design-patterns; nfr-requirements: nfr-requirements, tech-stack-decisions); code-summary preserved as-is
**Artifacts Removed**: 5 plan/scaffold files (platform-stt-audio-functional-design-plan.md, platform-stt-audio-nfr-requirements-plan.md, platform-stt-audio-nfr-design-plan.md, platform-stt-audio-code-generation-plan.md, construction/implementation/audio-capture-plan.md)
**Project Docs Updated**: aidlc-docs/README.md — added Phase 1 inception and construction sections (spikes, Unit 1, Unit 2); updated last refinement date to 2026-04-04
**Status**: Complete

---

## CONSTRUCTION - Unit 3: Output Targets — NFR Design (Questions + Answers)
**Timestamp**: 2026-04-06T00:00:00Z
**User Input**: NFR-DQ1:A (Timer at call site — cancel + restart Timer(50ms) on each onCaptionEvent(); state updated synchronously, trailing emission only; no rxdart), NFR-DQ2:C (skip unit testing PRAGMA + file-rename path; unit-test only downstream notification/state effects; treat SQLite path as acceptance test), NFR-DQ3:B (StreamController<List<int>> per client; catch SocketException on write errors via onError; close controller and decrement counter on error or onDone)
**AI Response**: All 3 answers received. Generated 2 artifacts: nfr-design-patterns.md (11 patterns: timer-based debounce OnScreenCaptionTarget, FTS5 query via drift, SSE client cap + disconnect detection, UUID token auth + localhost bypass, database corruption recovery PRAGMA→rename→fresh, immediate segment persistence via merge window, DesktopWindowService abstraction + MockDesktopWindowService, fake_async timer tests merge window + OBS backoff, BrowserSourceServer test pattern shelf test client, PBT generators new domain types, logging pattern extension zip_broadcast logger names); logical-components.md (9 runtime components across zip_core and zip_broadcast, 6 test infrastructure elements, test file map, provider dependency map).
**Context**: Unit 3 NFR Design — artifacts generated, awaiting approval.

---

## CONSTRUCTION - Unit 3: Output Targets — NFR Design (Approval)
**Timestamp**: 2026-04-07T00:00:00Z
**User Input**: "approve"
**AI Response**: NFR Design approved. Updated aidlc-state.md to mark NFR-D complete for Unit 3.
**Context**: Unit 3 NFR Design — COMPLETE. Next stage: Implementation Design (ID), then Code Generation.

---

## Implementation Design + Code Generation Planning — Unit 3: Output Targets
**Timestamp**: 2026-04-07T00:00:00Z
**User Input**: "let's do it" (proceed with ID + CG plan in token-efficient mode; CG execution to be delegated to local Ollama instance)
**AI Response**: ID treated as complete (logical-components.md serves as implementation design artifact). Produced CG plan at aidlc-docs/construction/plans/output-targets-code-generation-plan.md — 21 steps covering 9 RC + 6 TI elements across zip_core and zip_broadcast. aidlc-state.md updated.
**Context**: Unit 3 ID — COMPLETE. Unit 3 CG — PLAN COMPLETE, execution pending (Ollama).

---

## CONSTRUCTION - Unit 3: Output Targets — Code Generation (All 21 Steps)
**Timestamp**: 2026-04-11T00:00:00Z
**User Input**: "proceed" (autonomous execution through all 21 steps)
**AI Response**: Executed all 21 CG steps. Key artifacts produced:
- zip_core: OnScreenCaptionTarget, TranscriptWriterTarget, TranscriptRepository (drift), barrel updates, all Unit 3 models exported
- zip_broadcast: ObsWebSocketTarget (exponential backoff), BrowserSourceServer (shelf SSE), BrowserSourceTarget, CaptionOverlayTarget (desktop_multi_window), ObsSettingsNotifier, OutputTargetSettingsNotifier, barrel (zip_broadcast.dart)
- Tests: 6 test files across zip_core and zip_broadcast; glados/mocktail/flutter_test conflict resolved via hide directives
- Lint cleanup: 0 errors, 0 warnings; 7 pre-existing implementation_imports infos remain (pre-Unit-3)
- Notable API discoveries: ObsWebSocket cannot be subclassed (tests cover timer paths only); DesktopMultiWindow.createWindow() returns WindowController not int; OverlayConfig has no toJson() (manual JSON encoding added)
**Context**: Unit 3 Code Generation — COMPLETE. aidlc-state.md updated. Next: Unit 4 (UI Prototypes).

---

## CONSTRUCTION - State Correction: Units 5 & 6 Retroactively Logged
**Timestamp**: 2026-04-25T00:00:00Z
**User Input**: "I want to stick to the correct approach defined in ai-dlc. Let's make sure we update our status documents in the repo, and get the code back on track with that approach."
**AI Response**: Identified that aidlc-state.md was stale — Units 5 and 6 were merged but not checked off; Build and Test stage had never been executed for Phase 1. Corrected state:
- Unit 5: Zip Captions App (S-09) — marked COMPLETE (merged PR #14)
- Unit 6: Zip Broadcast App (S-10) — marked COMPLETE (merged PR #15; 80 tests)
**Context**: State correction — no code changed; audit record added to reflect real completion order.

---

## CONSTRUCTION - Unit 7: Integration Milestones — Build and Test
**Timestamp**: 2026-04-25T00:00:01Z
**User Input**: (continuation of above — executing Build and Test stage for Phase 1)
**AI Response**: Executed Build and Test stage. Results:
- Static analysis: 0 issues across all 4 packages (melos run analyze)
- Unit tests: 457 passed, 0 failed (zip_core 313, zip_captions 64, zip_broadcast 80; zip_supabase N/A)
- Integration tests: 5 scenarios defined in integration-test-instructions.md; manual execution pending
- E2E / UI/UX: checklist defined in e2e-test-instructions.md against Phase 1 HTML prototypes; manual execution pending
- Files generated/updated: build-instructions.md, unit-test-instructions.md, integration-test-instructions.md (new), e2e-test-instructions.md (new), build-and-test-summary.md
- aidlc-state.md updated: Units 5+6 marked complete, Unit 7 Build and Test marked complete; Doc Refinement pending
**Context**: Unit 7 Build and Test — COMPLETE. Doc Refinement is the remaining gate before Phase 2 planning.

---

## CONSTRUCTION - Unit 7: Integration Milestones — Documentation Refinement
**Timestamp**: 2026-04-25T00:00:02Z
**User Input**: "approve and continue"
**AI Response**: Executed Documentation Refinement for Phase 1. Changes made:
- RIVERPOD_CONVENTIONS.md: added "List State Mutation Safety" section (`List.of()` snapshot pattern; ConcurrentModificationError prevention) and "Widget Test — Button Finders" section (`find.bySubtype<ButtonStyleButton>()` for FilledButton.icon variants)
- ARCHITECTURE.md: version 0.1.0 → 1.0.0; date 2026-03-26 → 2026-04-25; status updated to reflect Phase 1 complete
- docs/03-roadmap.md: version v0.2 → v0.3; date updated; Phase Overview table updated with Status column (Phase 0 ✓ Complete, Phase 1 ✓ Complete, Phase 2 In planning)
- docs/TEST_SETUP.md: fixed `melos run test` interactive-prompt issue; added `melos exec --no-fail-fast -- flutter test` as the non-TTY command; added explanatory note
- aidlc-state.md: Unit 7 marked fully COMPLETE; Current Stage updated to "Phase 1 COMPLETE"
**Context**: Unit 7 Documentation Refinement — COMPLETE. Phase 1 Construction fully closed. Ready for Phase 2 planning.

---
## CONSTRUCTION - Unit 7: PR #16 Review Feedback — Code Generation (Planning)
**Timestamp**: 2026-07-18T18:00:00Z
**User Input**: "Check PR #16 ... for review status and feedback. Pull any comments/requested changes via gh pr view 16 --comments and gh pr checks 16. If there's feedback, address it and push updates." followed by "Determine why the runner failed, we need to make sure that all actions work properly." followed by "Use the ai-dlc approach to respond to the PR feedback"
**AI Response**: Pulled PR #16 status via gh pr view/api/checks. Found reviewDecision=CHANGES_REQUESTED (CodeRabbit, 5 actionable comments across 4 files) and 2 failing CI checks (Analyze & Test lint failures; Windows Build Verify MSVC C2338 on local_auth_windows/permission_handler_windows). Root-caused Windows failure: windows-latest runner image now ships MSVC toolset that removed deprecated <experimental/coroutine> support; last green Windows Build Verify run was April 2026 on the same code path, confirming this is a runner/toolchain regression, not caused by this PR's diff. Created code generation plan `aidlc-docs/construction/plans/unit7-pr16-review-fixes-code-generation-plan.md` (9 steps: 6 review-comment fixes, lint fixes, Windows toolchain fix, verification) as a revision within Unit 7's existing Code Generation stage — no new Functional Design/NFR stages needed per Adaptive Workflow Principle.
**Context**: Unit 7 Code Generation — Planning (revision pass). Awaiting user approval before executing Part 2 (Generation).

---
## CONSTRUCTION - Unit 7: PR #16 Review Feedback — Code Generation (Approval)
**Timestamp**: 2026-07-18T18:05:00Z
**User Input**: "Approve — execute the plan"
**AI Response**: Plan approved. Proceeding to Part 2 (Generation) of `unit7-pr16-review-fixes-code-generation-plan.md`.
**Context**: Unit 7 Code Generation — Generation starting.

---
## CONSTRUCTION - Unit 7: PR #16 Review Feedback — Code Generation (Generation complete)
**Timestamp**: 2026-07-19T00:00:00Z
**User Input**: (execution of approved plan; no further user input during generation)
**AI Response**: Executed all 9 plan steps. Summary:
- Step 1: Added `_loadFuture` fence to `ObsSettingsNotifier` (broadcast_providers.dart), awaited in `update()`/`markConnectionVerified()`.
- Step 2: Fixed OBS toggle lockout in output_targets_panel.dart — `onToggle` now allows disabling even when unverified.
- Step 3: Reordered `_testConnection()` in settings_screen.dart so `markConnectionVerified()` persists before the `mounted` check.
- Step 4: Localized zb_nav_rail.dart nav labels via `ZipBroadcastLocalizations` (appTitleDefault/appTitleBroadcast/appTitleHistory), matching ZbAppShell's existing pattern.
- Step 5: SKIPPED as false positive — package imports can't address test/ files; matches 39 other test files' existing relative-import convention.
- Step 6: Added `sharedPreferencesProvider.overrideWithValue(prefs)` to audio_config_recording_integration_test.dart and caption_bus_flow_test.dart containers.
- Step 7: Fixed 10 lint infos in recording_pipeline_integration_test.dart (prefer_int_literals, lines_longer_than_80_chars).
- Step 8: Root-caused Windows CI failure to windows-latest runner's MSVC toolset dropping `<experimental/coroutine>` support. Applied `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` compile definition in zip_captions/windows/CMakeLists.txt's `APPLY_STANDARD_SETTINGS` (applies to all targets including local_auth_windows/permission_handler_windows plugins). Did not bump local_auth to 3.x (breaking API change, out of scope) since permission_handler_windows has no newer version anyway.
- Step 9: Verified — additional pre-existing lint issues surfaced in zip_broadcast test files once zip_captions's failure stopped masking them via fail-fast (obs_settings_connection_integration_test.dart: cascade_invocations, prefer_int_literals, avoid_redundant_argument_values, prefer_const_constructors); fixed via `dart fix --apply` + targeted `// ignore: cascade_invocations` comments (matching existing repo precedent in obs_websocket_target_test.dart). Final state: `melos run analyze` — 0 issues across all 4 packages. `flutter test` — zip_core 313 passed, zip_broadcast 93 passed, zip_captions 71 passed (zip_supabase has no test/ directory, pre-existing, unrelated).
**Context**: Unit 7 Code Generation (PR #16 revision) — COMPLETE. Ready to commit and push to `feature/phase1-integration-tests`, then re-check CI/CodeRabbit on PR #16.

---
## CONSTRUCTION - Unit 7: PR #16 Review Feedback — Follow-up nitpick
**Timestamp**: 2026-07-19T19:50:00Z
**User Input**: "check the PR again, there's a new reply we need to address"
**AI Response**: Re-checked PR #16. CI: Analyze & Test, Linux, iOS now passing; 4 of 5 original CodeRabbit findings marked "✅ Addressed in commit b12cb51" (the relative-imports one remains open as intentionally skipped). New CodeRabbit re-review (COMMENTED, not blocking) flagged a nitpick: the Windows coroutine-suppression define was applied globally via APPLY_STANDARD_SETTINGS instead of scoped to the two affected plugins. Fixed by reverting the global function change and instead applying target_compile_definitions directly to the local_auth_windows_plugin and permission_handler_windows_plugin targets (guarded with if(TARGET ...) for safety) after generated_plugins.cmake creates them. Committed (19cf2ca) and pushed.
**Context**: Unit 7 Code Generation (PR #16 revision) — follow-up nitpick addressed. Awaiting CI re-run.

---
## CONSTRUCTION - Unit 7: Handoff write
**Timestamp**: 2026-07-19T20:05:00Z
**User Input**: "yes" (confirming /handoff-write after PR #16 merge confirmation)
**AI Response**: Wrote session handoff. Note: the `obsidian-mcp` server was connected to an unrelated vault this session (returned notes from a different project entirely), so per user instruction, read/wrote the vault directly via the filesystem at `~/Documents/ai-dlc-vault` instead of the MCP tools. Updated `handoffs/unit7-pr-review.md` (status COMPLETE, full session summary of PR #16 fixes/merge) and `_current-context.md` (phase: Inception, stage: Requirements Analysis, unit: "Phase 2: Broadcasting & Transport", with a model-switch reminder to Opus per CLAUDE.md). Updated `aidlc-docs/aidlc-state.md` in-repo to record PR #16 merged and Phase 1 Construction fully complete.
**Context**: Unit 7 — CLOSED. Phase 1 Construction — FULLY COMPLETE. Next: Phase 2 Requirements Analysis (Inception phase, switch to Opus).

---

## PHASE 2 — Workspace Detection + Requirements Analysis (start)
**Timestamp**: 2026-07-19T21:00:00Z
**User Input**: "Start Phase 2 planning (Broadcasting & Transport) via the AI-DLC Requirements Analysis stage. Read _current-context.md in the vault first — it points to the Unit 7 handoff and docs/03-roadmap.md's Phase 2 section for scope (WebRTC + Supabase Realtime live broadcast, replacing v1's Socket.IO + PeerJS, stable broadcast URLs). Phase 1 is fully merged and closed; the caption-bus prerequisite is satisfied. Follow ai-dlc/aidlc-rules/aws-aidlc-rules/core-workflow.md for the Inception flow. Note the 3 flagged research spikes (Supabase Realtime channel limits, OBS WebSocket protocol, Coturn/TURN relay) — figure out whether they need to happen before or during Requirements Analysis."
**AI Response**: Loaded vault _current-context.md, handoffs/unit7-pr-review.md, docs/03-roadmap.md (Phase 2 section), ADR-008/011/006/009, extension opt-in files, aidlc-state.md. Workspace Detection: brownfield; Phase 1 Construction fully complete (PR #16 merged 2026-07-19); caption bus (ADR-008) exists in zip_core; OBS + browser-source output targets already shipped in Phase 1 Unit 6; no reverse engineering needed. Phase 2 is a new Inception cycle. Model: Opus (Inception phase per CLAUDE.md) — confirmed active. Spike-timing assessment: none of the 3 spikes (2.1 Supabase Realtime limits, 2.2 OBS WebSocket CC protocol, 2.3 Coturn/TURN) block Requirements Analysis — they validate feasibility/infra and inform Construction-phase NFR/Infrastructure Design, matching the Phase 1 precedent where spikes 1.1-1.3 ran as early Construction units. Recommended running them as early Phase 2 construction units (option B in the questions file), with Requirements Analysis proceeding now and flagging any requirement whose target depends on a spike outcome (e.g. concurrent-viewer NFR ← Spike 2.1). Determined requirements depth = Comprehensive (system-wide new feature, cross-phase dependencies, security/networking risk). Generated aidlc-docs/inception/requirements/phase2-requirement-verification-questions.md (12 questions incl. 2 extension opt-ins). GATE: awaiting user answers before generating requirements.md.
**Context**: Phase 2 Inception — Workspace Detection COMPLETE; Requirements Analysis in progress (Step 6 gate).

---

## PHASE 2 — Requirements Analysis (answers review + clarifications)
**Timestamp**: 2026-09-25T18:54:15Z
**User Input**: "using ai-dlc, I would like to review the phase 2 requirements verification questions, and begin the next piece of work"
**AI Response**: Reviewed all 12 answers in phase2-requirement-verification-questions.md (Q1:A, Q2:B, Q3:C, Q4:B, Q5:A, Q6:B, Q7:A, Q8:B, Q9:B, Q10:C with 100-200 viewer target, Q11:A, Q12:A). Accepted Q1, Q5, Q7, Q10, Q11, Q12 as-is; Security Baseline and PBT remain enabled (full rule files deferred to first constraining Construction stage per aidlc-project-rules/common/session-protocol.md). Contradiction/ambiguity analysis per question-format-guide.md found: (1) Q2:B pulled-forward auth vs Q9:B persistence deferred "until auth exists", plus ADR-011 permanent broadcast ID cannot be ephemeral-only; (2) Q2:B "minimal auth" undefined (mechanism; which Zip Broadcast features require sign-in; OAuth is security-critical requiring approach pre-approval); (3) Q8:B optional viewer sign-in has no Phase 2 function defined; (4) Q3:C deferred relay for lack of E2E encryption vs Q4:B local Wi-Fi WebSocket with same plaintext exposure, plus WebRTC host candidates already cover same-network delivery and web cannot host/consume local ws; (5) destination of deferred relay deliverables and exit criterion; (6) with relay deferred, Spike 2.1 no longer measures the 100-200 viewer bottleneck (broadcaster WebRTC fan-out), and at-capacity behaviour undefined; (7) Q6:B external display platform scope and likely new multi-window dependency. Created aidlc-docs/inception/requirements/phase2-clarification-questions.md (8 questions). GATE: awaiting clarification answers before generating phase2-requirements.md.
**Context**: Phase 2 Inception — Requirements Analysis, Step 6 gate (clarification round 1).

---

## PHASE 2 — Requirements Analysis (clarifications answered; requirements generated)
**Timestamp**: 2026-09-25T19:12:59Z
**User Input**: "I've filled in the answers"
**AI Response**: Read phase2-clarification-questions.md answers: CQ1:A (hybrid persistence: broadcast_id registry in Postgres + RLS, session state ephemeral in Realtime), CQ2:A (GoTrue with provider-agnostic OAuth, 1-2 providers), CQ3:A (sign-in required only for remote broadcasting), CQ4:A (viewer identity protocol-ready only; viewer sign-in UI Phase 3), CQ5:A (local Wi-Fi WebSocket deferred to Phase 5), CQ6:A (relay deliverables and exit criterion move to Phase 3), CQ7:A (Spike 2.1 re-scoped to broadcaster fan-out + signaling load; hard cap with "broadcast is full"), CQ8:A (external display Zip Broadcast desktop only). Re-validated: no remaining contradictions. Step 6 gate passed. Generated aidlc-docs/inception/requirements/phase2-requirements.md (Comprehensive depth: 10 FRs, 8 NFR groups, 3 spikes, deferred-scope table, doc updates, extension compliance, revised exit criteria, 4 assumptions to confirm). Updated aidlc-state.md with Phase 2 section. Next stage recommendation: User Stories (new user-facing features across Jordan and Sam personas). GATE: awaiting requirements approval.
**Context**: Phase 2 Inception — Requirements Analysis, Step 9 approval gate.

---

## PHASE 2 — Requirements Analysis (approval)
**Timestamp**: 2026-09-25T19:25:54Z
**User Input**: "approve and continue"
**AI Response**: Requirements approved; phase2-requirements.md accepted. Attempted to load User Stories rules and found .aidlc-rule-details (symlink to ai-dlc/aidlc-rules/aws-aidlc-rule-details) is broken: the ai-dlc submodule working tree was fast-forwarded at 2026-09-25 15:14 -0400 from the pinned b7161b66 to 60214a06 (435 commits ahead), and upstream no longer contains aidlc-rules/. Stopped per AGENTS.md "if blocked, stop and document the blocker"; asked user how to proceed.
**Context**: Phase 2 Inception — Requirements Analysis COMPLETE (approved). User Stories blocked on missing rule files.

---

## PHASE 2 — ai-dlc submodule restore
**Timestamp**: 2026-09-25T19:29:02Z
**User Input**: "Restore pinned commit (Recommended)" (answer to: ai-dlc submodule moved 435 commits ahead to 60214a06 and no longer contains aidlc-rules/; how to proceed?)
**AI Response**: Ran git -C ai-dlc checkout b7161b66 (the commit recorded by the monorepo). Submodule status now clean at b7161b66; .aidlc-rule-details resolves again. Adopting the restructured upstream ai-dlc is left as a separate task.
**Context**: Phase 2 Inception — blocker resolved.

---

## PHASE 2 — User Stories (Part 1: Planning)
**Timestamp**: 2026-09-25T19:29:02Z
**User Input**: (continuation of "approve and continue")
**AI Response**: Loaded inception/user-stories.md. Assessment: execute (new user features in both apps, multi-persona interaction Jordan/Sam, complex state logic) — aidlc-docs/inception/plans/phase2-user-stories-assessment.md. Created aidlc-docs/inception/plans/phase2-story-generation-plan.md with 7 questions (carry forward Phase 1 conventions; Sam remote-viewer scenario gap / proposed S3.6; milestone selection; prototype scope; security-critical review gates; infrastructure enabler stories; placement of failure-path/security ACs) and 15 generation steps. Phase 2 artifacts use phase2- prefix; story IDs continue from Phase 1 (S-11+, Proto-10+). GATE: awaiting answers.
**Context**: Phase 2 Inception — User Stories, Part 1 Planning (Step 7-8 gate).

---

## PHASE 2 — User Stories (Part 1: plan approval)
**Timestamp**: 2026-09-25T21:00:03Z
**User Input**: "done" (all 7 story-plan answers: A). Then, to approval prompt "Approve the story plan and start generating stories?": "Approve & generate". To "Line 1 of phase2-requirements.md now begins with 'ok' ... sign-off or stray?": "Stray: remove it".
**AI Response**: Analyzed answers (Step 9): no ambiguity; all match recommended options. Removed stray "ok" prefix from phase2-requirements.md heading. Plan approved; starting Part 2 generation.
**Context**: Phase 2 Inception — User Stories, Part 1 approved; Part 2 Generation starting.

---

## PHASE 2 — User Stories (Part 2: generation complete)
**Timestamp**: 2026-09-25T21:20:00Z
**User Input**: (tool rejection feedback) "Why are you using bash, when you should be able to work with any files in the working directory just by reading them? You keep pausing and waiting for me to grant permission to a bash script that you're using to read a file. That seems wrong"
**AI Response**: Switched to Read/Edit/Write for all file operations; saved as a feedback memory. Executed all 15 plan steps. Brownfield finding: Phase 1 CaptionOverlayTarget (desktop_multi_window, targetDisplayId) exists but never opens a window and cannot list displays; S-20 completes it, and FR-9.6 was added to phase2-requirements.md recording this. Generated aidlc-docs/inception/user-stories/phase2-stories.md: enablers S-11 (broadcast identity backend), S-12 (Coturn), S-13 (Realtime signaling), S-14 (WebRTC transport); features S-15 (auth), S-16 (remote output target), S-17 (session management), S-18 (capacity), S-19 (viewer), S-20 (external display); security reviews SR-01 (OAuth), SR-02 (RLS + Realtime authorization), SR-03 (server log config); prototypes Proto-10..15; milestones M-S2.2 (completed), M-S2.3 (Phase 2 slice), M-S3.6, M-REG-01; traceability matrix, dependency graph, INVEST table. Generated phase2-personas.md with draft S3.6 scenario for Documentation Refinement. GATE: awaiting user story approval.
**Context**: Phase 2 Inception — User Stories, Step 20-21 approval gate.

---

## PHASE 2 — User Stories (approval) + Workflow Planning
**Timestamp**: 2026-09-25T21:35:00Z
**User Input**: "approve and continue"
**AI Response**: User stories approved. Loaded inception/workflow-planning.md and phase1-execution-plan.md (format precedent). Generated aidlc-docs/inception/plans/phase2-execution-plan.md: risk High; Application Design EXECUTE (new cross-package components; transport abstraction must accommodate Phase 3/5 transports); Units Generation EXECUTE; Reverse Engineering SKIP; Operations SKIP (Coturn delivered for local stack; VPS/domain hosting out of scope). Preliminary construction: Spikes 2.1-2.3 plus 9 units (1 Prototypes; 2 Auth + SR-01; 3 Identity + Signaling + SR-02; 4 Coturn + SR-03; 5 WebRTC Transport + Remote Output + Capacity; 6 ZB Broadcast UI; 7 ZC Viewer; 8 External Display; 9 Integration Milestones). Package sequence zip_supabase -> local stack -> zip_core -> apps. Noted single-branch workflow (no worktrees) per project memory. Mermaid diagram with text alternative. GATE: awaiting execution plan approval.
**Context**: Phase 2 Inception — Workflow Planning, Step 9 approval gate.

---

## PHASE 2 — Workflow Planning (approval) + Application Design (plan)
**Timestamp**: 2026-09-25T21:45:00Z
**User Input**: "approve and continue"
**AI Response**: Execution plan approved. Loaded inception/application-design.md, Phase 1 application-design-plan.md and phase1-application-design.md (precedent), zip_captions and zip_core pubspecs (go_router present; supabase_flutter and flutter_webrtc not yet added). Created aidlc-docs/inception/plans/phase2-application-design-plan.md: 12 design steps, 6 mandatory artifacts (phase2- prefix), carried-forward constraints (plain Dart services behind providers, registry-managed targets, explicit side-effect calls, stable contracts unchanged, signaling behind an interface), and 6 questions: package placement; transport abstraction shape; broadcast vs recording lifecycle; viewer session and caption bus; Supabase client ownership; display enumeration dependency. Resolution mechanism, TURN credential issuance and OAuth flow left to Functional/Infrastructure Design under SR-01..03. GATE: awaiting answers.
**Context**: Phase 2 Inception — Application Design, Step 6-7 gate.

---

## PHASE 2 — Application Design (answers + generation)
**Timestamp**: 2026-09-25T22:10:00Z
**User Input**: "proceed" (plan answers: Q1 A, Q2 A, Q4 A, Q5 A, Q6 A; Q3: "It should be independent, so that broadcast can start without starting captions, but there should be a configuration option to provide the coupled start if a user desires. In the case where a broadcast exists but no active caption session is running, the UI for any connected user should render a message similar to the paused message, whereby it informs the user that there is no active text stream because the broadcast has paused captions. The broadcaster should be able to easily see a large notification that the captions are inactive when in an active broadcast with no live captioning sessions yet started.")
**AI Response**: Analyzed answers: Q3 custom answer is specific (independent lifecycles; opt-in coupled start defaulting off; viewer paused-captions message; broadcaster large captions-inactive notice); no follow-up needed. Read zip_core CaptionBus, CaptionEvent, CaptionOutputTarget, RecordingState, SttResult to align signatures. Generated aidlc-docs/inception/application-design/phase2-components.md, phase2-component-methods.md, phase2-services.md (flows F1-F8), phase2-component-dependency.md, phase2-application-design.md. Introduced CaptionActivity (active/paused/inactive) derived from existing SessionStateEvent and sent as a snapshot on viewer join. Applied Q3 revisions: phase2-requirements.md FR-6.7 (new) and FR-7.4; phase2-stories.md S-16, S-17, S-19, Proto-11, Proto-12, Proto-15. GATE: awaiting application design approval.
**Context**: Phase 2 Inception — Application Design, Step 12-13 approval gate.

---

## PHASE 2 — Application Design (approval) + Units Generation (Part 1 planning)
**Timestamp**: 2026-09-25T22:20:00Z
**User Input**: "proceed"
**AI Response**: Application design approved. Loaded inception/units-generation.md and Phase 1 unit-of-work-plan.md (precedent). Created aidlc-docs/inception/plans/phase2-unit-of-work-plan.md: 11 decomposition steps for 3 spikes + 9 units, 5 mandatory artifacts (phase2- prefix), and 5 questions: UI unit stage depth (Phase 1 precedent full stages); spike sequencing (per-unit dependencies); PR boundaries (one PR per unit per AGENTS.md vs bundling); Unit 5 size (keep vs split); spike code (throwaway vs seed). GATE: awaiting answers.
**Context**: Phase 2 Inception — Units Generation, Part 1 Step 5-6 gate.

---

## PHASE 2 — Units Generation (plan approval + generation)
**Timestamp**: 2026-09-25T22:35:00Z
**User Input**: "done" (answers Q1-Q5: all A). To approval prompt "Unit of work plan complete ... Ready to generate the unit documents?": "Approve & generate".
**AI Response**: Answers analyzed; no ambiguity. Generated aidlc-docs/inception/application-design/phase2-unit-of-work.md (Spikes 2.1-2.3 with deliverables/exit criteria, spike code in spikes/phase2/ never merged; Units 1-9 with packages, stories, components, stages; SR-01/02/03 approval gates before Code Generation of U2/U3/U4; stage summary table), phase2-unit-of-work-dependency.md (matrix, graph with text alternative, critical path, suggested single-branch build order, shared resources, testing checkpoints), phase2-unit-of-work-story-map.md (all 10 stories, 3 reviews, 6 prototypes, 4 milestones, 3 spikes assigned exactly once; FR/NFR/exit-criteria and persona mapping). GATE: awaiting units approval; next is CONSTRUCTION (switch to Sonnet per CLAUDE.md).
**Context**: Phase 2 Inception — Units Generation, Step 16-17 approval gate.

---

## PHASE 2 — Units Generation (approval) — Inception complete
**Timestamp**: 2026-09-26T01:08:26Z
**User Input**: "let's mark phase 2 inception as complete before I commit and push"
**AI Response**: Units approved. Marked Units Generation COMPLETE (approved) in aidlc-state.md, recorded Phase 2 Inception as COMPLETE, and set Current Stage to CONSTRUCTION Phase 2 — not started (next: Unit 1 Prototypes with Proto-10 first, then Spike 2.1, per the suggested build order in phase2-unit-of-work-dependency.md). Construction to run in a new session on Sonnet per CLAUDE.md model selection.
**Context**: Phase 2 Inception — Units Generation, Step 17 approval recorded; Inception → Construction transition.

---

## CONSTRUCTION - Unit 1: UI Prototypes — Code Generation Plan Approval Prompt
**Timestamp**: 2026-09-25T00:00:00Z
**AI Response**: Created `feature/phase2-unit1-prototypes` off `phase-2` (not `develop` — Phase 2 inception docs aren't merged to `develop` yet; user chose to branch off `phase-2` and merge to `develop` at a later checkpoint). Wrote `aidlc-docs/construction/plans/unit1-prototypes-code-generation-plan.md`: 7 steps (Proto-10 sign-in, Proto-11 broadcast setup, Proto-12 live dashboard, Proto-13 external display, Proto-14 join, Proto-15 viewer states, doc summary), each a standalone HTML/CSS file at `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/`, following the Phase 1 prototype design precedent (CSS custom properties + `data-theme` dark mode, responsive sidebar/drawer, `data-testid` automation hooks). No FD/NFR stages per the unit-of-work doc (Code Generation only, then per-prototype Human Review Gate). Prompted user for approval of the plan.
**Context**: Unit 1 Code Generation — Part 1 (Planning). Awaiting user approval before Part 2 (Generation).

---

## CONSTRUCTION - Unit 1: UI Prototypes — Code Generation Plan Approval
**Timestamp**: 2026-09-25T00:05:00Z
**User Input**: "approve and proceed"
**AI Response**: Plan approved. Proceeding to Part 2 (Generation), starting with Proto-10.
**Context**: Unit 1 Code Generation — Generation starting.

---

## CONSTRUCTION - Unit 1: Proto-10 Sign-In — Generated + Approved
**Timestamp**: 2026-09-25T00:10:00Z
**AI Response**: Generated `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/zip-broadcast-sign-in.html` — centered card (no nav shell), 3 switchable states (signed-out with provider buttons and remote-broadcasting-only copy, signed-in with account row and sign-out, auth-failure with alert + retry), theme toggle, `data-testid` on all interactive elements.
**User Input**: "approve"
**Context**: Unit 1 Code Generation — Step 1 (Proto-10) COMPLETE and approved; unblocks Unit 2 (Broadcaster Auth). Proceeding to Step 2 (Proto-11).

---

## CONSTRUCTION - Unit 1: Proto-11 Broadcast Setup — Generated + Approved
**Timestamp**: 2026-09-25T00:15:00Z
**AI Response**: Generated `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/zip-broadcast-setup.html` — app-shell layout, state switcher (default / validation-error / signed-out), session name field with inline validation, output target grid (no relay option), "start captioning when going live" toggle (off by default), stable URL + copy action, signed-out modal overlay.
**User Input**: "approve and proceed"
**Context**: Unit 1 Code Generation — Step 2 (Proto-11) COMPLETE and approved. Proceeding to Step 3 (Proto-12).

---

## CONSTRUCTION - Unit 1: Proto-12 Live Dashboard — Generated, Revised
**Timestamp**: 2026-09-25T00:20:00Z
**AI Response**: Generated `zip-broadcast-dashboard.html` (stat row, caption preview, single audio-level row, viewer list, blocking full-screen states for broadcast-full and start-failure).
**User Input (revision 1)**: Move audio level into the stat row as a third card; add a controls row (End Broadcast + pause/resume captioning) below the stat row and above the caption preview; replace the single audio-level row with a per-input list (name + own meter) where it used to sit; trim viewer-row spacing and drop the redundant "Viewer ·" label prefix.
**User Input (revision 2, mid-turn)**: Give the caption preview more visual priority; broadcast-full must not block the dashboard — show it as a non-blocking error banner like the captions-inactive warning banner, not a full-screen state.
**AI Response**: Reordered content to Live Captions (larger, bolder caption preview) → stat row (Viewers / Duration / Audio Level meter) → controls row (End Broadcast, Pause/Resume Captioning toggle) → Audio Inputs list (Built-in Microphone, USB Lapel Mic, each with its own meter) → compact Viewers list (no per-row "Viewer" prefix). Broadcast-full is now a `.banner.err` shown above the still-visible dashboard body, matching the captions-inactive `.banner.warn` shape; only start-failure (which precedes going live, so there's no dashboard yet) remains a blocking full-screen state.
**Context**: Unit 1 Code Generation — Step 3 (Proto-12) revised per feedback; awaiting review/approval.

---

## CONSTRUCTION - Unit 1: Proto-12 Live Dashboard — Revision 5 (Clear button)
**Timestamp**: 2026-09-25T00:35:00Z
**User Input**: "next to the pause/resume button, the user needs a button that can clear the text from the screen."
**AI Response**: Added a "🗑 Clear" button to the controls row next to Pause/Resume Captioning. Resets the caption preview to the empty placeholder state ("No captions yet — start captioning to show live captions here.").
**Context**: Unit 1 Code Generation — Step 3 (Proto-12) revised; awaiting review/approval.

---

## CONSTRUCTION - Unit 1: Proto-12 Live Dashboard — Revision 6 (explicit label)
**Timestamp**: 2026-09-25T00:36:00Z
**User Input**: "The button needs to be explicit \"Clear caption text\""
**AI Response**: Relabeled the button "🗑 Clear Caption Text".
**Context**: Unit 1 Code Generation — Step 3 (Proto-12) revised; awaiting review/approval.

---

## CONSTRUCTION - Unit 1: Proto-12 Live Dashboard — Approved
**Timestamp**: 2026-09-25T00:38:00Z
**User Input**: "approved"
**Context**: Unit 1 Code Generation — Step 3 (Proto-12) COMPLETE and approved (unblocks half of Unit 6's prototype dependency, pending Proto-11 which is already approved). Proceeding to Step 4 (Proto-13).

---

## CONSTRUCTION - Unit 1: Proto-13 External Display Controls — Generated
**Timestamp**: 2026-09-25T00:40:00Z
**AI Response**: Generated `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/zip-broadcast-external-display.html` — display list (Built-in Display, Dell U2720Q Projector) with per-display enable/disable toggle, active-state pill, caption position selector (top/bottom), and a 16:9 projector mock rendering the borderless caption overlay at projector scale. State switcher: default (no active display, placeholder preview), active (projector enabled, caption preview shown), disconnected (error banner + disconnected meta + placeholder preview).
**Context**: Unit 1 Code Generation — Step 4 (Proto-13) COMPLETE; awaiting review/approval. Unblocks Unit 8 (External Display) independently of the rest of Unit 1.

---

## CONSTRUCTION - Unit 1: Proto-13 External Display Controls — Approved
**Timestamp**: 2026-09-25T00:42:00Z
**User Input**: "approve"
**Context**: Unit 1 Code Generation — Step 4 (Proto-13) COMPLETE and approved; unblocks Unit 8 (External Display). Proceeding to Step 5 (Proto-14).

---

## CONSTRUCTION - Unit 1: Proto-14 Join Broadcast — Generated
**Timestamp**: 2026-09-25T00:45:00Z
**AI Response**: Generated `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/zip-captions-join.html` — centered card (zip_captions branding), broadcast ID/URL input, invalid-input state with inline error, connecting state (disabled input, spinner button). Responsive from mobile to desktop widths.
**Context**: Unit 1 Code Generation — Step 5 (Proto-14) COMPLETE; awaiting review/approval.

---

## CONSTRUCTION - Unit 1: Proto-14 Join Broadcast — Approved
**Timestamp**: 2026-09-25T00:47:00Z
**User Input**: "approve"
**Context**: Unit 1 Code Generation — Step 5 (Proto-14) COMPLETE and approved. Proceeding to Step 6 (Proto-15, last prototype).

---

## CONSTRUCTION - Unit 1: Proto-15 Live Viewer States — Generated
**Timestamp**: 2026-09-25T00:50:00Z
**AI Response**: Generated `aidlc-docs/construction/phase2-unit1-prototypes/prototypes/zip-captions-viewer-states.html` — all 8 states switchable: connecting (spinner), live, captions-paused-by-broadcaster (inline notice + dimmed last segment), reconnecting (inline notice + dimmed last segment), not-currently-broadcasting, broadcast-ended, broadcast-full (with retry), cannot-connect-with-reason (with retry). Each state distinguishable by icon + status-indicator text + copy, not color alone (per acceptance criteria). Live captions use the Phase 1 caption rendering style from `zip-captions-recording.html` (on-surface text, no black bar) scaled up (24px) since this is the viewer's primary content, not a secondary preview panel.
**Context**: Unit 1 Code Generation — Step 6 (Proto-15) COMPLETE; awaiting review/approval. This is the last of the 6 Unit 1 prototypes.

---

## CONSTRUCTION - Unit 1: Proto-15 — Render controls added; pop-out window backlogged
**Timestamp**: 2026-09-25T00:55:00Z
**User Input**: "Live view should have render controls, and user should be able to pop out into a separate window" → asked which to do for the pop-out request (backlog / mock in prototype / other) → "Backlog it (Recommended)" → clarified mid-turn: "I mean the captions should be able to be 'popped out' into a smaller floating window"
**AI Response**: Render controls are scoped (FR-7.3: viewer's own text size, font, contrast, flow direction) — added a control bar to the caption view in `zip-captions-viewer-states.html` with Size (S/M/L/XL), Font (Sans/Serif), and Flow (Down/Up) chips, wired to restyle the caption body live. Pop-out-to-floating-window is not in S-19/FR-7.1-7.6/`BroadcastViewerScreen`'s design — logged as a Backlog entry in `aidlc-state.md` with the clarified PiP-style intent, flagged for Unit 7 Functional Design (FR-9.5 requires approval + justification if it needs a new dependency). Not implemented in the prototype.
**Context**: Unit 1 Code Generation — Step 6 (Proto-15) revised; awaiting review/approval.

---

## CONSTRUCTION - Unit 1: Proto-15 — Flow-direction stacking corrected (revision 1)
**Timestamp**: 2026-09-25T01:00:00Z
**User Input**: "when captions direction is toggled to be bottom-up, the scroll order must show the live results at the bottom of the screen, with the segments shown above it, scrolling up as they arrive." followed mid-turn by: "when caption direction is toggled to be top-down, the live results must be pinned to the top, with segments organized most recent above older"
**AI Response**: Replaced the initial (incorrect) `column-reverse` up-flow rule with two explicit, named modifiers on `.caption-body`: `.flow-down` (`column-reverse` + `justify-content: flex-end`) puts the live segment at the top with older segments stacking downward below it; `.flow-up` (normal `column` + `justify-content: flex-end`) keeps chronological top-to-bottom order with the live segment pinned at the bottom and older segments stacking upward above it. Set `flow-down` as the caption body's default class (matching the render control's default-selected "↓ Down" chip) and updated `setCaptionFlow()` to swap between the two classes explicitly rather than toggling one class's presence.
**Context**: Unit 1 Code Generation — Step 6 (Proto-15) revised; awaiting review/approval.

---

## CONSTRUCTION - Unit 1: Proto-12 Live Dashboard — Revision 3
**Timestamp**: 2026-09-25T00:25:00Z
**User Input**: "add a view where captions are inactive at the start of the broadcast, and thus no live captions text would render"
**AI Response**: Added a 5th switchable state, "Captions inactive (start)", distinct from the existing captions-inactive (mid-broadcast pause) state: the caption preview shows an empty/placeholder message ("No captions yet — start captioning to show live captions here", italicized/muted) instead of a frozen last-caption, the warning banner text says captioning "hasn't started yet" rather than "is not running", and the captioning control reads "Start Captioning" instead of "Resume Captioning". The existing mid-broadcast captions-inactive state keeps showing the last real caption text (frozen, not italicized) to distinguish "paused after running" from "never started".
**Context**: Unit 1 Code Generation — Step 3 (Proto-12) revised; awaiting review/approval.

---

## CONSTRUCTION - Unit 1: Proto-12 Live Dashboard — Caption attribution deferred to backlog
**Timestamp**: 2026-09-25T00:32:00Z
**User Input**: "The user also needs to be able to configure caption attribution, so that the audio input label (or perhaps a different label such as 'speaker name') can be prepended to the text, in order to differentiate speakers." ... "If that's scope creep, let's not worry about it just yet, but put it in a backlog to address in future"
**AI Response**: Not implemented in the prototype. Logged as a Backlog entry in `aidlc-docs/aidlc-state.md` (Phase 2 Construction section): whether the per-input speaker label should be prepended as caption text (vs. today's Phase 1 scope of color/indicator-only visual distinction) is an open design question for Unit 6 Functional Design, since it may touch shared zip_core caption rendering.
**Context**: Unit 1 Code Generation — Step 3 (Proto-12); no prototype change from this request. Proceeding with the audio-input enable/disable toggle only.

---

## CONSTRUCTION - Unit 1: Proto-12 Live Dashboard — Revision 4 + scope question
**Timestamp**: 2026-09-25T00:30:00Z
**User Input**: "Each individual audio input also needs a toggle to enable/disable the audio input from adding captions to the screen. Have we scoped concurrent transcription from multiple inputs?"
**AI Response**: Confirmed concurrent multi-input transcription is already scoped and built — Phase 1 S-06 (`aidlc-docs/inception/user-stories/stories.md`): each configured audio input runs its own STT engine instance, `SttResult` carries a source identifier, and the caption bus renders captions from each source with a distinct visual style. This is existing zip_core/zip_broadcast functionality (Phase 1 Unit 2, COMPLETE), not new Phase 2 work — the dashboard's Audio Inputs list surfaces already-configured inputs. Added a per-input toggle (small switch + "Captioning"/"Muted" status label) to each row in `zip-broadcast-dashboard.html`; muted rows dim to indicate they're excluded from captioning while still showing their live audio level.
**Context**: Unit 1 Code Generation — Step 3 (Proto-12) revised; awaiting review/approval.

---

## CONSTRUCTION - Unit 1: Proto-15 — Flow direction verified against spec
**Timestamp**: 2026-09-25T01:03:00Z
**User Input**: "you can read the requirements for clarification, there's specific detail available in the repo to clarify the correct behaviour I expect to see" ... "that's looking correct now"
**AI Response**: Found the exact spec at `aidlc-docs/inception/user-stories/stories.md` lines 146-152 (Phase 1 `ScrollDirection`, FR-4.2): "scroll direction bottom-to-top → new text appears at the bottom and older text scrolls upward" / "scroll direction top-to-bottom → new text appears at the top and older text scrolls downward". The current `.flow-down`/`.flow-up` CSS in `zip-captions-viewer-states.html` already matched this exactly (no code change needed): Down = top-to-bottom (live pinned top, older pushed down via `column-reverse` + `justify-content: flex-end`); Up = bottom-to-top (live pinned bottom, older pushed up via normal `column` + `justify-content: flex-end`). User confirmed correct.
**Context**: Unit 1 Code Generation — Step 6 (Proto-15) — flow-direction behavior confirmed correct against the Phase 1 `ScrollDirection` spec (FR-7.3 reuses it for Phase 2). Awaiting final approval of Proto-15.

---

## CONSTRUCTION - Unit 1: Proto-15 — Reconnecting banner uses spinner, not icon
**Timestamp**: 2026-09-25T01:06:00Z
**User Input**: "the reconnecting banner shouldn't use an icon, it should show a spinner similar to the connecting screen, to show that it's attempting an action"
**AI Response**: Added a small spinner variant (`.spinner-sm`, 16px) reusing the connecting screen's spin animation. The reconnecting inline notice now shows this spinner instead of the ↻ icon; the paused notice is unaffected and still shows its ⏸ icon (that's a static state, not an in-progress action). Top-bar status pill text ("↻ Reconnecting") left as-is since the request was specific to the banner.
**Context**: Unit 1 Code Generation — Step 6 (Proto-15); awaiting review/approval.

---

## CONSTRUCTION - Unit 1: Proto-15 — Reconnection failure behavior clarified
**Timestamp**: 2026-09-25T01:10:00Z
**User Input**: "what will the user see when reconnection fails?"
**AI Response**: Checked `phase2-stories.md`: S-19's acceptance criteria (line 477-479) only specify the success path ("if connectivity returns within the reconnection window TBD/Spike 2.1, the viewer rejoins automatically"); the 8 named viewer states are stated as exhaustive, with no separate "reconnection failed" state. Asked the user how to represent this; they chose reusing "cannot connect" with a specific reason. Implemented: added a prototype-only link inside the reconnecting banner ("simulate reconnection window expiring") that transitions to the existing cannot-connect full-state, but with a distinct reason string ("Lost connection to the broadcast and couldn't reconnect...") versus the initial-join failure reason, demonstrating that one state can carry different specific reasons per its acceptance criterion ("'cannot connect' states its specific reason").
**Context**: Unit 1 Code Generation — Step 6 (Proto-15); awaiting review/approval.

---

## CONSTRUCTION - Unit 1: Proto-15 Approved; All Prototypes Complete
**Timestamp**: 2026-09-25T01:12:00Z
**User Input**: "ok, ui approved"
**AI Response**: Proto-15 approved (last of 6 prototypes). Wrote Step 7 documentation summary at `aidlc-docs/construction/phase2-unit1-prototypes/code/unit1-summary.md` (file mapping, downstream unblocks, notable review outcomes, backlog items, open questions). All 7 plan steps in `unit1-prototypes-code-generation-plan.md` now marked complete.
**Context**: Unit 1 Code Generation — all steps COMPLETE. Presenting unit completion message; awaiting Step 15 human approval to close Unit 1 and move to Unit 2 (Broadcaster Auth).

---

## CONSTRUCTION - Unit 1: Complete — Approved, holding for permission to proceed
**Timestamp**: 2026-09-25T01:15:00Z
**User Input**: "yes, unit 1 complete. update the status, but wait to proceed until i give you permission"
**AI Response**: Unit 1 (UI Prototypes) approved and marked COMPLETE in `aidlc-docs/aidlc-state.md` (top-level Current Stage and the Phase 2 Construction checklist). Per explicit instruction, holding here — not starting Spike 2.1 or Unit 2 until the user gives the go-ahead.
**Context**: Unit 1 — CLOSED. Awaiting user permission to begin the next work item (Spike 2.1, per the suggested build order in phase2-unit-of-work-dependency.md).

---

## CONSTRUCTION - Unit 1: PRs opened
**Timestamp**: 2026-09-25T01:20:00Z
**User Input**: "actually, I think maybe it makes more sense to open two prs, one from phase-2 to develop, and one from phase-2-unit-1 to phase-2" → "yes" (confirming to proceed)
**AI Response**: Opened PR #18 (`phase-2` → `develop`, Phase 2 Inception) and PR #19 (`feature/phase2-unit1-prototypes` → `phase-2`, Unit 1 UI Prototypes). Both branches were already committed and pushed to origin from earlier in this session. `phase-2` now serves as the phase-level integration branch that Construction units PR into, merged to `develop` separately/periodically.
**Context**: Unit 1 — PRs open, awaiting review/merge. Holding per prior instruction; not starting Spike 2.1 or Unit 2 until the user gives permission.

---

## CONSTRUCTION - Unit 1: Local Build & Test Verification
**Timestamp**: 2026-09-25T01:25:00Z
**User Input**: "we should do the build and test verification locally too"
**AI Response**: Ran `melos run analyze` (`dart analyze --fatal-infos`) — clean, 0 issues across all 4 packages (zip_core, zip_captions, zip_broadcast, zip_supabase). Ran `flutter test` per package — zip_core 316 passed, zip_captions passed, zip_broadcast 93 passed; zip_supabase has no `test/` directory (pre-existing condition, unrelated to Unit 1, already noted in earlier Phase 1 audit entries). Expected result since Unit 1 is docs-only (HTML prototypes, no application code) — this is a regression check, not new coverage. Attempted to validate the 6 prototype HTML files with `tidy` via Bash; user corrected this as a file-inspection task that should not go through Bash per standing instruction (Bash reserved for git/flutter/gh). Skipped external HTML linting; user confirmed the Dart/Flutter baseline is sufficient.
**Context**: Unit 1 — build and test verification complete, all green (baseline unaffected). Holding on Spike 2.1 / Unit 2 per prior instruction.

---

## CONSTRUCTION - Unit 1: PR #19 conflict resolved (rebase after squash-merge)
**Timestamp**: 2026-09-25T01:30:00Z
**User Input**: "one pr merged, the other has conflicts"
**AI Response**: Diagnosed: PR #18 (`phase-2` → `develop`) was squash-merged as a new commit `3e703f8` (distinct SHA from `phase-2`'s original `10efc8c`, though identical content); GitHub then auto-retargeted the still-open PR #19 from `phase-2` (deleted after merge) to `develop`. Because the SHA changed, git's merge-base for PR #19 no longer included the Phase 2 Inception content, producing add/add conflicts (worst on `audit.md`/`aidlc-state.md`, which differ between the two copies). Fix: stashed a pending uncommitted `audit.md` edit, rebased `feature/phase2-unit1-prototypes` onto the new `origin/develop` (applied cleanly — git recognized `10efc8c`'s content as already present and skipped it, replaying only the Unit 1 commit), force-pushed (`--force-with-lease`) with prior confirmation, and restored the stashed edit. PR #19 now shows `MERGEABLE` with a clean diff containing only the 10 Unit 1 files.
**Context**: Unit 1 — PR #19 conflict resolved, ready to merge. Holding on Spike 2.1 / Unit 2 per prior instruction.

---

## CONSTRUCTION - Unit 1 closed; Spike 2.1 starting
**Timestamp**: 2026-09-26T00:00:00Z
**User Input**: "ok, phase 2 step 1 complete, prs merged, let's create a new branch and start on the next piece"
**AI Response**: Confirmed both PRs merged into `develop` (#18 `3e703f8`, #19 `f711267`). Checked out and pulled `develop`, created `spike/2.1-broadcaster-fanout-signaling` off it (per `CONTRIBUTING.md`'s `spike/<spike-id>-short-name` convention; no worktree, per standing preference). Updated `aidlc-state.md`: Unit 1 marked fully closed (PR merged), Spike 2.1 (Broadcaster Fan-Out and Signaling Load) marked in progress. Per `phase2-unit-of-work.md`, spike code goes in `spikes/phase2/` and is never merged; only the report at `aidlc-docs/construction/spikes/spike-2.1-report.md` will be docs-only PR'd to `develop`.
**Context**: Phase 2 Construction — Spike 2.1 starting. Scope: (1) broadcaster fan-out CPU/memory/latency with N concurrent WebRTC data channels up to 200 across macOS + one of Windows/Linux + web; (2) self-hosted Supabase Realtime signaling/presence load at 200 joining viewers. Must complete before Units 3 and 5.

---

## CONSTRUCTION - Spike 2.1: Harness Built (Plan/Harness, Human Runs)
**Timestamp**: 2026-09-26T00:15:00Z
**User Input**: Chose "I'll write the plan/harness, you run it" for Spike 2.1, given it needs real multi-platform load testing this session can't execute.
**AI Response**: Built throwaway harness in `spikes/phase2/` (never merged, per Q5:A): (1) `fanout/signaling_server/` — minimal Node.js WebSocket signaling relay (not the real SignalingService, which doesn't exist yet since Unit 3 depends on this spike); (2) `fanout/broadcaster_app/` — a minimal Flutter app using `flutter_webrtc` that opens one data channel per connecting viewer, sends a synthetic caption payload once per second per channel (matching real cadence), self-reports RSS memory and per-viewer join-to-first-message latency (CPU sampled externally per the runbook, since in-process CPU measurement is unreliable); (3) `fanout/viewer_swarm/` — a Node.js synthetic viewer swarm (`wrtc`) that joins N viewers ramped 100ms apart and reports latency percentiles; (4) `realtime_load/` — a Node.js script joining N concurrent Supabase Realtime channels with presence tracking against the local stack, measuring join and presence-sync time. Wrote `spikes/phase2/README.md` as the full runbook (prerequisites, per-platform run steps, `docker stats` sampling, deliverables checklist) and pre-filled `aidlc-docs/construction/spikes/spike-2.1-report.md` with methodology, risk assessment, and TBD measurement tables for N = 25/50/100/150/200 across macOS, Windows-or-Linux, and web.
**Context**: Spike 2.1 — harness and report template complete on branch `spike/2.1-broadcaster-fanout-signaling`; none of this has been executed (requires the user to actually run it across platforms). Awaiting user review of the harness before running, or direction on next steps.

---

## CONSTRUCTION - Spike 2.1: Qwen delegation considered and declined; harness run directly (macOS, partial)
**Timestamp**: 2026-09-26T00:30:00Z
**User Input**: "Can we instruct qwen to run this test using opencode headless?"
**AI Response**: Investigated feasibility. Found `opencode/zip-builder.prompt.md` (the actual Qwen agent instructions) explicitly forbids running `flutter run` and models one-shot bounded sessions, not supervision of long-lived interactive processes — a hard mismatch with what running this harness requires. User chose to have Claude run it directly instead of loosening the builder agent's constraints. Adapted `broadcaster_app/lib/main.dart` for headless automation: `--dart-define` flags (RELAY_URL, BROADCAST_ID, AUTO_CONNECT, TEST_DURATION_SECONDS, RESULTS_FILE), auto-connect on first frame, RSS sample history, and self-terminating exit(0) after writing a results JSON — so the app needs no manual UI interaction.
**Context**: Spike 2.1 — proceeding to actually run the macOS + web + Node.js legs directly via Bash on this machine, per user's chosen approach.

---

## CONSTRUCTION - Spike 2.1: macOS harness debugged and validated (N=25, N=50); key finding surfaced
**Timestamp**: 2026-09-26T01:15:00Z
**AI Response**: Ran the harness end-to-end on macOS. Found and fixed 3 real bugs along the way: (1) `wrtc`'s npm install fails here (needs `node-pre-gyp`) — swapped to `node-datachannel` and rewrote `viewer_swarm/swarm.js` for its callback-based API (the documented fallback in the README worked as planned); (2) the macOS Runner's default entitlements lack `com.apple.security.network.client` (blocked outbound WebSocket) and enforce the App Sandbox (blocked writing the results file to `/tmp`) — fixed both `DebugProfile.entitlements` and `Release.entitlements`; (3) `node-datachannel`'s `cleanup()` segfaults on process exit (native addon teardown issue) — results are written before it runs, so no data loss; worked around by skipping `cleanup()`. Ran `flutter create --platforms=macos,windows,linux,web .` in `broadcaster_app/` since it was hand-written without platform scaffolding. Validated the full pipeline with a 10-viewer smoke test (10/10 succeeded), then real measurements at N=25 (24/25 succeeded) and N=50 (37/50 succeeded) against a live broadcaster instance. **Key finding**: join success rate degrades with N (100% → 96% → 74%) while the broadcaster's own log reports 100% of data channels reaching "open" at every N — the gap is post-connection, not the broadcaster refusing connections. Leading hypothesis: public STUN server (`stun.l.google.com`) contention under near-simultaneous ICE gathering from many peer connections on one host. Recommended investigating this (e.g. testing against a local STUN server, which Spike 2.3's Coturn work provides anyway) before running N=100/150/200, since scaling into the same unresolved bottleneck wouldn't add new information about the broadcaster itself. Also noted a methodology gap: the viewer swarm closes connections immediately after each resolves, so CPU/memory were only captured as post-hoc snapshots (2.6% CPU, ~342MB RSS after N=50), not true sustained-peak measurements — flagged a `--dwellMs` fix needed before further runs. Updated `spike-2.1-report.md` with real data, the finding, updated risk assessment, and a concrete "Next Steps" section. Updated `aidlc-state.md` accordingly. Stopped all background processes (broadcaster app, signaling relay) cleanly.
**Context**: Spike 2.1 — partial completion (macOS N=25/50 only). Windows/Linux leg, web leg, Realtime load test, N=100/150/200, and the STUN root-cause investigation remain. Awaiting user direction on how to continue.

---

## CONSTRUCTION - Spike 2.1: STUN hypothesis tested and ruled out; root cause narrowed to SCTP/DCEP
**Timestamp**: 2026-09-26T01:45:00Z
**User Input**: "are we blocked by this?" → confirmed no (Unit 2 only depends on Proto-10, not Spike 2.1; Spike 2.1 gates Units 3 and 5 specifically) → "finish the spike now"
**AI Response**: Made `STUN_URL`/`--stun` configurable in both the broadcaster app and `viewer_swarm/swarm.js` (previously hardcoded to `stun.l.google.com`). Started a local coturn STUN server via Docker (`coturn/coturn`, port 3478) and reran N=50 pointed at it: got 39/50 (78%) success — statistically the same as the public-STUN run (37/50, 74%). **This rules out STUN server contention as the cause.** Added per-viewer connection-state instrumentation to `swarm.js` (`onStateChange`, `onIceStateChange`, `onSignalingStateChange`, `onGatheringStateChange`) and reran N=50 again: the state trail shows every failed viewer reaches `ice: completed` and `pc: connected` within ~60ms, identical to succeeded viewers — ICE/DTLS transport establishment is not the bottleneck. The actual stall is downstream at the SCTP/DCEP (data channel establishment protocol) layer: a `DataChannel.readyState` can flip to "open" on the *creating* side once its local SCTP stream is ready, without the handshake having completed with the remote peer — meaning the broadcaster logging "100% channels open" doesn't mean 100% are usable. This points at the broadcaster's own SCTP/DCEP handling under concurrent, unpaced channel creation (it creates a channel as fast as `viewer-joined` events arrive) as the likely root cause — inside the spike's actual target (broadcaster fan-out capacity), not a testing artifact. Not yet fully confirmed. Cleaned up: removed the leftover `flutter create` default widget test and two `prefer_const_constructors` infos from `broadcaster_app` (now analyzes clean), stopped the coturn container, signaling relay, and broadcaster app. Updated `spike-2.1-report.md` (Executive Summary, Fan-Out Measurements table with the second N=50 row, Risk Assessment, Exit Criteria, Next Steps) and `aidlc-state.md` with the narrowed root cause.
**Context**: Spike 2.1 — root cause narrowed but not fully confirmed. Remaining: confirm SCTP/DCEP hypothesis (libwebrtc-side logging or pace broadcaster channel creation and retest), `--dwellMs` fix for sustained CPU/mem sampling, then N=100/150/200, Windows/Linux leg, web leg, Realtime load test.

---

## CONSTRUCTION - Spike 2.1: Pacing experiment — inconclusive; stopping here for this session
**Timestamp**: 2026-09-27T00:00:00Z
**AI Response**: Implemented the Next Steps' pacing experiment: added `CHANNEL_CREATION_PACING_MS` to the broadcaster (serializes `viewer-joined` handling through a chained `Future` instead of letting concurrent events race into `createPeerConnection`/`createOffer`). Reran N=50 at 50ms pacing (42/50, 84%) and 150ms pacing (39/50, 78%) — no monotonic trend versus the unpaced baseline (37-39/50, 74-78%), and with only ~50 trials per configuration this is plausibly within normal run-to-run noise rather than a confirmed causal fix. Reported this honestly as inconclusive rather than claiming pacing as a fix. Updated `spike-2.1-report.md` (new measurement rows, Executive Summary, Risk Assessment, Next Steps now recommending repeated trials for statistical confidence or direct libwebrtc-side DCEP logging instead of further black-box parameter sweeps) and `aidlc-state.md`. Cleaned up all background processes and the coturn Docker container.
**Context**: Spike 2.1 — root cause narrowed to the SCTP/DCEP layer but not confirmed or fixed. Stopping active investigation here for this session given diminishing returns from further black-box experimentation without lower-level instrumentation. Remaining: statistically-powered pacing trials or libwebrtc logging, `--dwellMs` fix, N=100/150/200, Windows/Linux leg, web leg, Realtime load test. Awaiting user direction — continue the deeper investigation now, or pause Spike 2.1 here and revisit later (recall: Unit 2 can proceed independently, per the earlier "are we blocked" discussion).

---

## CONSTRUCTION - Spike 2.1: Paused; interim maxViewers=50 accepted
**Timestamp**: 2026-09-27T00:15:00Z
**User Input**: Asked what pausing Spike 2.1 would affect downstream (answered: blocks Unit 3 directly, cascading to Unit 5, 6, 7, 9; does not block Unit 2, Spike 2.3, Unit 4, Unit 8). Asked how v1's WebRTC approach compares (researched via agent: v1 used Socket.IO + PeerJS signaling, public STUN only, no TURN, manual join codes; no documented viewer-capacity numbers ever existed for v1; the core fan-out shape — one broadcaster process holding N direct data channels — is unchanged in Phase 2, so the SCTP/DCEP ceiling found in this spike may be a pre-existing, previously-unmeasured limitation rather than a regression). Then: "Okay, so let's pause spike 2.1 here and consider a tentative cap of 50 viewers per broadcast, defined as a project constant... Once we have an initial build available for beta testing, we can look at running some more tests to see what the real world limits are."
**AI Response**: Paused Spike 2.1. Recorded `BroadcastLimits.maxViewers = 50` as an interim, explicitly-revisable project constant in `spike-2.1-report.md` (Status, Executive Summary, Recommendations, Exit Criteria all updated) and `aidlc-state.md`, with the caveat made explicit: this is not evidence of safety at that scale — the harness itself never demonstrated 100% success even at N=50 (best run 84%) — it's a conservative placeholder pending real beta data. Flagged to the user that `presenceTimeout`, `reconnectWindow`, and the NFR-1.3 timings remain fully open (the Realtime signaling/presence leg was never run) and Unit 3/5 will need interim values for those too, or must handle them as open design questions when reached.
**Context**: Spike 2.1 — PAUSED. Unit 3 (Identity + Signaling) is now unblocked on the `maxViewers` front but still needs presenceTimeout handled somehow. Next: Unit 2 (Broadcaster Auth), per the build order, with Spike 2.1 resumable later (post-beta, per Unit 9, or sooner if needed).

---

## CONSTRUCTION - Spike 2.1: Realtime load test attempted — 7 real bugs fixed, blocked on JWT signature issue; interim timings set
**Timestamp**: 2026-09-27T02:00:00Z
**User Input**: "Let's resolve those unknown timings right now, if possible." Then, mid-investigation, after finding the local Supabase stack had never been fully bootstrapped: chose "Reset the volume" for a stale-password Postgres volume, "Try a newer image tag" for a suspected broken pinned image version (later found to be a false lead), and finally "Use documented defaults instead" once a JWT signature issue in Realtime's compiled internals proved unresolvable without source access.
**AI Response**: Attempted to run `spikes/phase2/realtime_load/` against the local Supabase stack. Found and fixed 7 real, previously-latent bugs in tracked infrastructure files (`packages/zip_supabase/docker-compose.yml`, `volumes/api/kong.yml`, `migrations/20260326000000_initial.sql`), none related to this spike specifically: (1) the `db` service's migration volume mount replaced the base `supabase/postgres` image's own bootstrap directory entirely, skipping base schema/role setup — fixed by mounting the one migration file individually; (2) the base image never sets passwords for `authenticator`/`supabase_auth_admin`/`supabase_storage_admin` — added `ALTER ROLE` statements; (3) `realtime`'s `DB_AFTER_CONNECT_QUERY` referenced `_realtime` instead of the actual `realtime` schema; (4)-(6) `rest`, `meta`, and `storage` healthchecks used missing tools (`curl`, `wget`) or `localhost` resolving to `::1` ahead of the IPv4-only bound server — fixed with `/dev/tcp`, `node`, and explicit `127.0.0.1` respectively; (7) `kong.yml`'s realtime upstream hostname didn't match the compose service name, and since Realtime resolves its tenant from the request's Host header, fixed via a network alias (`realtime-dev.supabase-realtime`) rather than just renaming the URL. Also upgraded the Supabase CLI (brew, 2.75.0→2.118.0) and swapped the pinned `supabase/postgres` image tag, both later shown unnecessary once the real root causes were found. With all 7 fixed, the stack starts cleanly through Kong except for one remaining issue: the auto-seeded Realtime tenant's `jwt_secret` (correctly sourced from `API_JWT_SECRET`, matching the project's `.env`) still fails signature validation against the standard local-dev anon key, confirmed even after a clean reseed by reading Realtime's actual seed script (`/app/lib/realtime-2.76.5/priv/repo/seeds.exs`) inside the container. This is a compiled-release internal (Joken/JWT verification path) with no accessible source — stopped rather than reverse-engineer further. Per user decision, set interim/tentative values instead of measured ones: `presenceTimeout = 60s` (2x Phoenix Channels' documented 30s heartbeat default), `reconnectWindow = 120s` (UX judgment — covers a mobile network handoff without holding a capacity slot indefinitely), NFR-1.3 join-to-first-caption ≤3s and reconnection ≤5s (standard real-time-app UX targets). Updated `spike-2.1-report.md` (Status, Executive Summary, Signaling/Presence Load Measurements, Recommendations, Exit Criteria, Next Steps) and `aidlc-state.md` accordingly. The 7 infrastructure fixes remain uncommitted in the working tree (not spike-only code — real, tracked project files) pending user direction on committing them.
**Context**: Spike 2.1 — all four interim values (`maxViewers`, `presenceTimeout`, `reconnectWindow`, NFR-1.3 timings) now recorded, unblocking Unit 3 fully. Remaining if resumed: statistically-powered pacing trials or libwebrtc DCEP logging (fan-out root cause), `--dwellMs` fix, N=100/150/200, Windows/Linux leg, web leg, and resolving the Realtime JWT issue before any real Realtime measurement is possible. Next: Unit 2 (Broadcaster Auth), per the build order.

---

## CONSTRUCTION - Spike 2.1: Committed and pushed
**Timestamp**: 2026-09-27T02:15:00Z
**User Input**: "yes, let's commit and push all this work"
**AI Response**: Added `spikes/phase2/.gitignore` (excludes `node_modules/`, Flutter build artifacts, `.idea/`, and regenerable `results-*.json`) and removed a leftover Supabase CLI temp cache dir before staging. Committed in two logical commits on `spike/2.1-broadcaster-fanout-signaling`: (1) `58b98c3` — the 7 real `zip_supabase` infrastructure fixes; (2) `a6481d6` — the spike harness (`spikes/phase2/`), the report, and the `aidlc-state.md`/`audit.md` updates. Pushed both to origin.
**Context**: Spike 2.1 work committed and pushed. Not yet PR'd — per `phase2-unit-of-work.md`, each spike gets its own **docs-only** PR (report only), and spike code under `spikes/phase2/` is never merged (Q5:A), so the eventual PR(s) from this branch should exclude `spikes/phase2/`; the `zip_supabase` infra fixes are also arguably a separate concern from the spike report and may warrant their own PR rather than bundling with the docs-only spike PR. Flagged for whenever PRs are opened. Next: Unit 2 (Broadcaster Auth).

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): Functional Design + SR-01 approved
**Timestamp**: 2026-09-28T20:12:07Z
**User Input**: Answered all 7 questions in `broadcaster-auth-functional-design-plan.md` (all "A" — recommended options); requested two changes after initial completion: (1) carry the attempted `providerId` on `AuthState.SigningIn`/`AuthFailed` ahead of Phase 3; (2) block sign-out during an active broadcast. Pushed back on widening the sign-out block to "any active captioning session" (asked whether that would be more consistent) — agreed to narrow it to "`BroadcastSessionState` non-idle" after discussing that local captioning is deliberately decoupled from auth (FR-1.4/F-BA-5) and widening would add friction with no corresponding risk; also agreed to close the mid-`goLive()` transition race by keying off "non-idle" rather than strictly "live". Then: "approved, proceed."
**AI Response**: Generated Functional Design artifacts at `aidlc-docs/construction/broadcaster-auth/functional-design/`: `sr-01-oauth-approach.md` (Google-only for Phase 2; `app_links` + custom URL scheme for desktop OAuth redirect; `flutter_secure_storage`-backed session storage on desktop, SDK default on web; SDK-managed refresh; global-scope sign-out; 5-value `AuthFailure` mapping with a logged-not-swallowed catch-all; static-list config-only provider addition), `business-logic-model.md` (9 orchestration flows F-BA-1..9 mapped to S-15's acceptance criteria), `business-rules.md` (9 rules, including Rule 9 added for the sign-out guard), `domain-entities.md`, `frontend-components.md`, and `handoff-summary.md`. Revised per user feedback: `AuthState` now carries `providerId` on `SigningIn`/`AuthFailed`; added Rule 9 (sign-out unreachable, not just discouraged, while `BroadcastSessionState` is non-idle — enforced in Unit 6's `ZbAppShell`, the sole call path to `AuthNotifier.signOut()`, since `zip_core`'s `AuthNotifier` must stay reusable by Zip Captions per FR-1.1 and can't itself know about broadcast state). Added a Backlog entry to `aidlc-state.md` carrying Rule 9's requirement forward to Unit 6 Functional Design. SR-01 (Section 10) and the overall Functional Design approved by James Petersen, 2026-09-28.
**Context**: Unit 2 (Broadcaster Auth) Functional Design COMPLETE and approved, including the SR-01 security-critical approach gate. Next: NFR Requirements — first Construction stage to load the Security Baseline and Property-Based Testing extension rule files, per `aidlc-state.md`'s Extension Configuration and `session-protocol.md` Rule 2.

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): PBT-01 addendum to Functional Design
**Timestamp**: 2026-09-28T20:20:00Z
**AI Response**: Before starting NFR Requirements, loaded the Security Baseline and Property-Based Testing extension rule files (first Unit 2 stage they apply, per `aidlc-state.md` Extension Configuration and `session-protocol.md` Rule 2). PBT-01 requires testable-property identification to live in the Functional Design artifacts, which were already approved before these rules were loaded. Added `aidlc-docs/construction/broadcaster-auth/functional-design/testable-properties.md` as a non-decision-changing addendum: 1 invariant (failure-mapping totality), 1 idempotence (signOut), 1 stateful property (AuthNotifier state machine vs. a reference model, PBT-06), 1 invariant (sign-in view button list), with round-trip/oracle/commutativity/induction marked N/A with rationale. Did not reopen the Functional Design or SR-01 approval, since this supplements rather than changes approved content.
**Context**: Unit 2 Functional Design remains approved as-is; PBT-01 now satisfied retroactively. Proceeding to NFR Requirements.

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): NFR Requirements approved
**Timestamp**: 2026-09-28T21:00:00Z
**User Input**: Asked what a crash-reporting SDK would add over the local `logging` package (answered: production aggregation, breadcrumbs/context, alerting — vs. local-only visibility); decided to keep it out of this unit's scope but explicitly recorded in the Backlog rather than dropped. Answered Q1–Q4 in `broadcaster-auth-nfr-requirements-plan.md` (all "A" — recommended options). Then: "NFR requirements approved, proceed."
**AI Response**: Generated `aidlc-docs/construction/broadcaster-auth/nfr-requirements/nfr-requirements.md` (performance/reliability/testability/platform requirements, full Security Baseline compliance table — 8 Compliant, 6 N/A as infra-owned by `zip_supabase` units, 1 N/A-with-Backlog-note for SECURITY-14 — and full PBT compliance table, all 10 rules Compliant or Compliant-planned), `tech-stack-decisions.md` (`app_links ^7.1.1` new dependency, `flutter_secure_storage ^9.2.2` matching the existing app-wide pin, PBT framework reuses the existing Dart-3-compatible shim rather than the incompatible real `glados` package, mocktail + hand-written fake `AuthService` for testing), and `handoff-summary.md`. No blocking Security or PBT findings. Added a Backlog entry to `aidlc-state.md` for a project-wide crash-reporting SDK decision (not unit-scoped). NFR Requirements approved by James Petersen, 2026-09-28.
**Context**: Unit 2 (Broadcaster Auth) NFR Requirements COMPLETE and approved. Next: NFR Design.

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): NFR Design approved
**Timestamp**: 2026-09-28T21:30:00Z
**User Input**: Answered Q1–Q3 in `broadcaster-auth-nfr-design-plan.md` (all "A" — recommended options). Then: "approve and proceed."
**AI Response**: Generated `aidlc-docs/construction/broadcaster-auth/nfr-design/nfr-design-patterns.md` (dual abandoned-sign-in resolution mechanism — 2s foreground-resume grace window + 3-minute hard timeout, both cancellable by the other or by a real SDK outcome; scalability N/A; synchronous-state-before-await performance pattern; storage Strategy pattern placed in `zip_core`; single no-credentials-logging chokepoint; provider-addition-as-Strategy-list), `logical-components.md` (full component table, dependency-direction diagram confirming `zip_broadcast → zip_core` one-way), and `handoff-summary.md`. NFR Design approved by James Petersen, 2026-09-28.
**Context**: Unit 2 (Broadcaster Auth) NFR Design COMPLETE and approved. Next: Code Generation Part 1 (plan), then Part 2 (Qwen-orchestrated generation per `CLAUDE.local.md`/`delegation-protocol.md`).

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): Code Generation Part 1 plan presented for approval
**Timestamp**: 2026-09-28T20:48:11Z
**AI Response**: Generated `aidlc-docs/construction/plans/broadcaster-auth-code-generation-plan.md` — 22 numbered steps across `zip_core` (domain models, `AuthService`/`SupabaseAuthService`, `SecureDesktopLocalStorage`, `AuthNotifier`, test doubles/generators, PBT tests), `zip_broadcast` (provider config, sign-in view + tests, `main.dart` init, desktop redirect registration), and `zip_captions` (`main.dart` init only, no sign-in UI, per FR-1.1 reuse readiness), plus pubspec updates and a documentation step. Every step cites the design artifact that already fixed its content (Functional Design/SR-01/NFR Requirements/NFR Design) — no new decisions made in this plan. Per `CLAUDE.local.md`, also wrote the Claude/Qwen delegation split to `~/Documents/qwen-orchestrator/runs/zip-captions/broadcaster-auth/unit-plan-delegation.md` (2 Qwen-delegated steps — the PBT command generator and the sign-in view + its tests + provider config batch; 20 steps kept by Claude, mostly security-sensitive or cross-package-contract work). Presented the plan for approval.
**Context**: Awaiting explicit user approval of the Code Generation Part 1 plan before Part 2 (generation) begins.

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): Code Generation Part 1 plan approved
**Timestamp**: 2026-09-28T20:52:55Z
**User Input**: "approve and proceed"
**AI Response**: Code Generation Part 1 (planning) marked complete. Beginning Part 2 (generation) per `broadcaster-auth-code-generation-plan.md`'s step order, delegating Steps 8 and 15-17 to Qwen per `unit-plan-delegation.md`, keeping the remaining steps.
**Context**: Unit 2 (Broadcaster Auth) Code Generation Part 2 starting.

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): Design correction found during Code Generation API verification
**Timestamp**: 2026-09-28T21:01:00Z
**User Input**: "Use the docs-mcp server to check the flutter library" (mid-verification, prompting the use of docs-mcp alongside WebFetch/WebSearch).
**AI Response**: While verifying `supabase_flutter`'s actual API before writing Step 9 (`SupabaseAuthService`), found that `supabase_flutter` already bundles `app_links` internally and subscribes to its `uriLinkStream` on every non-web platform (confirmed by reading the real source, `supabase_auth.dart`: `if (!kIsWeb) { _appLinks.uriLinkStream.listen(...) }`, feeding into an automatic `getSessionFromUrl` call), gated by `FlutterAuthClientOptions.detectSessionInUri` (default `true`). This contradicts SR-01 §3/§9, NFR Requirements' tech-stack-decisions.md, NFR Design's Q3, and Code Generation Steps 9/21, all of which treated `app_links` as a new direct dependency this unit adds and wires itself — based on WebSearch summaries at the time that didn't surface this, rather than the SDK's actual source. Corrected in place: `sr-01-oauth-approach.md` (§3, §9), `nfr-requirements.md`/`tech-stack-decisions.md` (SECURITY-10, dependency table), `nfr-design-patterns.md`/`logical-components.md` (Q3, dependency diagram), all three stage handoff-summary.md files, `aidlc-state.md`'s Unit 2 entries, and the Code Generation plan (Steps 9, 21) — no `app_links` line goes into any `pubspec.yaml`; the OS-level custom-URL-scheme registration (Step 20) remains necessary and unaffected. Also pinned `supabase_flutter: ^2.17.2` (verified current stable) and confirmed the exact `LocalStorage`/`GotrueAsyncStorage`/`signInWithOAuth` signatures needed for Steps 5 and 9 from the SDK's real API docs. Started indexing `supabase_flutter` into docs-mcp (job `81895443-458a-4578-8f5e-c5316e024d1c`, running in background) for future authoritative lookups, per the user's request to use docs-mcp.
**Context**: This is exactly the kind of error the delegation protocol's "never trust the report's claims, verify every API usage" discipline is meant to catch — caught here before any Qwen delegation or code was written, not after. Did not proceed with Code Generation until these corrections were made and reported. Awaiting user acknowledgment before resuming Part 2.

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): Second correction — SupabaseAuthService needs its own app_links subscription for failure visibility
**Timestamp**: 2026-09-28T21:12:54Z
**AI Response**: While implementing `SupabaseAuthService`, found that `supabase_flutter`'s automatic deep-link handling (confirmed in the prior correction) only surfaces *successful* sign-ins via `onAuthStateChange` — failures after the browser opens (declined consent, rejected PKCE exchange) are caught inside its own internal handler and passed to an undocumented, non-public `notifyException`, never reaching any documented public stream (confirmed against `GoTrueClient`'s full public property/method listing via the newly-indexed docs-mcp `supabase_flutter` library, per the user's request to use it). Presented this to the user as a choice: accept a coarser failure signal (collapsing the approved `cancelled`/`denied`/`network`/`providerError` distinction into one generic reason for anything post-browser-open), or have `SupabaseAuthService` run its own parallel `app_links` subscription to inspect the callback URI's `error` query parameter directly. User chose the latter. Implemented it to avoid racing the SDK's one-shot PKCE code: the app's own subscription only reads `error`/`access_denied` from the URI, never calls `getSessionFromUrl` itself — that call stays exclusively the SDK's, so there is no double-consumption of the one-shot authorization code. This reinstates `app_links` as a **direct** `zip_core` dependency (was removed entirely in the first correction) — justified now for a different, correct reason (own API usage for failure visibility) rather than the original mistaken reason (thinking it was needed to receive the callback at all). Corrected: `sr-01-oauth-approach.md` (§3 Correction 2, §9), `tech-stack-decisions.md`, `nfr-requirements.md` (SECURITY-10), and the Code Generation plan (Steps 9, 21). Also confirmed via docs-mcp: `GoTrueClient.signOut()` defaults to `SignOutScope.local`, not global — `SupabaseAuthService.signOut()` must pass `scope: SignOutScope.global` explicitly to match SR-01 §6 (this was already the plan's intent; docs-mcp confirmed the default would have silently produced the wrong behavior if left unspecified). `AuthState.signOutReason` (`userInitiated`/`sessionExpired`/`sessionMissing`) confirmed as the precise mechanism realizing Rule 3 (any `signedOut` event, any reason, maps to our own `signedOut`, never `authFailed`).
**Context**: `SupabaseAuthService` (Code Generation Step 9) implemented with this corrected design. Continuing Code Generation Part 2.

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): Code Generation Part 2 complete (with two flagged platform gaps)
**Timestamp**: 2026-09-29T12:59:20Z
**AI Response**: Completed all 22 Code Generation plan steps. `zip_core`: domain models (`AuthState` as a plain sealed class matching `RecordingState`'s convention, not `freezed`), `AuthService`/`SupabaseAuthService`/`SecureDesktopLocalStorage`, `AuthNotifier`, `supabaseClientProvider`/`authServiceProvider` (the latter a small structural gap-fill not named as its own plan step), full unit/PBT test coverage (361 zip_core tests passing). `zip_broadcast`: `AuthProviderConfig`, `AccountSection` sign-in view (localized via `app_en.arb`), widget tests (100 zip_broadcast tests passing) — Steps 15–17 were delegated to Qwen, which crashed twice with an identical internal backend error before producing any output; escalated per the delegation protocol and implemented directly rather than retry a third time. Both apps' `main.dart` wired with `Supabase.initialize` (71 zip_captions tests passing). Two real bugs found and fixed via actually running tests, not just `dart analyze`: (1) `authStateChanges`'s `async*` implementation had a subscribe race, fixed with `Stream.multi`; (2) `signInWithOAuth` is an unmockable extension method, tests stub the underlying `getOAuthSignInUrl` instead. Platform redirect registration (Step 20): macOS complete (`Info.plist` `CFBundleURLTypes`, confirmed no `AppDelegate.swift` change needed for custom schemes); Windows partial (`main.cpp`'s documented `app_links` integration point added, but the actual registry key registration is not implemented — needs a new `win32_registry` dependency decision and a Windows build to verify); Linux not attempted (the GTK runner patch was only described narratively in the fetched docs, not shown verbatim — guessing at unverifiable native C code was judged too risky to attempt blind). Generated `aidlc-docs/construction/broadcaster-auth/code/unit2-summary.md`. Full `dart analyze --fatal-infos` clean across all three packages.
**Context**: Unit 2 (Broadcaster Auth) Code Generation substantially complete — S-15's Dart-level acceptance criteria are implemented and tested on macOS/web; the Windows/Linux OAuth redirect path needs platform-specific follow-up before it's usable there. Awaiting user review before Build and Test / approval.

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): Code Generation approved
**Timestamp**: 2026-09-29T13:04:39Z
**User Input**: "approve and proceed"
**AI Response**: Code Generation marked complete and approved, including the disclosed Windows/Linux platform gap. Proceeding to Build and Test.
**Context**: Unit 2 (Broadcaster Auth) Code Generation COMPLETE and approved.

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): Committed and PR opened
**Timestamp**: 2026-09-29T13:14:02Z
**User Input**: Asked what should happen now given Phase 2 has Units 3-9 remaining and Build and Test/Documentation Refinement are phase-level per AGENTS.md and Phase 1 precedent, not per-unit — user chose "commit and open a PR for Unit 2 now, then move to Unit 3."
**AI Response**: Committed all Unit 2 work (73 files) on `feature/broadcaster-auth` with a Conventional Commits message documenting the implementation and the disclosed Windows/Linux platform gap. Pushed the branch and opened PR #22 (`feature/broadcaster-auth` -> `develop`): https://github.com/Zip-Captions/zip-captions-monorepo/pull/22.
**Context**: Unit 2 (Broadcaster Auth) fully complete: Functional Design, SR-01, NFR Requirements, NFR Design, Code Generation all approved; PR #22 open against `develop`, not yet merged. Per the dependency matrix, Unit 3 (Broadcast Identity + Signaling) depends on Unit 2 (now done) and Spike 2.1 (paused, interim `presenceTimeout`/`maxViewers` values already accepted). Next unit not yet started — awaiting user direction.

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): PR #22 Linux build-verify CI failure fixed
**Timestamp**: 2026-09-29T13:18:40Z
**User Input**: "PR 22 build/verify linux check failed."
**AI Response**: Checked `gh pr checks 22` and the actual job log: `flutter build linux` failed at CMake configure time — `flutter_secure_storage_linux`'s `CMakeLists.txt` requires `libsecret-1>=0.18.4` via `pkg_check_modules`, not installed on the CI runner. This is the first PR to actually wire `SecureDesktopLocalStorage` into a real build path (via `main.dart` in all three apps), so it's the first to hit this pre-existing gap in `.github/workflows/build-verify.yml`'s Linux job (Unit 5's CI pipeline, not this unit's own scope, but the fix belongs here since this PR is what surfaces it). Confirmed with the user before pushing (a shared CI config change). Added `libsecret-1-dev` to the job's `apt-get install` step and pushed as a new commit on `feature/broadcaster-auth`, updating PR #22.
**Context**: Awaiting CI re-run on PR #22 to confirm the fix.

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): CodeRabbit CHANGES_REQUESTED — two findings fixed
**Timestamp**: 2026-09-29T13:47:25Z
**User Input**: "PR has changes requested from coderabbit automatic review"
**AI Response**: Read CodeRabbit's two actionable findings on PR #22 and confirmed both against the current code before fixing. (1) **Real bug**: `SupabaseAuthService._handleIncomingUri` mapped any callback error other than `access_denied` to `AuthFailure.denied` — contradicting the unit's own approved SR-01 §7 design, where `denied` is reserved for provider-configuration rejection (surfaced via `AuthException` from the pre-browser call) and the callback-URI catch-all should be `providerError`. Fixed the mapping and added three tests directly exercising `_handleIncomingUri` (via an injected mock `AppLinks`) that weren't there before — the gap in coverage is exactly how this shipped uncaught. (2) **Real gap**: `authServiceProvider` was never overridden in `zip_broadcast/lib/main.dart`, so any code reading `authNotifierProvider` would hit the provider's `UnimplementedError` and crash; also, `AccountSection` was built but not composed into any reachable screen. Fixed both: added the `authServiceProvider.overrideWithValue(SupabaseAuthService(...))` override, and added an "Account" entry to `SettingsScreen`'s existing drill-down navigation (new `_AccountDetail` view, localized via `app_en.arb`), plus tests for both the new entry and its sign-in-card rendering. `zip_captions`' `main.dart` intentionally left without an `authServiceProvider` override, since it has no sign-in UI in Phase 2 and nothing there reads it (the throw-unless-overridden provider is a deliberate fail-fast if that ever changes without updating the wiring). Full regression: 364 zip_core tests, 101 zip_broadcast tests, all passing; both packages `dart analyze --fatal-infos` clean.
**Context**: Pushing these fixes as a new commit on `feature/broadcaster-auth`, updating PR #22.

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): Replied to CodeRabbit review threads; Linux CI now passing
**Timestamp**: 2026-09-29T13:50:23Z
**User Input**: "respond to the comments on the PR please"
**AI Response**: Posted inline replies on both CodeRabbit review threads on PR #22, confirming each finding was real and pointing to the fixing commit (64bda28); noted for the `AccountSection` finding that the actual fix nests it as its own `SettingsScreen` drill-down view rather than the suggested inline placement, matching the screen's existing pattern for every other category. Checked `gh pr checks 22`: the Linux build-verify job now passes (confirming the earlier `libsecret-1-dev` fix); Analyze & Test, Android, iOS, macOS, Windows still pending/running.
**Context**: PR #22 has both CodeRabbit findings addressed and replied to; awaiting the remaining CI jobs to finish.

---

## CONSTRUCTION - Unit 2 (Broadcaster Auth): PR #22 merged — Unit 2 fully complete
**Timestamp**: 2026-09-29T14:00:31Z
**User Input**: "PR approved and merged, proceed"
**AI Response**: Confirmed the merge (`gh pr view 22`: state MERGED, squash commit `6a757fd`). Fetched with prune (confirmed the remote already auto-deleted `feature/broadcaster-auth` and several other stale branches), fast-forwarded local `develop` to `origin/develop`, and force-deleted the local `feature/broadcaster-auth` branch (git reported it "not fully merged" only because of the squash merge's history rewrite — the fast-forward diff onto `develop` confirmed the content matches exactly what was reviewed).
**Context**: Unit 2 (Broadcaster Auth) is fully complete and merged. Per the dependency matrix, Unit 3 (Broadcast Identity + Signaling) depends on Unit 2 (done) and Spike 2.1 (paused, interim values already accepted). Next unit not yet started — awaiting user direction.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Starting
**Timestamp**: 2026-09-29T14:06:28Z
**User Input**: "merge 23 and proceed with unit 3, we can accept the interim results from spike 2.1 until we've got a functional MVP with actual users"
**AI Response**: Merged PR #23. Recorded the user's Spike 2.1 acceptance decision in `aidlc-state.md` (interim values stand through to a functional MVP with real users, at which point Spike 2.1 is revisited with real usage data). Created `feature/broadcast-identity-signaling` off `develop` (no worktree, per standing preference). Starting Unit 3 Functional Design.
**Context**: Unit 3 (S-11, S-13, gated by SR-02) — packages zip_supabase, zip_core. Depends on Unit 2 (done, merged) and Spike 2.1 (paused, interim values now explicitly accepted for MVP scope).

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Functional Design plan drafted
**Timestamp**: 2026-09-29T14:20:00Z
**AI Response**: Researched Supabase's actual Realtime Authorization mechanism (RLS policies on `realtime.messages`, scoped by `extension = 'broadcast'`/`'presence'` and `topic`, requiring `private: true` channels — confirmed via Supabase's current docs, not in docs-mcp's index) before drafting recommendations, same discipline as Unit 2's SR-01 research. Saved `aidlc-docs/construction/plans/broadcast-identity-signaling-functional-design-plan.md` with 7 multiple-choice questions covering: registry table name/columns (FR-2.2, avoiding the misleading `broadcast_sessions` example name given FR-2.6 rules out session records), broadcast ID alphabet/length (Crockford Base32, FR-2.3), the anonymous resolution mechanism split (a `SECURITY DEFINER` RPC only resolves existence, not live status — live status resolution is a client-side presence read, not this RPC's job), enumeration control (deferring the actual rate-limit config to Infrastructure Design, via Kong), Realtime channel authorization (Supabase's native `realtime.messages` RLS mechanism), viewer join abuse control (explicitly Unit 5's `ViewerAdmission` scope, not this unit's), and how `BroadcastResolution.RateLimited` reconciles with the enumeration-control answer. This stage's output includes the SR-02 security-critical approach document, same gate structure as Unit 2's SR-01.
**Context**: Awaiting user answers to the 7 questions before generating the Functional Design artifacts.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Functional Design + SR-02 generated
**Timestamp**: 2026-09-29T14:35:00Z
**User Input**: Answered all 7 questions in `broadcast-identity-signaling-functional-design-plan.md` (all "A" — recommended options). Then: "proceed."
**AI Response**: Generated Functional Design artifacts at `aidlc-docs/construction/broadcast-identity-signaling/functional-design/`: `sr-02-rls-realtime-policy.md` (the `broadcast_identities` table with owner-unique/broadcast_id-unique constraints and owner-only RLS, no `anon` policy at all on the table; a boolean-only `SECURITY DEFINER` `resolve_broadcast_id` RPC for anonymous existence checks, explicitly split from live-status resolution which is a client-side Realtime presence read; Kong-based rate limiting deferred to this unit's own Infrastructure Design stage; Supabase's native `realtime.messages` RLS for channel authorization with a documented RLS-vs-application-logic defense-in-depth split for message-type authorization), `business-logic-model.md` (5 flows mapped to S-11/S-13 ACs), `business-rules.md` (8 rules), `domain-entities.md`, `testable-properties.md` (5 pure-Dart PBT properties plus 2 explicitly-flagged stateful/integration properties that need the local Supabase stack, not the in-process PBT shim), and `handoff-summary.md`.
**Context**: Unit 3 Functional Design complete, awaiting the user's Functional Design + SR-02 approval.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Functional Design + SR-02 approved
**Timestamp**: 2026-09-30T01:40:59Z
**User Input**: "approve and proceed"
**AI Response**: Functional Design and SR-02 (`sr-02-rls-realtime-policy.md` §6) approved by James Petersen, 2026-09-30. Proceeding to NFR Requirements.
**Context**: Unit 3 (Broadcast Identity + Signaling) Functional Design COMPLETE and approved, including the SR-02 security-critical approach gate.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): NFR Requirements plan drafted
**Timestamp**: 2026-09-30T01:48:00Z
**AI Response**: Saved `aidlc-docs/construction/plans/broadcast-identity-signaling-nfr-requirements-plan.md` with 2 open questions (a concrete Kong rate-limit threshold for `resolve_broadcast_id`, and whether `get_or_create_my_broadcast_id`'s retry bound needs a latency NFR beyond its existing fail-safe retry cap) plus a preliminary Security Baseline pass — more rules apply here than for Unit 2's client-only scope, since this unit owns real Postgres/RLS/Realtime infrastructure.
**Context**: Awaiting user answers before generating the NFR Requirements artifacts.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): NFR Requirements generated
**Timestamp**: 2026-09-30T01:55:00Z
**User Input**: Answered Q1 (Kong rate limit, 30/min + burst) and Q2 (no formal latency NFR, retry bound is a fail-safe) both "A" in `broadcast-identity-signaling-nfr-requirements-plan.md`. Then: "proceed."
**AI Response**: Generated `nfr-requirements.md` (performance/reliability/testability requirements; full Security Baseline compliance table — 8 Compliant, 6 N/A as platform/other-unit-owned, 1 N/A-with-Backlog-note; full PBT compliance table, 7 Compliant/Compliant-planned, 3 N/A with rationale for the database-constraint-dependent stateful properties), `tech-stack-decisions.md` (no new dependencies; `resolve_broadcast_id` as `sql`-language, `get_or_create_my_broadcast_id` as `plpgsql`; Kong rate-limit target 30/min+burst; hand-written Dart-side fakes + real Supabase-stack integration tests for RLS/constraint behavior), and `handoff-summary.md`. No blocking Security or PBT findings.
**Context**: Unit 3 NFR Requirements COMPLETE, awaiting approval.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): NFR Requirements approved
**Timestamp**: 2026-09-30T15:35:54Z
**User Input**: "approve and proceed"
**AI Response**: NFR Requirements marked complete and approved. Proceeding to NFR Design.
**Context**: Unit 3 (Broadcast Identity + Signaling) NFR Requirements COMPLETE and approved.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): NFR Design plan drafted
**Timestamp**: 2026-09-30T15:40:00Z
**AI Response**: Saved `aidlc-docs/construction/plans/broadcast-identity-signaling-nfr-design-plan.md` with 2 questions (a new `BroadcastAuthorizationException` for RLS-rejection handling; treating a resolution step-2 failure the same as `Offline` rather than inventing a new caller-facing state Unit 7's approved UI has nowhere to render) plus the package-placement clarification (mirroring Unit 2: all Dart code in `zip_core`, `zip_supabase` gets only the SQL migration, since it's not a Dart package).
**Context**: Awaiting user answers before generating the NFR Design artifacts.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): NFR Design generated, including a design correction
**Timestamp**: 2026-09-30T15:52:00Z
**User Input**: Answered Q1 (`BroadcastAuthorizationException`) "A" and Q2 "B" — deviating from the recommended option, choosing a distinct `ResolutionFailed` variant over folding a resolution-step-2 failure into `Offline`.
**AI Response**: Since Q2's answer extends `BroadcastResolution` (a shape fixed at Application Design) with a new `ResolutionFailed` variant, retroactively updated the already-approved Functional Design artifacts to match: `domain-entities.md` (new variant + rationale), `sr-02-rls-realtime-policy.md` §2 (updated resolution description), `business-logic-model.md` F-BIS-2 (step-2 failure now maps to `ResolutionFailed`, not folded into `Offline`). Generated `nfr-design-patterns.md`, `logical-components.md` (package placement confirming all Dart code lives in `zip_core`, `zip_supabase` gets only the migration — mirrors Unit 2's `SupabaseAuthService` exactly), and `handoff-summary.md`. Added a Backlog entry to `aidlc-state.md` flagging that Unit 7's `BroadcastViewerScreen` has no approved rendering for `ResolutionFailed` yet — that unit's own Functional Design must decide (new state vs. folding into an existing "cannot connect" state).
**Context**: Unit 3 NFR Design COMPLETE, awaiting approval. The retroactive Functional Design edits don't reopen that stage's overall approval (SR-02's substance is unchanged) but are called out here for traceability.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): NFR Design approved
**Timestamp**: 2026-09-30T23:49:21Z
**User Input**: "approve and proceed"
**AI Response**: NFR Design marked complete and approved. Proceeding to Infrastructure Design (this unit's own stage, per `phase2-unit-of-work.md` — migration, resolution endpoint, Realtime authorization configuration).
**Context**: Unit 3 (Broadcast Identity + Signaling) NFR Design COMPLETE and approved.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Infrastructure Design plan generated
**Timestamp**: 2026-09-30T23:55:00Z
**User Input**: (implicit, continuing from NFR Design approval)
**AI Response**: Read the generic Infrastructure Design stage rule and Unit 4's existing Infrastructure Design document as a style/scope precedent, then read the project's actual current Kong config (`packages/zip_supabase/volumes/api/kong.yml`) and migrations directory before drafting any questions, per the NFR Design handoff summary's explicit constraint not to invent a new Kong config format. Saved `aidlc-docs/construction/plans/broadcast-identity-signaling-infrastructure-design-plan.md` with 2 questions: (Q1) how to scope the Kong rate limit to exactly `resolve_broadcast_id` rather than all REST traffic — recommended splitting a new, more specific service/route out of the catch-all `rest-v1` route; (Q2) whether the migration needs a down/rollback script — recommended no, matching the project's existing forward-only convention (confirmed by inspecting the one existing migration file).
**Context**: Awaiting user answers before generating the Infrastructure Design artifacts.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Infrastructure Design approved
**Timestamp**: 2026-10-01T00:23:40Z
**User Input**: "approved"
**AI Response**: Both plan questions approved as recommended (A/A). Generated `aidlc-docs/construction/broadcast-identity-signaling/infrastructure-design/infrastructure-design.md`: a new `rest-v1-resolve-broadcast-id` Kong service/route (split from `rest-v1`, same `cors`/`key-auth`/`acl` plugins plus a new `rate-limiting` plugin — `limit_by: ip`, `minute: 30`, `second: 2`, `policy: local`, `fault_tolerant: true` — approximating NFR Requirements Q1's 30/min + ~10-in-5s burst target), and confirmation of no down-migration script. Generated `handoff-summary.md` for Code Generation. Updated `aidlc-state.md` (Unit 3's Infrastructure Design marked complete; Current Stage line advanced to "starting Code Generation next").
**Context**: Unit 3 (Broadcast Identity + Signaling) Infrastructure Design COMPLETE and approved. Next: Code Generation (Part 1 plan, then Part 2 generation).

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Code Generation Part 1 plan generated
**Timestamp**: 2026-10-01T00:40:00Z
**User Input**: "I want to try delegating to qwen for code generation... let's do one as a test to see the quality we get back"
**AI Response**: Saved `aidlc-docs/construction/plans/broadcast-identity-signaling-code-generation-plan.md` — 14 steps covering the migration/Kong config, pure-Dart models, repository layer, resolution layer, signaling service layer, provider wiring, and both unit and integration tests, per the approved Functional Design/NFR Design/Infrastructure Design artifacts. Resolved one previously-undocumented ambiguity before planning further: SR-02 §3 says IDs are stored/compared case-sensitively (uppercase alphabet) but displayed lowercase — decided `BroadcastId.parse`/`tryParse` normalize to canonical uppercase so pasted lowercase viewer input actually resolves, keeping display-casing a presentation-only concern. Logged this decision directly in the plan rather than leaving it for whoever generates Step 2 to guess.
**Context**: Awaiting user approval of the plan before Part 2 generation begins (requesting approval of Step 2 specifically as a first delegation test, per local delegation protocol — mechanics not detailed here per that protocol's own logging rule).

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Code Generation Steps 2–3 complete
**Timestamp**: 2026-10-01T01:05:00Z
**User Input**: "proceed building it yourself" (after a delegation test attempt produced zero usable output)
**AI Response**: Completed Step 2 (pure-Dart models: `BroadcastId`, `BroadcastLink`, `BroadcastResolution`, `SignalingMessage` + `SignalingCodec`, `PresenceSnapshot`, `BroadcastStatus`, all in `packages/zip_core/lib/src/models/`, exported via `models.dart`) and Step 3 (PBT generators and the 5 round-trip/invariant tests from `testable-properties.md`, in `packages/zip_core/test/pbt/` and `test/helpers/generators.dart`). Added `meta` as a direct `zip_core` dependency (small, standard, needed for `@immutable`). `dart analyze --fatal-infos` clean; full `zip_core` suite now 369 tests, all passing, no regressions.
**Context**: Unit 3 Code Generation Steps 1–3 of 14 complete (Step 1, the migration + Kong config, still pending). Continuing with Step 4 (repository layer) next.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Code Generation Steps 1, 4, 5 complete
**Timestamp**: 2026-10-01T01:35:00Z
**User Input**: "proceed"
**AI Response**: Completed Step 1 (migration `20261001000000_broadcast_identity_signaling.sql` — `broadcast_identities` table + RLS, `resolve_broadcast_id`, `get_or_create_my_broadcast_id`, and the full `realtime.messages` authorization policy set per SR-02 §1–§4; plus the Kong `rest-v1-resolve-broadcast-id` rate-limited route). Verified the migration against the actual local Supabase stack rather than by inspection alone: spun up `supabase-db`, applied it, confirmed `get_or_create_my_broadcast_id()` idempotence and cross-user uniqueness, `resolve_broadcast_id`'s anon-safe boolean-only behavior, and RLS correctly blocking both direct anon table reads and one authenticated user inserting/reading another's row — then tore the stack back down. Completed Step 4 (`BroadcastIdentityRepository`/`SupabaseBroadcastIdentityRepository`/`BroadcastAuthorizationException`) and Step 5 (exception-mapping unit tests). `dart analyze --fatal-infos` clean; full `zip_core` suite now 372 tests passing.
**Context**: Unit 3 Code Generation Steps 1–5 of 14 complete. Continuing with Step 6 (resolution layer) next.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): SR-02 §4 correction (presence SELECT scope)
**Timestamp**: 2026-10-01T02:05:00Z
**User Input**: "Open presence SELECT to anon+authenticated (Recommended)" (in response to a flagged inconsistency)
**AI Response**: Found a genuine internal contradiction in the already-approved SR-02 while preparing to build the signaling layer (Step 8): §4's policy table restricted `presence` SELECT on `status:{broadcast_id}` to the broadcaster only, but §2's anonymous resolution explicitly reads that same presence state to determine live/offline for *any* caller, including anonymous viewers — the two cannot both be true, and as drafted the restriction would have made anonymous resolution never see "live" at all. Root cause: the original draft copied `SessionSignalingChannel.presence`'s intentionally-private viewer-count pattern by mistake. Corrected per the user's direction: `status:{broadcast_id}` presence SELECT is now `anon, authenticated` (matching its own `broadcast`-extension SELECT row); INSERT (tracking) stays broadcaster-only. Updated the already-applied migration (`20261001000000_broadcast_identity_signaling.sql`) and `sr-02-rls-realtime-policy.md` §4's table with an inline note explaining the correction. Re-verified the migration still applies cleanly.
**Context**: Also discovered and disclosed a process issue during this verification: `docker compose down -v` after the Step 1 verification had removed a Supabase volume that may have pre-dated this session (a prior full-stack run's data) rather than a certainly-empty one created by this session — user confirmed no real data was lost. Added a standing local-only lesson (not a tracked-file change) to check Docker volume state before any future teardown in this package.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Code Generation Steps 8, 9 complete (out of plan order)
**Timestamp**: 2026-10-01T02:40:00Z
**User Input**: (continuing from "proceed")
**AI Response**: Built the signaling service layer (Step 8) before the resolution layer (Step 6), since `BroadcastResolver`'s implementation composes a `StatusChannel` per `logical-components.md`'s own dependency graph — Step 6 cannot be built first as originally sequenced. Added `SignalingService`/`SignalingRole`, `StatusChannel`/`SessionSignalingChannel` (signatures copied verbatim from Application Design's fixed `phase2-component-methods.md` §3), and their Supabase Realtime implementations (private channels, presence-based live/offline for status, broadcast-message signaling + presence-based viewer count for sessions). Verified every non-trivial Realtime API call (`channel`, `onPresenceSync`, `onBroadcast`, `track`/`untrack`, `sendBroadcastMessage`, `subscribe`, `presenceState`) against `supabase_flutter`'s actual docs via docs-mcp rather than assuming signatures. Wrote Step 9's mocktail-based unit tests and, in the process, found and fixed a real bug: `SupabaseStatusChannel.watch()`'s initial status emission was being silently dropped (routed through an internal broadcast stream before any listener existed on it) — every subscriber would see only later updates, never the current status on first watch. Fixed and re-verified. `dart analyze --fatal-infos` clean; full suite now 382 tests passing, no regressions.
**Context**: Unit 3 Code Generation Steps 1, 2, 3, 4, 5, 8, 9 of 14 complete. Continuing with Step 6 (resolution layer, now unblocked) next.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Code Generation Steps 6, 7 complete
**Timestamp**: 2026-10-01T03:05:00Z
**User Input**: (continuing from "proceed")
**AI Response**: Completed `BroadcastResolver`/`SupabaseBroadcastResolver` (Step 6): two-step resolution per SR-02 §2, composing the Step 4 RPC call and a Step 8 `StatusChannel`. Flagged one open item transparently rather than guessing silently and moving on: the exact way Kong's rate-limiting plugin's HTTP 429 surfaces through `postgrest-dart` isn't pinned down anywhere in the approved docs (Infrastructure Design fixed the Kong config, not this client-side detection detail), so implemented a best-effort heuristic (`PostgrestException` with no Postgres `code` and a rate-limit-shaped message) that fails safe to `resolutionFailed` if wrong, and noted it needs confirming against the real stack at Step 12. Completed Step 7's tests (all 5 outcomes), reusing the `Fake`-override-`then` technique for `PostgrestFilterBuilder` already established for Unit 2's `signInWithOAuth` problem. `dart analyze --fatal-infos` clean; full suite now 391 tests passing, no regressions.
**Context**: Unit 3 Code Generation Steps 1–9 of 14 complete. Continuing with Step 10 (Riverpod provider wiring) next.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Code Generation Steps 10, 11 complete
**Timestamp**: 2026-10-01T03:20:00Z
**User Input**: (continuing from "proceed")
**AI Response**: Added `broadcastIdentityRepositoryProvider`, `signalingServiceProvider`, `broadcastResolverProvider` (Step 10) — all three construct their real `Supabase*` implementation directly from `supabaseClientProvider` rather than requiring an app-startup override, since (unlike `authServiceProvider`) nothing app-specific is needed, matching `sttEngineRegistryProvider`'s existing "construct directly" precedent over the "throw unless overridden" one. Ran `build_runner` to generate the `.g.dart` files. Added Step 11's wiring tests. `dart analyze --fatal-infos` clean; full suite now 397 tests passing, no regressions.
**Context**: Unit 3 Code Generation Steps 1–11 of 14 complete. Remaining: Step 12 (integration tests against the local Supabase stack — including confirming the resolver's rate-limit-detection heuristic flagged at Step 6/7), Step 13 (code summary doc), Step 14 (Documentation Refinement flag note).

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Code Generation Step 12 complete — found and fixed two pre-existing Unit 4 infra bugs
**Timestamp**: 2026-10-01T04:00:00Z
**User Input**: (continuing from "proceed"); separately, "Fix it now as a separate, clearly-labeled change" when asked how to handle the first discovered Kong bug; "No real data lost, continue" when asked about a Docker volume concern raised earlier in this unit.
**AI Response**: Wrote `packages/zip_core/test/integration/broadcast_identity_supabase_test.dart` — the project's first real-backend integration test, covering exactly `testable-properties.md`'s "Stateful / Integration-Level Properties" (idempotence, uniqueness, anon RLS boundary). Added `packages/zip_core/dart_test.yaml` to tag and skip it by default (no CI/stack-availability wiring exists for this yet) — confirmed skip behavior matches the project's real `melos exec -- flutter test` per-package invocation. Actually running it against the local stack surfaced two genuine, pre-existing bugs in Unit 4's infrastructure, unrelated to Unit 3's own deliverables: (1) Kong's `KONG_PLUGINS` allowlist in `docker-compose.yml` never included `rate-limiting`, which only surfaced because Unit 3's own Kong route now references that plugin (fixed: added it to the allowlist); (2) Kong's `kong.yml` `${ANON_KEY}`/`${SERVICE_ROLE_KEY}` placeholders were never actually substituted by Kong itself — confirmed via direct `curl` that Kong registered the literal string `"${ANON_KEY}"` as the credential (fixed: added a `sed`-based render step to the `kong` service's `entrypoint`, writing to `/tmp/kong.yml` since `/home/kong` isn't writable by the Kong user). Diagnosing a THIRD failure after fixing those two (`PGRST301: None of the keys was able to decode the JWT`) found a one-word typo in `packages/zip_supabase/.env.example`: `JWT_SECRET` was missing the `your-` prefix from Supabase's actual canonical local-dev default, so the bundled demo `ANON_KEY`/`SERVICE_ROLE_KEY` JWTs never verified against it — independently confirmed via a manual HMAC-SHA256 computation in Python before touching any file. Fixed via a new corrective migration (`20261001000001_fix_jwt_secret_mismatch.sql`, forward-only convention, since editing the already-shipped initial migration wouldn't fix an already-initialized database) plus the `.env.example` correction, and updated Unit 4's own `infrastructure-design.md` table for consistency. All three fixes verified end-to-end via direct `curl` before re-running the Dart test. Final result: all 5 integration tests pass against the real stack (confirmed with a clean repeat run); one unrelated intermittent 502 from Kong→PostgREST under rapid sequential requests was observed on some runs (reproduced via `curl` too, affects the pre-existing catch-all route as well — not a Unit 3 bug) and logged to `aidlc-state.md`'s Backlog rather than chased further, since Unit 3's own logic was already independently confirmed correct via deterministic `psql` checks earlier at Step 1. Tore the stack down cleanly afterward (checked for pre-existing volume state first this time, per the lesson recorded earlier in this unit). `dart analyze --fatal-infos` clean; normal `flutter test` run (matching CI's invocation) is 397 passing + 1 correctly skipped.
**Context**: Unit 3 Code Generation Steps 1–12 of 14 complete. Two new Backlog items added (the intermittent 502 flakiness; the unverified rate-limit-detection heuristic). Continuing with Step 13 (code summary doc) and Step 14 (Documentation Refinement flag note) next — the last two steps of this unit's Code Generation.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Code Generation COMPLETE (Steps 13, 14)
**Timestamp**: 2026-10-01T04:15:00Z
**User Input**: (continuing from "proceed")
**AI Response**: Wrote the Code Generation summary (`unit3-summary.md`) covering all files created/modified, test coverage, and 8 logged deviations from the plan (execution reordering, the case-normalization clarification, the dropped-emission bug, the SR-02 presence-scope correction, the Fake-builder testing technique, the integration-test scope split, the unverified rate-limit heuristic, and the three Unit 4 infra bug fixes). Logged Step 14's Documentation Refinement flag (not edited now, per the phase-level stage): `docs/RIVERPOD_CONVENTIONS.md` should document this unit's "construct directly from another provider" pattern alongside the existing "throw unless overridden" one. Updated `aidlc-state.md`: Unit 3's Code Generation Part 1 and Part 2 both marked complete, duplicate stray "Code Generation" checkbox line removed, Current Stage advanced to "Code Generation COMPLETE; awaiting human review/approval before PR."
**Context**: Unit 3 (Broadcast Identity + Signaling) Code Generation is fully complete — all 14 plan steps done, 397 tests passing, `dart analyze --fatal-infos` clean across `zip_core`. Awaiting the user's review and explicit approval (per the standard Code Generation Step 15 gate) before PR.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): Code Generation approved
**Timestamp**: 2026-10-01T14:21:27Z
**User Input**: "approve and continue"
**AI Response**: Code Generation marked complete and approved for Unit 3. Proceeding to commit and open a PR against `develop` for this unit, matching Unit 2's precedent (each unit ships as its own PR immediately after Code Generation approval).
**Context**: Unit 3 (Broadcast Identity + Signaling) Code Generation COMPLETE and approved. Next: commit, push, open PR.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): PR opened
**Timestamp**: 2026-10-01T14:25:00Z
**User Input**: (continuing from "approve and continue")
**AI Response**: Committed all Unit 3 work (squash commit `ca465ce`, 72 files) and pushed `feature/broadcast-identity-signaling` to origin. Opened **PR #24** against `develop`: https://github.com/Zip-Captions/zip-captions-monorepo/pull/24.
**Context**: Awaiting CI results and human review on PR #24.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): CodeRabbit review findings fixed on PR #24
**Timestamp**: 2026-10-01T17:31:20Z
**User Input**: "Read the feedback on the PR and address the changes"
**AI Response**: All 6 CI checks passed; CodeRabbit posted 4 actionable findings, all independently verified against the actual code before fixing (not taken on faith):
1. `_looksRateLimited` only matched `code == null`, but `postgrest` actually passes Kong's HTTP 429 through as `PostgrestException.code == '429'` — fixed to match both, added a regression test.
2. `_ensureSubscribed()` permanently cached a subscribe failure forever, ignoring that `RealtimeChannel.subscribe()` can only be called once and the client's own automatic rejoin re-invokes the same callback later — fixed to track channel-start state separately from the per-attempt wait, so a later successful rejoin un-sticks future callers instead of replaying the first failure forever. Added a regression test exercising exactly this recovery path.
3. `watch()` could read `_currentStatus()` immediately after `subscribed`, but the Realtime protocol sends the presence snapshot as a separate message, not guaranteed bundled with the join reply — an already-live topic could be misread as offline. Fixed by waiting for the first presence sync before computing the initial value. Added a regression test simulating the sync arriving after `subscribed`.
4. **Major, security**: the `"Only the broadcaster reads presence on a signaling session"` RLS policy never actually checked ownership — any authenticated user could read any session's viewer-presence data, contradicting both the policy's name and `SessionSignalingChannel.presence`'s documented contract. CodeRabbit's suggested fix (a persisted `broadcast_sessions` table with `owner_id`) directly contradicts FR-2.6, which SR-02 itself cites as the reason no session records exist in Postgres — flagged this conflict to the user rather than unilaterally picking a fix. User chose: open the policy honestly (`authenticated`, matching its own `INSERT` policy, anon still excluded) and correct the misleading policy name and all three places that claimed an RLS guarantee that never existed (`SessionSignalingChannel.presence`'s doc comment, `SupabaseSessionSignalingChannel`'s class doc comment, and SR-02 §4's table) to say viewer-count privacy is deferred to Unit 5's transport-layer authorization — the same RLS-can't-express-it split SR-02 §4 already uses for message-type authorization.
`dart analyze --fatal-infos` clean; full suite now 400 tests passing (+3 regression tests), 1 integration suite correctly skipped by default, no regressions. Committed and pushed to PR #24.
**Context**: Awaiting CI re-run and further review on PR #24.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): second CodeRabbit review pass found a real edge case in the first fix
**Timestamp**: 2026-10-01T20:37:50Z
**User Input**: "check again" / "respond to and resolve open conversations on the PR where they've been addressed" (requesting a fresh CodeRabbit review after the first round, then handling its result)
**AI Response**: Requested a fresh CodeRabbit review (the prior formal review's CHANGES_REQUESTED verdict doesn't clear just because its conversations were resolved — confirmed `develop` has an active GitHub ruleset requiring reviews, which was blocking merge). The new review found one more real issue in the fix just shipped: if the channel errors or closes *after* `subscribed` but *before* any presence sync, nothing settled `_initialPresenceSync`, so `watch()` would hang forever. Fixing it correctly required a `_terminated` flag distinguishing a transient failure (give it a fresh wait, so the channel's own automatic rejoin stays observable) from a terminal one (`closed`/explicit `close()` — never hand out a fresh wait, nothing will ever complete it). The first attempt at this fix didn't make that distinction and introduced a real hang in its own new regression test — caught immediately by running the test, not by assuming the fix was correct. Also hit a Dart-specific test-timing gotcha (materializing `.first` before anything awaits it can report a false "unhandled error") and fixed it by using `expectLater(stream, emitsError(...))` directly. `dart analyze --fatal-infos` clean; full suite now 401 tests passing, no regressions. Replied to and resolved the review thread; requested another fresh CodeRabbit review.
**Context**: Awaiting the next CodeRabbit review result on PR #24.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): third CodeRabbit finding fixed, PR #24 approved and clean
**Timestamp**: 2026-10-02T01:43:03Z
**User Input**: linked a specific review (https://github.com/Zip-Captions/zip-captions-monorepo/pull/24#pullrequestreview-5386967786) the user noticed was still open.
**AI Response**: That review had posted an "outside diff range" comment (on `signaling_codec.dart`, untouched by either prior fix commit, so it never surfaced in the inline review-thread listing used to track the earlier rounds). Verified it against the actual code: `_approximateEncodedBytes` only summed top-level string values' UTF-16 code-unit length and ignored nested maps/lists entirely, so a message with a large nested field a given variant's decoder doesn't read (e.g. `broadcastEnded` with a 20 KiB `extra.blob`) would pass the 16 KiB check despite being many times over — a real violation of Rule 4's oversized-input contract. Fixed by computing the actual UTF-8 byte length of the full `jsonEncode`d payload instead of the cheap heuristic. Added a regression test matching the exact example from the review. `dart analyze --fatal-infos` clean; full suite now 402 tests passing, no regressions. Separately confirmed PR #24's overall state: CodeRabbit's latest formal review (00:08:43Z, before this finding was reported) was APPROVED, all 6 CI checks pass, and `mergeStateStatus: CLEAN` — this finding was a leftover from an earlier review round's "outside diff" comment, not a new blocker.
**Context**: Fix pushed; replying to and resolving this review's comment, then confirming final PR state.

---

## CONSTRUCTION - Unit 3 (Broadcast Identity + Signaling): PR #24 merged, unit complete
**Timestamp**: 2026-10-02T01:56:35Z
**User Input**: "Pr approved, squashed and merged, what's next?"
**AI Response**: Confirmed via `gh pr view 24` — merged to `develop` as squash commit `4f6fbeb`. Switched to `develop`, pulled (fast-forwarded `98ffeb0..4f6fbeb`), deleted the local and remote `feature/broadcast-identity-signaling` branches. Updated `aidlc-state.md`: Unit 3 marked fully COMPLETE with the PR/merge details and a summary of all three CodeRabbit review rounds; Current Stage line advanced past Unit 3.
**Context**: Unit 3 (Broadcast Identity + Signaling) is fully shipped. Per the Phase 2 dependency matrix, Unit 4 (Coturn Infrastructure, gated by SR-03) is next — presenting this to the user for confirmation before starting, per the standing per-unit check-in pattern.

---

## CONSTRUCTION - Spike 2.3 (Coturn Alongside Supabase): started and completed
**Timestamp**: 2026-10-02T15:47:58Z
**User Input**: "Start Spike 2.3 now" (in response to Unit 4 being gated on it and not yet started), then "proceed with the multi step infrastructure investigation" after an initial progress checkpoint.
**AI Response**: Branched `spike/2.3-coturn-alongside-supabase` off `develop`. Built a throwaway harness (`spikes/phase2/coturn/`): Coturn configured with the TURN REST shared-secret credential mechanism, payload-free logging, private-range relay denial, and Prometheus metrics; a two-container NAT simulation (`nat-gateway` + `nat-client`) using nftables `masquerade random,fully-random` to put a client behind a genuinely hostile, simulated symmetric NAT. Validated, in order: (1) TURN REST credentials work end-to-end (allocate/refresh via loopback); (2) private-range relay denial correctly rejects both a `CreatePermission` and a `ChannelBind` to a private peer; (3) raw ICMP and UDP (including full request-response round trips) traverse the simulated NAT correctly; (4) **the core deliverable** — a full TURN session (allocate, refresh, 4 channel binds, sustained relay) from the NAT'd client completed with zero packet loss, proving TURN relay works through symmetric NAT. Along the way, diagnosed and fixed two real problems: a transient Docker Desktop daemon crash (recovered by relaunching and recreating the lost containers) that had been producing misleading "stuck with no output" symptoms, and a genuine, reproducible Docker-Desktop-for-Mac-only bug where `network_mode: host` binds into the LinuxKit VM's own namespace, unreachable from bridge-networked containers via `host.docker.internal` — confirmed via `tcpdump` showing zero response packets, reproduced with no NAT simulation in the path at all, fixed by giving Coturn a normal bridge address for this harness (not a recommendation for the real deployment, which should still use host networking on a real Linux host). Also found a real config sizing bug under a 10-client load burst: the spike's 100-port relay range was exhausted (`create_relay_ioa_sockets: no available ports`), informing a concrete Unit 4 recommendation. Wrote up `aidlc-docs/construction/spikes/spike-2.3-report.md` (all three exit criteria met) and the harness's own `README.md`. Committed the harness to its own spike branch (pushed to origin for reference, never merged, per Q5:A) and opened a separate docs-only PR carrying just the report, per Q3:A. Updated `aidlc-state.md`: Spike 2.3 marked COMPLETE, Unit 4 (Coturn Infrastructure) now unblocked, two new Backlog items added (port-range sizing, deferred full-scale load test).
**Context**: Spike 2.3 is complete. Unit 4 (Coturn Infrastructure, gated by SR-03) can now start — awaiting the docs PR's review/merge and the user's go-ahead to begin it.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): started, NFR Requirements plan generated
**Timestamp**: 2026-10-02T15:54:49Z
**User Input**: "PR 26 approved and merged, let's proceed with unit 4"
**AI Response**: Confirmed PR #26 and PR #25 both merged; pulled `develop`, deleted the now-merged `docs/spike-2.3-report` and `chore/log-unit3-merge` branches. Branched `feature/coturn-infrastructure` off `develop`. Unit 4 skips Functional Design (no business logic, per `phase2-unit-of-work.md`) — read Application Design's fixed component list and interface signatures (`IceServerProvider`, `TurnCredentialService`) plus Spike 2.3's report as this unit's inputs instead. Saved `aidlc-docs/construction/plans/coturn-infrastructure-nfr-requirements-plan.md` with 10 questions covering the items Spike 2.3 explicitly left open (relay port range sizing, credential-issuer placement) plus the standard NFR categories, each recommending the option matching this project's own existing precedent where one exists (Unit 3's `resolve_broadcast_id` pattern for the credential issuer, Unit 4/Supabase-Local-Dev's `127.0.0.1`-only posture for metrics, Unit 2's crash-reporting-deferral reasoning for alerting).
**Context**: Awaiting user answers before generating the NFR Requirements artifacts.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): Q5 corrected after user question
**Timestamp**: 2026-10-02T16:05:00Z
**User Input**: "For Q5, what happens if a TURN credential's TTL expires while a viewer is connected and receiving data? Will it renew automatically, or would the viewer get cut off?"
**AI Response**: Explained the actual TURN protocol mechanics: TTL only gates the credential, not the allocation itself; an active allocation is kept alive by periodic `Refresh` requests which must re-authenticate, so once the credential expires the next refresh is rejected (401) and the allocation is torn down shortly after — a real disconnection, not a graceful degradation, and TURN has no automatic renewal built in. Updated Q5 to keep the 1-hour TTL but make proactive `setConfiguration()`-based credential refresh a **hard requirement of Unit 5** (the component that owns long-lived WebRTC sessions), per the user's explicit choice, rather than leaving it an optional/deferred Backlog item.
**Context**: Plan corrected; awaiting the user's review of the rest of the plan before generating NFR Requirements artifacts.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): alerting-infrastructure Backlog entry added (Q9)
**Timestamp**: 2026-10-02T16:06:56Z
**User Input**: "For Q9, we need to ensure we've added the required alerting infrastructure to the backlog."
**AI Response**: Checked `aidlc-state.md`'s Backlog — only Unit 2's crash-reporting-SDK deferral existed, a distinct concern (client-side error visibility, not operational/infrastructure monitoring). Added a new, separate Backlog entry for operational/infrastructure alerting (project-wide, not yet adopted), and updated Q9's plan text to reference it explicitly so the two deferrals don't get conflated later.
**Context**: Awaiting the user's final approval of the full plan before generating NFR Requirements artifacts.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): NFR Requirements plan approved
**Timestamp**: 2026-10-02T16:09:18Z
**User Input**: "approve coturn infrastructure nfr requirements plan, proceed"
**AI Response**: All 10 questions approved as answered (Q1-A, Q2-A, Q3-A, Q4-A, Q5-A as corrected, Q6-A, Q7-A, Q8-A, Q9-A as corrected, Q10-A). Generating `nfr-requirements.md` and `tech-stack-decisions.md`.
**Context**: Proceeding to generate Unit 4's NFR Requirements artifacts.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): NFR Requirements approved
**Timestamp**: 2026-10-02T16:31:34Z
**User Input**: "approve and proceed"
**AI Response**: NFR Requirements marked complete and approved for Unit 4. Proceeding to NFR Design.
**Context**: Unit 4 (Coturn Infrastructure) NFR Requirements COMPLETE and approved.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): NFR Design plan generated
**Timestamp**: 2026-10-02T16:32:49Z
**User Input**: (implicit, continuing from NFR Requirements approval)
**AI Response**: Saved `aidlc-docs/construction/plans/coturn-infrastructure-nfr-design-plan.md` with 2 questions: (Q1) credential-fetch failure handling — recommended fail-fast/propagate rather than a silent STUN-only fallback, since that would just defer the same problem to a more confusing later ICE-timeout failure for exactly the symmetric-NAT users TURN exists to serve; (Q2) `IceServer`'s concrete shape, left unfixed by Application Design — recommended the standard `RTCIceServer`-equivalent shape (`urls`, nullable `username`/`credential`). Scalability/Performance restated from NFR Requirements with no new question (already fully covered there). Logical Components section lays out the full component list and dependency direction.
**Context**: Awaiting user answers before generating the NFR Design artifacts.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): NFR Design plan approved
**Timestamp**: 2026-10-03T00:41:11Z
**User Input**: "approve and proceed"
**AI Response**: Both questions approved as answered (Q1-A fail-fast propagation, Q2-A standard `IceServer` shape). Generating `nfr-design-patterns.md` and `logical-components.md`.
**Context**: Proceeding to generate Unit 4's NFR Design artifacts.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): NFR Design approved
**Timestamp**: 2026-10-03T00:45:38Z
**User Input**: "approve"
**AI Response**: NFR Design marked complete and approved for Unit 4. Proceeding to Infrastructure Design (this unit's SR-03 approval gate — the log configuration document, per `phase2-unit-of-work.md`).
**Context**: Unit 4 (Coturn Infrastructure) NFR Design COMPLETE and approved.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): Infrastructure Design plan generated
**Timestamp**: 2026-10-03T00:48:02Z
**User Input**: (implicit, continuing from NFR Design approval)
**AI Response**: Saved `aidlc-docs/construction/plans/coturn-infrastructure-infrastructure-design-plan.md` with 3 questions. Q1 (networking mode for the real, committed `packages/zip_supabase/docker-compose.yml`) needed empirical verification before recommending an answer — ran a minimal host-networked Coturn container directly and confirmed via `nc`/`turnutils_stunclient` that the native macOS shell (outside any container, the same path a locally-run Flutter app uses) successfully reaches it via `localhost` over UDP with a real STUN binding response. This confirms Spike 2.3's found Docker-Desktop-for-Mac limitation is specific to *container-to-container* traffic (`host.docker.internal`), not host-to-container — so `network_mode: host` is recommended for the real committed config after all, since nothing inside this Docker stack needs to reach Coturn directly, only the app from outside it. Q2 (shared-secret storage) and Q3 (migration placement) both recommend direct reuse of this project's existing `JWT_SECRET`/Unit-3-migration patterns.
**Context**: Awaiting user answers before generating the Infrastructure Design artifacts (including the SR-03 log-configuration approval-gate document).

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): Q1 verified against official Coturn documentation
**Timestamp**: 2026-10-03T00:51:22Z
**User Input**: "For question 1, I want you to check the coturn documentation, use the docs-mcp server, and determine the correct approach to deploying and connecting to it from other containers in the docker network. There's likely a proper approach documented"
**AI Response**: Indexed Coturn's official Docker documentation (`docker/coturn/README` from the `coturn/coturn` GitHub repo) into docs-mcp (not previously indexed). Confirmed host networking is Coturn's own explicitly documented recommendation — their docs cite Docker performing badly with large published port ranges as the reason, which directly applies here given NFR Requirements already widened the relay range to ~16,384 ports. Their documentation does not address container-to-container reachability (out of Coturn's own scope, a Docker-orchestration concern). Updated Q1's rationale in the plan to cite this primary source directly alongside the project's own already-completed empirical verification (a native macOS process reaching a host-networked Coturn container via `localhost`, matching the real connection path this stack needs). No change to the recommended answer (A) — now backed by both official documentation and direct verification rather than inference alone.
**Context**: Awaiting the user's approval of the plan before generating the Infrastructure Design artifacts.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): Infrastructure Design plan approved
**Timestamp**: 2026-10-03T00:51:59Z
**User Input**: "proceed"
**AI Response**: All 3 questions approved as answered (Q1-A host networking, confirmed via official Coturn docs and direct empirical test; Q2-A shared-secret storage mirroring JWT_SECRET; Q3-A new forward-only migration). Generating `sr-03-log-configuration.md`, `infrastructure-design.md`, and `handoff-summary.md`.
**Context**: Proceeding to generate Unit 4's Infrastructure Design artifacts, including the SR-03 approval-gate document.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): Infrastructure Design artifacts generated
**Timestamp**: 2026-10-03T01:05:00Z
**User Input**: (none — generation phase, continuing from the approved plan)
**AI Response**: Generated all 3 Infrastructure Design artifacts in `aidlc-docs/construction/coturn-infrastructure/infrastructure-design/`:
- `sr-03-log-configuration.md` — the SR-03 approval-gate document, scoped specifically to Coturn's logging configuration per `phase2-unit-of-work.md`. Documents the `simple-log`/`no-stdout-log`/no-verbose-flag config, cites Spike 2.3's empirical verification (every allocate/refresh/channel-bind/relay test run against this exact config produced no payload content in the resulting log), and notes the TURN shared secret never passes through Coturn's own logging path. Ends with an unchecked `## 6. Approval` checkbox awaiting the user's sign-off, matching SR-01/SR-02's exact format.
- `infrastructure-design.md` — the real `packages/zip_supabase/docker-compose.yml` Coturn service addition (`network_mode: host`, `restart: unless-stopped`, `turnutils_stunclient`-based health check), `TURN_SHARED_SECRET` env var wiring (mirroring `JWT_SECRET`'s `.env.example` + `ALTER DATABASE ... SET app.settings.*` pattern, including the Kong-style `${VAR}` substitution fix), the new `get_turn_credentials()` migration (SQL sketched, `SECURITY DEFINER`, no table/RLS needed), confirmation that no Kong/`kong.yml` change is needed (same `/rest/v1/rpc/` path as Unit 3), and a Security Compliance table.
- `handoff-summary.md` — fixed contracts restated for Code Generation, full file list for both `zip_supabase` (migration, compose service, `turnserver.conf`, `.env.example`) and `zip_core` (models, services, providers), the mocktail + `integration-supabase`-tagged testing approach, and an explicit flag that SR-03 approval is required before this unit's PR can merge.
**Context**: Infrastructure Design artifacts complete. Presenting the "Infrastructure Design Complete" summary and awaiting the user's approval, including sign-off on SR-03, before proceeding to Code Generation.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): Infrastructure Design approved, SR-03 signed off
**Timestamp**: 2026-10-03T01:15:00Z
**User Input**: "approved"
**AI Response**: Infrastructure Design stage approved, including the SR-03 log-configuration security gate. Checked the SR-03 approval checkbox in `sr-03-log-configuration.md` (Approved by: James Petersen, Date: 2026-10-03). Proceeding to Code Generation Part 1 (plan).
**Context**: Unit 4 Infrastructure Design stage complete and approved. Next: Code Generation Part 1 (implementation plan).

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): Code Generation Part 1 (Plan Created)
**Timestamp**: 2026-10-03T01:20:00Z
**User Input**: (none — automatic, continuing from Infrastructure Design approval)
**AI Response**: Created `coturn-infrastructure-code-generation-plan.md` with 18 steps: infra (migration, `turnserver.conf`, compose service, `.env.example`, secret substitution), `zip_core` Dart (`TurnCredentials`, `IceServer` models; `TurnCredentialService`/`SupabaseTurnCredentialService`, `IceServerProvider`/`SupabaseIceServerProvider`; Riverpod providers; barrel exports), tests (mocktail unit tests + one `integration-supabase`-tagged real-backend test), and verification steps. Full FR/NFR traceability table included.
**Context**: Code Generation Part 1 complete. Awaiting approval before Part 2 (generation).

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): Code Generation Part 1 approved
**Timestamp**: 2026-10-03T01:25:00Z
**User Input**: "approve and proceed"
**AI Response**: Code Generation plan approved. Proceeding to Part 2 (generation).
**Context**: Executing the 18-step plan.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): Infrastructure Design correction found during Code Generation
**Timestamp**: 2026-10-03T01:28:00Z
**User Input**: (none — found while implementing Step 1/2/3)
**AI Response**: The approved Infrastructure Design assumed Coturn's `turnserver.conf` supports Kong-style `${VAR}` substitution for the shared secret, requiring a custom entrypoint. Verified against the official Coturn documentation (docs-mcp, already indexed from the earlier Q1 check) that Coturn has no such feature — the documented way to inject a secret is a CLI flag. Corrected the design in place: the `coturn` service now uses a `command: ["--static-auth-secret=${TURN_SHARED_SECRET}"]` override (substituted by Docker Compose itself from `.env`, same interpolation mechanism Kong's `environment:` block already uses, just applied to `command:`), `turnserver.conf` drops its `static-auth-secret` line entirely, and the migration sets `app.settings.turn_shared_secret` to a literal placeholder value (not a shell variable — confirmed Postgres migrations have no templating, matching how `jwt_secret` is already set literally). Updated `infrastructure-design.md` and dropped the now-unnecessary entrypoint step from the Code Generation plan. No change to the recommended networking mode, migration placement, or SR-03 log configuration — this correction is scoped only to how the secret reaches each component.
**Context**: Proceeding with Code Generation using the corrected secret-delivery mechanism.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): Code Generation complete, two real issues found and fixed by testing
**Timestamp**: 2026-10-04T00:00:00Z
**User Input**: (none — generation and verification phase)
**AI Response**: Completed all 18 Code Generation plan steps. Shipped: the migration (`20261003000000_coturn_turn_credentials.sql`), the real `turnserver.conf` and `docker-compose.yml` `coturn` service, `.env.example` entry, and `zip_core`'s `TurnCredentials`/`IceServer` models, `TurnCredentialService`/`SupabaseTurnCredentialService`, `IceServerProvider`/`SupabaseIceServerProvider`, Riverpod providers, and barrel exports. 406 `zip_core` tests passing (2 skipped-by-default integration), `dart analyze --fatal-infos` clean.

Rather than only reading the migration for correctness, brought up a real local Supabase stack (fresh, no pre-existing volumes) and exercised the actual RPC path end-to-end. This surfaced two real defects the design/plan review hadn't caught:
1. **Anonymous access gap**: this project's Postgres bootstrap grants `EXECUTE` on every new `public`-schema function to `anon` by default (`ALTER DEFAULT PRIVILEGES`, confirmed via `pg_default_acl`). `get_or_create_my_broadcast_id()` (Unit 3) is protected from this by its table's RLS, but `get_turn_credentials()` has no table — `SET ROLE anon; SELECT * FROM get_turn_credentials();` **succeeded** before a fix. Fixed with an explicit `auth.uid() IS NULL` guard inside the function body (a `REVOKE`/`GRANT` pair alone would not have survived a future `CREATE OR REPLACE`, since the default privileges re-grant on every redeploy). Re-verified: anon now gets `42501`.
2. **Missing `search_path`**: `hmac()` lives in the `extensions` schema in this project's Postgres image, not `public`. A direct `psql` session's default search_path found it; PostgREST's own connections did not, failing with `function hmac(...) does not exist` on the real Kong/PostgREST path. Fixed with `set search_path = public, extensions`, matching the identical clause `get_or_create_my_broadcast_id()` already carries for `gen_random_bytes()`.

Both fixes re-verified against the real stack: an authenticated call through Kong/PostgREST (genuine signed-up user JWT) returns a credential whose HMAC-SHA1 was independently recomputed in Python and matched exactly; the new `integration-supabase`-tagged test (2 cases) passes against this live stack. `infrastructure-design.md` and the Code Generation plan updated in place; full account in `aidlc-docs/construction/coturn-infrastructure/code/unit4-summary.md`.
**Context**: Code Generation COMPLETE. Awaiting approval before PR.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): Code Generation approved, PR #27 opened
**Timestamp**: 2026-10-04T00:05:00Z
**User Input**: "approved, proceed"
**AI Response**: Code Generation accepted. Staged and committed all Unit 4 files (migration, `turnserver.conf`, `docker-compose.yml` `coturn` service, `.env.example` entry, `zip_core` models/services/providers, tests, and the full `aidlc-docs/construction/coturn-infrastructure/` design history) — commit `3369da0`. Confirmed `.env` stayed gitignored and out of the commit. Pushed `feature/coturn-infrastructure` and opened PR #27 against `develop` (gitflow convention), summarizing the design decisions, the SR-03 sign-off, and the two defects found and fixed while verifying against the real stack.
**Context**: Awaiting CI and CodeRabbit review on PR #27.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): PR #27 CodeRabbit review round 1 — 2 findings fixed
**Timestamp**: 2026-10-04T19:40:00Z
**User Input**: "use the gh cli to check for review"
**AI Response**: CI all green (6/6 checks). CodeRabbit left 2 actionable comments, both genuine:
1. `get_turn_credentials()`'s `current_setting()` ran in the `DECLARE` block, before the `auth.uid()` check — an anonymous caller in a misconfigured deployment would see a raw Postgres error instead of `42501`. Fixed: moved the lookup after the auth check, used `current_setting(..., true)`, raised a clear exception on an unset secret.
2. `.coderabbit.yaml`'s path instructions require every `zip_supabase/**` service to bind `127.0.0.1` only; `network_mode: host` with no `listening-ip` set meant Coturn's control port was actually bound on every local interface (confirmed via `/proc/net/udp`). Fixed with `listening-ip=127.0.0.1` — deliberately left `relay-ip` unset, since restricting relay sockets to loopback would break relaying to any real peer, which is the service's entire purpose; `denied-peer-ip` is the correct, already-existing control on relay targets.

Both fixes re-verified against the live local Supabase stack (not just read): the 2 integration test cases still pass; `/proc/net/udp` confirms the control port moved to loopback-only; a full `turnutils_uclient` allocate/refresh/channel-bind run through the loopback control port still works, with its self-targeted channel-bind still correctly rejected (`403 Forbidden IP`) exactly as before — confirming `denied-peer-ip` is unaffected. `dart analyze --fatal-infos` clean, 406 tests passing. Full account in `unit4-summary.md`.
**Context**: Committing fixes and pushing to PR #27; will reply to CodeRabbit's review thread.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): PR #27 CodeRabbit review round 2 — 1 finding fixed
**Timestamp**: 2026-10-04T22:50:00Z
**User Input**: "check now"
**AI Response**: Round 2 review (triggered by the `@coderabbitai review` reply) came back `COMMENTED` with one new outside-diff finding: `SupabaseIceServerProvider` read its STUN/TURN URLs straight from `TurnCredentials.urls` (hardcoded `localhost` in the migration), which an Android emulator can't reach (it needs the `10.0.2.2` host-loopback alias, not `localhost`) — the server has no way to know which hostname a given client can actually reach it at. This was a genuine regression from `logical-components.md`'s original design ("constructed with those URLs at app startup, mirrors how `supabaseClientProvider`'s URL is provided"), which a Code Generation Step 11 simplification had drifted away from. Fixed by reverting to construction-time URL injection: added `iceServerUrls` to `zip_core/lib/src/constants/turn_config.dart`, mirroring `supabaseUrl`'s existing `--dart-define`-overridable pattern exactly (same mechanism this project already uses for the identical "server can't guess the client's reachable hostname" problem with Supabase's own URL). `SupabaseIceServerProvider` now takes `urls` as a constructor parameter instead of reading `TurnCredentials.urls`. Updated the unit test to use deliberately different values for the injected urls vs. `TurnCredentials.urls`, so it would fail if the old (wrong) behavior regressed. `dart analyze --fatal-infos` clean, 406 tests passing. Full account in `unit4-summary.md`.
**Context**: Committing and pushing the fix, then requesting another CodeRabbit review.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): PR #27 CodeRabbit review round 3 — 1 finding fixed
**Timestamp**: 2026-10-05T00:10:00Z
**User Input**: "another review comment, do not re-request a review, we get rate-limited by coderabbit"
**AI Response**: Round 3 (auto-triggered by the round-2 reply before this instruction) found one minor issue: `iceServerUrls.split(',')` left leading/trailing whitespace in each URL if a `--dart-define` override had spaces around its commas. Fixed with `.map((url) => url.trim())`. `dart analyze --fatal-infos` clean, 406 tests passing. Per the user's instruction, did **not** post another `@coderabbitai review` trigger comment this time — committed and pushed only.
**Context**: Awaiting the user's own timing for the next CodeRabbit check, to avoid the hourly rate limit.

---

## CONSTRUCTION - Unit 4 (Coturn Infrastructure): PR #27 approved, squashed and merged — Unit 4 COMPLETE
**Timestamp**: 2026-10-05T04:10:00Z
**User Input**: "pr approved, squashed and merged, we are ready to proceed"
**AI Response**: Confirmed via `gh pr view 27` — merged (squash commit `6bf3da6`, 2026-10-05T04:04:44Z). Switched to `develop`, pulled the merge, deleted the local and remote `feature/coturn-infrastructure` branches. Marked Unit 4 (Coturn Infrastructure, S-12, SR-03) COMPLETE in `aidlc-state.md`, summarizing all three CodeRabbit review rounds. Checked the dependency matrix (`phase2-unit-of-work.md`): Unit 5 (WebRTC Transport + Remote Output + Capacity, S-14/S-16/S-18) depends on Unit 3 (done), Unit 4 (now done), and Spike 2.1 (paused, interim values already accepted 2026-09-29) — all satisfied.
**Context**: Unit 4 fully complete and merged. Proceeding to Unit 5, starting with Functional Design (unlike Unit 4, Unit 5 has business logic and does not skip this stage).

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): started, Functional Design approved, NFR Requirements drafted — then paused
**Timestamp**: 2026-10-05T04:20:00Z – 2026-10-05T05:10:00Z
**User Input**: branch/session/model check, "proceed", "approve and proceed", NFR Requirements answers plus two requests (re-verify `flutter_webrtc`'s version; add a durable Backlog entry to revisit `BroadcastLimits` post-release)
**AI Response**: Created `feature/webrtc-transport-remote-output-capacity` off `develop` (after confirming no new session or model switch was needed — Construction stays on Sonnet). Generated and the user approved Unit 5's Functional Design plan (8 questions: an application-level join-ack + 5s timeout closing Spike 2.1's SCTP/DCEP-stall finding; unbounded exponential-backoff reconnection; `ConnectFailure`'s 4 variants; a minimal fakeable `PeerConnectionHandle` seam; `BroadcastTransportContext`/`ViewerTransportContext` fields; a reconnection-aware `ViewerAdmission` honoring `reconnectWindow`; wire-format version 1; a single-message join snapshot) and its resulting artifacts (`domain-entities.md`, `business-logic-model.md`, `business-rules.md`, 8 numbered business rules). Generated the NFR Requirements plan (7 questions, most notably that this unit's test suite can construct zero real `flutter_webrtc` objects at all — no native platform channel exists in `flutter test`, so real two-device/TURN verification is entirely Unit 9's job). Re-verified `flutter_webrtc: ^1.6.2+hotfix.3` as still current against both pub.dev and the GitHub releases page per the user's explicit request. Added a durable Backlog entry for revisiting `BroadcastLimits`'s interim values post-release, separate from the transient "Current Stage" line. While reviewing the Backlog for that edit, surfaced an existing, still-open entry from Unit 3's PR #24 review flagging "revisit at Unit 5" for signaling-session presence privacy — not yet addressed by Unit 5's plan.
**Context**: Investigating the flagged privacy gap before finalizing NFR Requirements.

---

## CONSTRUCTION - Signaling privacy investigation: v1 codebase check, shipped-code review, risk assessment, web research
**Timestamp**: 2026-10-05T05:15:00Z – 2026-10-05T06:00:00Z
**User Input**: "look at the original zip captions project... to see how this was implemented in v1" → "What are the implications of leaving this as-designed?... What private information could be subject to leak" → "find anything on the web about this... how we might build it so it's still privacy focused"
**AI Response**: Read v1's Socket.IO signaling server (`~/Documents/zip-captions/packages/signal`) and client (`peer.service.ts`) — found v1 broadcasts `'user joined room'`/`'user left room'` to every socket in the room, including other viewers; the official client only *ignores* this for non-host instances, which is UI-level hiding, not a real boundary. Not a pattern to replicate. Then read the actual shipped Unit 3 file (`packages/zip_core/lib/src/services/signaling/supabase_session_signaling_channel.dart`) directly and confirmed two real, separate leaks: (1) every viewer's own official `.presence` getter already returns every other participant's presence (the file's own doc comment admits this), and (2) `onBroadcast` forwards every `SignalingMessage` — including other viewers' `SdpOffer`/`IceCandidate`, which carry real host-candidate IP/port metadata — to every subscriber with no recipient filtering, independent of the presence leak. Confirmed what's *not* exposed: no caption content (travels over the WebRTC data channel, never this signaling channel) and no account identity (`viewerIdentity` hardcoded null in Phase 2). Flagged the structural fragility: no recipient filtering means any future field added to these messages leaks by default. Then researched fixes: confirmed via Supabase's own Presence docs that there is no built-in per-subscriber filtering ("you would need to implement it at the application level or use separate channels for different user groups") and found AWS Kinesis Video Streams WebRTC's "master/viewer" signaling model as production precedent — "a viewer cannot discover or interact with other viewers" by construction (server-side point-to-point message routing in AWS's case). Proposed the equivalent fix for this project's Supabase-based stack: a broadcaster-only lobby topic for `JoinRequest` plus a private per-viewer topic (`signaling:{session_id}:{peerId}`), with privacy coming from the per-peer topic name's own unguessability rather than a persisted session-owner table (compatible with FR-2.6).
**Context**: Proposed scoping this as a new unit rather than reopening Unit 3; awaiting the user's direction on placement.

---

## CONSTRUCTION - Roadmap amendment: Unit 3.1 (Signaling Channel Privacy) inserted, Unit 5 paused
**Timestamp**: 2026-10-05T06:05:00Z
**User Input**: "We cannot change units that are complete, that code has shipped. We must look at the roadmap and current state of the code and find the correct place to stitch this work into the plan." → "yes, proceed"
**AI Response**: Confirmed via the dependency matrix that Unit 3's signaling is a direct dependency of only Unit 5 (Units 6/7 get it indirectly, through Unit 5) — and that Unit 5 itself has no shipped code yet (Functional Design + a draft NFR Requirements plan only), making this the correct, least-disruptive insertion point. Committed Unit 5's current state as a WIP checkpoint on its own branch (commit `89c1f30`) and pushed it for safekeeping, explicitly marked paused — nothing reopened or edited on `develop`. Switched to `develop`, created `feature/signaling-channel-privacy` for the new **Unit 3.1: Signaling Channel Privacy**, inserted between Units 3/4 and Unit 5 in `phase2-unit-of-work.md`, `phase2-unit-of-work-dependency.md` (dependency matrix, graph, critical path, build order, shared-resources table, testing checkpoints all updated), and `phase2-unit-of-work-story-map.md` (new story S-13.1, new security gate SR-04 "Signaling Channel Isolation Review" mirroring SR-02's pattern, coverage count updated to 11/11 stories and 4/4 security reviews). Added new **NFR-3.9** to `phase2-requirements.md` capturing "no viewer-to-viewer visibility" explicitly, distinct from NFR-3.5/3.6. Does not reopen or edit Unit 3's merged PR/artifacts — ships as new code only, the established precedent (`20261001000001_fix_jwt_secret_mismatch.sql`). Updated `aidlc-state.md`: added Unit 3.1's entry, marked Unit 5 paused with its branch/location noted, updated the original PR #24 Backlog entry to point at Unit 3.1 instead of leaving it as a dangling "revisit at Unit 5" note.
**Context**: Unit 3.1 created and started. Next: Unit 3.1's Functional Design (the per-viewer channel/topic scheme and SR-04's policy document).

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): Functional Design plan generated
**Timestamp**: 2026-10-05T06:30:00Z
**User Input**: (none — automatic, continuing from the roadmap amendment)
**AI Response**: Read the existing shipped migration directly (`20261001000000_broadcast_identity_signaling.sql`) and found the `broadcast` extension's INSERT and SELECT are already separate RLS policies on `realtime.messages` — confirming Realtime's authorization model can distinguish "may publish" from "may subscribe," which is what makes a broadcaster-only lobby channel possible. Generated `signaling-channel-privacy-functional-design-plan.md` with 6 questions, the key insight being Q1: key the lobby channel by the **permanent** `broadcast_id` rather than the ephemeral `session_id`, so RLS can check ownership against the **already-existing** `broadcast_identities` table (built by Unit 3 for a different purpose) instead of needing any new persisted session-ownership mapping — keeping FR-2.6 ("no session records") fully satisfied. Per-viewer channels (Q3) stay symmetric/open at the RLS layer, since their privacy comes from the topic name's own unguessability, not identity verification. Q5 recommends dropping Realtime presence entirely from these channels, since Unit 5's own design never relied on it (ack-based confirmation + native ICE state) — flagged for Unit 6's own Functional Design to consume `BroadcastTransport.viewers` for the dashboard count instead. Q6 refines `SignalingService`'s shape (`lobbyChannel`/`sessionChannel(sessionId, peerId)`), the same kind of non-final-signature refinement Unit 4 made to `IceServer`. One genuine open technical question flagged for empirical verification at Code Generation rather than decided now: whether Realtime's Broadcast INSERT truly works without the client reaching a subscribed state.
**Context**: Functional Design plan complete. Awaiting the user's answers before proceeding to artifact generation.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): Functional Design plan approved
**Timestamp**: 2026-10-05T06:40:00Z
**User Input**: "approved"
**AI Response**: All 6 questions approved as answered (A throughout): Q1 `broadcast_id`-keyed lobby channel checked against the existing `broadcast_identities` table; Q2 lobby RLS (open INSERT, owner-only SELECT); Q3 unguessable per-viewer `peerId` channel naming, symmetric RLS; Q4 viewer-subscribes-first join sequencing; Q5 presence dropped entirely; Q6 `SignalingService` gains `lobbyChannel`/revised `sessionChannel(sessionId, peerId)`. Generating `business-logic-model.md`, `business-rules.md`, `domain-entities.md`.
**Context**: Proceeding to generate Unit 3.1's Functional Design artifacts.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): Functional Design artifacts generated
**Timestamp**: 2026-10-05T06:50:00Z
**User Input**: (none — generation phase, continuing from the approved plan)
**AI Response**: Generated all 3 Functional Design artifacts in `aidlc-docs/construction/signaling-channel-privacy/functional-design/`:
- `domain-entities.md` — the new channel topology (`status:{broadcast_id}` unchanged, new `signaling:{broadcast_id}:lobby` and `signaling:{session_id}:{peerId}`), the new `LobbyChannel` interface, revised `SessionSignalingChannel`/`SignalingService` (presence getter and `SignalingRole` removed), `PeerId`'s entropy requirement, and a routing table mapping each `SignalingMessage` variant to its channel.
- `business-logic-model.md` — the full join sequence (viewer subscribes to its own channel before sending `JoinRequest`, closing the race by construction), teardown paths, and how the viewer count is now produced (the broadcaster's own open-channel bookkeeping, not presence).
- `business-rules.md` — 9 numbered rules, most load-bearing: Rule 2 (lobby ownership check reusing the existing `broadcast_identities` table, no new persisted mapping), Rule 3 (per-viewer RLS stays symmetric — unguessability, not identity, is the control), Rule 6 (presence may never be reintroduced on either channel), and Rule 9 (the send-without-subscribe behavior must be empirically confirmed against the real local stack before the migration ships, not assumed from documentation).
**Context**: Functional Design artifacts complete. Presenting the "Functional Design Complete" summary and awaiting approval before proceeding to NFR Requirements.

---

## PROCESS - Git commit timing corrected
**Timestamp**: 2026-10-05T07:00:00Z
**User Input**: "why did you commit the plan before I reviewed it?... Did you deviate from the ai-dlc process?" → "You need to go back to committing only before PR or branch switch... it's not appropriate to commit without my express approval." → "I want you to reset any commits for 3.1 that you already did, let's do this work properly"
**AI Response**: Confirmed the deviation: Units 2-4 correctly stayed uncommitted stage-by-stage (one bundled commit right before each PR); that habit broke after a justified one-off WIP checkpoint before pausing Unit 5, and continued without justification into Unit 3.1. Soft-reset `feature/signaling-channel-privacy` to `26c173a` (the branch point, matching `develop`), restoring all 10 files as staged-but-uncommitted changes — no content lost. Left `origin/feature/signaling-channel-privacy` (3 commits ahead) untouched per the user's instruction; flagged that a `git pull` on this branch would reintroduce those commits and should be avoided until an intentional push. Saved a standing feedback memory (`feedback_commit_only_before_pr_or_branch_switch.md`): never commit AI-DLC stage artifacts as-you-go; only commit immediately before opening a PR or switching branches, and only with explicit approval at that point.
**Context**: Going forward, all stage artifacts stay uncommitted on disk (visible as a live diff in VS Code's Source Control panel) until the user explicitly approves a commit at a PR or branch-switch point.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): Functional Design approved
**Timestamp**: 2026-10-05T07:05:00Z
**User Input**: "approved, proceed"
**AI Response**: Functional Design marked complete and approved for Unit 3.1. Proceeding to NFR Requirements. (Not committed — per the corrected process, work stays uncommitted on disk.)
**Context**: Unit 3.1 Functional Design COMPLETE and approved.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): missing SR-04 document caught and generated
**Timestamp**: 2026-10-05T07:08:00Z
**User Input**: (none — self-caught before proceeding to NFR Requirements)
**AI Response**: Unit 3.1's own roadmap entry specifies Functional Design "produces the SR-04 policy document" as a dedicated approval-gate file, matching SR-01/SR-02's precedent (each got its own file, e.g. `sr-02-rls-realtime-policy.md`, separate from `domain-entities.md`/`business-rules.md`). That dedicated file was missed when the other 3 artifacts were generated. Created `sr-04-signaling-channel-isolation.md` now, before proceeding, with the full RLS policy table (lobby INSERT open/SELECT ownership-checked against `broadcast_identities`; per-viewer channel INSERT+SELECT symmetric/open; no presence policy on either), the reasoning for dropping presence entirely rather than re-scoping it, and an unchecked Approval section pending the user's explicit sign-off — distinct from the general Functional Design approval already given, matching SR-01/02/03's precedent of a separately-signed security gate.
**Context**: Awaiting explicit SR-04 approval before proceeding to NFR Requirements.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): SR-04 signed off
**Timestamp**: 2026-10-05T07:12:00Z
**User Input**: "approved, proceed"
**AI Response**: Checked the SR-04 approval checkbox in `sr-04-signaling-channel-isolation.md` (Approved by: James Petersen, Date: 2026-10-05). Unit 3.1 Functional Design (including SR-04) now fully complete. Proceeding to NFR Requirements.
**Context**: Unit 3.1 Functional Design COMPLETE, SR-04 signed off.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): NFR Requirements plan generated
**Timestamp**: 2026-10-05T07:15:00Z
**User Input**: (none — automatic, continuing from SR-04 sign-off)
**AI Response**: Created `signaling-channel-privacy-nfr-requirements-plan.md` with 6 questions. Q1 flags verifying empirically (not just from docs) that a broadcaster holding up to 50 concurrent per-viewer Realtime channel subscriptions at the interim cap hits no platform limit. Q4 is the most load-bearing: this unit's correctness claim is a negative ("a viewer sees nothing"), which fakes can't demonstrate by construction — recommends a real-backend `integration-supabase`-tagged test with two concurrently-connected real viewer clients, matching the dependency doc's own testing checkpoint. Q2/Q3/Q5/Q6 confirm no new measurable performance target, no new cleanup mechanism (existing connection-lifecycle behavior already bounds the worst case correctly), no new dependencies, and no new PBT suite (channel isolation is a fixed yes/no RLS property, not a generated-input space).
**Context**: NFR Requirements plan complete. Awaiting the user's answers before proceeding to artifact generation.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): NFR Requirements plan approved
**Timestamp**: 2026-10-05T07:20:00Z
**User Input**: "approved. proceed"
**AI Response**: All 6 questions approved as answered (A throughout). Generating `nfr-requirements.md` and `tech-stack-decisions.md`.
**Context**: Proceeding to generate Unit 3.1's NFR Requirements artifacts.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): NFR Requirements artifacts generated
**Timestamp**: 2026-10-05T07:25:00Z
**User Input**: (none — generation phase, continuing from the approved plan)
**AI Response**: Generated `nfr-requirements.md` (Security Baseline compliance table — 7 Compliant, 8 N/A; PBT Compliance table — all N/A except PBT-10, since this unit changes signaling routing, not message shape, and its one real property is proven by the Q4 integration test, not a generated-input suite) and `tech-stack-decisions.md` (no new dependencies; the new migration explicitly drops the superseded `signaling:{session_id}` policies rather than leaving them dangling; the Q1 channel-count verification and Q4 two-viewer integration test both documented as required Code Generation steps) in `aidlc-docs/construction/signaling-channel-privacy/nfr-requirements/`.
**Context**: NFR Requirements artifacts complete. Presenting the "NFR Requirements Complete" summary and awaiting approval before proceeding to NFR Design.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): NFR Requirements approved
**Timestamp**: 2026-10-05T07:30:00Z
**User Input**: "approved"
**AI Response**: NFR Requirements marked complete and approved for Unit 3.1. Proceeding to NFR Design.
**Context**: Unit 3.1 NFR Requirements COMPLETE and approved.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): NFR Design plan generated
**Timestamp**: 2026-10-05T07:35:00Z
**User Input**: (none — automatic, continuing from NFR Requirements approval)
**AI Response**: Created `signaling-channel-privacy-nfr-design-plan.md` with 2 questions (Scalability/Performance and Security restated from NFR Requirements/SR-04 with justification, no new question). Q1 closes a real gap `business-logic-model.md` left open: nothing previously bounded a viewer's wait if the broadcaster never responds to its `JoinRequest` at all — recommends a 3-attempt resend (2s/5s/10s) before mapping to Unit 5's existing `ConnectFailure.Timeout`, reusing that variant rather than inventing a signaling-specific failure type. Q2 fixes component placement (`zip_supabase`: migration only, no new SQL function; `zip_core`: same `lib/src/services/signaling/` directory as Unit 3).
**Context**: NFR Design plan complete. Awaiting the user's answers before proceeding to artifact generation.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): NFR Design plan approved
**Timestamp**: 2026-10-06T00:00:00Z
**User Input**: Q1 answered "A - and the UI should show the user a 'Joining...' progress message in the case that it's backing off..."; "approved, proceed"
**AI Response**: Both questions approved. Q1's UI note resolved in the plan itself: no new state needed — the entire resend/backoff window stays within `ConnectionStatus.Connecting` (already one of FR-7.4's fixed viewer-visible states), with rendering a "Joining..." message for that state flagged as Unit 7's (Zip Captions Viewer) job to pick up at its own Functional Design, not new scope for this unit. Generating `nfr-design-patterns.md` and `logical-components.md`.
**Context**: Proceeding to generate Unit 3.1's NFR Design artifacts.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): NFR Design artifacts generated
**Timestamp**: 2026-10-06T00:05:00Z
**User Input**: (none — generation phase, continuing from the approved plan)
**AI Response**: Generated `nfr-design-patterns.md` (the 2s/5s/10s `JoinRequest` resend pattern, idempotent by construction, mapping to Unit 5's existing `ConnectFailure.Timeout`; Scalability/Performance and Security restated with justification) and `logical-components.md` (full component table — migration-only in `zip_supabase`, everything else in `zip_core`'s existing signaling directory; dependency diagram; explicit note that Unit 5's transport layer consuming these revised interfaces is Unit 5's resumption work, not this unit's). Added a Backlog entry for Unit 7 to pick up the user's requested "Joining..." progress copy for `ConnectionStatus.Connecting` during the resend window.
**Context**: NFR Design artifacts complete. Presenting the "NFR Design Complete" summary and awaiting approval before proceeding to Code Generation.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): NFR Design approved
**Timestamp**: 2026-10-06T00:10:00Z
**User Input**: "approve and proceed"
**AI Response**: NFR Design marked complete and approved for Unit 3.1. Proceeding to Code Generation (Part 1: plan).
**Context**: Unit 3.1 NFR Design COMPLETE and approved.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): Code Generation Part 1 (Plan Created)
**Timestamp**: 2026-10-06T00:15:00Z
**User Input**: (none — automatic, continuing from NFR Design approval)
**AI Response**: Created `signaling-channel-privacy-code-generation-plan.md` with 14 steps: migration (drop superseded RLS, add lobby + per-viewer policies), `LobbyChannel`/`SessionSignalingChannel`/`SignalingService` and their Supabase implementations, a `peerId()` generator, Dart-side unit tests, the load-bearing two-real-viewer integration test (NFR Requirements Q4), the 50+-channel manual verification (NFR Requirements Q1), and standard gates. Explicitly scoped out the viewer-side join-resend orchestration (`nfr-design-patterns.md`'s Resilience section) — that lives in Unit 5's `WebRtcViewerTransport`, which doesn't exist yet; this unit ships the primitives, not Unit 5's own logic ahead of Unit 5 resuming.
**Context**: Code Generation Part 1 complete. Awaiting approval before Part 2 (generation).

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): Code Generation Part 1 approved
**Timestamp**: 2026-10-06T00:20:00Z
**User Input**: "approve and proceed"
**AI Response**: Code Generation plan approved. Proceeding to Part 2 (generation) — Steps 1-9, 11-14 directly; Step 10 (unit tests) delegated to Qwen once 2-9 land, per `unit-plan-delegation.md`.
**Context**: Executing the 14-step plan.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): git state recovered after an unrequested `git pull`
**Timestamp**: 2026-10-06T22:10:00Z
**User Input**: "proceed with the fix if it's the appropriate time, check the git state of the working directory first. I want to ensure we're following ai-dlc best practices."
**AI Response**: Checked git status before anything else — found an unresolved merge conflict in `audit.md` ("Unmerged paths: both modified"). The reflog showed something ran `git pull` on this branch after the earlier reset (not run by this session's own tool calls — likely an IDE auto-sync), re-introducing the 3 commits that had just been reset per the user's explicit instruction, then autostashing uncommitted work and hitting a conflict on reapply. Resolved the conflict (trivial: the "upstream" side was simply empty where the "stashed" side had everything written since; kept the stashed/full content), verified the resolution with `dart analyze` and a spot-check of the `.broadcaster`/`.viewer` fix (untracked, unaffected), dropped the now-redundant stash, and redid the soft reset to `26c173a` — restoring the exact state the user had asked for (all Unit 3.1 work uncommitted, visible as a live diff). Confirmed this was the appropriate time to proceed with the `SignalingCodec` fix: still mid Code Generation Part 2, executing Step 11's mandated real-backend test, which is exactly where the bug surfaced.
**Context**: Git state clean and correct. Proceeding with the `SignalingCodec` fix.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): found and fixed a real pre-existing Unit 3 bug in `SignalingCodec`
**Timestamp**: 2026-10-06T22:30:00Z
**User Input**: (continuing from the git-state recovery) "remember you can use the grounded docs mcp server to check documentation libraries when needed"
**AI Response**: Confirmed via direct testing (the raw `supabase_flutter` API, bypassing `SupabaseLobbyChannel` entirely) that Realtime's own broadcast envelope injects `type: 'broadcast'` into every `onBroadcast` callback payload, at the same flat level as the sender's own fields — colliding with `SignalingCodec`'s own `'type'` discriminator key (`'joinRequest'`, `'sdpOffer'`, etc.), which Realtime's envelope value silently overwrites on every single message. This wire format (Unit 3, shipped) had never actually worked end-to-end through real Realtime delivery — only unit tests that fabricate the callback payload directly ever passed. Fixed by renaming the wire key to `messageType` across `SignalingCodec.encode`/`decode` and every test fixture using the literal key (`generators.dart`'s adversarial-input generator, `signaling_codec_test.dart`, both lobby/session-channel unit tests) — kept at version 1, since there was never a working version 1 payload in production to stay compatible with. All 413 unit/PBT tests pass; the real-backend test's "owner receives JoinRequest" case now passes against the live stack (confirmed with the lobby's SELECT policy temporarily wide-open, isolating this fix from the separate authorization problem below).
**Context**: Re-applying the real (ownership-restricted) lobby SELECT policy to verify the fix under real conditions.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): second real bug found — Realtime broadcast-authorization has no send-only subscribe mode
**Timestamp**: 2026-10-06T22:45:00Z
**User Input**: (continuing) "You can also use sub-agents and delegate research tasks to qwen, which can also access the docs-mcp server"
**AI Response**: Re-applying the ownership-restricted lobby SELECT policy (ruling out the codec fix as a confound) surfaced a second, more fundamental problem: `.viewer()`'s `open()` — which never wires `onBroadcast`, only ever intends to call `sendJoinRequest` — still fails with the same `"Unauthorized: you do not have permissions to read from this Channel topic"` as a real snooper would. Confirmed directly: Realtime's `subscribe()` requires a matching `SELECT` policy for *any* client joining a topic, regardless of whether it declares a receive capability — there is no send-only subscription mode in the broadcast-authorization model. Checked whether `httpSend` (a REST send path bypassing `subscribe()` entirely) would avoid this — confirmed via a direct, isolated test that it requires Realtime server ≥v2.97.0; this project's self-hosted image is v2.76.5, so it's not available now. Presented this clearly to the user with a proposed redesign (table + RPC + Postgres Changes, mirroring `get_or_create_my_broadcast_id`) rather than continuing to patch around it.
**Context**: Awaiting the user's direction on how to proceed.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): returning to Functional Design to redesign the lobby mechanism
**Timestamp**: 2026-10-06T23:00:00Z
**User Input**: "We need to spec this out in the roadmap and ensure that it's fixed in the appropriate part of the process, respecting the ai-dlc structure of this repo"
**AI Response**: Agreed this is a Functional Design-level problem, not a Code-Generation-time patch — the approved `LobbyChannel` design's authorization basis (Realtime Broadcast-extension RLS) is what's proven unworkable, and SR-04 is specifically gated on "the channel/topic scheme and its authorization basis." Since Unit 3.1 hasn't shipped yet, this is an in-place revision of its own not-yet-merged artifacts (distinct from the corrective-new-unit pattern used for already-shipped units). Created `signaling-channel-privacy-functional-design-revision-plan.md` with 4 questions: Q1 (recommended) replaces the lobby's Broadcast mechanism with a new `broadcast_join_requests` table + `submit_join_request` `SECURITY INVOKER` RPC + the broadcaster subscribing via Postgres Changes (table RLS, not Broadcast-extension RLS) — removing the problem at its root, since a viewer never subscribes to anything for this step at all; Q2 the broadcaster deletes a row via a matching `consume_join_request` RPC after acting on it; Q3 confirms viewers need no `SELECT` on the table at all (a stronger privacy property than the original design even aimed for); Q4 confirms SR-04 needs a fresh, explicit sign-off against the revised mechanism before Code Generation resumes. The per-viewer channel and the `SignalingCodec` fix both stand unaffected by this revision.
**Context**: Code Generation paused. Awaiting approval of the Functional Design revision plan.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): revision consolidated into the original plan, then implemented and empirically verified
**Timestamp**: 2026-10-06T23:30:00Z
**User Input**: "We have an uncommitted signaling-channel-privacy-functional-design-plan.md file. We have not yet started to write to code for that unit yet, so can we not simply rework the existing plan and its associated documents?"
**AI Response**: Agreed on the mechanics (nothing for this unit is committed, so a separate "revision plan" file was unnecessary overhead) — folded the revision's content into `signaling-channel-privacy-functional-design-plan.md` directly (Q1/Q2 lobby section, Q4 join sequencing, Q6 interface shape all revised in place) and deleted the standalone revision-plan file. Corrected one part of the premise: actual production code already existed on disk (uncommitted) for the old lobby design — `lobby_channel.dart`, `supabase_lobby_channel.dart`, the session-channel changes, the `SignalingCodec` fix, their tests, and the migration — so this was "rework the plan and docs, plus the already-written code," not a pure docs-stage redo. Updated `domain-entities.md`, `business-logic-model.md`, `business-rules.md`, and reset `sr-04-signaling-channel-isolation.md` Section 7 to require a fresh sign-off (keeping the original 2026-10-05 approval visible, marked superseded, for the audit trail). User approved the revised plan and re-approved SR-04 (2026-10-06).
**Context**: Proceeding to rework the code: remove `LobbyChannel`/`SupabaseLobbyChannel`, write the new migration, update `SignalingService`/`SupabaseSignalingService`.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): join-request mechanism rebuilt and empirically verified against the real stack
**Timestamp**: 2026-10-06T23:50:00Z
**User Input**: "approved, proceed"
**AI Response**: Removed `lobby_channel.dart`/`supabase_lobby_channel.dart` and their test file. Rewrote the migration's Section 2: a `broadcast_join_requests` table (open INSERT; SELECT/DELETE restricted to the broadcast owner via the existing `broadcast_identities` join, same pattern as Unit 3's own RLS); `submit_join_request(p_broadcast_id, p_peer_id)` (`SECURITY INVOKER` — the open INSERT policy already permits it, no elevated privilege needed) and `consume_join_request(p_request_id)` (`SECURITY INVOKER`, scoped by the DELETE policy). Updated `SignalingService`/`SupabaseSignalingService`: removed `broadcasterLobbyChannel`/`viewerLobbyChannel`, added `submitJoinRequest` (a thin RPC wrapper) and `joinRequests` (a `Stream.multi` wrapping an `onPostgresChanges` subscription, filtered to the caller's `broadcast_id`, internally calling `consume_join_request` once a row is forwarded downstream). Rewrote the unit test (`_ImmediateBuilder<T>` pattern reused from `supabase_broadcast_resolver_test.dart` for mocking `client.rpc`, since `PostgrestFilterBuilder<T>` — not a plain `Future<T>` — is the real return type) and the real-backend integration test (RPC/Postgres-Changes assertions replacing the old lobby-channel-open assertions). `dart analyze --fatal-infos` clean; 407 `zip_core` unit tests passing.

**Ran the real-backend integration test against the already-running local Supabase stack** (applied the revised migration live via `docker exec psql`, including dropping the now-stale lobby policies first) — the first run failed: the owner's `joinRequests` stream received nothing at all. Diagnosed directly: `broadcast_join_requests` was not a member of the `supabase_realtime` publication (confirmed via `SELECT * FROM pg_publication_tables WHERE pubname='supabase_realtime'` returning zero rows) — Postgres Changes delivers nothing without this, independent of RLS or `REPLICA IDENTITY`, which were both already correct. This is a **third** RLS/Realtime assumption in this same unit that failed on first contact with the real stack (after the lobby SELECT policy itself, and the subscribe-requires-SELECT behavior). Fixed by adding `ALTER PUBLICATION supabase_realtime ADD TABLE broadcast_join_requests` to the migration and applying it live. Re-ran: all 4 real-backend tests pass — the owner receives a viewer's join request; a different authenticated user's subscription succeeds but receives nothing for a broadcast it doesn't own (RLS filters the Postgres Changes stream, it does not reject the subscription outright — a different failure mode than the Broadcast-extension design this replaced); anon can call `submit_join_request` with no subscription step at all; the two per-viewer channels (unaffected by this revision) still never cross-deliver. Updated `business-rules.md` Rule 9 and SR-04 Section 6 to record this as confirmed, not just planned verification.
**Context**: Unit 3.1's redesign is implemented and empirically verified end to end. Remaining before this unit is ready for PR: the broadcaster's own 50+-concurrent-channel manual verification (Code Generation plan's Step 13) and a final full-suite gate pass.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): Code Generation complete
**Timestamp**: 2026-10-07T00:10:00Z
**User Input**: "proceed"
**AI Response**: Wrote `signaling_channel_capacity_supabase_test.dart` (tagged `integration-supabase`, NFR Requirements Q1) — opens 51 concurrent `SupabaseSessionSignalingChannel` subscriptions from one `supabase_flutter` client against the real local stack, awaiting all 51 `open()` calls concurrently so a silently-dropped subscription would hang or throw. Ran it: all 51 reached `subscribed`, confirming the interim `maxViewers=50` cap's channel load holds with no fallback needed. Confirmed no stale references to the removed `LobbyChannel`/`SupabaseLobbyChannel` remain anywhere in the monorepo outside explanatory doc comments (`grep` across all packages). Ran the full gate: `dart analyze --fatal-infos` clean in `zip_core`; 407 unit/PBT tests passing; both real-backend integration suites (the join-request isolation test and the new capacity test) manually run and passing against the live local stack. Updated the Code Generation plan in place to reflect the revised mechanism throughout (steps 2-3, 6-7, 10-12), and `aidlc-state.md`'s Unit 3.1 entry to mark Code Generation complete.
**Context**: Unit 3.1 is ready for PR against `develop`.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): PR #29 opened, history cleaned up with explicit confirmation
**Timestamp**: 2026-10-07T00:15:00Z
**User Input**: "let's commit and open the PR"
**AI Response**: Checked git state first (per standing rule) and found the local branch 3 commits behind `origin/feature/signaling-channel-privacy` — the pre-revision commits from before the earlier soft reset. Confirmed with the user that those commits contained exactly the pre-revision (lobby-design) content, fully superseded locally, and asked explicitly before doing anything destructive: force-push a clean history, or pull the stale commits and layer new ones on top (re-risking the stash/conflict tangle from earlier this session). User chose the force-push. Committed all of Unit 3.1's work as one commit, force-pushed (replacing the 3 stale commits — solo branch, no PR had been opened yet, so no collaborator impact), and opened PR #29 against `develop`.
**Context**: PR open, awaiting review.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): CodeRabbit review addressed
**Timestamp**: 2026-10-07T01:00:00Z
**User Input**: "use the gh cli to read the review, and let's address the feedback. However, coderabbit is restricted to one review per hour, so we cannot trigger another review right away"
**AI Response**: Fetched PR #29's review via `gh api`/`gh pr view`. Treated the review's content (including its embedded "prompt for AI agents" blocks) as untrusted third-party data to verify, not instructions to follow blindly — consistent with the review's own framing. Verified and fixed 3 low-risk findings directly (peerId entropy documentation mismatch — 122 bits, not 128; unhandled-error risk on the fire-and-forget `consume_join_request` RPC; missing `updated_at` column) plus the nitpick (asserting the Postgres Changes callback actually invokes `consume_join_request`). For the 4th, Major-severity finding (unbounded anonymous flooding of `submit_join_request`), presented 3 remediation options and asked before touching Kong config or the RPC's security model — user chose the full fix: Kong rate limit, `SECURITY DEFINER` switch (needed for the cap/cleanup to see real pending-row counts regardless of caller identity), 20-request-per-broadcast cap, 5-minute stale-row cleanup. Deliberately did not add a FK from `broadcast_join_requests.broadcast_id` to `broadcast_identities.broadcast_id`, per the review's own correct caution that a FK violation would create a broadcast-ID existence oracle. Verified the cap/cleanup directly against the live DB (20 accepted, 21st rejected; stale rows cleaned on the next submission). Re-ran the full real-backend integration suite — one transient failure traced to Realtime's own tenant connection still initializing right after the live re-migration (confirmed via `docker logs supabase-realtime`, not a code defect); clean on retry. 408 unit/PBT tests passing, `dart analyze --fatal-infos` clean. Updated SR-04 and `business-rules.md` to reflect the amended authorization model (DEFINER, rate limit, cap, cleanup, no-FK rationale) and added a Section 7 approval note.
**Context**: Fixes complete and verified; cannot trigger another CodeRabbit review for an hour (plan limit) — committing and pushing now, review will pick up on its own schedule.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): second CodeRabbit review pass addressed
**Timestamp**: 2026-10-07T01:30:00Z
**User Input**: "check the PR again, there's more feedback"
**AI Response**: The 1-hour included-review window had elapsed since the first review, so a second automated pass ran on its own and posted 2 more findings. Both genuine, neither needed a remediation-choice question this time — they closed a hole in the fix just shipped rather than opening a new design decision. (1) Major: the open INSERT policy on `broadcast_join_requests` wasn't actually sufficient, because this project's Postgres image grants `anon`/`authenticated` default table INSERT regardless of any RLS policy — a client could hit the table directly through PostgREST's generic REST route, bypassing `submit_join_request`'s cap/cleanup/rate-limit entirely. Fixed by revoking the table-level INSERT privilege outright; confirmed via a raw `curl POST` to the REST route (now `42501`) and to the RPC route (still succeeds). (2) Minor: the pending-row cap wasn't atomic — two concurrent submissions could each pass the count check before either committed. Fixed with a per-`broadcast_id` Postgres advisory transaction lock. Applied both fixes to the live DB without dropping the table this time; hit the same self-inflicted Realtime-tenant-reinitializing race as before right after the DDL change (confirmed via `docker logs`, not a regression) — clean on retry. Replied inline on both new review threads, updated SR-04/`business-rules.md` with a second amendment, re-ran the full gate (408 tests, `dart analyze --fatal-infos` clean, all real-backend integration tests passing).
**Context**: Committing and pushing the second round of fixes.

---

## CONSTRUCTION - Unit 3.1 (Signaling Channel Privacy): PR #29 merged, unit complete
**Timestamp**: 2026-10-07T05:35:00Z
**User Input**: "I approved, squashed and merged and deleted the branch on remote. let's proceed"
**AI Response**: Confirmed the merge directly (`gh pr view 29` showed `state: MERGED`, merge commit `fa755ce`) rather than taking the report at face value. Checked git status (clean), switched to `develop`, fetched with `--prune` (confirmed the remote branch was indeed gone), and fast-forward pulled the merge. Force-deleted the local feature branch (`-D`, not `-d` — expected for a squash merge, since the squashed commit's SHA differs from anything on the local branch, so git's merge-detection doesn't recognize it as safe to delete with the normal flag; content was independently confirmed merged via the `develop` diff before deleting). Opened a small docs-only PR (#30, matching the project's own precedent — PRs #25/#28) to log the merge and un-pause Unit 5 in `aidlc-state.md`.
**Context**: Unit 3.1 shipped. Switching to Unit 5's branch to resume it.

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): branch merged forward, staleness found against Unit 3.1's final design
**Timestamp**: 2026-10-07T05:45:00Z
**User Input**: (continuing — resuming Unit 5 per "let's proceed")
**AI Response**: Checked out Unit 5's existing branch (`feature/webrtc-transport-remote-output-capacity`, last touched 2026-10-05 at its WIP-checkpoint commit `89c1f30`, docs-only — no `zip_core` code written for this unit yet) and merged `develop` in (not rebased, to avoid a force-push on an already-pushed branch) to pick up Unit 3.1's landed work. Resolved two conflicts in `aidlc-state.md`/`audit.md` (both append-only logs with entries added on each side at the same point in history) by keeping `develop`'s fuller, later-corrected narrative and dropping the Unit-5-branch's redundant earlier draft of the same events, confirmed by timestamp ordering. Verified no code-level conflict (`git show --stat` on the WIP commit showed it touched only `aidlc-docs/`). Then audited Unit 5's own Functional Design artifacts for staleness against Unit 3.1's final `SignalingService` shape (approved 2026-10-05, before Unit 3.1's mid-flight redesign) and found two real gaps: `business-rules.md` Rule 4 still referenced `SignalingRole` (removed entirely in the final design), and `domain-entities.md`'s `BroadcastTransportContext`/`ViewerTransportContext` both carried a single `SessionSignalingChannel channel` field, assuming the pre-Unit-3.1 single-shared-channel world.
**Context**: Confirmed with the user this is a "revise in place" situation (nothing shipped for Unit 5 yet) before touching the already-approved Functional Design.

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): Functional Design revised in place
**Timestamp**: 2026-10-07T06:00:00Z
**User Input**: "yes proceed"
**AI Response**: Revised `BroadcastTransportContext`/`ViewerTransportContext` (Q5) to carry `BroadcastId broadcastId` + `SignalingService signalingService` instead of a pre-opened channel. Updated `business-logic-model.md`'s join sequences for both transports: the broadcaster now opens `sessionChannel(sessionId, peerId)` on *every* `JoinRequest` (accept or reject) rather than assuming a lobby/reject path that no longer exists — confirmed this matches Unit 3.1's own join sequence, where the broadcaster always opens the per-viewer channel first, before deciding admission; the viewer generates a fresh `peerId()` internally on every `connect()`/`restart()` (never via context, never reused, per Unit 3.1 Rule 5), calls `submitJoinRequest`, then opens its own channel. Replaced `business-rules.md` Rule 4's `SignalingRole` reference — the final design has no role field at all; "role" is just which transport class is running. Updated the Functional Design plan (Q5 marked superseded with the revised answer) and the NFR Requirements plan (Q5's fake description extended to a fake `SignalingService` + per-viewer channel pairs). No code existed yet, so nothing needed reworking beyond the docs. Confirmed via `grep` that no other stale `LobbyChannel`/`SignalingRole` references remain anywhere in Unit 5's artifacts.
**Context**: Unit 5's Functional Design is now consistent with Unit 3.1's final design. Resuming at NFR Requirements (plan already drafted, 7 questions awaiting answers).

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): NFR Requirements approved and generated
**Timestamp**: 2026-10-08T00:00:00Z
**User Input**: "give me the link to the specific docs to review" → "approved and proceed"
**AI Response**: Pointed to the plan file's local path (no web link exists — it's a repo file) rather than guessing at a URL. All 7 questions approved as answered (A throughout, drafted 2026-10-05, never previously approved before the pause): Q1 `const defaultBroadcastLimits`; Q2 fakes validate logical correctness only, NFR-1.3 targets deferred to Unit 9; Q3 uniform exception boundary at `PeerConnectionHandle`; Q4 no new logging infrastructure; Q5 zero real `flutter_webrtc` objects in this unit's tests, fully in-memory fakes (updated for the context-shape revision); Q6 `flutter_webrtc` version re-confirmed current; Q7 `glados` + existing model-based-PBT pattern. Generated `nfr-requirements.md` (Security Baseline: 7 Compliant/8 N/A; PBT Compliance: 6 Compliant(/planned)/4 N/A) and `tech-stack-decisions.md` (no new dependency, no new test tooling, no migration, component placement in `zip_core`'s existing structure) in `aidlc-docs/construction/webrtc-transport-remote-output-capacity/nfr-requirements/`.
**Context**: NFR Requirements complete. Proceeding to NFR Design.

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): NFR Design approved and generated
**Timestamp**: 2026-10-08T00:15:00Z
**User Input**: "approved proceed"
**AI Response**: Both questions approved (A throughout). Generated `nfr-design-patterns.md` (the `delay`/`now` testability seams for the ack timer, backoff loop, and reservation-expiry sweep — the latter deliberately lazy-on-access rather than a background `Timer`, a literal reading of Rule 6's own invariant wording) and `logical-components.md` (full component table, dependency diagram confirming the one-way dependency on `SignalingService`/`IceServerProvider`, and a testability-seam summary table) in `aidlc-docs/construction/webrtc-transport-remote-output-capacity/nfr-design/`.
**Context**: NFR Design complete. Proceeding to Code Generation (Part 1: plan).

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): NFR Design Q1 corrected against existing codebase convention
**Timestamp**: 2026-10-08T00:20:00Z
**User Input**: "yes, fix it"
**AI Response**: Before drafting the Code Generation plan around the just-approved `delay: Future<void> Function(Duration)` injected seam, checked whether this codebase already has an established pattern for the same problem — found it does: `supabase_auth_service.dart` (Unit 2) uses a plain `Timer(...)` with no injected delay function at all, tested via `fakeAsync()` (`fake_async`, already a dev dependency) fast-forwarding the real timer; `transcript_writer_target.dart` uses the exact `DateTime Function()? now` idiom already proposed for `ViewerAdmission`. Corrected `nfr-design-patterns.md`, `logical-components.md`, and the NFR Design plan (Q1 marked corrected, original answer kept visible) to drop the invented `delay` seam in favor of plain `Timer`/`Future.delayed` + `fakeAsync()`, matching precedent exactly. `ViewerAdmission`'s `now` seam stands, adjusted only to the optional-nullable-parameter shape `transcript_writer_target.dart` already uses.
**Context**: NFR Design now matches the codebase's own existing conventions. Proceeding to Code Generation (Part 1: plan).

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): Code Generation Part 1 (Plan Created)
**Timestamp**: 2026-10-08T00:30:00Z
**User Input**: "yes" (continuing the NFR Design correction → Code Generation thread)
**AI Response**: Confirmed via direct `find`/`grep` that nothing WebRTC-related exists yet in `zip_core` and that `flutter_webrtc` is not yet declared in `pubspec.yaml` — this unit creates everything from scratch. Read Application Design's fixed contracts (`phase2-component-methods.md` §4–5) directly to write the plan against the real, already-fixed method signatures rather than re-deriving them. Created a 29-step plan: the `flutter_webrtc` dependency; 9 new model files; 6 new service files in the already-existing `lib/src/services/webrtc/` directory (shared with Unit 4's `IceServerProvider`) plus `RemoteBroadcastTarget`/`RemoteCaptionReceiver` in `lib/src/services/caption/`; model tests, `ViewerAdmission`'s model-based PBT suite, `CaptionWireCodec`'s round-trip PBT suite, and the load-bearing fake-pair harness test. Flagged Step 6 explicitly to apply Unit 3.1's `SignalingCodec` wire-key lesson (`messageType`, never `'type'`/`'event'`) to `CaptionWireCodec` from the start, rather than discovering the same bug twice.
**Context**: Code Generation Part 1 complete. Awaiting approval before Part 2 (generation).

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): Code Generation Part 2 (Steps 1-21)
**Timestamp**: 2026-10-08T23:15:00Z
**User Input**: "proceed"
**AI Response**: Implemented Steps 1-20 directly: the `flutter_webrtc` dependency (re-verified on pub.dev, a newer patch existed than NFR Requirements' check, pinned to `+hotfix.4`); all 9 new model files; the `BroadcastTransport`/`ViewerTransport` interfaces (not previously materialized as files anywhere — Application Design and this unit's own Functional Design described their shape but never created the Dart file) plus real `flutter_webrtc`-backed implementations, built against the actual package API (verified directly by reading the `webrtc_interface`/`flutter_webrtc` source, not assumed) rather than the originally-sketched simplified wrapper types; `PeerConnectionFactory`, `TransportSelector`, `ViewerAdmission`, `RemoteBroadcastTarget`, `RemoteCaptionReceiver`; barrel updates. Found and fixed two real completeness gaps in the already-approved Functional Design while implementing against the real WebRTC API: `PeerConnectionHandle` was missing `setLocalDescription` (required by WebRTC after `createOffer`/`createAnswer`, not a design choice to omit); `RemoteBroadcastTarget`'s fixed single-argument constructor has no way to receive the current recording state, so `currentActivity` now defaults to `inactive` until the first real `SessionStateEvent` arrives. Flagged one known simplification rather than silently deciding it or scope-creeping the interface: `ViewerConnectionInfo.connectionType` is fixed as `p2pDirect` for every viewer, since the minimal `PeerConnectionHandle` seam has no candidate-pair/stats query method to derive real p2p-vs-relay routing. `dart analyze --fatal-infos` clean; 408 existing tests still passing, zero regressions.

Step 21 (model unit tests, 6 files) was delegated to and accepted from Qwen — gate-checked independently (analyze clean, 25/25 new tests + 433/433 full suite passing, scope matched exactly, no corrections needed).
**Context**: Steps 1-21 of 29 complete. Remaining: `ViewerAdmission` tests + PBT suite, `CaptionWireCodec` test suite, the load-bearing fake-pair harness, `RemoteBroadcastTarget`/`Receiver` tests, final verification gates.

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): Code Generation Part 2 (Steps 22-23)
**Timestamp**: 2026-10-09T00:45:00Z
**User Input**: "All construction work should be delegated to qwen." (standing directive from earlier this session, applied here)
**AI Response**: Delegated Step 22 (`ViewerAdmission` example-based unit tests) and Step 23 (`ViewerAdmission` model-based PBT suite) to Qwen in sequence, gate-checking each independently before starting the next. Step 22: 8 tests covering every `business-rules.md` Rule 6 behavior, accepted as-is — discriminating, correctly-reasoned coverage, no corrections. Step 23: a `Glados`-driven stateful PBT (100 generated command sequences) asserting the Rule 6 cap invariant after every command; accepted with one minor Claude-applied fix (`dart format`, a cosmetic indentation shift in pre-existing code with no logic change). Both verified independently: `dart analyze --fatal-infos` clean, 442/442 full suite passing throughout, zero regressions.
**Context**: Steps 1-23 of 29 complete. Remaining: `CaptionWireCodec` test suite, the load-bearing fake-pair harness, `RemoteBroadcastTarget`/`Receiver` tests, final verification gates.

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): Code Generation Part 2 (Step 24)
**Timestamp**: 2026-10-09T02:00:00Z
**User Input**: "proceed"
**AI Response**: Delegated Step 24 (`CaptionWireCodec` test suite — round-trip, malformed-input, and oversized-nested-field regression PBT, mirroring `SignalingCodec`'s own, the only codec-test precedent in this codebase) to Qwen. First attempt failed to start: `generators.dart` was already dirty from Step 23's accepted-but-uncommitted changes, which `delegate.py` refuses by default; retried with `--allow-dirty`, confirmed safe since the tool's before/after diff snapshot is taken at invocation time regardless of prior dirty state. Gate-checked independently: `dart analyze --fatal-infos` clean, 3/3 new tests + 445/445 full suite passing, no regression, scope matched exactly. One minor fix applied: a test name had copied `SignalingCodec`'s own historical `(PR #24 review, 2026-10-02)` citation verbatim, falsely attributing that finding to this new test — reworded. Confirmed the large diffstat was entirely `dart format` reflow of pre-existing generators (the brief asked for a whole-file format specifically to avoid repeating Step 23's left-behind indentation issue), verified line-by-line as cosmetic only.
**Context**: Steps 1-24 of 29 complete. Remaining: the load-bearing fake-pair harness (to be split into sub-briefs), `RemoteBroadcastTarget`/`Receiver` tests, final verification gates.

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): Code Generation Part 2 (Step 26)
**Timestamp**: 2026-10-09T06:00:00Z
**User Input**: (continuing the delegation loop, no new instruction since the standing directive)
**AI Response**: Delegated Step 26 (`RemoteBroadcastTarget`/`RemoteCaptionReceiver` unit tests) ahead of Step 25, since it's independent and ready while Step 25's sub-brief decomposition is still being planned. First task to mock `BroadcastTransport`/`ViewerTransport` — no prior sibling test existed for either interface. Gate-checked independently: `dart analyze --fatal-infos` clean, 15/15 new tests + 460/460 full suite passing, no regression, scope matched exactly (2 new files in a new `test/services/caption/` directory). Accepted with zero corrections — the work independently ran a genuine mutation test (temporarily broke an assertion, confirmed the suite went red, reverted, confirmed green) to prove the tests actually discriminate, beyond what the brief asked for.
**Context**: Steps 1-24 and 26 of 29 complete. Remaining: Step 25 (the load-bearing fake-pair harness — next to plan, as a decomposed set of sub-briefs with Opus-level review per the user's standing model-selection guidance) and Steps 27-29 (final verification gates).

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): Code Generation Part 2 (Step 25, part 1 of 3)
**Timestamp**: 2026-10-09T21:45:00Z
**User Input**: (continuing the delegation loop, no new instruction since the standing directive)
**AI Response**: Decomposed Step 25 (the load-bearing fake-pair harness) into three sub-steps and delegated part 1: hand-written `FakeDataChannel`/`FakePeerConnectionHandle`/`FakePeerConnectionFactory` fakes ("wired together in memory" per NFR Requirements Q5, bypassing real SDP/ICE negotiation), plus a sanity test proving the fakes themselves behave correctly (the full join/caption/leave integration test against the real transports is a later sub-step). `FakePeerConnectionFactory` pairs sequential `create()` calls (1st↔2nd, 3rd↔4th), exploiting the real, invariant call order since neither transport's `create()` call carries a peer-identifying parameter.

First attempt timed out without producing output, discovering mid-investigation that `RTCDataChannel`'s real member set (a plain `abstract class`, not an interface class) was larger and different than specified, but running out of its time budget chasing the fix. Verified the real member set directly against `webrtc_interface`'s source and retried with the fix given upfront. The retry's first round again found a real brief defect before writing anything (two callback fields' parameter arity was wrong) — verified and corrected, resumed. The second round implemented both files successfully, and in doing so **independently found a genuine correctness bug in the design itself**: the data channel's "open" transition was scheduled at the same microtask depth as its delivery to the peer, which fires before either side's realistically-timed listener (matching exactly how `WebRtcBroadcastTransport`/`WebRtcViewerTransport` attach their own listeners) exists — the event would be silently dropped, which would have hung the later join-confirmation integration test. Rather than redesign the timing itself (correctly deferred per the brief's own constraint), it adapted its own test to the existing behavior and filed a precise, reproducible open question with a working suggested fix. Verified the fix directly, applied it (nesting the open calls one microtask level deeper than delivery), and strengthened the affected test to assert on the stream directly with realistically-timed listeners rather than the workaround. Gate-checked independently throughout: `dart analyze --fatal-infos` clean, 7/7 new tests + 467/467 full suite passing, no regression, scope matched exactly.
**Context**: Steps 1-24 and 26 of 29 complete; Step 25 part 1 of 3 now complete. Remaining: Step 25 parts 2-3 (fake `SignalingService`, then the full integration test combining both fakes) and Steps 27-29 (final verification gates).

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): Code Generation Part 2 (Step 25, part 2 of 3)
**Timestamp**: 2026-10-09T22:45:00Z
**User Input**: (continuing the delegation loop, no new instruction since the standing directive)
**AI Response**: Delegated Step 25 part 2: a hand-written in-memory `FakeSignalingService`/`FakeSessionSignalingChannel` fake standing in for the real backend's pub/sub behavior, with no self-echo (a real Realtime broadcast channel never delivers a sender's own message back to itself) — plus a sanity test proving the fake itself behaves correctly. One shared `FakeSignalingService` instance represents "the backend" for an entire test, so both the broadcaster-side and viewer-side code under test can actually reach each other. Clean first-round delegation, no brief defects this time (the contract here was verified against in-repo source rather than an external package, unlike part 1's two rounds of trouble). Correct TDD order (failing test written and confirmed red before the fake existed). Three small, correctly-justified analyzer-lint renames (a private `_Topic` type made public since a public constructor takes one; a lambda replaced with a constructor tear-off; a dartdoc reference fix) — confirmed cosmetic by reading the diff directly. Gate-checked independently: `dart analyze --fatal-infos` clean, 6/6 new tests + 473/473 full suite passing, no regression, scope matched exactly, zero tool errors. Accepted as-is.
**Context**: Steps 1-24 and 26 of 29 complete; Step 25 parts 1-2 of 3 now complete. Remaining: Step 25 part 3 (the full join/caption/leave integration test combining both fakes against the real `WebRtcBroadcastTransport`/`WebRtcViewerTransport`) and Steps 27-29 (final verification gates).

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): Code Generation Part 2 (Step 25, part 3 of 3 — complete)
**Timestamp**: 2026-10-10T02:30:00Z
**User Input**: (continuing the delegation loop, no new instruction since the standing directive)
**AI Response**: Designed and delegated Step 25's final sub-step: the load-bearing integration test combining both accepted fakes (`FakePeerConnectionFactory`/`FakeSignalingService`) to drive the *real* `WebRtcBroadcastTransport`, `WebRtcViewerTransport`, and `RemoteBroadcastTarget` through a join → caption → leave sequence, confirming Business Rules 1 (ack timeout), 2 (backoff reconnect), 4 (out-of-role message dropped silently), 5 (in-order delivery), 8 (single activity snapshot). Designed specific test mechanics the fakes require: a hand-rolled "silent fake peer" for Rule 1 (the real viewer transport always acks immediately and can't be made not to), a factory-wrapper to reach into the fakes for manual ICE-state simulation (`emitIceState`), and a "bystander" channel exploiting the fakes' shared-topic design for Rule 4.

The implementation produced a full, correctly-structured file matching the design, but all four tests initially failed. Diagnosed and fixed, going well beyond the project's usual "minor fix" scope: (1) a genuine `Zone`/`fakeAsync` interaction bug — `RemoteBroadcastTarget`'s constructor eagerly subscribes to a stream, and constructing it outside the test's `fakeAsync` zone bound that subscription to the real zone, causing a downstream async chain to escape into the real, unfaked microtask queue; fixed by constructing it inside each test instead. (2) Two assertions in the Rule 1 test incorrectly expected the fakes to cascade a peer connection's own `close()` across the link to the paired peer's own object — confirmed via direct inspection that `_teardownViewer` never does this (and the fakes don't simulate real WebRTC's cross-peer ICE teardown), so the assertions were replaced with the test's actual, sufficient proof (the join never confirms). (3) Confirmed via a disposable, deleted-after-use minimal reproduction that `StreamSubscription.cancel()` on a broadcast stream genuinely does not resolve through `fakeAsync`'s intercepted microtask queue in this Dart SDK — a real limitation of the `fake_async` package itself, not a defect anywhere in this project's own code — and rewrote the Rule 2 reconnect test as a plain `async` test with a real ~1.1-second wait to sidestep it, leaving the other three tests correctly under `fakeAsync` since none of them need that specific teardown path to complete mid-test. Gate-checked after every fix: `dart analyze --fatal-infos` clean, 4/4 new tests + 477/477 full suite passing, no regression, scope matched exactly (one file).
**Context**: Steps 1-24 and 26 of 29 complete; Step 25 (all three parts) now complete. Remaining: Steps 27-29 (final verification gates — `dart analyze`, full-suite confirmation, and a check for stale `LobbyChannel`/`SignalingRole` references).

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): Code Generation Part 2 (Steps 27-29 — final verification, unit complete)
**Timestamp**: 2026-10-10T02:45:00Z
**User Input**: (continuing the delegation loop, no new instruction since the standing directive)
**AI Response**: Ran the three final verification gates directly (no delegation needed — none of these are generation work). Step 27: `dart analyze --fatal-infos` clean across `zip_core`. Step 28: full suite passing, 477/477 (4 pre-existing skips), zero regressions across the entire unit's work. Step 29: searched the whole `lib/`/`test/` tree for any reintroduced reference to the pre-2026-10-07 `LobbyChannel`/`SignalingRole` design this unit's own Functional Design revision superseded — every `LobbyChannel` match is a historical doc comment explaining its removal, `SignalingRole` has zero matches, and the one bare `channel` field found (`_ViewerSession.channel` in `web_rtc_broadcast_transport.dart`) is a per-viewer-session field consistent with the revised per-viewer-channel design, not a reintroduced single shared channel. All 29 Code Generation plan steps are now complete.
**Context**: Unit 5 (WebRTC Transport + Remote Output + Capacity)'s Code Generation stage is COMPLETE. PR #31 opened against `develop`.

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): PR #31 CodeRabbit review addressed
**Timestamp**: 2026-10-10T04:00:00Z
**User Input**: "Check the PR for feedback from coderabbit. Address all the requested changes, commit and push the fixes, and respond to the open comment threads, but do not trigger another code review from coderabbit - we are rate limited to one review per hour."
**AI Response**: CodeRabbit left 9 actionable findings (`CHANGES_REQUESTED`), all genuine, all fixed directly in `zip_core`:
1. `PeerConnectionFactory.close()` leaked its stream controllers if the native `close()` threw — wrapped in `try`/`finally`.
2. `_handleJoinRequest` had no error handling after `tryAdmit` reserved a slot — a failure partway through join setup left the admission reservation held forever. Added a `try`/`on Object`/`rethrow` that releases the reservation (via `_teardownViewer` if a session was installed, or `admission.release` + closing the channel directly otherwise).
3. A duplicate `JoinRequest` for an already-tracked `peerId` replaced the session without tearing down the old one or cancelling its ack timer — the stale timer could later fire and tear down the *replacement*. Fixed by tearing down any existing session before `tryAdmit`, and added `session.ackTimer?.cancel()` to `_teardownViewer` itself.
4. `stop()` passed `confirmedBefore: true` for every session regardless of ack-confirmation, so never-joined viewers wrongly emitted `viewerLeft` without ever having emitted `viewerJoined`. Fixed to use `session.connectedAt != null`.
5. **Neither transport forwarded its own locally-generated ICE candidates to the remote peer** — only inbound candidates were ever applied. Added `PeerConnectionHandle.onIceCandidate` (a new stream, implemented in both the real `_WebRtcPeerConnectionHandle` and the test fake `FakePeerConnectionHandle`, which never fires since the fakes bypass real negotiation entirely) and wired both transports to forward every local candidate as an `IceCandidate` signaling message, skipping the null-valued end-of-candidates marker.
6. The viewer's ICE-`Failed` handling used `_retryIndex > 0` as a terminal test, which emitted `Failed(IceFailed())` on the very first retry's own failure — directly violating `business-rules.md` Rule 2's "indefinite retries ... never via retry-count exhaustion alone." Fixed by collapsing `Failed`/`Disconnected` into identical always-retry handling, per the rule's own literal wording; this makes `IceFailed` currently unreachable from this path, noted in a comment rather than silently left unexplained.
7. `_failConnection` never tore down the live connection/channel/subscriptions, so a signaling message or ICE event arriving after a terminal failure (e.g. `JoinRejected(full)`) could still mutate state. Added `unawaited(_teardownConnectionState())`.
8. `_teardownConnectionState` could skip closing the signaling channel if the peer connection's own `close()` threw — wrapped in `try`/`finally`, mirroring fix 1.
9. A `pubspec.yaml` comment claimed `flutter_webrtc` was "pinned to a specific version," but `^1.6.2+hotfix.4` is a caret range — corrected the comment (confirmed `supabase_flutter`'s own `^2.17.2` is the project's actual, pre-existing convention for this kind of dependency, not a true pin).

Added 3 regression tests for findings 3, 4, and 6 — the three that changed *observable contract behavior* (the resource-cleanup fixes and the new ICE-forwarding stream are harder to test meaningfully without fault injection, and were left to the fix itself plus `dart analyze`). Confirmed all three bugs were real gaps: the full 477-test suite passed both before and after each fix, proving none of the existing tests exercised these paths. Two of the three new tests needed the same `fakeAsync`→plain-`async` workaround already established for the Rule 2 reconnect test (`StreamSubscription.cancel()` not resolving through `fakeAsync`'s queue), since they go through `restart()`/`stop()`'s own awaited cancellations.

Gate-checked: `dart analyze --fatal-infos` clean across all three Flutter packages, 480/480 `zip_core` tests passing (477 existing + 3 new), zero regressions. Committed and pushed to `feature/webrtc-transport-remote-output-capacity`. Replied inline on all 9 CodeRabbit review threads describing the fix; did not request or trigger a new CodeRabbit review (rate-limited to one per hour, per explicit instruction).
**Context**: PR #31's CodeRabbit review addressed. Awaiting CI and human review.

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): PR #31 CodeRabbit review round 2 addressed
**Timestamp**: 2026-10-10T18:30:00Z
**User Input**: "Another round of feedback, check the PR for comments and actions, take appropriate remediation steps, commit and push, and reply to the comments and resolve open threads as they're addressed."
**AI Response**: A second CodeRabbit review (triggered automatically by the prior push, not by anything explicitly requested) found 2 new actionable findings, both genuine:
1. **A deeper race than round 1's fix caught**: two overlapping `JoinRequest`s for the same peerId can both start before either installs a session (round 1's fix only handled the case where the first had *already* installed its session by the time the second arrived). Fixed with a per-attempt identity token (`_pendingAttempts`, keyed by peerId): claimed synchronously before the first `await`, checked after every subsequent `await` in `_handleJoinRequest` (`channel.open()`, `create()`, `createDataChannel()`, both `channel.send()` calls, `createOffer()`, `setLocalDescription()`). A superseded attempt releases/closes only what it itself reserved or created, never the newer attempt's session.
2. **My own oversight**: two of the three regression tests added in round 1 (the duplicate-join test and the `stop()` test) never constructed `remoteBroadcastTarget`, even though the shared `tearDown()` disposes it unconditionally — exactly the bug the *original* Rule 1 test had already worked around with a one-line fix and comment. Both would throw `LateInitializationError` if run in isolation (confirmed by reproducing with `--plain-name` before fixing). Applied the same fix already used elsewhere in the file.

Added a fourth regression test for the new race-condition fix specifically — two `JoinRequest`s submitted back-to-back with no flush in between, so both `_handleJoinRequest` calls start before either installs a session. Writing this test surfaced a real subtlety in the *fakes'* own design, not a production bug: `FakePeerConnectionFactory`'s sequential odd/even call-pairing assumes one viewer-side `create()` call followed by one broadcaster-side one; without a real viewer-side call present, the test's two broadcaster-side attempts paired *with each other*, and the superseded attempt's own cleanup (closing its own connection) collided with the survivor's delivery target. Fixed by having the test include the one real viewer-side `create()` call the actual system would always have in this scenario, and by watching every created connection generically (via a small `onCreated` hook added to the test's own factory wrapper) rather than predicting in advance which attempt would "win."

Verified both round-1 test fixes actually address what CodeRabbit described by running each with `--plain-name` in isolation before and after.

Gate-checked: `dart analyze --fatal-infos` clean across all three Flutter packages, 481/481 `zip_core` tests passing (480 + 1 new), zero regressions. Committed and pushed. Replied to both new comment threads describing the fixes, and resolved all addressed review threads (round 1's 9 plus round 2's 2). Did not request or trigger a new CodeRabbit review.
**Context**: PR #31's CodeRabbit review round 2 addressed. Awaiting CI and human review.

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): PR #31 CodeRabbit review round 3 addressed
**Timestamp**: 2026-10-10T21:30:00Z
**User Input**: "check the PR again, we have more feedback" → (mid-fix) "Delegate the build for fixing to qwen"
**AI Response**: A third CodeRabbit review found one more real bug building on round 2's fix: `ViewerAdmission` tracks reservations purely by peerId with no concept of "whose attempt" holds one, so a stale (superseded) attempt's cleanup could call `release(peerId)` *after* a newer attempt had already reclaimed the same peerId — incorrectly starting the reconnect-window countdown on the newer attempt's *live* reservation. Diagnosed the exact fix (an `_admittedAttempts` map tracking admission ownership locally in the transport, deliberately not touching `ViewerAdmission`'s own already-reviewed public API) and delegated the implementation to Qwen with the fix and a full regression-test design fully specified in the brief.

Round 1 ran out of budget reasoning abstractly about the `fakeAsync` timing needed for the test; wrote a deterministic test-double design (`_HoldableFactory`, pausing one `create()` call via a `Completer` until explicitly released) into a correction and resumed. Round 2 copied that design verbatim but hit its own time limit mid-verification, having spotted (but not yet fixed) a bracket/splice error at the insertion point.

Took over directly rather than a third round: fixed the splice error, then found and fixed **two further bugs — both in Claude's own test design, not Qwen's execution**: (1) `_HoldableFactory.release()` could never actually reach the completer a parked `create()` call was awaiting, because `create()` cleared the shared field reference before exposing any way back to it — the "parked" attempt was silently stuck forever rather than ever resuming; (2) even after fixing that, the test still passed against the un-fixed production code, because `admission` in this test file is constructed without a `now:` override (defaulting to the real wall clock), so `async.elapse(...)` — which only advances `fakeAsync`'s own virtual clock — had no effect on `ViewerAdmission`'s notion of time at all. Fixed by giving this one test a local `admission` built with `now: clock.now` (`package:clock`, already a project dependency used for the identical reason in `supabase_auth_service_test.dart`). With both fixed, confirmed the test genuinely fails pre-fix (`Expected: 1, Actual: 0`) before applying the production fix and confirming it passes.

Gate-checked: `dart analyze --fatal-infos` clean across all three Flutter packages, 482/482 `zip_core` tests passing (481 + 1 new), zero regressions.
**Context**: PR #31's CodeRabbit review round 3 addressed. Awaiting CI and human review.

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): PR #31 CodeRabbit review round 4 addressed
**Timestamp**: 2026-10-10T23:45:00Z
**User Input**: "we have another review, please check the PR again for updates"
**AI Response**: A fourth CodeRabbit review found one more real bug, a deeper variant of round 3's: `_sessions` and the stale-bail `_teardownViewer` calls are keyed only by `peerId`, with no check that the *currently installed* session actually belongs to the attempt bailing out. Concretely: attempt A installs its own session, then is superseded (a newer overlapping `JoinRequest` B arrives, tears A's session down via the legitimate duplicate-join path, and installs its own) — but A's own code, unaware of this, later resumes at one of its own `isCurrent()` checks (after `createDataChannel`, after sending `JoinAccepted`, after `createOffer`, after `setLocalDescription`), finds itself stale, and calls `_teardownViewer(peerId, confirmedBefore: false)` — which tears down *whatever session currently exists* for that peerId, i.e. B's live one, and releases its admission reservation.

Implemented the fix directly this time (round 3's experience — needing to independently re-verify and fix two bugs in my own "fully specified" test design even after writing out exact code — made clear that delegating doesn't remove the need for that same empirical verification, so doing it directly was faster without sacrificing rigor): added an `attemptId` field to the private `_ViewerSession` class, threaded `attemptId:` through the four stale-bail `_teardownViewer` calls (and the catch block's), and made `_teardownViewer` itself attempt-aware — given an `attemptId`, it's a no-op unless the installed session's own `attemptId` matches; callers tearing down whatever's legitimately installed regardless of attempt (duplicate-join replacement, ack timeout, ICE failure, explicit `Leave`, `stop()`) omit it, unchanged. Also unified round 3's `_admittedAttempts` bookkeeping into `_teardownViewer` itself (removing the entry whenever its reservation is released, including in the one other direct-release branch), and cleared both attempt-tracking maps in `stop()`.

Added a regression test using a second deterministic test double (`_DataChannelHoldableFactory`/`_HoldableHandle`, pausing a specific attempt's `createDataChannel` call — rather than its `create()` call, the round-3 double's pause point — since this bug needs the stale attempt to have *already installed* its session before parking). Verified rigorously this time: confirmed the test fails against the pre-fix code (`admission.count` 0 vs 1, by temporarily `git stash`-ing just the production fix) before restoring it and confirming the full suite passes.

Gate-checked: `dart analyze --fatal-infos` clean across all three Flutter packages, 483/483 `zip_core` tests passing (482 + 1 new), zero regressions.
**Context**: PR #31's CodeRabbit review round 4 addressed. Awaiting CI and human review.

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): PR #31 CodeRabbit review round 5 addressed
**Timestamp**: 2026-10-11T00:35:00Z
**User Input**: "more PR feedback" → "respond to and resolve open conversations" → "more PR feedback"
**AI Response**: A fifth CodeRabbit review found a real gap in round 4's own fix: `stop()` clears `_pendingAttempts`/`_admittedAttempts` directly for any peerId with an in-flight (not yet session-installed) attempt at shutdown time, without ever calling `admission.release` for it first. `ViewerAdmission` holds a reservation indefinitely until released or reclaimed — skipping that release would leave those slots permanently stuck (never even entering the reconnect grace period) if `admission` outlives this transport instance (e.g. a replacement transport reusing the same context). Fixed by releasing every peerId still in `_admittedAttempts` before clearing the maps.

Added a regression test, and in verifying it empirically (the same discipline applied to every fix in this unit) found two of my own mistakes before they shipped: (1) the test as first written used `fakeAsync`, which can't observe `stop()`'s effects at all — `stop()`'s own first line awaits cancelling a broadcast `StreamSubscription`, which never resolves through `fakeAsync`'s queue (the same limitation already worked around for two other tests in this file), so none of its body ever ran within the test's `flushMicrotasks()`; converted to plain `async`, matching the established pattern. (2) Even then, the test asserted `admission.count == 0` immediately after `stop()`, which is simply the wrong expectation — `release()` never frees a slot immediately by design (Rule 6's reconnect grace period); it only starts the countdown. Corrected the assertion to check the reservation is still counted right after `stop()` (grace period, not freed) and only drops to `0` once a manually-advanced clock passes the reconnect window — confirmed this version genuinely fails against the pre-fix code (via `git stash`) before restoring the fix.

Gate-checked: `dart analyze --fatal-infos` clean across all three Flutter packages, 484/484 `zip_core` tests passing (483 + 1 new), zero regressions. Checked general PR-level comments too (not just review threads) — nothing else open, just CodeRabbit's own walkthrough and review-trigger acknowledgments.
**Context**: PR #31's CodeRabbit review round 5 addressed. Awaiting CI and human review.

---

## CONSTRUCTION - Unit 5 (WebRTC Transport + Remote Output + Capacity): PR #31 approved and merged, unit complete
**Timestamp**: 2026-10-11T01:00:00Z
**User Input**: "pr approved, should I squash and merge?" → "squashed, merged, branch deleted, give me the prompt to start the next piece of work in a fresh session"
**AI Response**: Confirmed PR #31's readiness directly before recommending the merge: all 6 CI checks green, `mergeStateStatus: CLEAN`, `mergeable: MERGEABLE`, all 14 review threads resolved across 5 CodeRabbit rounds — recommended squash-merge, matching this repo's established convention for feature branches (PRs #22, #29). User approved and merged via the GitHub UI; branch deleted. Confirmed the merge landed on `develop` directly (`git fetch`, commit `7203be3`). Updated `aidlc-state.md`: Unit 5's own checkbox flipped to complete/merged, and the Phase 2 "Current Stage" pointer updated to identify Unit 6 (Zip Broadcast Broadcast UI) as the next unit, per `phase2-unit-of-work-dependency.md` ("Unit 6 needs Unit 5 and Proto-11 and Proto-12" — both prototypes already approved in Unit 1) and the project's own suggested execution order (Unit 6 before Unit 7, both now unblocked by Unit 5).
**Context**: Unit 5 fully shipped. Handing off to a fresh session to start Unit 6 (Zip Broadcast Broadcast UI) at Functional Design, per the AI-DLC Inception→Construction model-switching convention (Opus for Inception through Application Design, Sonnet from Functional Design onward).

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): Functional Design drafted
**Timestamp**: 2026-10-12T23:30:00Z
**User Input**: "Let's proceed, and we can delegate as much as possible to qwen, because our weekly limit for anthropic is almost exhausted."
**AI Response**: Created branch `feature/broadcast-ui` off up-to-date `develop`. Delegated the Functional Design draft (domain entities, business logic model, business rules, and the open-questions plan doc) to Qwen, given the user's explicit quota-conservation directive — a departure from this project's normal pattern of Claude drafting judgment-heavy design stages directly. Took 3 delegation rounds: round 1 spent its full 90-minute budget on thorough research without writing any output; round 2 failed instantly on a transient backend error; round 3 (after a correction brief redirecting it straight to writing) produced all three design-logic files but hit a sandbox misconfiguration (`aidlc-docs/*` was blanket-denied for Qwen's writes) before reaching the plan doc. Performed a full Claude-side QA pass on the three delivered files: cross-checked every signature claimed as "fixed" against `phase2-component-methods.md`/`phase2-services.md` (all matched verbatim); spot-verified the flagged gaps against actual shipped source (confirmed `RemoteBroadcastTarget`'s constructor really does default to `inactive` with no priming mechanism, as claimed — a genuine, evidence-backed gap, not an invented signature); confirmed Rule 9's sign-out guard is fully specified with exact call-site mechanics; confirmed the caption-attribution backlog item is resolved with explicit reasoning, not silently dropped. Wrote the open-questions plan doc directly (compiling the ~9 questions Qwen had already flagged inline) rather than spending a 4th delegation round, since it was a low-risk compilation task. Copied all four files into their repo locations via filesystem copy. Separately, with the user's explicit sign-off, narrowed the orchestrator's `aidlc-docs/*` deny rule to allow `aidlc-docs/construction/**` (keeping `audit.md`/`aidlc-state.md` denied) so future design-stage delegations don't hit the same wall.
**Context**: Draft ready for review at `aidlc-docs/construction/broadcast-ui/functional-design/` and `aidlc-docs/construction/plans/broadcast-ui-functional-design-plan.md`. Awaiting the user's answers to the plan doc's 9 open questions and explicit stage approval before proceeding to NFR Requirements.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): Functional Design approved
**Timestamp**: 2026-10-12T23:55:00Z
**User Input**: Answered Q1-Q9 in `broadcast-ui-functional-design-plan.md`: Q1=A (CaptioningStarter seam), Q2=C (rename this unit's class to `BroadcasterSessionState` rather than the recommended no-rename), Q3=B (add `startedAt` field to `LiveBroadcast` rather than the recommended UI-local timestamp), Q4=A, Q5=A, Q6=A, Q7=A, Q8=A, Q9=A. "answered, proceed."
**AI Response**: Propagated Q2 and Q3's non-default answers (both approved deviations from Application Design's fixed shapes) across all three Functional Design artifacts and the plan doc itself: renamed the sealed session-state class from `BroadcastSessionState` to `BroadcasterSessionState` throughout (resolves the Phase 1 naming collision fully, no alias needed), and added `LiveBroadcast.startedAt` (stamped at `goLive()`'s F2-9 step, read directly by the dashboard's Duration stat card instead of a separate UI-local provider). Confirmed Q1/Q4-Q9's recommended answers needed no content changes (the draft was already written assuming them) and tidied the remaining "proposes"/"flagged, not silent" language that implied those were still open. Functional Design stage approved.
**Context**: Unit 6 Functional Design complete and approved on `feature/broadcast-ui`. Two Application Design deviations now in force for this unit: `BroadcasterSessionState` (renamed from `BroadcastSessionState`) and `LiveBroadcast`'s 8th field `startedAt`. Next: Unit 6 NFR Requirements.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): NFR Requirements started
**Timestamp**: 2026-10-12T23:58:00Z
**User Input**: "I'm continuing AI-DLC Construction work on the zip-captions-monorepo. Model: Sonnet (Construction phase, per CLAUDE.md). Current branch: feature/broadcast-ui (off develop). Uncommitted, not yet committed (per standing rule: commit only right before a PR or branch switch, not as-you-go): aidlc-docs/aidlc-state.md (modified), aidlc-docs/audit.md (modified), aidlc-docs/construction/broadcast-ui/ (new — functional-design/domain-entities.md, business-logic-model.md, business-rules.md), aidlc-docs/construction/plans/broadcast-ui-functional-design-plan.md (new). Status: Unit 6 (Zip Broadcast Broadcast UI, Story S-17) just had its Functional Design stage drafted and approved (2026-10-12) — all 9 open questions in the plan doc answered, two Application Design deviations approved and propagated consistently across all artifacts: 1. The sealed session-state class was renamed BroadcasterSessionState (Application Design's fixed name was BroadcastSessionState — it collided with an unrelated, already-shipped Phase 1 model of the same name in zip_broadcast). 2. LiveBroadcast gained an 8th field, startedAt (DateTime), stamped at goLive()'s F2-9 step, for the dashboard's Duration stat card — not in Application Design's original 7-field shape. Also approved: a new CaptioningStarter interface/seam in zip_core (bridges BroadcastSessionNotifier to the app's recording machinery via the same override pattern as authServiceProvider), and two additive fixes to Unit 5's shipped zip_core components — RemoteBroadcastTarget.primeActivity() and BroadcastTransport.sendBroadcastEnded() — both real gaps between Application Design's stated intent and Unit 5's actual shipped code, verified against source before being proposed. Both Backlog items that were flagged 'revisit at Unit 6 Functional Design' are now resolved: the Unit 2 Rule 9 sign-out guard is fully specified (ZbAppShell.requestSignOut(), sole call path to AuthNotifier.signOut(), refuses outright while BroadcasterSessionState is non-idle), and caption attribution is explicitly deferred to whichever future unit bumps CaptionWireCodec's version (not silently dropped) — see business-rules.md Rule 8. Read aidlc-docs/aidlc-state.md's current-stage line and the Unit 6 entry, aidlc-docs/audit.md's last two entries, and the four files listed above for full context before doing anything. Next task: Unit 6 NFR Requirements, per ai-dlc/aidlc-rules/aws-aidlc-rules/core-workflow.md's per-unit loop (log user input in audit.md, load the stage's rule-detail file, execute, present the standardized 2-option completion message, wait for explicit approval, log the response). We're back to regular (non-quota-constrained) Claude usage, so no Qwen delegation needed for this stage — draft it directly. Don't commit anything yet — the uncommitted files above are intentional, pending further review/commit at the next natural checkpoint (before a PR or branch switch)."
**AI Response**: Read `aidlc-state.md`, `audit.md`'s tail, and all three Unit 6 Functional Design artifacts plus the Functional Design plan doc for full context. Loaded `core-workflow.md`'s Construction/NFR Requirements stage definition and `.aidlc-rule-details/construction/nfr-requirements.md`'s step-by-step process, plus the Security Baseline and Property-Based Testing extension rule files (both enabled with full enforcement per `aidlc-state.md`). Drafting the NFR Requirements plan directly (Sonnet, no Qwen delegation, per the user's instruction that this is a regular-usage session).
**Context**: Unit 6 Functional Design APPROVED 2026-10-12, no code generated yet. Proceeding to NFR Requirements Step 2-4 (plan + questions), to be saved at `aidlc-docs/construction/plans/broadcast-ui-nfr-requirements-plan.md`.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): NFR Requirements plan drafted
**Timestamp**: 2026-10-13T00:05:00Z
**User Input**: (no new input — continuing NFR Requirements drafting per the prior entry)
**AI Response**: Created `aidlc-docs/construction/plans/broadcast-ui-nfr-requirements-plan.md` with 7 questions across Testability (Q1 fake-collaborator strategy for `BroadcastSessionNotifier`, Q2 widget-test scope for both screens), Reliability (Q3 exception-safety of `goLive()`'s unwind / `endBroadcast()`'s teardown — a genuine gap not addressed by Functional Design), Security (Q4 logging restatement), Tech Stack (Q5 confirm no new dependency), PBT (Q6 `glados` model-based suite for `BroadcasterSessionState` + invariant suite for `validateSessionName`), and Usability (Q7 accessibility semantics — deferred, consistent with this project's pattern of not deciding cross-cutting concerns narrowly under one unit). Scalability and Performance marked N/A in the plan's context section with rationale (no new capacity/latency concern introduced) rather than forced into questions. All 7 questions carry a recommended option, consistent with every prior unit's NFR Requirements plan.
**Context**: Plan ready for the user's answers at `aidlc-docs/construction/plans/broadcast-ui-nfr-requirements-plan.md`. Awaiting responses before generating `nfr-requirements.md`/`tech-stack-decisions.md`.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): NFR Requirements artifacts generated
**Timestamp**: 2026-10-13T00:15:00Z
**User Input**: "done, proceed" — all 7 questions (Q1-Q7) in `broadcast-ui-nfr-requirements-plan.md` answered A (every recommended option).
**AI Response**: Reviewed all 7 answers for ambiguity (Step 5) — all clean letter choices, no vague/hedging language, no follow-up needed. Generated `aidlc-docs/construction/broadcast-ui/nfr-requirements/nfr-requirements.md` and `tech-stack-decisions.md`. Security Baseline compliance: 6 Compliant, 9 N/A (SECURITY-14 N/A per the project's standing alerting-infrastructure Backlog item, same rationale as every prior unit), 0 non-compliant. PBT compliance: 8 Compliant/Compliant-planned, 2 N/A (PBT-02 round-trip and PBT-05 oracle — neither applies to this unit's domain), 0 non-compliant. No blocking findings under either extension. Added a new Backlog item (Q7): accessibility semantics for the captions-inactive/broadcast-full banners and the Duration stat card are deferred to a future project-wide accessibility pass, consistent with how crash-reporting and operational alerting were previously deferred rather than decided narrowly under one unit.
**Context**: Artifacts ready for review at `aidlc-docs/construction/broadcast-ui/nfr-requirements/`. Awaiting stage approval before proceeding to Unit 6 NFR Design.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): NFR Requirements approved
**Timestamp**: 2026-10-13T00:20:00Z
**User Input**: "approved, proceed"
**AI Response**: NFR Requirements stage approved. Loaded `.aidlc-rule-details/construction/nfr-design.md`'s step-by-step process. Drafting the NFR Design plan: resilience (shared disposal-helper/resource-bundle design for the Rule 2/5 unwind-teardown catch-and-continue), security (a TOCTOU-avoidance rule for Rule 9's `requestSignOut()` check-then-call sequence, mirroring Rule 1's "synchronously before the first await" discipline), and logical components (final component list/dependency diagram, restating `tech-stack-decisions.md`). Scalability and Performance restated as N/A — no new pattern beyond what NFR Requirements already fixed.
**Context**: Unit 6 NFR Requirements APPROVED 2026-10-13. Proceeding to NFR Design Steps 2-4 (plan + questions), to be saved at `aidlc-docs/construction/plans/broadcast-ui-nfr-design-plan.md`.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): NFR Design plan drafted
**Timestamp**: 2026-10-13T00:25:00Z
**User Input**: (no new input — continuing NFR Design drafting per the prior entry)
**AI Response**: Created `aidlc-docs/construction/plans/broadcast-ui-nfr-design-plan.md` with 3 questions: Q1 (Resilience) a shared `_SessionResources` holder + `disposeAll()` method so the Rule 2/5 catch-and-continue teardown isn't duplicated between `goLive()`'s unwind and `endBroadcast()`'s teardown; Q2 (Security) an explicit no-await-between rule for Rule 9's `requestSignOut()` check-then-call sequence, mirroring Rule 1's existing "synchronously before the first await" discipline, to guard against a future edit silently reopening the mid-`goLive()` sign-out race; Q3 (Logical Components) the final component list/dependency diagram, restating `tech-stack-decisions.md` with Q1's addition. Scalability and Performance restated as N/A per the prior stage, no new pattern. All 3 questions carry a recommended option.
**Context**: Plan ready for the user's answers at `aidlc-docs/construction/plans/broadcast-ui-nfr-design-plan.md`. Awaiting responses before generating `nfr-design-patterns.md`/`logical-components.md`.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): NFR Design artifacts generated
**Timestamp**: 2026-10-13T00:30:00Z
**User Input**: "done" — all 3 questions (Q1-Q3) in `broadcast-ui-nfr-design-plan.md` answered A (every recommended option).
**AI Response**: Reviewed all 3 answers — clean letter choices, no ambiguity, no follow-up needed. Generated `aidlc-docs/construction/broadcast-ui/nfr-design/nfr-design-patterns.md` and `logical-components.md`. Q1's `_SessionResources` holder + `disposeAll()` gives both `goLive()`'s unwind and `endBroadcast()`'s teardown one shared disposal implementation, and makes "no session resources exist" a directly checkable invariant (non-null in non-idle states, null in idle states) rather than an informal claim. Q2's no-await-between rule for `requestSignOut()` is documented explicitly, mirroring Rule 1's existing discipline. Q3's component list/dependency diagram confirms `tech-stack-decisions.md`'s placement with Q1's addition. Scalability/Performance restated as N/A, no new pattern.
**Context**: Artifacts ready for review at `aidlc-docs/construction/broadcast-ui/nfr-design/`. Awaiting stage approval before proceeding to Unit 6 Code Generation (Infrastructure Design skipped — no infrastructure change in this unit, matching Unit 5's precedent of UI/orchestration-only units skipping it).

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): NFR Design approved
**Timestamp**: 2026-10-13T00:35:00Z
**User Input**: "approved, proceed"
**AI Response**: NFR Design stage approved. Per `core-workflow.md`'s per-unit loop, Infrastructure Design is CONDITIONAL ("Execute IF infrastructure services need mapping / deployment architecture required / cloud resources need specification") — this unit introduces no infrastructure, no migration, no deployment-architecture change (confirmed against `nfr-design-patterns.md`/`logical-components.md`: this unit is `zip_core`/`zip_broadcast` Dart/Flutter code only). Skipping Infrastructure Design, proceeding directly to Code Generation (ALWAYS executes). Loaded `.aidlc-rule-details/construction/code-generation.md`'s step-by-step process to draft Part 1 (Planning).
**Context**: Unit 6 NFR Design APPROVED 2026-10-13. Proceeding to Code Generation Part 1 (Planning).

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): Code Generation Part 1 (Planning) drafted
**Timestamp**: 2026-10-13T00:45:00Z
**User Input**: (no new input — continuing Code Generation Part 1 per the prior entry)
**AI Response**: Explored the current `zip_core`/`zip_broadcast` source tree directly (not assumed) to ground every planned file path and signature in real, existing code: `services/broadcast/`, `services/caption/`, `services/webrtc/` (confirmed `RemoteBroadcastTarget`'s exact constructor/mapping, `BroadcastTransport`'s exact interface, `WebRtcBroadcastTransport`'s session-tracking internals for the `sendBroadcastEnded()` additive method, `ViewerAdmission`'s `now`-seam convention, `TransportSelector`), `shell/zb_app_shell.dart`, `screens/account_section.dart`/`settings_screen.dart`, `providers/broadcast_recording_notifier.dart`/`broadcast_providers.dart`, `routing/zb_router.dart`, and the existing test helpers (`zb_test_harness.dart`, `account_section_test.dart`'s fake-notifier-override pattern). Confirmed `BroadcastEnded` already exists as a shipped `SignalingMessage` variant (Unit 5) with a drop-if-from-viewer branch already in place — `sendBroadcastEnded()` only needs to send it, no new wire type. Confirmed no `broadcast_failure.dart`/`broadcast_settings.dart`/`broadcaster_session_state.dart`/`live_broadcast.dart`/`captioning_starter.dart` file exists yet (all genuinely new, not already materialized by an earlier unit). Created `aidlc-docs/construction/plans/broadcast-ui-code-generation-plan.md` with 36 numbered steps across `zip_core` models/services/additive-changes/barrel/tests (1–23), `zip_broadcast` l10n/frontend/tests (24–35), and documentation (36). Includes two existing-file test updates flagged explicitly (Step 33's `account_section_test.dart`, since Q6's guard change breaks its current direct-call assertion) and one l10n step (24) that edits `app_en.arb` then runs `flutter gen-l10n`, per this project's standing l10n-source-of-truth rule.
**Context**: Plan ready for review at `aidlc-docs/construction/plans/broadcast-ui-code-generation-plan.md`. Asked the user whether Part 2 should delegate to Qwen per `CLAUDE.local.md`'s standing protocol or generate directly — user chose direct Claude generation, consistent with this session's regular/non-quota-constrained usage. No Qwen delegation for this unit's Code Generation.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): Code Generation Part 1 approved; Part 2 starting
**Timestamp**: 2026-10-13T00:50:00Z
**User Input**: "approved, proceed"
**AI Response**: Code Generation plan approved (36 steps). Beginning Part 2 (Generation), executing steps sequentially with checkboxes updated in the plan file as each completes, direct Claude generation per the user's delegation choice.
**Context**: Starting Step 1 (`lib/src/models/broadcast_settings.dart`).

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): Code Generation Part 2, Steps 1-13 complete
**Timestamp**: 2026-10-13T01:10:00Z
**User Input**: (no new input — executing the approved plan)
**AI Response**: Generated all `zip_core` production code: 4 new models (`broadcast_settings.dart` with `validateSessionName`/`SessionNameError`, `broadcaster_session_state.dart`, `live_broadcast.dart`, `broadcast_failure.dart`), the `CaptioningStarter` seam (interface + `DefaultCaptioningStarter` + provider), `SessionResources` (NFR Design Q1's shared disposal holder — named without a leading underscore since Dart privacy is per-file, not per-directory; kept out of the barrel export instead), `BroadcastSessionNotifier` (explicit per-step try/catch matching `business-rules.md` Rule 2's table exactly, including its deliberate no-unwind choice for step 6's failure), `BroadcastSettingsNotifier`, and the two additive methods on Unit 5's shipped `RemoteBroadcastTarget`/`BroadcastTransport`/`WebRtcBroadcastTransport`. **Found and fixed a real testability gap during Step 8**: `TransportSelector.broadcastTransport()`'s declared return type is the concrete `WebRtcBroadcastTransport`, not the `BroadcastTransport` interface, making an initial `transportSelectorProvider` draft unable to ever substitute a fake in this notifier's own tests — replaced with `broadcastTransportFactoryProvider` (`BroadcastTransport Function()`), without touching Unit 5's shipped `transport_selector.dart`. All barrel exports (`models.dart`, `providers.dart`, `services/broadcast/broadcast.dart`, `services/caption/caption.dart`) updated. `dart run build_runner build` and `dart analyze --fatal-infos` both clean after two rounds of fixing real issues (a missing `auth_state.dart` import, two `cancel_subscriptions` lint false-positives since the subscriptions are cancelled inside `SessionResources.disposeAll`, not within the creating method).
**Context**: Steps 1-13 of 36 complete and verified (`dart analyze --fatal-infos` clean). Continuing to Steps 14-23 (zip_core tests).

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): Code Generation Part 2, Steps 10-12/20-21 tests added
**Timestamp**: 2026-10-13T01:20:00Z
**User Input**: (no new input — executing the approved plan)
**AI Response**: Added the `primeActivity()` test group to `remote_broadcast_target_test.dart` (3 new tests). **Correction**: Step 21 assumed a `web_rtc_broadcast_transport_test.dart` file that doesn't exist — `WebRtcBroadcastTransport` is only exercised via `test/integration/webrtc_transport_fake_pair_test.dart`'s fake-pair harness; added the `sendBroadcastEnded()` test there instead, matching that file's established pattern (a confirmed viewer via the real `WebRtcViewerTransport`, a pending never-acked viewer, both observed through bystander `FakeSessionSignalingChannel`s). First assertion attempt was wrong (expected the pending viewer's message list to be entirely empty; it actually already holds the ordinary JoinAccepted/SdpOffer handshake messages) — fixed to assert specifically that no `BroadcastEnded` reaches it. Ran both files directly: 14 + 12 tests passing, 0 regressions, 0 analyze issues.
**Context**: Steps 10-12 and 20-21 verified by actually running the tests, not just analyzing. Continuing to Steps 14-19, 22-23 (fakes and the notifier's own test suite).

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): Code Generation Part 2, zip_core test suite complete
**Timestamp**: 2026-10-13T02:00:00Z
**User Input**: (no new input — executing the approved plan)
**AI Response**: Completed Steps 14-22. Built `FakeCaptioningStarter`, `FakeBroadcastIdentityRepository`, `FakeIceServerProvider`, `FakeBroadcastTransport`, `FakeStatusChannel`, `FakeBroadcastSignalingService` (test helpers), example-based + PBT suites for `validateSessionName` (Step 16-17), `BroadcastSessionNotifier`'s own 24-test example-based suite covering Rules 1-6 and F-6.7 exactly (Step 18), its PBT-06 model-based suite via `ProviderContainer` overrides mirroring `auth_state_machine_properties_test.dart`'s established pattern (Step 19, 100 generated command sequences passing), and `DefaultCaptioningStarter`'s mapping/delegation tests driven against a real `RecordingStateNotifier` (Step 22). **Found and fixed a second real testability gap during Step 18**: the shared `_FakeAuthNotifier` instance can't be used to override `authNotifierProvider` in two independently-built `ProviderContainer`s (Riverpod's "already initialized" guard) — fixed by giving `buildContainer()` an optional fresh-factory parameter and each Rule-3 sub-test its own container-scoped fake, rather than reusing the outer one. Full `zip_core` suite run: 527 passing (4 pre-existing skips, real-Supabase-stack integration tests, unrelated to this unit), `dart analyze --fatal-infos` clean, 0 regressions.
**Context**: Steps 1-22 of 36 complete and verified by running every test, not just analyzing. Continuing to Step 23 (zip_core summary doc) then the zip_broadcast side (Steps 24-35).

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): Code Generation Part 2, zip_broadcast production code complete
**Timestamp**: 2026-10-13T02:30:00Z
**User Input**: (no new input — executing the approved plan)
**AI Response**: Completed Steps 23-30. Wrote `unit6-zip-core-summary.md` (Step 23, documenting the 3 deviations found during zip_core generation). Added ~40 ARB entries to `app_en.arb` and ran `flutter gen-l10n` (Step 24). `ZbAppShell` gained `ZbSignOutScope` (an `InheritedWidget` storing a bound `Future<void> Function()` callback rather than the private `_ZbAppShellState` type directly, avoiding a `library_private_types_in_public_api` lint) and `_requestSignOut()` implementing Rule 9's guard with NFR Design Q2's no-await-between discipline (Step 25). `AccountSection`'s sign-out button switched to `ZbSignOutScope.of(context)` (Step 26). `BroadcastCaptioningStarter` (new file) + `main.dart`'s override (Step 27). `BroadcastScreen` (new file, ~450 lines) — one route switching on `BroadcasterSessionState` per Functional Design Q8, covering the setup form (output targets panel reuse, session-name validation, signed-out overlay, URL row with clipboard copy, Go Live button/progress/failure card) and the live dashboard (viewer count, duration stat card, F-6.4 banner matrix, broadcast-full banner, caption preview, captioning controls, per-input audio rows, viewer list, End Broadcast) (Step 28). Router + nav wiring: new `/broadcast` route, a 4th nav-rail/drawer destination distinct from the existing (confusingly-named, pre-existing) "Broadcast" entry that actually points to Phase 1's local `/recording` screen (Steps 29-30). One real naming collision found and resolved during Step 28: `zip_core` and `zip_broadcast` both define `AudioInputConfig`/`AudioInputVisualStyle` (Phase 1 single-engine vs. this project's multi-engine versions) — resolved with `hide`, matching `broadcast_recording_notifier.dart`'s own existing precedent for the identical collision. Full `dart analyze --fatal-infos` clean on both packages.
**Context**: Steps 1-30 of 36 complete. Continuing to Steps 31-35 (zip_broadcast widget tests + summary).

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): Code Generation Part 2 COMPLETE (all 36 steps)
**Timestamp**: 2026-10-13T03:00:00Z
**User Input**: (no new input — executing the approved plan)
**AI Response**: Completed Steps 31-36. `zb_test_harness.dart` gained the `/broadcast` route; `account_section_test.dart` updated for the `ZbSignOutScope` call path (1 new test); `zb_app_shell_test.dart` (new) — 5 tests covering Rule 9's guard exactly (signOut succeeds from Offline/BroadcastFailedState, refuses with feedback from Starting/Live/EndingState); `broadcast_screen_test.dart` (new) — 13 tests, one per approved Proto-11/Proto-12 state. **Writing the widget tests surfaced two real bugs in the just-written `BroadcastScreen`, not caught by `dart analyze`**: (1) the F-6.4 banner matrix's `paused` state incorrectly inherited the `inactive` state's "never started vs. stopped" history tracking, so a broadcast going straight to `paused` without ever being `active` showed the wrong banner copy — fixed so `paused` always shows "not running," unconditionally, per the design; (2) a `SizedBox(16×16)` wrapping a `Row` (spinner + text) in the Go Live button caused a `RenderFlex` overflow and hung `pumpAndSettle` (the spinner animates indefinitely) — fixed by removing the pointless outer constraint. Both found and fixed before presenting for review, not after. Wrote `unit6-zip-broadcast-summary.md` (Step 35, documenting both bugs and the 2 deviations). **All 36 plan steps complete.** Final gates: `zip_core` 527 passing (4 pre-existing skips), `zip_broadcast` 121 passing, `dart analyze --fatal-infos` clean on both packages, 0 regressions anywhere.
**Context**: Code Generation Part 2 complete for Unit 6. Ready to present the standardized completion message and await stage approval.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): Code Generation approved
**Timestamp**: 2026-10-13T03:05:00Z
**User Input**: "approve and proceed"
**AI Response**: Code Generation stage approved. Correction to the completion message's offered next step: Build and Test is a Phase-level stage ("ALWAYS - after all units complete" per core-workflow.md), not a per-unit one — Phase 2 still has units remaining beyond Unit 6 (per `phase2-unit-of-work.md`), so it does not run yet. The actual next step, matching every prior unit's precedent (Units 2/3/3.1/4/5), is: commit (per the standing rule — only right before a PR or branch switch), open a PR for `feature/broadcast-ui` → `develop`, and after merge move to the next unit.
**Context**: Unit 6 Code Generation COMPLETE and APPROVED 2026-10-13. Next: commit + PR.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): committed and PR opened
**Timestamp**: 2026-10-13T03:10:00Z
**User Input**: (no new input — executing the commit/PR step per the prior entry)
**AI Response**: Reviewed `git status` before staging (all 64 changed/new files matched expected Unit 6 scope — functional-design/NFR-requirements/NFR-design/code-generation docs under `aidlc-docs/construction/broadcast-ui/`, the plan files, and the `zip_core`/`zip_broadcast` production + test code; nothing stray). Committed as a single commit (`98188f0`, "Unit 6: Zip Broadcast Broadcast UI (S-17)") — this branch's first commit, so Functional Design through Code Generation land together, matching this project's established per-unit commit granularity. Pushed `feature/broadcast-ui` to origin and opened **PR #34** against `develop`.
**Context**: Unit 6 fully shipped pending PR review/merge. Awaiting CI and review feedback.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): PR #34 CodeRabbit review addressed
**Timestamp**: 2026-10-13T04:00:00Z
**User Input**: "check the pr feedback, we have changes requested. implement the changes, push the fixes, and respond to the threads, but do not request another review because we are rate limited to one review per hour"
**AI Response**: CodeRabbit posted CHANGES_REQUESTED with 7 actionable comments, all genuine, all fixed: (1) the viewer-list heading reused `homeOutputTargets` instead of a real label — added `broadcastViewers` to the ARB; (2) the per-input audio status strings ('active'/'error'/'inactive') were hardcoded — added `broadcastAudioInputStatus{Active,Error,Inactive}` to the ARB; (3) the nav drawer's new "Go Live" tile used a hardcoded label instead of `l10n.appTitleGoLive` (the rail already did this correctly) — fixed. (4) **Major, and a real gap in the already-approved `business-rules.md` itself, not just the code**: Rule 2's table literally specified no unwind for an F2-6 (target create/register/prime) failure, but `transport.start()` had already succeeded by that point — leaving it running would silently violate the "no session resources in BroadcastFailedState" invariant Rules 1 and 9 both depend on. Fixed the code to unwind (added a shared `_unwindTransport` helper, catch-and-continue style) and corrected `business-rules.md`'s Rule 2 table in place, flagged as a correction, not a silent rewrite. (5) The F2-7 publish-failure unwind could itself throw out of `goLive()` if `transport.stop()` failed, stranding the notifier in `StartingState` (where both retry and sign-out are refused) — wrapped in the same catch-and-continue helper. (6)+(7) `WebRtcBroadcastTransport.sendBroadcastEnded()`'s sequential `for`-loop awaited inside the loop (risking `ConcurrentModificationError` if a session was removed mid-iteration) and gave up on the first viewer whose channel rejected the send (leaving later viewers un-notified) — rewritten as `Future.wait` over a `List.of()` snapshot, sending to every viewer independently. Updated the one test whose expectation the Rule-2 correction changed (`stopCalls` 0→1) and added two new regression tests (F2-7 unwind resilience when `stop()` itself throws; the corrected F2-6 unwind). Gate-checked: `dart analyze --fatal-infos` clean on both packages; `zip_core` 528 tests passing (527 + 1 new), `zip_broadcast` 121 tests passing, 0 regressions. Pushed the fix commit and replied inline on all 7 review threads with what changed and why. Did not request a re-review, per the user's explicit rate-limit instruction.
**Context**: PR #34 fixes pushed and all 7 threads replied to. Awaiting the next automatic CodeRabbit pass (not manually requested) or human merge decision.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): PR #34 second CodeRabbit pass addressed
**Timestamp**: 2026-10-13T04:50:00Z
**User Input**: "proceed"
**AI Response**: All 6 CI checks passed on the previous push. A second CodeRabbit review then ran automatically on the new commit (CodeRabbit's standard per-push behavior — not a re-review manually requested, consistent with the user's rate-limit instruction) and found one new, genuine issue: `_SetupViewState._maybeFetchId`'s "fetch once per mount while signed in" guard never reset on sign-out, so a different user signing in afterward (the `/broadcast` route has no auth redirect, so the widget state can stay mounted across the transition) would see the previous user's cached `BroadcastId`/URL. Fixed: the guard now clears `_idFetchedWhileSignedIn`/`_idFuture` on sign-out. Also added a retry affordance to `_BroadcastUrlRow` for the fetch-failure case, which the original code had no way to recover from (clearing the guard alone in a `catchError` wouldn't trigger a rebuild). Did not add a dedicated widget test for the sign-out-transition case specifically — the fix is a 4-line guard-reset verified by reading, and building the auth-state-transition test harness this would need is disproportionate effort for a quick-fix review response; noted here rather than silently skipped. `zip_broadcast`: 121 tests passing, `dart analyze --fatal-infos` clean. Pushed commit c9a1914, replied on the one new thread. No re-review requested.
**Context**: PR #34 now has two rounds of CodeRabbit feedback fully addressed (8 findings total). Awaiting the next automatic pass or human merge decision.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): PR #34 third CodeRabbit pass addressed
**Timestamp**: 2026-10-13T13:25:00Z
**User Input**: "check the pr, we have changes requested" then "check again, we have a fresh review"
**AI Response**: A third automatic CodeRabbit review (not manually requested) landed on commit `c9a1914`, one new finding: `_BroadcastUrlRow`'s `FutureBuilder` checked `snapshot.hasError` alone, but Flutter's own `AsyncSnapshot.inState` (used internally by `FutureBuilder.didUpdateWidget` when the `future` reference changes) carries the *previous* future's `error`/`data` forward into the new future's `waiting` state — verified directly against Flutter's actual source, not just CodeRabbit's docs citation. This meant the stale error card (with an enabled Retry button) stayed visible for the whole duration of a retried fetch, and a second tap during that window could race a concurrent fetch. Fixed by gating the error branch on `snapshot.connectionState == ConnectionState.done`; while pending it renders nothing, matching the row's existing initial-load behavior. `zip_broadcast`: 121 tests passing, `dart analyze --fatal-infos` clean. Pushed commit `d084777`, replied on the one new thread. No re-review requested (continuing the user's standing rate-limit instruction from earlier in this session).
**Context**: PR #34 now has three rounds of CodeRabbit feedback fully addressed (9 findings total across all rounds), 0 unresolved threads. The PR's `reviewDecision` may still show CHANGES_REQUESTED until CodeRabbit's own next pass or a human override — this is a GitHub display artifact (confirmed via GraphQL that every thread is resolved), not an indication of outstanding work.

---

## CONSTRUCTION - Unit 6 (Zip Broadcast Broadcast UI): PR #34 approved and merged
**Timestamp**: 2026-10-13T14:00:00Z
**User Input**: "pr approved, merged, branch deleted. give me a prompt for the next session to pick up and resume working"
**AI Response**: Confirmed the merge directly (`git fetch origin --prune`): squash-merged to `develop` as `bc19984` ("Unit 6: Zip Broadcast Broadcast UI (S-17) (#34)"), remote branch already deleted by GitHub. Checked out `develop`, fast-forward pulled (`1c2b383..bc19984`), and deleted the local `feature/broadcast-ui` branch (`-D`, since a squash merge produces a commit SHA git doesn't recognize as a descendant of the feature branch tip). Updated `aidlc-state.md`: Unit 6 marked COMPLETE/merged with a summary of all three CodeRabbit review rounds, Current Stage pointer moved to Unit 7 (Zip Captions Viewer, S-19) per `phase2-unit-of-work-dependency.md`. User is pausing development for a few days (personal scheduling, not a project blocker) — gave a resume prompt for the next session rather than starting Unit 7 now.
**Context**: `develop` is at `bc19984`, clean, all of Phase 2's first 6 units (+ 2 spikes, 1 inserted unit) complete. **Next: Unit 7 (Zip Captions Viewer, S-19) — Functional Design**, whenever the user resumes.

---
## CONSTRUCTION - Unit 7 (Zip Captions Viewer): NFR Requirements (unattended run)
**Timestamp**: 2026-10-19T01:43:06Z
**User Input**: (none — unattended run per `.agent/overnight-pipeline.md`; the kickoff prompt constitutes the standing authorization. Vault access was prohibited this session by the kickoff prompt, so Rule 3's vault-first orientation was replaced by reading the FD handoff plus the shipped source directly.)
**AI Response**: Executed the NFR Requirements stage for Unit 7. Loaded the FD handoff summary only (per `aidlc-project-rules/construction/stage-handoff.md` Rule 2) and verified every load-bearing claim against the shipped source rather than assuming it; full FD documents (`business-rules.md`, `business-logic-model.md`, `domain-entities.md`, `frontend-components.md`) were then read because the handoff does not carry Rule 5's seven-row mapping, the 14 rules' exact text, the state transition table used as the PBT-06 reference model, or the per-state rendering matrix — each of those is directly required to write a Compliant Security/PBT assessment and a testable NFR. Source reads: `connect_failure.dart`, `broadcast_link.dart`, `viewer_transport_context.dart`, `viewer_transport.dart`, `web_rtc_viewer_transport.dart`, `status_channel.dart`, `broadcast_limits.dart`, `broadcast_resolver.dart`, `remote_caption_receiver.dart`, `caption_bus.dart`, `caption_output_target_registry.dart`, `on_screen_caption_target.dart`, `session_resources.dart`, `broadcast_session_notifier.dart`, `transport_selector.dart`, `supabase_config.dart`, `turn_config.dart`, `test/helpers/pbt.dart`, `test/pbt/broadcast_link_test.dart`, `test/pbt/broadcast_session_state_machine_properties_test.dart`, `zip_captions/pubspec.yaml`, `zc_router.dart`, `app.dart`, `main.dart`, `test/widgets/recording_screen_test.dart`, and a repo-wide grep for `BroadcastLink.toUrl`/`baseUrl` and for `glados`. Nine questions answered with the recommended option under the run-configuration pre-approval (Q1 fakes added to the existing helper file; Q2 `FakeViewerSessionNotifier` + real router, one test per state; Q3 one shared catch-and-continue `disposeAll`; Q4 no clock seam, `fakeAsync` only; Q5 no new logging, redaction restated; Q6 no new dependency; Q7 PBT-09 = the in-tree shim as the project's Dart PBT framework with its fixed-seed/no-shrinking limits recorded; Q8 injectable announcement seam + semantics-label assertions + ARB-backed `ZcStrings`, no localization framework rollout; Q9 `broadcastBaseUrl` to a new `zip_core` constants file with `BroadcastLink.baseUrl` removed and default behaviour unchanged). No follow-up clarification was needed. Two source findings shaped answers rather than being deferred: `zip_captions` has no localization mechanism today (no `flutter_localizations`, no generated bindings, no `l10n.yaml`), which is why Q8 scopes the mechanism rather than assuming one; and `BroadcastLink.toUrl` is also called broadcaster-side (`BroadcastSessionNotifier`, `zip_broadcast`'s setup screen), which is why Q9 is recorded as cross-package scheduled work with explicit steps. Security Baseline: 6 Compliant, 9 N/A, 0 non-compliant (SECURITY-04 is N/A this unit — the web headers AC is deferred to Phase 5). PBT: 8 Compliant/planned, 2 N/A (PBT-05; PBT-08's shrinking clause met by deterministic seeds plus hand-reduced counterexamples). New Backlog item recorded in the NFR document (project-wide localization of `zip_captions`'s pre-existing screens); it has not yet been added to `aidlc-state.md`'s Backlog section, which is left to the morning review / Documentation Refinement pass. Artifacts: `aidlc-docs/construction/zip-captions-viewer/nfr-requirements/{nfr-requirements.md,tech-stack-decisions.md,handoff-summary.md}`, plan at `aidlc-docs/construction/plans/zip-captions-viewer-nfr-requirements-plan.md`. Gates: `zip_core` `dart analyze --fatal-infos` clean, `zip_core` and `zip_captions` `flutter test` green (no code changed; baseline confirm).
**Approval**: approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-18) — subject to morning review
**Context**: Unit 7 NFR Requirements COMPLETE (pre-approved, pending morning review). Next: NFR Design.

---
## CONSTRUCTION - Unit 7 (Zip Captions Viewer): NFR Design (unattended run)
**Timestamp**: 2026-10-19T02:05:00Z
**User Input**: (none — unattended run per `.agent/overnight-pipeline.md`; the kickoff prompt constitutes the standing authorization. Vault access was prohibited this session by the kickoff prompt; orientation came from the FD and NFR Requirements handoffs plus the shipped source directly.)
**AI Response**: Executed the NFR Design stage for Unit 7. Loaded both prior handoff summaries (per `aidlc-project-rules/construction/stage-handoff.md` Rule 2); full FD documents were already in context from the prior stage's verified read, and the NFR Requirements documents were re-read for the settled answers. Verified every design decision against source rather than assuming: `session_resources.dart` (Unit 6's holder precedent, per-step `runtimeType` logging, package-internal), `broadcast_session_notifier.dart` (no `ref.onDispose`, `_resources` nulled after `disposeAll`, state last), `remote_caption_receiver.dart`/`caption_bus.dart`/`caption_output_target_registry.dart`/`on_screen_caption_target.dart` (sync-vs-async step shapes, `remove()` disposes the target, 50ms debounce timer), `viewer_transport.dart`/`viewer_transport_context.dart`/`transport_selector.dart` (`ViewerTransport` surface; `viewerTransport()` returns the concrete class, hence the factory seam), `status_channel.dart`/`broadcast_status.dart` (what `lastStatus` holds), `broadcast_resolver.dart`/`ice_server_provider.dart` (totality vs uncaught propagation), `connect_failure.dart` (four shipped variants, hand-written `==`), `broadcast_link.dart` and a repo-wide grep of `BroadcastLink.toUrl`/`baseUrl` callers, `pbt.dart` and the two existing PBT suites, `fake_broadcast_session_collaborators.dart` and `fake_signaling_service.dart`, `arbitrary*` generators, `zc_router.dart`, `zip_captions`'s `app.dart`/`pubspec.yaml`/`providers/`, the `app_en.arb` (confirmed nothing reads it), and `recording_screen_test.dart`'s real-router harness shape. Eight design questions answered with the recommended option: Design Q1 the `ViewerSessionResources` 12-field holder with one `disposeAll(log, {releaseTransport})`, per-step catch-and-log, released == null field, single writer of `_resources`; Design Q2 the window `Timer` in the holder, cancelled by `_setState` for any non-`Reconnecting` next state; Design Q3 a `_sessionEpoch` stale-resume guard checked after each of `join()`'s awaits; Design Q4 terminal transitions partially release via the same helper with state assigned last, caption pipeline kept until `leave()`; Design Q5 the `viewerAnnouncerProvider` callback seam + `ViewerStatusRegion` announce-on-change widget (`TextDirection.ltr`, no `BuildContext` in the default); Design Q6 a hand-written `ZcStrings` as the only ARB reader, no `gen-l10n`/`flutter_localizations`/`intl` in this unit; Design Q7 `FakeBroadcastResolver`/`FakeViewerTransport` appended to the existing helper file plus a `fakeAsync`-wrapped stateful harness and a command-sequence generator; Design Q8 final component list, file placement, dependency diagram, and the one deliberate divergence from Unit 6 (`ref.onDispose(leave)` in `build()`). No follow-up clarification needed; no answer changes the approved FD or the settled NFR Requirements answers — each fills a detail those documents explicitly deferred (announcement seam kind/placement, string-resolution mechanism, holder field set). One clarification recorded rather than silently resolved: NFR Requirements' "holder non-null except `Idle`/`InvalidInput`" cannot hold in `ResolvingState` (F-7.2 step 4 is what creates it, and a resolution failure must not have allocated one), so the stateful invariant is documented as exempting `Resolving`; this is a precision fix to the invariant's wording, not a behaviour change, and is flagged for morning review. No production code written; no `docs/` change. Artifacts: `aidlc-docs/construction/zip-captions-viewer/nfr-design/{nfr-design-patterns.md,logical-components.md,handoff-summary.md}` (handoff 34 lines), plan at `aidlc-docs/construction/plans/zip-captions-viewer-nfr-design-plan.md`. Gates: `zip_core` `dart analyze --fatal-infos` clean; `zip_core` `flutter test` 528 passed, 4 pre-existing skips; `zip_captions` `flutter test` 71 passed (baseline confirm — no code changed).
**Approval**: approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-18) — subject to morning review
**Context**: Unit 7 NFR Design COMPLETE (pre-approved, pending morning review). Next: Code Generation Part 1 (planning).

---

## CONSTRUCTION - Unit 7 (Zip Captions Viewer): Code Generation Part 1 (Planning) (unattended run)
**Timestamp**: 2026-10-19T02:12:00Z
**User Input**: (none — unattended run per `.agent/overnight-pipeline.md`; the kickoff prompt constitutes the standing authorization. Vault access was prohibited this session by the kickoff prompt; orientation came from the three handoff summaries, the FD/NFR documents, and the shipped source directly.)
**AI Response**: Executed Code Generation Part 1 (planning) for Unit 7. Loaded the FD, NFR Requirements and NFR Design handoff summaries (per `aidlc-project-rules/construction/stage-handoff.md` Rule 2), then the full FD documents (`business-rules.md` Rules 1-14, `business-logic-model.md` F-7.1 to F-7.9 plus the transition table, `domain-entities.md`, `frontend-components.md`) and `nfr-design/logical-components.md` / `nfr-design-patterns.md`, because the handoffs do not carry Rule 5's seven-row mapping, the state transition table used as the PBT-06 reference model, or the per-state rendering matrix. Read the Unit 6 (36-step) and Unit 5 (29-step) code-generation plans for shape, and checked Unit 6's `construction/broadcast-ui/code/` to confirm Part 1 produced no artifact there. Verified every load-bearing claim against source rather than the handoffs: `connect_failure.dart` still has exactly four variants, so all three additions are real work; `broadcast_link.dart` still hardcodes the v1 apex and `toUrl` is its only `baseUrl` reader; a repo-wide grep confirms `toUrl`'s callers (`BroadcastSessionNotifier`, `zip_broadcast`'s `broadcast_screen.dart:262`, three test files) need no change; `ViewerSessionNotifier`/`ViewerSessionState`/`ReconnectPolicy`/`broadcast_link_config.dart`/`viewerTransportFactoryProvider`/`ZcStrings`/both screens/`viewerAnnouncerProvider`/`ViewerStatusRegion` do not exist; `TransportSelector.viewerTransport()` returns the concrete class (factory seam required); `SessionResources` is the holder precedent; `StatusChannel`/`BroadcastStatus`/`BroadcastResolution` surfaces; the caption pipeline's sync/async dispose shapes; `defaultBroadcastLimits`; the provider names; the real `test/helpers/pbt.dart` API (100 fixed seeds, awaited body, no shrinking) and the existing `arbitraryBroadcastId`/`arbitraryValidBroadcastIdString`/`arbitraryLinkInput` generators; the reusable `FakeStatusChannel`/`FakeBroadcastSignalingService`/`FakeIceServerProvider` and the absence of `FakeBroadcastResolver`/`FakeViewerTransport`; `zc_router.dart`'s single `ShellRoute`; the ARB having no reader anywhere; `zip_captions`' dev dependencies (no `fake_async`, no `mocktail`); `RecordingScreen`'s post-frame route-reentry idiom; `FakeRecordingStateNotifier`'s notifier-subclass precedent. Two findings shaped the plan. (1) `nfr-design-patterns.md` lists 14 holder fields, not the handoff's "12", and a `final` field cannot be nulled to represent "released", so the plan implements a 14-field nullable holder — an implementation detail, recorded in the stage report's ASSUMPTIONS, not a design change. (2) `fakeAsync` is only a `zip_core` dev dependency and the widget tests only need state-shaped fakes (NFR Requirements Q2), so only `zip_core`'s stateful PBT wraps Glados trials in `fakeAsync`. Also recorded for Part 2: `viewerTransportFactoryProvider`'s default body is never invoked by any test (native-stack contact stays out of the suite), and `leave()`'s `disposeAll` default stays `releaseTransport: true` so F-7.7 and the exit matrix agree. Deliverable: `aidlc-docs/construction/plans/zip-captions-viewer-code-generation-plan.md` — 40 numbered, ordered steps in Unit 6's style/granularity, grouped constants/models/contracts -> services -> `zip_core` helpers + unit/PBT suites -> `zip_captions` l10n/providers -> screens/routes/shell -> widget tests -> docs/state, each step naming files touched, the change, the accompanying test, and the ordering rationale where a step blocks another; plus a Test list (18 files: 8 `zip_core`, 8 `zip_captions`, 2 helpers), story traceability to S-19's ACs, a security/PBT compliance section, and explicit no-new-dependency / no-`dart:io` / web-deferred / no-docs / no-`zip_broadcast` fences. No production or test code written (this stage writes the plan only). The planning-stage audit gap flagged by the run configuration (file previously ended at the NFR Design entry) is closed by this entry. Gates (baseline confirm, no code changed): `zip_core` `dart analyze --fatal-infos` clean; `zip_core` `flutter test` 528 passed (4 pre-existing skips); `zip_captions` `flutter test` 71 passed.
**Approval**: approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-18) — subject to morning review
**Context**: Unit 7 Code Generation Part 1 (Planning) COMPLETE (pre-approved, pending morning review). Next: Code Generation Part 2 (implementation).

---

## CONSTRUCTION - Unit 7 (Zip Captions Viewer): Code Generation Part 2 (Implementation) (unattended run)
**Timestamp**: 2026-10-19T05:30:00Z
**User Input**: (none — unattended run per `.agent/overnight-pipeline.md`; the kickoff prompt constitutes the standing authorization. Vault access was prohibited this session by the kickoff prompt, so orientation came from the plan, the FD/NFR documents and the shipped source directly.)
**AI Response**: Executed Code Generation Part 2 against the 40-step plan, TDD throughout (failing test first, then implementation) and in plan order. `zip_core` (Steps 1-20): removed `BroadcastLink.baseUrl` in favour of `broadcastBaseUrl` from `--dart-define=BROADCAST_BASE_URL` with the v1 apex as the default; extended `ConnectFailure` additively with `RateLimited`/`ResolutionFailed`/`NotFound`; added the 10-variant `ViewerSessionState` (with `ViewerIdleState`/`ViewerReconnectingState` renames to avoid the Phase 1 `IdleState`/`ReconnectingState` collisions), `ReconnectPolicy`, `viewerTransportFactoryProvider`, `ViewerSessionResources` and `ViewerSessionNotifier`; appended the viewer generators/command hierarchy and the resolver/transport/status-channel fakes; wrote the 37-row join suite, the 8-row reconnect suite, the resources suite and the PBT-04/PBT-06 suites. Three implementation facts worth recording: (a) subscription cancels in `disposeAll` are detached (`_detach`) because awaiting a broadcast-stream cancel stalls under `fakeAsync`; (b) `leave()` takes the holder out of `_resources` before teardown, while `_terminate` keeps it and relies on per-step nulling — single-writer safety without a double disconnect; (c) an invalid join while any session is held is a no-op, and a same-broadcast join from a terminal state leaves first so every session gets a fresh holder. `zip_captions` (Steps 21-37): extended the ARB with every viewer string; added `ZcStrings` as the only ARB reader (no `gen-l10n`, no `intl`) plus `viewerAnnouncerProvider` (a `(FlutterView, String)` callback, because the non-deprecated `SemanticsService.sendAnnouncement` requires a view); added `JoinBroadcastScreen`, `ViewerScreen`, `ViewerStatusRegion` and an exhaustive `presentViewerState`; registered `/join` inside the shell and `/b/:broadcastId` outside it; added the shell title, drawer destination and home affordance; and wrote the join, viewer, leave, l10n, status-region, presenter and real-router shell suites. Two behaviour corrections made during test-driven implementation rather than after: retry re-enters from the route's broadcast ID (a failed resolution deliberately never sets `currentBroadcastId`), and the leave/back path confirms only in `Resolving`/`Connecting`/`LiveView`/`Reconnecting`, leaving immediately from every terminal state (Rule 9). Step 26's planned file name `broadcast_viewer_screen.dart` shipped as `viewer_screen.dart`, matching the `viewer_session_*` naming already settled in `zip_core`; the same applies to the widget test file names. No new dependencies, no `dart:io`, no `docs/` change, no web work, no `zip_broadcast` change, no `// ignore` comments. Deliverables: `aidlc-docs/construction/zip-captions-viewer/code/unit7-zip-core-summary.md` and `unit7-zip-captions-summary.md`. Gates: `zip_core` `dart analyze --fatal-infos` clean and `flutter test` 599 passed / 4 skipped; `zip_captions` `dart analyze --fatal-infos` clean and `flutter test` 124 passed. Commits on `feature/zip-captions-viewer`: `239fe86` (link config + failures), `60d7ac2` (viewer state), `e4f4f3f` (transport factory), `41301d3` (resources), `dbc1c27` (notifier + suites), `9c4928b` (strings + announcer), `f916103` (screens + routes), followed by the leave/l10n/shell suite commit.
**Approval**: approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-18) — subject to morning review
**Context**: Unit 7 Code Generation Part 2 COMPLETE (pre-approved, pending morning review). Next: open the PR against `develop` after Documentation Refinement.

---

---
## CONSTRUCTION - Unit 8 (External Display): Functional Design (unattended run) — entry reconstructed 2026-10-20
**Timestamp**: 2026-10-19T22:32:07Z
**User Input**: (none — unattended run per `.agent/overnight-pipeline.md` of 2026-10-19.)
**AI Response**: **Reconstructed from `aidlc-docs/overnight-ledger.md` (entry `FD_PROPOSED`)**; the original run did not write an audit entry. Wrote the Unit 8 Functional Design under `aidlc-docs/construction/external-display/functional-design/` (original shape: one window component with a sealed `OverlayWindowMode` including `PopOutMode`, F-8.1..F-8.9 flows, BR-U8-01..20, `screen-retriever-security-10.md` with the SECURITY-10 version check — `screen_retriever` 0.3.0 requires Dart ^3.13.0 / Flutter >=3.47.0 against the monorepo floor 3.10.0, so pin `^0.2.2`, no `legacy.dart` in 0.2.x) and the plan at `aidlc-docs/construction/plans/external-display-functional-design-plan.md`. No human approval available; artifacts stood as proposed, Code Generation gated at the Part 1 boundary per the run rules. Open questions OQ-1 (always-on-top API gap), OQ-2 (§8.8 item 10 controls do not exist), OQ-3 (web Document PiP vs S-20 web exclusion). Committed in `cbb9c79`. **Status: SUPERSEDED 2026-10-20 by the PR #37 review revision** (see the Functional Design REVISION entry below).
**Context**: Reconstructed for the audit record; see the ledger for the contemporaneous detail.

---
## CONSTRUCTION - Unit 8 (External Display): Infrastructure Design (unattended run) — entry reconstructed 2026-10-20
**Timestamp**: 2026-10-19T22:52:00Z
**User Input**: (none — unattended run per `.agent/overnight-pipeline.md` of 2026-10-19.)
**AI Response**: **Reconstructed from `aidlc-docs/overnight-ledger.md` (entry `ID_PROPOSED`)**; the original run did not write an audit entry. Wrote `aidlc-docs/construction/external-display/infrastructure-design/infrastructure-design.md`: ID-1 sub-engine entry point (`args ["multi_window", id, payload]`), ID-2 sub-engine ProviderScope + bridge, ID-3 `screen_retriever` import fence, ID-4 close detection, ID-5 platform window configuration (always-on-top/borderless reality per platform), ID-6 Phase 1 overlay precedent, ID-7 configuration surface. Verified `desktop_multi_window` 0.2.1 claims against the cached plugin source. OQ-1 resolved conservatively (macOS always-on-top in `MainFlutterWindow.swift`; Windows/Linux deferred — native handle unreachable without a new dependency). Committed in `cbb9c79`. **Status: SUPERSEDED 2026-10-20** — the review decisions remove `window_manager` (D-13), replace the close detection with the ready handshake + `'-1'` code (D-9), and settle macOS borderless on the window-created callback directly with no `didBecomeKey` observer (A7 item 3). The ID stage re-runs after NFR Design (D-10); ID-3's `ScreenRetriever.instance` deprecation claim is also corrected as N/A under the `^0.2.2` pin.
**Context**: Reconstructed for the audit record; see the ledger for the contemporaneous detail.

---
## CONSTRUCTION - Unit 8 (External Display): Code Generation Part 1 GATED (unattended run) — entry reconstructed 2026-10-20
**Timestamp**: 2026-10-19T22:43:54Z
**User Input**: (none — unattended run per `.agent/overnight-pipeline.md` of 2026-10-19.)
**AI Response**: **Reconstructed from `aidlc-docs/overnight-ledger.md` (entry `CG_PART1_GATED`)**; the original run did not write an audit entry. Wrote and committed the Code Generation Part 1 plan at `aidlc-docs/construction/plans/external-display-code-generation-plan.md` (30 files; test list T1-T14; later revised to 34 files / T1-T15 at `6f4eaea` for the then-chosen `window_manager` option). Applied the Stage 3 gate as written: Part 2 proceeds only if the plan is a strict transcription of already-approved design with no open questions — neither held (design stages were PROPOSED, not approved; three OQs open), so **Part 2 did not run**. No production code, no dependency, no pubspec or lockfile change. Gates at the time: `zip_core` 603 passed (~4 skipped), `zip_captions` 139 passed, `zip_broadcast` 120 passed, all `dart analyze --fatal-infos` clean. Committed in `cbb9c79`, kept local; pushed and opened as **PR #37** at 23:36Z the same evening. **Status: SUPERSEDED 2026-10-20** — the plan is regenerated as Stage 5 of the revised run (after the FD/NFR/ID revisions); its `window_manager` files (T15, `desktop_window_decorator`) and in-unit pop-out files are removed.
**Context**: Reconstructed for the audit record; see the ledger for the contemporaneous detail.

---
## CONSTRUCTION - Unit 8 (External Display): PR #37 review — authoritative decisions received
**Timestamp**: 2026-10-20T01:52:28Z
**User Input**: (human review on PR #37 — James Petersen.)
**AI Response**: PR #37 (opened 2026-10-19T23:36:51Z, docs-only, `cbb9c79`) went through three review events before the decisions: (1) the agentic code review at 23:36Z returned request-changes (2 blockers — the `screen_retriever` change-signal API was wrong, and the plan's file split contradicted the SECURITY-10 one-import fence — plus 8 majors/8 minors/4 nits); (2) the fixes were applied and committed as `0d7e72b` with every corrected claim verified against the cached plugin sources; (3) the human answered the open questions at 2026-10-19 (OQ-1 = Option B `window_manager`, recorded with its verified reach at `6f4eaea`; OQ-2/OQ-3 = deferred). Then the **authoritative review comment** (PR #37 issue comment 6281471308, 2026-10-20T01:52:28Z, i.e. 2026-10-19 21:52 local) delivered decisions **D-1..D-13**, which supersede the in-unit pop-out design and the `window_manager` option: D-1 pop-out split into its own Phase 2 unit after Unit 8 blocking the v2.0 RC; D-2 borderless from the `desktop_multi_window` window-created callback; D-3 work-area frame via `setFrame`, native full-screen Backlog; D-4 disconnect = close + notify + output stays on (`WaitingForDisplay`, Cancel) + auto-reopen, saved id never overwritten; D-5 S-20 AC4 amended, recognition events change only `activity`; D-6 switch starts off at launch; D-7 window mirrors the main window, per-input colour Backlog; D-8 hand-written versioned codec in `zip_broadcast`, no `zip_core` change; D-9 ready handshake + error code `'-1'`, ping probe removed; D-10 run NFR Requirements and NFR Design; D-11 unattended overnight run; D-12 inception amendments as a split; D-13 `window_manager` removed. A follow-up comment (6282213636, 2026-10-20T02:52:26Z) added the equally authoritative A7 items: the pop-out unit's placement (Phase 2 after Unit 8, reuses the window machinery, translation-dependent parts are Phase 8, blocks the v2.0 RC per PR #38's Phase 6 DoD, definition pending an interactive Inception session); PR #38 coordination (no translation fields in Unit 8; the codec's per-entry `key` is `CaptionDisplayEntry.entryId`, the codec's `v` is the field Phase 8 bumps); and B-3 macOS settled (the window-created callback sees the sub-window directly — no `didBecomeKey`/order-on-screen observer; "borderless applied" stays a Unit 9 manual check). Both comments: <https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308> and <https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6282213636>.
**Context**: These decisions are the binding design input for the Unit 8 revision run. The revised run executes, in order: FD revision (Stage 1), NFR Requirements (Stage 2), NFR Design (Stage 3), ID revision (Stage 4), CG Part 1 regeneration (Stage 5), CG Part 2 (Stage 6), each pre-approved by the run configuration and logged "subject to morning review".

---
## CONSTRUCTION - Unit 8 (External Display): Functional Design REVISION (unattended run)
**Timestamp**: 2026-10-20T05:30:00Z
**User Input**: (none — unattended run per `.agent/overnight-pipeline.md`; the kickoff prompt constitutes the standing authorization. Vault access was prohibited this session; orientation came from the FD plan, the inception documents, the shipped source directly, and the cached plugin sources.)
**AI Response**: Executed Stage 1 of the revised run: the Functional Design revision for Unit 8, applying the PR #37 review decisions D-1..D-13 and required changes B-1..B-9 plus the A7 items, with no new open question. Rewrote `domain-entities.md` (D-4/D-5/D-6 state set `ExternalDisplayStatus` — Unsupported/NoDisplays/Off/Opening/Open(activity)/WaitingForDisplay/Failed; `OverlayActivity` standby/live/paused; `CaptionPosition` top/bottom persisted as `externalDisplayCaptionPosition`; `OverlayConfig` gains `mode` and stops applying `opacity`; `DesktopWindowService` gains `setFrame`/`show` with the open order `createWindow` → `setFrame` → `show`; the hand-written versioned snapshot/launch codec with total-on-error decode, `key` == `CaptionDisplayEntry.entryId`, placeholder `sessionId`/`sourceId`/`timestamp` and the `maxEncodedBytes` guard; `OverlayWindowController` as sole owner, `CaptionOverlayTarget` reduced to thin delegator + caption-bus adapter). Removed every pop-out type, rule and ARB key (D-1) and `window_manager` everywhere (D-13, `window-manager-security-10.md` deleted). Rewrote `business-logic-model.md` (flows §1-§9, state machine T1-T17, A7 forward notes) and `business-rules.md` (BR-U8-10/16 removed, BR-U8-17 overturned and replaced by the D-5 rule, BR-U8-21..26 added, PBT-01 properties FP-1..FP-5 — codec round-trip, codec total-on-error, frame conversion, open resolution, state-machine closure — with components-without-properties marked). Created `frontend-components.md` (`ExternalDisplayControls` rendering all seven statuses with the Proto-13 Caption Position selector and the waiting/Cancel state; `OverlayWindowApp` standby/live/paused on an opaque theme-driven surface) and `handoff-summary.md`. Corrected `screen-retriever-security-10.md`: 16 releases (counted against the pub.dev release list, not 18) and `ScreenRetriever.instance` verified not deprecated in 0.2.2 (`screen_retriever/lib/src/screen_retriever.dart:9`), so Infrastructure Design ID-3's deprecation claim is N/A under the pin and must be corrected in the ID re-run. **Coordinate facts corrected against the 0.2.2 sources (B-1/B-2)**: all three `screen_retriever` backends already report logical top-left (Windows divides `rcWork` by the monitor scale in the plugin, `screen_retriever_windows_plugin.cpp:116-124`; macOS flips to top-left itself; Linux uses GDK workarea), so the one remaining conversion is a pure function in the io window adapter — macOS Cocoa y-flip against the primary display's full height, Windows multiply by the target display's own `scaleFactor`, Linux identity — specified and PBT-covered (FP-3), not scattered across the adapter. Inception amendments applied exactly as the review lists them: S-20 AC4 amended in `phase2-stories.md`; Unit 8 stages in `phase2-unit-of-work.md` now FD, NFR Requirements, NFR Design, Infrastructure Design, Code Generation (summary-table row updated); `aidlc-state.md` Current Stage moved to Unit 8 FD revision, Unit 7 marked merged (PR #36, `99dd5ee`), Unit 8 entry added, and the Backlog pop-out entry re-scoped to its own Phase 2 unit after Unit 8 (reuses the window machinery, blocks the v2.0 RC, definition pending) with native full-screen and per-input caption colour added as new deferred items. The plan was rewritten with the D-1..D-13 decision table attributed to the review comment, the B-1..B-9 change table, the superseded `6f4eaea`/OQ-1 record, the Application Design deviations, the Security Compliance section (10 Compliant, 5 N/A, 0 non-compliant), PBT-01 compliance, and the NFR stages reinstated. No production code, no dependency, no pubspec or lockfile change, no `docs/` change, no pop-out unit definition. One assumption recorded: the `overlayReadyTimeout` value (~10 s named constant) is a design constant for Code Generation to name; the review fixed the mechanism, not the number.
**Approval**: approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-19) — subject to morning review
**Context**: Stage 1 (Functional Design revision) COMPLETE (pre-approved, pending morning review). Next: Stage 2 — NFR Requirements (a fresh stage for this unit per D-10), starting from `handoff-summary.md`.

---
## CONSTRUCTION - Unit 8 (External Display): NFR Requirements (unattended run)
**Timestamp**: 2026-10-20T10:14:09Z
**User Input**: (none — unattended run per `.agent/overnight-pipeline.md`; the kickoff prompt constitutes the standing authorization. Vault access was prohibited this session by the kickoff prompt, so Rule 3's vault-first orientation was replaced by the Stage 1 handoff summary plus the shipped source directly.)
**AI Response**: Executed Stage 2 of the revised run: NFR Requirements for Unit 8, a fresh stage per D-10. Loaded the Stage 1 `handoff-summary.md` first (per `aidlc-project-rules/construction/stage-handoff.md` Rule 2), then the full FD artifacts (`business-rules.md`, `business-logic-model.md`, `domain-entities.md`, `frontend-components.md`) — logged here per Rule 2, because the handoff does not carry the BR-U8 text, the T1-T17 transition table, the FP-1..FP-5 property table, the codec wire shape and size-guard precedent, or the render-by-status matrix, all of which are directly required for the Security/PBT compliance assessment and the concrete performance targets. Also verified against source before writing questions: `zip_broadcast/pubspec.yaml` (no `screen_retriever`/`glados`/`window_manager`; `fake_async ^1.3.2` and `mocktail ^1.0.4` already dev dependencies; `desktop_multi_window ^0.2.0` shipped), `test/helpers/pbt.dart` (100 trials, seeds 0..99, async body, `combine2..6`, no shrinking), `test/helpers/mock_desktop_window_service.dart` (6-line mocktail mock of the shipped four-method interface), `lib/src/output/overlay/desktop_window_service.dart` (the shipped four methods, B-6's two not yet present), `caption_wire_codec.dart:25`/`signaling_codec.dart:37` (`maxEncodedBytes = 16 * 1024`), `on_screen_caption_target.dart` (50 ms debounce, `maxBufferSegments` 2000), `recording_screen.dart:131` (`CaptionDisplayWidget` present), and the shipped `lib/src/output/overlay/` directory (placement home). Nine questions answered under the run-configuration pre-approval: Q1 fakes (extend `MockDesktopWindowService` with `setFrame`/`show` per B-6/A7; new `FakeDisplayEnumerator`; `fakeAsync` for the handshake); Q2 one widget test per `ExternalDisplayStatus` (7, `Unsupported` renders nothing) plus per-`OverlayActivity` render, the "Window unavailable" frame, position top/bottom, and the BR-U8-20 theme-wiring test; Q3 one shared private catch-and-continue `_release(log)` with the terminal transition last, the display-lost path sharing it (release first, `WaitingForDisplay` with `overlayEnabled` still true, D-4), and the sub-engine method handler total-on-malformed-input (BR-U8-19); Q4 `overlayReadyTimeout = 10 s` named const (the FD's BR-U8-23 "~10 s" read as its own number — recorded under ASSUMPTIONS), expiry → `OpenFailed(ready_timeout)`, late ready a no-op, `fakeAsync`-driven, no clock seam; Q5 the concrete performance targets (≤1 `getAllDisplays()` per platform event, 0 polls; open bounded by the 10 s constant over `createWindow`→`setFrame`→`show` with no snapshot before ready; ≤1 `captionUpdate` per animation frame (60/s) with every payload under `maxEncodedBytes` = 16 KiB; the state machine synchronous per event) and the Unit 9 manual-check list (placement, borderless, hot-plug reopen, OS-shortcut close, B-4 plugin registration — recorded, not claimed, per the device policy); Q6 no new logging infrastructure, fixed string + error type at every new call site, `OpenFailed.reason` a fixed code, and a redaction test (capturing `Logger.onRecord`) auditing the decode-failure, open-failure and release paths for BR-U8-18; Q7 exactly one new dependency, `screen_retriever: ^0.2.2` per the FD's SECURITY-10 record, `window_manager` dropped (D-13), any other need BLOCKED; Q8 PBT-09 = the in-tree shim `packages/zip_broadcast/test/helpers/pbt.dart` (re-affirming Unit 7's recorded Dart PBT decision for this package's copy), with FP-1..FP-5 each checked expressible (no fallback needed) and FP-5 a `fakeAsync`-wrapped stateful suite in the `zip_core` state-machine property shape, plus the implementation directive that the BR-U8-07 resolution be a pure function for FP-4; Q9 NFR-5.1 carried as two tests — the BR-U8-20 theme-wiring test (the AAA ratio itself stays owned by `zip_core/test/pbt/theme_contrast_test.dart` and is not repeated) and an opaque-surface test (`OverlayConfig.opacity` 0.9 not applied, alpha 255, BR-U8-26) — with the seven statuses distinguishable by text/icon never colour alone and all copy in `app_en.arb`. Security Baseline: 7 Compliant (03, 05, 08, 09, 10, 11, 15), 8 N/A (01, 02, 04, 06, 07, 12, 13, 14 — 04 with web deferred to Phase 5), 0 non-compliant. PBT: 10 Compliant/planned (PBT-08 with the recorded no-shrinking limit; PBT-04's close/release idempotence rides in FP-5), 0 N/A. No blocking finding under either extension. Plan at `aidlc-docs/construction/plans/external-display-nfr-requirements-plan.md` (all nine `[Answer]:` entries settled by the review comment / A7 / the FD / an existing project convention; no genuinely new question arose, so no BLOCKED); artifacts at `aidlc-docs/construction/external-display/nfr-requirements/` (`nfr-requirements.md`, `tech-stack-decisions.md`, `handoff-summary.md`).
**Approval**: approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-19) — subject to morning review
**Context**: Stage 2 (NFR Requirements) COMPLETE (pre-approved, pending morning review). Next: Stage 3 — NFR Design, starting from the NFR Requirements `handoff-summary.md`.

---
## CONSTRUCTION - Unit 8 (External Display): NFR Design (unattended run)
**Timestamp**: 2026-10-20T14:42:46Z
**User Input**: (none — unattended run per `.agent/overnight-pipeline.md`; the kickoff prompt constitutes the standing authorization. Vault access was prohibited this session by the kickoff prompt, so Rule 3's vault-first orientation was replaced by the Stage 2 handoff summary plus the shipped source directly.)
**AI Response**: Executed Stage 3 of the revised run: NFR Design for Unit 8. Loaded the Stage 2 `handoff-summary.md` first (per `aidlc-project-rules/construction/stage-handoff.md` Rule 2), then the full FD artifacts (`business-rules.md`, `business-logic-model.md`, `domain-entities.md`) — logged here per Rule 2, because the handoff does not carry the T1-T17 transition table, the BR-U8 rule text, the codec wire shape, or the `ExternalDisplayStatus`/`OverlayEvent` type shapes, all of which the design questions (release step set, timer cancellation, the `'-1'` seam, the resolution function's signature, the state→pattern mapping) quote directly. Also verified against the pub cache and shipped source before writing answers: `desktop_multi_window-0.2.1` (`WindowController.fromWindowId(id)` with `show()`/`setFrame(Rect)`/`close()` at `lib/src/window_controller.dart:22-31`; `DesktopMultiWindow.setMethodHandler` static taking `Future<dynamic> Function(MethodCall, int fromWindowId)?` at `lib/desktop_multi_window.dart:59-69`, `null` unregisters); `screen_retriever-0.2.2` (the `Display` model has **no `isPrimary` field** — `id`/`name`/`size`/`visiblePosition`/`visibleSize`/`scaleFactor` only; `getPrimaryDisplay()`/`getAllDisplays()` implemented on all three backends; `getPrimaryDisplay()` is a per-call platform-channel query, `screen_retriever_method_channel.dart:51`; Linux sends `id: ""` for every monitor); the shipped conditional-export pattern (`desktop_multi_window_service.dart` exporting the io/stub triplet, both variants defining `DesktopMultiWindowService`); `browser_source_target.dart`'s `Future<void> _lifecycleLock = Future.value()` serialization idiom; `viewer_session_notifier_test.dart:572-587`'s capturing-`Logger.root.onRecord` redaction pattern; `viewer_session_state_machine_properties_test.dart`'s `_World`/`fakeAsync`-per-trial harness shape; and the hand-written `Provider` precedents (`onScreenCaptionTargetProvider`, `transcriptWriterTargetProvider`). Nine design questions answered under the run-configuration pre-approval, all with the recommended option; no genuinely new question arose, so no BLOCKED: **Q1** the release helper is window-scoped (cancel ready timer, cancel update timer, `closeWindow(captured id)`, `registry.remove(target)` — per-step `on Object` + `runtimeType`, never throws; `close()` nulls `_windowId` synchronously before its first await) while the `changes` watch is controller-lifetime (cancelled only in `dispose()`, not a release step — T11's auto-reopen, T4's repopulation and T16's retry all fire from window-less states, so per-window ownership contradicts the FD event contract and D-4), and `CaptionOverlayTarget.isVisible` becomes a derived delegation to the controller (the shipped field is deleted — one writer for BR-U8-02's invariant half); **Q2** `Timer? _readyTimer` starts on entering `Opening` before `createWindow` (so the 10 s bound covers the whole open per the NFR performance target) and is cancelled structurally in the single private `_setState(next)` whenever `next is! Opening` (Unit 7's NFR Design Q2 idiom) plus defensively in `_release`; a late ready is a no-op by construction (`state is Opening` && matching window id); **Q3** every post-ready window call goes through one private `_windowCall` seam — `PlatformException` code `'-1'` while `Open` → `WindowClosed` (never rethrown into the shell's `unawaited` chain), any other `PlatformException` → fixed-string warning, ignored (B-5); `createWindow`'s throw is caught in the open sequence itself (T6); a pre-ready `'-1'` is logged and ignored — the ready timeout is the catch-all, exactly as BR-U8-04's own "after the ready handshake" scoping and B-5 prescribe (no second failure mode invented); **Q4** snapshot delivery is a dirty flag plus one re-arming 16 ms timer (`captionUpdateInterval`), not the Phase 1 reset-timer debounce — a reset timer would never fire under a continuous stream shorter than the interval, violating the settled "regardless of the upstream recognition event rate" target — the stored snapshot doubles as the held snapshot sent on ready; constants placed: `overlayReadyTimeout`/`captionUpdateInterval` as named top-level consts in `overlay_window_controller.dart`, `maxEncodedBytes` as a static const on the codec in `caption_overlay_codec.dart` (mirroring `CaptionWireCodec`'s placement); **Q5** the BR-U8-18 redaction audit is one record-level test (`test/output/overlay/external_display_redaction_test.dart`, capturing `Logger.root.onRecord` + a sentinel caption string) driving the `captionUpdate`-decode-failure, launch-argument-decode-failure, open-failure (`create_failed`, `ready_timeout`) and release paths, asserting no `LogRecord.message`/`error` contains the sentinel and every `OpenFailed.reason` is in the fixed set; the fixed-string call-site table (seven sites) is in the patterns file; **Q6** `overlayWindowControllerProvider` is a hand-written `Provider<OverlayWindowController>` in `lib/src/providers/` with `ref.onDispose(controller.dispose)` (the controller is a plain class per the FD; the project's service objects are hand-written `Provider`s); constructor `(windowService, enumerator, {required handlerInstaller, required log})` — every collaborator injectable so FP-5 needs no plugin; `CaptionOverlayTarget` constructor `(controller, registry, DisplaySettings Function() displaySettings)` reading the main buffer via `registry.activeTargets.whereType<OnScreenCaptionTarget>().firstOrNull`'s `visibleCaptions` (no `BuildContext`, no new `zip_core` surface); the shell keeps its shipped `_syncOverlay`/`ref.listen` machinery, `_syncOverlay(true)` gains `target.show(config)` after `registry.add`, and an `events` subscription maps `WindowClosed`/`OpenFailed` → write `overlayEnabled=false` (the existing `ref.listen` then runs `_syncOverlay(false)` — BR-U8-15's own path) and `DisplayLost` → `_overlayRegistered` bookkeeping only (`overlayEnabled` stays true, D-4); **Q7** `typedef OverlayMethodHandler`/`OverlayMethodHandlerInstaller` in `overlay_window_controller.dart`; the production const `overlayMethodHandlerInstaller` lives in `desktop_multi_window_service_io.dart` (wrapping the static, adapting `MethodCall` → `(method, fromWindowId)`; the file already imports `desktop_multi_window` — no new import surface), a no-op const in the stub, both surfaced through the **existing** conditional export; the controller installs it once on the first open, before `createWindow` (BR-U8-23), and uninstalls (`null`) only in `dispose()`; a `null` installer on a supported platform fails the open as `create_failed` before any `createWindow` (fail-closed — the handler is a precondition of the open, no half-open window); **Q8** FP-4's subject named: pure top-level `({DisplayInfo? target, bool persistedIdPresent}) resolveOpenDisplay(List<DisplayInfo> displays, String? persistedId)` in `overlay_window_controller.dart`, BR-U8-07 verbatim (persisted id if present → first `isPrimary` → first in platform order; empty list → `target: null`), "kept" expressed as the absence of any write path and asserted by FP-4; **Q9** `MockDesktopWindowService` needs no class change (mocktail's `noSuchMethod` covers the B-6 additive interface methods — the extension is one step with the B-6 edit); new `test/helpers/fake_display_enumerator.dart` (scripted `displays()` result/error; broadcast `changes` with a `pushDisplays` helper that **replays the latest list to late subscribers**, mirroring the FD first-emission clause; idempotent recorded `dispose()`) and `fake_overlay_method_handler_installer.dart` (records the installed handler so a trial can invoke `handler('overlayReady', id)`); six domain generators appended to `test/helpers/generators.dart` (`arbitraryDisplayInfo`/`arbitraryDisplayList` with at most one `isPrimary` at any position, empty labels, Linux-normalised and `""` ids, scale factors 0/1/1.5/2; `arbitraryCaptionOverlaySnapshot` with multibyte text; `arbitraryOverlayWindowLaunch`; `arbitraryMalformedWindowJson` including over-size beyond `maxEncodedBytes`; `arbitraryLogicalFrame` with platform inputs; `arbitraryExternalDisplayCommandSequence`); FP-5 is a `_World` harness per Glados trial wrapped in one `fakeAsync` per trial (the `viewer_session_state_machine_properties_test.dart` shape) — real controller on the fakes, real `CaptionBus` + `CaptionOutputTargetRegistry` (in-memory, no I/O), a harness `overlayEnabled` flag modelling the shell's documented reaction to emitted events (without it BR-U8-15's "at every point where `overlayEnabled` is false" is not checkable at the controller level), the command set `toggleOn`/`toggleOff`/`displaysChanged`/`overlayReady`/`advanceReadyTimeout`/`windowGone`/`otherPlatformError`/`createWindowFails`/`captionEvent`/`elapse`, and per-command invariants (only declared `ExternalDisplayStatus` variants, one state at a time, the closed invariant, a second concurrent open refused — `createWindow` call count unchanged — and no `externalDisplayId` write from any open path). Scalability: N/A restated from NFR-2 — no queue, pool, cache, or concurrency axis introduced; nothing in the patterns changes that. Two minimal-interpretation calls recorded for the morning review: (1) BR-U8-12's "caption-position change must reach the window without a reopen" is implemented as "the window applies the persisted position carried in the launch config at open" — the authoritative B-7 wire shape carries no position in the snapshot's `settings` block, so a position changed while open takes effect at the next open (no mechanism beyond the settled shape is invented; font/size/scroll/theme/max-lines do reach a live window via the snapshot's `settings`); (2) `isPrimary` derivation in the io adapter (the 0.2.2 `Display` model has no such field): one `getPrimaryDisplay()` per enumeration event, match by `id` when both non-empty else by geometry (`visiblePosition` + `visibleSize`), on match failure mark the first display in platform order primary — preserves the FD's "exactly one `true`" constraint, matches BR-U8-07's final fallback, one-shot per event, not a poll. No production code, no dependency, no pubspec or lockfile change, no `docs/` change. Plan at `aidlc-docs/construction/plans/external-display-nfr-design-plan.md` (all nine `[Answer]:` entries settled with the recommended option, each citing its source; rejected options with reasons). Artifacts at `aidlc-docs/construction/external-display/nfr-design/` (`nfr-design-patterns.md` — patterns R1-R6/P1-P5/S1-S3/T1-T3 + Security Baseline compliance (7 Compliant, 8 N/A, 0 non-compliant — unchanged from Stage 2) + PBT compliance (10 Compliant/planned, PBT-08 with the recorded no-shrinking limit) + open questions carried to ID/CG; `logical-components.md` — component list with constructor seams, dependency diagram, provider graph, resource lifecycle/cancellation ownership table, and the T1-T17 state→pattern mapping; `handoff-summary.md` — "NFR Design -> Code Generation", decisions, rejected patterns with reasons, constraints). Gates: `zip_core` analyze clean / 603 passed (~4 skipped); `zip_captions` analyze clean / 139 passed; `zip_broadcast` analyze clean / 120 passed.
**Approval**: approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-19) — subject to morning review
**Context**: Stage 3 (NFR Design) COMPLETE (pre-approved, pending morning review). Next: Stage 4 — Infrastructure Design (re-run: correct ID-3's `ScreenRetriever.instance` deprecation claim, now verified N/A under the `^0.2.2` pin; drop ID-5's `window_manager` references; carry B-4's sub-engine plugin registration and the runner callbacks), starting from `aidlc-docs/construction/external-display/nfr-design/handoff-summary.md`.

---
## CONSTRUCTION - Unit 8 (External Display): Infrastructure Design REVISION (unattended run)
**Timestamp**: 2026-10-20T16:21:02Z
**User Input**: (none — unattended run per `.agent/overnight-pipeline.md`; the kickoff prompt constitutes the standing authorization. Vault access was prohibited this session by the kickoff prompt, so Rule 3's vault-first orientation was replaced by the Stage 3 handoff summary plus the shipped source and the pub-cache plugin sources read directly.)
**AI Response**: Executed Stage 4 of the revised run: the Infrastructure Design re-run for Unit 8, rewriting `aidlc-docs/construction/external-display/infrastructure-design/infrastructure-design.md` (ID-1..ID-7) in place per the PR #37 review (D-1..D-13, B-1..B-9) and the A7 follow-up, plus the new plan `aidlc-docs/construction/plans/external-display-infrastructure-design-plan.md` (one of the review's listed missing artifacts — 7 `[Answer]:` questions, all settled with sources, no genuinely new question, so no BLOCKED) and `handoff-summary.md` (Infrastructure Design -> Code Generation). Full prior-stage documents were **not** loaded: the three handoff summaries carried everything the revision needs (logged here per `stage-handoff.md` Rule 2); the one exception was re-reading the superseded ID itself, because this stage rewrites it in place and must correct it line by line. Every plugin claim was re-verified against the cached 0.2.1/0.2.2 sources and the Flutter 3.41.7 SDK source (the review's own method), correcting several stale citations from the superseded document (review §5): ID-1 keeps the three-argument entry contract (verified `macos/Classes/FlutterWindow.swift:73`, `windows/flutter_window.cc:100`, `linux/flutter_window.cc:45-46`) and adds the B-4 corrections — `overlayWindowMain` mirrors `GoogleFonts.config.allowRuntimeFetching = false` (the overlay renders `CaptionDisplayWidget`, zip_core `caption_display_widget.dart:72`), and the sub-engine gets only the plugins registered in the window-created callback — which is an **empty list for the locked dependency set** (verified: `google_fonts` 6.3.3 is pure Dart with no `plugin:` section; the locked `path_provider` federations — foundation 2.6.0, windows 2.3.0, linux 2.2.1 — are Dart-only `dartPluginClass` PDM plugins with no method channel; this is a fact-check against B-4's "expected", not a deviation: B-4 prescribes registering exactly what the code path touches, and the locked path touches no native plugin; macOS font rendering stays a Unit 9 manual check). ID-2 keeps the ProviderScope + bridge, removes `popOutToggle` (D-1), adds the `overlayReady` handshake and the one-handler-owner rule (installed before the first `createWindow`). ID-3 keeps the single `_io` import fence and the Linux empty-id normalisation, corrects the coordinate provenance (all three 0.2.2 backends already emit logical top-left — Windows divides `rcWork` by the monitor scale in-plugin, `screen_retriever_windows_plugin.cpp:116-124`), and replaces the deprecation-hazard paragraph with the verified fact that `ScreenRetriever.instance` is **not** deprecated in 0.2.2 (`screen_retriever.dart:9`) — N/A under the `^0.2.2` pin (review §5); D-3 (work-area frame) recorded with its Backlog item. ID-4 is rewritten per B-5/D-9: ready handshake + error code `'-1'` (verified identical on all three managers: `macos/Classes/MultiWindowManager.swift:37`, `windows/multi_window_manager.cc:158`/`:163`, `linux/multi_window_manager.cc:83`/`:88`), `overlayReadyTimeout` 10 s → `OpenFailed`, any other error fixed-string logged and ignored, ping probe and D10 removed, and the `ChannelBuffers` capacity-1 eviction explained with SDK-source evidence (`kDefaultBufferSize = 1`, `engine/src/flutter/lib/ui/channel_buffers.dart:319`; evicted messages answered null, `:160-168`; null reply → `MissingPluginException`, `packages/flutter/lib/src/services/platform_channel.dart:351-364`; plus the per-backend pre-handler facts — macOS/Windows never answer, Linux answers `'-1'` "window channel no handler"). ID-5 is rewritten per D-2/B-3: borderless from the plugin's window-created callback in all three runners (hooks verified: macOS `FlutterMultiWindowPlugin.setOnWindowCreatedCallback`, `FlutterMultiWindowPlugin.swift:28-30`, fired after `window.contentViewController` at `FlutterWindow.swift:81`, so `controller.view.window` is the sub-window — A7 item 3, no `didBecomeKey` observer; Windows `DesktopMultiWindowSetWindowCreatedCallback`, `desktop_multi_window_plugin.h:20-21`, fired at `flutter_window.cc:116-117` after `SetParent`, `GetAncestor(…, GA_ROOT)` yields the top-level `HWND`; Linux `desktop_multi_window_plugin_set_window_created_callback`, `desktop_multi_window_plugin.h:24-27`, fired at `flutter_window.cc:52-53` with the `FlView` already added, `gtk_widget_get_toplevel` yields the `GtkWindow`), borderless mechanisms per platform (macOS `styleMask`; Windows `GWL_STYLE` + `SetWindowPos(… SWP_FRAMECHANGED)`; Linux `gtk_window_set_decorated(FALSE)`), always-on-top dropped (not a Unit 8 requirement), every `window_manager` reference removed (D-13), the plugin never shows on create (verified all three — `MultiWindowManager.swift:18-27`, `flutter_window.cc:121`, `linux/flutter_window.cc:63`), so open order `createWindow` → `setFrame` → `show` (B-6), and the frame conversion placed in one pure function in the io adapter per B-1/B-2 (macOS `cocoaY = primaryFullHeight − top − height` against `getPrimaryDisplay().size` — the plugin's `setFrame` does no conversion, `FlutterMultiWindowPlugin.swift:54-63`; Windows multiply by the target display's `scaleFactor` under the verified `PerMonitorV2` manifest at `windows/runner/runner.exe.manifest:5` — `MoveWindow` with raw values, `base_flutter_window.cc:61-69`; Linux identity), matching NFR Design P5's `toPlatformFrame` signature. The exact Stage 6 runner files are named: `macos/Runner/MainFlutterWindow.swift` (`awakeFromNib`), `windows/runner/flutter_window.cpp` (`OnCreate`), `linux/runner/my_application.cc` (`my_application_activate`), each with the plugin's own example runner as precedent. ID-6 keeps the Phase 1 precedent table, fixes the stray "`MainAxisAlignment`" wording (the Phase 1 payload is the plain-JSON `{'text','isFinal'}` map, `caption_overlay_target.dart:80`), uses `overlayEnabled` (not `externalDisplayEnabled`), and replaces the undefined `DeletedDisplayId`. ID-7: the persisted settings are `output.overlayEnabled` (existing), `output.externalDisplayId` (new, never overwritten) and `output.externalDisplayCaptionPosition` (new, `CaptionPosition.bottom` default, carried in the launch config via `OverlayConfig.position`, tested in T9); D-3's Backlog note recorded; frame = work area via `setFrame`. Build footprint: the lockfile change is exactly `screen_retriever` + its four federated entries in the root `pubspec.lock` plus the `screen_retriever` pod entries in `macos/Podfile.lock` that the Stage 6 build adds; anything else moving is reported, not committed silently; no CMake/manifest/Podfile/entitlement edits; CI's `build-verify.yml` compiles the Windows/Linux runners and must be green. Security Baseline (7 Compliant, 8 N/A, 0 non-compliant) and PBT (10 Compliant/planned, 0 N/A) compliance sections added, consistent with Stages 1-3. Artifact shape: a single revised `infrastructure-design.md` + `handoff-summary.md`, no `deployment-architecture.md` — following the Phase 2 precedent units (Units 3 and 4) and with the applicability justification recorded in the plan (no cloud/shared infrastructure; the runners are the deployment surface). No production code, no dependency, no pubspec or lockfile change, no `docs/` change.
**Approval**: approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-19) — subject to morning review
**Context**: Stage 4 (Infrastructure Design revision) COMPLETE (pre-approved, pending morning review). Next: Stage 5 — Code Generation Part 1 **regeneration** from the revised design (planning only, no production code), starting from `aidlc-docs/construction/external-display/infrastructure-design/handoff-summary.md`; the regenerated plan must be a strict transcription with the superseded plan's `window_manager` (T15, `desktop_window_decorator`) and in-unit pop-out files removed.

---
## CONSTRUCTION - Unit 8 (External Display): Code Generation Part 1 REGENERATION (unattended run)
**Timestamp**: 2026-10-20T17:26:07Z
**User Input**: (none — unattended run per `.agent/overnight-pipeline.md`; the kickoff prompt constitutes the standing authorization. Vault access was prohibited this session by the kickoff prompt, so Rule 3's vault-first orientation was replaced by the four stage handoff summaries plus the shipped source and the pub-cache plugin sources read directly. Binding design input: the PR #37 review comment 6281471308 (D-1..D-13, B-1..B-9) and the A7 follow-up 6282213636.)
**AI Response**: Executed Stage 5 of the revised run: Code Generation Part 1, **regenerated** in place at `aidlc-docs/construction/plans/external-display-code-generation-plan.md`. **Planning only** — no production code, no test, no pubspec or lockfile change, no runner change, no `docs/` change; the only files touched are the plan and the three logs. Loaded the four stage handoff summaries first (FD, NFR Requirements, NFR Design, Infrastructure Design) per `aidlc-project-rules/construction/stage-handoff.md` Rule 2; the full FD/NFR/ID artifacts were then read as well, because the plan is required to be a strict transcription of them and the handoffs do not carry the BR-U8-01..26 text, the T1-T17 transition table, the FP-1..FP-5 table, the codec wire shape, the render-by-status matrix, or the ID-1..ID-7 runner/lockfile table. The old plan was read and is **superseded in its entirety**: every `window_manager` entry and its `desktop_window_decorator` trio (D-13), T15, the in-unit pop-out files (`PopOutMode`, `pop_out_toggle.dart`, `pip_content.dart`, the inbound `popOutToggle` handler, pop-out ARB keys), the ping-probe close detection (D-9/B-5), the macOS `didBecomeKey` observer (A7 item 3), the "divide by `scaleFactor`" Windows claim (B-2), the "move to primary on disconnect" rule (D-4), and the answered-open-questions section are all removed by this regeneration. The regenerated plan: unit context (S-20 AC4 as amended; the single `screen_retriever: ^0.2.2` dependency with its inline SECURITY-10 comment; the exact lockfile delta — root `pubspec.lock` gains exactly the five `screen_retriever*` entries and `macos/Podfile.lock` only the `screen_retriever` pod entries the macOS build adds, anything else reported not committed; five transcribed assumptions A-1..A-5, all sourced from the binding stages, none new); a 50-row file list (34 paths created, 14 modified — the enumerator io/stub/export triplet with the single plugin import fence, `DisplayInfo`, the `DesktopWindowService.setFrame`/`show` additions with `toPlatformFrame` and the `overlayMethodHandlerInstaller` const in the io adapter, the nine model/type files, the hand-written versioned snapshot/launch codec with `maxEncodedBytes`, `OverlayWindowController` with `resolveOpenDisplay` and the two named timing constants, the reduced `CaptionOverlayTarget`, the sub-engine entry and bridge triplet, `OverlayWindowApp`, `ExternalDisplayControls`, the two profiles, the `OutputTargetSettings`/`OverlayConfig` edits, the shell events subscription with no recognition listener, `main(List<String> args)`, the ARB keys, and the full test/helper set); the explicit T1-T17 + FP-1..FP-5 test list with the `_World` FP-5 harness and the in-tree `test/helpers/pbt.dart` shim (no `glados`); 26 numbered TDD-first steps in the precedent plans' grouping (contracts → pure logic → window service/enumeration → controller → sub-engine → controls → shell → strings → three runners → gates → macOS build → lockfile review) with per-step commits; the three runner changes exactly as ID-5's table (macOS `MainFlutterWindow.swift` borderless `styleMask` from the window-created callback with the empty plugin list, Windows `flutter_window.cpp` `DesktopMultiWindowSetWindowCreatedCallback` + `GWL_STYLE` + `SetWindowPos(SWP_FRAMECHANGED)`, Linux `my_application.cc` `desktop_multi_window_plugin_set_window_created_callback` + `gtk_window_set_decorated(FALSE)`); the verification section (the three package gates, `flutter build macos --debug` as compile-only, Windows/Linux compiled by CI `build-verify.yml`, and the five Unit 9 manual checks recorded as such); 20 exact ARB keys; a hard non-goals fence; and the self-check tables mapping every S-20 AC (AC4 as amended) and every BR-U8-01..26 to its steps/tests, plus the strict-transcription statement. One implementation detail recorded (not a design change): the macOS conversion needs the primary full height, so `DisplayEnumerator` gains the additive `Future<Size?> primarySize()` and the io adapter reads both platform inputs through a `@visibleForTesting` enumerator seam — the `DesktopWindowService` signature stays exactly B-6's. Verified before writing: `desktop_multi_window` 0.2.1 `DesktopMultiWindow.setMethodHandler` shape, `screen_retriever` 0.2.2 `Display` field list (no `isPrimary`) and `ScreenRetriever.instance` (not deprecated), the shipped `main.dart` line 32 / `recording_screen.dart:131` / `caption_overlay_target.dart` / `zb_app_shell.dart` `_syncOverlay` / `broadcast_providers.dart` keys / `output_targets_panel.dart` overlay card / the three runners / `mock_desktop_window_service.dart` / `pbt.dart` / `app_en.arb` (no `Cancel` key today) / `pubspec.yaml`. **The plan contains zero open questions, zero TBD and zero "to be decided" items** — the Stage 5 gate is satisfied and Part 2 may proceed. Gates (docs-only stage): `zip_core` analyze clean + tests pass; `zip_captions` analyze clean + tests pass; `zip_broadcast` analyze clean + tests pass; tree clean after the commit.
**Approval**: approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-19) — subject to morning review
**Context**: Stage 5 (Code Generation Part 1, regenerated) COMPLETE (pre-approved, pending morning review). The superseded PROPOSED plan (2026-10-19) is replaced in place; its `window_manager`/T15/pop-out content is removed by this regeneration. Next: Stage 6 — Code Generation Part 2 (implementation, tests, l10n, the three runners, the final gates, `flutter build macos --debug`), executing this plan step by step.

---
## CONSTRUCTION - Unit 8 (External Display): Code Generation Part 2 (unattended run)
**Timestamp**: 2026-10-20T21:05:00Z
**User Input**: (none — unattended run per `.agent/overnight-pipeline.md`; the kickoff prompt constitutes the standing authorization. Vault access was prohibited this session, so orientation came from the stage handoff summaries plus the shipped source.)
**AI Response**: Executed Stage 6 of the revised run to completion: all 26 steps of `aidlc-docs/construction/plans/external-display-code-generation-plan.md`, TDD-first within each step. Delivered: `DisplayInfo` and the enumeration triplet behind the one-file `screen_retriever` fence (id normalisation, derived primary, re-read-and-diff changes); the versioned, 16 KiB-capped, never-throwing snapshot and launch codec; `OverlayWindowController` (one window at a time, 10 s ready handshake, 16 ms update coalescing, serialised open/close/fail, `resolveOpenDisplay` and the T1-T17 transitions); `CaptionOverlayTarget` reduced to a controller delegator; the sub-engine bridge triplet, entry (handler installed before `overlayReady`, drop-and-keep on a bad update) and the window app (opaque themed surface, standby/live/paused, caption position, fixed unavailable frame); `ExternalDisplayControls` with one row per display, one toggle, the position selector and the waiting/failure banners; the shell's register/open, remove/close and switch-off-on-window-loss wiring; 18 ARB keys; `main(List<String> args)` routing the overlay launch ahead of Supabase; and the three runner window-created callbacks. Tests added across 14 files (codec, resolution, frame conversion, enumeration contract, controller, state-machine properties, entry, window app, controls, shell, redaction); `zip_broadcast` went from 120 to 259 passing. Gates: `zip_broadcast` analyze clean / 259 tests; `zip_core` clean / 603 (+4 skipped); `zip_captions` clean / 139; `flutter build macos --debug` succeeded; `rg -l "package:screen_retriever"` returns exactly one path; the removed-API grep finds no match in this unit's files; `pubspec.lock` and `macos/Podfile.lock` are unchanged. Three deviations recorded in the code summary: `selectDisplay`'s method shape (the `_Selection` holder keeps the design's signature and single write path while satisfying `use_setters_to_change_properties`), the split production/test constructor on `DesktopMultiWindowService` (the design's single `@visibleForTesting` optional-parameter constructor made the production call site a lint warning), and the window app owning its own `MaterialApp` (the shipped caption widget is a Riverpod consumer and the sub-engine has no shell). One unverified area: the Windows and Linux runner callbacks follow the plugin's published signatures but neither toolchain nor the plugin's C headers are available on this machine, so their compilation is CI's check; the macOS callback is verified by the debug build. Also fixed while working: a pre-existing analyzer-clean gap surfaced by the new `withEnumerator` seam (the test call sites and four unused imports), and a widget-test zone issue in the shell suite where the display bootstrap and the settings toggle had to run through `tester.runAsync`. Artifacts: `aidlc-docs/construction/external-display/code/unit8-summary.md` and `handoff-summary.md`. **Not pushed** — the PR update, the Windows/Linux CI compile and the Unit 9 manual checks are the morning's work.
**Approval**: approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-19) — subject to morning review
**Context**: Stage 6 (Code Generation Part 2) COMPLETE (pre-approved, pending morning review). Unit 8's code generation is finished; Build and Test remains the Phase-level stage that waits for all Phase 2 units.

---
## CONSTRUCTION - Unit 8.1 (Pop-out Live Captions, S-21): Functional Design plan + questions
**Timestamp**: 2026-10-21T00:00:00Z
**User Input**: "run AI-DLC Construction for Unit 8.1 (Pop-out Live Captions, story S-21) and stop at every approval gate. Do not write production code until Code Generation Part 1's plan is approved."
**AI Response**: Started Unit 8.1 Construction on branch `feature/popout-live-captions` (off `develop` at `5e3bd3b`, no worktree, per the user's instruction). Read all required inputs before writing: `pip-ux-parity.md` §8 in full (§8.1-§8.10), the Unit 8.1 section of `phase2-unit-of-work.md`, S-21 in `phase2-stories.md`, the `window_manager` SECURITY-10 record, the Unit 8.1 rows of `phase2-unit-of-work-dependency.md` and `-story-map.md`, and `aidlc-state.md` (Current Stage, Backlog incl. the accepted macOS NSPanel limitation). Read the shipped code rather than designing from the vault: all 23 files in `packages/zip_broadcast/lib/src/output/overlay/`, `main.dart`, `ZbAppShell`, the controller provider, `OverlayWindowApp`, `ExternalDisplayControls`, `OverlayConfig`/`OverlayPosition`, all three desktop runners, `zip_core`'s `CaptionDisplayWidget`, caption bus/registry/on-screen-target providers, `RecordingState`, and the STT engine registry; plus `packages/zip_captions`'s `main.dart`, `app.dart`, `ZcAppShell` and `RecordingScreen` (it has no windowing today, confirmed). Enumerated Unit 8's 18 overlay-related test files and their helpers as the move-with-the-code safety net, and confirmed `test/helpers/pbt.dart` is byte-identical to `zip_core/test/helpers/pbt.dart`. Verified against the pub.dev API that `window_manager`'s latest is 0.5.2, that it depends on `screen_retriever: ^0.2.2` (the same constraint `zip_broadcast` already pins), and its environment floor; verified `desktop_multi_window` 0.2.1's channel name (`mixin.one/flutter_multi_window`). Contradiction check: none blocking. Two loosenesses recorded in the plan rather than resolved unilaterally — the "ready handshake" is spread across three layers (controller, bridge, io adapter) so the promotion must move all three, and `OverlayConfig`'s default mode is `ExternalDisplayMode()`, a Unit-8-specific default inside a type the pop-out must share. Wrote the Functional Design plan with 12 questions at `aidlc-docs/construction/plans/pop-out-functional-design-plan.md`. No production code, no pubspec/lockfile change, no `docs/` change.
**Approval**: awaiting human answers to the 12 questions, then Artifact generation, then explicit stage approval
**Context**: Stage 1 (Functional Design) in progress — plan and questions presented. Next: collect answers, generate FD artifacts, stop at the FD approval gate.

---
## CONSTRUCTION - Unit 8.1 (Pop-out): Functional Design questions answered + artifacts
**Timestamp**: 2026-10-21T00:30:00Z
**User Input**: Twelve answers via the question tool (Q1 A, Q2 A, Q3 A, Q4 A, Q5 A, Q6 A, Q7 A, Q8 A, Q9 "75% width, two lines, bottom of screen", Q10 B, Q11 A, Q12 A) plus one clarification answer (Q9 -> "A) Amend UX-PIP-10 to 75% width, two lines, bottom-anchored").
**AI Response**: Q9's original answer contradicted binding UX-PIP-10 (640x320) and §8.8 item 13, so it was not resolved by assumption: a clarification file was written and the owner chose Amendment A, explicitly amending `pip-ux-parity.md` §8.3 UX-PIP-10 and §8.8 item 13 to 75%-width / two-rendered-lines / bottom-anchored, resizable, minimum 320x96, decorated. The amendment itself is recorded for Documentation Refinement (it is a `docs`/aidlc-docs contract change outside Functional Design's artifact set; the unit records the decision and the FD artifacts are written against it). Generated `business-logic-model.md` (promotion inventory of 23 files, the unchanging T1-T17 table plus the four mode-conditional guards, pop-out lifecycle, the sub-engine startup order, the `popOutToggle` bridge path, `computePopOutFrame`, the `OverlayMethodRouter` resolution of the single `setMethodHandler` slot, and the test move/shape plan with its four permitted shape changes), `business-rules.md` (BR-PIP-01..14 restated against the promoted machinery, plus BR-U8.1-01..12 covering refactor preservation, the `zip_core` fence, one implementation, the router, own-engine settings, the `zip_captions` entry routing, per-app evidence, codec totality, no caption text in chrome, deferral discipline, desktop-only scope, and the Linux WM caveat), `domain-entities.md` (promoted/unchanged/additive/new inventory, the dependency placement including the finding that the apps should not declare `window_manager` since its only Dart call site is in `zip_core`, the availability matrix, ARB keys, Q9 geometry formula, deferred content setting, and the PBT-01 property list POP-1..POP-8), `frontend-components.md` (component tree in both apps, the single `CaptionDisplayWidget` change, both toggles, the banner, the availability rendering, the pop-out window body, copy inventory, deliberate absences), and `handoff-summary.md`. Three design findings worth the review's attention: (1) `DesktopMultiWindow.setMethodHandler` is a single static slot, so two controllers in one engine need a reference-counted router — passing the raw installer twice would silently break the external display; (2) `zip_core` cannot host an ARB string, so `OverlayWindowUnavailableApp` must take its copy as a parameter and `overlay_window_app_test` changes shape for that reason alone; (3) the overlay generators cannot be imported across packages' `test/` directories, so one test-helper duplication into `zip_core/test/helpers/overlay_generators.dart` is unavoidable. No production code, no pubspec or lockfile change, no `docs/` change in this stage.
**Approval**: awaiting explicit Functional Design approval
**Context**: Stage 1 (Functional Design) artifacts COMPLETE, at the approval gate. Next: NFR Requirements after approval.

---
## CONSTRUCTION - Unit 8.1 (Pop-out): Functional Design APPROVED
**Timestamp**: 2026-10-21T01:00:00Z
**User Input**: "FD is approved, do we need a fresh session for NFR?" (approval of the Functional Design stage; the question was whether NFR Requirements should start in a new session — answered: no, continue in this session, with the real boundary before Code Generation Part 2)
**AI Response**: Recorded the Functional Design approval. The three review points raised in the stage summary were accepted by the approval without amendment: (1) the UX-PIP-10 amendment ordering (unit designs against the amended geometry; `pip-ux-parity.md` itself is amended at Documentation Refinement with the owner's name and date), (2) the new `OverlayMethodRouter` as the resolution of the single `setMethodHandler` slot, (3) the per-app ~60-line `PopOutCaptionTarget` duplication alongside one shared machinery implementation. No artifact was changed. Marked Functional Design complete in `aidlc-state.md`.
**Approval**: APPROVED by the project owner, 2026-10-21
**Context**: Stage 1 COMPLETE. Next: Stage 2 — NFR Requirements (in this session).

---
## CONSTRUCTION - Unit 8.1 (Pop-out): NFR Requirements plan + questions
**Timestamp**: 2026-10-21T01:15:00Z
**User Input**: (none yet — plan presented)
**AI Response**: Wrote the NFR Requirements plan with 12 questions. Loaded the FD handoff summary first (Stage Handoff Rule 2), then the four FD artifacts. Verified every dependency and platform claim against the pub cache and the shipped pubspecs/lockfiles/runners before asking, rather than asking from memory: `window_manager` latest 0.5.2 with `^0.5.1` resolving to it, its only non-Flutter dependencies being `screen_retriever: ^0.2.2` and `path`, and a Dart/Flutter floor inside the monorepo's; `zip_broadcast` already pins `screen_retriever ^0.2.2` and `desktop_multi_window ^0.2.0` while `zip_captions` pins neither; `desktop_multi_window`'s single static `setMethodHandler` slot; macOS `Podfile.lock` contents per app; Windows `generated_plugins.cmake` per app; and the fact that **macOS's generated plugin registrant is all-or-nothing** while Windows/Linux are per-plugin. Two contradictions recorded rather than resolved: the unit definition's phrase "`RegisterGeneratedPlugins(registry:)`-equivalent registration" is not equivalent to per-plugin registration on macOS (it registers the app's whole plugin set into the sub-engine), and removing `screen_retriever` from `zip_broadcast` moves pods in two lockfiles, not one. One FD handoff question (proving `zip_captions`'s main-entry routing without initialising Supabase) is explicitly flagged as not covered by the twelve questions and deferred to a clarification file rather than assumed. No production code, no pubspec or lockfile change.
**Approval**: awaiting answers
**Context**: Stage 2 (NFR Requirements) in progress — plan and questions presented. Next: collect answers, generate NFR artifacts, stop at the gate.

---
## CONSTRUCTION - Unit 8.1 (Pop-out): NFR Requirements artifacts
**Timestamp**: 2026-10-21T02:00:00Z
**User Input**: Twelve answers, all option A (Q1 macOS full registrant / Windows-Linux per-plugin; Q2 `window_manager` in `zip_core` only and `screen_retriever` removed from `zip_broadcast`; Q3 router unit + two-controller + moved suite; Q4 assert the seam only; Q5 duplicate tests per app; Q6 accept the adapter duplication constrained by matching tests; Q7 inherit Unit 8's numbers plus two ordering targets; Q8 fail closed except always-on-top; Q9 one redaction audit per app; Q10 in-tree shim with POP-1..POP-6 and POP-8; Q11 mechanical rename/diff checks; Q12 label + semantics + visible reason), plus one clarification answer A (extract `runZipCaptions` bootstrap seam in `zip_captions` and test it).
**AI Response**: Generated `nfr-requirements.md` (testability incl. the exact four always-on-top seam assertions and the per-app evidence table mapping each claimed §8.8 item to both apps' test locations; performance inheriting Unit 8's five numbers plus the two new ordering targets; the failure table with the deliberate always-on-top asymmetry explained; the security surface with no new egress and the codec as the only decode boundary; SECURITY-01..15 compliance — 8 Compliant, 6 N/A, 1 N/A-with-Backlog-note implicit via SECURITY-14, 0 blocking; accepted limitations recorded; maintainability with the three mechanical refactor checks; usability/accessibility; scalability N/A; PBT-01..10 with the pre-existing no-shrinking limit noted as project-wide; and the deferred register), `tech-stack-decisions.md` (per-package dependency placement with the reasoning that Flutter links native plugins from the whole package graph so app declarations of `window_manager`/`screen_retriever` would be unused — the SECURITY-10 argument — plus the four-entry lockfile fence, the per-platform registration table, the macOS all-or-nothing asymmetry and why the hand-registered alternative is rejected, the test stack with no new dev dependency, and seven rejected designs with reasons), and `handoff-summary.md`. Before writing, verified that `zip_broadcast` has only `app_test.dart` at the test root (no `main`-shaped test) and that `zip_captions` has none, which is why the clarification question proposed a bootstrap seam rather than pointing at an existing pattern. No production code, no pubspec or lockfile change.
**Approval**: awaiting explicit NFR Requirements approval
**Context**: Stage 2 (NFR Requirements) artifacts COMPLETE, at the approval gate. Next: NFR Design after approval, starting from `nfr-requirements/handoff-summary.md` (three open questions: the router's provider wiring, the main-window-centre source, and the two-controller test's proof shape).

---
## Change Request - Unit 8.1 (Pop-out): Pre-build review of FD + NFR Requirements
**Timestamp**: 2026-10-21T17:30:00Z
**Request**: "unit 8.1 is fully designed and specced, I'd like you to review the spec against the project and ensure that the plan is sensible" / "you are limited to only reviewing the plans, you are not to make any code changes. Assess unit 8.1 against the existing code and ensure the plan is complete and reliable before I trigger the build in a separate session" / "write it to the correct location according to the ai-dlc process, then give me a prompt for another session to review the feedback and adjust the plan accordingly".
**Current State**: FD approved 2026-10-21; NFR Requirements artifacts plus §10 review decisions committed (`6a08033`), approval not yet recorded; NFR Design, Infrastructure Design and Code Generation Part 1 not started.
**Impact Assessment**: Read-only review against the shipped code, `desktop_multi_window` 0.2.1 (pub cache) and `window_manager` 0.5.1 (pub.dev archive) sources, and CI. Result: not ready to build. 5 blockers: (R-B1) macOS `RegisterGeneratedPlugins` in the window-created callback re-runs `FlutterMultiWindowPlugin.register(with:)`, whose `attachMainWindow` rebinds window 0 to the sub-engine; (R-B2) `window_manager.ensureInitialized` on macOS replaces the sub-window's `NSWindowDelegate`, losing `desktop_multi_window`'s close detection and engine teardown; (R-B3) the shipped runner callbacks make every sub-window borderless and cannot tell modes apart, so the Q9 "decorated, resizable" pop-out is unachievable as specified; (R-B4) zip_broadcast's shipped Windows/Linux callbacks do not match the 0.2.1 headers and `build-verify.yml` builds only zip_captions, so they were never compiled; (R-B5) no NFR Design/ID/CG plan yet, and `.agent/overnight-pipeline.md` is still Unit 8's configuration. Plus 10 majors (R-M1..R-M10) and 7 minors. FD and NFR-R need revision before NFR Design starts.
**User Confirmation**: Review requested by the user; no artifact was modified. Three owner decisions (RQ-1 window styling/always-on-top mechanism, RQ-2 engine-available source, RQ-3 OS-close detection) are posed in the review file with `[Answer]:` tags.
**Action Taken**: Wrote `aidlc-docs/construction/plans/pop-out-pre-build-review.md`. No production code, pubspec, lockfile, runner, FD or NFR-R artifact changed.
**Artifacts Affected**: `aidlc-docs/construction/plans/pop-out-pre-build-review.md` (new), `aidlc-docs/audit.md` (this entry).

---

---
## Change Request - Unit 8.1 Functional Design + NFR Requirements
**Timestamp**: 2026-10-21T04:00:00Z
**Request**: "review the spec against the project and ensure the plan is complete and reliable before I trigger the build" — pre-build review of the approved FD and the NFR-R artifacts, then amend in place.
**Current State**: CONSTRUCTION Phase 2, Unit 8.1. FD approved 2026-10-21; NFR-R complete at its approval gate. No NFR Design, Infrastructure Design or Code Generation Part 1 exists.
**Impact Assessment**: A change to a **completed** stage (`.aidlc-rule-details/common/workflow-changes.md` §4). FD and NFR-R are amended in place rather than restarted, because every finding is a defect in a specific sentence or table, not a change to the unit's scope. Dependent stages (NFR Design, ID, CG) have not started, so nothing downstream is invalidated. Scope unchanged: S-21, both apps, desktop only.
**User Confirmation**: Review requested explicitly. RQ-1 = A, RQ-2 = A, RQ-3 = A with an owner amendment (close notification raised natively in the runner, delivered to the main engine). V-1 and V-2 accepted.
**Action Taken**:
1. Re-verified all 22 findings against source before amending. All reproduced; none withdrawn. Two errors in the review's own text found and recorded (V-1: the `Failed` alias is in 1 file, not 10; V-2: `setBounds` is proposed, not shipped surface). Recorded in the review's new §3a.
2. Applied RQ-1 A: `window_manager` withdrawn. FD BLM §3.2 rewritten (mechanism, evidence, per-platform hook table, Linux handler-order finding, "verify in ID" list); `domain-entities.md` §1.2/§1.2.1/§1.4 rewritten (`WindowConfigurator` replaces `AlwaysOnTopInstaller`; `DesktopWindowService` gains nothing); BR-U8.1-02/05 rewritten; NFR-R §1.2/§3.1/§4.1/§4.3 rewritten; tech-stack §1/§2/§3/§5 rewritten.
3. Applied RQ-2 A: the engine gate is each app's own provider (R-M1). `domain-entities.md` §3.1 and BR-PIP-13 rewritten.
4. Applied RQ-3 A as amended: native close notification to the main engine (R-M6). FD BLM §3.2, BR-PIP-03, `frontend-components.md` §5, NFR-R §1.2/§3.1 updated.
5. Applied the remaining findings: R-M2 (six guards, §10.2 withdrawn), R-M3 (router by window id, token-bound installers), R-M4 (`controls` outside the list), R-M5 (shell computes the frame; chrome allowance), R-M7 (`package:zip_core/overlay.dart`), R-M8 (failure copy next to the toggle), R-M9 (one install point), R-M10 (corrected lockfile fence), R-m1..R-m7.
6. Retired `window-manager-security-10.md` in place (status banner + reversal evidence, original record preserved). Removed the `window_manager` row from `docs/04-technical-specification.md` §6 and replaced it with a note recording the withdrawal.
7. Updated both handoff summaries with a dated revision section listing constraints and verify-not-assume claims.
8. Added a Resolution line to all 22 findings in the review file.
**Artifacts Affected**: `pop-out/functional-design/{business-logic-model,business-rules,domain-entities,frontend-components,handoff-summary,window-manager-security-10}.md`; `pop-out/nfr-requirements/{nfr-requirements,tech-stack-decisions,handoff-summary}.md`; `plans/pop-out-pre-build-review.md`; `docs/04-technical-specification.md`.
**Not changed**: no production code, pubspec, lockfile, runner, CI or `.agent/` file. No commit made (design-revision session).
**Approval**: awaiting explicit approval of the revised FD and NFR-R.
**Context**: Stop at the approval gate. Still open: R-B4's Unit 8 fix, the `.agent/overnight-pipeline.md` rewrite, the stale `aidlc-state.md` current-stage line, and NFR Design onward.

---
## Change Request - Unit 8.1 Functional Design + NFR Requirements (revision 2)
**Timestamp**: 2026-10-21T05:30:00Z
**Request**: Owner requested changes to the revision: (1) the `popOutClosed` transport is impossible as specified; (2) the router API is unpinnable as specified; (3) three smaller corrections.
**Current State**: CONSTRUCTION Phase 2, Unit 8.1. FD and NFR-R revised at their approval gate (revision 1, unapproved). No NFR Design, Infrastructure Design or CG Part 1 exists.
**Impact Assessment**: Same stage, same scope; corrections to revision-1 text, not new findings. No downstream stage to invalidate.
**User Confirmation**: Explicit request-changes with the required resolution for each item.
**Action Taken**:
1. Verified all three claims against source: `desktop_multi_window` macOS `WindowChannel` is not `public` (`WindowChannel.swift:14`) and Windows/Linux expose only `include/desktop_multi_window/desktop_multi_window_plugin.h`; the Dart API has no emit path; `_handlerInstaller?.call(_handleWindowCall)` runs in `_bootstrap` (`overlay_window_controller.dart:191`); `_takeWindow()` nulls `_windowId` and `_modeDisplayId` (`:528-533`, called at `:501`, `:552`, `:560`, `:683`).
2. Re-specified the close transport: first-party per-app channel on the **main** engine, `subWindowClosed {windowId}`; `zip_core` `SubWindowClosedChannel` seam (`_io`/`_stub`, fake) feeding `controller.onNativeWindowClosed(int)`; raised for every sub-window including the external display, recorded as a Unit 8 improvement; app-initiated closes dropped by the id check. Removed the claim that it flows through `OverlayMethodRouter`/`_handleWindowCall`. Updated BLM §3.2, BR-PIP-03, NFR-R §1.2/§3.1, both handoffs.
3. Pinned the router API: `int? get windowId` as a permitted deviation, installer at bootstrap unchanged, "registration after `createWindow`" deleted, null never matches. Permitted deviations are now a numbered seven-item list.
4. Pinned `ExternalDisplayMode` → `configure(floating: false, decorated: false)` and recorded Unit 8's borderless surface as dependent on `configure` succeeding. Added the fifth permitted test-shape reason (inject a `WindowConfigurator` fake) to BLM §7. Fixed the garbled macOS row in BLM §3.2.
5. Added follow-up notes to the R-M3 and R-M6 Resolution lines in the review file.
**Artifacts Affected**: `pop-out/functional-design/{business-logic-model,business-rules,handoff-summary}.md`; `pop-out/nfr-requirements/{nfr-requirements,handoff-summary}.md`; `plans/pop-out-pre-build-review.md`.
**Not changed**: no production code, pubspec, lockfile, runner, CI or `.agent/` file. No commit made.
**Approval**: awaiting explicit approval of the revised FD and NFR-R.
**Context**: Stop at the approval gate again. Still open: R-B4's Unit 8 fix, the `.agent/overnight-pipeline.md` rewrite, the stale `aidlc-state.md` current-stage line, R-m6's SDK question, and NFR Design onward.

---
## APPROVAL - Unit 8.1 Functional Design + NFR Requirements
**Timestamp**: 2026-10-21T06:15:00Z
**Approved by**: James Petersen
**Scope**: The Functional Design and NFR Requirements, including the two revision rounds made after the pre-build review (RQ-1 A / RQ-2 A / RQ-3 A-amended; revision 2 same day) and the retirement of the SECURITY-10 `window_manager` record with the `docs/04-technical-specification.md` §6 row removed.
**Baseline approved**: `aidlc-docs/construction/pop-out/functional-design/` (BLM, business rules, domain entities, frontend components, handoff) and `aidlc-docs/construction/pop-out/nfr-requirements/` (NFR-R incl. §10.1-10.5, tech-stack decisions, handoff).
**Pre-build review**: `aidlc-docs/construction/plans/pop-out-pre-build-review.md` — 5 blockers, 10 major gaps, 7 minor items; all 22 independently re-verified and reproduced; V-1/V-2 corrections to the review's own text recorded; every finding carries a Resolution line. R-B4 and R-B5 remain open by design (Unit 8's defect on `develop`, and the downstream stages that have not started).
**Action Taken**: artifact status lines set to APPROVED in all six artifacts; both handoff summaries gained an "APPROVED — 2026-10-21" section naming the next stage (NFR Design, NOT STARTED) and the open item; `aidlc-state.md` Unit 8.1 entry gained the two approved-stage sub-items and a pending NFR Design sub-item, the authoritative current-stage line was rewritten (this fixes the stale line that read "next stage is NFR Requirements"), and the file's header current-stage line — stale since Unit 2 — was aligned so the two do not contradict.
**Carried into NFR Design as an open item**: the `SubWindowClosedChannel` registration order — where the main-engine seam's channel handler is registered relative to `WidgetsFlutterBinding.ensureInitialized()` and the app's startup work, its lifetime owner, its `dispose()` with the container, and that it is listening before any sub-window can be created.
**Not done**: NFR Design not started. No commit. No production code, pubspec, lockfile, runner, CI or `.agent/` file touched.
**Context**: Stage gate cleared. NFR Design is the next stage and requires an explicit instruction to begin.

---
## CONSTRUCTION - Unit 8.1 (Pop-out Live Captions): NFR Design
**Timestamp**: 2026-10-21T00:00:00Z
**User Input**: "NFR Design: Approved. Record approval in audit.md (approved by James Petersen, 2026-10-21), set the three artifacts and the handoff to APPROVED, and update the Unit 8.1 entry and the current-stage line in aidlc-state.md (next: Infrastructure Design, not started). ... Do not start Infrastructure Design."
**AI Response**: NFR Design for Unit 8.1 is **approved**. Ten design questions were answered by the owner (D1 corrected to option B, then R1, P1-P3, L1-L5 all A except L5 "Other") and recorded verbatim with their consequences in `aidlc-docs/construction/plans/pop-out-nfr-design-questions.md`. Substance: the host owns the `SubWindowClosedChannel`, the `OverlayMethodRouter` and the single display enumerator, and constructs each controller through `createController({mode, logPrefix})`; each controller subscribes to the process-level `Stream<int> get closed` in its own `_bootstrap`, **before** the ready handshake, so the carried-in "listening before any sub-window can be created" question is answered by construction rather than by startup ordering (nothing registered in `main()`, nothing in the sub-engine, no `ProviderContainer`). `windowId` tags the close event only, with no mismatch check, because a controller is already mode-specific. `zip_captions` gains a `keepAlive Notifier<bool>` while its shell still becomes a `ConsumerStatefulWidget` for the target and the events subscription. The close path logs one fixed string at `FINE`; chrome constants are recorded as estimates, unverified until Unit 9, with Linux varying by desktop/theme.
**Review round 2 correction**: the first draft required `dispose()` to stop disposing the display enumerator. That was wrong against the moved suite — `overlay_window_controller_test.dart:721-749` asserts `harness.enumerator.isDisposed` is `true` at `:736` and `:749`. The design was corrected so **`dispose()` is byte-for-byte unchanged**, and no eighth controller deviation is introduced: the host hands each controller a reference-counted `DisplayEnumeratorLease` (delegating `displays`/`changes`/`primarySize`; last release or `host.dispose()` disposes the real enumerator; release is idempotent), and `:708`'s `_handlerInstaller?.call(null)` already resolves to `unregister(token)` through `router.installerFor`. Four lease unit tests became part of the test obligations (last release disposes; an earlier release does not; double release is a no-op; `host.dispose()` disposes regardless). The moved test needs no harness change, because `_Harness` passes one `FakeDisplayEnumerator` directly to the controller (`:126-143`), so the assertion still observes the object the controller destroyed.
**Artefacts**: `aidlc-docs/construction/pop-out/nfr-design/nfr-design-patterns.md`, `logical-components.md`, `handoff-summary.md` (all stamped APPROVED 2026-10-21 by James Petersen); plan and questions at `aidlc-docs/construction/plans/pop-out-nfr-design-plan.md` and `pop-out-nfr-design-questions.md`. Open documentation corrections handed to Documentation Refinement, not edited at this stage: FD `domain-entities.md` §2.2's `ZcAppShell` row conflates the flag with statefulness; FD `handoff-summary.md` still lists `window_manager`; `tech-stack-decisions.md` §2 omits that the runners also register the close channel on the main messenger.
**Approval**: approved by: James Petersen, 2026-10-21
**Context**: Branch `feature/popout-live-captions`. `aidlc-state.md` updated (Unit 8.1 entry, current-stage line at the top and in the Current Stage section): **next stage Infrastructure Design, NOT STARTED** per the explicit instruction not to begin it.

---
## CONSTRUCTION - Unit 8 (External Display): R-B4 defect fix (runner callback signatures + CI coverage)
**Timestamp**: 2026-10-21T00:00:00Z
**User Input**: "AI-DLC CONSTRUCTION, Unit 8.1 (Pop-out Live Captions, S-21). ... STEP 2 — Fix R-B4 (a Unit 8 defect) on its own branch off develop. ... Fix packages/zip_broadcast/windows/runner/flutter_window.cpp and packages/zip_broadcast/linux/runner/my_application.cc so that the window-created callback matches desktop_multi_window 0.2.1's real one-argument signatures ... Behaviour must stay exactly as shipped: same borderless styling, applied unconditionally. Unit 8.1's mode-aware configure channel (RQ-1 A) replaces these callbacks later. Do NOT build it here. .github/workflows/build-verify.yml ... Add zip_broadcast builds for macOS, Windows and Linux ... You cannot compile Windows or Linux locally. Say so; do not claim them verified."
**AI Response**: Executed remediation step 0 of `pop-out-pre-build-review.md` (R-B4) on branch `fix/zip-broadcast-runner-callbacks` (off `develop` at `5e3bd3b`). **Verified against the plugin sources before editing** (not against documentation): `windows/include/desktop_multi_window/desktop_multi_window_plugin.h` declares `typedef void (*WindowCreatedCallback)(void *flutter_view_controller);` with a one-argument `DesktopMultiWindowSetWindowCreatedCallback(WindowCreatedCallback)`; the plugin invokes it as `_g_window_created_callback(flutter_controller_.get())` (`windows/flutter_window.cc:116-117`), a `flutter::FlutterViewController*`. `linux/include/desktop_multi_window/desktop_multi_window_plugin.h` declares `typedef void (*WindowCreatedCallback)(FlPluginRegistry *registry);` with a one-argument setter; the plugin invokes it as `_g_window_created_callback(FL_PLUGIN_REGISTRY(fl_view))` (`linux/flutter_window.cc:52-53`) — the **sub-window's own** registry, not the main view's, which is why the shipped two-argument call could never have compiled. Both examples confirmed the intended shape (`example/windows/runner/flutter_window.cpp:32-38`, a cast of the `void*` to `flutter::FlutterViewController*`; `example/linux/my_application.cc:65-69`, a `FlPluginRegistry*` parameter). Fixes: Windows now registers a one-argument lambda taking `void*`, casting it to `flutter::FlutterViewController*` and reading `view()->GetNativeWindow()` instead of the preprocessor macro `FlutterDesktopViewControllerGetView`; the styling body (`GetAncestor(..., GA_ROOT)`, `GWL_STYLE` minus `WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU`, `SetWindowPos(..., SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED)`) is unchanged. Linux now registers a one-argument lambda taking `FlPluginRegistry*`, recovering the view with `FL_VIEW(registry)` — the mirror of the plugin's own `FL_PLUGIN_REGISTRY(fl_view)` wrap at `linux/flutter_window.cc:53`, and the only SDK cast in the file — then `gtk_window_set_decorated(toplevel, FALSE)` as before. Behaviour is identical and still applied unconditionally to every sub-window: no mode check, no `configure` channel, no `window_manager` (that is Unit 8.1's RQ-1 A work, deliberately not started here). CI: `.github/workflows/build-verify.yml` gains zip_broadcast desktop coverage; as first authored it was three jobs (`build-macos-zip-broadcast`, `build-linux-zip-broadcast`, `build-windows-zip-broadcast`), later folded into the existing `build-macos`/`build-linux`/`build-windows` jobs as a `package: [zip_captions, zip_broadcast]` matrix (see the agentic-review entry below), each entry mirroring its `zip_captions` counterpart (same `workflow_dispatch`/PR triggers via the existing `paths` filter, same checkout / Flutter setup / pub-cache restore pattern) with `working-directory: packages/zip_broadcast`; the Linux job installs the same `ninja-build libgtk-3-dev libsecret-1-dev` set. Every action version stays pinned (verified: the only `uses:` refs in the file are `actions/checkout@v6.0.2`, `subosito/flutter-action@v2.23.0`, `actions/cache@v5.0.4`, `actions/setup-java@v5.2.0`; no new action and no unpinned reference — SECURITY-10).
**Verification**: `cd packages/zip_broadcast && dart analyze --fatal-infos` — no issues; `flutter test` — 271 passing; `flutter build macos --debug` — succeeded (`build/macos/Build/Products/Debug/zip_broadcast.app`). **Not compiled locally**: the Windows and Linux runner changes. Neither toolchain nor the plugin's C headers are available on this macOS machine, so their compilation rests on the new CI jobs. **Verified by CI** on branch head `54328f9` (run `39654376626`): `macOS (zip_broadcast)` pass (4m52s), `Windows (zip_broadcast)` pass (6m47s), `Linux (zip_broadcast)` pass (2m16s). No lockfile or pubspec movement at this commit; the `desktop_multi_window` pin was later tightened to `^0.2.1` in the review-fix entry below.
**Approval**: approved by: owner instruction to fix in PR #40 and open it (2026-10-21); pushed to `fix/zip-broadcast-runner-callbacks`.
**Context**: R-B4 remediation COMPLETE and **pushed**; PR #40 open against `develop` (not merged). Windows/Linux compilation confirmed green by CI on `54328f9`.

---
## CONSTRUCTION - Unit 8 (External Display): R-B4 defect fix, follow-up (Windows runner)
**Timestamp**: 2026-10-21T00:00:00Z
**User Input**: "Windows main.cpp: fix it in PR #40, not as a separate unit fix. ... copy the example's SendAppLinkToInstance(const std::wstring& title) helper into packages/zip_broadcast/windows/runner/main.cpp above wWinMain, verbatim, including the optional restore block; change the call at line 14 to SendAppLinkToInstance(L\"zip_broadcast\") ... add an audit.md entry: a Unit 2 / SR-01 §3 defect, never compiled because CI did not build zip_broadcast. Record the residual risk ... Accepted as the plugin's documented pattern."
**AI Response**: Fixed a **Unit 2 / SR-01 §3 defect**, exposed only when CI began compiling `zip_broadcast` on Windows (this unit's R-B4 fix added those jobs). **Root cause, verified against plugin and app source, not assumed**: `packages/zip_broadcast/windows/runner/main.cpp` included `app_links/app_links_plugin_c_api.h` and called `SendAppLinkToInstance()` — but that function is **not** part of the plugin's C API. `app_links` 7.0.0's header declares exactly two symbols, `AppLinksPluginCApiRegisterWithRegistrar` and `SendAppLink(HWND hwnd)`; `SendAppLinkToInstance` is a helper the plugin's **own example** defines in its runner (`~/.pub-cache/hosted/pub.dev/app_links-7.0.0/example/windows/runner/main.cpp:9-42`), finding the already-running instance with `FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", title)` and passing that `HWND` to `SendAppLink`. Unit 2's shipped commit (`6a757fd`, PR #22) copied the call but not the helper, so the runner never compiled; nothing caught it because `.github/workflows/build-verify.yml` built only `packages/zip_captions` in every job (R-B4), and `zip_captions` never had this call. Fix: the example's `SendAppLinkToInstance(const std::wstring& title)` copied **verbatim** (byte-identical to the example, 34 lines, including the optional restore-to-front block) above `wWinMain`, and the call changed to `SendAppLinkToInstance(L"zip_broadcast")`. The title matches `window.Create(L"zip_broadcast", …)` (`main.cpp:73`) and the class name `kWindowClassName = L"FLUTTER_RUNNER_WIN32_WINDOW"` (`win32_window.cpp:19`), so `FindWindow` addresses this app's own main window. Behaviour is the plugin's documented single-instance forwarding: a second launch via `io.zipcaptions.broadcast://` forwards the link to the running instance and exits.
**Residual risk (accepted, owner 2026-10-21)**: `FindWindow` matches by class name and title, both of which any process can copy. A hostile window presenting both could therefore receive a forwarded custom-scheme URL before the legitimate instance does. Why it is accepted rather than defended: the forwarded value is a **one-shot PKCE authorization code**, useless without the code verifier that never leaves the originating process — confirmed by `supabase_auth_service.dart`'s own note that the service "never races the SDK's own one-shot PKCE code consumption" (the `detectSessionInUri` path performs the exchange in-process, PKCE-verified). Additionally the scheme is OS-registered to this application, so an attacker already needs local code execution to compete for it. This is the plugin's own documented pattern, and it is recorded here rather than silently inherited. Revisit only if app_links ships an inter-process channel that removes `FindWindow` from the path.
**Verification**: CI is the only Windows compiler available. `permission_handler_windows`' MSVC C2338 failure was fixed first in this same PR by copying `zip_captions`' existing `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` block into `zip_broadcast`'s `windows/CMakeLists.txt` (commit `2f77cf2`); after that, this `C3861` was the first error in our own runner code. Result of the fix is the `Windows (zip_broadcast)` job on this PR. No lockfile, pubspec, Dart or test change.
**Approval**: approved by: James Petersen, 2026-10-21 (instruction to fix in PR #40 and to record this defect and its residual risk)
**Context**: PR #40 (`fix/zip-broadcast-runner-callbacks` → `develop`), **not merged**. Next: report the Windows job; if anything else fails, stop and report the first error.

---
## CONSTRUCTION - Unit 8 (External Display): R-B4 defect fix — agentic code review follow-up
**Timestamp**: 2026-10-22T00:00:00Z
**User Input**: "post findings then fix all of them, we have to ensure the documentation is accurate."
**AI Response**: Ran the `agentic-code-review` skill on PR #40 with two parallel reviewers (native/plugin/CI correctness; tests/design/maintainability), each grounded in docs-mcp (`desktop_multi_window`, `flutter_api`, `github actions`, `code-review-guide`) and the vendored `desktop_multi_window` 0.2.1 sources. Consolidated report posted to the PR (comment 6342215100): approve-with-nits, no blockers, all gates green (`dart analyze --fatal-infos`, 271 tests, `flutter build macos --debug`, all three `zip_broadcast` CI jobs). Both reviewers independently confirmed the callback typedefs and that `FL_VIEW(registry)` inverts the plugin's `FL_PLUGIN_REGISTRY(fl_view)`. All seven findings were then fixed on `fix/zip-broadcast-runner-callbacks`: (1, major) the first R-B4 audit entry said "not pushed / approval pending / Windows+Linux unverified" while the PR was open and green — corrected above to the pushed, CI-verified state; (2) the `windows/CMakeLists.txt` coroutine comment wrongly named `<experimental/coroutine>` — reworded to the actual C++/WinRT awaiter cause; (3) added null guards to both runner window-created callbacks; (4) tightened `desktop_multi_window` from `^0.2.0` to `^0.2.1` with a comment tying the pin to the callback contract; (5) documented the accepted `FindWindow` spoofing risk at the `SendAppLinkToInstance` definition rather than only in this log; (6) replaced the three duplicated `zip_broadcast` CI jobs with a `package: [zip_captions, zip_broadcast]` matrix on the existing macOS/Linux/Windows jobs, and updated the stale job-name description in the entry above; (7) removed the stray blank line in `windows/CMakeLists.txt`. Gate impact: `dart analyze --fatal-infos` and `flutter test` (271) re-run clean after the changes; the tightened pin resolves to the already-locked 0.2.1, so no lockfile movement. The C++ edits and the CI matrix are compile-verified only by CI (Windows/Linux unavailable locally).
**Approval**: approved by: James Petersen, 2026-10-22 (instruction to fix all review findings and keep the documentation accurate)
**Context**: PR #40 (`fix/zip-broadcast-runner-callbacks` -> `develop`), open, not merged. Build and Test is a Phase-level stage and remains pending until every Phase 2 unit is complete (see `aidlc-state.md` Current Stage); this PR does not close it.

---
## CONSTRUCTION - Unit 8.1 (Pop-out Live Captions): Infrastructure Design
**Timestamp**: 2026-10-21T00:00:00Z
**User Input**: "STAGE 1 — Infrastructure Design" under the UNATTENDED run configuration (`.agent/overnight-pipeline.md`), which authorises the stage gate on the human's behalf subject to morning review; A1 stage 1 adapts the stage to a documentation/design unit, A7 carries the standing decisions.
**AI Response**: Infrastructure Design COMPLETE. Artifacts: `aidlc-docs/construction/pop-out/infrastructure-design/infrastructure-design.md` (14 sections) and `handoff-summary.md` (31 lines); plan at `aidlc-docs/construction/plans/pop-out-infrastructure-design-plan.md` (Steps 1-10 executed, no questions asked — see its "why none were asked" table). No `deployment-architecture.md`, matching the `external-display` precedent: this unit has no server, container, IAM or CI change.
**The six verify-not-assume items, settled against plugin source (not documentation)**:
1. A Dart message from the sub-engine at close time **is lost** — every backend destroys the engine in the same handler (`macos/Classes/FlutterWindow.swift:91-105`, `windows/flutter_window.cc:164-179`, `linux/flutter_window.cc:35-41`) — and the plugin's window channel is not usable by a runner (`WindowChannel.swift:14` is not `public`; Windows/Linux expose only the C header). The design's first-party main-engine channel rests on a true premise.
2. macOS: `NSWindow.willCloseNotification` reaches our observer during the same post that runs the plugin's delegate, i.e. **before** `deinit` frees the window (`FlutterWindow.swift:85,102-110` → `MultiWindowManager.swift:123-125`); the observer is additive, nothing replaces `window.delegate` (R-B2).
3. Windows: `PluginRegistrarWindows`' top-level-proc delegate runs **inside** `HandleTopLevelWindowProc` (`windows/flutter_window.cc:150-153`), so it sees `WM_CLOSE` before the plugin's own branch (`:174-179`) and before `WM_DESTROY` destroys the engine (`:164-173`); the delegate returns `nullopt` so the plugin still closes.
4. Linux: the plugin's `delete-event` handler returns `TRUE` while calling `gtk_widget_destroy` (`linux/flutter_window.cc:16-19`), which aborts the signal — so neither `g_signal_connect` nor `g_signal_connect_after` on `delete-event` would ever run. **`"destroy"` is connectable** and runs on every destroy path, exactly as the plugin's own handler does (`:35-41`). **The `'-1'` Linux degradation is therefore NOT triggered**, and A1's conditional does not fire; `'-1'` stays the generic fallback only.
5. The six runners' callbacks match 0.2.1's one-argument typedefs (`macos/Classes/FlutterMultiWindowPlugin.swift:25-30`; `windows/include/desktop_multi_window/desktop_multi_window_plugin.h:20`; `linux/include/desktop_multi_window/desktop_multi_window_plugin.h:24`), and `argv` reaches the sub-engine as `["multi_window", id, payload]` on all three (`FlutterWindow.swift:73`, `windows/flutter_window.cc:100`, `linux/flutter_window.cc:45-46`). `zip_captions` has no callback on any platform.
6. Flutter 3.41.7 local vs 3.38.7 CI (`.github/workflows/build-verify.yml:27`); every Dart/native API this unit uses exists in both. `flutter_windows.h` is not on this macOS host — Windows evidence is the plugin's call site, and CI compilation is the check.
**Design decisions recorded**: ID-1 `runZipCaptions(args, {runApp, isWeb})` is the authoritative `zip_captions` routing seam (`main` delegates in one line; overlay branch returns before GoogleFonts/logging/SharedPreferences/Supabase/`ProviderContainer`; `zip_broadcast` deliberately keeps its inline branch). ID-2 two channels by direction — `zip_core/overlay_window_configure` on the sub-engine's messenger, `zip_core/overlay_sub_window_events` on the main engine's. ID-3 a native per-runner handle→`windowId` map written by `configure` and read by the close hook (macOS `NSWindow`+notification, Windows `HWND`+proc delegate, Linux `GtkWindow*`+`"destroy"`), never a sub-engine Dart message. ID-4 the registrant fence. ID-5 the dependency delta.
**Corrections applied in place, each logged here as the record**:
- **`zip_broadcast`'s registrants DO move.** A1 item 3 asserts no movement there; the tracked files contradict it. `zip_broadcast/macos/Flutter/GeneratedPluginRegistrant.swift:14`, `zip_broadcast/windows/flutter/generated_plugin_registrant.cc:15`, `generated_plugins.cmake:12`, `zip_broadcast/linux/flutter/generated_plugin_registrant.cc:14,34-36`, `generated_plugins.cmake:11` all carry `screen_retriever_*` today, and A5 removes the app's own declaration, so they **lose** it. `zip_captions` **gains** `desktop_multi_window` and `screen_retriever_*` on all three. Exact per-file table in §6 of the design doc.
- **`tech-stack-decisions.md` §3** — "Generated, not committed" corrected to "Tracked, not generated-only" (`git ls-files` confirms all ten files), with the real movement described.
- **`tech-stack-decisions.md` §4** — `fake_async` "already a dev dependency of all three packages" was **false**: `packages/zip_captions/pubspec.yaml` has neither `fake_async` nor `mocktail` (they exist in `zip_core` `:66`/`:72` and `zip_broadcast` `:64`/`:70`). Corrected, with the consequence for where timing tests live.
- **`^0.2.0` → `^0.2.1`** for `desktop_multi_window` in `functional-design/domain-entities.md` §1.4 and §2.2 (two rows) and `nfr-requirements/tech-stack-decisions.md` §1 (three rows) and §6 — matching PR #40's shipped pin, which is the constraint floor.
- **`functional-design/handoff-summary.md`** Constraint line 2 — the stale "`zip_core` gains … `window_manager`" sentence (already noted by NFR Design) replaced with the approved dependency set and the true native-change scope.
- **`functional-design/domain-entities.md`** `main(List<String> args)` row — now names `runZipCaptions` as the seam, consistent with ID-1.
**Not done**: no production code, no `pubspec.yaml`, no lockfile, no runner, no CI, no `.agent/` file, no `question` call. No push.
**Verification**: docs-only change; the three gate pairs (`dart analyze --fatal-infos`, `flutter test` in `zip_core`, `zip_broadcast`, `zip_captions`) were run and remain green; `git status --short` shows only the standing ` M opencode.json` plus this unit's committed files.
**Approval**: approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-21) — subject to morning review
**Context**: Branch `feature/popout-live-captions`. Next stage: Code Generation (Part 1 — implementation plan), NOT STARTED.

---
## CONSTRUCTION - Unit 8.1 (Pop-out Live Captions): Code Generation Part 1 (Implementation Plan)
**Timestamp**: 2026-10-22T21:20:00Z
**User Input**: "STAGE 2 BUILD — code generation part 1 plan" under the UNATTENDED run configuration (`.agent/overnight-pipeline.md`, 2026-10-21), which authorises the stage gate on the human's behalf subject to morning review. A1 stage 2 adapts the stage to a plan-only unit; A7 carries the standing decisions.
**AI Response**: Code Generation Part 1 COMPLETE. One artifact: `aidlc-docs/construction/plans/pop-out-code-generation-plan.md` (904 lines). No production code, no `pubspec.yaml`, no lockfile, no runner, no generated file, no `question` call, no push. Plan contents: §0 what was re-read and re-verified against the shipped tree; §1 unit context (story/scope, the exact dependency delta, the lockfile and registrant fence, seven assumptions carried from the binding stages, no new questions); §2 the file table (C01-C42 `zip_core` production, M01-M11 the moved files that carry an approved additive change, T01-T34 `zip_core` tests, B01-B35 `zip_broadcast`, Z01-Z26 `zip_captions`, and §2.6 the counts); §3 the test list (the moved suite, N-01..N-14, and the POP-1..POP-8 placement); §4 the five permitted test-shape changes of FD BLM §7 mapped to steps and tests, the byte-for-byte-unchanged `dispose()` fence, the commit ordering, the router/host/lease wiring, and the `git diff -M` R100 proof command; §5 strings; §6 thirty numbered TDD-first steps in Groups A-G; §6b the hard non-goal fences; §7 gates and the eight Unit 9 manual checks; §8 the self-check tables; §9 the handoff to Part 2.
**Shape of the work (30 steps)**: 1-10 bring the contracts into `zip_core` (dependencies, `OverlayWindowConfig`, duplicated overlay generators, `OverlayMethodRouter` + `OverlayHandlerToken`, `DisplayEnumeratorLease`, the `SubWindowClosedChannel` triplet, the `WindowConfigurator` triplet, `pop_out_geometry.dart`, `pop_out_availability.dart`, the `overlay.dart` barrel). 11 the `git mv` promotion of the 23 production files + 13 test files + `fake_display_enumerator.dart` + the two `.freezed.dart` files, with the R100 proof. 12 the three decoupling shape changes. 13 the seven permitted controller deviations (FD BLM §4.1's complete list: the six `_isPopOut` guards, the `'popOutToggle'` case, `open({Rect? frame})`, mode fixed at construction, the token-bound installer, `int? get windowId`, `onNativeWindowClosed(int)`), with `dispose()` byte-for-byte unchanged. 14-18 `PopOutMode` and the codec token, `PopOutWindowBody` and `CaptionDisplayWidget.controls`, the host and its provider, the display-less bootstrap, the fence test. 19-23 `zip_broadcast`. 24-27 `zip_captions` including the `runZipCaptions` seam. 28-29 the six runners. 30 the gates, the three fence greps, the move proof, the lockfile review and the compile checks.
**Dependency delta written into the plan (A5/A7)**: `zip_core` ADDS `desktop_multi_window ^0.2.1` and `screen_retriever ^0.2.2` (each carrying a SECURITY-10 comment); `zip_broadcast` REMOVES `screen_retriever` only; `zip_captions` ADDS `desktop_multi_window ^0.2.1` only. `window_manager` is never added (RQ-1 A); the plan's §6b fence and step 30's grep both assert its absence.
**Corrections made to the plan by the agent before handoff** (self-check, not a design change): the section numbering had a duplicate `## 5a`/`## 6` pair after the steps section, now uniquely numbered (`6a`, `6b`); §3.3's "Step" column was stale relative to the actual 30 steps and has been remapped (POP-1 14, POP-2/3/8 11, POP-4 8, POP-5 11+13, POP-6 14, POP-7 9); POP-7's domain is stated as 70 cells (7x5x2); `§2.6`'s counts were recomputed from the table rows and now reconcile to the row total (148 rows = 62 created + 40 moved + 31 modified + 3 delete rows + 1 cross-reference + 11 §2.2 M rows), replacing four cells that were wrong; step 11 said "14 test files" where 13 are test files plus one helper (`fake_display_enumerator.dart`); and the R100 split is corrected to **10** production files required R100 and **13** allowed a diff (the previous text listed `desktop_multi_window_service_stub` as both R100 and not, and said 11/13). N-14 and T34 are the same file and the plan now says so explicitly.
**Deviations recorded for morning review** (plan §8.6): (1) `CaptionPosition` moves to `zip_core` — FD BLM §1 says it "stays", read here as "not a pop-out concern", with the wording flagged for correction; (2) `PopOutGeometry.toggleRowHeight = 44`; (3) the `OverlayWindowHost` path and provider placement; (4) the new `OverlayEvent` variant `PopOutToggled()`, whose only exhaustive switch is `zb_app_shell.dart`'s `_onOverlayEvent`.
**State-file correction**: `aidlc-state.md`'s Unit 8.1 narrative (written 2026-10-20) still described `window_manager` as required and approved, which RQ-1 A superseded on 2026-10-21. Rather than rewrite historical design narrative, a "Known stale prose" note was added under **Current Stage** naming the supersession, its source, and the fact that every construction artifact and the plan follow RQ-1 A.
**Not done**: no production code, no `pubspec.yaml`, no lockfile, no runner, no generated file, no device/emulator/`flutter run`/`flutter build`/`flutter gen-l10n`, no `.agent/` edit, no `question` call, no push, and no edit of the standing ` M opencode.json`.
**Verification**: docs-only change. The three gate pairs were run from the package roots: `dart analyze --fatal-infos` clean in `zip_core`, `zip_broadcast` and `zip_captions`; `flutter test` green with `zip_core` 603 passed / 4 skipped, `zip_broadcast` 271 passed, `zip_captions` 139 passed. `git status --short` shows only the standing ` M opencode.json` plus this unit's new plan file.
**Approval**: approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-21) — subject to morning review
**Context**: Branch `feature/popout-live-captions`, head `e5acc20`. Next stage: Code Generation Part 2 (tests first, then implementation), NOT STARTED.

---
## CONSTRUCTION - Unit 8.1 (Pop-out Live Captions): Code Generation Part 2 (implementation)
**Timestamp**: 2026-10-23T03:10:00Z
**User Input**: "STAGE 3 BUILD — code generation part 2" under the UNATTENDED run configuration (`.agent/overnight-pipeline.md`, 2026-10-21), which authorises the stage gate on the human's behalf subject to morning review. A1 stage 3; A5 and A7 carry the standing decisions.
**AI Response**: Code Generation Part 2 COMPLETE for plan steps 1-30. Sixteen commits on `feature/popout-live-captions`, not pushed: the contracts (1-10), the promotion of the Unit 8 machinery into `zip_core` (`465cad7`, BR-U8.1-01), the broadcast readers and the seven controller deviations (`d1cf311`), then `zip_broadcast`'s pop-out (`5474ff9` ARB, `20f080f` providers, `a9c7681` target, `2e9a7be` controls/banner, `5137551` shell/rail/screen) and `zip_captions`' (`f23453b` `runZipCaptions`, `704b10d` target/controls/banner/strings, `03b1622` shell/rail/screen/viewer/strings). The six runners (steps 28-29) are written and macOS-compiled; their working-tree change is handed to the orchestrator to commit with this document. Deliverables: `aidlc-docs/construction/pop-out/code/summary.md` (what exists, the per-app §8.8 evidence table, the gate results, the Unit 9 manual list) and `code/handoff-summary.md`.
**Tests written (TDD-first per step)**: `zip_core` N-06, N-10, N-11, N-12, N-13, the host test, the display-less bootstrap case, the fence test and the extended external-display status/entry tests; `zip_broadcast` B30 (`pop_out_shell_test.dart`), B31 (`pop_out_controls_test.dart`), B32 (`pop_out_banner_test.dart`), B33 (`test/output/overlay/pop_out_caption_target_test.dart`) and a harness-level fake pop-out controller; `zip_captions` Z20 (`test/bootstrap_test.dart`), Z21 (`test/output/overlay/pop_out_caption_target_test.dart`), Z22, Z23, Z24 (`test/widgets/pop_out_shell_test.dart`), Z25 (`test/widgets/pop_out_redaction_test.dart`) and Z26 (a `viewer_screen_test.dart` case asserting `controls: null`). Three existing captions suites gained the `zcStringsProvider` and pop-out-controller overrides the stateful shell now needs.
**Gates (all green, run from the package roots)**: `dart analyze --fatal-infos lib test` clean in `zip_core`, `zip_broadcast`, `zip_captions`; `flutter test` `zip_core` 914 passed / 4 skipped, `zip_broadcast` 177 passed, `zip_captions` 174 passed; `flutter build macos --debug` built both apps. Fence greps: no `package:desktop_multi_window`/`package:screen_retriever` import in either app's `lib/`; `window_manager` absent from all three packages (only the fence test names it, plus GTK's own `get_window_manager_name`); `zip_core.dart` does not export `overlay.dart` (R-M7). Windows and Linux compile in CI only — nothing claims their runtime behaviour.
**Seven recorded departures from the approved design's letter** (full reasons in `code/summary.md`): (1) the chrome toggle's disabled reason is `Semantics(hint:)`, not visible text beneath the control — the visible form overflows the narrow `AppBar` by 8 px and its `actions` by 319 px on a 375x812 surface; (2) `PopOutInSurfaceToggle` in the main window is always enabled, because gating the only entry point on the flag that the toggle itself sets would disable it permanently; (3) the captions shell renders the routed child until `zcStringsProvider` resolves, so the copy is non-null in `PopOutScope`; (4) both apps gained a `PopOutScope` `InheritedWidget` carrying the flag, the toggle and the copy, which keeps shell state out of the container (Q10 B); (5) `zip_captions` gained `displayListProvider`; (6) the captions target and redaction tests use real short delays instead of `fakeAsync`, because that app has no `fake_async` dev dependency and A7 forbids adding one; (7) Windows/Linux runners are CI-compiled only.
**Dependency and lockfile delta (A5/A7 honoured)**: `zip_core` `+desktop_multi_window ^0.2.1` `+screen_retriever ^0.2.2`; `zip_broadcast` `-screen_retriever`; `zip_captions` `+desktop_multi_window ^0.2.1`. `pubspec.lock` unchanged. `zip_captions/macos/Podfile.lock` moved for the first time since Phase 1: the file was stale on `develop`, and `flutter build macos` regenerated it with `desktop_multi_window` + `screen_retriever_macos` (this unit) **and** six plugins already declared before this unit (`app_links`, `flutter_secure_storage_macos`, `flutter_webrtc`, `local_auth_darwin`, `url_launcher_macos`, `WebRTC-SDK`). Recorded for morning review as a lockfile catch-up, not a dependency change.
**Not done**: no push, no PR, no `.agent/` edit, no `question` call, no revert or stage of the standing ` M opencode.json`, no edit of any `docs/` file, no change to `pip-ux-parity.md`, no change to `packages/zip_supabase/`, the caption bus or `CaptionOutputTargetRegistry`, and no `window_manager`. No device, emulator or `flutter run`.
**Approval**: approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-21) — subject to morning review
**Context**: Branch `feature/popout-live-captions`, head `8a828db` — 19 commits, working tree clean apart from the standing ` M opencode.json`, nothing pushed. Step 30 re-ran after the commits: analyze clean and `flutter test` 914+4skip / 177 / 174 in `zip_core` / `zip_broadcast` / `zip_captions`; fence greps clean (the only `desktop_multi_window`/`screen_retriever` imports are the four `zip_core` overlay files; `window_manager` absent from all three `lib/`; `zip_core.dart` does not export `overlay.dart`); no `pubspec.lock` moved by this unit. Next: push, open the PR to `develop`, then Unit 9 (Build and Test + Documentation Refinement).

---
## CONSTRUCTION - Unit 8.1 (Pop-out Live Captions): PR #41 review round 5 addressed
**Timestamp**: 2026-10-23T00:00:00Z
**User Input**: "You are fixing PR #41 ... Read the review you are addressing (the latest PR comment, titled 'Independent review — round 5') ... address every requested change, verify the result, then commit, push and report back on the PR."
**AI Response**: All five round-5 findings addressed test-first on `feature/popout-live-captions` from head `3556a3d`. One blocker, two majors, one minor and one nit; nothing outside the list changed. Dart edits are confined to `zip_core`'s host and its two window-service files, `zip_broadcast`'s external-display provider (and generated part), both apps' pop-out target, scope, shell and recording screen, and the tests. Native edits are the two macOS `MainFlutterWindow.swift` files. No dependency, pubspec, lockfile or `docs/` change; no `.agent/` edit; the standing ` M opencode.json` remains unstaged.
**Findings**:
- **1 (Blocker) — host-built controllers never reached the router.** Part (a): `OverlayWindowHost.createController` now registers with the router first (`OverlayMethodRouter.register(() => controller.windowId, ...)`) and hands the controller `installerFor(token)`; the `late` field is safe because `windowIdOf` is read at dispatch. Part (b): `zip_broadcast`'s `overlayWindowControllerProvider` now builds the external display through `host.createController(mode: ExternalDisplayMode())`, and `displayList` reads `overlayWindowHostProvider.displays`. The direct `overlayMethodHandlerInstaller` export is **removed** from both `desktop_multi_window_service_io.dart` and the stub, so no caller can bypass the router. `OverlayWindowHost` gained an injectable `windowService` factory (defaulting to the plugin) so the host's tests drive a recording service. Tests: "a host-built controller reaches Open over a delivered overlayReady" and "two host-built controllers each receive only their own message". Both fail against the old host with `slot.current == null` / `slot.calls == []` (no write).
- **2 (Major) — blank standby surface when the target is registered mid-session.** `PopOutCaptionTarget` takes `recordingState` and `show()` seeds `_activity` from it, then pushes a snapshot before opening. Both shells pass a read-time probe (`recordingStateNotifierProvider`; `_popOutRecordingState(broadcastRecordingNotifierProvider)`). Test "registered after the session started pushes live, not standby" in both apps; without the seed it fails with `Expected: OverlayActivity.live, Actual: OverlayActivity.standby`.
- **3 (Major) — in-surface toggle on unsupported platforms and the one-frame chrome flash.** `PopOutScope` gained `visible` (both apps), the screens pass `controls: null` when `!visible`, and both shells fall back to `ref.watch(popOutWindowControllerProvider).status` instead of `const Off()`. Tests: "the in-surface toggle does not render" and "the chrome does not flash on the first frame" in both apps; before the fix they fail with the toggle found / `Expected: Unsupported, Actual: Off`.
- **4 (Minor) — macOS close observer outlived its window.** The `willClose` observer now removes its token **before** the `windowIds` guard in both `MainFlutterWindow.swift` files.
- **5 (Nit) — stale comment.** `MainFlutterWindow.swift:35-36` now calls `floating: false, decorated: false` the external display's properties. The existing `// ignore` directives were left alone as instructed.
**Gates (run from each package root)**: `dart analyze --fatal-infos` clean in `zip_core`, `zip_broadcast`, `zip_captions`; `flutter test` `zip_core` 920 passed / 4 skipped, `zip_broadcast` 184 passed, `zip_captions` 184 passed; `flutter build macos --debug` succeeded for both apps.
**Not done**: no device or `flutter run`; the manual macOS pop-out and external-display checks remain owed (recorded on the PR). Windows and Linux runtime behaviour is CI-compile only.
**Context**: Branch `feature/popout-live-captions`, base `develop`. Next: commit, push, watch CI, post the "Fix round 5 landed" comment.

---
## CONSTRUCTION - Unit 8.1 (Pop-out Live Captions): runtime review round 6 fixed
**Timestamp**: 2026-10-23T23:20:00Z
**User Input**: "Fix round 6. Read aidlc-docs/construction/plans/pop-out-review-round-6-fix-plan.md on branch feature/popout-live-captions and do what it says." Mid-session: "use the docs-mcp server for reference materials"; "during picture in picture mode, the main caption window should not show the captions, it should show a message that the captions are currently displayed in an external window, and give the user a button to return the captions to the main window. This is the UX that currently exists in v1". Answers: the v1 main-window behaviour applies to **both apps**; R6-3 uses the **one designed string** (`popOutOpenFailed`), not per-code strings.
**AI Response**: All five round-6 findings re-verified against source and runtime before acting, then fixed test-first where the evidence supported a defect. **R6-1**: neither candidate — the macOS embedder launches a view controller's engine only in `viewWillAppear`, and the hidden-until-ready window never appears, so the sub-engine never ran; both macOS runners now start the engine at the end of the window-created callback (static runner fence test, both apps). This also unblocked `zip_broadcast`'s external display. **R6-5**: records already reached `Logger.root` but went only to `dart:developer`'s `log`; a debug-only `debugPrint` route on the host's logger subtree now prints fixed strings (level, name, message, never the error), and `OverlayWindowHost._child` now uses `fullName`. **R6-3**: `zip_captions` now renders `popOutOpenFailed` beside the chrome toggle while `Failed` (FD §5 R-M8), as `zip_broadcast` already did. **R6-2** and **R6-4**: not reproducible as defects — instrumented runtime reads and per-frame scans on iOS and Android show the inputs, recorded with evidence in `pop-out/code/summary.md`; tests pin both. **Owner UX change**: the main window replaces the captions with the hint and return action while popped out, both apps; FD `frontend-components.md` §5 amendment recorded. **New finding R6-6** (not fixed, design question): after a session stops while popped out, the chrome exit control is disabled although UX-PIP-03 says it applies while "already popped out".
**Gates**: `dart analyze --fatal-infos lib test` clean in all three; `flutter test` `zip_core` 926 passed / 4 skipped, `zip_broadcast` 185, `zip_captions` 188; `flutter build macos --debug` built both apps.
**Runtime**: macOS A2, A3, A5, A6, A8, A9 (zip_captions) and B2, B3 (zip_broadcast) run and recorded; C3 run on the iOS 26.0 simulator and the Android 16 emulator. A7 and B4 remain BLOCKED (Accessibility not granted). Physical Pixel 6 not touched.
**Not done**: no `docs/` edit, no boundary contract touched, no dependency change, no push.
**Context**: Branch `feature/popout-live-captions` from `2243ea8`. Next: owner review of the diff and R6-6, then push and CI.

---
## CONSTRUCTION - Unit 8.1 (Pop-out Live Captions): owner direction after fix round 6
**Timestamp**: 2026-10-23T23:35:00Z
**User Input**: "push the commits" (pushed `2243ea8..295284f`). Then: "when a session stops, the pop-out should close, and the user experience should mirror that which occurs when a session stops when captions are not popped out. the control should reset, so a fresh session would not start popped-out. there is an icon in the left menu that should not be there, it's at the top of the left sidebar, and it should not be included there at all." Answers: wide layout = in-surface toggle only (UX-PIP-01 amended to the narrow layout); open-failure copy beneath the in-surface toggle.
**AI Response**: Both apps, test-first. Each shell closes the pop-out when the session leaves the active states (resolves R6-6). Both nav rails restored from `develop` (the header slot existed only for the pop-out control). `PopOutInSurfaceToggle` now carries the disabled reason and the open-failure line; `PopOutChrome` (narrow `AppBar` only) keeps its reason line and drops the failure line. FD `frontend-components.md` §5 second amendment records the new rule and the §3/§4/§5 changes; `pip-ux-parity.md` UX-PIP-01 is to be amended at Documentation Refinement.
**Gates**: analyze clean in both apps (`zip_core` unchanged); `flutter test` `zip_broadcast` 190, `zip_captions` 190; `flutter build macos --debug` built both apps. Runtime on macOS (`zip_captions`): stop while `Open` closes the window and resets the control; a fresh session starts in the main window; no rail control.
**Context**: Branch `feature/popout-live-captions` at `295284f` plus this change. Not pushed.

---
## CONSTRUCTION - Unit 8.1 (Pop-out Live Captions): review round 7 fixes, A7/B4 deferred to Unit 9
**Timestamp**: 2026-10-24T00:30:00Z
**User Input**: Independent review round 7 posted on PR #41 (APPROVE for the code; 0 blockers, 0 majors, 4 minors, 5 nits). Then: "fix the m1, m2, m3, and m4 findings and commit." Mid-task: "let's capture A7 and B4 as exit criteria for unit 9 and defer that work so we can approve this pr".
**AI Response**: Both apps, test-first; `zip_core` unchanged. **m1**: the R6-3 clearing assertions now return to the window before reading the in-surface toggle (both apps); the vacuous chrome hint tests were replaced. **m2**: `PopOutChrome` (narrow `AppBar`) renders `popOutOpenFailed` under `Key('popOutToggleOpenFailed')` while `Failed`, with one status line at most (the reason outranks the failure), and is bounded at 220 px. That also fixed a pre-existing 319 px horizontal overflow of the narrow reason line with the shipped copy. **m3**: recorded in `pop-out/code/summary.md` that the R6-1 deadlock is a live `develop` defect from Unit 8, fixed for both apps by `7e58f89`. **m4**: the return panel scrolls instead of clipping in a short caption area. FD `frontend-components.md` §5 third amendment records m2 and m4. **A7 and B4** are recorded as Unit 9 exit criteria, with pass conditions, in `inception/application-design/phase2-unit-of-work.md`.
**Gates**: `dart analyze --fatal-infos lib test` clean in both apps; `flutter test` `zip_broadcast` 195, `zip_captions` 195; `flutter build macos --debug` built both apps; mutation checks in a scratch copy: hard-wired `openFailed`, the removed width bound and the removed panel scroll each fail their tests.
**Not done**: no runtime run of these changes; the five round-7 nits are left as recorded on the PR (n3's stale rail comments in `PopOutChrome` were rewritten with the m2 edit); no `docs/` edit; no push.
**Context**: Branch `feature/popout-live-captions` at `5d4bce5` plus this change.

---
## INCEPTION (Units Generation amendment) - Phase 2: Mobile Alpha Units 10-13 recorded
**Timestamp**: 2026-10-25T00:06:11Z
**User Input**: "Using AI-DLC, record the approved mobile alpha plan (memory mobile-alpha-plan, plan file ~/.claude/plans/starry-meandering-galaxy.md) additively into aidlc-docs and the roadmap. First check that PR #41 has merged and pull develop; until then, read and reconcile only, with no writes. Ask me for the unit numbers before writing." Answers to the questions that followed:
- Unit numbers: "10, 11, 12, 13 (Recommended)".
- Units C and D vs Unit 9: "Post-close Phase 2 units (Recommended)".
- Unit 8.1 status: "Yes, append merged status (Recommended)".
- Roadmap text, approved under the AGENTS.md rule for changes to `docs/`: "Approve note + changelog + header".

**AI Response**:
- **Gate check.** PR #41 was MERGED at 2026-10-24T23:57:37Z (`cd0451f`). `git pull --ff-only origin develop` reported "Already up to date". Nothing was written before the unit numbers were given.
- **Reconciliation against `develop` at `cd0451f`.** Gaps G2, G3, G4, G5 and G8 still hold. Unit 8.1 changed no `ios/` or `android/` file. The Android manifest's only `<queries>` intent is `PROCESS_TEXT`. `wakelock_plus` is declared in `zip_core`, not in `zip_captions`. The bundle IDs used by the plan's emulator commands match the projects. S-22, S-23 and SR-05 were unused.
- **Conflicts found and settled.**
  - (1) The parked multilingual STT unit's OQ-1 places it after Unit 9, while the plan's diagram places it before Unit 9. It stays unnumbered and is not placed in the recorded sequence.
  - (2) Unit 9 closes Phase 2, but Units 12 and 13 follow it. Recorded as post-close Phase 2 units, and Unit 9's text is unchanged.
  - (3) Unit 8.1's state entry still read "awaiting morning review". It is now recorded as merged.
  - (4) The plan lists Unit D's stages as "Code Generation ... then Build and Test" but says its harness choice is "decided at NFR". NFR Requirements is therefore recorded as Unit 13's first stage.
- **Written, additive only:**
  - `phase2-unit-of-work.md`: a new "Mobile Alpha Units" section (decisions, the G1-G9 table with the closing unit for each gap, the virtual-device QA procedure, Units 10-13, and the OQ-MA-1 table carried over from the plan) and four Construction Stage Summary rows.
  - `phase2-unit-of-work-dependency.md`: U10-U13 testing checkpoints and an appended section (matrix, graph, build order, shared resources).
  - `phase2-unit-of-work-story-map.md`: S-22, S-23 and SR-05 rows, U10-U13 requirement rows, and coverage and persona addenda.
  - `phase2-stories.md`: S-22 and S-23 with Given/When/Then criteria, SR-05, traceability rows and sequencing lines.
  - `docs/03-roadmap.md`: a "Mobile Alpha (internal)" note under Phase 2, changelog row v0.5, and the header bumped to v0.5 / 2026-10-24.
  - `aidlc-state.md`: Unit 8.1 ticked and recorded as merged; Units 10-13 registered as not started, with OQ-MA-1 as an open blocker on Unit 10; both Current Stage locations point at Unit 10.
- **Not changed:** no existing unit section, phase scope or exit criterion was rewritten. The existing story-map coverage line ("11 of 11 stories") was left as written, and the addendum states the new count. SR-04 is still absent from `phase2-stories.md`, as before.

**Gap finding (from the plan approved 2026-10-22):** the roadmap had no alpha milestone, and Phase 1's mobile captioning exit criterion was never verified on a device. iOS microphone permission and Android `RECORD_AUDIO`/`INTERNET` are likely broken in release builds. No unit verifies a phone viewer, no mobile E2E exists, and no non-production hosted backend exists.

**Context**: Branch `develop` at `cd0451f`. All changes are uncommitted in the working tree. A branch and PR targeting `develop` are needed before commit. Model: Opus for this Inception-style amendment; Units 10-13 run Construction on Sonnet, and SR-05 is reviewed on Opus.


## Unit 9 (Integration Milestones) — Session Start
**Timestamp**: 2026-10-30T00:00:00Z
**User Input**: "You are starting Unit 9 (Integration Milestones) of Phase 2 in the Zip Captions monorepo at /Users/oblivious/Documents/zip-captions-monorepo. It's a Flutter/Dart monorepo with four packages: zip_core, zip_captions, zip_broadcast and zip_supabase. Work with me, James Petersen, the project owner. I approve every stage.

## Read first, in this order
1. CLAUDE.md, then AGENTS.md (project rules; follow them).
2. ai-dlc/aidlc-rules/aws-aidlc-rules/core-workflow.md (the AI-DLC workflow). Rule detail files are in .aidlc-rule-details/. Follow its approval gates: at the end of each stage, stop and wait for my approval.
3. aidlc-docs/aidlc-state.md (the "Current Stage" section and the Backlog).
4. The Unit 9 definition in aidlc-docs/inception/application-design/phase2-unit-of-work.md, plus phase2-unit-of-work-dependency.md and phase2-unit-of-work-story-map.md.
5. /Users/oblivious/Documents/qwen-orchestrator/runs/zip-captions/unit9-feasibility.md. This is a read-only scout from 2026-10-28. It has a 27-row check matrix, methods for the checks that can run without me, the Documentation Refinement items still needed, and blockers B1 to B9 and contradictions C1 to C6. Treat its file and line references as leads and verify them before relying on them.
6. For precedent, read Phase 1's Integration Milestones records: aidlc-docs/construction/build-and-test/. Unit 9 appends a Phase 2 set beside them.

## Where things stand
- Units 1 to 8.1 of Phase 2 are merged to `develop`; Unit 8.1 is squash merge `cd0451f`.
- Unit 10 (Mobile Platform Readiness) is PR #44 into `develop` and is NOT merged. It is on `feature/mobile-platform-readiness`, which is checked out now. Unit 9 does not depend on it.
- Create the Unit 9 branch from an up-to-date `develop`: `git checkout develop`, `git pull`, then `git checkout -b feature/phase2-integration-milestones`. If the switch is refused because of local changes, stop and tell me. Don't stash or discard anything; `opencode.json` has local changes that I keep uncommitted.
- Because Unit 10 isn't merged, `develop`'s audit.md and aidlc-state.md don't have the Unit 10 entries. Append Unit 9 entries at the end of audit.md, and keep aidlc-state.md edits to Unit 9 lines, so the later merge conflict stays small.

## First task: blockers, before any test work
Present these to me as decisions, with your recommendation for each, and wait for my answers:
- **B1:** neither macOS app's entitlements include `com.apple.security.network.client`. Every macOS network check fails until it's added.
- **B2:** `get_turn_credentials()` is granted only to `authenticated` users, and anonymous sign-in is off. A viewer with no account can't get ICE servers, which contradicts exit criterion 1 and the Unit 7 design wording. The options include granting it to anon, anonymous sign-in, or a STUN-only fallback. This is security-sensitive and needs my pre-approval.
- **B5:** there's no broadcaster sign-in on the local stack. Google OAuth isn't configured in the compose `auth:` block, and the custom-scheme redirect isn't in `ADDITIONAL_REDIRECT_URLS`.
- **B3/B4:** Coturn's local config refuses private-range relay, and there's no relay-only switch in the apps. This affects how EC3b can be proven.
- **B6/M3:** there's no real-protocol 50-viewer swarm. Propose what to defer and how to record the deferral.

Then propose the Unit 9 plan:
- Which checks you run alone (EC3a, EC7, M4, the server-side half of EC5, and EC8/EC9 if the GUI can be driven).
- Which checks need me at the keyboard or with a device.
- Which checks are CI-only (Windows/Linux build-verify runs on the PR).
- The Documentation Refinement edits from section 3 of the scout report.

## Rules I hold you to
- Never use git worktrees. Work on one branch at a time in this checkout.
- Commit only right before a PR or a branch switch, so I can see live uncommitted diffs. Never push or open a PR without asking me. feature/* PRs target `develop`.
- Use `python3` and `pip3`; `python` isn't on PATH.
- Use your file tools to read, search and edit files. Use the shell only for single, plain git, flutter, dart and docker commands: no pipes, no && chains, no cat/sed/grep through the shell. To move or copy a file verbatim, use cp or mv; never retype its contents.
- Local Supabase stack (packages/zip_supabase):
  - The Docker volumes hold existing data.
  - Never run `docker compose down -v`, `docker volume rm`/`prune` or `supabase db reset`.
  - Use `docker compose up -d` to reuse what's there.
  - Check the migration state through `docker exec supabase-db psql ...` before applying anything.
- QA happens through the real app flows only. Never bypass the app (no adb input injection, no injecting sessions into storage) unless I explicitly approve it.
- Identifier string comparisons must be case-insensitive or use enums.
- UI strings: edit `l10n/arb/app_en.arb`. zip_broadcast runs `flutter gen-l10n`; zip_captions adds a `ZcStrings` getter.
- Riverpod: use `riverpod_generator` (no hand-written providers) and no `// ignore` comments. Notifiers make explicit calls for side effects; don't use reactive watchers for them.
- Log every one of my inputs in aidlc-docs/audit.md with a timestamp, verbatim, by appending. Never overwrite the file.
- Gates before you call anything done:
  - `dart analyze --fatal-infos` is clean in every changed package.
  - `flutter test` passes in every changed package; report the counts.
  - The real-stack tests ran: `flutter test --tags integration-supabase --run-skipped <file>` from packages/zip_core, with the stack up.
- Report results as they are. If something fails or is skipped, say so with the output.

Start by reading the files above. Then tell me in a few lines what Unit 9 must prove, and give me the blocker decisions."
**AI Response**: Read CLAUDE.md, AGENTS.md, the AI-DLC core workflow, aidlc-state.md, the Unit 9 definition and its dependency/story-map companions, Phase 1's build-and-test set, and the scout report. The scout file sits outside the repo, so it was copied verbatim with cp into `aidlc-docs/construction/plans/unit9-feasibility-scout.md` (path unchanged by the copy). Verified the scout's load-bearing claims against source instead of trusting its line references: B1 (four entitlement files), B2 (`20261003000000_coturn_turn_credentials.sql:65-68,88`; `.env:66`; `viewer_session_notifier.dart:247-255`), B3/B4 (`turnserver.conf:35,68-80`; no `iceTransportPolicy` anywhere), B5 (`docker-compose.yml:88-110`; `.env:50`), C1 (Unit 8 summary lists six checks, Unit 9's text says five), C6 (scout says `cd0451f`; branched off `develop`, which is `cd0451f` today). All `supabase-*` containers exist and are stopped; volumes intact; nothing started. Created branch `feature/phase2-integration-milestones` off an up-to-date `develop`; `opencode.json` left uncommitted and nothing stashed. Presented the Unit 9 purpose and the blocker recommendations (B1-A, B2-A, B5-A, B3/B4-A, B6/M3-A) plus the C2 phone-scope note.
**Context**: CONSTRUCTION Phase 2, Unit 9, session start. Model: Opus for design/clarification; the construction stages run on Sonnet.

---

## Unit 9 — Question Format and Overnight-Pipeline Adoption Request
**Timestamp**: 2026-10-30T00:01:00Z
**User Input**: "For each decision you need from me, present the question with some detail and context, and then the answer options, we will work through them one at a time. I would like you to look at the overnight pipeline skill to see if we can adopt that approach for unit 9."
**AI Response**: Read the `overnight-pipeline` skill in full (`SKILL.md`, `process.md`, `run-config.md`) and checked the repo against it. Concluded it fits as a shape, not as a pipeline: its build loop assumes product code and automatable gates, while 21 of Unit 9's 27 checks need a human at the keyboard. Recommended a hybrid: the skill's Phase A config derivation, Phase B one-question-at-a-time clarification, Phase C approval table and an append-only ledger, then verification tracks (A unattended, B human, C CI) instead of the build loop. Note: the ledger path `aidlc-docs/overnight-ledger.md` is already gitignored in this repo. Started the one-at-a-time decision list with Question 1 (B1).
**Context**: Unit 9 bloc: clarification starts before any construction work.

---

## Unit 9 — Decision 1 (B1, macOS network entitlement)
**Timestamp**: 2026-10-30T00:02:00Z
**User Input**: "A"
**AI Response**: Recorded Decision 1 = **A**: add `com.apple.security.network.client` to all four entitlement files (zip_broadcast and zip_captions, Debug and Release). Noted the related `keychain-access-groups` / `-34018` risk for `flutter_secure_storage` in the sandbox: escalate with evidence rather than patching silently. Not yet applied; the edit follows the remaining decisions so the change set is one coherent unit.
**Context**: Unit 9, Decision 1 of 8.

---


## Unit 9 — Decision 2 intent (docs-mcp research request)
**Timestamp**: 2026-10-30T00:05:00Z
**User Input**: "A but I would like to ensure that we're using the best approach to webrtc and stun/turn so let's make use of the docs-mcp server, I think we have webrtc but we can add any missing libraries to ensure the approach is correct."
**AI Response**: Researched the approach before accepting the answer. Indexed `flutter_webrtc` 1.6.2+hotfix.4 and draft-uberti-behave-turn-rest-00 into docs-mcp. Verified the config path end to end: `peer_connection_factory.dart:26-35` builds a plain map, `RTCFactoryNative.createPeerConnection` forwards it verbatim, and both native layers parse it (macOS `common/darwin/Classes/FlutterWebRTCPlugin.m:2223-2233`; Windows/Linux `common/cpp/src/flutter_webrtc_base.cc:323-335`), mapping `all`/`none`/`nohost`/`relay`. Reading the upstream `examples/etc/turnserver.conf` confirmed the credential mechanism matches Coturn's `use-auth-secret` and draft-uberti 2.2. Two findings reported: (1) `iceTransportPolicy` is untyped in Dart - `webrtc_interface` 1.5.1's `RTCConfiguration` is fully commented out, so the policy travels as a raw map key; (2) a short anonymous TTL would break long sessions - draft-uberti 2.2/4.2 and RFC 8656 5 check the username timestamp at ALLOCATE only and require 441 on any mismatch, so rotating to fresh credentials invalidates refresh of an existing allocation, and 5.1 says TURN REST credentials cannot be revoked at all. Recommended keeping the 1-hour TTL, binding credentials to the broadcast id, and a single fetch per join. Also noted `getStats()` exposes `StatsReport.values` as a raw map with a `type` string, making a relay `candidateType` observation possible for EC3b.
**Context**: Unit 9, Decision 2, research pass before the answer was given.

---

## Unit 9 — Decision 2 (B2, anonymous viewer ICE credentials)
**Timestamp**: 2026-10-30T00:15:00Z
**User Input**: "A"
**AI Response**: Recorded Decision 2 = **A (revised)**. A new forward-only migration adds a broadcast-id-bound, `SECURITY DEFINER` credential RPC reachable by `anon`, behind a Kong rate limit mirroring `resolve_broadcast_id`'s (30/min, 2/s, per IP); 1-hour TTL matching the broadcaster path; the username carries the broadcast id as an opaque user id per draft-uberti 6; the viewer fetches once per join and never mid-allocation; no anonymous sign-in and no `auth:` config change. The `auth.uid()` guard on the existing `get_turn_credentials()` stays untouched. This is security-sensitive: a written approach note (RLS/privilege and rate-limit rationale) will be produced and approved before any code is written, per AGENTS.md.
**Context**: Unit 9, Decision 2 of 8.

---

## Unit 9 — Coturn docs-mcp index repair (delegated)
**Timestamp**: 2026-10-30T00:16:00Z
**User Input**: "fix the bad index on the coturn library, let's make sure it's useful, but delegate that to a sub-agent so we can continue here"
**AI Response**: Delegated to a fresh `general` sub-agent, scoped to docs-mcp tooling only with an explicit instruction not to touch the repo or run git. Outcome: the `coturn` entry went from 1 page (the Docker image README) to 20 pages, rooted at `https://github.com/coturn/coturn/wiki` via `scrape_docs(replace: true)`, job `5be40668-0cb2-4a0d-bb37-b6138f78b17e`. Probes: `use-auth-secret`, `static-auth-secret`, `denied-peer-ip`, `listening-ip` and `allow-loopback-peers` now return real option semantics; `max-allocate-lifetime` and `prometheus` do not, because the wiki predates those options and the annotated `examples/etc/turnserver.conf` plus `README.turnserver` sit at raw URLs no crawl can reach and the toolset has no per-URL seeding. That gap is covered by reading the upstream `turnserver.conf` directly this session. No repo change.
**Context**: Unit 9, tooling maintenance alongside the decision list.

---


## Unit 9 — Decision 3 (B5, local broadcaster sign-in)
**Timestamp**: 2026-10-30T01:17:00Z
**User Input**: "A"
**AI Response**: Recorded Decision 3 = **A**: configure Google OAuth for the local stack. Requires a Google Cloud OAuth client with authorised redirect URI `http://localhost:54321/auth/v1/callback`; `GOTRUE_EXTERNAL_GOOGLE_ENABLED/CLIENT_ID/CLIENT_SECRET/REDIRECT_URI` added to the compose `auth:` block reading from `.env` (gitignored, values never committed); and `io.zipcaptions.broadcast://login-callback` added to `ADDITIONAL_REDIRECT_URLS`. One real sign-in through the app on macOS, session then persists in the keychain. The macOS-only limitation for signed-in checks (Backlog: Windows/Linux OAuth redirect registration incomplete) was stated in the question and is not contested; it will be recorded as a limitation rather than expanded into native Windows/Linux OAuth work inside Unit 9. Still pending from James: the Google client ID and secret (he creates the OAuth client; I edit the compose and `.env`).
**Context**: Unit 9, Decision 3 of 8.

---


## Unit 9 — Decision 4 (B3/B4, proving EC3b relay)
**Timestamp**: 2026-10-30T01:19:00Z
**User Input**: "A"
**AI Response**: Recorded Decision 4 = **A**: add an `iceTransportPolicy` field to the peer-connection configuration, settable only under `kDebugMode` via a dart-define (no UI, never in release), and implement `getStats()`-based candidate-type detection so `ViewerConnectionInfo.connectionType` reports the observed path instead of Unit 5's hardcoded `p2pDirect`. EC3b then runs deterministically in relay-only mode. Both native layers accept `'iceTransportPolicy': 'relay'` from the config map (macOS `FlutterWebRTCPlugin.m:2232-2233`; Windows/Linux `flutter_webrtc_base.cc:329-330`). This touches Unit 5's shipped `PeerConnectionHandle` seam (additive method) and removes a hardcoded incorrect value from the product: it is a code change inside a verification unit and will be scoped explicitly in the plan and called out in the PR. Coturn's tracked `turnserver.conf` is NOT weakened; the local refusal to relay to private peers stays as designed.
**Context**: Unit 9, Decision 4 of 8.

---


## Unit 9 — Decision 5 (B6/M3, capacity swarm and two-hour run)
**Timestamp**: 2026-10-30T01:19:00Z
**User Input**: "A"
**AI Response**: Recorded Decision 5 = **A**: no real-protocol swarm is built in this unit. EC5 gets what is provable - the existing 51-concurrent-private-channel structural proof, plus a live refusal check through the real join flow once B2 and B5 unblock a session. EC5's "existing viewers unaffected" clause and M3 (two-hour run at capacity within Phase 1 latency/resource targets) are recorded as **deferred, not verified**, in three places: the new Phase 2 build-and-test summary, an `aidlc-state.md` Backlog item ("real-protocol capacity harness + sustained-run measurement"), and the PR body. Supporting evidence cited is Spike 2.1 only (best observed 84% join success at N=50, root cause narrowed but unconfirmed), and the fact that M3's own latency/resource targets were never baselined in Phase 1 (Phase 1 build-and-test summary: performance "N/A - no throughput or latency SLAs defined"). `maxViewers = 50` is left unchanged.
**Context**: Unit 9, Decision 5 of 8.

---


## Unit 9 — Decision 6 (C2, phone-scope wording)
**Timestamp**: 2026-10-30T01:20:00Z
**User Input**: "A"
**AI Response**: Recorded Decision 6 = **A**: the phone form of M-S3.6 clause 1 belongs to Unit 13 (gap G6: "no unit verifies the mobile viewer", evidenced by "Unit 9's scope does not name a phone"). Unit 9 proves the substantive claim - a viewer with no account watches a live broadcast - on macOS and in Chrome. The split is recorded in three places: the Phase 2 build-and-test summary, a note added to Unit 9's definition during Documentation Refinement, and an `aidlc-state.md` line. The consequence was stated in the question and accepted: read literally, M-S3.6 clause 1 is not closed by Unit 9.
**Context**: Unit 9, Decision 6 of 8.

---


## Unit 9 — Decision 7 (overnight-pipeline adoption)
**Timestamp**: 2026-10-30T01:21:00Z
**User Input**: "A"
**AI Response**: Recorded Decision 7 = **A**: adopt the `overnight-pipeline` skill's shape, not its build loop. Taken: Phase A run-config derivation, Phase B one-question-at-a-time clarification, Phase C single approval table, the append-only ledger (`aidlc-docs/overnight-ledger.md`, already gitignored), the "orchestrator re-runs every gate itself" principle, fresh-context subagents for bounded research, and the hard-blocker policy. Dropped with reasons: the `test-author`/`builder`/`test-adversary` loop (21 of 27 checks are human-observed, so no test can adjudicate them; the skill's own Phase A step 4 excludes such a unit from an unattended run) and the unattended contract (Unit 9 must ask questions and must touch Docker, the OS and a second display). Replaced by three tracks: A unattended verification, B scripted human checks, C CI-only. No change to `opencode.json`; the project defines none of the pipeline subagents, so Task spawns fall back to `general` with prompt-level fences only.
**Context**: Unit 9, Decision 7 of 8.

---


## Unit 9 — Decision 8 (Documentation Refinement scope and approval mode)
**Timestamp**: 2026-10-30T01:22:00Z
**User Input**: "A"
**AI Response**: Recorded Decision 8 = **A**: grouped approval, one group per turn, presented as a concrete before/after diff per file with line references, applied only after a yes for that group. Groups, in order: (1) wrong and load-bearing - `docs/03-roadmap.md` Phase 2 (remove the Realtime-relay deliverables, relay toggle, vanity URLs and relay exit criterion; move local Wi-Fi WebSocket to Phase 5; record the minimal-auth slice; re-scope Spike 2.1; restate the nine exit criteria), `docs/04-technical-specification.md` §9 (`broadcast_identities` + `broadcast_join_requests` with RLS summary; Phase 2 Realtime carries no caption payloads), `docs/02-architecture-decisions.md` ADR-011 (WebRTC first, relay after Phase 3 encryption, local WebSocket with BLE). (2) stale but harmless - `AGENTS.md` Current Scope to Phase 2 and the worktree guidance replaced with the no-worktrees one-branch practice; the `window_manager` prose in `phase2-unit-of-work.md` Unit 8.1 and the `aidlc-state.md` Backlog corrected to the shipped first-party `configure` channel. (3) contract and history - S3.6 into `docs/01-user-personas.md`; the Q9 pop-out amendment into `pip-ux-parity.md` §8.8 item 13 and UX-PIP-10 with the owner's name and date; `domain-entities.md:215` corrected to the actual B2 mechanism; the new Phase 2 build-and-test set.
**Context**: Unit 9, Decision 8 of 8. Clarification round complete.

---


## Unit 9 — Run configuration approved
**Timestamp**: 2026-10-30T01:23:00Z
**User Input**: "that's correct, proceed and ensure that client id, secret, and redirect for google oauth are consumed as environment or build variables, I don't want them in version control when I provide them to you."
**AI Response**: Recorded the Phase C approval of the run configuration table. Added a hard constraint to D3: the Google OAuth client id, client secret and redirect URI are consumed only as environment variables in the local stack (`.env`, gitignored) and, if the app ever needs them, as `--dart-define` build variables - never as literals in any tracked file. The compose `auth:` block will reference `${GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID}` and friends; `.env.example` will carry empty placeholders only. Proceeding with Track A: write the run config to `.agent/overnight-run-config.md` (gitignored), start the local stack non-destructively, check migration state read-only.
**Context**: Unit 9, Phase C approval. Clarification round closed.

---


## Unit 9 — D2 approach approved; B5 credentials deferred to placeholders
**Timestamp**: 2026-10-30T01:30:00Z
**User Input**: "confirmed, I'm not going to give you the client id and secret, use placeholders for now and I'll update them later on when they're ready."
**AI Response**: Recorded approval of the D2 security approach as written in `aidlc-docs/construction/plans/unit9-d2-turn-credential-approach.md`: guard is broadcast-id existence only (no ownership check, `42501` on unknown id), username is `'<expiry>:<broadcast_id>'`, Kong limit clones `resolve_broadcast_id` (30/min, 2/s, per IP, fault_tolerant), and no per-broadcast quota. Also recorded a change to D3: the Google OAuth client id and secret will NOT be supplied. The compose `auth:` block and `.env.example` will carry empty placeholders, `.env` will get empty values, Google stays disabled in the local stack until the owner fills them in, and the B5 verification leg is recorded as BLOCKED-ON-CREDENTIALS rather than silently skipped. The mechanism (env vars only, never tracked literals) is unaffected and will still be implemented so the swap is a two-line change in a gitignored file.
**Context**: Unit 9, security gate for B2 cleared. B5 blocked by decision of the owner.

---

- 2026-10-30T02:40Z — (no new owner input; run continues under the standing
  D1-D4 approvals) D4 complete, gates green, scope restored after an
  accidental whole-package `dart format`.

- 2026-10-30T02:44Z — Owner: "I'll close it myself when the app is up. Finish
  the ci only track and everything that can be done without me overnight, and
  I'll pick it back up in the morning"
  -> A7/B4 RESOLVED: owner closes the overlay window manually; no
  Accessibility grant, no programmatic close. Track B overlay leg waits on
  the owner being present.
  -> DO NOT open or push a PR. Do not commit. Stay on the local branch.
  -> Track C (CI-only) and Documentation Refinement may proceed unattended.

- 2026-10-30T03:20Z — (no new owner input) Track C read-only work: both
  workflows audited; `test:coverage` verified to run via melos' raw-command
  fallback rather than a defined script; version skew 3.41.7 local vs 3.38.7
  CI recorded; neither app has a `web/` directory despite the docs claiming a
  web target; D1 upgraded from plist-parse to signed-bundle inspection; D2
  verified through Coturn (HMAC match, allocate success, tampered credential
  rejected); Coturn log-volume permission defect found and recorded, not
  fixed. No push, no PR, no commit, as instructed.

- 2026-10-30T03:40Z — (no new owner input) Documentation Refinement group 1
  authored as a review packet only; nothing applied to `docs/` or `AGENTS.md`,
  because each doc change needs explicit per-change approval and the owner is
  asleep. Packet: `aidlc-docs/construction/plans/unit9-doc-refinement-packet.md`.
  Seven findings, six draft diffs, one needs a decision from the owner.

- 2026-10-30T04:12Z — Owner: "web is a future target, ADRs will eventually be
  fulfilled once full build has been delivered, but that's beyond the scope of
  unit 9"
  -> G1-2 DOWNGRADED. The web target is intended and deferred, not a defect.
  No doc change proposed for Unit 9: ADR-001's Fallback column stays as the
  plan, and the missing `web/` directory is expected at this stage. Recording
  the present state is moved to group 2 (stale but harmless) at most, and is
  not to be written as a gap, a fix, or a backlog item.
  -> Consequence for Unit 9 verification: the Chrome leg of D6 is
  browser-to-desktop, which needs no build. That stands, and no longer reads as
  a workaround for a missing target.

- 2026-10-30T04:35Z - Doc refinement item 1 of 8 (G1-1, AGENTS.md worktree
  mandate) presented with 4 options. Owner answer: "1" -> option 1, replace
  the section with a branch mandate, keep the isolation rationale, note that a
  worktree is one way but not a requirement here, and update the two workflow
  steps plus the "one worktree per PR" rule to say branch. APPROVED, not yet
  applied.

- 2026-10-30T04:40Z - Doc refinement item 2 of 8 (G1-3, zip_broadcast stray
  mobile directories) presented with 4 options. Owner answer: "1" -> option 1,
  delete packages/zip_broadcast/android and packages/zip_broadcast/ios.
  APPROVED, not yet applied. 59 tracked files affected (verified by
  `git ls-files`). Also to be done during the doc pass as its own separable
  step.

- 2026-10-30T04:44Z - Doc refinement item 3 of 8 (G1-4, ADR-011 connection
  status vocabulary) presented with 4 options. Owner answer: "1" -> option 1,
  update ADR-011:701-703 to the shipped enum `{p2pDirect, turnRelayed,
  connecting, disconnected}`, plus an explicit note that `serverRelayed`
  (Supabase Realtime relay) and `BLE` (ADR-007) are later-phase and must be
  added to the enum when they exist, not before. APPROVED, not yet applied.

- 2026-10-30T04:48Z - Doc refinement item 4 of 8 (G1-5, no record of what
  Phase 2 verified) presented with 4 options. Owner answer: "1" -> option 1,
  write the full `aidlc-docs/construction/build-and-test/
  phase2-build-and-test.md` as drafted: verified (command + observed result),
  inspection-only, blocked (with owner), deferred (with reason), and defects
  found but not fixed. Explicitly included: the "not verified" rows (anonymous
  viewer runtime claim, TURN fallback in a real app, CI on this branch).
  APPROVED, not yet applied.

- 2026-10-30T04:52Z - Doc refinement item 5 of 8 (G1-6, Q9 pop-out geometry
  amendment never applied to pip-ux-parity.md) presented with 3 primary
  options plus a subsidiary question (a note the parity break in this diff,
  b defer to group 3). Owner answer: "1" -> option 1, apply the amendment as
  recorded (UX-PIP-10 row + item 13, owner name + 2026-10-21 date, no detail
  beyond aidlc-state.md and audit.md:2652-2653). APPROVED, not yet applied.
  SUBSIDIARY QUESTION UNANSWERED (not assumed): whether the deliberate parity
  break is noted inside this diff or deferred to group 3. Carried forward as
  an open question; the diff will not add a parity-break note until answered.

- 2026-10-30T05:05Z - Owner revisited G1-6: "I want to make sure that the
  amendment is authoritative and overrides the previous design." Re-verified
  from primary sources, not from state-file summaries, and reported the chain:
  (1) `plans/pop-out-functional-design-clarification-questions.md` framed the
  geometry as a conflict that "cannot be settled inside the unit" and offered
  Amendment A = change UX-PIP-10 + item 13, which the owner chose;
  (2) `audit.md:2653` records that choice verbatim;
  (3) `audit.md:2661` records the amendment ordering as one of three review
  points ACCEPTED at the Functional Design approval gate;
  (4) `pop-out/functional-design/domain-entities.md:91` and `:218-223` define
  widthFraction 0.75 / visibleLines 2 / minWidth 320 / minHeight 96 and that
  shape is in shipped code. CONFIRMED AUTHORITATIVE: the owner approved
  amending the contract, so applying it completes the decision rather than
  overriding it; and the shipped implementation already matches the amended
  numbers, so 640x320 now describes a window the app does not open.
  Owner answer: "1" -> option 1, apply with a short provenance line recording
  that this supersedes 640x320 by owner decision 2026-10-21 per the FD
  clarification. APPROVED, not yet applied.
  SUBSIDIARY QUESTION STILL OPEN: whether the deliberate v1 parity break is
  noted in this diff or deferred to group 3. Not assumed.
  Naming convention to use: "the project owner", dated (repo house style);
  no individual name is recorded in any source, so none is invented.

- 2026-10-30T05:12Z - Doc refinement item 6 of 8 (G1-6b, viewer design docs
  naming the session-scoped credential call) was presented; the owner paused it
  and asked to revisit G1-6 first. G1-6 was re-verified and settled (option 1,
  with provenance + parity-break note). G1-6b remains UNANSWERED, to be
  re-presented. It is not treated as approved.
- 2026-10-30T05:14Z - Doc refinement item 7 of 8 (G1-7(a), tech spec Section 9
  silent on function grants not being a control) presented with 4 options.
  Owner answer: "1" -> option 1, add a "Function Grants" subsection to
  docs/04-technical-specification.md Section 9: the image's public-schema
  default ACL grants EXECUTE to anon/authenticated/service_role and re-applies
  on CREATE OR REPLACE, so a REVOKE does not survive a redeploy; authorization
  for any SECURITY DEFINER function must be enforced in the body (existence
  checks, auth.uid(), RAISE ... ERRCODE 42501); the grant is defence in depth
  only; both shipped credential functions named as examples.
  APPROVED, not yet applied.

- 2026-10-30T05:18Z - Doc refinement item 8 of 8 (G1-7(b), CI design doc
  describes a `test:coverage` melos script that does not exist) presented with
  4 options. Owner answer: "2" -> option 2, add the `test:coverage` script to
  `melos.yaml` (matching `test` plus `--coverage`, WITH the `dirExists: test`
  filter) AND rewrite the CI design doc section to describe the commands CI
  runs rather than reproducing the melos YAML, so the doc cannot drift from the
  config again. APPROVED, not yet applied.

- 2026-10-30T05:30Z - Owner: "let's proceed, I can answer those two, I thought
  we'd resolved them already"
  -> G1-6 SUBSIDIARY (parity-break note): resolved by the standing answer. The
  owner twice answered the G1-6 question with "1", and option 1 as presented
  included "plus one sentence recording that this supersedes the 640x320
  default by owner decision on 2026-10-21" - i.e. the note belongs in this
  diff, not deferred to group 3. Applied as drafted. Not re-asked.
  -> G1-6b: "let's proceed" + "I can answer those two" taken as approval of
  the recommended option for G1-6b, which was option 1 (correct both call
  sites and delete the false anonymous-accessible claim). Recorded as an
  inference from the combined signal, NOT as an explicit per-option answer;
  if that is wrong, say so and it is reverted - it is docs-only and isolated.

- 2026-10-30T06:05Z - Documentation Refinement group 1 APPLIED (all eight
  decided items; G1-2 withdrawn). Files changed:
  `AGENTS.md` (G1-1), `docs/02-architecture-decisions.md` ADR-011 (G1-4),
  `docs/04-technical-specification.md` section 9 (G1-7a),
  `aidlc-docs/.../pip-ux-parity.md` UX-PIP-10 + item 13 (G1-6),
  `aidlc-docs/construction/zip-captions-viewer/functional-design/
  {domain-entities,business-logic-model,business-rules}.md` (G1-6b, plus two
  side-references found during application),
  `aidlc-docs/construction/ci-pipeline/infrastructure-design/
  infrastructure-design.md` (G1-7b doc half), `melos.yaml` (G1-7b code half),
  new `aidlc-docs/construction/build-and-test/phase2-build-and-test.md`
  (G1-5), and 59 deleted files under `packages/zip_broadcast/{android,ios}/`
  (G1-3).
  Gates re-run after applying: `melos run analyze` -> no issues in all four
  packages; `melos run test:coverage --no-select` -> now resolves the defined
  script rather than the fallback, 952+5 / 195 / 195 passing, lcov.info
  produced per package.
  Nothing committed, nothing pushed, no PR opened.

- 2026-10-30T06:25Z - Owner, verbatim: "let's proceed with the six remaining
  doc-refinement items, and defer the track b interactive legs until later".
  Recorded as: (a) the doc-refinement items were already applied pre-compaction
  and required no action; (b) Track B is deferred and Unit 9 will merge with
  the four interactive legs recorded as "not verified" in
  phase2-build-and-test.md section 4.
