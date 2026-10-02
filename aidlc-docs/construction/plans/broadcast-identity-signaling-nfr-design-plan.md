# NFR Design Plan: Broadcast Identity + Signaling (Unit 3)

**Unit**: broadcast-identity-signaling | **Prior stage**: NFR Requirements, approved 2026-09-30

## Planned Steps

- [x] Resilience Patterns — RLS-rejection handling (Q1), resolution's two-step failure mode (Q2 — resolved as a new `ResolutionFailed` variant, deviating from the initial recommendation; `domain-entities.md`/`sr-02-rls-realtime-policy.md`/`business-logic-model.md` updated accordingly)
- [x] Scalability Patterns — N/A, justified below
- [x] Performance Patterns — documented, no open question
- [x] Security Patterns — documented (RLS-vs-app-logic split, already fixed at SR-02)
- [x] Logical Components — package placement, full component list
- [x] Generate `aidlc-docs/construction/broadcast-identity-signaling/nfr-design/nfr-design-patterns.md`
- [x] Generate `aidlc-docs/construction/broadcast-identity-signaling/nfr-design/logical-components.md`
- [x] Generate `aidlc-docs/construction/broadcast-identity-signaling/nfr-design/handoff-summary.md`

## Resilience Patterns

### Q1: How should an RLS-rejected operation surface to callers?
`getOrCreateMine()` already "throws if signed out" (a known, named case). But an RLS
rejection can also happen for reasons that *aren't* "signed out" — e.g. a bug elsewhere
briefly sends a request with a stale/invalid session, or (adversarially) a client
attempts to publish on a channel it doesn't own and Realtime's RLS policy rejects it.

- A. A single `BroadcastAuthorizationException` (new, `zip_core`-defined) wraps any
  RLS/permission-denied rejection from Postgres or Realtime, distinct from a plain
  network failure — callers (e.g. `BroadcastSessionNotifier`, Unit 6) can catch this
  specifically to distinguish "the server said no" from "the network is down," without
  this unit needing to enumerate every possible caller-facing state for what should be
  a rare, largely-adversarial-or-buggy case. **(recommended — one new exception type is
  enough signal for callers to react sensibly; inventing a full sealed-result type for
  an edge case this narrow would be over-engineering relative to how often it's expected
  to occur)**
- B. Let the raw Postgrest/Realtime exception propagate uncaught — callers must know
  Supabase's own exception types to handle this
- C. Other (write in)

[Answer]: A

### Q2: What happens if `resolve()`'s second step (presence read) fails after the first step (existence RPC) succeeded?
SR-02 §2's two-step design means a transient failure can occur *between* "the code
exists" and "here's whether it's live."

- A. Treat a step-2 failure (e.g. the Realtime channel join times out or errors) the
  same as `Offline` — from a viewer's perspective, "I can't tell if it's live" and "it's
  not live" both currently correctly resolve to the exact same viewer-facing UI (Unit
  7's `BroadcastViewerScreen` has no distinct "resolution partially failed" state in the
  approved prototypes) — no new `BroadcastResolution` variant needed. **(recommended —
  avoids inventing a new caller-facing state that Unit 7's already-approved UI has
  nowhere to render)**
- B. Add a distinct `BroadcastResolution.ResolutionFailed` variant for this case
- C. Other (write in)

[Answer]: B

## Scalability Patterns — N/A

This unit's write volume is bounded by broadcaster count (one registry row per
broadcaster, written once ever); its read volume (resolution) is the only
higher-frequency path, and that's exactly what Q1 of NFR Requirements' rate limiting
targets. Signaling *message* volume/fan-out scaling is Unit 5's transport-layer concern,
not this unit's — this unit only defines the channel and its authorization, not the
message-passing performance characteristics under load (that's what Spike 2.1 measured).

## Performance Patterns

Restated from NFR Requirements: no formal latency NFR beyond the two-round-trip
resolution design and the fail-safe retry bound on ID allocation — nothing new to add
here.

## Security Patterns

Restated from SR-02/NFR Requirements: RLS establishes channel/row membership,
application logic establishes message-type authorization (the defense-in-depth split,
SR-02 §4) — Unit 3 implements the RLS half and the codec/shape-validation half; Unit 5
implements the message-type half. `SECURITY INVOKER` vs `SECURITY DEFINER` choice per
function is fixed (SR-02 §3, least privilege).

## Logical Components

### Package Placement (not a question — follows existing convention)

`zip_supabase` is TypeScript/Deno + SQL only (per `AGENTS.md`) — it is **not** a Dart
package. This unit's actual placement, mirroring Unit 2's `SupabaseAuthService`
precedent exactly:
- `zip_supabase`: the migration file only (`broadcast_identities` table, RLS policies,
  the two SQL functions) — no Dart code.
- `zip_core`: every Dart type and implementation — `BroadcastId`, `BroadcastLink`,
  `BroadcastIdentityRepository`/`SupabaseBroadcastIdentityRepository`,
  `BroadcastResolver`/its implementation, `BroadcastResolution`, `SignalingService`/
  `SupabaseSignalingService`, `StatusChannel`, `SessionSignalingChannel`,
  `SignalingMessage`, `SignalingCodec`, `PresenceSnapshot`, `BroadcastAuthorizationException`
  (Q1).

### Component List

- `BroadcastId` / `BroadcastLink` — value object + parsing utility (`zip_core/lib/src/models/`).
- `BroadcastResolution` / `PresenceSnapshot` / `BroadcastStatus` — sealed/value models (`zip_core/lib/src/models/`).
- `BroadcastIdentityRepository` (interface) / `SupabaseBroadcastIdentityRepository` (impl, Adapter pattern over `supabaseClientProvider`, same seam Unit 2 established) — `zip_core/lib/src/services/broadcast/`.
- `BroadcastResolver` (interface) / its implementation — same directory, composes `SupabaseBroadcastIdentityRepository`'s client access plus a `StatusChannel` read for the live-status half (Q2).
- `SignalingService` (interface) / `SupabaseSignalingService` (impl) — `zip_core/lib/src/services/signaling/`.
- `StatusChannel`, `SessionSignalingChannel` — implementations returned by `SupabaseSignalingService`, wrapping `private: true` Realtime channels.
- `SignalingMessage` (sealed) / `SignalingCodec` — pure Dart, no Supabase dependency at all (`zip_core/lib/src/models/` + a codec file) — this is deliberately the one piece of this unit with zero platform coupling, since it's shared protocol shape Unit 5/7 also depend on.
- `BroadcastAuthorizationException` (Q1) — `zip_core/lib/src/services/broadcast/` (or a shared exceptions file if this unit's the first to need one — check for an existing convention before creating a new one).

### Dependency Direction

```
zip_supabase (migration: broadcast_identities table, RLS, 2 SQL functions — no Dart)
        ▲ (schema/policy contract only, no code dependency)
        │
zip_core (BroadcastIdentityRepository ─▶ SupabaseBroadcastIdentityRepository ─▶ supabaseClientProvider
          BroadcastResolver ─▶ (SupabaseBroadcastIdentityRepository's client access, StatusChannel)
          SignalingService ─▶ SupabaseSignalingService ─▶ supabaseClientProvider
          SignalingCodec — no dependency on anything above, pure Dart)
```

No Dart code depends on `zip_supabase` directly (there's nothing to depend on — it's SQL
and Deno). The only "dependency" is a schema/contract one: `zip_core`'s implementations
assume the migration's table/function/policy shapes exist, verified at Code Generation
via integration tests against the local stack.
