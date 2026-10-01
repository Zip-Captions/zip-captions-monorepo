# SR-02: RLS and Realtime Authorization Policy Review

**Stories**: S-11 (Broadcast Identity Backend), S-13 (Signaling via Supabase Realtime) | **Blocks**: S-11, S-13 Code Generation
**Area**: Supabase RLS (AGENTS.md: RLS policy definitions — pre-approval required)
**FR**: FR-2.2, FR-2.5, FR-3.3 | **NFR**: NFR-3.4, NFR-3.5

This document is the human-approval gate required by AGENTS.md before any RLS policy or
Realtime authorization is implemented. It records the approach decided in
`broadcast-identity-signaling-functional-design-plan.md` (Q1–Q7, all answered).

## 1. Registry Table

`broadcast_identities` (not `broadcast_sessions` — FR-2.6 explicitly rules out session
records in Postgres; this table holds one permanent row per broadcaster):

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` | primary key, `default gen_random_uuid()` |
| `owner_id` | `uuid` | `references auth.users(id)`, **unique** — this unique constraint is what makes "one permanent ID per broadcaster" a database guarantee, not just application discipline |
| `broadcast_id` | `text` | **unique**, the short public code (Section 2) |
| `created_at` | `timestamptz` | `default now()` |
| `updated_at` | `timestamptz` | `default now()` |

RLS is **enabled** on this table (AGENTS.md: no table without RLS). Policies:

| Policy | Role | Operation | Condition |
|---|---|---|---|
| Owners read their own row | `authenticated` | `SELECT` | `owner_id = auth.uid()` |
| Owners create their own row | `authenticated` | `INSERT` | `owner_id = auth.uid()` |

No `UPDATE`, `DELETE`, or `anon` policy exists on this table in Phase 2 — the row is
immutable once created, and anonymous access never touches this table directly (Section
2 below). Phase 3 account deletion (FR-1.6) will need a `DELETE` path; that's out of
scope here and flagged for Unit 2/3's eventual Phase 3 follow-up, not designed now.

## 2. Anonymous Resolution Path (FR-2.5)

**Split responsibility, per Q3**: this table's RLS has no `anon` policy at all. Anonymous
existence lookups go through a single-purpose `SECURITY DEFINER` Postgres function:

```sql
create or replace function public.resolve_broadcast_id(p_broadcast_id text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists(
    select 1 from broadcast_identities where broadcast_id = p_broadcast_id
  );
$$;

grant execute on function public.resolve_broadcast_id(text) to anon, authenticated;
```

This function returns **only a boolean** — never `owner_id`, never any other column.
That is the entire enumeration-resistance property of the function's own design: even a
successful call reveals nothing beyond "this code exists or it doesn't" (NFR-3.5: no
account identifiers ever exposed).

**What this function does *not* do**: resolve live/offline status. `BroadcastResolution`
(`NotFound | Offline | Live(sessionId, sessionName) | RateLimited | ResolutionFailed` —
the last added at NFR Design, see `domain-entities.md`) requires knowing whether the
broadcaster is *currently* live — that state lives entirely in ephemeral Realtime
presence on `status:{broadcast_id}` (FR-2.6), which Postgres cannot query directly.
`BroadcastResolver.resolve()`'s actual implementation therefore does two things in
sequence: (1) call `resolve_broadcast_id` — a `false` result short-circuits to
`NotFound`; (2) on `true`, open (or briefly join) `status:{broadcast_id}` and read
presence — no presence within the channel resolves to `Offline`; a present broadcaster
publishing `sessionId`/`sessionName` resolves to `Live(sessionId, sessionName)`; a
step-2 failure/timeout (the channel join itself errors, distinct from a clean "no
presence found") resolves to `ResolutionFailed`, not `Offline` — the two are kept
distinct so a transient Realtime glitch is never reported as "confirmed not
broadcasting." This two-step design is a Functional Design decision, not an
Infrastructure Design one — the exact Realtime client call sequence is elaborated in
`business-logic-model.md`.

### Enumeration control (NFR-3.5, Q4)

The 6-character Crockford Base32 space (Section 3) is large (~1.07 billion codes), but a
single anon-callable function with no rate limit is still a standing brute-force
surface. **Decision**: rate-limit `resolve_broadcast_id`'s PostgREST RPC route
(`/rest/v1/rpc/resolve_broadcast_id`) at the Kong gateway layer, already present in this
project's local/deployed Supabase stack. The exact Kong configuration (requests-per-IP
threshold, window) is an Infrastructure Design decision for this unit, not fixed here —
this document only fixes *that* rate limiting happens at the gateway, not in
application code or a bespoke Edge Function (Q4-A: no reason to duplicate what the
gateway already provides).

`BroadcastResolution.RateLimited` (Q7) is produced when Kong rejects a resolution
request (HTTP 429), mapped by `SupabaseBroadcastIdentityRepository`'s implementation of
`BroadcastResolver`.

## 3. Broadcast ID Generation (FR-2.3, Q2)

Crockford's Base32 alphabet (`0123456789ABCDEFGHJKMNPQRSTVWXYZ` — excludes `I`, `L`,
`O`, `U` to avoid visual confusion with `1`/`0`), 6 characters, generated server-side via
`pgcrypto`'s `gen_random_bytes` inside a Postgres function (never client-generated, and
never derived from `owner_id`/email — FR-2.3). Displayed lowercase to broadcasters
(`k7m9x2`-style) while stored and compared case-sensitively as generated.

`get_or_create_my_broadcast_id()` (the implementation behind
`BroadcastIdentityRepository.getOrCreateMine()`) is `SECURITY INVOKER` (runs as the
calling authenticated user, not a privilege-escalated definer) — the table's own
`INSERT`/`SELECT` RLS policies (Section 1) already scope it correctly, so no elevated
privilege is needed or wanted here (least privilege, AGENTS.md/SECURITY-06 in spirit).
It first checks for an existing row for `auth.uid()`; if none, it generates a candidate
code, attempts insert, and retries with a fresh candidate on a unique-constraint
violation (bounded retry count, per `SupabaseBroadcastIdentityRepository`'s documented
collision-retry behavior) — `owner_id`'s own uniqueness constraint additionally
guarantees a concurrent double-call from the same user can never create two rows.

## 4. Realtime Channel Authorization (FR-3.3, Q5)

Supabase's native Realtime Authorization: RLS policies on `realtime.messages`, scoped by
`extension` (`'broadcast'` or `'presence'`) and `topic` (the channel name). This is the
platform's own purpose-built mechanism for exactly this requirement — not a custom
relay or Edge Function.

**Precondition**: both `status:{broadcast_id}` and `signaling:{session_id}` channels
must be created as `private: true` on the client (`SupabaseSignalingService`'s
implementation) — public channels bypass RLS entirely, so this is not optional
configuration, it's what makes any of the following policies apply at all.

| Channel | Extension | Policy | Role | Condition |
|---|---|---|---|---|
| `status:{broadcast_id}` | `broadcast` | `INSERT` (publish live/offline) | `authenticated` | the caller's `auth.uid()` matches the `owner_id` of the `broadcast_identities` row whose `broadcast_id` matches the topic suffix — i.e. only the owning broadcaster may publish their own status |
| `status:{broadcast_id}` | `broadcast` | `SELECT` (receive) | `anon`, `authenticated` | always true — anyone may watch a broadcast's live/offline status (that's the point of the resolution path) |
| `status:{broadcast_id}` | `presence` | `INSERT` (track) | `authenticated` (broadcaster only) | same owner check as above — only the broadcaster tracks presence on their own status channel |
| `status:{broadcast_id}` | `presence` | `SELECT` (read) | `anon`, `authenticated` | always true — **corrected at Code Generation (2026-10-01)**: this must be anon-readable, not broadcaster-only, because §2's anonymous resolution reads this exact presence state to determine live/offline for any viewer, including unauthenticated ones (presence-expiry is what makes `Offline` detection automatic, per `domain-entities.md`'s `BroadcastStatus`). The original draft of this row copied `SessionSignalingChannel.presence`'s intentionally-private viewer-count pattern by mistake — that restriction only makes sense for viewer-count privacy, not for the public live/offline signal this row backs. |
| `signaling:{session_id}` | `broadcast` | `INSERT` (send messages) | `anon`, `authenticated` | always true at the RLS layer — a session id is an unguessable-enough ephemeral value (not derived from `broadcast_id` or any account), and per-message-type authorization (e.g. only the broadcaster may send `JoinAccepted`/`BroadcastEnded`) is enforced by `SignalingCodec`/business-logic validation, not RLS, since RLS cannot distinguish message *types* within a single broadcast payload — this is a defense-in-depth split, not a gap: RLS establishes *who may be on this channel at all*, application logic establishes *what a given role is allowed to send* |
| `signaling:{session_id}` | `broadcast` | `SELECT` (receive) | `anon`, `authenticated` | always true — both the broadcaster and every viewer on the session need to receive all signaling traffic |
| `signaling:{session_id}` | `presence` | `SELECT` (receive) | `authenticated` (broadcaster only) | matches `SessionSignalingChannel.presence`'s documented "broadcaster role only" restriction (Section 3) — viewers do not need or get viewer-presence visibility into each other |
| `signaling:{session_id}` | `presence` | `INSERT` (track) | `anon`, `authenticated` | any connected peer (broadcaster or viewer) may track its own presence, which is what makes the broadcaster's presence-based viewer count possible |

**Application-layer message-type enforcement** (the defense-in-depth layer noted above):
`SignalingCodec.decode` validates every inbound message's shape and `type` (Section 3,
already fixed); the *orchestration* layer (Unit 5's transport, informed by this unit's
`SignalingMessage` sealed type) must additionally reject a `JoinAccepted`/`JoinRejected`/
`BroadcastEnded` message whose sender is not the session's broadcaster, since RLS alone
cannot express "only sender X may send message shape Y within a channel both may
publish to." This constraint is recorded here for Unit 5 to implement against, per this
unit's component-ownership boundary (Q6).

## 5. Viewer Join Abuse / Capacity (Q6)

Explicitly out of scope for this unit. `ViewerAdmission.tryAdmit` (capacity enforcement)
is Unit 5's component per `phase2-services.md`'s F4 flow. This unit's only obligation is
that the channel *authorization* above is correct; admission-count logic is a separate,
later concern.

## 6. Approval

- [x] **Approved** — this approach may proceed to NFR Requirements and, eventually,
      Infrastructure Design and Code Generation for S-11/S-13.

Approved by: James Petersen  Date: 2026-09-30
