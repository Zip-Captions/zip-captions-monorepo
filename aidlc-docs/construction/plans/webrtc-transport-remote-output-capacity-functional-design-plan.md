# Functional Design Plan: WebRTC Transport + Remote Output + Capacity (Unit 5)

**Stories**: S-14 (WebRTC Transport), S-16 (Remote Broadcast Output Target), S-18 (Viewer Capacity)
**Package**: `zip_core` (adds `flutter_webrtc`, an approved dependency per FR-4.1)
**Dependencies**: Unit 3 (signaling — done), Unit 4 (ICE servers — done), Spike 2.1 (cap/fan-out findings — paused, interim values accepted)

## Context

This is the first unit with real business logic since Unit 3 — unlike Unit 4, Functional
Design is not skipped. Fixed contracts from Application Design
(`phase2-component-methods.md` §4–5): `BroadcastTransport`, `ViewerTransport`,
`PeerConnectionFactory`, `TransportSelector`, `CaptionWireMessage`/`CaptionWireCodec`,
`RemoteBroadcastTarget`, `RemoteCaptionReceiver`, `BroadcastLimits`, `ViewerAdmission`.
Several supporting types are deliberately **not** fixed yet (left to this stage, per
"Signatures are indicative Dart... final names may be refined in Functional Design
without changing responsibilities"): `BroadcastTransportContext`/`ViewerTransportContext`,
`PeerConnectionHandle`, `ConnectFailure`, `ViewerConnectionInfo`'s full shape beyond what's
already fixed (`peerId`, `connectionType`, `connectedAt`).

**Spike 2.1's load-bearing finding for this unit**: at N=50 concurrent viewers, 74–84%
join success while the broadcaster's own log reports 100% of data channels "open" —
narrowed to the SCTP/DCEP handshake layer (not ICE/STUN, ruled out directly), not
confirmed/fixed. This is squarely inside `WebRtcBroadcastTransport`'s responsibility
(star topology, one peer connection per viewer, FR-4.2) and needs an explicit design
answer here, not deferral — see Q1.

**Cap value**: `BroadcastLimits.maxViewers = 50` (Spike 2.1 interim, tentative, below
FR-8.1's 100-200 target — tracked as an open Backlog item already, not re-decided here).
`presenceTimeout = 60s`, `reconnectWindow = 120s` — also interim. This unit treats them as
injected `const`/configuration values per Spike 2.1's own recommendation, not literals.

## Planned Steps

- [ ] Business logic: `WebRtcBroadcastTransport`'s per-viewer connection lifecycle,
      including the SCTP/DCEP-stall handling Spike 2.1 surfaced
- [ ] Business logic: `WebRtcViewerTransport`'s reconnection/ICE-restart policy
- [ ] Domain models: `ConnectFailure`, `BroadcastTransportContext`,
      `ViewerTransportContext`, `PeerConnectionHandle`
- [ ] Business rules: `ViewerAdmission`'s cap/reservation semantics, including the
      disconnect-vs-reconnectWindow interaction
- [ ] Business rules: `CaptionWireCodec` versioning and `RemoteBroadcastTarget`'s
      join-snapshot sequencing
- [ ] Generate `business-logic-model.md`, `business-rules.md`, `domain-entities.md`

## Business Logic Modeling

### Q1: How should `WebRtcBroadcastTransport` handle Spike 2.1's SCTP/DCEP-stall failure mode?

Spike 2.1's finding: a viewer's data channel can report "open" locally (broadcaster side)
without the DCEP handshake having actually completed with that viewer — so "100% channels
open" in the broadcaster's own log does not mean 100% are usable. The spike **narrowed**
this to the broadcaster's own SCTP/DCEP handling under concurrent channel creation but did
not confirm a fix (a pacing experiment was inconclusive). This unit can't wait for that
investigation to resume — a real design decision is needed now.

- A. Treat a data channel as "viewer joined" only after an **application-level
  handshake ack** — the viewer transport sends a small ack message immediately upon
  receiving its first wire message (or a dedicated `JoinAck`), and the broadcaster starts
  a bounded timer (e.g. 5s) from channel creation; if no ack arrives in time, treat that
  viewer as failed (emit `viewerLeft`, release its admission slot) rather than leaving it
  silently half-open. This gives `WebRtcBroadcastTransport` a real signal independent of
  the native "open" event, which Spike 2.1 showed is unreliable, and keeps per-viewer
  isolation (NFR-4.2) — one stalled viewer times out and is cleaned up without touching
  others. **(recommended — the only option that gives the broadcaster true visibility
  into the exact failure Spike 2.1 found, instead of trusting the same signal the spike
  showed lying)**
- B. No special handling in this unit — rely on the native `RTCDataChannel` "open" event
  as-is, and treat the SCTP/DCEP stall as purely Spike 2.1's unfinished investigation to
  resume later (Unit 9 or a resumed spike). Simpler, but ships Unit 5 with a known,
  already-measured failure mode (16–26% of joins at N=50) with no detection or recovery
  at all.
- C. Other (write in)

[Answer]: A

### Q2: What's `WebRtcViewerTransport`'s retry/backoff policy for `restart()`?

FR-7.5 requires automatic reconnection "without user action, via ICE restart or
re-signaling." The interface fixes `restart()` as a single method but not its retry
policy if the first restart attempt itself fails (e.g. still no network).

- A. Exponential backoff with a cap: retry at 1s, 2s, 4s, 8s, capped at 8s, continuing
  indefinitely as long as the underlying platform reports *some* network path (per
  `connectivity_plus` or equivalent) — matching a standard reconnection pattern and
  avoiding a battery-draining tight loop. Surface `ConnectionStatus.interrupted` while
  retrying, `ConnectionStatus.failed(ConnectFailure)` only if the viewer explicitly backs
  out (disconnects) or the broadcast itself ends. No fixed give-up point — matches FR-7.4's
  "reconnecting" state being one of the fixed set of viewer states, implying this is a
  state the viewer can stay in, not a path to failure.
  **(recommended — matches FR-7.4's distinct "reconnecting" vs "cannot connect" states:
  only a *terminal* condition like the broadcast ending should produce the latter)**
- B. Bounded retries (e.g. 5 attempts) then `ConnectionStatus.failed`, requiring the user
  to manually retry.
- C. Other (write in)

[Answer]: A

## Domain Model

### Q3: What does `ConnectFailure` need to distinguish?

`ConnectionStatus.failed(ConnectFailure)` is fixed as a sealed-model shape, but
`ConnectFailure`'s own variants aren't. FR-7.4 fixes the *viewer-visible* state set
(connecting, live, captions-paused, reconnecting, not-currently-broadcasting,
broadcast-ended, broadcast-full, cannot-connect-with-reason) — `ConnectFailure` is the
"with a specific reason" part of "cannot connect."

- A. `ConnectFailure { broadcastFull, iceFailed, signalingRejected, timeout }` —
  `broadcastFull` maps from a `JoinRejected(JoinRejection.full)` signaling message (Unit
  3, already fixed); `iceFailed` from the peer connection's own ICE state machine;
  `signalingRejected` from any other `JoinRejected`/channel-level rejection;
  `timeout` from Q1's broadcaster-side ack timer surfacing back to this specific viewer
  (if its own join attempt is the one that timed out) or a viewer-side connect timeout
  with no broadcaster response at all.
  **(recommended — each variant maps to a distinct, already-identified real cause, and
  "broadcast full" needs its own UI copy per FR-7.4/FR-8.2, not a generic failure message)**
- B. A single `ConnectFailure(String reason)` — less structured, UI must pattern-match
  on string content for the "broadcast full" case specifically.
- C. Other (write in)

[Answer]: A

### Q4: What does `PeerConnectionHandle` (the `PeerConnectionFactory` seam) need to expose?

Fixed as `Future<PeerConnectionHandle> create(List<IceServer> iceServers)` — the shape of
the handle itself is open. It exists specifically so transports are testable with fakes
(NFR-7.3), so its surface should be exactly what `WebRtcBroadcastTransport`/
`WebRtcViewerTransport` need, not a full `flutter_webrtc` passthrough.

- A. `PeerConnectionHandle { createDataChannel(label), createOffer(), createAnswer(),
  setRemoteDescription(sdp), addIceCandidate(candidate), Stream<RTCIceConnectionState>
  iceConnectionState, Stream<RTCDataChannel> onDataChannel, close() }` — the minimal set
  both transport implementations actually call, each individually fakeable in a test
  double. **(recommended — matches the stated NFR-7.3 purpose exactly: a thin seam, not a
  full API mirror)**
- B. Expose the raw `flutter_webrtc` `RTCPeerConnection` object directly, with no
  wrapping — simpler, but defeats NFR-7.3's "testable with fakes" goal, since
  `RTCPeerConnection` isn't fakeable without a real platform channel.
- C. Other (write in)

[Answer]: A

### Q5: What do `BroadcastTransportContext`/`ViewerTransportContext` carry?

Fixed as parameters to `start()`/`connect()` with inline comments "session channel, ICE
servers, admission" and "session channel, ICE servers" respectively — the actual field
list is open.

- A. (original answer, **superseded 2026-10-07** — see below) `BroadcastTransportContext
  { String sessionId, SessionSignalingChannel channel, List<IceServer> iceServers,
  ViewerAdmission admission }` / `ViewerTransportContext { String sessionId,
  SessionSignalingChannel channel, List<IceServer> iceServers }` — exactly the
  four/three things named in the existing inline comments, constructed by the caller
  (Unit 6's `BroadcastSessionNotifier` / Unit 7's viewer session orchestration) which
  already has all of them from `SignalingService`/`IceServerProvider` (Units 3–4).
- B. Other (write in)

**Revised 2026-10-07, before this unit's Code Generation began**, against Unit 3.1's
final signaling design (approved after this answer was written): there is no single
`SessionSignalingChannel` per session anymore — `JoinRequest` arrives via a
Postgres-Changes stream, and `SessionSignalingChannel` is opened per-`(sessionId,
peerId)` pair. Revised answer: `BroadcastTransportContext { String sessionId,
BroadcastId broadcastId, SignalingService signalingService, List<IceServer>
iceServers, ViewerAdmission admission }` / `ViewerTransportContext { String sessionId,
BroadcastId broadcastId, SignalingService signalingService, List<IceServer>
iceServers }` — both contexts carry the service + id instead of a pre-opened channel,
and each transport opens its own per-viewer channel(s) internally. See
`domain-entities.md`'s own revision note for the full reasoning.

[Answer]: A (revised)

[Answer]: A

## Business Rules

### Q6: How does `ViewerAdmission`'s cap interact with `reconnectWindow`?

Spike 2.1 defines `reconnectWindow` (interim 120s) but not how it's used. `ViewerAdmission`
is fixed as a flat `tryAdmit(peerId)`/`release(peerId)`/`count` counter keyed only by
`maxViewers`. The open question: does a viewer who disconnects and reconnects within
`reconnectWindow` need their admission slot *reserved* (not released immediately, so a
new viewer can't take their place and lock them out), or is `reconnectWindow` purely a
higher-level (Unit 6/7) UX concept that doesn't touch `ViewerAdmission` at all?

- A. `ViewerAdmission` is reconnection-aware: `release(peerId)` doesn't immediately
  decrement `count` — it starts a `reconnectWindow` timer for that `peerId` first. A
  fresh `tryAdmit(peerId)` for the *same* `peerId` within the window reclaims the
  reserved slot (no net change to `count`); if the window expires with no reclaim, the
  slot is released for real. A *different* `peerId` can never jump the reservation.
  **(recommended — this is the only reading of "the count can never exceed maxViewers
  under concurrent joins" (component-methods.md) that also makes `reconnectWindow`
  actually do something for the one component that owns capacity; otherwise a
  reconnecting viewer could lose their slot to someone else mid-reconnect, defeating
  the entire reason `reconnectWindow` exists per Spike 2.1's own recommendation)**
- B. `ViewerAdmission` stays a flat counter; `reconnectWindow` is handled entirely above
  this unit (e.g. the broadcaster's dashboard/session layer tracks recently-disconnected
  peer ids itself and declines to admit a replacement). Keeps `ViewerAdmission` simpler,
  but duplicates slot-tracking logic in whichever higher unit implements it, and risks
  the two counters disagreeing.
- C. Other (write in)

[Answer]: A

### Q7: `CaptionWireMessage` wire-format versioning — what's the current version, and what happens on a version mismatch?

`CaptionWireCodec.decode` is fixed to "return null for... unsupported version" (mirroring
`SignalingCodec`'s identical pattern from Unit 3). Need the concrete starting version
number and the caller-side behavior when `decode` returns null.

- A. Version `1`. On the viewer side, a null decode result is dropped silently (matching
  `SessionSignalingChannel.messages`'s "already validated; invalid messages are dropped"
  precedent) — a malformed/future-version message never crashes `RemoteCaptionReceiver`
  or surfaces as a caption. On the broadcaster side, `CaptionWireCodec.encode` always
  emits the current version, so this case only matters for a future version bump, not at
  initial ship. **(recommended — exact precedent match with Unit 3's already-approved
  `SignalingCodec` handling, no new pattern invented)**
- B. Other (write in)

[Answer]: A

### Q8: `RemoteBroadcastTarget`'s join-snapshot sequencing — exact ordering?

Fixed: "Tracks the latest activity and sends it to each newly joined viewer as a
snapshot... never sends caption backlog" (FR-5.4). The `viewerJoined` stream (on
`BroadcastTransport`) is how `RemoteBroadcastTarget` learns of a new viewer — need the
precise trigger and payload.

- A. On `BroadcastTransport.viewerJoined` firing for a `peerId` (which, per Q1, only
  fires *after* the ack-based join confirmation — i.e. a viewer that's genuinely ready
  to receive messages, not merely channel-created), `RemoteBroadcastTarget` immediately
  calls `transport.sendTo(peerId, CaptionWireMessage.captionActivity(currentActivity))`
  — exactly one message, the current activity only, nothing else. Subsequent captions
  reach this viewer the same way every other viewer gets them (`sendToAll`), with no
  special-casing after the snapshot. **(recommended — the simplest reading that honors
  "never sends backlog" literally: one snapshot message, then normal broadcast)**
- B. Other (write in)

[Answer]: A

## PBT Properties to Carry Forward (restated, no new question)

Per `phase2-requirements.md` PBT-03 and this unit's own Notes ("this is where PBT covers
the wire format round-trip, in-order delivery after join, the cap invariant and the peer
connection state machine"):
- `CaptionWireCodec` round-trip (encode/decode identity, mirroring `SignalingCodec`'s PBT
  suite from Unit 3)
- Cap invariant: `ViewerAdmission.count` never exceeds `maxViewers` under any sequence of
  `tryAdmit`/`release` calls (including the Q6 reconnect-reservation behavior)
  — a model-based/stateful PBT target, same style as Unit 2's `AuthNotifier` state-machine
  PBT suite
- In-order delivery: every connected viewer receives every caption, in order, after its
  join point (PBT-03) — exercised against a fake `PeerConnectionFactory`/transport pair,
  per this unit's own Notes ("both protocol sides are tested together against fakes")

These will be finalized as concrete PBT properties at NFR Requirements, not re-litigated
here.
