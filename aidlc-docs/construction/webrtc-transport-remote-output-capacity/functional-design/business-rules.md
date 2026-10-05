# Business Rules — WebRTC Transport + Remote Output + Capacity

**Rule 1 — A viewer is "joined" only after an application-level ack, never on the
native data-channel "open" event alone.**
Spike 2.1 found the broadcaster-side data channel's local "open" event can fire before
the DCEP handshake has actually completed with the remote viewer — a real, measured
failure mode (16–26% of joins failed this way at N=50 while the broadcaster logged
100% "open"). `WebRtcBroadcastTransport` therefore starts a **5-second** ack timer per
`peerId` the moment that `peerId`'s data channel reports locally open, and only adds
that `peerId` to `viewers`/fires `viewerJoined` once a `JoinAck` message is received
from it. No ack within 5s → release that `peerId`'s admission slot and close its peer
connection, exactly as if the join had been rejected; no other viewer's timer or state
is affected (NFR-4.2 — this is a per-`peerId` timer, not a shared one).

**Rule 2 — Reconnection retries indefinitely with capped exponential backoff; only a
terminal condition produces a connection failure.**
`WebRtcViewerTransport`'s retry schedule on an ICE `disconnected`/`failed` state: 1s,
2s, 4s, 8s, then 8s repeating — for as long as the platform reports any network path.
`ConnectionStatus.Interrupted` is a stable, non-failing state a viewer may remain in
indefinitely (matching FR-7.4's distinct "reconnecting" state). `ConnectionStatus.Failed`
is reachable only via `disconnect()` (explicit user action) or the broadcast itself
ending — never via retry-count exhaustion alone.

**Rule 3 — `ConnectFailure` mapping is exhaustive and exact; no generic fallback.**
`BroadcastFull` ⟵ `JoinRejected(JoinRejection.full)`. `SignalingRejected` ⟵ any other
`JoinRejected`. `IceFailed` ⟵ the peer connection's own ICE state reports `failed` with
no retry in progress (i.e. after Rule 2's retries are abandoned by a terminal
condition). `Timeout` ⟵ no response at all (no SDP/ICE progress, no `JoinAccepted`/
`JoinRejected`) within the viewer's own connect window. Every rejection/failure path a
viewer can observe must resolve to exactly one of these four — a transport
implementation must never surface a failure that doesn't map, since FR-7.4's
"cannot connect, with a specific reason" requires a concrete reason every time.

**Rule 4 — Message-type sender authorization is a transport-layer responsibility (carried
forward from Unit 3, Business Rule 5).**
Realtime RLS (Unit 3) establishes channel membership only — "who may publish on
`signaling:{session_id}` at all" — never which message *type* a given sender may use.
This unit enforces that: a message received from a peer whose `SignalingRole` doesn't
match the message's expected origin (e.g. a `JoinAccepted`/`JoinRejected`/
`BroadcastEnded` received by the broadcaster's own transport, which only a broadcaster
may originate; a `JoinRequest`/`Leave` received by a viewer's transport, which only a
viewer may originate) is dropped silently — treated exactly like a
`SignalingCodec.decode` failure (Unit 3 Rule 4), never thrown or surfaced as a
connection error. A misbehaving or compromised peer sending an out-of-role message type
must never be able to affect the receiving side's state.

**Rule 5 — Data channels are created ordered and reliable; this is what makes PBT-03's
in-order-delivery property true, not an incidental default.**
`PeerConnectionHandle.createDataChannel` is always called with WebRTC's default
ordered+reliable configuration (no `maxRetransmits`/`maxPacketLifeTime`, no
`ordered: false`). Every `CaptionWireMessage` a viewer receives therefore arrives in the
exact order `sendToAll`/`sendTo` wrote it, with delivery guaranteed as long as the
channel stays open — this is the mechanism, not just an assumption, behind "every
connected viewer receives every caption, in order, after its join point" (PBT-03).

**Rule 6 — `ViewerAdmission`'s cap accounts for a disconnected viewer's `reconnectWindow`
grace period; a slot is never handed to a new viewer while its original holder might
still reclaim it.**
State per tracked `peerId`: `active` (counted against `maxViewers`) or
`reservedUntil: DateTime` (still counted against `maxViewers`, but eligible for reclaim).
- `tryAdmit(peerId)` for a `peerId` with no existing state: `Admitted` and `active` if
  `count < maxViewers`, else `Full`.
- `tryAdmit(peerId)` for a `peerId` currently `reservedUntil` (i.e. the same viewer
  reconnecting within its window): always `Admitted`, transitions back to `active`, no
  net change to `count` — this is the reclaim path Q6 exists for.
- `release(peerId)` for an `active` `peerId`: transitions to `reservedUntil = now +
  reconnectWindow`. `count` (the number of `active` **and** `reservedUntil` entries
  combined) does **not** decrease yet.
- A `reservedUntil` entry whose deadline passes with no reclaiming `tryAdmit` is
  removed entirely; `count` decreases by one at that point, freeing the slot for a
  genuinely new viewer.
- **Invariant** (PBT-03's cap property, stated precisely for the property test's
  reference model): `count` (active + reserved) never exceeds `maxViewers`, under any
  interleaving of `tryAdmit`/`release` calls, including when a reservation's deadline
  expiry and a new `tryAdmit` race — expiry must be checked and applied before a new
  `tryAdmit` can consume the freed slot, never concurrently in a way that could
  transiently exceed the cap.

**Rule 7 — `CaptionWireCodec` wire-format version 1; decode failures are dropped, never
thrown (mirrors Unit 3's `SignalingCodec`, Business Rule 4, exactly).**
`encode` always emits version 1. `decode` returns `null` for an unsupported version,
unrecognized shape, or invalid field types. Every consumer (`RemoteCaptionReceiver`)
treats `null` as "ignore this message" — a single malformed or future-version message
from a misbehaving peer must never crash the receiving side, for the same reasoning
Unit 3 already established for signaling messages.

**Rule 8 — `RemoteBroadcastTarget` sends exactly one snapshot message per newly joined
viewer; never a caption backlog (FR-5.4).**
On `viewerJoined` (which, per Rule 1, only ever fires for an ack-confirmed viewer),
`RemoteBroadcastTarget` sends exactly one `CaptionWireMessage.CaptionActivityChanged`
carrying `currentActivity` to that one `peerId`, via `sendTo` — never any buffered or
replayed `Caption` messages from before that viewer's join point.
