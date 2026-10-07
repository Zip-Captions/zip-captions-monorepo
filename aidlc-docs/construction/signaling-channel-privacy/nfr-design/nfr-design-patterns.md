# NFR Design Patterns — Signaling Channel Privacy (Unit 3.1)

## Resilience

**Viewer-side `JoinRequest` resend (Q1)**: if no response (`SdpOffer`, `JoinAccepted`,
or `JoinRejected` arriving on the viewer's own per-viewer channel) appears, the viewer
resends `JoinRequest` on the lobby channel at **2s, 5s, then 10s** (3 attempts total
beyond the initial send). This covers the one gap `business-logic-model.md`'s happy
path left open: nothing previously bounded how long a viewer waits if the broadcaster
never even saw the request (missed/dropped `JoinRequest`, or crashed between receiving
it and subscribing to the per-viewer channel).

A resend is safe to make unconditionally idempotent: the broadcaster's lobby-side
handling of a duplicate `JoinRequest` for a `peerId` it's already subscribed to (because
an earlier attempt *did* arrive, and only the broadcaster's *response* was lost or
delayed) is a harmless no-op — re-subscribing to an already-subscribed topic, or
re-sending `JoinAccepted` to a viewer that's already listening, changes nothing.

If all 3 resends produce nothing, the viewer maps this to `ConnectFailure.Timeout` —
Unit 5's existing variant (domain-entities.md), not a new signaling-specific failure
type. From the viewer's own perspective, "the broadcaster never responded to my join
attempt" and "the broadcaster responded but the data channel never confirmed" (Unit 5's
own Rule 1 ack-timeout) are both just "I asked to connect and nothing came of it within
a bounded wait" — one failure variant covers both causes correctly.

**UI note (carried to Unit 7, not this unit's own scope)**: the entire resend/backoff
window stays within `ConnectionStatus.Connecting` (already fixed, FR-7.4) — no new
state. The user specifically wants a "Joining..." progress message rendered for this
state (not a bare spinner) so a viewer understands a process is underway during the
backoff. Tracked as a Backlog item for Unit 7's own Functional Design to pick up the
exact copy.

## Scalability / Performance (restated from NFR Requirements, no new pattern)

The up-to-51-concurrent-channel load (one `LobbyChannel` + up to `maxViewers`
`SessionSignalingChannel`s on the broadcaster's client) is a verification target for
Code Generation, not a design pattern this stage introduces. The join sequence's added
latency (one extra Realtime subscribe round-trip versus the old one-hop design) folds
into Unit 5's existing NFR-1.3 target. Nothing new to design here.

## Security (restated from SR-04, no new pattern)

Every RLS policy, the lobby's ownership-check mechanism, and the symmetric per-viewer
channel authorization are already fully fixed at SR-04. This stage adds no new security
pattern.
