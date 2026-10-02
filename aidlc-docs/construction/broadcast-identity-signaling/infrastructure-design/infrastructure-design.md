# Infrastructure Design — Unit 3: Broadcast Identity + Signaling

## Overview

No new infrastructure is stood up for this unit. It adds to the existing, already-deployed
self-hosted Supabase Docker Compose stack (topology fixed at Unit 4's Infrastructure
Design, unchanged here): one forward-only SQL migration (schema, RLS, two SQL functions —
per SR-02) and one scoped addition to the existing Kong declarative config (a rate limit
on a single RPC route — per NFR Requirements Q1). There is no cloud-provider decision,
compute-sizing decision, or networking-topology decision open in this unit; both items
below extend an existing, already-fixed shape rather than designing a new one.

---

## Migration

`packages/zip_supabase/migrations/<timestamp>_broadcast_identity_signaling.sql`
(filename finalized at Code Generation) implements exactly the schema/RLS/function
surface specified in SR-02 §1 and §3: the `broadcast_identities` table, its RLS
policies, `resolve_broadcast_id`, and `get_or_create_my_broadcast_id`. Infrastructure
Design does not re-decide any of that content — it only confirms the migration's
packaging convention.

**No down-migration/rollback script** (Infrastructure Design Q2). This project's
migrations are forward-only: the sole existing migration,
`packages/zip_supabase/migrations/20260326000000_initial.sql`, has no down
counterpart, and `docs/04-technical-specification.md` §9 establishes forward-only as the
project convention. A mistake in this unit's migration ships forward as a new corrective
migration in a later unit, not as a rollback of this one.

---

## Kong Rate-Limiting Config (Infrastructure Design Q1)

### Current State

`packages/zip_supabase/volumes/api/kong.yml` has one `services` entry per upstream
(`rest-v1`, `graphql-v1`, `auth-v1`, `realtime-v1`, `storage-v1`, `functions-v1`, `meta`).
`resolve_broadcast_id` is called via PostgREST as `POST /rest/v1/rpc/resolve_broadcast_id`,
which today falls under the catch-all `rest-v1` service (route path `/rest/v1/`,
`strip_path: true`, plugins: `cors`, `key-auth`, `acl`). No `rate-limiting` plugin exists
anywhere in the current file.

### Change

Add a new Kong service + route, more specific than `rest-v1`'s `/rest/v1/` prefix so Kong
routes `resolve_broadcast_id` calls here instead (Kong prioritizes the longest matching
path):

```yaml
services:
  # (existing rest-v1, graphql-v1, auth-v1, realtime-v1, storage-v1, functions-v1, meta — unchanged)

  ## PostgREST — resolve_broadcast_id (rate-limited; split out of rest-v1)
  - name: rest-v1-resolve-broadcast-id
    url: http://rest:3000/rpc/resolve_broadcast_id
    routes:
      - name: rest-v1-resolve-broadcast-id-route
        strip_path: true
        paths:
          - /rest/v1/rpc/resolve_broadcast_id
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - anon
            - admin
      - name: rate-limiting
        config:
          limit_by: ip
          minute: 30
          second: 2
          policy: local
          fault_tolerant: true
          hide_client_headers: false
```

**Rationale for each setting**:
- `limit_by: ip` — required because every anon caller shares the same `anon` key-auth
  consumer; the default `limit_by: consumer` would collapse all viewers into one shared
  bucket (a single popular broadcast's viewers would rate-limit each other out). Limiting
  by IP is what actually targets "one abusive client," matching NFR Requirements Q1's
  intent (brute-force enumeration resistance).
- `minute: 30` — directly the NFR Requirements Q1 target.
- `second: 2` — approximates the "~10 in the first 5 seconds" burst allowance (Kong's
  plugin windows are per-second/minute/hour, not arbitrary custom windows; 2/sec sustained
  bounds a 5-second burst to ~10, the closest fit available in the plugin's config shape).
- `policy: local` — matches this single-node Docker Compose deployment; no Redis exists in
  this stack to back a distributed/cluster policy, and none is needed for a single
  `supabase-kong` container.
- `fault_tolerant: true` — Kong's own default; a counter-store hiccup fails open rather
  than blocking legitimate traffic, consistent with this being an abuse-resistance
  measure, not a strict quota.
- `cors`/`key-auth`/`acl` are copied unchanged from `rest-v1` so this split route doesn't
  change authentication/authorization behavior for `resolve_broadcast_id` callers —
  only adds the rate limit on top.

No other existing route, service, or plugin changes. `rest-v1`'s catch-all route and
every other REST/RPC call remain unaffected.

---

## Security Compliance

| NFR | Rule | Status | Implementation |
|---|---|---|---|
| NFR Requirements Q1 | SECURITY-11 (rate limiting) | Compliant | `rate-limiting` Kong plugin, `limit_by: ip`, 30/min + ~10/5s burst, on a route scoped to exactly `resolve_broadcast_id` |
| SR-02 §1/§3 | SECURITY-04 (RLS), least privilege | Compliant | Migration implements RLS policies and `SECURITY DEFINER`/`SECURITY INVOKER` function split exactly as specified — no infra-level re-decision |
| — (forward-only convention) | — | Compliant | No down-migration script, matching the project's one existing migration and `docs/04-technical-specification.md` §9 |

No change to Unit 4's existing port mapping, volume configuration, environment
variables, or service topology — all out of scope for this unit.
