# Handoff: NFR Design -> Infrastructure Design
**Unit**: broadcast-identity-signaling
**Date**: 2026-09-30

## Decisions Made
- New `BroadcastAuthorizationException` (`zip_core`) wraps any RLS/permission-denied rejection from Postgres or Realtime, distinct from a plain network failure.
- **Design correction**: `BroadcastResolution` gains a fifth variant, `ResolutionFailed` (a step-2 presence-read failure/timeout), kept distinct from `Offline` (now specifically "the read completed and found nothing"). This extends the shape fixed at Application Design — done within this unit before Code Generation, not deferred. `domain-entities.md`, `sr-02-rls-realtime-policy.md` §2, and `business-logic-model.md` F-BIS-2 all updated. Backlog entry added for Unit 7 to decide its rendering.
- Package placement: `zip_supabase` gets only the SQL migration (not a Dart package); all Dart code lives in `zip_core`, mirroring Unit 2's `SupabaseAuthService` precedent exactly.
- Full component table and dependency-direction diagram fixed in `logical-components.md`.

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
| `broadcast_identities` migration | SQL | Table/RLS/functions exactly as specified in SR-02 §1/§3 — Infrastructure Design writes the literal migration file against this spec, doesn't re-decide it |
| Kong rate-limit config | infra | 30 req/min + burst target (NFR Requirements Q1) — Infrastructure Design writes the actual declarative config, matching this project's existing Kong setup format |
| `BroadcastAuthorizationException` | exception | New type — Code Generation should use it consistently in both `SupabaseBroadcastIdentityRepository` and `SupabaseSignalingService`, not just one |
| `BroadcastResolution.ResolutionFailed` | sealed variant | New — Code Generation must implement the step-2-failure detection distinctly from step-2-clean-empty-result |

## Constraints
- Infrastructure Design must read this project's *existing* Kong declarative config (from Phase 0/Spike 2.1 infra work) before writing new rate-limit rules — don't invent a new config format.
- No Dart code in `zip_supabase` — if Infrastructure Design finds itself wanting to write Dart there, that's a sign something's misplaced.
- `ResolutionFailed`'s Unit 7 consumption is explicitly not this unit's or this stage's to design — Backlog item only.

## Open Questions for Next Stage
- Exact Kong declarative-config syntax for the 30 req/min + burst target (Infrastructure Design's own job to resolve, not pre-answered here).
- Whether the migration needs a down-migration/rollback script, or whether this project's forward-only convention (confirmed in `docs/04-technical-specification.md` Section 9) means none is needed — Infrastructure Design should confirm against existing migration precedent (the Phase 0 initial migration has none).
