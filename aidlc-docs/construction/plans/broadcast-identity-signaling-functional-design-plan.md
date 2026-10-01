# Functional Design Plan: Broadcast Identity + Signaling (Unit 3)

**Unit**: broadcast-identity-signaling
**Stories**: S-11 (Broadcast Identity Backend), S-13 (Signaling via Supabase Realtime), gated by SR-02
**Packages**: zip_supabase, zip_core
**Branch**: `feature/broadcast-identity-signaling` (off `develop`)

Like Unit 2, this stage produces the security-critical approach document itself: **SR-02** (registry RLS, anonymous resolution path + enumeration controls, Realtime channel authorization) requires explicit human approval under AGENTS.md before implementation.

## What's Already Decided (from phase2-application-design.md / phase2-component-methods.md / phase2-requirements.md)

- Interfaces (Section 2, Broadcast Identity): `BroadcastId` (parse/tryParse, unambiguous alphabet, FR-2.3), `BroadcastLink` (parses `k7m9x2` / bare or full URL forms, FR-2.4), `BroadcastIdentityRepository.getOrCreateMine()` (throws if signed out), `SupabaseBroadcastIdentityRepository` (retries on uniqueness collision), `BroadcastResolver.resolve(BroadcastId)`, `BroadcastResolution` sealed (`NotFound | Offline | Live(sessionId, sessionName) | RateLimited`).
- Interfaces (Section 3, Signaling): `SignalingService` (factory for `StatusChannel` and `SessionSignalingChannel`), `StatusChannel` (`publishLive`/`publishOffline`, broadcaster-only, enforced server-side; `watch()` for live/offline incl. presence-expiry offline), `SessionSignalingChannel` (`open/send/messages/presence/close`, presence is broadcaster-role only), `SignalingMessage` sealed (JoinRequest, JoinAccepted/Rejected, SdpOffer/Answer, IceCandidate, IceRestart, Leave, BroadcastEnded), `SignalingCodec` (encode/decode, `null` on malformed/unknown-type/unsupported-version/oversized).
- Realtime channel naming (Section 9, fixed): `status:{broadcast_id}`, `signaling:{session_id}`.
- Persistence model (FR-2.6, Q9:B): registry is the **only** Postgres table — no session records. Live/offline status and presence are ephemeral, carried entirely in Realtime.
- Presence timeout: `60s` (Spike 2.1 interim value, accepted through MVP per 2026-09-29 direction).
- Viewer identity field exists on `JoinRequest` but is always `null` in Phase 2 (FR-3.5).
- No caption payloads ever cross Realtime in Phase 2 (FR-3.6) — this unit carries signaling/control/presence only.
- Table conventions (Section 9): `snake_case` plural, `id`/`created_at`/`updated_at`, RLS mandatory, migrations in `packages/zip_supabase/migrations/`, forward-only.

## Planned Functional Design Artifacts

- [x] `aidlc-docs/construction/broadcast-identity-signaling/functional-design/sr-02-rls-realtime-policy.md` — the SR-02 approach document (registry RLS, resolution path + enumeration controls, Realtime channel authorization)
- [x] `aidlc-docs/construction/broadcast-identity-signaling/functional-design/business-logic-model.md` — identity get-or-create flow, resolution flow, signaling open/send/receive/presence flows, mapped to S-11/S-13 acceptance criteria
- [x] `aidlc-docs/construction/broadcast-identity-signaling/functional-design/business-rules.md` — uniqueness-collision retry, enumeration resistance, message-validation-drops-not-crashes, presence-expiry-means-offline
- [x] `aidlc-docs/construction/broadcast-identity-signaling/functional-design/domain-entities.md` — `BroadcastId`, `BroadcastResolution`, `SignalingMessage`, `BroadcastStatus`, `PresenceSnapshot` shapes and invariants
- [x] `aidlc-docs/construction/broadcast-identity-signaling/functional-design/testable-properties.md` — PBT-01 property identification (round-trip candidates: `BroadcastId.parse`/`tryParse`, `SignalingCodec.encode`/`decode`; invariants: registry uniqueness, message-drop-not-crash)
- [x] `aidlc-docs/construction/broadcast-identity-signaling/functional-design/handoff-summary.md`

## Open Questions

Researched Supabase's actual Realtime Authorization mechanism (WebSearch — not in docs-mcp's index) before drafting these, same discipline as Unit 2's SR-01.

### Q1: Registry table name and columns?
FR-2.2 requires the name be fixed here. "`broadcast_sessions`" (used as an example name in `docs/04-technical-specification.md` Section 9) is misleading for this table, since FR-2.6 explicitly says there are **no session records** in Postgres — this table holds one permanent row per broadcaster, not sessions.

- A. `broadcast_identities` — columns: `id` (uuid, pk), `owner_id` (uuid, FK to `auth.users`, unique), `broadcast_id` (text, unique, the short public code), `created_at`, `updated_at`. **(recommended — name doesn't collide with the session concept FR-2.6 explicitly rules out; `owner_id` unique constraint is what makes "one permanent ID per broadcaster" enforceable at the database level, not just application logic)**
- B. `broadcast_ids` (same columns, different table name)
- C. Other (write in)

[Answer]: A

### Q2: Broadcast ID generation — alphabet and length?
FR-2.3 requires an unambiguous alphabet, unique (DB-enforced), not derived from user identity. Proto-10-era examples used 6-character codes like `k7m9x2`.

- A. Crockford's Base32 alphabet (`0123456789ABCDEFGHJKMNPQRSTVWXYZ` — excludes `I`, `L`, `O`, `U` to avoid confusion with `1`, `0`), lowercase-displayed, 6 characters, generated server-side via a Postgres function using `pgcrypto`'s `gen_random_bytes` — collision retried per `SupabaseBroadcastIdentityRepository`'s documented behavior. **(recommended — a well-known unambiguous alphabet rather than inventing one; 32^6 ≈ 1.07 billion combinations, ample headroom for this app's scale and a meaningful deterrent to brute-force enumeration)**
- B. Same alphabet, 7 characters (larger space, marginally less readable)
- C. Other (write in)

[Answer]: A

### Q3: Anonymous resolution mechanism (FR-2.5)?
- A. A Postgres `SECURITY DEFINER` RPC function (`resolve_broadcast(broadcast_id text)`), exposed via PostgREST to the `anon` role, doing an exact-match lookup only (never a list/range query) against the registry joined with the live Realtime presence state is **not** queryable from Postgres directly — so this RPC can only ever return the registry's static existence check (found/not-found), **not** live/offline status. Live status resolution itself must happen client-side by having the viewer open `status:{broadcast_id}` and read presence — the RPC's job is narrower than FR-2.5 first suggests: it resolves "does this broadcast_id exist at all" only, not "is it live." **(recommended for the existence check specifically — a `SECURITY DEFINER` RPC is the standard Supabase pattern for anon-safe lookups that must not expose the underlying table's other rows or columns via a broader anon SELECT grant)**
- B. A Supabase Edge Function instead of a Postgres RPC for the existence check (adds a Deno function + cold-start latency vs. an RPC's direct-to-Postgres path, no meaningful security difference for this exact-match-only lookup)
- C. Other (write in)

[Answer]: A

### Q4: Enumeration control for the resolution RPC (NFR-3.5)?
The 6-character Crockford-Base32 space (Q2) is large, but a single anon-callable RPC with no rate limit is still a standing brute-force-enumeration surface.

- A. Rely on Kong's existing rate-limiting capability (already-deployed infra from Unit 5's CI/CD-adjacent local stack work) scoped to this RPC's PostgREST route, configured at Infrastructure Design time (not Functional Design) — document the requirement here, implement the actual Kong config later in this unit's Infrastructure Design stage. **(recommended — avoids inventing a bespoke application-level rate limiter when the stack already has a gateway capable of this)**
- B. A bespoke rate limiter inside a wrapping Edge Function (more code, more to maintain, only justified if Kong rate-limiting turns out to be insufficient)
- C. No rate limiting in Phase 2 — accept the alphabet-space-as-sufficient-protection given this MVP's expected scale (explicitly revisable later, similar in spirit to the Spike 2.1 interim values)
- D. Other (write in)

[Answer]: A

### Q5: Realtime channel authorization mechanism (FR-3.3)?
- A. Supabase's native Realtime Authorization: RLS policies on `realtime.messages`, scoped by `extension = 'broadcast'` / `extension = 'presence'` and `topic` matching `status:{broadcast_id}` / `signaling:{session_id}` — an INSERT policy (checked via `auth.uid()` against the registry's `owner_id` for broadcaster-only sends) and a SELECT policy (receive) per channel type, with channels created as `private: true` client-side (required for these policies to apply at all — public channels bypass RLS entirely). **(recommended — this is Supabase's own documented, purpose-built mechanism for exactly FR-3.3's requirement, confirmed via their current Realtime Authorization docs; using anything else would mean reimplementing what the platform already provides)**
- B. A custom Edge-Function-mediated relay instead of direct client-to-Realtime channels (much larger surface, defeats the point of using Realtime directly, not justified here)
- C. Other (write in)

[Answer]: A

### Q6: Viewer join rate/abuse control on `signaling:{session_id}`?
FR-8.2's "broadcast is full" is a capacity check (`ViewerAdmission`, Unit 5's concern per the dependency chain), but nothing yet stops a single client from opening many join attempts against one session channel.

- A. Out of scope for this unit — capacity enforcement (`ViewerAdmission.tryAdmit`) is explicitly Unit 5's component per `phase2-services.md`'s F4 flow; this unit only needs to ensure the channel *authorization* (who may publish what) is correct, not admission-count logic. **(recommended — matches the existing component-ownership split; re-litigating it here would blur Unit 3/Unit 5's boundary)**
- B. Add a join-attempt rate limit at the signaling layer now, ahead of Unit 5
- C. Other (write in)

[Answer]: A

### Q7: `BroadcastResolution.RateLimited` — when does this actually get produced, given Q3/Q4's design?
The component signature already includes `RateLimited` as a `BroadcastResolution` variant (fixed at Application Design), but Q4-C (no rate limiting) would leave nothing to ever produce it.

- A. If Q4 resolves to A or B (Kong or a custom limiter), `RateLimited` is produced when the gateway/limiter rejects the request (e.g. HTTP 429), mapped by `SupabaseBroadcastIdentityRepository`/`BroadcastResolver`'s implementation. If Q4 resolves to C (no rate limiting yet), `RateLimited` is simply unreachable in Phase 2 — kept in the sealed type for forward-compatibility (Application Design already fixed the shape; not worth changing now for an interim scope decision), covered by an explicit `// unreachable in Phase 2 — see Q4/Q7` comment rather than deleted. **(recommended — keeps the already-approved sealed type stable regardless of which way Q4 lands)**
- B. Other (write in)

[Answer]: A
