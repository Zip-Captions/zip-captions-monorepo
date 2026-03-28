# Tech Stack Decisions — Unit 4: Supabase Local Dev

## Docker Compose

**Decision**: Use Docker Compose v2 (`docker compose` command) with `compose.yaml` format.

**Rationale**: Standard for local development stacks. All developers already have Docker Desktop or equivalent installed. Supabase official self-hosted template uses Docker Compose.

---

## Supabase Self-Hosted Version

**Decision**: Pin to latest stable Supabase self-hosted release (determined at generation time from official Supabase GitHub releases).

**Services included**:
| Service | Image | Purpose |
|---|---|---|
| Postgres | `supabase/postgres` | Primary database with PostgREST extensions |
| Kong | `kong` | API gateway routing |
| GoTrue | `supabase/gotrue` | Authentication service |
| Realtime | `supabase/realtime` | WebSocket subscriptions |
| Storage | `supabase/storage-api` | File storage API |
| Studio | `supabase/studio` | Web-based database management UI |
| Meta | `supabase/postgres-meta` | Database metadata API (used by Studio) |

**Note**: Exact image tags will be determined during Code Generation by referencing the official Supabase self-hosted Docker Compose template.

---

## Environment Configuration

**Decision**: `.env` file with `.env.example` template.

**Rationale**: Standard pattern for Docker Compose secrets. `.env` is gitignored; `.env.example` is committed with placeholder values and documentation for each variable.

---

## Database

**Decision**: PostgreSQL 15.x (bundled with Supabase image).

**Rationale**: Supabase bundles a specific Postgres version with required extensions (pg_graphql, pg_net, pgsodium, etc.). Using the bundled version ensures compatibility.

**Extensions**: Enabled by Supabase image automatically — no manual extension setup needed for Phase 0 (empty schema).
