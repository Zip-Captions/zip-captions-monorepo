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
  SET "app.settings.jwt_secret" TO 'your-super-secret-jwt-token-with-at-least-32-characters-long';

-- Enable Row Level Security on all future tables by default.
-- Individual tables will define their own RLS policies in Phase 1+.
-- (No tables exist yet — this is a reminder for future migrations.)
