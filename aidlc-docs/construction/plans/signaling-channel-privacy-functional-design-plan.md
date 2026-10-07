# Functional Design Plan: Signaling Channel Privacy (Unit 3.1)

**Story**: S-13.1, gated by SR-04 (Signaling Channel Isolation Review)
**Packages**: zip_supabase (migration), zip_core (`SignalingService`/`SessionSignalingChannel`)
**Inserted into the roadmap**: 2026-10-05, after Units 3/4 shipped — see
`phase2-unit-of-work.md`'s Unit 3.1 entry for the full finding.

## Context

Confirmed by reading the shipped code directly: every viewer's own official
`SupabaseSessionSignalingChannel.presence` returns every other participant's presence on
`signaling:{session_id}`, and `onBroadcast` forwards every `SignalingMessage` (including
other viewers' `SdpOffer`/`IceCandidate`, which carry real network metadata) to every
subscriber, with no recipient filtering. This unit replaces the single shared channel
with per-viewer isolation, confirmed against both Supabase's own Presence documentation
("use separate channels for different user groups" — no built-in per-subscriber
filtering exists) and AWS Kinesis Video Streams WebRTC's "master/viewer" signaling
model as production precedent.

**Does not reopen Unit 3.** Ships as new code only — a new migration and a revised
`SignalingService`/`SessionSignalingChannel` in `zip_core` — the same precedent as
`20261001000001_fix_jwt_secret_mismatch.sql`.

**Read directly from the existing migration** (`20261001000000_broadcast_identity_signaling.sql`):
the `broadcast` extension's INSERT and SELECT are already **separate** RLS policies on
`realtime.messages` — confirming Realtime's authorization model can distinguish "may
publish" from "may subscribe/receive" on the same topic pattern. This is what makes a
broadcaster-only lobby channel possible at the RLS layer (Q2).

## Planned Steps

- [ ] Lobby channel: keying scheme and RLS (how the broadcaster alone can read it)
- [ ] Per-viewer channel: naming, entropy, RLS
- [ ] Channel lifecycle: who opens what, when, and the join-sequencing race
- [ ] Presence: keep, scope, or drop
- [ ] `SignalingService`/`SessionSignalingChannel` interface shape
- [ ] Flag the one open technical unknown for empirical verification at Code Generation
- [ ] Generate `business-logic-model.md`, `business-rules.md`, `domain-entities.md`

## Lobby Mechanism

**Revised 2026-10-06, before Code Generation shipped/committed.** The original Q1/Q2
answers below (a Realtime Broadcast-extension channel, `signaling:{broadcast_id}:lobby`,
with an owner-restricted SELECT policy) were approved on 2026-10-05 and partially
implemented, but **confirmed unworkable by direct testing at Code Generation Step 11**:
Realtime rejects the entire `subscribe()` call — not just individual messages — for any
client lacking a matching `SELECT` policy on the topic, regardless of whether that
client ever wires `onBroadcast`. A viewer that only intends to *send* a `JoinRequest`
still cannot open the channel at all under an owner-restricted SELECT policy — there is
no send-only subscription mode in Realtime's broadcast-authorization model. (`httpSend`,
a REST path that bypasses `subscribe()` entirely, would sidestep this, but requires
Realtime server ≥v2.97.0; this project's self-hosted image is v2.76.5, confirmed via a
direct version-gate error.)

Since nothing for this unit is committed, this section is revised in place rather than
tracked as a separate addendum — the original Q1/Q2 reasoning is replaced below, and the
`audit.md` trail (append-only) retains the record of what was tried and why it changed.

### Q1 (revised): How does a viewer submit a `JoinRequest` without ever subscribing to anything?

- A. Drop the Realtime Broadcast-extension lobby channel entirely. Add a table
  `broadcast_join_requests` (`id uuid default gen_random_uuid()`, `broadcast_id text`,
  `peer_id text`, `created_at timestamptz default now()`) and a `SECURITY INVOKER`
  function `submit_join_request(p_broadcast_id text, p_peer_id text)` that inserts a row
  — `INVOKER` because no privileged lookup is needed, matching
  `get_or_create_my_broadcast_id`'s own reasoning for using `INVOKER` wherever elevated
  privilege isn't actually required. A viewer calls this RPC directly — it never
  subscribes to anything for this step, so there is no SELECT grant to get wrong. The
  broadcaster subscribes to its own `broadcast_join_requests` rows via Realtime's
  **Postgres Changes** feature (CDC-based, governed by the table's own standard RLS — a
  different, longer-established Realtime mechanism than the Broadcast-extension
  authorization that just failed), filtered to its own `broadcast_id`. This mirrors the
  pattern this project has already proven works twice
  (`get_or_create_my_broadcast_id`/`resolve_broadcast_id`). **(recommended — removes the
  problem at its root: a viewer never subscribes to anything, so the failure mode found
  at Code Generation cannot recur)**
- B. Other (write in)

[Answer]: A

### Q2 (revised): Table RLS and join-request row lifecycle?

- A. **INSERT**: `anon, authenticated` may insert via `submit_join_request` only (no
  direct table INSERT grant needed beyond what the `SECURITY INVOKER` function itself
  requires — same posture as today's symmetric lobby INSERT policy, just expressed as a
  table policy instead of a Broadcast-extension one). **SELECT**: restricted to the
  broadcast's owner via the same `broadcast_identities` ownership check Q1 of the
  original design already established (`EXISTS (SELECT 1 FROM broadcast_identities
  WHERE broadcast_id = ... AND owner_id = auth.uid())`) — standard table RLS, not
  Broadcast-extension RLS. A viewer is never granted SELECT at all — it has no reason to
  read `broadcast_join_requests` directly, which is actually a *stronger* privacy
  property than the original design aimed for. **Row lifecycle**: the broadcaster
  deletes a row immediately after acting on it (accept or reject), via a second small
  `SECURITY INVOKER` function `consume_join_request(p_request_id uuid)`, scoped by the
  same ownership check (`DELETE` RLS restricted to the owner) — no accumulating rows, no
  separate cleanup job, matching this unit's existing "nothing ephemeral outlives its own
  handshake" intent (Q5 below). **(recommended)**
- B. Other (write in)

[Answer]: A

## Per-Viewer Channel

### Q3: Per-viewer channel naming and `peerId` entropy?

- A. `signaling:{session_id}:{peerId}`, where `peerId` is a client-generated random
  value with at least 128 bits of entropy (e.g. a v4 UUID), never derived from anything
  identity-related. RLS for this topic pattern stays **symmetric and open**
  (`anon, authenticated` for both INSERT and SELECT, matching today's pattern) —
  deliberately *not* an ownership check like Q1/Q2's lobby. Privacy here comes entirely
  from the topic name's own unguessability (nobody else ever learns this `peerId`), the
  same capability-based security property AWS's `senderClientId`-routed model relies on,
  just expressed as a channel-name secret instead of server-side per-recipient routing.
  **(recommended — simpler than an ownership check, and correct: unlike the lobby, this
  topic's name is never shared with anyone but the two intended participants)**
- B. Other (write in)

[Answer]: A

## Channel Lifecycle

### Q4 (revised): Join sequencing — who opens/calls what, in what order, to avoid a race?

- A. 1) Viewer generates its own `peerId`, **subscribes to its own
  `signaling:{session_id}:{peerId}` channel first** (so it's already listening before
  anyone could possibly respond), 2) viewer calls `submit_join_request(broadcast_id,
  peerId)` — a single RPC, not a channel publish, 3) broadcaster (already subscribed via
  Postgres Changes to its own `broadcast_join_requests` rows) receives the new row and
  subscribes to that same `signaling:{session_id}:{peerId}` topic, then calls
  `consume_join_request(request_id)` to delete the row, 4) normal
  SDP/ICE/`JoinAccepted`/`JoinRejected` exchange proceeds on the per-viewer channel
  exactly as `SignalingMessage`'s existing shape already describes — no change to the
  message types themselves, only which mechanism carries the initial join request. The
  per-viewer channel stays open for the connection's lifetime (it carries `IceRestart`
  re-signaling too, per Unit 5's own reconnection design) and is closed on `Leave`,
  `BroadcastEnded`, or the broadcaster's own cleanup after Unit 5's ack-timeout/ICE-failure
  detection. **(recommended — eliminates the race by construction: the viewer is always
  listening before it could possibly need to be, and the RPC-based join request has no
  subscribe step to race against at all)**
- B. Other (write in)

[Answer]: A

## Presence

### Q5: Does presence have any remaining purpose on these channels?

Unit 5's own (already-approved) Functional Design does **not** use Realtime presence at
all for viewer discovery or disconnect detection — it uses explicit `JoinRequest`/
`JoinAccepted` messages and an application-level join-ack timer (Unit 5 business-rules.md
Rule 1), plus native ICE state for disconnect detection (Rule 2). The broadcaster's own
`BroadcastTransport.viewers` stream already gives a live, confirmed viewer list/count
without needing Realtime presence as a second source of truth.

- A. **Drop presence entirely** from both the lobby and per-viewer channels. Removes the
  three presence-related RLS policies from Unit 3's original migration (via this unit's
  own new migration, not an edit to the old one) and the `presence`/`track`/
  `onPresenceSync` code path from the revised `SessionSignalingChannel`. Unit 6's
  dashboard viewer count (FR-6.4/FR-8.3) should consume `BroadcastTransport.viewers`
  (Unit 5) directly, not `PresenceSnapshot` — flagged for Unit 6's own Functional Design
  to pick up. `PresenceSnapshot` itself can be removed from `zip_core` as dead code once
  nothing references it. **(recommended — one less mechanism to keep private, and it
  was never load-bearing for anything Unit 5 actually does)**
- B. Keep presence, scoped the same way as the lobby (broadcaster-only reads via the
  `broadcast_identities` ownership check) — a defense-in-depth signal for detecting a
  viewer that vanishes without a clean WebRTC-level signal.
- C. Other (write in)

[Answer]: A

## Interface Shape

### Q6 (revised): How does `SignalingService`'s shape change?

Fixed at Application Design as `SessionSignalingChannel sessionChannel(String sessionId,
SignalingRole role)` — one channel object representing the whole shared topic for
either role. That shape no longer fits: the broadcaster now needs a way to receive join
requests *plus* one channel per accepted viewer; a viewer needs exactly one RPC call and
one channel (its own) — no `LobbyChannel`/Realtime object for the join-request step at
all.

- A. `SignalingService` gains a plain async method `Future<void>
  submitJoinRequest(BroadcastId broadcastId, String peerId)` (viewer-side; a thin wrapper
  over the `submit_join_request` RPC — no channel object, nothing to open/close) and
  `Stream<JoinRequest> joinRequests(BroadcastId broadcastId)` (broadcaster-only; wraps a
  Postgres Changes subscription on `broadcast_join_requests`, internally calling
  `consume_join_request` once a request is forwarded downstream), alongside the already
  separately-verified `SessionSignalingChannel sessionChannel(String sessionId, String
  peerId)` (symmetric — used by both the broadcaster, once per accepted viewer, and that
  one viewer, once). `LobbyChannel`/`SupabaseLobbyChannel` (and their `.broadcaster`/
  `.viewer` named constructors, written against the now-abandoned Broadcast-channel
  design) are removed entirely — there is no "channel" to represent on the join-request
  side anymore, only an RPC call and a Postgres Changes stream. `SignalingRole` stays
  unneeded, consistent with the original Q6 answer. **(recommended — the simplest shape
  that matches what Q1/Q4 actually need: a call and a stream, not a channel)**
- B. Other (write in)

[Answer]: A

## Previously-Flagged Open Technical Question — now resolved

The prior version of this plan flagged "does Broadcast INSERT work without the client
reaching subscribed state" as an open question for empirical verification at Code
Generation. **It has been answered, empirically, and the answer drove this revision**:
a client that never subscribes can still never *receive*, which is fine (confirmed: the
viewer side of this design has no receive need at all) — but the deeper issue the
original fallback didn't anticipate is that *subscribing in a receive-nothing
configuration still requires a SELECT grant*, which an unprivileged viewer will never
have. That's what makes the table + RPC + Postgres Changes approach necessary rather
than optional. See `audit.md`'s 2026-10-06 entries for the full empirical trail
(including the `httpSend` version-gate finding, ruled out as an alternative fix).
