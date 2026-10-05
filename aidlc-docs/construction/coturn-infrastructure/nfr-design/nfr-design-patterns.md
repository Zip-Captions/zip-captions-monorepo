# NFR Design Patterns — Coturn Infrastructure (Unit 4)

## Resilience Patterns

### Credential-fetch failure handling (Q1)

`SupabaseTurnCredentialService.fetch`/`SupabaseIceServerProvider.iceServersFor` do not
retry and do not fall back to a degraded (STUN-only) `IceServer` list on failure — any
exception from the underlying Postgres RPC call (network error, Postgres unreachable,
RLS/auth rejection) propagates uncaught to the caller. A WebRTC connection attempt needs
ICE servers before ICE gathering can even start; silently degrading to STUN-only would
defer the real problem to a much more confusing later failure (an ICE connection
timeout) for exactly the symmetric-NAT users TURN exists to serve (Spike 2.3). Unit 5's
transport layer decides how to surface "couldn't start this session" to its own caller
(user-facing error, retry, etc.) — that's a session-orchestration decision, not this
unit's. Matches `SupabaseBroadcastIdentityRepository`'s precedent (Unit 3): a thin
adapter propagates a clear failure rather than inventing degraded-mode behavior.

### Credential expiry (restated from NFR Requirements Q5)

This unit's own components have no resilience obligation here beyond correctly
supporting repeated calls — `TurnCredentialService.fetch` can be called again at any
time for a fresh credential. The actual resilience requirement (detecting approaching
expiry and proactively renewing before a `Refresh` request fails) is Unit 5's, since
only Unit 5's transport components hold a long-lived session to monitor.

## Scalability Patterns

Restated from NFR Requirements Q1: relay port range widened to `49152–65535` (~16,384
ports), fixing Spike 2.3's accidentally-narrow 100-port test config. Nothing new to
design at this stage — the fix is a Coturn config value, finalized at this unit's own
Infrastructure Design.

## Performance Patterns

Restated from NFR Requirements Q2: no new formal latency target for TURN
allocation/ICE gathering (already implicitly bounded by NFR-1.3's join-to-first-caption
target). Nothing new to design.

## Security Patterns

### `IceServer` shape (Q2)

Fixed as `IceServer({required List<String> urls, String? username, String? credential})`
— the standard WebRTC `RTCIceServer` descriptor shape, matching what `flutter_webrtc`
(Unit 5) expects directly. `username`/`credential` are nullable since the STUN entry in
the list needs neither.

### Credential flow

`SupabaseIceServerProvider.iceServersFor(sessionId)` calls
`SupabaseTurnCredentialService.fetch(sessionId)` (NFR Requirements Q4's
`get_turn_credentials()` RPC), then builds exactly two `IceServer` entries: one STUN
(`urls` only, pointing at Coturn's STUN listener) and one TURN (all three fields, using
the fetched `TurnCredentials`). No caching and no credential-sharing across sessions —
each call fetches fresh, since the RPC is cheap/stateless and sharing a credential
across sessions would undermine the short-TTL blast-radius reasoning from NFR
Requirements Q5.

### Restated from NFR Requirements

Credential issuance via a `SECURITY DEFINER` Postgres function (Q4), 1-hour TTL with
proactive renewal as a hard Unit 5 requirement (Q5), internal-only Prometheus metrics
(Q6), and the `denied-peer-ip` private-range relay denial carried forward from Spike 2.3
— all already fixed, nothing new to design here.
