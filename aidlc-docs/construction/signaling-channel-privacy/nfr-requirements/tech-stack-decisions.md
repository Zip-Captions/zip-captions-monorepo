# Tech Stack Decisions — Signaling Channel Privacy (Unit 3.1)

## No New Dependencies

This unit introduces no new Dart package and no new Postgres extension. The migration
uses only RLS policies (no new `SECURITY DEFINER`/`INVOKER` function); `LobbyChannel`/
`SessionSignalingChannel`'s revised implementations are built on the same
`supabase_flutter` APIs Unit 3 already uses (`channel()`, `onBroadcast`,
`sendBroadcastMessage`, `subscribe`).

## Migration Shape

New forward-only migration (does not edit `20261001000000_broadcast_identity_signaling.sql`):
drops the three presence-related RLS policies on `signaling:{session_id}` (NFR
Requirements Q3/SR-04 §4 — presence dropped entirely) and the two `signaling:{session_id}`
broadcast policies (superseded by the lobby/per-viewer split), adding the new policies
specified in SR-04 §3. The old `signaling:{session_id}` broadcast policies are replaced,
not left dangling — a topic pattern no code now uses should not keep a live RLS grant.

## Channel-Count Verification (NFR Requirements Q1)

Before this unit's Code Generation closes: a direct test against the real local
Supabase stack opening 50+ concurrent private channel subscriptions from one
`supabase_flutter` client (simulating the broadcaster's worst case at the interim cap),
confirming none are silently dropped. Documented here as a required Code Generation
step, not assumed from `RealtimeClient`'s documented multiplexing behavior alone.

## Test Double Strategy (NFR-7.3)

- **Dart-side unit tests**: hand-written fakes for `LobbyChannel`/
  `SessionSignalingChannel`, matching Unit 3's own `SessionSignalingChannel` fake
  precedent (stateful — message streams, not simple call-assertion mocks). `mocktail`
  remains available for simpler interaction assertions.
- **The one real-backend integration test this unit needs** (NFR Requirements Q4):
  two concurrently-connected real viewer clients plus one broadcaster client against
  the local Supabase stack, tagged `integration-supabase` (skip-by-default, Unit 3's
  convention) — the only way to actually prove the RLS isolation holds, since a fake
  can't demonstrate anything about whether the real policies work.

## Framework Reuse

No new PBT suite (NFR Requirements Q6) — this unit has no new pure-Dart property to
test; `packages/zip_core/test/helpers/pbt.dart` is unused by this unit specifically but
remains the project's framework for any unit that does need it.
