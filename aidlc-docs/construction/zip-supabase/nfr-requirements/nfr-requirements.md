# NFR Requirements — Unit 4: Supabase Local Dev

## NFR Summary

Unit 4 is an infrastructure-only unit (Docker Compose, config files, documentation). No Dart code.

---

## NFR-U4-01: No Secrets Committed (SECURITY-09, SECURITY-12)

**Requirement**: No credentials, API keys, JWT secrets, or service role keys committed to version control.

**Implementation**:
- `.env` file gitignored (must be in `.gitignore`)
- `.env.example` committed with placeholder values and descriptions — no real secrets
- `docker-compose.yml` references environment variables via `${VAR}` syntax, never inline secrets
- Initial migration SQL uses placeholder syntax for JWT secret: `'super-secret-jwt-token-with-at-least-32-characters-long'` (Supabase default local dev value, documented as local-only)

**Verification**: `grep -r` for known secret patterns (passwords, tokens, keys) in committed files must return zero matches against real credentials.

---

## NFR-U4-02: Pinned Docker Image Versions (SECURITY-10)

**Requirement**: All Docker images use specific version tags. No `latest` tags.

**Implementation**:
- All `image:` directives in `docker-compose.yml` use pinned version tags (e.g., `supabase/postgres:15.6.1.143`, not `supabase/postgres:latest`)
- Version tags correspond to the latest stable Supabase self-hosted release as of March 2026
- Documented upgrade procedure in README

**Verification**: `grep 'image:' docker-compose.yml | grep -v ':' | wc -l` must return 0 (all images have tags).

---

## NFR-U4-03: Local TLS Exception (SECURITY-01)

**Requirement**: Document the local-only TLS exception for Postgres.

**Implementation**:
- Postgres listens on `localhost:54322` only — no network exposure
- TLS not configured for local dev (connections never leave the machine)
- README documents this exception explicitly: "Local development only. Production Supabase instances use TLS by default."
- Docker Compose binds ports to `127.0.0.1` (not `0.0.0.0`) to prevent LAN exposure

**Verification**: Port bindings in `docker-compose.yml` use `127.0.0.1:port:port` format.

---

## NFR-U4-04: Persistent Volumes

**Requirement**: Postgres data persists across container restarts.

**Implementation**:
- Named Docker volume (`supabase_db_data`) for Postgres data directory
- Volume survives `docker-compose down` (requires `docker-compose down -v` to destroy)
- README documents reset procedure: `docker-compose down -v` to wipe all data

---

## NFR-U4-05: Standard Port Mapping

**Requirement**: Use standard Supabase local development ports.

| Service | Port | Purpose |
|---|---|---|
| Kong (API Gateway) | 54321 | REST/GraphQL API, Auth endpoints |
| Postgres | 54322 | Direct database access |
| Studio | 54323 | Supabase Studio web UI |

---

## Security Baseline Compliance

| Rule | Status | Notes |
|---|---|---|
| SECURITY-01 (Encryption) | Exception documented | Local-only Postgres, no TLS needed; ports bound to 127.0.0.1 |
| SECURITY-09 (Hardening) | Compliant | No real secrets in committed files; .env.example with placeholders |
| SECURITY-10 (Supply Chain) | Compliant | All Docker images pinned to specific version tags |
| SECURITY-12 (Auth/Credentials) | Compliant | No hardcoded credentials; JWT secret is local-dev placeholder only |
