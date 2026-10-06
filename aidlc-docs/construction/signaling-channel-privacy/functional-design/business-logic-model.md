# Business Logic Model — Signaling Channel Privacy (Unit 3.1)

## Broadcaster: going live

1. Open `StatusChannel` (unchanged, Unit 3) and publish live.
2. Subscribe to `joinRequests` for this broadcast's `broadcast_id` — internally, a
   Postgres Changes subscription on `broadcast_join_requests`, authorized by the
   `broadcast_identities` ownership check (no Realtime Broadcast-extension RLS
   involved). Held open for the entire time the broadcast is live.
3. For each `JoinRequest(fromPeerId: peerId)` received, proceed to the join sequence
   below.

## Join sequence (revised 2026-10-06 — replaces the old lobby-channel exchange)

1. **Viewer**: generates a fresh `peerId` (domain-entities.md), opens a
   `SessionSignalingChannel` for `(sessionId, peerId)` — this subscribes the viewer to
   `signaling:{session_id}:{peerId}` *before* anything else happens, closing the race a
   lobby-only design would otherwise have.
2. **Viewer**: calls `submitJoinRequest(broadcastId, peerId)` — a single RPC call
   (`submit_join_request`), inserting one row into `broadcast_join_requests`. The
   viewer never subscribes to anything for this step.
3. **Broadcaster**: receives the new row on its `joinRequests` stream, opens its *own*
   `SessionSignalingChannel` for the same `(sessionId, peerId)` pair, then calls
   `consume_join_request(requestId)` to delete the row (business-rules.md Rule 2).
4. From here, the existing SDP offer/answer/ICE-candidate exchange, `JoinAccepted`/
   `JoinRejected`, proceeds exactly as Unit 5's own Functional Design already specifies
   (`WebRtcBroadcastTransport`'s per-viewer lifecycle, business-rules.md Rule 1's
   join-ack timer) — unchanged by this unit, just now carried on a channel only these
   two participants ever subscribe to.
5. **Reconnection** (Unit 5 Q2, `WebRtcViewerTransport.restart()`): a fresh re-signal
   after a network change generates a **new** `peerId` and repeats the full join
   sequence from step 1 — the old per-viewer channel (if still open) is closed. This
   means a reconnecting viewer is, from the signaling layer's perspective,
   indistinguishable from a brand-new join; Unit 5's `ViewerAdmission` reservation
   (its own business-rules.md Rule 6, keyed by `peerId`) is what lets the broadcaster's
   capacity-tracking recognize this as a *reclaim* rather than a new viewer taking a
   slot — that logic is unaffected by this unit, since it operates one layer above the
   raw channel.

## Teardown

- **Clean leave**: viewer sends `Leave(fromPeerId: peerId)` on its per-viewer channel,
  then closes it. Broadcaster, on receiving `Leave`, closes its own instance of that
  same channel.
- **Broadcast ending**: broadcaster sends `BroadcastEnded` to every still-open per-viewer
  channel (iterating its own open-channel set — this is also how it knows the current
  viewer count, see below), then closes each one, then closes its `joinRequests`
  subscription and publishes offline on `StatusChannel`.
- **Unclean disconnect**: detected entirely at Unit 5's layer (native ICE state, the
  ack-timeout path) — this unit's channels have no presence-based detection of their
  own (Q5). Once Unit 5 decides a viewer is gone, the broadcaster closes that `peerId`'s
  `SessionSignalingChannel` as part of its own cleanup.

## Viewer count (replaces the dropped presence mechanism)

The broadcaster's own bookkeeping — the number of currently-open per-viewer
`SessionSignalingChannel` instances it holds (equivalently, Unit 5's own confirmed
`BroadcastTransport.viewers` count, once a viewer passes the join-ack) — *is* the
viewer count. No Realtime presence read is needed to produce FR-6.4/FR-8.3's dashboard
figure; Unit 6's own Functional Design should consume `BroadcastTransport.viewers`
directly rather than anything from this unit.
