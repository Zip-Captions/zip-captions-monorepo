# zip_supabase — Agent Instructions

Read `../../AGENTS.md` for project-wide rules. Read `../../ARCHITECTURE.md` for the system overview.

## What This Package Is

The Supabase backend: Edge Functions (TypeScript/Deno), Postgres database migrations, seed data, and RLS policies. Provides auth, encrypted transcript storage, entitlements, broadcast session management, and signaling.

See `docs/04-technical-specification.md` Section 9 (Supabase Conventions) and Section 11 (`zip_supabase`) for rules.
See ADR-004 in `docs/02-architecture-decisions.md` for the Supabase architecture decision.

## Key ADRs

- **ADR-004** — self-hosted Supabase (Postgres, GoTrue, Storage, Realtime, Edge Functions)
- **ADR-006** — zero-knowledge encryption (server stores only encrypted blobs)
- **ADR-009** — entitlement system (Patreon webhook handler, payment-provider-agnostic)
- **ADR-011** — Supabase Realtime for signaling and optional caption relay
- **ADR-012** — observability (community metrics derived from Supabase data)

All ADRs are in `docs/02-architecture-decisions.md`.

## Stack

- Edge Functions: TypeScript / Deno
- Database: PostgreSQL with Row Level Security
- Migrations: SQL files, numbered sequentially
- Local development: Docker Compose (official Supabase self-hosted stack)

## Build and Test

```bash
# Start local Supabase:
cd packages/zip_supabase
docker compose up -d

# Apply migrations:
supabase db reset          # Reset and re-apply all migrations + seed

# Run Edge Functions locally:
supabase functions serve

# Test Edge Functions:
# (Define test commands as Edge Functions are created)
```

## File Organization

```
functions/
  function-name/
    index.ts
migrations/
  00001_initial_schema.sql
  00002_add_entitlements.sql
seed.sql
docker-compose.yml         # Or reference to Supabase CLI config
```

## Critical Patterns

- All tables must have RLS policies. No exceptions. Every new table in a migration must include its RLS policy in the same migration.
- Table names: `snake_case`, plural (`users`, `entitlements`, `broadcast_sessions`)
- Column names: `snake_case`
- All tables have `id` (UUID, primary key), `created_at`, `updated_at`
- Migrations are forward-only. Never edit an existing migration. Create a new one.
- Edge Functions: one function per file, `kebab-case` naming, validate JWT on authenticated endpoints, return structured JSON errors
- Realtime channel naming: `broadcast:{session_id}`, `status:{broadcast_id}`, `signaling:{session_id}`

## Security — Pre-Approval Required

**All work in this package touches security-sensitive systems.** Before implementing any of the following, get human approval of the approach:

- RLS policy definitions (every new table)
- Edge Function authentication/authorization logic
- Encryption-related storage schemas
- Realtime channel access control
- Any code that could log, store, or expose caption content (the answer is: it must not)

## Do Not

- Create tables without RLS policies
- Edit existing migration files — always create new migrations
- Log request bodies or response bodies that could contain caption content
- Store any unencrypted user content
- Hardcode secrets or credentials — use environment variables
- Use Supabase Cloud features not available in self-hosted mode
