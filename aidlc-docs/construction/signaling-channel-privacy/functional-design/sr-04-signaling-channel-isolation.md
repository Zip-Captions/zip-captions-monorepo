# SR-04: Signaling Channel Isolation Review

**Story**: S-13.1 (Signaling Channel Privacy) | **Blocks**: S-13.1 Code Generation
**Area**: Supabase RLS / Realtime Authorization (AGENTS.md: RLS policy definitions —
pre-approval required)
**FR/NFR**: NFR-3.9 (no viewer-to-viewer visibility) | **Inserted** 2026-10-05, after
Units 3/4 shipped

This document is the human-approval gate required by AGENTS.md before any new RLS
policy or Realtime channel-authorization change is implemented for this unit. It
records the approach decided in `signaling-channel-privacy-functional-design-plan.md`
(Q1–Q6, all answered A).

**Revised 2026-10-06, before Code Generation shipped/committed, requiring fresh
sign-off (Section 7).** The original design (a Realtime Broadcast-extension lobby
channel) was confirmed unworkable by direct testing at Code Generation Step 11 —
Realtime's `subscribe()` rejects any client lacking SELECT regardless of receive
intent, so a send-only viewer could never open the lobby channel at all. The
join-request mechanism (Sections 2–3 below) is replaced with a table + RPC + Postgres
Changes design; the per-viewer channel (unaffected) keeps its original, already
empirically-verified authorization basis.

## 1. The Gap Being Closed

Confirmed by reading the shipped `SupabaseSessionSignalingChannel` directly (not
assumed): every participant on the existing `signaling:{session_id}` channel — one
shared topic for the broadcaster and every viewer — receives (a) every other
participant's presence via `.presence`, and (b) every other participant's raw
`SignalingMessage` traffic (including `SdpOffer`/`IceCandidate`, which carry real
network-address metadata) via the unfiltered `onBroadcast` forward. This unit replaces
that single shared topic with two isolated topic types (Section 2) so that no viewer
can observe any other viewer's presence or signaling traffic, while the broadcaster can
still discover and connect to every viewer (NFR-3.9).

**Does not reopen or edit Unit 3's merged migration/artifacts.** This ships as a new,
forward-only migration extending Unit 3's package — the same precedent as
`20261001000001_fix_jwt_secret_mismatch.sql`.

## 2. Channel Topology (revised 2026-10-06)

| Mechanism | Scope | Purpose |
|---|---|---|
| `status:{broadcast_id}` | unchanged | Unit 3's existing live/offline presence — not part of this unit's scope or the original leak |
| `broadcast_join_requests` (table) + `submit_join_request`/`consume_join_request` (RPCs) | new | broadcaster-only read (via Postgres Changes); viewers call `submit_join_request` only, never subscribe to anything |
| `signaling:{session_id}:{peerId}` | new, unaffected by this revision | one per accepted viewer; symmetric read/write, scoped to exactly two participants |

## 3. Authorization (revised 2026-10-06 — RLS on `broadcast_join_requests`, not `realtime.messages`)

**Why this changed**: the original design put the join-request step on a Realtime
Broadcast-extension channel, authorized via `realtime.messages` RLS. Confirmed
unworkable by direct testing — `subscribe()` rejects any client lacking SELECT,
regardless of receive intent, so a send-only viewer could never open that channel.
Replaced with ordinary table RLS plus two functions, governing a Postgres Changes
subscription instead of a Broadcast-extension one.

**Revised again 2026-10-07 (PR #29 review, three findings)**: (1) `submit_join_request`
is `SECURITY DEFINER`, not `INVOKER` as first implemented — bounding/cleaning up
pending requests (below) means reading every row for a `broadcast_id`, which a
non-owner's own SELECT RLS would otherwise filter to nothing, silently defeating the
bound; this mirrors `resolve_broadcast_id`'s own existing `DEFINER` use for the same
class of problem. (2) The RPC is now Kong-rate-limited (ip-based, same shape as
`resolve_broadcast_id`), and the function itself deletes this `broadcast_id`'s pending
rows older than 5 minutes before rejecting the insert outright once 20 are already
pending — confirmed directly: 20 succeed, a 21st raises; aging rows past the TTL and
retrying leaves exactly the fresh row. Without this, an anonymous caller could grow the
table without bound, especially against an offline owner. (3) No foreign key from
`broadcast_join_requests.broadcast_id` to `broadcast_identities.broadcast_id` was
added, despite the column being `UNIQUE` and a natural-looking FK target — a
constraint violation would let a caller distinguish "this broadcast_id exists" from
"it doesn't" purely from the error shape, recreating the exact existence-oracle problem
`resolve_broadcast_id`'s own separate rate limit exists to contain. This table accepts
any `broadcast_id` text at face value, same as the lobby design it replaced.

| Resource | Policy | Role | Condition |
|---|---|---|---|
| `broadcast_join_requests` | `INSERT` | — | not granted directly; all inserts go through `submit_join_request(broadcast_id, peer_id)` — `SECURITY DEFINER`, Kong-rate-limited, callable by `anon`/`authenticated`. Bounds pending requests to 20 per `broadcast_id` and opportunistically deletes rows older than 5 minutes before inserting |
| `broadcast_join_requests` | `SELECT` | `authenticated` | `EXISTS (SELECT 1 FROM broadcast_identities WHERE broadcast_id = broadcast_join_requests.broadcast_id AND owner_id = auth.uid())` — **the one identity check in this unit's authorization**, reusing the already-existing `broadcast_identities` table (built by Unit 3 for a different purpose) rather than requiring any new persisted session-ownership mapping, keeping FR-2.6 ("no session records in Postgres") fully satisfied. Governs both direct SELECT and the broadcaster's Postgres Changes subscription (Realtime's Postgres Changes feature enforces the table's own RLS, not a separate Broadcast-extension policy) |
| `broadcast_join_requests` | `DELETE` | `authenticated` | same ownership check as SELECT; exercised only via `consume_join_request(request_id)`, called by the broadcaster after acting on a request, so no row outlives its own handshake |
| `signaling:{session_id}:{peerId}` | `broadcast` `INSERT` (send) | `anon`, `authenticated` | always true — deliberately symmetric and open, same posture as Unit 3's original policy for this extension — **unaffected by this revision** |
| `signaling:{session_id}:{peerId}` | `broadcast` `SELECT` (receive) | `anon`, `authenticated` | always true — **this is safe, not an oversight**: unlike the join-request step (which, until a per-viewer channel exists, has more than two possible participants), a per-viewer topic's full name (including the unguessable `peerId`, domain-entities.md) is never shared with anyone but the broadcaster and that one viewer. There is no legitimate third party to exclude here, so an identity check would add complexity without adding security — **unaffected by this revision, already empirically verified** |
| `signaling:{session_id}:{peerId}` | `presence` | — | **no presence policy at all**, same reasoning as before (Section 4) |

## 4. Why Presence Is Dropped, Not Just Re-Scoped

Unit 5's own (already-approved) Functional Design never relies on Realtime presence for
viewer discovery or disconnect detection — it uses explicit `JoinRequest`/`JoinAccepted`
messages, an application-level join-ack timer, and native ICE state (Unit 5
business-rules.md Rules 1–2). The broadcaster's own count of currently-open per-viewer
channels already gives a live, confirmed viewer count without a second, presence-based
source of truth. Re-scoping presence (e.g. "broadcaster-only reads, same as the lobby")
was considered and rejected: it adds a mechanism that nothing in this project actually
needs, for a property (viewer count) already available more directly from Unit 5's own
bookkeeping.

## 5. Message-Type Authorization (restated, unchanged)

Per Unit 3's original SR-02 §4 split (RLS establishes channel membership only, never
message-*type* authorization) and Unit 5's business-rules.md Rule 4/8: narrowing the
per-viewer channel's audience to exactly two participants does not remove the need to
verify that, e.g., a `JoinAccepted`/`BroadcastEnded` on that channel actually came from
the broadcaster's side, not the viewer's. Still Unit 5's transport-layer responsibility,
unaffected by this unit.

## 6. Verification (confirmed 2026-10-06 against the real local stack, business-rules.md Rule 9)

Confirmed by a real-backend test, not asserted from documentation alone: a
broadcaster's `onPostgresChanges` subscription on `broadcast_join_requests`, filtered
to its own `broadcast_id`, receives rows inserted by a different (viewer) client; a
non-owner receives nothing for a `broadcast_id` it doesn't own (RLS filters the stream
rather than rejecting the subscription); anon can call `submit_join_request` with no
subscription step. One additional requirement surfaced during this verification and
is now part of the migration: the table must be added to the `supabase_realtime`
publication (`ALTER PUBLICATION supabase_realtime ADD TABLE
broadcast_join_requests`) — Postgres Changes delivers nothing without it, even with
RLS and `REPLICA IDENTITY FULL` already correct.

## 7. Approval

**Revision requires a fresh sign-off** — the previous approval below applied to the
original (now-replaced) Broadcast-extension design and does not cover Section 2/3's
table + RPC + Postgres Changes mechanism.

- [x] **Approved** — this revised approach may proceed to Code Generation for S-13.1.

Approved by: James Petersen  Date: 2026-10-06

**Amendment approved 2026-10-07** (PR #29 review remediation — `submit_join_request`
switched to `SECURITY DEFINER`, Kong rate limit added, 20-request pending cap +
5-minute stale-row cleanup added, no FK to `broadcast_identities`): approved via the
user's explicit choice of remediation approach ("Kong rate limit + pending cap +
opportunistic cleanup") over the alternatives offered, rather than a separate written
sign-off — Section 3's table above reflects the approved shape.

---
*Superseded approval, retained for the audit trail:*
- [x] Approved (original Broadcast-extension lobby design) — James Petersen, 2026-10-05
