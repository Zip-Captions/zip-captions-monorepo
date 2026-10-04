# Handoff Summary — Coturn Infrastructure (Unit 4) → Code Generation

## What This Unit Delivers

TURN/STUN infrastructure (Coturn) wired into the real local dev stack, plus the
server-side credential-issuing function and the `zip_core` Dart types/services that
consume it. No business logic (Functional Design was skipped for this unit, per
`phase2-unit-of-work.md`). No wiring into actual WebRTC peer connections — that's Unit 5.

## Fixed Contracts (do not redesign at Code Generation)

- `IceServerProvider.iceServersFor(String sessionId) -> Future<List<IceServer>>`
  (Application Design, `phase2-component-methods.md`)
- `TurnCredentialService.fetch(String sessionId) -> Future<TurnCredentials>`
  (Application Design)
- `IceServer({required List<String> urls, String? username, String? credential})`
  (NFR Design Q2)
- `TurnCredentials`: `username`, `credential`, `expiresAt`, `urls` (NFR Design)
- `get_turn_credentials()` Postgres function: returns `username, credential, ttl, urls`
  (Infrastructure Design Section 4)
- Credential-fetch failure handling: propagate uncaught, no retry/fallback (NFR Design Q1,
  matches `SupabaseBroadcastIdentityRepository`'s precedent)

## Files to Create/Modify

**`packages/zip_supabase/`**
- `migrations/<timestamp>_coturn_turn_credentials.sql` — new (Section 4)
- `docker-compose.yml` — add `coturn` service (Section 2)
- `volumes/coturn/turnserver.conf` — new, derived from Spike 2.3's validated config,
  widened port range, `${TURN_SHARED_SECRET}` substitution (Section 2)
- `.env.example` — add `TURN_SHARED_SECRET=` placeholder (Section 3)

**`packages/zip_core/`**
- `lib/src/models/turn_credentials.dart` — new
- `lib/src/models/ice_server.dart` — new
- `lib/src/services/webrtc/turn_credential_service.dart` — new (interface)
- `lib/src/services/webrtc/supabase_turn_credential_service.dart` — new (impl)
- `lib/src/services/webrtc/ice_server_provider.dart` — new (interface)
- `lib/src/services/webrtc/supabase_ice_server_provider.dart` — new (impl)
- Riverpod providers for the above, following the existing provider-per-service pattern
  (e.g. how `SupabaseBroadcastIdentityRepository` is provided)

## Testing Approach (NFR Requirements Q10, restated)

- Mocktail unit tests for `SupabaseTurnCredentialService` and `SupabaseIceServerProvider`
  (mock the Supabase client / `TurnCredentialService` respectively)
- One real-backend integration test, tagged `integration-supabase` (skip-by-default,
  Unit 3's `dart_test.yaml` convention), calling the real `get_turn_credentials()` RPC
  against the local dev stack and asserting a well-formed, HMAC-valid credential

## Not In Scope (explicitly deferred to Unit 5)

- Anything consuming the ICE server list (`PeerConnectionFactory`, transport classes)
- Proactive credential renewal before TTL expiry (NFR Requirements Q5 — hard requirement,
  not optional, for Unit 5)

## Approval Gates for This Unit

- SR-03 (`sr-03-log-configuration.md`) — **must be approved before this unit's PR can
  merge**, per AGENTS.md's security-critical pre-approval gate list.
