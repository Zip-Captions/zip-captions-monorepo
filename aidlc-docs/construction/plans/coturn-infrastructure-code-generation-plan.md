# Code Generation Plan: Coturn Infrastructure (Unit 4)

**Prior stage**: Infrastructure Design, approved 2026-10-03 (SR-03 signed off) | **Handoff**: `aidlc-docs/construction/coturn-infrastructure/infrastructure-design/handoff-summary.md`

## Scope

Infrastructure wiring (migration, compose service, config, env) plus the `zip_core`
Dart types/services that issue and shape ICE server credentials. No business logic unit
(Functional Design was skipped), no WebRTC consumption (Unit 5).

## Steps

### `packages/zip_supabase/` (infra)

1. [x] `migrations/20261003000000_coturn_turn_credentials.sql` —
   `app.settings.turn_shared_secret` setting + `get_turn_credentials()` `SECURITY
   DEFINER` function (FR: Infrastructure Design §4; NFR Requirements Q4/Q5). Two
   additions found necessary by testing the real stack: an `auth.uid()` guard (closes a
   real anon-access gap) and `set search_path = public, extensions` (fixes `hmac()` not
   resolving through PostgREST's connections) — see Deviations 2–3 in
   `unit4-summary.md`.
2. [x] `volumes/coturn/turnserver.conf` — real config derived from Spike 2.3's validated
   version: widened port range (`49152–65535`), no `static-auth-secret` line (delivered
   via Step 3's `command:` override instead), `denied-peer-ip` list, SR-03 logging
   directives unchanged.
3. [x] `docker-compose.yml` — add `coturn` service (`network_mode: host`,
   `restart: unless-stopped`, `command: ["--static-auth-secret=${TURN_SHARED_SECRET}"]`,
   `turnutils_stunclient` health check, `coturn_logs` named volume). (Infrastructure
   Design §2)
4. [x] `.env.example` — add `TURN_SHARED_SECRET=` literal placeholder. (Infrastructure
   Design §3)
5. [x] ~~Entrypoint/substitution step~~ — **dropped during Code Generation** (2026-10-03):
   Coturn has no native env-var substitution for `turnserver.conf` (confirmed via
   docs-mcp), so the secret is passed as a `command:` CLI-flag override
   (`--static-auth-secret=${TURN_SHARED_SECRET}`), substituted by Docker Compose itself
   from `.env` — no custom entrypoint needed. Folded into Step 3.

### `packages/zip_core/` (Dart)

6. [x] `lib/src/models/turn_credentials.dart` — `TurnCredentials` (`username`,
   `credential`, `expiresAt`, `urls`), freezed value model matching project convention.
7. [x] `lib/src/models/ice_server.dart` — `IceServer` (`urls`, `username?`,
   `credential?`), freezed value model (NFR Design Q2 shape).
8. [x] `lib/src/services/webrtc/turn_credential_service.dart` — abstract interface
   `TurnCredentialService.fetch(String sessionId) -> Future<TurnCredentials>`.
9. [x] `lib/src/services/webrtc/supabase_turn_credential_service.dart` — impl, calls
   `get_turn_credentials()` via `supabaseClientProvider` (Unit 2's provider, unchanged).
   Propagates failure uncaught — no retry, no fallback (NFR Design Q1).
10. [x] `lib/src/services/webrtc/ice_server_provider.dart` — abstract interface
    `IceServerProvider.iceServersFor(String sessionId) -> Future<List<IceServer>>`.
11. [x] `lib/src/services/webrtc/supabase_ice_server_provider.dart` — impl, composes
    `SupabaseTurnCredentialService`'s result with Coturn's known STUN/TURN URLs (read
    straight from `TurnCredentials.urls`, since `get_turn_credentials()` already returns
    them — simpler than the original construction-time-injected-URLs sketch) into a
    2-entry `IceServer` list.
12. [x] Riverpod providers: `turnCredentialServiceProvider`, `iceServerProviderProvider`.
13. [x] Barrel export updates (`models.dart`, `services.dart`, `providers.dart`).

### Tests

14. [x] Mocktail unit tests: `supabase_turn_credential_service_test.dart` (mocked
    Supabase client — success + uncaught-failure-propagation cases),
    `supabase_ice_server_provider_test.dart` (mocked `TurnCredentialService` — composition
    + failure propagation). 4 tests, all passing.
15. [x] Real-backend integration test, tagged `integration-supabase` (skip-by-default,
    Unit 3's `dart_test.yaml` convention): calls the real `get_turn_credentials()` RPC
    against the local dev stack, asserts a well-formed response and HMAC-valid
    credential (recomputed locally from the known test shared secret), and that anon is
    rejected. 2 tests, both passing against a real running stack.

### Verification

16. [x] `dart analyze --fatal-infos` clean across `zip_core`.
17. [x] All new + existing `zip_core` tests passing (406 passing, 2 skipped-by-default
    integration).
18. [x] Manual: brought up a real local Supabase stack, applied the migration, confirmed
    `supabase-coturn` healthy and received the secret via its `command:` override,
    called `get_turn_credentials()` through the real Kong/PostgREST path with a genuine
    signed-up user, independently recomputed the HMAC in Python (exact match), confirmed
    anon is rejected, and ran the `integration-supabase`-tagged test against this real
    stack (2/2 passing). Found and fixed two real issues along the way — see
    `aidlc-docs/construction/coturn-infrastructure/code/unit4-summary.md`.

## Delegation Note

Per this project's standard process, Part 2 (generation) proceeds after this plan is
approved.

## Traceability

| Step | FR/NFR |
|---|---|
| 1 | Infrastructure Design §4; NFR Requirements Q4, Q5 |
| 2–5 | Infrastructure Design §2, §3; SR-03 |
| 6–13 | Application Design (`IceServerProvider`/`TurnCredentialService` interfaces); NFR Design Q1, Q2 |
| 14–15 | NFR Requirements Q10 (testing approach) |
| 16–18 | Project-wide `dart analyze`/test conventions |
