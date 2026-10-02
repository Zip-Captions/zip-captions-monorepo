# Handoff: Infrastructure Design -> Code Generation
**Unit**: broadcast-identity-signaling
**Date**: 2026-09-30

## Decisions Made
- Kong: new `rest-v1-resolve-broadcast-id` service + route (`/rest/v1/rpc/resolve_broadcast_id`), split out of the catch-all `rest-v1` route, carrying the same `cors`/`key-auth`/`acl` plugins plus a new `rate-limiting` plugin (`limit_by: ip`, `minute: 30`, `second: 2`, `policy: local`, `fault_tolerant: true`) — implements NFR Requirements Q1's 30/min + burst target without affecting any other REST/RPC traffic.
- Migration: forward-only, no down/rollback script, matching the project's sole existing migration and `docs/04-technical-specification.md` §9.
- No change to Unit 4's existing service topology, port mapping, volumes, or environment variables — this unit adds to the stack, doesn't reshape it.

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
| `rest-v1-resolve-broadcast-id` Kong service/route | infra config | Code Generation edits `packages/zip_supabase/volumes/api/kong.yml` to add exactly this block; does not touch any other service's config |
| `<timestamp>_broadcast_identity_signaling.sql` | SQL migration | Code Generation writes the literal migration file against SR-02 §1/§3's spec — table, RLS policies, `resolve_broadcast_id`, `get_or_create_my_broadcast_id`; no down script |

## Constraints
- Kong config change is additive only — do not modify `rest-v1`'s existing route/plugins; the new, more specific route takes priority by path length, so `rest-v1` continues serving every other REST/RPC call unchanged.
- Migration filename must sort after `20260326000000_initial.sql` (standard Supabase CLI timestamp-prefixed convention) — Code Generation picks the actual timestamp.
- Verify the Kong rate limit and the migration's RLS/function behavior via integration tests against the local Supabase stack (`packages/zip_supabase`), not unit tests alone — this is infra/SQL behavior, not Dart logic.

## Open Questions for Next Stage
None — both Infrastructure Design questions (Kong config shape, rollback script) are resolved. Code Generation proceeds directly from this document, SR-02, and `logical-components.md`.
