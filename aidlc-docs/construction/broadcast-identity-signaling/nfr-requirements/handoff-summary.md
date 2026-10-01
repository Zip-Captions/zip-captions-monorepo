# Handoff: NFR Requirements -> NFR Design
**Unit**: broadcast-identity-signaling
**Date**: 2026-09-30

## Decisions Made
- Kong rate limit for `resolve_broadcast_id`: 30 req/min per IP, ~10-request burst allowance — a concrete target, exact Kong config still at Infrastructure Design.
- No formal latency NFR for `get_or_create_my_broadcast_id` — its 10-attempt retry bound is a fail-safe, not a performance target.
- `resolve_broadcast_id` is `sql`-language; `get_or_create_my_broadcast_id` is `plpgsql` (needs loop + exception handling).
- Test doubles: hand-written fakes for the Dart-side interfaces (Unit 2's `FakeAuthService` precedent), real integration tests against the local Supabase stack for anything RLS/constraint-dependent.
- Security Baseline: 8 Compliant, 6 N/A (platform/other-unit-owned), 1 N/A-with-Backlog-note (alerting, same project-wide item as Unit 2's). PBT: 7 Compliant/Compliant-planned, 3 N/A with rationale (no pure-Dart stateful PBT for database-constraint behavior).

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
| `resolve_broadcast_id` | SQL function | `sql`-language, `SECURITY DEFINER`, boolean-only return — do not widen its return shape |
| `get_or_create_my_broadcast_id` | SQL function | `plpgsql`, `SECURITY INVOKER`, 10-attempt bounded retry, raises on exhaustion |
| Kong rate-limit config | infra config | 30/min per IP + burst — Infrastructure Design implements against this number |
| Dart-side fakes | test helpers | Stateful fakes (not `mocktail` mocks) for repository/resolver/signaling interfaces |

## Constraints
- No SECURITY-01/02/07 work belongs in this unit — those are platform/Unit 4/5-owned; don't re-litigate them here.
- The two stateful properties (registry uniqueness/reuse) are integration-test territory against the real local stack, not something to force into the in-process PBT shim.
- Kong's exact declarative config format must match whatever this project's existing Kong setup already uses (from Phase 0/Spike 2.1 infra work) — Infrastructure Design should read that existing config before writing new rules, not invent a new format.

## Open Questions for Next Stage
- None new from NFR Requirements. Still open from Functional Design (not this stage's to resolve): the exact Kong declarative-config syntax (Infrastructure Design); whether `BroadcastResolution.RateLimited` needs any Dart-side test coverage before Kong's rate limit actually exists (likely just an explicit "N/A until Infrastructure Design" note, to be confirmed there).
