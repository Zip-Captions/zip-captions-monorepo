# Domain Entities — Broadcast Identity + Signaling

## BroadcastId (value object)

Wraps a validated 6-character Crockford-Base32 string (SR-02 §3). `parse` throws
`FormatException`; `tryParse` returns `null`. Invariant: a `BroadcastId` instance always
holds a value that passed alphabet/length validation — invalid strings never reach a
network call (FR-2.3, `business-rules.md`'s SECURITY-05-adjacent boundary validation).

## BroadcastLink (parsing utility)

Not a domain entity itself, but the boundary between free-form user input (pasted URL or
bare code) and a validated `BroadcastId`. `parseInput` accepts `k7m9x2`,
`zipcaptions.app/b/k7m9x2`, or the full `https://` form; anything else returns `null`
(never throws) — this is what lets `ViewerSessionNotifier` (Unit 7) treat "invalid
input" as `invalidInput` without a network call, per `phase2-services.md`'s F4 flow.

## BroadcastResolution (sealed)

```
BroadcastResolution = NotFound
                    | Offline
                    | Live(sessionId: String, sessionName: String)
                    | RateLimited
                    | ResolutionFailed
```

- `NotFound`: `resolve_broadcast_id` returned `false` (SR-02 §2) — the code doesn't
  exist at all.
- `Offline`: the code exists, and the second resolution step (a presence read on
  `status:{broadcast_id}`) **completed successfully** and found no presence — the
  broadcaster is confirmed not live right now.
- `Live(sessionId, sessionName)`: the code exists and a broadcaster is currently
  publishing on `status:{broadcast_id}`; carries only the session's own id and display
  name — never an account identifier (NFR-3.5).
- `RateLimited`: Kong rejected the resolution request (SR-02 §2). Reachable only once
  Kong's rate-limit config exists (Infrastructure Design); until then this variant is
  simply never produced — the sealed type is kept stable regardless (plan Q7).
- `ResolutionFailed`: **added at NFR Design (2026-09-30), extending the shape fixed at
  Application Design** — the code exists (step 1 succeeded) but the second step (the
  presence read) itself failed or timed out (a transient Realtime/network issue), so
  live/offline status is genuinely unknown, not confirmed offline. Kept distinct from
  `Offline` on the reasoning that conflating "we couldn't check" with "confirmed not
  live" could make a transient glitch look like the broadcaster going offline (NFR
  Design plan Q2 — the user's call, deviating from the initially recommended "fold into
  `Offline`" option). Callers (Unit 7) may retry on this variant; `Offline` should be
  treated as a stable, non-retry-suggesting result.

Invariant: exactly one variant per `resolve()` call; `Live`'s fields are never present
on any other variant (enforced by the type system, not runtime checking).

## SignalingMessage (sealed)

`JoinRequest(fromPeerId, viewerIdentity: null in Phase 2) | JoinAccepted(toPeerId) |
JoinRejected(toPeerId, JoinRejection) | SdpOffer | SdpAnswer | IceCandidate |
IceRestart | Leave(fromPeerId) | BroadcastEnded` — every variant carries `type` and
`version` (Section 3, fixed). `SignalingCodec.decode` is the sole boundary from raw
JSON into this type: malformed, unknown-`type`, unsupported-`version`, or oversized
input all resolve to `null`, never a thrown exception (`business-rules.md`).

## PresenceSnapshot

Not yet given a concrete shape at Application Design beyond "presence stream for viewer
count" (Section 3's `SessionSignalingChannel.presence`). This unit fixes it as: a
snapshot of currently-tracked peer ids on a session's `signaling:{session_id}` presence
channel, with a count derived from its length — no per-viewer identity beyond the
ephemeral peer id (never a `viewerIdentity`, which is always `null` in Phase 2 per
FR-3.5). Used by the broadcaster's dashboard (Unit 6) for the viewer count against the
capacity cap (FR-8.3) and by Unit 5's `ViewerAdmission` for capacity enforcement.

## BroadcastStatus

The value `StatusChannel.watch()` emits: live (carrying `sessionId`/`sessionName`) or
offline — the same shape as `BroadcastResolution`'s `Live`/`Offline` variants minus
`NotFound`/`RateLimited`, since a `StatusChannel` is only ever opened for a code that's
already known to exist. Presence-expiry (the 60s timeout, Spike 2.1 interim) transitions
a stale `live` to `offline` automatically — this is a Realtime platform behavior
(presence entries expire), not application-level polling.
