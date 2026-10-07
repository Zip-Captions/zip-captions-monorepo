# Code Generation Plan: Signaling Channel Privacy (Unit 3.1)

**Prior stage**: NFR Design, approved 2026-10-06 | **SR-04**: signed off at Functional Design

## Scope

The channel primitives and migration only: `LobbyChannel`, revised
`SessionSignalingChannel`/`SignalingService`, and their Supabase implementations, plus
the migration replacing Unit 3's superseded RLS policies. **Not in scope**: the
viewer-side join-sequence orchestration (the 2s/5s/10s `JoinRequest` resend,
`nfr-design-patterns.md`'s Resilience section) — that logic lives in Unit 5's
`WebRtcViewerTransport.connect()`, which doesn't exist yet (Unit 5 is paused). This
unit ships the primitives Unit 5 will call; it does not implement Unit 5's own
orchestration ahead of Unit 5 resuming.

## Steps

### `packages/zip_supabase/` (migration)

1. [x] New forward-only migration (`20261006000000_signaling_channel_privacy.sql`):
   drops the 4 superseded `signaling:{session_id}` broadcast/presence RLS policies;
   adds per-viewer policies (open INSERT+SELECT) per SR-04 §3. **Revised 2026-10-06**:
   the originally-planned lobby policies (`signaling:%:lobby` on `realtime.messages`)
   were replaced before shipping — see Step 2 below — with a `broadcast_join_requests`
   table (open INSERT; ownership-checked SELECT/DELETE against `broadcast_identities`)
   plus `submit_join_request`/`consume_join_request` `SECURITY INVOKER` functions and
   `ALTER PUBLICATION supabase_realtime ADD TABLE broadcast_join_requests` (confirmed
   necessary by testing — Postgres Changes delivers nothing without it, even with RLS
   and `REPLICA IDENTITY FULL` correct). No presence policy on either new pattern.

### `packages/zip_core/` (Dart)

2. [x] **Revised 2026-10-06** — `LobbyChannel`/`SupabaseLobbyChannel` (originally
   planned here) were implemented, then found unworkable by Step 11's real-backend
   test: Realtime's `subscribe()` rejects the entire channel join for any client
   lacking a SELECT grant, regardless of receive intent, so a send-only viewer could
   never open it. Removed entirely, along with their unit test. Replaced by plain
   methods on `SignalingService` (Step 6) backed by an RPC call and a Postgres Changes
   subscription — no channel object for the join-request step at all.
3. [x] ~~`supabase_lobby_channel.dart`~~ — removed (see Step 2).
4. [x] `lib/src/services/signaling/session_signaling_channel.dart` — revised: dropped
   `presence` getter; `SignalingService.sessionChannel`'s new signature takes `peerId`
   instead of `role`.
5. [x] `lib/src/services/signaling/supabase_session_signaling_channel.dart` — revised:
   dropped `track()`/`onPresenceSync` wiring entirely; keyed by `(sessionId, peerId)`.
6. [x] `lib/src/services/signaling/signaling_service.dart` /
   `supabase_signaling_service.dart` — **revised 2026-10-06**: added
   `submitJoinRequest(BroadcastId, String)` (viewer-only, a thin RPC wrapper) and
   `joinRequests(BroadcastId)` (broadcaster-only, a `Stream.multi` wrapping
   `onPostgresChanges` on `broadcast_join_requests`, internally calling
   `consume_join_request` once a row is forwarded downstream) in place of the
   originally-planned `lobbyChannel(BroadcastId)`; `statusChannel`/`sessionChannel`
   unchanged.
7. [x] `lib/src/services/signaling/signaling.dart` barrel — `SignalingRole` removed
   (nothing else referenced it); `LobbyChannel`/`SupabaseLobbyChannel` exports added
   then removed again in the 2026-10-06 revision (Step 2).
8. [x] `lib/src/models/peer_id.dart` — `peerId()` top-level generator function (v4 UUID,
   122 bits of randomness, plain `String` return, no new model class).
9. [x] `lib/src/providers/signaling_service_provider.dart` — no change needed;
   `SupabaseSignalingService`'s constructor is unchanged (`client` only).

### Tests

10. [x] Dart-side unit tests (fakes/mocktail, mirroring Unit 3's own
    `SessionSignalingChannel` fake precedent). Originally `SupabaseLobbyChannel` (4
    tests), delegated to Qwen (`u3.1-s10`) and accepted with one minor fix — removed
    along with the class itself in the 2026-10-06 revision (Step 2). Replaced by
    `SupabaseSignalingService.submitJoinRequest`/`joinRequests` tests (RPC-call
    assertion via the `_ImmediateBuilder<T>` mocking pattern from
    `supabase_broadcast_resolver_test.dart`; `onPostgresChanges` subscription/filter
    assertion), plus the existing `SupabaseSessionSignalingChannel`/
    `SupabaseSignalingService` tests updated for the revised signatures.
11. [x] **The load-bearing test** (NFR Requirements Q4): a real-backend integration
    test, tagged `integration-supabase`. **Revised 2026-10-06** along with the
    mechanism itself: confirms (a) the real broadcast owner receives a join request
    submitted via `submit_join_request` by a viewer client; (b) a different
    authenticated user's `joinRequests` subscription succeeds but receives nothing for
    a broadcast it doesn't own (RLS filters the Postgres Changes stream — a different
    failure mode than the original Broadcast-extension design's outright subscription
    rejection); (c) anon can call `submit_join_request` with no subscription step at
    all; (d) two distinct per-viewer channels for the same `sessionId` never
    cross-deliver messages (unaffected by the revision). All 4 pass against the real
    local stack. One additional real-stack-only requirement surfaced and was fixed:
    `broadcast_join_requests` had to be added to the `supabase_realtime` publication
    before Postgres Changes delivered anything at all.
12. [x] Manual verification (NFR Requirements Q1) — `signaling_channel_capacity_supabase_test.dart`:
    opened 51 concurrent `SupabaseSessionSignalingChannel` subscriptions from one
    client against the real local stack; all 51 reached `subscribed`, none silently
    dropped. Confirms the assumption; no fallback needed.

### Verification

13. [x] `dart analyze --fatal-infos` clean in `zip_core`.
14. [x] All new + existing `zip_core` tests passing (407 unit/PBT tests + 2 skip-by-default
    real-backend integration suites, manually run and confirmed passing against the
    live local stack).

## Delegation Note

Per this project's standard process, Part 2 (generation) proceeds after this plan is
approved.

## Traceability

| Step | FR/NFR |
|---|---|
| 1 | SR-04 §3 |
| 2–9 | SR-04 §6 (interface refinement); NFR Design Q1 resilience spec informs Unit 5's future caller, not this unit's own code |
| 10 | NFR Requirements Q4 (unit-test half) |
| 11 | NFR Requirements Q4 (the real-stack half — the actual proof) |
| 12 | NFR Requirements Q1 |
| 13–14 | Project-wide `dart analyze`/test conventions |
