# Infrastructure Design Plan: Broadcast Identity + Signaling (Unit 3)

**Unit**: broadcast-identity-signaling | **Prior stage**: NFR Design, approved 2026-09-30

## Context

This project has no cloud-provider infrastructure decision to make — it's a self-hosted
Docker Compose Supabase stack, already deployed (Unit 4's own Infrastructure Design
document describes that topology; this unit doesn't change it). The generic AI-DLC
Infrastructure Design categories (Deployment Environment, Compute, Storage, Messaging,
Networking, Monitoring, Shared Infrastructure) are therefore almost entirely already
fixed and not open questions here. The two genuinely open items, per the NFR Design
handoff summary's "Open Questions for Next Stage," are narrower:

1. The literal Kong declarative-config change to implement the already-approved 30
   req/min + burst rate limit on `resolve_broadcast_id` (NFR Requirements Q1).
2. Whether the new `broadcast_identities` migration needs a down-migration/rollback
   script.

I read the existing config/precedent before drafting these questions:
- `packages/zip_supabase/volumes/api/kong.yml` — the actual, currently-deployed Kong
  declarative config. Structure: `consumers` (anon/service_role with keyauth
  credentials), `acls` (anon/admin groups), then one `services` entry per upstream
  (`rest-v1`, `graphql-v1`, `auth-v1`, `realtime-v1`, `storage-v1`, `functions-v1`,
  `meta`), each with its own `routes` (path-based, `strip_path: true`) and `plugins`
  list (`cors`, `key-auth`, `acl`). No `rate-limiting` plugin is used anywhere in the
  current file — this unit would be the first to introduce one.
- `packages/zip_supabase/migrations/` — contains exactly one file,
  `20260326000000_initial.sql`, and no down/rollback counterpart. Confirms the
  forward-only convention already noted in NFR Design's handoff summary.

## Planned Steps

- [ ] Kong rate-limiting config (Q1)
- [ ] Migration rollback script (Q2)
- [ ] Generate `aidlc-docs/construction/broadcast-identity-signaling/infrastructure-design/infrastructure-design.md`
- [ ] Generate `aidlc-docs/construction/broadcast-identity-signaling/infrastructure-design/handoff-summary.md`

## Kong Rate-Limiting Config

### Q1: How should the 30 req/min + burst limit on `resolve_broadcast_id` be implemented in Kong?

The RPC is called via PostgREST as `POST /rest/v1/rpc/resolve_broadcast_id`, which today
falls under the existing catch-all `rest-v1` service/route (`/rest/v1/` strip_path).
Attaching a `rate-limiting` plugin to that existing route would throttle *all* REST
traffic (every table/RPC call), not just this one RPC.

- A. Add a new, more specific Kong service + route
  (`rest-v1-resolve-broadcast-id`, path `/rest/v1/rpc/resolve_broadcast_id`, more
  specific than `rest-v1`'s `/rest/v1/` so Kong prioritizes it) pointing at the same
  `rest:3000` upstream, carrying the same `cors`/`key-auth`/`acl` plugins as `rest-v1`
  (so anon callers still authenticate identically) plus a new `rate-limiting` plugin
  configured `policy: local` (matches this single-node Docker Compose deployment — no
  Redis in the stack to back a distributed policy), `minute: 30`, and `second: 5` for
  the burst bound. **(recommended — scopes the limit to exactly the one endpoint NFR
  Requirements targeted, leaves every other REST/RPC call unaffected, and reuses this
  file's existing per-service plugin pattern rather than inventing a new one)**
- B. Attach `rate-limiting` directly to the existing `rest-v1` service, limiting all
  REST/RPC traffic to 30/min
- C. Other (write in)

[Answer]: A

## Migration Rollback Script

### Q2: Does the `broadcast_identities` migration need a down-migration/rollback script?

- A. No — this project's migrations are forward-only (the sole existing migration,
  `20260326000000_initial.sql`, has no down counterpart, and `docs/04-technical-
  specification.md` §9 confirms this as the established convention). A mistake ships
  forward as a new corrective migration, not a rollback. **(recommended — matches
  existing precedent exactly; introducing rollback scripts for only this unit's
  migration would be inconsistent with every other migration in the repo)**
- B. Yes — add a down script for this migration specifically, as a new convention
  starting here
- C. Other (write in)

[Answer]: A
