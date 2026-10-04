# Infrastructure Design Plan: Coturn Infrastructure (Unit 4)

**Unit**: coturn-infrastructure | **Prior stage**: NFR Design, approved 2026-10-03

## Context

Same self-hosted, no-cloud-provider-decision context as every prior unit's Infrastructure
Design (Unit 4/Supabase-Local-Dev's own precedent, and Unit 3's). This unit's actual
deliverable is the Coturn service added to `packages/zip_supabase/docker-compose.yml` —
the project's real local dev stack, not a separate production deployment (per
`phase2-unit-of-work.md`: "Packages: local dev stack... in zip_supabase"). Spike 2.3
already validated the Coturn config itself (TURN REST credentials, private-range denial,
payload-free logging, port range) — this stage's job is wiring that into the real stack,
plus producing the SR-03 approval-gate document.

**Open items carried forward from Spike 2.3's own Recommendations**: the networking mode
for the real compose file (Spike 2.3 found a real Docker-Desktop-for-Mac limitation with
`network_mode: host`, worked around it for the spike, but flagged the workaround as
spike-only, not a deployment recommendation) — this unit has to actually decide what
ships in the committed `docker-compose.yml`, which every Mac-based developer on this
project runs locally.

## Planned Steps

- [ ] Networking mode for the real `docker-compose.yml` addition
- [ ] Shared-secret storage (env var + Postgres setting)
- [ ] Migration placement
- [ ] Generate `aidlc-docs/construction/coturn-infrastructure/infrastructure-design/sr-03-log-configuration.md` (approval gate)
- [ ] Generate `aidlc-docs/construction/coturn-infrastructure/infrastructure-design/infrastructure-design.md`
- [ ] Generate `aidlc-docs/construction/coturn-infrastructure/infrastructure-design/handoff-summary.md`

## Networking Infrastructure

### Q1: What networking mode should Coturn use in the real, committed `packages/zip_supabase/docker-compose.yml`?

**Checked against Coturn's own official documentation** (`docker/coturn/README`, via
docs-mcp, 2026-10-03), not just this project's own spike findings: Coturn's maintainers
explicitly recommend host networking over per-port publishing — *"Or just use the host
network directly (**recommended**, as Docker [performs badly with large port
ranges](https://github.com/instrumentisto/coturn-docker-image/issues/3))."* This matters
directly here: NFR Requirements already widened the relay range to `49152–65535`
(~16,384 ports) to fix Spike 2.3's port-exhaustion finding — publishing that many
individual ports via `-p`/compose `ports:` would be exactly the bad case their docs warn
about. Host networking isn't just correct, it's the only sane option at this port-range
size. (Their docs don't address container-to-container reachability at all — that's a
Docker-orchestration question outside Coturn's own scope, not something their
documentation could resolve either way.)

Separately, Spike 2.3 found that on Docker Desktop for Mac specifically, a
host-networked container isn't reachable from the stack's *other bridge-networked
containers* via `host.docker.internal` (it binds into the LinuxKit VM's own namespace).
Verified directly (2026-10-03, not just inferred) whether this actually matters for this
stack's real usage: ran a minimal host-networked Coturn container and confirmed via
`nc`/`turnutils_stunclient` that the **native macOS shell** (the same path a locally-run
Flutter app uses — outside any container entirely) reaches it correctly via `localhost`
over UDP, with a real STUN binding response. The Mac-only limitation is specific to
container-to-container traffic, which this stack doesn't need: nothing else in
`docker-compose.yml` talks to Coturn (no Kong proxy route, unlike REST/Auth/Realtime) —
only the app, from outside Docker.

- A. `network_mode: host` as the real, committed config — matches Coturn's own
  documented recommendation (especially given the already-decided large port range),
  and the one Docker-Desktop-for-Mac caveat that exists (container-to-container
  reachability) doesn't apply to how this stack actually uses Coturn.
  **(recommended — backed by both the upstream documentation and a direct empirical
  check of the real connection path this project needs)**
- B. A fixed bridge-network address (Spike 2.3's own workaround) as the real config,
  trading correctness/port-range efficiency for guaranteed container-to-container
  reachability that this stack doesn't actually need
- C. Other (write in)

[Answer]: A

## Security

### Q2: Shared-secret storage for the TURN REST credential scheme?

- A. `TURN_SHARED_SECRET` in `.env.example` (placeholder value, like every other secret
  there), read into Postgres via the same mechanism `JWT_SECRET` already uses
  (`ALTER DATABASE postgres SET "app.settings.turn_shared_secret" TO '...'` in the
  migration, following the exact pattern `20260326000000_initial.sql` established and
  `20261001000001_fix_jwt_secret_mismatch.sql` already re-confirmed works). Also passed
  to the `coturn` container's own environment as `TURN_SHARED_SECRET`, referenced by
  `turnserver.conf`'s `static-auth-secret` — matching how `ANON_KEY`/`SERVICE_ROLE_KEY`
  reach Kong today (**with the `${VAR}` substitution actually rendered**, per the fix
  already applied to Kong's entrypoint for this exact category of bug). **(recommended
  — identical pattern to the project's existing secrets, no new mechanism invented)**
- B. Other (write in)

[Answer]: A

## Migration Placement

### Q3: Where does `get_turn_credentials()` live?

- A. A new forward-only migration, `packages/zip_supabase/migrations/<timestamp>_coturn_turn_credentials.sql` — the function itself (NFR Requirements Q4's `SECURITY DEFINER` design), plus the `app.settings.turn_shared_secret` setting. No table, no RLS policy needed (the function is stateless). **(recommended — matches this project's one-migration-per-unit convention exactly, e.g. Unit 3's `20261001000000_broadcast_identity_signaling.sql`)**
- B. Other (write in)

[Answer]: A
