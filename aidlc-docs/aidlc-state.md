# AI-DLC State Tracking

## Project Information
- **Project Name**: Zip Captions v2
- **Project Type**: Documentation-Brownfield / Code-Brownfield
- **Phase 0 Start Date**: 2026-03-26T00:00:00Z
- **Phase 1 Start Date**: 2026-03-28T00:00:00Z
- **Phase 2 Start Date**: 2026-07-19T21:00:00Z
- **Current Stage**: CONSTRUCTION Phase 2 — Unit 1 COMPLETE; Spike 2.1 PAUSED 2026-09-27 (interim `maxViewers=50` accepted, see below). Unit 2 (Broadcaster Auth) Functional Design + SR-01 APPROVED 2026-09-28. Next: Unit 2 NFR Requirements.

## Workspace State
- **Existing Source Code**: Yes — Phase 0 scaffold complete (zip_core models/providers/theme, app shells, Supabase stack, CI/CD)
- **Existing Documentation**: Yes (docs/, AGENTS.md, ARCHITECTURE.md, CONTRIBUTING.md, aidlc-docs/)
- **Reverse Engineering Needed**: No (codebase built by AI-DLC in Phase 0; design artifacts in aidlc-docs/)
- **Workspace Root**: /Users/oblivious/Documents/zip-captions-monorepo

## Code Location Rules
- **Application Code**: Workspace root (NEVER in aidlc-docs/)
- **Documentation**: aidlc-docs/ only
- **Structure patterns**: See code-generation.md Critical Rules

## Extension Configuration

| Extension | Enabled | Decided At |
|---|---|---|
| Security Baseline | Yes — all rules as blocking constraints | Requirements Analysis |
| Property-Based Testing | Yes — full enforcement (all rules) | Requirements Analysis |

## Stage Progress

### INCEPTION PHASE
- [x] Workspace Detection — Documentation-brownfield / code-greenfield; no source code
- [ ] Reverse Engineering — SKIPPED (no source code to analyze)
- [x] Requirements Analysis — COMPLETE; requirements.md generated
- [ ] User Stories — SKIPPED (infrastructure scaffolding; no user-facing features)
- [x] Workflow Planning — COMPLETE; execution-plan.md generated (6 units)
- [x] Application Design — COMPLETE
- [x] Units Generation — COMPLETE

### CONSTRUCTION PHASE
- [x] Unit 1: Monorepo Scaffold — MERGED (PR #2, commit d6c9cd1)
- [x] Unit 2: zip_core Library — COMPLETE (Functional Design, NFR Requirements, NFR Design, Code Generation all done; 81 tests passing)
- [x] Unit 3: App Shells — COMPLETE (Code Generation done; 6 widget tests passing)
- [x] Unit 4: Supabase Local Dev — COMPLETE (NFR Requirements, Infrastructure Design, Code Generation all done)
- [x] Unit 5: CI/CD Pipeline — COMPLETE (NFR Requirements, Infrastructure Design, Code Generation all done)
- [x] Unit 6: Spike 0.1 — COMPLETE (platform scaffolding, macOS builds pass, build-verify.yml, PLATFORM_SETUP.md)
- [x] Build and Test — COMPLETE (87 tests pass, 0 analyze issues, docs generated)
- [x] Documentation Refinement — COMPLETE

### OPERATIONS PHASE
- [x] Operations — SKIPPED (Phase 0 is infrastructure scaffolding; no deployment or production operations)

---

## Phase 1: Core Captioning

### INCEPTION PHASE
- [x] Workspace Detection — Brownfield; Phase 0 scaffold exists; no reverse engineering needed
- [ ] Reverse Engineering — SKIPPED (codebase built by AI-DLC; design artifacts current)
- [x] Requirements Analysis — COMPLETE; phase1-requirements.md generated (11 FRs, 5 NFR groups, 3 spikes; 4 revisions)
- [x] User Stories — COMPLETE; 10 feature stories, 9 prototype stories, 6 milestones; 4 revisions
- [x] Workflow Planning — COMPLETE; 7 construction units + 3 spikes
- [x] Application Design — COMPLETE; 22 new components, 8 modified, 7 service layers; DisplaySettings rename
- [x] Units Generation — COMPLETE; 3 spikes + 7 units; all stories assigned; relaxed spike sequencing

### CONSTRUCTION PHASE
- [x] Spike 1.1: Windows/Linux STT Survey — COMPLETE; Sherpa-ONNX recommended primary, Whisper.cpp secondary
- [x] Spike 1.2: System Audio Capture Feasibility — COMPLETE; custom plugin needed, Core Audio taps (macOS), WASAPI loopback (Windows), PulseAudio monitors (Linux)
- [x] Spike 1.3: STT Integration PoC — COMPLETE; Sherpa-ONNX confirmed viable, OnlineRecognizer API maps to SttEngine contract
- [x] Unit 1: Core Abstractions (S-01, S-03) — FD, NFR-R, NFR-D, CG — COMPLETE (156 tests passing, 0 errors)
- [x] Unit 2: Platform STT + Audio (S-02, S-06) — FD, NFR-R, NFR-D, CG — COMPLETE (247 tests passing, 0 errors)
- [x] Unit 3: Output Targets (S-04, S-05, S-07, S-08) — FD, NFR-R, NFR-D, ID, CG — COMPLETE (all 21 CG steps done; 0 errors, 0 warnings; 7 pre-existing implementation_imports infos)
- [x] Unit 4: UI Prototypes (Proto-01..09) — CG, Human Review Gate, Implementation Design — COMPLETE
- [x] Unit 5: Zip Captions App (S-09) — FD, NFR-R, NFR-D, CG — COMPLETE (merged PR #14)
- [x] Unit 6: Zip Broadcast App (S-10) — FD, NFR-R, NFR-D, ID, CG — COMPLETE (merged PR #15; 80 tests)
- [x] Unit 7: Integration Milestones — Build and Test COMPLETE (457 tests pass, 0 analyze issues); Doc Refinement COMPLETE
- [x] Phase 1 UI/UX Human Review Gate (Zip Broadcast) — COMPLETE 2026-07-07; sign-off PASS after fixing nav Audio Inputs icon, Start-button gating, stuck-disabled-after-stop, duplicate audio-inputs back-stack push, active-route re-navigation, mobile drawer grouping, Appearance chip→select-box conversion (branch `feature/phase1-integration-tests`)
- [x] PR #16 (`feature/phase1-integration-tests` → `develop`) — MERGED 2026-07-19; CodeRabbit CHANGES_REQUESTED (5 findings) and 2 failing CI checks (lint, Windows Build Verify — MSVC toolchain regression, unrelated to PR diff) resolved across 3 follow-up commits (`b12cb51`, `19cf2ca`, `2a5c987`); see `aidlc-docs/construction/plans/unit7-pr16-review-fixes-code-generation-plan.md`

**Phase 1 Construction — FULLY COMPLETE.**

### OPERATIONS PHASE
*(placeholder)*

---

## Phase 2: Broadcasting & Transport

### INCEPTION PHASE
- [x] Workspace Detection — Brownfield; Phase 1 fully merged; caption bus exists; no reverse engineering needed
- [ ] Reverse Engineering — SKIPPED (codebase built by AI-DLC; design artifacts current)
- [x] Requirements Analysis — COMPLETE (approved); phase2-requirements.md (10 FRs, 8 NFR groups, 3 spikes as early construction units)
- [x] User Stories — COMPLETE (approved); phase2-stories.md (10 stories S-11..S-20, 3 security reviews SR-01..03, 6 prototypes Proto-10..15, 4 milestones) + phase2-personas.md (draft S3.6)
- [x] Workflow Planning — COMPLETE (approved); phase2-execution-plan.md (App Design EXECUTE, Units Generation EXECUTE; 3 spikes + 9 preliminary units; Operations SKIP)
- [x] Application Design — COMPLETE (approved); phase2-application-design.md + components, component-methods, services, component-dependency (zip_core-centric; role-specific transports; independent broadcast/captioning lifecycles with optional auto-start)
- [x] Units Generation — COMPLETE (approved); phase2-unit-of-work.md, -dependency.md, -story-map.md (3 spikes + 9 units; SR gates before CG in U2/U3/U4; one PR per unit; spike code throwaway)

**Phase 2 Inception — COMPLETE 2026-09-26.**

### CONSTRUCTION PHASE
- [x] Unit 1: UI Prototypes (Proto-10 through Proto-15) — COMPLETE 2026-09-25 (approved 2026-09-25); all 6 prototypes generated and individually approved. Unblocks Unit 2 (Proto-10), and independently unblocks Unit 8 (Proto-13); Units 6 and 7 still need Unit 5 in addition to their approved prototypes. See `aidlc-docs/construction/phase2-unit1-prototypes/code/unit1-summary.md`. PR #19 → `develop` merged 2026-09-26 (after rebase to resolve a conflict caused by PR #18's squash-merge).
- [ ] Spike 2.1: Broadcaster Fan-Out and Signaling Load — **PAUSED 2026-09-27** by user decision; branch `spike/2.1-broadcaster-fanout-signaling` left as-is (not merged; spike code never merges per Q5:A). Harness built, debugged, and validated end-to-end on macOS (N=25, N=50 real measurements, 4 N=50 runs total). Found and fixed 4 real harness bugs (macOS entitlements x2, `wrtc`→`node-datachannel` swap, native cleanup segfault). **Root cause narrowed, not confirmed**: join success rate degrades under concurrent load (N=50: 74-84% across runs) while the broadcaster reports 100% channels locally "open." Public-STUN-contention ruled out (local coturn test). Per-viewer state instrumentation showed 100% reach `ice: completed`/`pc: connected`; the stall is at the SCTP/DCEP data-channel-establishment layer, likely broadcaster-side. A channel-creation pacing experiment (50ms/150ms/unpaced) was inconclusive (no monotonic trend, single-run-per-config).
  - **Interim decisions (2026-09-27)**, all explicitly-revisable project constants/targets, none evidence-backed by this spike — implement as named constants/config, not literals, so they move without a redesign once real data exists (Unit 9's real-world capacity work, or a resumed Spike 2.1):
    - `BroadcastLimits.maxViewers = 50` — harness never saw 100% success even at N=50 (best: 84%).
    - `presenceTimeout = 60s` — from Phoenix Channels' documented 30s heartbeat default (2x, standard one-missed-heartbeat convention), not measured.
    - `reconnectWindow = 120s` — UX judgment call (covers a typical mobile network handoff without holding a capacity slot indefinitely), not measured.
    - NFR-1.3 join-to-first-caption ≤3s, reconnection ≤5s — aspirational targets from standard real-time-app UX thresholds, not measured.
  - **Realtime load test attempted, blocked**: fixed 7 real pre-existing bugs in the local Supabase stack along the way (docker-compose.yml migration-mount clobbering, 3 missing role passwords, a `_realtime`/`realtime` schema typo, 3 healthcheck tooling bugs, and a Kong↔Realtime hostname/network-alias mismatch — all now fixed in tracked files, independent of this spike). Stopped on an unresolved JWT signature validation issue in Realtime v2.76.5's compiled internals (`{:error, :signature_error}`) that further guessing couldn't responsibly resolve.
  - Remaining if resumed: repeated trials per pacing config for statistical confidence, or direct libwebrtc-side DCEP logging; `--dwellMs` methodology fix for sustained CPU/mem sampling; N=100/150/200; Windows/Linux leg; web leg; resolve the Realtime JWT issue (different image version, or trace the JWT verification path) then run the Realtime load test. See `aidlc-docs/construction/spikes/spike-2.1-report.md` (Next Steps section).
- [x] Unit 2: Broadcaster Auth (S-15, gated by SR-01) — Functional Design + SR-01 APPROVED 2026-09-28, on branch `feature/broadcaster-auth` (off `develop`). Providers: Google only for Phase 2. Desktop OAuth via external browser + custom URL scheme (`io.zipcaptions.broadcast://login-callback`); web via the SDK's default redirect. Token storage: `flutter_secure_storage`-backed on desktop, SDK default on web. `AuthState` carries `providerId` on `SigningIn`/`AuthFailed` (Phase 3 multi-provider readiness). New Rule 9: sign-out must be unreachable (not just disabled) while `BroadcastSessionState` is non-idle — enforced in Unit 6's `ZbAppShell` (sole call path to `AuthNotifier.signOut()`), not in this unit; see Backlog below. Artifacts: `aidlc-docs/construction/broadcaster-auth/functional-design/`. **Correction 2026-09-28 (found at Code Generation)**: `app_links` is not a new dependency of this unit — reading `supabase_flutter`'s source confirmed it already bundles and wires `app_links` internally on every non-web platform; the SR-01/NFR Requirements/NFR Design artifacts and the Code Generation plan were corrected in place (no `app_links` line added to any `pubspec.yaml`, no app-level listener written; only the OS-level custom-scheme registration remains necessary).
  - [x] NFR Requirements — APPROVED 2026-09-28. `flutter_secure_storage ^9.2.2` (matches existing app-wide pin) version-locked; PBT reuses the existing Dart-3-compatible shim (`test/helpers/pbt.dart`), not the incompatible real `glados`; `mocktail` + a hand-written fake `AuthService` for testing; no crash-reporting SDK (Backlog). Security Baseline: 8 Compliant, 6 N/A (infra-owned by `zip_supabase` units), 1 N/A-with-Backlog-note. PBT: all 10 rules Compliant/Compliant-planned. No blocking findings. Artifacts: `aidlc-docs/construction/broadcaster-auth/nfr-requirements/`.
  - [x] NFR Design — APPROVED 2026-09-28. Abandoned-sign-in resolution: 2s foreground-resume grace window + 3-minute hard timeout backstop, both mapping to `AuthFailed(providerId, cancelled)`. `SecureDesktopLocalStorage` placed in `zip_core` (Phase 3 reuse, FR-1.1). No app-level OAuth-redirect listener exists (corrected — `supabase_flutter` handles this internally). Single no-credentials-logging chokepoint identified for Code Gen review. Artifacts: `aidlc-docs/construction/broadcaster-auth/nfr-design/`.
  - [x] Code Generation Part 1 (Planning) — APPROVED 2026-09-28, corrected same day (see above). 22-step plan at `aidlc-docs/construction/plans/broadcaster-auth-code-generation-plan.md`. Delegation split (local-only, not tracked): 2 steps to Qwen (PBT command generator; sign-in view + its widget tests + provider config), 20 kept by Claude (security-sensitive or cross-package-contract work). Part 2 (generation) starting.
  - [x] Code Generation Part 2 (Generation) — COMPLETE 2026-09-29. All 22 plan steps done; 364/101/71 tests passing (zip_core/zip_broadcast/zip_captions), all four packages `dart analyze --fatal-infos` clean. Two design corrections found and fixed during API verification before Qwen delegation (see audit.md); one real production bug found and fixed via actually running tests (`authStateChanges` subscribe race, fixed with `Stream.multi`). Delegation to Qwen for the sign-in UI (Steps 15-17) crashed twice with an identical backend error; escalated and implemented directly. PR #22 opened against `develop`; CI's Linux build-verify job failed (missing `libsecret-1-dev` on the runner, fixed in `.github/workflows/build-verify.yml`); CodeRabbit's automated review then found two real issues, both fixed — a mismapped `AuthFailure` in the desktop callback-URI handler (contradicted the unit's own approved SR-01 §7 design) and a missing `authServiceProvider` override in `zip_broadcast`'s `main.dart` (would have crashed on first use) plus `AccountSection` never being composed into a reachable screen (now in `SettingsScreen`). **PR #22 approved and merged to `develop`** 2026-09-29 (squash merge `6a757fd`). **Known gap**: Windows OAuth redirect registry registration and the Linux GTK runner patch are not implemented (macOS is complete) — see Backlog. Artifacts: `aidlc-docs/construction/broadcaster-auth/code/unit2-summary.md`.

**Current Stage**: CONSTRUCTION Phase 2 — Unit 2 (Broadcaster Auth) FULLY COMPLETE: PR #22 approved and merged to `develop` (squash merge `6a757fd`, 2026-09-29). Local `feature/broadcaster-auth` branch deleted post-merge (remote already auto-deleted). Per the dependency matrix, Unit 3 (Broadcast Identity + Signaling) depends on Unit 2 (done) and Spike 2.1 (paused, interim values already accepted) — not yet started. Spike 2.1 remains paused on branch `spike/2.1-broadcaster-fanout-signaling`; not blocking.

#### Backlog (Deferred Scope)
- **Caption attribution / speaker-name prefix on captions**: raised during Proto-12 review 2026-09-25. Phase 1 (S-06) already scopes a per-audio-input `speakerLabel` + visual style (color/indicator) on `AudioInputConfig`, applied by the on-screen renderer (`phase1-services.md` §7). Not yet scoped: whether the speaker label should be *prepended as text* to the caption content itself (e.g. "Teacher: ...") rather than only conveyed via color/indicator, and whether a broadcaster can set a label distinct from the raw input device name specifically for this purpose. Out of scope for Unit 1 (prototypes) and not implemented in `zip-broadcast-dashboard.html`. Revisit at Unit 6 (Zip Broadcast Broadcast UI) Functional Design, since it may touch shared `zip_core` caption rendering (used by both apps), not just zip_broadcast-specific UI.
- **Pop out live captions into a small floating window (Zip Captions viewer)**: raised during Proto-15 review 2026-09-25. Not in S-19's acceptance criteria, FR-7.1–7.6, or `BroadcastViewerScreen`'s component design (`phase2-components.md`), which renders captions inline only. User clarified intent: a small floating/PiP-style caption window, not a full separate app window — closer to browser Picture-in-Picture than to the desktop multi-window overlay Unit 8 builds for broadcasters (`OverlayWindowApp`). Not implemented in `zip-captions-viewer-states.html`. Revisit at Unit 7 (Zip Captions Viewer) Functional Design: if it needs a new dependency (e.g. a PiP/windowing plugin), FR-9.5 requires human approval and a supply-chain justification before it's added; web (browser Document Picture-in-Picture API) and desktop may need different mechanisms.
- **Sign-out must be unreachable while the broadcast session is non-idle**: raised during Unit 2 (Broadcaster Auth) Functional Design review 2026-09-28, scope narrowed 2026-09-28 (deliberately *not* widened to "any active captioning" — local captioning/transcripts/OBS/browser-source/external-display stay decoupled from auth per FR-1.4/F-BA-5, since blocking sign-out there would add friction with no corresponding risk). `AuthNotifier.signOut()` in `zip_core` stays unconditional by design — it has no visibility into broadcast state, and must stay reusable by Zip Captions (FR-1.1), which never broadcasts. The guarantee is a **mandatory Unit 6 (Zip Broadcast Broadcast UI) requirement**: `ZbAppShell` must be the sole call path to `AuthNotifier.signOut()` within `zip_broadcast`, gated by a check against `BroadcastSessionState` (Unit 6) that refuses the call outright while non-idle (live **or** mid-`goLive()` transition, per the 9-step sequence in `phase2-services.md` F2, to close the race before the state formally reaches `live`) — not a disabled-button-only guard, which other call paths could bypass. See `aidlc-docs/construction/broadcaster-auth/functional-design/business-rules.md` Rule 9 and `business-logic-model.md` F-BA-3. Revisit at Unit 6 Functional Design.
- **Windows/Linux OAuth redirect registration incomplete**: raised during Unit 2 (Broadcaster Auth) Code Generation, 2026-09-29. macOS's `CFBundleURLTypes` registration for `io.zipcaptions.broadcast://` is complete and confirmed sufficient (custom URL schemes on macOS don't need the `AppDelegate.swift` universal-links code path). Windows has `app_links`'s documented `main.cpp` integration point (`SendAppLinkToInstance()`), but the actual registry key registration is not implemented — `app_links`'s own docs describe this as an app-runtime registration via the `win32_registry` package (a new dependency, not yet added or approved), not something the plugin does automatically. Linux was not attempted at all: the required GTK runner patch (`linux/my_application.cc`) was only described narratively in the documentation fetched, not shown as a verbatim diff, and hand-writing unverifiable native C code with no Linux build available here was judged too risky. Revisit before shipping OAuth sign-in on Windows or Linux: decide on the `win32_registry` dependency (Section 6 justification) for Windows, and apply/verify the actual GTK patch on a real Linux build for Linux. Until resolved, S-15's remote-broadcast sign-in only works on macOS and web.
- **Crash/error-reporting SDK (e.g. Sentry) — project-wide, not yet adopted**: raised during Unit 2 (Broadcaster Auth) NFR Requirements 2026-09-28, discussing where the `providerError` catch-all's logged exception type/stack trace (SR-01 Section 7, `business-rules.md` Rule 9) actually goes. Decided against adopting one now: the project has no crash-reporting dependency anywhere today, and scoping one in just to cover this unit's auth catch-all would make a project-wide infrastructure decision (new third-party data flow — device metadata, stack traces — leaving the device; a call that affects every unit, not just auth) look like a narrow, already-settled one. For now, unmapped exceptions are logged only via the existing local `logging` package (device/console-only, per `packages/zip_broadcast/lib/main.dart`'s existing `Logger` setup) — no aggregation, no field visibility into how often real bugs are hiding behind `providerError` in production. Revisit if/when the project adopts crash reporting generally (worth reconsidering after beta, when there's an actual felt need for production error visibility) — at that point, wire the auth catch-all (and any other unit's swallowed-exception logging) into it rather than deciding it unit-by-unit.

