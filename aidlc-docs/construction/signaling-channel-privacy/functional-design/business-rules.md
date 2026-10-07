# Business Rules — Signaling Channel Privacy (Unit 3.1)

**Rule 1 (revised 2026-10-06) — A viewer submits a `JoinRequest` via a single RPC call;
it never subscribes to anything for this step.**
Confirmed by direct testing that Realtime's `subscribe()` requires a matching SELECT
grant for *any* client joining a topic, regardless of whether that client wires a
receive callback — there is no send-only subscription mode. The original "subscribe
with zero callbacks wired" fallback (previously documented here) does not work either,
since the rejection happens at `subscribe()` itself, before any callback would matter.
`submit_join_request(broadcast_id, peer_id)` replaces the lobby channel's send side
entirely: a viewer calls it and is done, with no channel object and no subscribe step
at all. **Revised again 2026-10-07 (PR #29 review)**: the function is `SECURITY
DEFINER`, not `INVOKER` — bounding submissions and cleaning up stale rows (Rule 2.1)
requires reading every pending row for a `broadcast_id`, which a non-owner caller's own
SELECT RLS would otherwise filter to nothing, defeating the bound. Also rate-limited at
Kong (ip-based, same shape as `resolve_broadcast_id`'s existing limit) — an
unauthenticated caller could otherwise flood the RPC itself, independent of the
per-broadcast cap.

**Rule 2.1 (added 2026-10-07, PR #29 review) — `submit_join_request` bounds pending
requests per `broadcast_id` and opportunistically deletes stale ones; it never trusts
caller identity to self-limit.**
Before inserting, it deletes this `broadcast_id`'s own rows older than 5 minutes (TTL
set well above Unit 5's own join-ack timeout, so a real response is never mistaken for
stale), then rejects the insert outright if 20 requests are already pending for that
`broadcast_id`. Confirmed directly: 20 submissions for one `broadcast_id` succeed, the
21st raises; aging 20 rows past the TTL and submitting again leaves exactly 1 row
(every stale row cleaned, the fresh one inserted). Without this, an anonymous caller
with a real or guessed `broadcast_id` could grow this table without bound, especially
if the owner is offline to consume anything.

**Rule 2.2 (added 2026-10-07, second PR #29 review pass) — the table itself grants no
INSERT privilege to `anon`/`authenticated`; the only path in is the function.**
A second review pass found that an open `WITH CHECK (true)` INSERT *policy* (the first
version of this rule) was not enough on its own: this project's Postgres image grants
`anon`/`authenticated` default INSERT on every `public` table, so a client could hit
`broadcast_join_requests` directly through PostgREST's generic REST route, bypassing
`submit_join_request` entirely — no cap, no cleanup, no rate limit. The privilege
check happens *before* RLS is ever consulted, so no policy could have closed this; the
table-level grant itself had to be revoked (`REVOKE INSERT ... FROM anon,
authenticated`). Confirmed directly: a raw REST `POST` to the table now returns
`42501 permission denied`, while the RPC path still succeeds (`SECURITY DEFINER` runs
as the table owner, unaffected by the revoke).

**Rule 2.3 (added 2026-10-07, same review pass) — the pending-request cap is
serialized per `broadcast_id`, not just checked.**
Without this, two concurrent `submit_join_request` calls for the same `broadcast_id`
could each count 19 pending rows before either inserts, both pass the `< 20` check,
and leave 21 — Postgres's default READ COMMITTED isolation does not make a
count-then-insert sequence atomic by itself. `submit_join_request` now takes
`pg_advisory_xact_lock(hashtext(p_broadcast_id))` before the cleanup/count/insert
sequence, serializing concurrent calls for the same `broadcast_id` while leaving
different broadcasts' calls independent; the lock releases automatically at the
transaction's end.

**Rule 2 (revised 2026-10-06) — `broadcast_join_requests` SELECT is restricted to the
real broadcast owner, checked against the existing `broadcast_identities` table — never
a new persisted mapping; rows are deleted once consumed.**
Table RLS: `SELECT`/`DELETE` restricted to `EXISTS (SELECT 1 FROM broadcast_identities
WHERE broadcast_id = broadcast_join_requests.broadcast_id AND owner_id = auth.uid())`.
`INSERT` is performed only through `submit_join_request` (a viewer is never granted
direct table INSERT, matching Unit 3's existing posture of routing writes through a
function rather than a raw table grant). The broadcaster calls
`consume_join_request(request_id)` — a second `SECURITY INVOKER` RPC, scoped by the
same ownership check — to delete a row immediately after acting on it, so no row
outlives its own handshake. This is the one place in this unit's authorization that
checks identity — the per-viewer channel (Rule 3) relies on topic-name unguessability
instead, because only the join-request step has more than two possible participants
until a per-viewer channel exists.

**Rule 3 — Per-viewer channel RLS stays symmetric and open; privacy is the `peerId`'s own
unguessability, not an identity check.**
`signaling:{session_id}:{peerId}` INSERT and SELECT both stay open to
`anon, authenticated`, exactly like Unit 3's original (now-superseded) policy. This is
deliberate, not an oversight: unlike the lobby's topic name (knowable by every viewer of
this broadcast), a per-viewer topic's name is never shared with anyone but the
broadcaster and that one viewer — there is no "legitimate third party" for RLS to need
to exclude, so an identity check here would add complexity without adding security.

**Rule 4 — A viewer must subscribe to its own per-viewer channel before sending
`JoinRequest`, never after.**
This ordering (business-logic-model.md's join sequence, steps 1–2) eliminates the race
a lobby-only design would otherwise have — the viewer is always listening before the
broadcaster could possibly respond. A `JoinRequest` sent before the viewer's own channel
is confirmed-subscribed is a logic error in any implementation of this unit, not a race
to tolerate.

**Rule 5 — `peerId` is single-use: a fresh one is generated for every connection attempt,
never reused across a reconnect.**
Each `connect()` and each `restart()` (Unit 5's reconnection loop) generates a new
`peerId` and opens a new per-viewer channel; the old one (if still open) is closed. A
`peerId` that leaked or was logged once therefore stops being useful to an attacker the
moment that one connection attempt ends — unlike a long-lived identifier, it has no
ongoing value to compromise.

**Rule 6 — No code may reintroduce presence tracking on either channel type.**
Dropped entirely (Q5) because nothing in this unit or Unit 5 depends on it — the
broadcaster's own open-channel bookkeeping is the viewer count (business-logic-model.md).
Reintroducing `track()`/`onPresenceSync` on either the lobby or a per-viewer channel
would reopen exactly the leak this unit exists to close, since presence state is
inherently broadcast to every subscriber of whichever channel it's enabled on — there is
no partial/filtered presence in Realtime's protocol (confirmed against Supabase's own
documentation during this unit's investigation).

**Rule 7 (revised 2026-10-06) — `JoinRequest` only ever travels via
`submit_join_request`/`broadcast_join_requests`; nothing else may travel there, and
`JoinRequest` must never travel on a per-viewer channel.**
Every other `SignalingMessage` variant (`JoinAccepted` through `BroadcastEnded`) only
ever travels on a `SessionSignalingChannel`. There is no `SignalingCodec`-encoded
payload on the join-request path at all — `submit_join_request`'s own typed SQL
parameters (`broadcast_id text, peer_id text`) are the entire wire format, so there is
no risk of an `SdpOffer` or any other variant reaching it by mistake the way a shared
channel could.

**Rule 8 — Message-type sender authorization still applies within a per-viewer channel
(restated from Unit 3's Business Rule 5 / Unit 5's Business Rule 4).**
Narrowing the audience from "everyone on the session" to "one viewer and the
broadcaster" does not remove the need to check that, e.g., a `BroadcastEnded` or
`JoinAccepted`/`JoinRejected` message actually came from the broadcaster's side of that
one channel, not the viewer's. Still Unit 5's transport-layer responsibility, unchanged
by this unit — restated here only so it isn't assumed to have been superseded by the
narrower audience.

**Rule 9 (revised 2026-10-06, confirmed 2026-10-06) — The Postgres Changes + table RLS
behavior was empirically confirmed against the real local stack before this unit's
migration shipped (not assumed from documentation alone).**
This project had already had two RLS/Realtime assumptions fail on first contact with
the real stack within this same unit (the lobby SELECT policy itself, and the
subscribe-requires-SELECT behavior that invalidated it) — a **third** surfaced testing
this redesign: Postgres Changes delivers nothing at all for a table that isn't a member
of the `supabase_realtime` publication, even with RLS and `REPLICA IDENTITY FULL` both
already correct. Fixed by adding `ALTER PUBLICATION supabase_realtime ADD TABLE
broadcast_join_requests` to the migration. With that in place, the real-backend test
confirmed: (a) a broadcaster's `onPostgresChanges` subscription, filtered to its own
`broadcast_id`, receives a row inserted via `submit_join_request` by a *different*
(viewer) client; (b) a client lacking the ownership match receives nothing for a
`broadcast_id` it doesn't own — RLS filters the Postgres Changes stream rather than
rejecting the subscription outright, unlike the Broadcast-extension design this
replaced; (c) anon can call `submit_join_request` with no subscription step at all.
