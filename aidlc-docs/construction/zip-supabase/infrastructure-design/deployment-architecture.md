# Deployment Architecture — Unit 4: Supabase Local Dev

## Architecture Overview

Local-only development environment. No cloud deployment. All services run in Docker containers on the developer's machine.

```
┌─────────────────────────────────────────────────────────┐
│  Developer Machine (localhost)                           │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Docker Compose Network: supabase_default        │    │
│  │                                                  │    │
│  │  ┌──────────┐    ┌──────────┐    ┌──────────┐   │    │
│  │  │  Studio   │    │   Kong   │    │Edge Funcs │   │    │
│  │  │ :54323    │    │  :54321  │    │(internal) │   │    │
│  │  └────┬─────┘    └────┬─────┘    └──────────┘   │    │
│  │       │               │                          │    │
│  │       │    ┌──────────┼──────────┐               │    │
│  │       │    │          │          │               │    │
│  │       ▼    ▼          ▼          ▼               │    │
│  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌────────┐          │    │
│  │  │ Meta │ │ Auth │ │ REST │ │Storage │          │    │
│  │  └──┬───┘ └──┬───┘ └──┬───┘ └───┬────┘          │    │
│  │     │        │        │         │               │    │
│  │     └────────┴────────┴─────────┘               │    │
│  │                    │                             │    │
│  │              ┌─────▼─────┐                       │    │
│  │              │ Postgres  │◄── supabase_db_data   │    │
│  │              │  :54322   │    (named volume)     │    │
│  │              └───────────┘                       │    │
│  └──────────────────────────────────────────────────┘    │
│                                                         │
│  Flutter App ──► http://localhost:54321 (via Kong)       │
│  Browser    ──► http://localhost:54323 (Studio)          │
│  psql       ──► localhost:54322 (direct DB access)       │
└─────────────────────────────────────────────────────────┘
```

## Developer Workflow

### First-Time Setup

```bash
cd packages/zip_supabase
cp .env.example .env          # Copy environment template
docker compose up -d           # Start all services
# Wait for health checks to pass (~30s)
open http://localhost:54323    # Open Studio
```

### Daily Development

```bash
docker compose up -d           # Start (idempotent)
docker compose ps              # Check service status
docker compose logs -f auth    # Tail specific service logs
docker compose down            # Stop (preserves data)
```

### Reset Database

```bash
docker compose down -v         # Destroy volumes (wipes all data)
docker compose up -d           # Fresh start with empty schema
```

### Run Migrations

```bash
# Migrations in migrations/ directory are applied on Postgres startup
# To re-apply: reset database (above), or use psql directly
psql postgresql://postgres:${POSTGRES_PASSWORD}@localhost:54322/postgres \
  -f migrations/20260326000000_initial.sql
```

## Network Architecture

- **Docker network**: `supabase_default` (bridge, created by Docker Compose)
- **Service discovery**: Services reference each other by container name (e.g., `db`, `auth`)
- **External access**: Only 3 ports exposed to host, all on `127.0.0.1`
- **No TLS**: Local-only traffic; documented exception per NFR-U4-03

## Request Flow

```
Flutter App
    │
    ▼
Kong (:54321)
    │
    ├── /rest/v1/*    → PostgREST (:3000)  → Postgres
    ├── /auth/v1/*    → GoTrue (:9999)     → Postgres
    ├── /realtime/v1/ → Realtime (:4000)   → Postgres
    ├── /storage/v1/* → Storage (:5000)    → Postgres + local files
    └── /functions/v1/* → Edge Runtime (:9000)
```

## File Structure

```
packages/zip_supabase/
├── docker-compose.yml          # Service definitions (9 services)
├── .env.example                # Environment template (committed)
├── .env                        # Actual secrets (gitignored)
├── supabase/
│   └── config.toml             # Supabase CLI configuration
├── migrations/
│   └── 20260326000000_initial.sql  # Empty schema + extensions
├── volumes/
│   └── api/
│       └── kong.yml            # Kong declarative routing config
└── README.md                   # Setup instructions and documentation
```

## Production Considerations (Future)

This unit is local-dev only. For production (Phase 2+):
- Use Supabase hosted platform (supabase.com) or self-hosted with TLS
- Replace local JWT secrets with production-grade secrets
- Enable TLS for all connections
- Configure proper SMTP for auth emails
- Set up monitoring and alerting
- Use managed Postgres with automated backups
