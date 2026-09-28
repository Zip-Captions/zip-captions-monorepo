-- Zip Captions — Initial Migration (Phase 0)
--
-- This migration sets up the database foundation:
--   - Enables commonly needed extensions
--   - Sets the JWT secret for PostgREST
--   - No application tables (added in Phase 1+)
--
-- To re-apply: docker compose down -v && docker compose up -d

-- Enable extensions commonly needed by Supabase applications.
-- The supabase/postgres image pre-installs these; we just activate them.
CREATE EXTENSION IF NOT EXISTS "pgcrypto" SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgjwt" SCHEMA "extensions";

-- JWT secret placeholder for PostgREST app.settings.
-- This uses the local-dev default from .env.example.
-- Production environments use proper secrets via environment variables.
ALTER DATABASE postgres
  SET "app.settings.jwt_secret" TO 'super-secret-jwt-token-with-at-least-32-characters-long';

-- NOTE: All future tables MUST have RLS enabled and policies defined.
-- PostgreSQL does not enable RLS by default; each table migration must include:
--   ALTER TABLE <table_name> ENABLE ROW LEVEL SECURITY;
-- See coding guidelines: "Do not create tables without RLS policies"

-- Set passwords for predefined Supabase roles used by service DB connections.
-- The supabase/postgres base image's own bootstrap (migrate.sh) only sets a password for
-- supabase_admin; authenticator, supabase_auth_admin and supabase_storage_admin are left
-- without one, so PostgREST/GoTrue/Storage cannot authenticate over the docker network
-- (pg_hba.conf requires scram-sha-256 there; only 127.0.0.1/local get "trust"). The base
-- image expects an external postinit script at /etc/postgresql.schema.sql to do this in a
-- real deployment; this local dev stack doesn't provide one, so we do it here instead.
-- This uses the local-dev default from .env.example, same as the JWT secret above.
ALTER ROLE authenticator WITH PASSWORD 'your-super-secret-and-long-postgres-password';
ALTER ROLE supabase_auth_admin WITH PASSWORD 'your-super-secret-and-long-postgres-password';
ALTER ROLE supabase_storage_admin WITH PASSWORD 'your-super-secret-and-long-postgres-password';
