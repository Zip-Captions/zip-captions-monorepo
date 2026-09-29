# Handoff: NFR Requirements -> NFR Design
**Unit**: broadcaster-auth
**Date**: 2026-09-28

## Decisions Made
- No numeric sign-in latency target (OAuth is externally paced); `SigningIn` must render within one UI frame of the tap.
- Session restore at app start must not block on a network round trip (restated as a hard NFR from F-BA-2).
- `flutter_secure_storage ^9.2.2` (matches existing app-wide pin) is the version constraint to carry into Code Generation. **Corrected 2026-09-28**: `app_links` is not a separate dependency — it ships inside `supabase_flutter`, confirmed from source at Code Generation.
- Test doubles: `mocktail` for interaction assertions, a hand-written fake `AuthService` for the stateful PBT.
- PBT framework: reuse `packages/zip_core/test/helpers/pbt.dart` (the existing Dart-3-compatible shim), not the real `glados` package — add one new generator (`AuthCommand` sequences) to `test/helpers/generators.dart`.
- No crash-reporting SDK in this unit (logged locally via `logging` only) — Backlog item recorded for a future project-wide decision.
- Security Baseline: 8 rules Compliant, 6 N/A (server/infra-owned, out of this unit's scope), 1 N/A-with-Backlog-note (SECURITY-14, pending the crash-reporting decision).
- PBT: all 10 rules Compliant or Compliant-planned; PBT-08's shrinking is framework-limited (seeded reproducibility, no true shrink-to-minimal) — an accepted, pre-existing limitation from Phase 1, not new here.

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
~~`app_links` | new dependency~~ | **Corrected 2026-09-28**: internal to `supabase_flutter`, not a dependency this unit adds. |
| Fake `AuthService` | test helper | Must support a driven sequence of `authStateChanges` emissions for the stateful PBT — a `mocktail` mock cannot do this |
| `AuthCommand` generator | test helper | New addition to `test/helpers/generators.dart`; must weight realistic sequences (PBT-07), not uniform-random enum picks |

## Constraints
- No crash-reporting/error-aggregation service may be introduced in this unit — `providerError` logging stays local-only (`logging` package) per Q3.
- Dependency versions must not drift from what's recorded here without re-checking SECURITY-10 compliance (pinning, trusted registry).
- PBT-08's framework-level shrinking limitation (seeded reproducibility, no automatic minimal-case shrink) is accepted as-is — NFR Design should not attempt to introduce a different PBT framework to fix this mid-unit; it's a project-wide characteristic, not specific to this unit.

## Open Questions for Next Stage
- None carried forward from NFR Requirements itself. Carried from Functional Design (still open, not this stage's to resolve): whether an already-live broadcast is force-ended on sign-out (Unit 5's call, per F-BA-3); the Unit 6 sign-out guard implementation itself (Rule 9, Backlog).
