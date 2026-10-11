# Domain Entities — WebRTC Transport + Remote Output + Capacity

## ConnectionType (enum, fixed at Application Design)

`p2pDirect | turnRelayed | connecting | disconnected` (FR-4.6). Reported per viewer on
the broadcaster side via `ViewerConnectionInfo.connectionType`, and to the viewer itself
via its own `ConnectionStatus.connected(ConnectionType)`. Derived from the peer
connection's own candidate-pair selection (host candidate selected → `p2pDirect`; relay
candidate selected → `turnRelayed`), not inferred from network heuristics.

## ViewerConnectionInfo (model, fixed shape + this unit's own invariant)

`{ peerId: String, connectionType: ConnectionType, connectedAt: DateTime }` — "no viewer
identity" (NFR-6.2) means exactly `peerId` (the ephemeral signaling-layer id, Unit 3) and
nothing from `BroadcastIdentityRepository`/auth. `connectedAt` is set once, at the moment
`BroadcastTransport.viewers` first includes this `peerId` — i.e. after the Q1 join-ack
confirms the viewer, not at raw data-channel "open" (business-rules.md).

## ConnectionStatus (sealed, fixed shape)

```
ConnectionStatus = Connecting
                 | Connected(ConnectionType)
                 | Interrupted
                 | Failed(ConnectFailure)
```

`Interrupted` is the FR-7.4 "reconnecting" state — entered when the peer connection's
ICE state degrades (`disconnected`/`failed` natively) and `WebRtcViewerTransport` starts
its Q2 backoff retry loop. Per Q2, `Interrupted` has no automatic timeout into `Failed`
— only a genuinely terminal condition (broadcast ended, or the viewer calling
`disconnect()`) produces `Failed`, or the broadcaster-signaled `BroadcastEnded` message
(Unit 3) produces the separate "broadcast ended" viewer-visible state (FR-7.4), which is
not a `ConnectionStatus` variant at all — it's `CaptionWireMessage.ended` surfaced by
`RemoteCaptionReceiver.ended` to the viewer session layer (Unit 7), independent of the
transport's own connection health.

## ConnectFailure (sealed — fixed at this stage, Q3)

```
ConnectFailure = BroadcastFull
               | IceFailed
               | SignalingRejected
               | Timeout
```

- `BroadcastFull`: mapped from a `SignalingMessage.JoinRejected(JoinRejection.full)`
  (Unit 3, already fixed) — the one `ConnectFailure` variant with its own FR-8.2 UI copy
  requirement ("broadcast is full").
- `IceFailed`: the peer connection's own ICE state machine reports `failed` (not
  `disconnected` — that's `ConnectionStatus.Interrupted`'s trigger, see above) with no
  retry currently in progress or all Q2 retries exhausted by a terminal condition.
- `SignalingRejected`: any other `JoinRejected`/channel-level rejection not covered by
  `BroadcastFull` (e.g. the session no longer exists).
- `Timeout`: the viewer's own connect timeout — no response reaches it from the
  broadcaster/signaling layer within the connect window at all (business-rules.md fixes
  the value). Distinct from the broadcaster-side Q1 ack timer, which produces a
  `viewerLeft` on the broadcaster's side, not a `ConnectFailure` — a viewer whose own
  join request is the one that stalls experiences this as its *own* `Timeout`, not as
  being told it was removed.

## PeerConnectionHandle (interface — fixed at this stage, Q4)

```
PeerConnectionHandle {
  Future<RTCDataChannel> createDataChannel(String label);  // ordered+reliable, see business-rules.md
  Future<RTCSessionDescription> createOffer();
  Future<RTCSessionDescription> createAnswer();
  Future<void> setRemoteDescription(RTCSessionDescription sdp);
  Future<void> addIceCandidate(RTCIceCandidate candidate);
  Stream<RTCIceConnectionState> get iceConnectionState;
  Stream<RTCDataChannel> get onDataChannel;                 // viewer side: broadcaster-created channel arrives here
  Future<void> close();
}
```

The minimal surface both `WebRtcBroadcastTransport` and `WebRtcViewerTransport` actually
call — each method/stream independently fakeable in a unit test (NFR-7.3), rather than a
full `flutter_webrtc` `RTCPeerConnection` passthrough.

## BroadcastTransportContext / ViewerTransportContext (fixed at this stage, Q5 —
**revised 2026-10-07**, before this unit's Code Generation began, against Unit 3.1's
final signaling design)

The original fixed shape (below, superseded) carried a single `SessionSignalingChannel
channel` field — written against the pre-Unit-3.1 world, where one shared
`signaling:{session_id}` channel existed and `JoinRequest` arrived over it directly.
Unit 3.1 replaced that entirely: there is no single shared channel, `JoinRequest`
arrives via a Postgres-Changes-backed stream (`SignalingService.joinRequests`), and
`SessionSignalingChannel` is now opened per-`(sessionId, peerId)` pair, not once per
session.

```
BroadcastTransportContext { String sessionId, BroadcastId broadcastId,
                             SignalingService signalingService,
                             List<IceServer> iceServers, ViewerAdmission admission }
ViewerTransportContext   { String sessionId, BroadcastId broadcastId,
                             SignalingService signalingService,
                             List<IceServer> iceServers }
```

Both contexts now carry the `SignalingService` + `BroadcastId` instead of a pre-opened
channel: `WebRtcBroadcastTransport` calls `signalingService.joinRequests(broadcastId)`
to learn about joins, then `signalingService.sessionChannel(sessionId, peerId)` per
accepted viewer (business-logic-model.md); `WebRtcViewerTransport.connect()`/
`restart()` generates a fresh `peerId()` internally on every call (never supplied via
context, never reused — matching Unit 3.1 `business-rules.md` Rule 5), calls
`signalingService.submitJoinRequest(broadcastId, peerId)`, then opens its own
`sessionChannel(sessionId, peerId)`. Constructed by the caller (`BroadcastSessionNotifier`,
Unit 6; the viewer-side session orchestrator, Unit 7) from values already available to
it via `SignalingService`/`BroadcastId` resolution (Unit 3/3.1) and `IceServerProvider`
(Unit 4) — this unit does not resolve these itself.

*Superseded shape, retained for the audit trail:*
```
BroadcastTransportContext { String sessionId, SessionSignalingChannel channel,
                             List<IceServer> iceServers, ViewerAdmission admission }
ViewerTransportContext   { String sessionId, SessionSignalingChannel channel,
                             List<IceServer> iceServers }
```

## CaptionWireMessage (sealed, fixed shape) / CaptionActivity (enum, fixed)

```
CaptionWireMessage = Caption(SttResult fields, per ADR-005)
                    | CaptionActivityChanged(CaptionActivity)
                    | Ended
CaptionActivity = active | paused | inactive
```

Wire-format version: **1** (Q7). `CaptionWireCodec.encode` always emits version 1;
`decode` returns `null` for an unsupported version, an unknown message shape, or invalid
field types — mirroring `SignalingCodec`'s identical, already-approved pattern from Unit
3 exactly, including the "never throws" boundary guarantee.

## BroadcastLimits / AdmissionDecision (fixed shape, this unit's own reservation state — Q6)

```
BroadcastLimits { int maxViewers, Duration presenceTimeout, Duration reconnectWindow }
                 // interim values: 50 / 60s / 120s (Spike 2.1) — injected config, not literals
AdmissionDecision = Admitted | Full
```

`ViewerAdmission` (business logic below) additionally tracks, per `peerId`, whether a
released slot is in its `reconnectWindow` grace period — this is internal state, not a
new fixed public type; `tryAdmit`/`release`/`count`'s signatures are unchanged from
Application Design.
