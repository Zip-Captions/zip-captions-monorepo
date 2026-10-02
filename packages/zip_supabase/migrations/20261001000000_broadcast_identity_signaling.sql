-- Zip Captions — Broadcast Identity + Signaling (Unit 3, S-11/S-13)
--
-- Adds the broadcast identity registry (one permanent row per broadcaster)
-- and the two SQL functions and Realtime authorization policies that back
-- it, per SR-02 (approved 2026-09-30):
--   - broadcast_identities table + its RLS policies (SR-02 §1)
--   - resolve_broadcast_id: anonymous existence check, boolean-only (SR-02 §2)
--   - get_or_create_my_broadcast_id: per-broadcaster id allocation (SR-02 §3)
--   - Realtime authorization policies on realtime.messages (SR-02 §4)
--
-- Forward-only: no down-migration (project convention, confirmed at this
-- unit's Infrastructure Design against the one existing migration).

-- ---------------------------------------------------------------------------
-- 1. Registry table (SR-02 §1)
-- ---------------------------------------------------------------------------

CREATE TABLE broadcast_identities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL UNIQUE REFERENCES auth.users(id),
  broadcast_id text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE broadcast_identities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owners read their own row"
  ON broadcast_identities
  FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "Owners create their own row"
  ON broadcast_identities
  FOR INSERT
  TO authenticated
  WITH CHECK (owner_id = auth.uid());

-- No UPDATE, DELETE, or anon policy in Phase 2 (SR-02 §1) — the row is
-- immutable once created; Phase 3 account deletion will need a DELETE path,
-- out of scope here.

-- ---------------------------------------------------------------------------
-- 2. Anonymous resolution function (SR-02 §2) — boolean-only, never exposes
--    owner_id or any other identifying column (NFR-3.5, business-rules.md
--    Rule 3).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.resolve_broadcast_id(p_broadcast_id text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS(
    SELECT 1 FROM broadcast_identities WHERE broadcast_id = p_broadcast_id
  );
$$;

GRANT EXECUTE ON FUNCTION public.resolve_broadcast_id(text) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Broadcast ID allocation (SR-02 §3) — SECURITY INVOKER, since the
--    table's own RLS policies already scope SELECT/INSERT correctly
--    (least privilege). Retries on a unique-constraint violation: a
--    broadcast_id collision gets a fresh candidate (bounded to 10 attempts,
--    NFR Requirements Q2's fail-safe, not a performance target); an
--    owner_id collision (two concurrent calls for the same broadcaster,
--    business-rules.md Rule 1) is detected by re-selecting for the caller's
--    own row before retrying, and returns that row rather than erroring —
--    it is not a candidate-code collision at all.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_or_create_my_broadcast_id()
RETURNS text
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, extensions
AS $$
DECLARE
  v_alphabet text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  v_existing text;
  v_candidate text;
  v_result text;
  v_attempt int := 0;
  v_bytes bytea;
  i int;
BEGIN
  SELECT broadcast_id INTO v_existing
  FROM broadcast_identities
  WHERE owner_id = auth.uid();

  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;

  LOOP
    v_attempt := v_attempt + 1;
    IF v_attempt > 10 THEN
      RAISE EXCEPTION 'get_or_create_my_broadcast_id: exceeded max attempts generating a unique broadcast_id';
    END IF;

    v_bytes := gen_random_bytes(6);
    v_candidate := '';
    FOR i IN 0..5 LOOP
      v_candidate := v_candidate || substr(v_alphabet, (get_byte(v_bytes, i) % 32) + 1, 1);
    END LOOP;

    BEGIN
      INSERT INTO broadcast_identities (owner_id, broadcast_id)
      VALUES (auth.uid(), v_candidate)
      RETURNING broadcast_id INTO v_result;
      RETURN v_result;
    EXCEPTION WHEN unique_violation THEN
      -- Could be our own owner_id race (a concurrent call already inserted
      -- our row) or a broadcast_id collision with someone else's code.
      -- Re-check for our own row first; only loop again if it's genuinely
      -- a broadcast_id collision.
      SELECT broadcast_id INTO v_existing
      FROM broadcast_identities
      WHERE owner_id = auth.uid();

      IF v_existing IS NOT NULL THEN
        RETURN v_existing;
      END IF;
      -- else: broadcast_id collision, loop again with a fresh candidate
    END;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_my_broadcast_id() TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Realtime channel authorization (SR-02 §4) — RLS on realtime.messages,
--    scoped by extension ('broadcast'/'presence') and topic. Channels MUST
--    be created with private: true client-side or these policies never
--    apply at all (public channels bypass RLS entirely).
-- ---------------------------------------------------------------------------

ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

-- status:{broadcast_id} — broadcast extension
CREATE POLICY "Only the owning broadcaster publishes their own status"
  ON realtime.messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    realtime.messages.extension = 'broadcast'
    AND realtime.messages.topic LIKE 'status:%'
    AND EXISTS (
      SELECT 1 FROM broadcast_identities
      WHERE broadcast_id = split_part(realtime.messages.topic, ':', 2)
        AND owner_id = auth.uid()
    )
  );

CREATE POLICY "Anyone may watch a broadcast's status"
  ON realtime.messages
  FOR SELECT
  TO anon, authenticated
  USING (
    realtime.messages.extension = 'broadcast'
    AND realtime.messages.topic LIKE 'status:%'
  );

-- status:{broadcast_id} — presence extension (broadcaster-only liveness
-- signal, not viewer presence)
CREATE POLICY "Only the owning broadcaster tracks presence on their status"
  ON realtime.messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    realtime.messages.extension = 'presence'
    AND realtime.messages.topic LIKE 'status:%'
    AND EXISTS (
      SELECT 1 FROM broadcast_identities
      WHERE broadcast_id = split_part(realtime.messages.topic, ':', 2)
        AND owner_id = auth.uid()
    )
  );

-- NOTE: deliberately anon + authenticated, NOT broadcaster-only — SR-02 §2's
-- anonymous resolution reads this same presence state to determine
-- live/offline for any viewer, including unauthenticated ones. The initial
-- draft of this migration restricted this to the broadcaster only, copying
-- SessionSignalingChannel's (intentionally private) viewer-count presence
-- pattern — but that restriction contradicts §2's own described mechanism
-- and would have broken anonymous resolution entirely. Fixed here; only
-- INSERT (tracking) stays broadcaster-only.
CREATE POLICY "Anyone may read presence on a broadcast's status"
  ON realtime.messages
  FOR SELECT
  TO anon, authenticated
  USING (
    realtime.messages.extension = 'presence'
    AND realtime.messages.topic LIKE 'status:%'
  );

-- signaling:{session_id} — broadcast extension (session ids are unguessable
-- ephemeral values, not derived from broadcast_id or any account;
-- per-message-type authorization is Unit 5's application-layer concern,
-- not RLS's — SR-02 §4's documented defense-in-depth split)
CREATE POLICY "Anyone may send on a signaling session's broadcast channel"
  ON realtime.messages
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    realtime.messages.extension = 'broadcast'
    AND realtime.messages.topic LIKE 'signaling:%'
  );

CREATE POLICY "Anyone may receive on a signaling session's broadcast channel"
  ON realtime.messages
  FOR SELECT
  TO anon, authenticated
  USING (
    realtime.messages.extension = 'broadcast'
    AND realtime.messages.topic LIKE 'signaling:%'
  );

-- signaling:{session_id} — presence extension
CREATE POLICY "Any peer may track its own presence on a signaling session"
  ON realtime.messages
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    realtime.messages.extension = 'presence'
    AND realtime.messages.topic LIKE 'signaling:%'
  );

-- NOTE: NOT actually restricted to the broadcaster, despite the original
-- intent — RLS cannot check "does auth.uid() own this session" without a
-- persisted session-owner mapping, and FR-2.6 explicitly rules out
-- persisting session records in Postgres (SR-02 §1 cites this directly: no
-- table holds per-session rows, only one permanent row per broadcaster).
-- CodeRabbit flagged this gap on PR #24 (2026-10-01): the policy's name
-- and `SessionSignalingChannel.presence`'s doc comment both falsely
-- claimed RLS enforces broadcaster-only reads. Fixed by being honest
-- instead: open to any authenticated caller (anon excluded — the viewer
-- count is still not a fully public signal), with per-session viewer-count
-- privacy left to the application layer (Unit 5's transport authorization,
-- the same RLS-can't-express-it split SR-02 §4 already uses for
-- message-type authorization) rather than claiming an RLS guarantee that
-- doesn't exist.
CREATE POLICY "Authenticated users may read presence on a signaling session"
  ON realtime.messages
  FOR SELECT
  TO authenticated
  USING (
    realtime.messages.extension = 'presence'
    AND realtime.messages.topic LIKE 'signaling:%'
  );
