# Infrastructure Design — Unit 4: Supabase Local Dev

## Overview

Local-only Docker Compose stack providing the full Supabase platform for development. No cloud deployment. All ports bound to `127.0.0.1`. No real secrets committed.

## Tech Stack

| Tool | Decision | Rationale |
|---|---|---|
| Docker Compose v2 | Container orchestration | Standard for local dev stacks; Supabase official template uses Docker Compose |
| PostgreSQL 15.x | Database (bundled with Supabase image) | Supabase bundles specific Postgres with required extensions (pg_graphql, pg_net, pgsodium) |
| `.env` + `.env.example` | Environment configuration | Standard Docker Compose secrets pattern; `.env` gitignored, `.env.example` committed |

---

## Service Topology

### Core Services

| Service | Container Name | Image | Purpose |
|---|---|---|---|
| Database | `supabase-db` | `supabase/postgres:15.8.1.085` | PostgreSQL 15 with Supabase extensions |
| API Gateway | `supabase-kong` | `kong/kong:3.9.1` | Routes REST/Auth/Realtime/Storage requests |
| Auth | `supabase-auth` | `supabase/gotrue:v2.186.0` | Authentication and user management |
| REST API | `supabase-rest` | `postgrest/postgrest:v14.6` | Auto-generated REST API from Postgres schema |
| Realtime | `supabase-realtime` | `supabase/realtime:v2.76.5` | WebSocket subscriptions for database changes |
| Storage | `supabase-storage` | `supabase/storage-api:v1.44.2` | File storage API |
| Studio | `supabase-studio` | `supabase/studio:2026.03.16-sha-5528817` | Web UI for database management |
| Meta | `supabase-meta` | `supabase/postgres-meta:v0.95.2` | Database metadata API (used by Studio) |
| Edge Functions | `supabase-edge-functions` | `supabase/edge-runtime:v1.71.2` | Deno-based Edge Functions runtime |

All images pinned to specific version tags (SECURITY-10). No `:latest` tags.

### Excluded Services

| Service | Reason |
|---|---|
| imgproxy | No image processing needed |
| Logflare/Analytics | Log analytics overkill for local dev |
| Vector | Log collection not needed locally |
| Supavisor (pooler) | Connection pooling unnecessary for single-developer local use |

---

## Dependency Graph and Health Checks

```
supabase-db (postgres)
  ├── health check: pg_isready -U postgres -d postgres
  │
  ├─► supabase-auth (gotrue)
  │     health check: wget --no-verbose --tries=1 --spider http://localhost:9999/health
  │
  ├─► supabase-rest (postgrest)
  │     health check: GET http://localhost:3000/ready
  │
  ├─► supabase-realtime
  │     depends_on: db (healthy)
  │
  ├─► supabase-storage
  │     depends_on: db (healthy), rest (started)
  │     health check: wget --no-verbose --tries=1 --spider http://localhost:5000/status
  │
  └─► supabase-meta
        health check: wget --no-verbose --tries=1 --spider http://localhost:8080/health
        depends_on: db (healthy)

supabase-kong (API gateway)
  depends_on: auth (healthy), rest (healthy), realtime (started), storage (healthy), meta (healthy)
  health check: kong health

supabase-studio
  depends_on: kong (healthy), meta (healthy)

supabase-edge-functions
  depends_on: db (healthy)
```

**Startup order**: db → {auth, rest, realtime, storage, meta} (parallel once db is healthy) → kong → studio, edge-functions

---

## Port Mapping

All ports bound to `127.0.0.1` to prevent LAN exposure (SECURITY-01 local TLS exception).

| Service | Host Port | Container Port | Access URL |
|---|---|---|---|
| Kong (API Gateway) | `127.0.0.1:54321` | `8000` | `http://localhost:54321` |
| Postgres | `127.0.0.1:54322` | `5432` | `postgresql://postgres:${POSTGRES_PASSWORD}@localhost:54322/postgres` |
| Studio | `127.0.0.1:54323` | `3000` | `http://localhost:54323` |

Internal-only ports (not exposed to host): GoTrue 9999, PostgREST 3000, Realtime 4000, Storage 5000, Meta 8080, Edge Runtime 9000.

---

## Volume Configuration

| Volume Name | Mount Point | Purpose |
|---|---|---|
| `supabase_db_data` | `/var/lib/postgresql/data` | Postgres data persistence |

Named volume survives `docker compose down`. Explicit destruction: `docker compose down -v`.

---

## Environment Variables

### .env.example Structure

Only variables required by the included services. Grouped by section with descriptions.

#### Secrets (local-dev defaults — NOT for production)

| Variable | Default | Description |
|---|---|---|
| `POSTGRES_PASSWORD` | `your-super-secret-and-long-postgres-password` | Postgres superuser password |
| `JWT_SECRET` | `super-secret-jwt-token-with-at-least-32-characters-long` | JWT signing secret (min 32 chars) |
| `ANON_KEY` | *(Supabase demo JWT)* | Public anonymous API key |
| `SERVICE_ROLE_KEY` | *(Supabase demo JWT)* | Service role key (bypasses RLS) |
| `DASHBOARD_USERNAME` | `supabase` | Studio login username |
| `DASHBOARD_PASSWORD` | `this_password_is_insecure_and_should_be_updated` | Studio login password |

#### Database

| Variable | Default | Description |
|---|---|---|
| `POSTGRES_HOST` | `db` | Internal Docker hostname |
| `POSTGRES_DB` | `postgres` | Database name |
| `POSTGRES_PORT` | `5432` | Internal container port |

#### API

| Variable | Default | Description |
|---|---|---|
| `SUPABASE_PUBLIC_URL` | `http://localhost:54321` | Public API URL (via Kong) |
| `API_EXTERNAL_URL` | `http://localhost:54321` | External API URL for auth redirects |
| `PGRST_DB_SCHEMAS` | `public,storage,graphql_public` | PostgREST exposed schemas |

#### Auth

| Variable | Default | Description |
|---|---|---|
| `SITE_URL` | `http://localhost:3000` | Application site URL for redirects |
| `JWT_EXPIRY` | `3600` | Token expiry in seconds |
| `ENABLE_EMAIL_SIGNUP` | `true` | Allow email registration |
| `ENABLE_EMAIL_AUTOCONFIRM` | `true` | Auto-confirm emails (local dev) |
| `DISABLE_SIGNUP` | `false` | Allow new user registration |

#### Functions

| Variable | Default | Description |
|---|---|---|
| `FUNCTIONS_VERIFY_JWT` | `false` | Skip JWT verification for local dev |

---

## Configuration Files

### config.toml

Supabase CLI configuration at `packages/zip_supabase/supabase/config.toml`:
- Project ID: `zip-captions-local`
- API port: 54321, DB port: 54322, Studio port: 54323
- Matches Docker Compose port mapping

### Initial Migration

`packages/zip_supabase/migrations/20260326000000_initial.sql`:
- Empty schema (no application tables for Phase 0)
- Enables `pgcrypto` and `uuid-ossp` extensions
- Sets `app.settings.jwt_secret` placeholder
- All future tables must have RLS enabled and policies defined

---

## Security Compliance

| NFR | Rule | Status | Implementation |
|---|---|---|---|
| NFR-U4-01 | SECURITY-09, -12 | Compliant | `.env` gitignored; `.env.example` has placeholder values only; no real secrets committed |
| NFR-U4-02 | SECURITY-10 | Compliant | All 9 services use pinned version tags (see service table above) |
| NFR-U4-03 | SECURITY-01 | Exception documented | All ports bound to `127.0.0.1`; local-only traffic; no TLS needed |
| NFR-U4-04 | — | Compliant | Named volume `supabase_db_data` for Postgres persistence |
| NFR-U4-05 | — | Compliant | Standard ports: 54321 (API), 54322 (Postgres), 54323 (Studio) |
