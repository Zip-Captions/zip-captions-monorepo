# Logical Components — Coturn Infrastructure (Unit 4)

## Package Placement

`zip_supabase` gets only the SQL function (not a Dart package, per `AGENTS.md`); all
Dart types/implementations live in `zip_core`, mirroring every prior unit's placement
(`SupabaseAuthService`, `SupabaseBroadcastIdentityRepository`, `SupabaseSignalingService`
are all here, consumed by both apps).

## Component List

| Component | Package | Kind | Responsibility |
|---|---|---|---|
| `get_turn_credentials()` | `zip_supabase` | SQL function (`SECURITY DEFINER`) | Computes the TURN REST HMAC-SHA1 credential server-side; the shared secret (`app.settings.turn_shared_secret`) never leaves Postgres. |
| `TurnCredentials` | `zip_core` | value model | `username`, `credential`, `expiresAt`, `urls` — fixed shape from Application Design (`zip_core/lib/src/models/`). |
| `IceServer` | `zip_core` | value model | `urls`, `username?`, `credential?` (NFR Design Q2) — the shape `flutter_webrtc` expects (`zip_core/lib/src/models/`). |
| `TurnCredentialService` | `zip_core` | interface | `fetch(sessionId) -> TurnCredentials` (`zip_core/lib/src/services/webrtc/`). |
| `SupabaseTurnCredentialService` | `zip_core` | impl (Adapter) | Calls `get_turn_credentials()` via `supabaseClientProvider` (Unit 2's provider, reused as-is — no change to it). Propagates any failure uncaught (NFR Design Q1) — no retry, no fallback. |
| `IceServerProvider` | `zip_core` | interface | `iceServersFor(sessionId) -> List<IceServer>` (`zip_core/lib/src/services/webrtc/`). |
| `SupabaseIceServerProvider` | `zip_core` | impl | Composes `SupabaseTurnCredentialService`'s fetched credentials with Coturn's known STUN/TURN URLs into the two-entry `IceServer` list. Constructed with those URLs at app startup (mirrors how `supabaseClientProvider`'s URL is provided, not discovered at runtime). |
| Coturn service | local dev stack | infra | STUN/TURN, ephemeral credentials, payload-free logs, private-range denial, Prometheus metrics (SR-03) — config validated by Spike 2.3, finalized at this unit's own Infrastructure Design. |

## Integration Points

- `SupabaseTurnCredentialService` → `supabaseClientProvider` (Unit 2's provider, reused
  as-is).
- `SupabaseIceServerProvider` → `SupabaseTurnCredentialService`'s `fetch` call, composed
  with Coturn's STUN/TURN URLs (a construction-time configuration value, not a runtime
  lookup).
- `get_turn_credentials()` → Postgres's `app.settings.turn_shared_secret`, set the same
  way `app.settings.jwt_secret` already is.

## Dependency Direction

```
zip_supabase (get_turn_credentials() SQL function — no Dart; SECURITY DEFINER)
        ▲ (schema/RPC contract only, no code dependency — same relationship as
        │  Unit 3's broadcast_identities migration)
        │
zip_core:
  TurnCredentialService ─▶ SupabaseTurnCredentialService ─▶ supabaseClientProvider
  IceServerProvider ─▶ SupabaseIceServerProvider ─▶ (SupabaseTurnCredentialService,
                                                      Coturn's known STUN/TURN URLs)
  TurnCredentials / IceServer ─▶ (nothing — pure Dart value models)
```

Not yet wired (explicitly out of this unit): `PeerConnectionFactory`,
`WebRtcBroadcastTransport`/`WebRtcViewerTransport` — anything that actually *consumes*
the ICE server list — and the proactive-credential-renewal requirement (NFR Requirements
Q5) are all Unit 5's responsibility.
