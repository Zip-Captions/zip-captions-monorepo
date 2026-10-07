-- Signaling Channel Privacy (Unit 3.1, SR-04).
--
-- Replaces the single shared `signaling:{session_id}` channel's RLS with
-- an isolated join-request mechanism plus a per-viewer channel pattern,
-- closing a confirmed viewer-to-viewer privacy leak: every participant on
-- the old shared channel could read every other participant's presence and
-- raw signaling traffic (SDP/ICE, which carries real network metadata) via
-- the same policies this migration drops below.
--
-- Revised 2026-10-06, before this unit shipped/committed: the join-request
-- step was originally a Realtime Broadcast-extension `signaling:
-- {broadcast_id}:lobby` channel (own RLS on realtime.messages). Confirmed
-- unworkable by direct testing -- Realtime's subscribe() rejects the entire
-- channel join for any client lacking a SELECT grant, regardless of
-- whether it ever wires a receive callback, so a send-only viewer could
-- never open that channel at all. Replaced below with a table + two RPC
-- functions (one DEFINER, one INVOKER -- see each function's own comment)
-- + a Postgres Changes subscription, mirroring
-- get_or_create_my_broadcast_id/resolve_broadcast_id (Unit 3) rather than
-- Broadcast-extension RLS.
--
-- Forward-only, per this project's convention -- does not edit
-- 20261001000000_broadcast_identity_signaling.sql.

-- ---------------------------------------------------------------------------
-- 1. Drop the superseded signaling:{session_id} policies (Unit 3 original).
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Anyone may send on a signaling session's broadcast channel"
  ON realtime.messages;

DROP POLICY IF EXISTS "Anyone may receive on a signaling session's broadcast channel"
  ON realtime.messages;

DROP POLICY IF EXISTS "Any peer may track its own presence on a signaling session"
  ON realtime.messages;

DROP POLICY IF EXISTS "Authenticated users may read presence on a signaling session"
  ON realtime.messages;

-- ---------------------------------------------------------------------------
-- 2. Join-request handshake -- table + RPCs + Postgres Changes, replacing
--    the Broadcast-extension lobby channel entirely.
--
-- A viewer never subscribes to anything for this step: submit_join_request
-- is a single RPC call, so there is no Realtime SELECT grant to get wrong.
-- Only the broadcaster ever subscribes, via Postgres Changes (governed by
-- this table's own standard RLS, not Broadcast-extension RLS on
-- realtime.messages).
-- ---------------------------------------------------------------------------

-- No FK from broadcast_id to broadcast_identities.broadcast_id (PR #29
-- review flagged this as tempting since the column is UNIQUE): a FK
-- constraint violation on insert would let an anonymous caller distinguish
-- "this broadcast_id exists" from "it doesn't" just from the error shape,
-- recreating the exact existence-oracle problem resolve_broadcast_id's own
-- separate rate limit exists to contain. This table accepts any
-- broadcast_id text at face value, same as the lobby design it replaced.
CREATE TABLE broadcast_join_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_id text NOT NULL,
  peer_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE broadcast_join_requests ENABLE ROW LEVEL SECURITY;

-- No INSERT policy for anon/authenticated at all, and their table-level
-- INSERT privilege is explicitly revoked below -- PR #29 review correctly
-- flagged that an earlier "WITH CHECK (true)" INSERT policy, combined with
-- this project's Postgres image granting anon/authenticated default INSERT
-- on every public table, let a client bypass submit_join_request entirely
-- via PostgREST's generic /rest/v1/ REST route: a raw table INSERT, with
-- none of that function's 20-row cap, stale-row cleanup, or Kong rate
-- limit. REVOKE closes this at the privilege-check layer, which runs
-- before RLS is ever consulted -- an RLS policy alone could not have
-- fixed this, since the hole was "has INSERT privilege at all," not
-- "the policy's condition is too permissive." submit_join_request
-- (below) is unaffected: it runs SECURITY DEFINER as the table owner,
-- which this REVOKE does not touch.
REVOKE INSERT ON TABLE public.broadcast_join_requests FROM anon, authenticated;

CREATE POLICY "Only the broadcast owner may read their own join requests"
  ON broadcast_join_requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM broadcast_identities
      WHERE broadcast_identities.broadcast_id = broadcast_join_requests.broadcast_id
        AND broadcast_identities.owner_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "Only the broadcast owner may delete their own join requests"
  ON broadcast_join_requests
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM broadcast_identities
      WHERE broadcast_identities.broadcast_id = broadcast_join_requests.broadcast_id
        AND broadcast_identities.owner_id = (SELECT auth.uid())
    )
  );

-- SECURITY DEFINER (revised from an earlier INVOKER draft, PR #29 review):
-- bounding and cleaning up requires reading every pending row for
-- p_broadcast_id, which an anonymous/non-owner caller's own SELECT RLS
-- would filter to zero -- the same class of problem resolve_broadcast_id's
-- own DEFINER already solves (crossing the owner boundary deliberately,
-- inside a function that returns nothing identifying back to the caller).
-- Bounded by construction, not by caller trust: deletes this broadcast_id's
-- stale rows (TTL matches the order of magnitude of Unit 5's own join-ack
-- timeout -- a real broadcaster response arrives in seconds, not minutes),
-- then rejects the insert outright once 20 requests are already pending
-- for this broadcast_id, so an anonymous flood cannot grow this table
-- without bound even if the owner never consumes anything.
CREATE OR REPLACE FUNCTION public.submit_join_request(
  p_broadcast_id text,
  p_peer_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pending_count int;
BEGIN
  -- Serializes concurrent calls for the same broadcast_id (PR #29 review):
  -- without this, two callers could each count 19 pending rows before
  -- either inserts, both pass the <20 check, and leave 21 rows -- Postgres's
  -- default READ COMMITTED isolation does not make a count-then-insert
  -- sequence atomic on its own. pg_advisory_xact_lock blocks a second
  -- concurrent call for the same broadcast_id until the first's
  -- transaction ends, and releases automatically at commit/rollback --
  -- never needs an explicit unlock. Different broadcast_ids hash to
  -- (almost certainly) different lock keys and proceed independently.
  PERFORM pg_advisory_xact_lock(hashtext(p_broadcast_id));

  DELETE FROM broadcast_join_requests
  WHERE broadcast_id = p_broadcast_id
    AND created_at < now() - interval '5 minutes';

  SELECT count(*) INTO v_pending_count
  FROM broadcast_join_requests
  WHERE broadcast_id = p_broadcast_id;

  IF v_pending_count >= 20 THEN
    RAISE EXCEPTION
      'submit_join_request: too many pending join requests for this broadcast';
  END IF;

  INSERT INTO broadcast_join_requests (broadcast_id, peer_id)
  VALUES (p_broadcast_id, p_peer_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_join_request(text, text) TO anon, authenticated;

-- SECURITY INVOKER (unlike submit_join_request above): the caller must
-- already own the row per the DELETE policy, so no elevated privilege is
-- needed -- least privilege, same reasoning as get_or_create_my_broadcast_id.
CREATE OR REPLACE FUNCTION public.consume_join_request(p_request_id uuid)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $$
  DELETE FROM broadcast_join_requests WHERE id = p_request_id;
$$;

GRANT EXECUTE ON FUNCTION public.consume_join_request(uuid) TO authenticated;

-- Required for the broadcaster's onPostgresChanges subscription to receive
-- row images at all.
ALTER TABLE broadcast_join_requests REPLICA IDENTITY FULL;

-- Confirmed necessary by testing, not assumed from documentation: Postgres
-- Changes delivers nothing at all for a table that isn't a member of the
-- supabase_realtime publication, even with RLS and REPLICA IDENTITY both
-- already correct -- found when the real-backend integration test's first
-- run received zero events despite every other piece being in place.
ALTER PUBLICATION supabase_realtime ADD TABLE broadcast_join_requests;

-- ---------------------------------------------------------------------------
-- 3. signaling:{session_id}:{peerId} -- symmetric, open.
--
-- Deliberately not an ownership/identity check: a per-viewer topic's full
-- name (including the unguessable peerId) is never shared with anyone but
-- the broadcaster and that one viewer, so there is no legitimate third
-- party for RLS to need to exclude. Privacy here is the topic name's own
-- entropy, not an RLS check. (No `:lobby` exclusion needed -- that topic
-- pattern no longer exists, replaced by Section 2's table + RPCs.)
-- ---------------------------------------------------------------------------

CREATE POLICY "Anyone on a per-viewer signaling channel may send"
  ON realtime.messages
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    realtime.messages.extension = 'broadcast'
    AND realtime.messages.topic LIKE 'signaling:%'
  );

CREATE POLICY "Anyone on a per-viewer signaling channel may receive"
  ON realtime.messages
  FOR SELECT
  TO anon, authenticated
  USING (
    realtime.messages.extension = 'broadcast'
    AND realtime.messages.topic LIKE 'signaling:%'
  );
