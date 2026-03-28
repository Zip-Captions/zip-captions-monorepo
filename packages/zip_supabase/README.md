# zip_supabase — Local Supabase Development Stack

Local development environment for Zip Captions using Docker Compose with the full Supabase platform.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine + Docker Compose v2)
- ~4 GB RAM allocated to Docker (9 containers run simultaneously)
- Ports 54321, 54322, 54323 available on localhost

## Quick Start

```bash
cd packages/zip_supabase

# 1. Create your local environment file
cp .env.example .env

# 2. Start all services
docker compose up -d

# 3. Wait for health checks to pass (~30-60 seconds)
docker compose ps

# 4. Open Supabase Studio
open http://localhost:54323
```

## Services

| Service | URL | Purpose |
|---|---|---|
| API Gateway (Kong) | http://localhost:54321 | REST API, Auth, Realtime, Storage, Functions |
| PostgreSQL | `localhost:54322` | Direct database access |
| Studio | http://localhost:54323 | Web UI for database management |

Internal services (not exposed to host): GoTrue (auth), PostgREST, Realtime, Storage API, Postgres Meta, Edge Runtime.

## Daily Development

```bash
# Start services (idempotent — safe to run repeatedly)
docker compose up -d

# Check service status and health
docker compose ps

# View logs for a specific service
docker compose logs -f auth
docker compose logs -f db

# Stop services (data is preserved)
docker compose down
```

## Connecting from Flutter

Configure your Flutter app's Supabase client:

```dart
await Supabase.initialize(
  url: 'http://localhost:54321',
  anonKey: '<ANON_KEY from .env>',
);
```

For Android emulator, replace `localhost` with `10.0.2.2`. For iOS simulator, `localhost` works directly.

## Database Access

```bash
# Connect via psql
psql postgresql://postgres:your-super-secret-and-long-postgres-password@localhost:54322/postgres

# Or use Supabase Studio at http://localhost:54323
```

## Reset Database

```bash
# Stop and destroy all data (named volumes are deleted)
docker compose down -v

# Start fresh
docker compose up -d
```

## Migrations

Migration files in `migrations/` are applied automatically when the Postgres container starts for the first time (via `/docker-entrypoint-initdb.d`).

To apply a new migration to an existing database:

```bash
psql postgresql://postgres:${POSTGRES_PASSWORD}@localhost:54322/postgres \
  -f migrations/<migration_file>.sql
```

## Edge Functions

The Edge Functions runtime (Deno) is included but no functions are deployed in Phase 0. Functions added in `functions/` will be served automatically.

## Port Reference

| Port | Service | Binding |
|---|---|---|
| 54321 | Kong (API Gateway) | `127.0.0.1` only |
| 54322 | PostgreSQL | `127.0.0.1` only |
| 54323 | Studio | `127.0.0.1` only |

## Security Notes

- **Local development only.** Do not expose this stack to the internet.
- All ports are bound to `127.0.0.1` — not accessible from other machines on the network.
- The `.env` file contains local-dev placeholder secrets. **Never use these values in production.**
- PostgreSQL does not use TLS for local connections (traffic never leaves the machine). Production Supabase instances use TLS by default.
- The JWT tokens in `.env.example` are Supabase's official demo tokens, published in their documentation. They are safe for local development only.

## Troubleshooting

**Services fail to start:** Ensure Docker has at least 4 GB of RAM allocated. Check `docker compose logs` for specific errors.

**Port conflicts:** If ports 54321-54323 are in use, stop other services or modify the port bindings in `docker-compose.yml` and update `.env` URLs accordingly.

**Database won't connect:** Wait for the health check to pass (`docker compose ps` should show `healthy` for the db service). The database may take 10-15 seconds to initialize on first start.

**Reset everything:**
```bash
docker compose down -v
docker compose up -d
```
