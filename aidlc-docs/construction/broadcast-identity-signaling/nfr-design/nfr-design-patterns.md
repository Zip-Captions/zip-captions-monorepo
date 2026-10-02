# NFR Design Patterns — Broadcast Identity + Signaling (Unit 3)

## Resilience Patterns

### RLS-rejection handling (Q1: `BroadcastAuthorizationException`)

A single `BroadcastAuthorizationException` (new, `zip_core`-defined) wraps any
RLS/permission-denied rejection from Postgres or Realtime — distinct from a plain
network failure. Thrown by `SupabaseBroadcastIdentityRepository` and
`SupabaseSignalingService`'s implementations whenever the underlying Postgrest/Realtime
call fails with a permission-denied signal, rather than letting Supabase's own raw
exception types leak to callers. This keeps `BroadcastSessionNotifier` (Unit 6) able to
catch one project-defined type to distinguish "the server said no" from "the network is
down," without this unit needing to model every possible RLS-rejection scenario as a
distinct caller-facing state (a full sealed-result type would be over-engineering for
what's expected to be a rare, largely adversarial-or-buggy case).

### Resolution's two-step failure mode (Q2: `ResolutionFailed`, extending the sealed type)

**Design correction, decided at this stage**: `BroadcastResolution` gains a fifth
variant, `ResolutionFailed`, produced when step 2 of resolution (the presence read on
`status:{broadcast_id}`) itself errors or times out — kept distinct from `Offline`
(which now means specifically "the presence read completed and found nothing"). This
extends a shape that was fixed at Application Design (inception phase); the extension is
made here, within the same unit that owns and implements the type, before any Code
Generation locks it in. See `domain-entities.md` (Functional Design, retroactively
updated) and `sr-02-rls-realtime-policy.md` §2 for the full rationale: conflating "we
couldn't check" with "confirmed not broadcasting" risks a transient Realtime glitch
being misreported to a viewer as the broadcast having ended.

**Consequence for Unit 7** (not designed here, flagged for that unit's own Functional
Design): `BroadcastViewerScreen`'s approved prototype states don't yet have a rendering
for `ResolutionFailed` distinct from `Offline`/`notBroadcasting`. Unit 7 must decide
whether to add one (e.g. offering a manual retry) or fold `ResolutionFailed` into an
existing "cannot connect" state at that unit's own Functional Design — this unit's
responsibility ends at producing the correct, honest resolution outcome; Unit 7 decides
how to render it. Added to `aidlc-state.md`'s Backlog.

## Scalability Patterns — N/A

Restated from NFR Requirements: registry writes are bounded by broadcaster count
(effectively one-time per broadcaster); resolution reads are exactly what Kong's rate
limit targets. Signaling message-volume scaling under fan-out load is Unit 5's concern
(informed by Spike 2.1), not this unit's — this unit only defines channels and their
authorization.

## Performance Patterns

No new patterns beyond NFR Requirements' restated two-round-trip resolution design and
the fail-safe (not performance-targeted) ID-allocation retry bound.

## Security Patterns

Restated from SR-02: RLS establishes channel/row membership; application logic
(Unit 5's transport layer, informed by this unit's `SignalingMessage` type) establishes
message-type authorization. `SECURITY INVOKER`/`SECURITY DEFINER` choice per function is
fixed and minimized to least privilege (SR-02 §3).
