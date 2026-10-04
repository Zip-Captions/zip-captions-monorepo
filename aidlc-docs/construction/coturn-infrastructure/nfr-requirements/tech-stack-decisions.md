# Tech Stack Decisions — Coturn Infrastructure (Unit 4)

## Coturn Version (Q7)

`coturn/coturn:4.6.2`, pinned — exactly the version Spike 2.3 validated every finding
against (TURN REST credential mechanism, symmetric-NAT traversal, private-range denial,
payload-free logging). No reason to drift to a newer tag without re-validating against
it.

## Package Placement (Q8)

`zip_core`, mirroring every prior unit's placement precedent (`SupabaseAuthService`,
`SupabaseBroadcastIdentityRepository`, `SupabaseSignalingService` are all here, consumed
by both apps):

- `TurnCredentialService` (interface) / `SupabaseTurnCredentialService` (impl) —
  `lib/src/services/webrtc/` (new directory — first unit needing WebRTC-adjacent
  infrastructure; `zip_core/lib/src/services/` already groups by domain, e.g.
  `broadcast/`, `signaling/`).
- `IceServerProvider` (interface) / `SupabaseIceServerProvider` (impl) — same directory.
  Composes `SupabaseTurnCredentialService`'s fetched credentials with the Coturn
  STUN/TURN URLs to build the `IceServer` list `flutter_webrtc` (Unit 5) expects.

## Credential-Issuing Mechanism (Q4)

TURN REST shared-secret scheme (Coturn's `use-auth-secret` mode), validated end-to-end
in Spike 2.3: `username` = a unix-timestamp expiry, `credential` =
base64(HMAC-SHA1(shared_secret, username)). The issuing function is a `SECURITY
DEFINER` Postgres function in `zip_supabase`, callable via PostgREST RPC —
`get_turn_credentials()`, returning `{username, credential, expiresAt, urls}` matching
`TurnCredentialService.fetch`'s fixed shape exactly. The shared secret itself is a
Postgres setting (`app.settings.turn_shared_secret`), set the same way
`app.settings.jwt_secret` already is — never in application code, never client-reachable.

## Relay Port Range (Q1)

`min-port=49152 max-port=65535` (the full dynamic/private range, ~16,384 ports) — fixes
Spike 2.3's test-config sizing bug (100 ports, exhausted by 10 concurrent clients).

## Test Double Strategy (Q10)

- **Dart-side unit tests**: `mocktail` mocks for the Postgres RPC call, matching
  `SupabaseBroadcastIdentityRepository`'s precedent — these are thin adapters with no
  internal state to model, so a fake (vs. a mock) isn't needed here the way it was for
  `SignalingService`'s stream-based components.
- **Integration test**: against the local Supabase stack (tagged `integration-supabase`,
  skipped by default — Unit 3's established `dart_test.yaml` convention), verifying the
  real HMAC credential issuance and that the issued credential is actually accepted by a
  real Coturn instance for an allocation.

## No New Dart Dependencies

`SupabaseTurnCredentialService`/`SupabaseIceServerProvider` are built on
`supabase_flutter`, already a `zip_core` dependency since Unit 2. No new package needed
for this unit's Dart surface (Unit 5 is the one that adds `flutter_webrtc`).
