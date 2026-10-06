# Domain Entities — Signaling Channel Privacy (Unit 3.1)

## Channel Topology (revised 2026-10-06 — see plan's "Lobby Mechanism" section)

```
status:{broadcast_id}                    — unchanged (Unit 3, StatusChannel)
broadcast_join_requests (table, not a channel) — new: viewer calls
                                            submit_join_request() RPC (no subscribe);
                                            broadcaster subscribes via Postgres
                                            Changes, filtered to its own broadcast_id
signaling:{session_id}:{peerId}          — new (Q3/Q4): one per accepted viewer,
                                            symmetric RLS, unguessable peerId;
                                            carries everything except the initial
                                            join request
```

`status:{broadcast_id}` is untouched by this unit. The original design used a
Realtime Broadcast-extension `signaling:{broadcast_id}:lobby` channel for the join
request — **confirmed unworkable by direct testing**: Realtime's `subscribe()`
rejects the entire join for any client lacking a matching SELECT policy, regardless of
whether that client ever wires a receive callback, so a send-only viewer could never
open the channel at all. Replaced with a table + RPC + Postgres Changes, which removes
the subscribe step for the viewer side entirely.

## Join-request mechanism (replaces `LobbyChannel`, Q1/Q2/Q6)

No channel object on the viewer side — a plain async call:

```
Future<void> submitJoinRequest(BroadcastId broadcastId, String peerId); // viewer-only;
                                                  // wraps the submit_join_request RPC
Stream<JoinRequest> joinRequests(BroadcastId broadcastId);              // broadcaster-only;
                                                  // wraps a Postgres Changes
                                                  // subscription on
                                                  // broadcast_join_requests, filtered
                                                  // to this broadcast_id; internally
                                                  // calls consume_join_request() once
                                                  // a row is forwarded downstream
```

A viewer never subscribes to anything for this step — it has no reason to, and is
granted no SELECT on `broadcast_join_requests` at all. Only `JoinRequest` is ever
produced by this mechanism; every other `SignalingMessage` variant moves to the
per-viewer channel below.

## `SessionSignalingChannel` (revised — fixed at this stage, Q6)

```
abstract interface class SessionSignalingChannel {
  Future<void> open();
  Future<void> send(SignalingMessage message);    // any variant except JoinRequest
  Stream<SignalingMessage> get messages;
  Future<void> close();
}
```

Same shape as before, **minus** the `presence` getter (Q5 — dropped entirely) and now
opened per-`(sessionId, peerId)` pair instead of per-`(sessionId, role)`. `SignalingRole`
is removed — nothing about this channel's behavior depends on who opened it; both the
broadcaster (once per accepted viewer) and that one viewer (once) open the identical
channel shape for the same topic.

## `SignalingService` (revised — fixed at this stage, Q6)

```
abstract interface class SignalingService {
  StatusChannel statusChannel(BroadcastId id);                       // unchanged
  Future<void> submitJoinRequest(BroadcastId broadcastId, String peerId); // new, viewer-only
  Stream<JoinRequest> joinRequests(BroadcastId broadcastId);          // new, broadcaster-only
  SessionSignalingChannel sessionChannel(String sessionId, String peerId); // revised
}
```

## `PeerId` (new, lightweight — Q3)

Not a validated value type like `BroadcastId` (no canonical format to enforce beyond
"sufficient entropy") — a plain `String`, client-generated once per connection attempt
via a cryptographically-random v4-UUID-equivalent generator (128 bits). Never derived
from account identity, never reused across connection attempts (a fresh `peerId` on
every `connect()`/`restart()` re-signal per Unit 5's own reconnection design — the old
channel's `peerId` is abandoned, a new one generated and subscribed to before the next
`JoinRequest`). This is the entire privacy mechanism for the per-viewer channel: nobody
but the broadcaster and that one viewer ever learns this value.

## `SignalingMessage` (unchanged shape, changed routing)

No change to the sealed type itself (still `JoinRequest | JoinAccepted | JoinRejected |
SdpOffer | SdpAnswer | IceCandidate | IceRestart | Leave | BroadcastEnded`, same fields,
same `SignalingCodec`). What changes is which channel carries which variant:

| Variant | Mechanism |
|---|---|
| `JoinRequest` | `submit_join_request` RPC / `broadcast_join_requests` row (not a `SignalingMessage`-carrying channel at all) |
| `JoinAccepted`, `JoinRejected`, `SdpOffer`, `SdpAnswer`, `IceCandidate`, `IceRestart`, `Leave`, `BroadcastEnded` | Per-viewer (`signaling:{session_id}:{peerId}`) |

## `PresenceSnapshot` (removed from this unit's scope — Q5)

No longer produced by either channel type. Not deleted from `zip_core` by this unit
(nothing else references it, but removing unused public API is a judgment call left to
whoever next touches it, not forced here) — simply unused going forward.
