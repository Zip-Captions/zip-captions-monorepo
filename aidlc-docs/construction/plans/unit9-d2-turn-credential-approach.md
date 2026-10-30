# D2 approach note — anonymous viewer TURN credentials

**Status**: awaiting owner approval. No code will be written until this is approved.
**Unit**: 9, Integration Milestones. **Blocker**: B2.
**Date**: 2026-10-30.

## The problem, verified

The viewer fetches TURN credentials with `get_turn_credentials()`
(`packages/zip_core/lib/src/services/webrtc/supabase_turn_credential_service.dart:24`).
That function is guarded by `auth.uid() IS NULL` and raises `42501`
(`20261003000000_coturn_turn_credentials.sql:65-68`), and only `authenticated`
is granted EXECUTE (`:88`). Anonymous sign-in is disabled
(`packages/zip_supabase/.env:66`, `ENABLE_ANONYMOUS_USERS=false`), and a
viewer is explicitly not signed in. Observed through Kong on 2026-10-30:

```
POST /rest/v1/rpc/get_turn_credentials  (apikey = anon)
-> HTTP 401  {"code":"42501","message":"get_turn_credentials: authentication required"}
```

Consequence: any viewer whose direct path fails cannot allocate a relay
candidate, and `viewer_session_notifier.dart:247-255` surfaces
`CannotConnect(IceFailed())`. EC3b cannot pass, and the Phase 2 promise that
a broadcast works across networks is false for anonymous viewers.

## The approach

One new forward-only migration. Nothing existing is edited.

### 1. New function `public.get_broadcast_turn_credentials(p_broadcast_id text)`

- `SECURITY DEFINER`, `SET search_path = public, extensions` — same shape and
  same reason as the existing function (pgcrypto's `hmac()` lives in
  `extensions`).
- **Guard**: the call is accepted only when the broadcast id exists in
  `broadcast_identities`. `IF NOT EXISTS (...) THEN RAISE EXCEPTION ... USING
  ERRCODE = '42501'`. This is what stops it being a general-purpose
  credential dispenser.
- **No new outage surface**: it reuses `app.settings.turn_shared_secret` and
  the same 1-hour TTL as the existing function, so a single secret still
  governs both paths.
- **Username** is `'<expiry>:<broadcast_id>'`, not bare `<expiry>`. TURN REST
  usernames are opaque to Coturn, so this costs nothing operationally and
  makes every issued credential attributable to one broadcast in TURN logs
  and in any future abuse investigation, without logging anything about the
  viewer. The HMAC is computed over the full username string, exactly as
  draft-uberti specifies.
- Returns the same four columns as the existing function
  (`username, credential, ttl, urls`) so the Dart mapper stays uniform.

### 2. Privilege reality

Measured, not assumed: this image's `public` default ACL grants EXECUTE to
`anon`, `authenticated` and `service_role` for every new function
(`anon=X/postgres` in `pg_default_acl`), and it re-applies on every
`CREATE OR REPLACE`. So:

- The `REVOKE ... FROM PUBLIC` / `GRANT ... TO authenticated` idiom in the
  existing migration **does not restrict anything** — verified live,
  `has_function_privilege('anon', 'public.get_turn_credentials()', 'EXECUTE')`
  returns `true` today, which is exactly why the `auth.uid()` check inside
  the body is doing the real work.
- For the new function the grant to `anon` is **intentional**, so no REVOKE
  dance: the explicit `GRANT EXECUTE ... TO anon, authenticated` line
  documents the intent, and the broadcast-id existence check plus the Kong
  limit are the actual controls.
- The note is written down here because the next person who reads the old
  migration will otherwise believe its grant is load-bearing.

### 3. Rate limiting — mirroring `resolve_broadcast_id`

A new Kong service in `packages/zip_supabase/volumes/api/kong.yml`, cloned
from the `resolve_broadcast_id` entry: own route
`/rest/v1/rpc/get_broadcast_turn_credentials`, `cors`, `key-auth`, `acl`
allowing `anon` and `admin`, and `rate-limiting` with `limit_by: ip`,
`minute: 30`, `second: 2`, `policy: local`, `fault_tolerant: true`.

Why per IP and why the same numbers: the abuse case is one host minting
credentials for a broadcast id it guessed, and the same host cannot reach
the gateway from more than one address. Thirty a minute is far above the
one-per-join a real viewer needs (the client fetches once and keeps the
credential for its 1-hour TTL) and far below what a credential-minting
abuse looks like. `resolve_broadcast_id` already carries this exact limit,
so one abusive probe is capped by the same policy at both steps of the same
flow, and there is no gap between learning an id exists and using it.
`fault_tolerant: true` matches the existing entry: if Redis is unavailable,
credential issuance degrades to unlimited rather than failing, which is the
correct trade for a local/self-hosted dev stack where a TURN failure breaks
broadcasting outright.

Deliberately **not** done: a per-broadcast-id limit. That would need shared
state across Kong nodes and would let one abuser lock legitimate viewers of
that broadcast out of TURN. The existing rate limit is per-IP for the same
reason.

### 4. Client change

`SupabaseTurnCredentialService.fetch(sessionId)` ignores its argument today
(`:22`, `:24`), and the interface's doc comment records that as a known
limitation: "credentials aren't currently session-scoped". The change is to
stop ignoring it, in a way that keeps the broadcaster on its existing path:

- `IceServerProvider` gains an origin: `iceServersFor(sessionId)` for the
  broadcaster (unchanged call site, `broadcast_session_notifier.dart:85`) and
  `iceServersForBroadcast(broadcastId)` for the viewer
  (`viewer_session_notifier.dart:247`). Both are one-line delegations; no
  provider body, no notifier and no transport changes.
- `SupabaseTurnCredentialService` calls
  `get_broadcast_turn_credentials(p_broadcast_id)` for the viewer origin and
  keeps `get_turn_credentials()` for the authenticated origin.

**Why the viewer cannot simply pass `sessionId`:** it is the ephemeral
Realtime signaling session id, generated per join to make the signaling
topic unguessable (`signaling:{session_id}:{peerId}`). It is not derivable
from, and not stored with, the broadcast. Binding the credential to it
server-side would need a persisted session→broadcast mapping, which FR-2.6
and SR-02 §1 explicitly rule out ("no table holds per-session rows, only one
per broadcaster"). Binding to the broadcast id is the only identifier the
viewer and the server both already know without persisting anything.

An interface addition is a design change, so it is called out here rather
than slipped in: two methods on a one-member interface, with the old one
retained, is additive and leaves every existing caller and test compiling
unchanged. The alternative — overloading `sessionId` to mean two different
things depending on the caller — was rejected as the kind of implicit
contract this codebase's other seams avoid.

### 5. Threat model

| Threat | Mitigation | Residual |
|---|---|---|
| Anonymous caller mints unlimited TURN credentials | 30/min, 2/s per IP via Kong; 1-hour TTL bounds each credential's life | A caller with many IPs can mint more; TURN quota and Coturn's own denied-peer list remain the backstop |
| Caller probes for valid broadcast ids | Same `42501` error shape whether the id is unknown; the existing `resolve_broadcast_id` limit governs discovery | None beyond the existing `resolve_broadcast_id` exposure |
| Credential shared with a non-viewer | Credentials are not secret-keyed to a viewer; TURN REST credentials are bearer tokens by design (RFC 8656 §5.1) | Any viewer could share a working credential for its 1-hour life; accepted, unchanged from the broadcaster path |
| Long session outlives the credential | Username timestamp is checked at ALLOCATE only; an existing allocation survives past expiry (draft-uberti §2.2, RFC 8656 §5) | A viewer joining after the 1-hour mark gets a fresh credential on join; mid-session re-join is the only re-fetch |
| Credentials leak into logs | The function returns them only in the RPC body; nothing is logged server-side | Client-side: no transcript content is involved; the credential itself is not written to any log |

### 6. What this does not do

- It does not enable anonymous sign-in, and does not touch the `auth` block.
- It does not change `get_turn_credentials()`'s existing guard. That
  function stays authenticated-only, and its integration test still passes
  unchanged.
- It does not weaken the tracked `turnserver.conf` (private peers stay
  denied — B3 is a separate, approved decision and is not solved here).
- It does not add a dependency.

## Tests planned (TDD, written first)

1. `zip_supabase` (via the real stack, `integration-supabase`):
   - anon caller with a real broadcast id receives a well-formed row whose
     credential is HMAC-SHA1-valid for `<expiry>:<broadcast_id>`;
   - anon caller with an unknown broadcast id gets `42501` and no credential;
   - the old `get_turn_credentials()` still rejects anon (`42501`);
   - the new RPC is reachable through Kong and its response carries the
     rate-limit headers.
2. `zip_core` unit: `SupabaseTurnCredentialService.fetchBroadcast` calls
   `get_broadcast_turn_credentials` with the broadcast id it was given, and
   `fetch` still calls `get_turn_credentials()`; `SupabaseIceServerProvider`
   delegates to the right one for each origin.

## Approval requested

Approve the approach as described — specifically: the guard (broadcast-id
existence only, no ownership check), the `'<expiry>:<broadcast_id>'`
username, the Kong limit being a copy of `resolve_broadcast_id`'s, and the
decision not to add a per-broadcast-id quota — and I will write the failing
tests, then the migration, then the client change.
