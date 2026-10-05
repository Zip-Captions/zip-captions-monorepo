# NFR Design Plan: Coturn Infrastructure (Unit 4)

**Unit**: coturn-infrastructure | **Prior stage**: NFR Requirements, approved 2026-10-02

## Planned Steps

- [ ] Resilience Patterns — TURN credential fetch failure handling
- [ ] Scalability Patterns — restated from NFR Requirements, no new question
- [ ] Performance Patterns — restated from NFR Requirements, no new question
- [ ] Security Patterns — `IceServer` shape, credential-flow walkthrough
- [ ] Logical Components — full component list and dependency direction
- [ ] Generate `aidlc-docs/construction/coturn-infrastructure/nfr-design/nfr-design-patterns.md`
- [ ] Generate `aidlc-docs/construction/coturn-infrastructure/nfr-design/logical-components.md`

## Resilience Patterns

### Q1: What should `IceServerProvider.iceServersFor`/`TurnCredentialService.fetch` do if the credential-fetch RPC fails (network error, Postgres unreachable, etc.)?

A WebRTC connection attempt needs ICE servers before it can start gathering candidates —
this isn't a background operation that can silently degrade.

- A. Let the exception propagate uncaught to the caller (Unit 5's transport layer) —
  no retry, no fallback to a STUN-only server list. A silent STUN-only fallback would
  just defer the same underlying problem to a much more confusing later failure (ICE
  connection timeout, for exactly the symmetric-NAT users TURN exists to serve — Spike
  2.3), with no actionable error message. Fail fast and clearly instead; Unit 5 decides
  how to surface "couldn't start this session" to its own caller (retry, user-facing
  error, etc.) — that's a session-orchestration decision, not this unit's. **(recommended
  — matches this project's established pattern of a thin adapter propagating a clear
  failure rather than inventing degraded-mode behavior nobody asked for; mirrors Unit
  3's `SupabaseBroadcastIdentityRepository`, which also doesn't retry or fall back
  internally)**
- B. Retry internally (e.g. 2 attempts with backoff) before giving up
- C. Fall back to a STUN-only `IceServer` list if the TURN credential fetch fails
- D. Other (write in)

[Answer]: A

## Scalability Patterns — restated from NFR Requirements, no new question

Covered in full at NFR Requirements Q1: relay port range widened to `49152–65535`
(~16,384 ports), sized with headroom over Spike 2.1's interim `maxViewers=50`. Nothing
new to design here — this unit's own scalability surface is entirely the Coturn config
itself, already fixed.

## Performance Patterns — restated from NFR Requirements, no new question

Covered in full at NFR Requirements Q2: no new formal latency target for TURN
allocation/ICE gathering (already implicitly bounded by NFR-1.3). Nothing new to design.

## Security Patterns

### Q2: What's the `IceServer` model's shape?

Application Design fixes `IceServerProvider.iceServersFor` returning `List<IceServer>`
but never gives `IceServer` itself a concrete shape (unlike `TurnCredentials`, which has
`username, credential, expiresAt, urls` in a comment).

- A. `IceServer({required List<String> urls, String? username, String? credential})` —
  matches the standard WebRTC `RTCIceServer` descriptor shape `flutter_webrtc` (Unit 5)
  expects directly, with `username`/`credential` nullable since the STUN-only entry in
  the returned list needs neither. `iceServersFor` returns exactly two entries: one STUN
  (`urls` only) and one TURN (all three fields, using the fetched `TurnCredentials`).
  **(recommended — the obvious, standard shape; inventing anything else would just
  require Unit 5 to re-map it into this exact shape anyway before handing it to
  `flutter_webrtc`)**
- B. A different shape (write in)
- C. Other (write in)

[Answer]: A

### Credential flow (not a question — restated for traceability)

`SupabaseIceServerProvider.iceServersFor(sessionId)` calls
`SupabaseTurnCredentialService.fetch(sessionId)`, which calls the `get_turn_credentials()`
Postgres RPC (NFR Requirements Q4) and maps the response into `TurnCredentials`. The
provider then builds the two-entry `IceServer` list (Q2). No caching, no
credential-sharing across sessions — each `iceServersFor` call fetches fresh (the RPC is
cheap and stateless; sharing a credential across sessions would also undermine the
short-TTL blast-radius reasoning from NFR Requirements Q5).

## Logical Components

### Component List

| Component | Package | Kind | Responsibility |
|---|---|---|---|
| `get_turn_credentials()` | `zip_supabase` | SQL function (`SECURITY DEFINER`) | Computes the TURN REST HMAC credential server-side; shared secret never leaves Postgres. |
| `TurnCredentials` | `zip_core` | value model | `username`, `credential`, `expiresAt`, `urls` — fixed shape from Application Design. |
| `IceServer` | `zip_core` | value model | `urls`, `username?`, `credential?` (Q2) — the shape `flutter_webrtc` expects. |
| `TurnCredentialService` | `zip_core` | interface | `fetch(sessionId) -> TurnCredentials`. |
| `SupabaseTurnCredentialService` | `zip_core` | impl (Adapter) | Calls `get_turn_credentials()` via `supabaseClientProvider` (Unit 2's provider, reused as-is). |
| `IceServerProvider` | `zip_core` | interface | `iceServersFor(sessionId) -> List<IceServer>`. |
| `SupabaseIceServerProvider` | `zip_core` | impl | Composes `TurnCredentialService` + the known Coturn STUN/TURN URLs into the two-entry list (Q1 credential-flow). |
| Coturn service | local dev stack | infra | STUN/TURN, ephemeral credentials, payload-free logs, private-range denial, Prometheus metrics (SR-03) — config fixed by Spike 2.3, finalized at this unit's own Infrastructure Design. |

### Dependency Direction

```
zip_supabase: get_turn_credentials() (SQL, SECURITY DEFINER — no Dart)
        ▲ (schema/RPC contract only, no code dependency)
        │
zip_core: TurnCredentialService ─▶ SupabaseTurnCredentialService ─▶ supabaseClientProvider
          IceServerProvider ─▶ SupabaseIceServerProvider ─▶ (SupabaseTurnCredentialService, Coturn's known STUN/TURN URLs)
          TurnCredentials / IceServer ─▶ (nothing — pure Dart value models)
```

No Dart code depends on `zip_supabase` directly — same "schema contract, not code
dependency" relationship as Unit 3's `broadcast_identities` migration. Coturn's STUN/TURN
URLs (hostnames/ports) are configuration `SupabaseIceServerProvider` is constructed with,
not discovered dynamically — mirrors how `supabaseClientProvider`'s URL is provided at
app startup, not looked up at runtime.

Not yet wired (explicitly out of this unit): anything that actually *uses* the ICE
servers — `PeerConnectionFactory`, `WebRtcBroadcastTransport`/`WebRtcViewerTransport`,
and the proactive-credential-renewal requirement (NFR Requirements Q5) are all Unit 5's
responsibility.
