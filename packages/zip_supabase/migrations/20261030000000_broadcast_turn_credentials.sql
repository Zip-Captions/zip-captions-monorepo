-- Broadcast-scoped TURN credentials (Unit 9, B2; approach approved 2026-10-30
-- in aidlc-docs/construction/plans/unit9-d2-turn-credential-approach.md).
--
-- Problem: a viewer is anonymous. It cannot call get_turn_credentials()
-- (20261003000000_coturn_turn_credentials.sql), whose auth.uid() guard raises
-- 42501 and whose only grant is to `authenticated`, and anonymous sign-in is
-- disabled (.env ENABLE_ANONYMOUS_USERS=false). So any viewer whose direct
-- path fails cannot allocate a relay candidate at all, and Phase 2's
-- cross-network broadcast promise is false for anonymous viewers.
--
-- Fix: a second credential function, reachable by `anon`, scoped to one
-- broadcast id. Not a general-purpose credential dispenser: the id must
-- already exist in broadcast_identities, which is the same existence check
-- resolve_broadcast_id already exposes anonymously, and the shared secret
-- stays in Postgres exactly as before.
--
-- Forward-only, per this project's convention. Does not edit
-- 20261003000000_coturn_turn_credentials.sql, and does not touch
-- get_turn_credentials() -- the broadcaster's path is deliberately unchanged.
--
-- The shared-secret requirement is NOT restated here: it is set on the
-- database by the Unit 4 migration, and re-declaring it would create a
-- second place to keep in sync with .env.example's TURN_SHARED_SECRET.

CREATE OR REPLACE FUNCTION public.get_broadcast_turn_credentials(
  p_broadcast_id text
)
RETURNS TABLE (username text, credential text, ttl integer, urls text[])
LANGUAGE plpgsql
SECURITY DEFINER
-- Same search_path reasoning as get_turn_credentials(): pgcrypto's hmac()
-- lives in the `extensions` schema in this image, and PostgREST's connection
-- uses a narrower search_path than an interactive psql session.
SET search_path = public, extensions
AS $$
DECLARE
  secret text;
  credential_ttl integer := 3600; -- 1 hour, matching get_turn_credentials()
  expiry bigint := extract(epoch FROM now())::bigint + credential_ttl;
  -- The broadcast id is appended to the TURN REST username. Coturn treats
  -- the username as an opaque string and only re-computes the HMAC over it
  -- (RFC 8656 §5.1 / draft-uberti §2.1), so this costs nothing operationally
  -- and makes every issued credential attributable to exactly one broadcast
  -- in TURN logs, without recording anything about the viewer. Nothing about
  -- the viewer is logged or stored by this function.
  computed_username text;
  computed_credential text;
BEGIN
  -- The real guard. Measured, not assumed: this image's public-schema default
  -- ACL grants EXECUTE to anon/authenticated/service_role on every new
  -- function and re-applies it on CREATE OR REPLACE (pg_default_acl shows
  -- anon=X/postgres), so a REVOKE would not survive a redeploy -- the same
  -- reason get_turn_credentials()'s grant is documented as defense in depth
  -- only. The check below is what makes this function broadcast-scoped
  -- rather than a credential dispenser.
  IF p_broadcast_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM broadcast_identities AS bi
    WHERE bi.broadcast_id = p_broadcast_id
  ) THEN
    -- Deliberately the same error shape and code as
    -- get_turn_credentials()'s auth failure: an anonymous caller learns
    -- nothing from this response that resolve_broadcast_id does not already
    -- tell it (false), and the two Kong limits are identical.
    RAISE EXCEPTION 'get_broadcast_turn_credentials: unknown broadcast'
      USING ERRCODE = '42501';
  END IF;

  secret := current_setting('app.settings.turn_shared_secret', true);
  IF secret IS NULL THEN
    RAISE EXCEPTION 'get_broadcast_turn_credentials: app.settings.turn_shared_secret is not configured';
  END IF;

  computed_username := expiry::text || ':' || p_broadcast_id;
  computed_credential := encode(hmac(computed_username, secret, 'sha1'), 'base64');

  RETURN QUERY SELECT
    computed_username,
    computed_credential,
    credential_ttl,
    -- The URLs are ignored by the client (SupabaseIceServerProvider uses its
    -- own --dart-define'd list, CodeRabbit PR #27); returned only so this
    -- function's row shape matches get_turn_credentials()'s exactly.
    ARRAY['turn:localhost:3478', 'stun:localhost:3478'];
END;
$$;

-- Intent only -- see the guard's comment for why this does not restrict
-- anything on its own. Stated as two grants rather than a REVOKE so the
-- anon reachability is explicit in the migration text instead of implied by
-- the image's default ACL.
GRANT EXECUTE ON FUNCTION public.get_broadcast_turn_credentials(text)
  TO anon, authenticated;