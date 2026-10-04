# Code Generation Summary — Unit 4 (Coturn Infrastructure)

**Plan**: `aidlc-docs/construction/plans/coturn-infrastructure-code-generation-plan.md` (18 steps)

## What Shipped

**`packages/zip_supabase/`**
- `migrations/20261003000000_coturn_turn_credentials.sql` — `app.settings.turn_shared_secret` + `get_turn_credentials()` (`SECURITY DEFINER`)
- `volumes/coturn/turnserver.conf` — real config (widened port range, no `static-auth-secret` line — see Deviation 1)
- `docker-compose.yml` — `coturn` service (`network_mode: host`, `command:` CLI-flag secret override, health check, `coturn_logs` volume)
- `.env.example` — `TURN_SHARED_SECRET` placeholder

**`packages/zip_core/`**
- Models: `TurnCredentials`, `IceServer` (freezed)
- Services: `TurnCredentialService`/`SupabaseTurnCredentialService`, `IceServerProvider`/`SupabaseIceServerProvider` (`lib/src/services/webrtc/`)
- Riverpod providers: `turnCredentialServiceProvider`, `iceServerProviderProvider`
- Barrel exports updated (`models.dart`, `services.dart`, `providers.dart`)

**Tests**: 4 new mocktail unit tests (`supabase_turn_credential_service_test.dart`,
`supabase_ice_server_provider_test.dart`) + 1 new `integration-supabase`-tagged
integration test (`turn_credentials_supabase_test.dart`, 2 cases). 406 `zip_core` tests
passing (2 skipped by default, both integration), `dart analyze --fatal-infos` clean.

## Verification

Unlike Units 1–3's infra-only work, this unit's `docker-compose.yml`/migration changes
were verified against a real running stack, not just read for correctness:
- Brought up a fresh local Supabase stack (`docker compose up -d`, no pre-existing
  volumes) and applied the new migration.
- Confirmed `supabase-coturn` is healthy and its `command:` actually received
  `--static-auth-secret=<the .env value>` (`docker inspect`), validating the
  Docker-Compose-level `${TURN_SHARED_SECRET}` substitution design.
- Called `get_turn_credentials()` through the real path (Kong → PostgREST, with a
  genuine signed-up user's JWT) and independently recomputed the returned HMAC-SHA1
  credential in Python against the same shared secret — exact match.
- Ran the new `integration-supabase`-tagged test against this real stack: both cases
  pass (well-formed/HMAC-valid row; anon correctly rejected).

## Deviations from the Approved Infrastructure Design

1. **Secret delivery mechanism corrected** (caught before writing any code): the
   approved design assumed a Kong-style `${VAR}`-in-config-file substitution for
   `turnserver.conf`. Confirmed via docs-mcp that Coturn has no such feature — fixed by
   using a `command:` CLI-flag override instead (Compose's own `${VAR}` substitution,
   applied to `command:` rather than `environment:`), and hardcoding the migration's
   `app.settings.turn_shared_secret` as a literal value (Postgres migrations have no
   templating — same as `jwt_secret`'s existing pattern). `infrastructure-design.md`
   updated in place; see `aidlc-docs/audit.md` for the full entry.

2. **Found and fixed a real access-control gap** (caught by testing, not by reading):
   this project's Postgres bootstrap applies `ALTER DEFAULT PRIVILEGES ... GRANT
   EXECUTE ON FUNCTIONS TO anon, authenticated, service_role` to every new
   `public`-schema function (confirmed via `pg_default_acl`). `get_or_create_my_broadcast_id()`
   (Unit 3) is unaffected by this because its real protection is the underlying table's
   RLS policy, not the function grant. `get_turn_credentials()` has no table —
   nothing else would have stopped an anonymous caller from minting a free TURN
   credential. Caught by actually running `SET ROLE anon; SELECT * FROM
   get_turn_credentials();` against the live stack, which **succeeded** before this fix.
   Fixed by adding an explicit `IF auth.uid() IS NULL THEN RAISE EXCEPTION ...` guard
   inside the function body (redeploy-proof, unlike a `REVOKE`, which the default
   privileges re-grant on every future `CREATE OR REPLACE`). Re-verified: anon now
   receives `42501`.

3. **Found and fixed a missing `search_path`** (caught by testing the real RPC path, not
   the direct-psql path): `hmac()` lives in the `extensions` schema in this project's
   Postgres image, not `public`. A direct `psql` session's default search_path found it;
   PostgREST's own connections (narrower search_path) did not, failing with `function
   hmac(...) does not exist`. Fixed by adding `SET search_path = public, extensions` to
   the function definition — the exact same clause `get_or_create_my_broadcast_id()`
   already carries for `gen_random_bytes()`. Re-verified against the real Kong/PostgREST
   path: now succeeds.

All three deviations are reflected directly in
`20261003000000_coturn_turn_credentials.sql`'s own comments and in
`infrastructure-design.md`.

## PR #27 — CodeRabbit Review Round 1 (2 findings, both fixed)

1. **Unset-secret error leaked to anonymous callers**: `current_setting('app.settings.turn_shared_secret')` was in the `DECLARE` block, which runs *before* the `auth.uid()` check in `BEGIN` — an anonymous caller in a misconfigured deployment (secret never set) would see a raw Postgres "unrecognized configuration parameter" error instead of the intended `42501`. Fixed: moved the lookup after the auth check, switched to `current_setting(..., true)` (`missing_ok`), and raised a clear exception if still unset. Re-verified against the live stack (both integration test cases still pass).

2. **Coturn exposed on all host interfaces, not just loopback**: `.coderabbit.yaml`'s path instructions for `packages/zip_supabase/**` require "ports bind to 127.0.0.1 only" — true for every other service via its compose `ports:` mapping, but `network_mode: host` has no such mapping, and Coturn with no `listening-ip` set auto-binds its control port to every local interface (confirmed via `/proc/net/udp`: entries for the host's real LAN IP, Docker bridge gateways, etc., not just `127.0.0.1`). Fixed by adding `listening-ip=127.0.0.1`. **Deliberately did not** restrict `relay-ip` the same way — relay sockets must stay reachable by real (non-loopback) peers, or the TURN server can't do the one thing it exists for; `denied-peer-ip` is the correct, already-existing control on relay *targets*. Re-verified against the live stack: control port now binds loopback-only (`/proc/net/udp` before/after), a loopback STUN request still succeeds, the health check passes, and a full `turnutils_uclient` allocate/refresh/channel-bind run through the loopback-restricted control port still works correctly — its self-targeted channel-bind is still rejected with `403 Forbidden IP`, exactly as before this change (that rejection is `denied-peer-ip` correctly refusing a loopback peer target, not a regression).

## PR #27 — CodeRabbit Review Round 2 (1 finding, fixed)

**ICE URLs weren't client-reachable from every platform**: `SupabaseIceServerProvider` read its STUN/TURN URLs straight from `TurnCredentials.urls` (the hardcoded `turn:localhost:3478`/`stun:localhost:3478` the migration returns). CodeRabbit pointed out that `localhost` inside an Android emulator refers to the emulator itself, not the host running Coturn (Android's documented `10.0.2.2` host-loopback alias is the standard fix) — the server has no way to know which hostname a given *client* can actually reach it at. Fixed by reverting to `logical-components.md`'s original design (which a Code Generation Step 11 simplification had drifted from): `SupabaseIceServerProvider` now takes a construction-time-injected `urls` list instead, sourced from a new `iceServerUrls` constant (`zip_core/lib/src/constants/turn_config.dart`) that mirrors `supabaseUrl`'s existing `--dart-define`-overridable pattern (same file resolves `SUPABASE_URL`, with the identical localhost-default/override shape) — exactly how this project already handles the same class of problem for Supabase's own URL. `TurnCredentials.urls` is unused by the client now (the fixed Application Design shape keeps the field; the migration still returns it for completeness/future use) but is no longer the source of truth for ICE server addresses. Updated the test to assert the provider uses the injected `urls`, not `TurnCredentials.urls` (using a deliberately different value for each, so the test would fail if the old behavior regressed).

## Not Yet Wired (Unit 5's responsibility, per `logical-components.md`)

`PeerConnectionFactory`/`WebRtcBroadcastTransport`/`WebRtcViewerTransport` (anything that
consumes the ICE server list), and proactive credential renewal before TTL expiry (NFR
Requirements Q5 — a hard Unit 5 requirement).
