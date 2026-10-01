# Business Rules — Broadcast Identity + Signaling

**Rule 1 — One broadcast ID per broadcaster, enforced at the database, not just in
application code.**
`broadcast_identities.owner_id` carries a `UNIQUE` constraint (SR-02 §1). A concurrent
double-call to `getOrCreateMine()` for the same broadcaster can race in application code
but can never produce two rows — the second insert attempt fails the constraint and
must be handled as "someone already has a row, re-select it," not treated as an error.

**Rule 2 — Broadcast IDs are never derived from account identity.**
The 6-character code (SR-02 §3) is generated from `pgcrypto` random bytes, never from
`owner_id`, email, or any other identifying value (FR-2.3). This is a security property
(an ID leak or a guessed-nearby ID must never hint at whose broadcast it is), not merely
a style preference.

**Rule 3 — The anonymous resolution function returns existence only, never ownership.**
`resolve_broadcast_id` (SR-02 §2) returns a bare `boolean`. No code path may extend this
function (or add a sibling one) to return `owner_id`, email, or any other
account-identifying column to an anonymous caller — that would violate NFR-3.5 even if
narrowly scoped elsewhere.

**Rule 4 — Malformed or adversarial signaling input is dropped, never thrown.**
`SignalingCodec.decode` returns `null` for anything malformed, unrecognized, or
oversized (Section 3, fixed at Application Design). Every consumer of `messages` must
treat `null` as "ignore this event," never propagate it as an exception — a single
crafted payload from any peer (broadcaster or viewer, since both can publish on
`signaling:{session_id}`) must never be able to crash the other side.

**Rule 5 — RLS establishes channel membership; application logic establishes message-type
authorization.**
Per SR-02 §4's documented split: Realtime RLS can express "who may publish on this
channel at all" but not "which message types a given sender may publish." Rejecting a
viewer-sent `BroadcastEnded` (or similar broadcaster-only message shape) is Unit 5's
transport-layer responsibility, informed by this unit's `SignalingMessage` sealed type —
this unit's own scope ends at RLS-level channel authorization and codec-level shape
validation.

**Rule 6 — Presence-expiry is the only "offline" detection mechanism; no application-level
heartbeat.**
`StatusChannel.watch()`'s offline transition when a broadcaster disappears uncleanly
(FR-6.6) relies entirely on Realtime's own presence-expiry behavior (Spike 2.1's 60s
interim `presenceTimeout`) — this unit does not implement a parallel heartbeat/polling
mechanism, which would be redundant with a platform capability already doing this job.

**Rule 7 — Viewer identity stays null in Phase 2; the field exists but is inert.**
`JoinRequest.viewerIdentity` is part of the fixed `SignalingMessage` shape (reserved for
Phase 3) but every Phase 2 code path that constructs a `JoinRequest` sets it to `null`
(FR-3.5) — no Phase 2 business logic may read or depend on a non-null value here.

**Rule 8 — Capacity enforcement is explicitly not this unit's concern.**
Per the plan's Q6: `ViewerAdmission`/join-count logic belongs to Unit 5. This unit
provides the channel and its authorization only — it must not grow ad hoc
admission-limiting logic that would later conflict with Unit 5's own implementation.
