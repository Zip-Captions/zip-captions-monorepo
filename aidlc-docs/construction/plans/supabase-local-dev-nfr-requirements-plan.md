# NFR Requirements Plan — Unit 4: Supabase Local Dev

## Context

Unit 4 creates the local Supabase development stack: Docker Compose, config.toml, initial empty migration, .env.example, and README. No Dart code. No business logic (Functional Design was SKIP).

The security requirements are pre-identified from inception:
- **SECURITY-09/12**: No secrets or credentials committed; `.env.example` templates only
- **SECURITY-01**: Local Postgres TLS (document local-only exception)
- **SECURITY-10**: Pinned Docker image versions (no `latest` tags)

## Steps

- [x] Step 1: Review Unit 4 scope from unit-of-work.md
- [x] Step 2: Assess NFR categories for applicability
- [x] Step 3: Collect answers to questions below
- [x] Step 4: Generate NFR requirements artifact
- [x] Step 5: Generate tech stack decisions artifact
- [x] Step 6: Present for approval

## Questions

**Q1: Supabase version** — Which Supabase self-hosted release should we pin to? The official `supabase/postgres` and related images use version tags.

- A) Use the latest stable Supabase self-hosted release as of March 2026 (I'll determine specific image tags)
- B) Use a specific version you have in mind

[Answer]: A

**Q2: Local port mapping** — The standard Supabase local ports are:
- Postgres: 54322
- Studio: 54323
- API (Kong): 54321
- Auth (GoTrue): 54321 (via Kong)

Should we use these standard ports, or do you have conflicts/preferences?

- A) Use standard Supabase local ports
- B) Custom ports (specify)

[Answer]: A

**Q3: TLS for local Postgres** — SECURITY-01 requires encryption in transit. For local development:

- A) Document the local-only TLS exception (Postgres on localhost doesn't need TLS; no data leaves the machine)
- B) Configure self-signed TLS for local Postgres (adds complexity for dev setup)

[Answer]: A

**Q4: Persistent volumes** — Should Docker volumes persist Postgres data between `docker-compose down` and `up`?

- A) Yes — named volume, data survives container restarts (standard for dev)
- B) No — ephemeral, clean slate each time (simpler but loses dev data)

[Answer]: A
