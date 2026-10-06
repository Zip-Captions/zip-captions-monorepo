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
-- never open that channel at all. Replaced below with a table + two
-- SECURITY INVOKER functions + a Postgres Changes subscription, mirroring
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

CREATE TABLE broadcast_join_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_id text NOT NULL,
  peer_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE broadcast_join_requests ENABLE ROW LEVEL SECURITY;

-- Open INSERT, same posture as Unit 3's other anon-writable surfaces -- a
-- viewer needs no proof beyond having already resolved the broadcast_id.
-- submit_join_request is still the only path callers actually use (no
-- client code issues a raw INSERT), but the policy itself is what lets a
-- SECURITY INVOKER function succeed at all -- least privilege over
-- SECURITY DEFINER, since no privileged lookup is needed for an insert.
CREATE POLICY "Anyone may submit a join request"
  ON broadcast_join_requests
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

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

-- SECURITY INVOKER: the open INSERT policy above already permits this
-- insert for any caller, so no elevated privilege is needed -- least
-- privilege, matching get_or_create_my_broadcast_id's own reasoning for
-- using INVOKER wherever a privileged lookup isn't actually required.
CREATE OR REPLACE FUNCTION public.submit_join_request(
  p_broadcast_id text,
  p_peer_id text
)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $$
  INSERT INTO broadcast_join_requests (broadcast_id, peer_id)
  VALUES (p_broadcast_id, p_peer_id);
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
