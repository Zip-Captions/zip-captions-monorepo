# Code Generation Plan — Unit 4: Supabase Local Dev

## Unit Context

- **Unit**: Unit 4 — Supabase Local Dev
- **Branch**: `feature/phase0-supabase-local-dev`
- **Package**: `packages/zip_supabase/`
- **Dependencies**: Unit 1 merged (monorepo scaffold in place)
- **Type**: Infrastructure only — no Dart code, no business logic, no tests

## Design Artifacts

- NFR Requirements: `aidlc-docs/construction/zip-supabase/nfr-requirements/`
- Infrastructure Design: `aidlc-docs/construction/zip-supabase/infrastructure-design/`

## Steps

- [x] Step 1: Create worktree and branch
- [x] Step 2: Generate `packages/zip_supabase/volumes/api/kong.yml` — Kong declarative routing config (routes for REST, Auth, Realtime, Storage, Edge Functions, Meta)
- [x] Step 3: Generate `packages/zip_supabase/docker-compose.yml` — 9 services with pinned images, health checks, dependency ordering, 127.0.0.1-bound ports, named volume
- [x] Step 4: Generate `packages/zip_supabase/.env.example` — all required environment variables with local-dev defaults and descriptions
- [x] Step 5: Generate `packages/zip_supabase/supabase/config.toml` — Supabase CLI config matching Docker Compose ports
- [x] Step 6: Generate `packages/zip_supabase/migrations/20260326000000_initial.sql` — empty schema with extensions and JWT secret placeholder
- [x] Step 7: Generate `packages/zip_supabase/README.md` — prerequisites, setup, daily workflow, reset, port reference, security notes
- [x] Step 8: Validate NFR compliance (no secrets in committed files, all images pinned, ports on 127.0.0.1)
- [x] Step 9: Present for approval — APPROVED

## File Summary

| File | Purpose |
|---|---|
| `volumes/api/kong.yml` | Kong API gateway declarative routing |
| `docker-compose.yml` | 9-service Supabase local dev stack |
| `.env.example` | Environment variable template (committed) |
| `supabase/config.toml` | Supabase CLI project configuration |
| `migrations/20260326000000_initial.sql` | Empty initial migration |
| `README.md` | Developer setup documentation |

## Notes

- No Dart code generated (infrastructure only)
- No unit tests (no executable code to test; NFR compliance verified by inspection in Step 8)
- `.env` already gitignored in root `.gitignore`
- All code goes to `packages/zip_supabase/` (never `aidlc-docs/`)
