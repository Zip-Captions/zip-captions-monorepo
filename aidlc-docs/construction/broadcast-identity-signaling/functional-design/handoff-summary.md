# Handoff: Functional Design -> NFR Requirements
**Unit**: broadcast-identity-signaling
**Date**: 2026-09-29

## Decisions Made
- Registry table: `broadcast_identities` (`id`, `owner_id` unique FK to `auth.users`, `broadcast_id` unique text, `created_at`, `updated_at`). RLS: owner-only `SELECT`/`INSERT`, no `anon` policy, no `UPDATE`/`DELETE` in Phase 2.
- Broadcast ID: Crockford Base32, 6 chars, server-generated via `pgcrypto`, collision-retried.
- Anonymous resolution is split: a `SECURITY DEFINER` RPC (`resolve_broadcast_id`, boolean-only return) answers existence; live/offline status is a separate client-side presence read on `status:{broadcast_id}` — Postgres never answers "is it live."
- Enumeration control: Kong gateway rate-limiting on the RPC's PostgREST route, exact config deferred to this unit's own Infrastructure Design stage.
- Realtime authorization: Supabase's native `realtime.messages` RLS (`extension`/`topic`-scoped), `private: true` channels required. Full policy table in `sr-02-rls-realtime-policy.md` §4. Message-*type* authorization (e.g. only the broadcaster sends `BroadcastEnded`) is explicitly Unit 5's job, not RLS-expressible.
- Capacity/admission (`ViewerAdmission`) is explicitly out of scope — Unit 5's component.
- `BroadcastResolution.RateLimited` is unreachable until Kong's rate limit exists; kept in the sealed type regardless (already fixed at Application Design).

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
| `broadcast_identities` | table | RLS as specified in SR-02 §1 — no `anon` policy, ever, on this table directly |
| `resolve_broadcast_id` | SQL function | `SECURITY DEFINER`, returns bare `boolean` only — never add columns to its return shape |
| `get_or_create_my_broadcast_id` | SQL function | `SECURITY INVOKER`, relies on RLS, not elevated privilege |
| Realtime RLS policies | `realtime.messages` policies | Must be paired with `private: true` channel creation client-side — one without the other is a silent no-op security hole |
| `SignalingCodec` | codec | Single chokepoint for the never-throws invariant (Rule 4) — NFR Requirements/Code Generation should audit exactly this one boundary |

## Constraints
- No RLS policy on `broadcast_identities` may grant `anon` any access (Rule 3) — the only anonymous-facing surface is the boolean-only RPC.
- Kong rate-limit configuration is Infrastructure Design's job for this unit, not Functional Design's or NFR Design's — don't re-decide it earlier.
- Message-type-level signaling authorization (who may send what) is Unit 5's responsibility, informed by but not implemented in this unit.
- `viewerIdentity` stays `null` everywhere in this unit's Phase 2 code paths (Rule 7).

## Open Questions for Next Stage
- Exact Kong rate-limit threshold/window for `resolve_broadcast_id` — NFR Requirements or Infrastructure Design should propose concrete numbers (not fixed here).
- Whether `get_or_create_my_broadcast_id`'s bounded retry count needs a specific NFR (e.g. "P99 allocation latency under N ms at collision rate X") — flagged for NFR Requirements to consider, not decided here.
