# Tech Stack Decisions — Broadcast Identity + Signaling (Unit 3)

## No New Dependencies

This unit introduces no new Dart package and no new Postgres extension — `pgcrypto` is
already enabled by the Phase 0 initial migration (`20260326000000_initial.sql`), which
is what `get_or_create_my_broadcast_id`'s random-byte generation needs (SR-02 §3).
`SupabaseSignalingService`/`SupabaseBroadcastIdentityRepository` are built on
`supabase_flutter`, already a `zip_core` dependency since Unit 2.

## SQL Function Language

- `resolve_broadcast_id`: plain `sql` (not `plpgsql`) — it's a single `select exists(...)`
  expression with no branching, so the simpler language is sufficient and (per Postgres
  convention) can be planner-inlined more readily than a `plpgsql` function.
- `get_or_create_my_broadcast_id`: `plpgsql` — needs a loop (collision retry) and
  exception handling (`unique_violation`), which `sql`-language functions can't express.

## Rate Limiting (Q1)

Kong route-level rate limiting on `/rest/v1/rpc/resolve_broadcast_id`: 30 requests/minute
per IP, ~10-request burst allowance in the first 5 seconds (NFR Requirements Q1). Exact
Kong plugin configuration (`kong.yml` or declarative config, matching this project's
existing Kong setup from the Phase 0/Spike 2.1 infrastructure work) is finalized at this
unit's own Infrastructure Design stage — this document fixes the target numbers, not the
YAML.

## Test Double Strategy (NFR-7.3)

- **Dart-side unit tests**: hand-written fakes for `BroadcastIdentityRepository`,
  `BroadcastResolver`, and `SignalingService`/`StatusChannel`/`SessionSignalingChannel`
  (matching Unit 2's `FakeAuthService` precedent — a fake, not a `mocktail` mock, since
  these need to hold and emit state across a sequence: presence changes, message
  streams). `mocktail` remains available for simpler interaction assertions (e.g. "was
  `publishLive` called with these arguments") where a fake's statefulness isn't needed.
- **SQL-side integration tests**: run against the local Supabase stack (already
  operational since Phase 0/Unit 4), exercising the real `broadcast_identities` table,
  RLS policies, and both SQL functions — not mocked. This is the only way to actually
  verify a unique-constraint collision retry or an RLS policy rejection behaves as
  designed, per `testable-properties.md`'s stateful/integration-property split.

## Framework Reuse

PBT framework: `packages/zip_core/test/helpers/pbt.dart` (the existing Dart-3-compatible
shim), same as every prior unit — no new decision needed here.
