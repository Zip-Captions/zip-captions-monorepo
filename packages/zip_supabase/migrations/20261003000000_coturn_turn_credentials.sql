-- Coturn Infrastructure (Unit 4): TURN REST shared-secret credential issuance.
--
-- Forward-only migration, matching this project's one-migration-per-unit
-- convention (20261001000000_broadcast_identity_signaling.sql).
--
-- Shared-secret placeholder for local dev, matching .env.example's
-- TURN_SHARED_SECRET default. As with app.settings.jwt_secret
-- (20260326000000_initial.sql), this is a literal value, not a shell
-- variable -- Postgres migrations have no templating. If .env.example's
-- default ever changes, this literal must be updated to match, or
-- credential issuance will start failing TURN's HMAC verification the same
-- way a jwt_secret mismatch once silently broke auth
-- (20261001000001_fix_jwt_secret_mismatch.sql).
ALTER DATABASE postgres
  SET "app.settings.turn_shared_secret" TO 'your-super-secret-turn-shared-secret-change-me';

-- Computes a TURN REST API (RFC: draft-uberti-behave-turn-rest) short-term
-- credential server-side, so the shared secret never leaves Postgres.
--
-- SECURITY DEFINER because the calling role (authenticated, via PostgREST)
-- must not have direct SELECT access to current_setting() for this
-- setting -- only this function may read it, mirroring the
-- SECURITY DEFINER / least-privilege split already established by
-- get_or_create_my_broadcast_id() (20261001000000_broadcast_identity_signaling.sql).
--
-- Stateless: no table, no RLS policy. That matters here more than it did
-- for get_or_create_my_broadcast_id(): this project's Postgres bootstrap
-- applies "ALTER DEFAULT PRIVILEGES ... GRANT EXECUTE ON FUNCTIONS TO anon,
-- authenticated, service_role" to every new public-schema function
-- (confirmed via pg_default_acl during Code Generation) -- so an explicit
-- REVOKE below does NOT survive a future CREATE OR REPLACE (the default
-- privileges re-grant it every time). get_or_create_my_broadcast_id() is
-- safe anyway because anon's INSERT is rejected by the table's own RLS;
-- this function has no table to fall back on, so the auth.uid() check
-- below is the real, redeploy-proof guard -- confirmed necessary by
-- testing an anon-role call against this function during Code Generation
-- (it succeeded until this check was added).
CREATE OR REPLACE FUNCTION public.get_turn_credentials()
RETURNS TABLE (username text, credential text, ttl integer, urls text[])
LANGUAGE plpgsql
SECURITY DEFINER
-- pgcrypto's hmac() lives in the `extensions` schema in this project's
-- Postgres image, not `public` -- PostgREST's own connections use a
-- narrower search_path than an interactive psql session, so this call
-- fails with "function hmac(...) does not exist" without this SET
-- (confirmed by testing the real RPC path through Kong during Code
-- Generation). Matches get_or_create_my_broadcast_id()'s identical
-- SET search_path, needed there for gen_random_bytes().
SET search_path = public, extensions
AS $$
DECLARE
  secret text;
  credential_ttl integer := 3600; -- 1 hour (NFR Requirements Q5)
  expiry bigint := extract(epoch FROM now())::bigint + credential_ttl;
  computed_username text := expiry::text;
  computed_credential text;
BEGIN
  -- CodeRabbit (PR #27): current_setting() was originally in the DECLARE
  -- block, which runs before this check -- an anonymous caller with no
  -- shared secret configured would have seen a raw "unrecognized
  -- configuration parameter" error instead of the intended 42501. Moved
  -- here, after the auth check, with missing_ok=true so a genuinely unset
  -- secret raises a clear exception instead of leaking Postgres's own
  -- error text to an unauthenticated caller.
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'get_turn_credentials: authentication required'
      USING ERRCODE = '42501';
  END IF;

  secret := current_setting('app.settings.turn_shared_secret', true);
  IF secret IS NULL THEN
    RAISE EXCEPTION 'get_turn_credentials: app.settings.turn_shared_secret is not configured';
  END IF;

  computed_credential := encode(hmac(computed_username, secret, 'sha1'), 'base64');
  RETURN QUERY SELECT
    computed_username,
    computed_credential,
    credential_ttl,
    ARRAY['turn:localhost:3478', 'stun:localhost:3478'];
END;
$$;

-- Defense in depth only -- the real guard is the auth.uid() check above
-- (this REVOKE/GRANT pair does not survive a future CREATE OR REPLACE,
-- per the comment on the function definition).
REVOKE EXECUTE ON FUNCTION public.get_turn_credentials() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_turn_credentials() TO authenticated;
