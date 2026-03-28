# Infrastructure Design Plan — Unit 4: Supabase Local Dev

## Context

Unit 4 creates a local Supabase development stack via Docker Compose. No cloud deployment. No Dart code. NFR Requirements are complete — pinned images, no secrets, 127.0.0.1-bound ports, persistent volumes, standard ports.

The infrastructure design maps the Supabase service topology to concrete Docker Compose service definitions with health checks, dependency ordering, and configuration.

## Steps

- [x] Step 1: Review NFR requirements and tech stack decisions
- [x] Step 2: Collect answers to questions below
- [x] Step 3: Generate infrastructure-design.md (service topology, health checks, dependency graph, environment variables)
- [x] Step 4: Generate deployment-architecture.md (local-only architecture diagram, developer workflow)
- [x] Step 5: Present for approval — APPROVED

## Questions

**Q1: Supabase CLI vs raw Docker Compose** — The Supabase CLI (`supabase start`) manages its own Docker Compose internally. Alternatively, we can use a raw `docker-compose.yml` based on the official self-hosted template, giving full control over service versions and configuration.

- A) Raw Docker Compose (full control, explicit service definitions, matches NFR pinned-version requirement)
- B) Supabase CLI wrapper (`supabase start` / `supabase stop`, simpler but less transparent)

[Answer]: A

**Q2: Health checks** — Docker Compose health checks ensure services start in the correct order (e.g., Postgres must be ready before GoTrue connects).

- A) Add health checks for all services with `depends_on: { condition: service_healthy }` ordering
- B) Basic `depends_on` without health checks (simpler, but services may fail on first start if Postgres is slow)

[Answer]: A

**Q3: Edge Functions runtime** — The unit scope mentions "Edge Functions runtime" in the Docker Compose stack. For Phase 0 (empty schema, no application logic):

- A) Include the Edge Functions container (Deno runtime) in the compose file but with no functions deployed — ready for Phase 2+
- B) Omit Edge Functions entirely for Phase 0 (can be added in Phase 2 when needed)

[Answer]: A

**Q4: Supabase Studio** — Studio provides a web UI for browsing the database, running SQL, and managing auth users. Useful during development but adds another container.

- A) Include Studio in the compose stack (accessible at localhost:54323)
- B) Omit Studio (use psql or other tools to interact with the database directly)

[Answer]: A
