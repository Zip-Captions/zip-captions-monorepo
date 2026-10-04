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

## Not Yet Wired (Unit 5's responsibility, per `logical-components.md`)

`PeerConnectionFactory`/`WebRtcBroadcastTransport`/`WebRtcViewerTransport` (anything that
consumes the ICE server list), and proactive credential renewal before TTL expiry (NFR
Requirements Q5 — a hard Unit 5 requirement).
