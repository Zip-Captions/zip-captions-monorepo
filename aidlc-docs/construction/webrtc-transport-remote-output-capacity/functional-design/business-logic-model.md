# Business Logic Model — WebRTC Transport + Remote Output + Capacity

## `WebRtcBroadcastTransport` — per-viewer connection lifecycle

**Revised 2026-10-07** (domain-entities.md's context-shape revision): star topology
(FR-4.2), one `PeerConnectionHandle` per viewer, created on receiving that viewer's
`JoinRequest` from `signalingService.joinRequests(broadcastId)` — a Postgres-Changes-
backed stream (Unit 3.1), not a message arriving over a shared signaling channel (there
is no such channel). Sequence per viewer:

1. On receiving a `JoinRequest`, open `signalingService.sessionChannel(sessionId,
   peerId)` first (Unit 3.1 business-logic-model.md's own join sequence — the
   broadcaster always opens this per-viewer channel on a join attempt, since it's now
   the only way to send either outcome back to a viewer that's already listening on it;
   there is no separate lobby/reject channel). Then `ViewerAdmission.tryAdmit(peerId)`
   (business-rules.md). `Full` → send `JoinRejected(JoinRejection.full)` on that
   per-viewer channel, close it, stop — this viewer never reaches peer-connection setup.
2. `Admitted` → create a `PeerConnectionHandle` via `PeerConnectionFactory.create`
   (Unit 4's ICE servers), create an ordered+reliable data channel, exchange SDP/ICE
   through that same per-viewer channel, send `JoinAccepted`.
3. **Q1 — join-ack confirmation, not native "open"**: Spike 2.1 found the data
   channel's local "open" event can fire on the broadcaster side before the DCEP
   handshake has actually completed with the remote viewer, so the broadcaster's own
   "100% channels open" log was never a reliable signal of 100% usable channels. This
   unit does not trust that event alone. Instead: once the data channel reports open
   *locally*, the broadcaster starts a 5-second ack timer for that `peerId` and sends
   nothing yet. The expected first inbound message from a genuinely-connected viewer is
   an application-level `JoinAck` (a new, minimal `CaptionWireMessage`-adjacent signal
   sent by `WebRtcViewerTransport` the moment *its own* data channel reports open — see
   below). If the ack arrives within 5s: this `peerId` is now a confirmed viewer —
   `ViewerConnectionInfo.connectedAt` is set, the id is added to `BroadcastTransport.viewers`,
   and `viewerJoined` fires (triggering Q8's snapshot). If the timer expires first: treat
   this exactly as a failed join — release the Step 1 admission slot
   (`ViewerAdmission.release(peerId)`), close this one `PeerConnectionHandle`, and do
   **not** fire `viewerJoined`. No other viewer is touched (NFR-4.2) — this is a
   per-`peerId` timer, not a global one.
4. Steady state: `sendToAll`/`sendTo` write to each viewer's own data channel
   independently; a slow or closed channel on one viewer never blocks or affects
   `sendToAll`'s delivery to any other (NFR-4.2) — implemented as independent
   fire-and-forget writes per channel, not a shared awaited loop.
5. Teardown: a native ICE `failed`/`closed` state on a confirmed viewer's peer
   connection releases that `peerId`'s admission slot (starting its `reconnectWindow`
   grace period per Q6, not an immediate hard release) and fires `viewerLeft`.
6. `stop()`: closes every peer connection and releases all native resources,
   regardless of each viewer's individual state.

## `WebRtcViewerTransport` — connection + reconnection

`connect(ViewerTransportContext)`: **revised 2026-10-07** — generates a fresh `peerId()`
(Unit 3.1 `business-rules.md` Rule 5: never reused, including across `restart()`),
opens `signalingService.sessionChannel(sessionId, peerId)` *first* (so it's already
listening before the broadcaster could possibly respond, closing the race by
construction — Unit 3.1's own join sequence), then calls
`signalingService.submitJoinRequest(broadcastId, peerId)` — a one-shot RPC, not a
message sent over any channel. Creates one `PeerConnectionHandle`, handles the
resulting SDP/ICE exchange or a `JoinRejected` arriving on that same per-viewer channel
(mapped to the matching `ConnectFailure` per domain-entities.md). The moment this
viewer's own data channel reports locally open, it immediately sends a `JoinAck` over
that channel — this is the signal the broadcaster's Q1 timer is waiting for. This
happens before any caption traffic is expected and requires no response.

**Q2 — reconnection**: a native ICE `disconnected`/`failed` state on an already-connected
viewer triggers `ConnectionStatus.Interrupted` and an internal retry loop calling
`restart()` (ICE restart if the existing peer connection can recover; a fresh
re-signaling exchange — a new `JoinRequest` — if it can't) at 1s, 2s, 4s, then 8s,
repeating at 8s thereafter for as long as the platform reports any network path at all.
No attempt counter forces a transition to `Failed` — `Failed` only results from a
terminal condition: the viewer itself calling `disconnect()`, or the broadcast ending
(`CaptionWireMessage.Ended`, handled by `RemoteCaptionReceiver`, not this transport
directly — see below). A successful reconnect at any point returns to
`ConnectionStatus.Connected`, re-confirmed via the same `JoinAck` handshake as a fresh
connect (so the broadcaster's Q6 reservation-reclaim logic has a real signal to key off
of, not just a resumed ICE state).

## `TransportSelector`

Phase 2: `broadcastTransport()`/`viewerTransport()` always construct and return the
`WebRtc*` implementations — no actual selection logic yet (ADR-011's negotiation entry
point exists as a seam for Phase 3/5 transports, not exercised until those phases add
alternatives).

## `RemoteBroadcastTarget` (`CaptionOutputTarget`)

Registered on the broadcaster's `CaptionOutputTargetRegistry` (existing Phase 1
infrastructure). `onCaptionEvent`: an `SttResultEvent` maps to
`CaptionWireMessage.Caption` and is sent via `transport.sendToAll`; a `SessionStateEvent`
maps to the fixed activity table (`RecordingActiveState`→`active`,
`PausedState`/`ReconnectingState`→`paused`, `IdleState`/`StoppedState`→`inactive`,
component-methods.md) and updates `currentActivity`, emitted on `activityChanges` and
sent to all viewers as `CaptionWireMessage.CaptionActivityChanged`.

**Q8 — join snapshot**: subscribes to `transport.viewerJoined`. On each firing (which,
per Q1, only ever fires for a confirmed, ack-completed viewer), sends exactly one
message — `transport.sendTo(peerId, CaptionWireMessage.CaptionActivityChanged(currentActivity))`
— to that one viewer only. No caption backlog, no replay (FR-5.4): this is the entire
snapshot. Ordinary `sendToAll` traffic reaches this viewer identically to every other
viewer from this point on, with no further special-casing.

## `RemoteCaptionReceiver` (viewer side)

Subscribes to `ViewerTransport.messages`. `Caption` → publishes an `SttResultEvent` into
the viewer-scoped `CaptionBus` (existing Phase 1 infrastructure, FR-5.3 — unchanged
rendering pipeline). `CaptionActivityChanged` → republished on `activity`.
`Ended` → republished on `ended` (the viewer session layer, Unit 7, maps this to the
FR-7.4 "broadcast ended" state — not a `ConnectionStatus` transition, since the
transport-level connection may still be technically healthy at the moment the
broadcaster ends the session).

## `ViewerAdmission`

See `business-rules.md` for the full `reconnectWindow` reservation rule (Q6) — this is
the one component in this unit whose correctness is a stated PBT target (PBT-03's cap
invariant), so its exact state machine is specified as a rule, not narrative logic, to
keep the property test's reference model and this design in lockstep.
