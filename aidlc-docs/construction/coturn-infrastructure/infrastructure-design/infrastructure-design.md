# Infrastructure Design — Coturn Infrastructure (Unit 4)

**Prior stage**: NFR Design (approved 2026-10-03) | **Plan**: `coturn-infrastructure-infrastructure-design-plan.md` (all 3 questions answered A)

## 1. Scope

This unit's infrastructure is entirely within the project's existing local dev stack —
`packages/zip_supabase/`. There is no separate production deployment target; per
`phase2-unit-of-work.md`, the Coturn service is part of "the local dev stack... in
zip_supabase," the same way Kong/Postgres/GoTrue/Realtime already are. This document
covers the three infrastructure decisions from the approved plan and how they land in
the real, committed files.

## 2. Coturn Service — `packages/zip_supabase/docker-compose.yml`

```yaml
  coturn:
    image: coturn/coturn:4.6.2
    container_name: supabase-coturn
    restart: unless-stopped
    network_mode: host
    command: ["--static-auth-secret=${TURN_SHARED_SECRET}"]
    volumes:
      - ./volumes/coturn/turnserver.conf:/etc/coturn/turnserver.conf:ro
      - coturn-logs:/var/log/turnserver
    healthcheck:
      test: ["CMD", "turnutils_stunclient", "-p", "3478", "127.0.0.1"]
      interval: 30s
      timeout: 5s
      retries: 3
```

**Networking (Q1-A)**: `network_mode: host`. This matches Coturn's own documented
recommendation (host networking over publishing the full `49152–65535` relay range,
which their docs explicitly warn performs badly under Docker) and was separately
confirmed empirically: the one Docker-Desktop-for-Mac limitation with host networking
(unreachable from other bridge-networked containers) doesn't apply here, because nothing
else in this compose file talks to Coturn — only the app, from outside Docker entirely,
which reaches a host-networked container via `localhost` with no issue (verified
directly in both Spike 2.3 and this unit's own Q1 investigation).

A consequence of `network_mode: host`: Coturn is **not** on the compose file's default
bridge network, and has no `ports:` mapping (host networking makes one meaningless — it
already binds directly to the host's interfaces). Developers access it at
`localhost:3478` (STUN/TURN) exactly as the Flutter apps will.

**Shared secret delivery (corrected during Code Generation, 2026-10-03)**: the original
draft of this section assumed a Kong-style `${VAR}`-in-config-file substitution for
`turnserver.conf`'s `static-auth-secret`, requiring a custom entrypoint. That doesn't
apply to Coturn — unlike Kong, Coturn's own config loader has no env-var-substitution
feature, confirmed against the official docs (`docker/coturn/README`, via docs-mcp):
*"Or specify command line options directly... `docker run ... coturn/coturn
--lt-cred-mech ... --realm=my.realm.org`"* is the documented way to override config via
CLI flags. Docker Compose itself substitutes `${TURN_SHARED_SECRET}` from `.env` into
the `command:` array at parse time (the same interpolation mechanism already used for
Kong's `environment:` block, just applied to `command:` instead) — no custom entrypoint
or `envsubst` step needed. `turnserver.conf` therefore has **no** `static-auth-secret`
line at all; the CLI flag (which takes precedence) supplies it.

**Restart/health (NFR Requirements Q3, restated)**: `restart: unless-stopped` plus a
`turnutils_stunclient` health check against the server's own STUN listener — the
simplest possible genuine liveness check, consistent with how `supabase-db`'s own health
check in this file works (a real protocol round-trip, not just "is the process running").

**Logging**: `turnserver.conf`'s logging directives are SR-03's subject in full —
see `sr-03-log-configuration.md`. Logs go to a named volume (`coturn-logs`), following
this file's existing convention for persistent-but-not-bind-mounted operational data.

**Config file**: `volumes/coturn/turnserver.conf` is the real, committed version of
Spike 2.3's validated `turnserver.conf` — same `use-auth-secret`, `realm`,
`denied-peer-ip` list, `fingerprint`/`no-multicast-peers`/`no-cli` hardening, and
logging directives, with two changes from the spike: `static-auth-secret` is **removed**
(supplied instead via the `command:` CLI-flag override above, per the corrected
Section 2), and `min-port=49152 max-port=65535` (NFR Requirements Q1's widened range,
fixing the spike's port-exhaustion finding).

## 3. Shared-Secret Storage (Q2-A)

- `.env.example` gets a new `TURN_SHARED_SECRET=` entry — a literal placeholder value
  (`your-super-secret-turn-shared-secret-change-me`), alongside the existing
  `JWT_SECRET`/`ANON_KEY`/`SERVICE_ROLE_KEY` placeholders, following their exact naming
  style (`your-...-change-me` echoes `JWT_SECRET`'s own placeholder wording).
- The `coturn` service receives it via Docker Compose's own `${TURN_SHARED_SECRET}`
  interpolation into the `command:` CLI-flag override (Section 2) — substituted from
  `.env` at compose-parse time, the same interpolation mechanism already used for Kong's
  `environment:` block, just applied to `command:` here since Coturn takes its secret as
  a CLI flag, not an env var it reads itself.
- Postgres gets the **same literal value** (not a shell variable — Postgres migrations
  have no templating, confirmed by how `app.settings.jwt_secret` is already set: a
  literal string hardcoded in SQL, matching `.env.example`'s literal default) via
  `ALTER DATABASE postgres SET "app.settings.turn_shared_secret" TO '...'` — set in this
  unit's own migration (Section 4), not `20260326000000_initial.sql`, since it's a
  new-to-this-unit setting (mirrors how `20261001000000_broadcast_identity_signaling.sql`
  introduced its own new settings rather than retrofitting the initial migration). As
  with `jwt_secret`, a developer who changes `.env.example`'s default must update this
  migration's literal value to match, or local auth breaks the same way
  `20261001000001_fix_jwt_secret_mismatch.sql` had to fix a real mismatch for
  `jwt_secret` — noted here so the same class of bug isn't repeated silently.

## 4. Migration Placement (Q3-A)

New file: `packages/zip_supabase/migrations/20261003000000_coturn_turn_credentials.sql`

```sql
alter database postgres
  set "app.settings.turn_shared_secret" to 'your-super-secret-turn-shared-secret-change-me';

create or replace function public.get_turn_credentials()
returns table (username text, credential text, ttl int, urls text[])
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  secret text := current_setting('app.settings.turn_shared_secret');
  credential_ttl int := 3600; -- 1 hour (NFR Requirements Q5)
  expiry bigint := extract(epoch from now())::bigint + credential_ttl;
  computed_username text := expiry::text;
  computed_credential text;
begin
  if auth.uid() is null then
    raise exception 'get_turn_credentials: authentication required'
      using errcode = '42501';
  end if;

  computed_credential := encode(hmac(computed_username, secret, 'sha1'), 'base64');
  return query select
    computed_username,
    computed_credential,
    credential_ttl,
    array['turn:localhost:3478', 'stun:localhost:3478'];
end;
$$;

revoke execute on function public.get_turn_credentials() from public;
grant execute on function public.get_turn_credentials() to authenticated;
```

No table, no RLS policy — the function is stateless (computes a credential, touches no
row), matching NFR Requirements Q4's design. `SECURITY DEFINER` is required because the
calling role (`authenticated`, via PostgREST) must not have direct `SELECT` access to
`current_setting('app.settings.turn_shared_secret')` — only this function may read it,
the same least-privilege shape as `resolve_broadcast_id()` (Unit 3) keeping its own
sensitive lookups inside the function body.

**Two additions found necessary during Code Generation, by testing the real stack
rather than assuming the sketch above was complete** (full account in
`aidlc-docs/construction/coturn-infrastructure/code/unit4-summary.md`, Deviations 2–3):

- The `auth.uid() IS NULL` guard. This project's Postgres bootstrap grants `EXECUTE` on
  every new `public`-schema function to `anon` by default (`ALTER DEFAULT PRIVILEGES`,
  confirmed via `pg_default_acl`). `get_or_create_my_broadcast_id()` is protected from
  anonymous abuse by its table's RLS policy, not by this grant — but this function has
  no table to fall back on. Confirmed exploitable before this guard was added (`SET ROLE
  anon; SELECT * FROM get_turn_credentials();` succeeded); confirmed fixed after
  (returns `42501`). The `revoke`/`grant` pair above is defense in depth only — it does
  **not** survive a future `CREATE OR REPLACE` (the default privileges re-grant it every
  time) — the `auth.uid()` check is the real, redeploy-proof guard.
- `set search_path = public, extensions`. `hmac()` lives in the `extensions` schema in
  this project's Postgres image, not `public`. An interactive `psql` session's default
  search_path happens to find it; PostgREST's own connections do not, failing with
  `function hmac(...) does not exist` when called through the real Kong/PostgREST path.
  Matches the identical clause `get_or_create_my_broadcast_id()` already carries for
  `gen_random_bytes()`.

This is a new forward-only migration file, not an edit to an existing one, per the
project's one-migration-per-unit convention (Unit 3's `20261001000000_broadcast_identity_signaling.sql`
precedent).

## 5. Kong / API Gateway

No change. Credential issuance goes through the same `/rest/v1/rpc/get_turn_credentials`
path every other RPC function already uses (e.g. Unit 3's
`/rest/v1/rpc/resolve_broadcast_id`) — no new route, no new rate-limit plugin entry in
`volumes/api/kong.yml`.

## 6. Security Compliance

| Control | Status | Notes |
|---|---|---|
| Shared secret never leaves Postgres | Compliant | `SECURITY DEFINER` function; secret read only inside function body |
| Shared secret not logged | Compliant | SR-03 (log config); verified empirically in Spike 2.3 |
| Payload-free TURN relay logging | Compliant | SR-03 |
| Private-range relay denial | Compliant | `denied-peer-ip` list, carried from Spike 2.3 unchanged |
| Metrics endpoint not externally exposed | Compliant | Prometheus directive, internal-only (NFR Requirements Q6) |
| Credential TTL bounded | Compliant | 1 hour; proactive renewal is a hard Unit 5 requirement (NFR Requirements Q5) |
| `.env.example` placeholder, not a real secret | Compliant | Matches `JWT_SECRET`/`ANON_KEY` convention |

## 7. Out of Scope for This Unit

Carried forward to Unit 5, per `logical-components.md`'s dependency-direction note:
anything that *consumes* the ICE server list (`PeerConnectionFactory`,
`WebRtcBroadcastTransport`/`WebRtcViewerTransport`), and the proactive credential-renewal
logic itself (NFR Requirements Q5 — a hard requirement on Unit 5, not implemented here).
