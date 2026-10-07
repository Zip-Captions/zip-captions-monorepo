# NFR Requirements Plan: Signaling Channel Privacy (Unit 3.1)

**Prior stage**: Functional Design, approved 2026-10-05 (including SR-04 sign-off)

## Context

Functional Design and SR-04 fixed the channel topology, RLS policies, and interface
shapes. This stage covers scalability (per-client channel limits at the viewer cap),
performance (the two-hop join sequence's added latency), reliability (channel cleanup),
testability (how isolation itself gets verified — this unit's correctness claim is
exactly "a viewer sees nothing," which needs a real multi-viewer test, not just unit
tests against fakes), and tech stack (none new).

## Planned Steps

- [ ] Scalability: per-client Realtime channel subscription limits at `maxViewers`
- [ ] Performance: two-hop join sequence latency
- [ ] Reliability: per-viewer channel cleanup and leak prevention
- [ ] Testability: how "a viewer sees nothing" gets verified for real
- [ ] Tech stack: confirm no new dependencies
- [ ] PBT: scope for this unit
- [ ] Generate `nfr-requirements.md` and `tech-stack-decisions.md`

## Scalability

### Q1: Does the broadcaster holding up to `maxViewers` (50, interim) concurrent per-viewer Realtime channel subscriptions hit any platform limit?

Previously the broadcaster held exactly one `signaling:{session_id}` subscription
regardless of viewer count. Now it holds one `LobbyChannel` plus one
`SessionSignalingChannel` **per accepted viewer** — up to 51 simultaneous Realtime
channel subscriptions on one client connection at the interim cap.

- A. Verify directly against the real local stack (Unit 4's Coturn/Supabase dev stack)
  before this unit's Code Generation closes: open 50+ concurrent private channel
  subscriptions from one `supabase_flutter` client and confirm none are silently
  dropped or rate-limited. Self-hosted Supabase Realtime multiplexes channels over a
  single WebSocket connection per client (confirmed via `supabase_flutter`'s own docs:
  `RealtimeClient` "multiplexes multiple `RealtimeChannel` subscriptions over a single
  connection") — no per-client channel-count limit is documented, but this project's own
  standing practice is to verify empirically rather than trust documentation alone for
  anything capacity-related (the same discipline Spike 2.1/2.3 and Unit 4's Code
  Generation already applied). If a real limit is found, the fallback is documented
  here for Code Generation to apply (e.g. closing a departed viewer's channel
  immediately rather than batching cleanup). **(recommended)**
- B. Other (write in)

[Answer]: A

## Performance

### Q2: Does the two-hop join sequence (viewer subscribes → sends `JoinRequest` → broadcaster subscribes → SDP exchange begins) add a meaningful delay versus the old one-hop design?

- A. No new measurable NFR target beyond what Unit 5 already owns (NFR-1.3's
  join-to-first-caption ≤3s, itself an unmeasured interim target per Spike 2.1). The
  added step is one additional Realtime channel subscribe round-trip (broadcaster
  subscribing to the new per-viewer topic after receiving the lobby `JoinRequest`) —
  the same order of latency as a single Realtime channel join, not a structural delay.
  This unit's own job is not to add an *unbounded* delay (e.g. polling instead of an
  event-driven subscribe), not to hit a specific number. **(recommended — consistent
  with how Unit 5 itself treated NFR-1.3: validate logically, let Unit 9's real
  two-device test measure the actual number)**
- B. Other (write in)

[Answer]: A

## Reliability

### Q3: Per-viewer channel cleanup — what prevents an orphaned/leaked channel subscription?

business-logic-model.md already specifies the happy-path teardown (`Leave`,
`BroadcastEnded`, Unit-5-detected disconnect). The NFR-level question is what bounds the
*worst* case — a channel that never gets an explicit close signal at all (e.g. the
broadcaster's own process crashes).

- A. No new mechanism needed beyond what already exists: Supabase Realtime's own
  connection-level cleanup (a dropped WebSocket connection implicitly ends every channel
  subscription on it — platform behavior, not application code) bounds the worst case
  to "the broadcaster's whole session ends," which is already the correct outcome for a
  crashed broadcaster (every viewer should lose their connection anyway). No per-channel
  heartbeat or timeout is needed on top of that. **(recommended — the failure mode this
  question worries about already has a correct, existing answer one layer down, in the
  underlying connection lifecycle, not something this unit needs to add)**
- B. Other (write in)

[Answer]: A

## Testability

### Q4: How does "a viewer sees nothing belonging to another viewer" actually get verified?

This unit's entire correctness claim is a negative ("X never happens"), which unit tests
against fakes can't demonstrate on their own — a fake `SessionSignalingChannel` pair
wired directly together (the kind of test double Unit 5 uses) would simply never route
cross-viewer traffic *by construction*, proving nothing about whether the **real** RLS
policies actually enforce it.

- A. A real-backend integration test (tagged `integration-supabase`, skip-by-default,
  Unit 3's established convention), run against the local Supabase stack with **two
  real, concurrently-connected viewer clients** plus one broadcaster client: assert that
  Viewer B's Realtime subscription to Viewer A's known per-viewer topic (constructed
  with a `peerId` it was never given — simulating the only way it could even attempt
  this) is rejected by RLS, and that Viewer B's `LobbyChannel` instance has no way to
  read `joinRequests` at all (interface-level, not just RLS — `LobbyChannel`'s public
  surface for a viewer-constructed instance literally has no `joinRequests` getter, per
  domain-entities.md). This is the one place in this unit where only testing against the
  real stack can actually confirm the security property holds — mirroring the
  dependency doc's own testing checkpoint ("verified against the real local stack with
  2+ concurrent viewers, not just unit tests"). **(recommended)**
- B. Other (write in)

[Answer]: A

## Tech Stack

### Q5: Any new dependencies?

- A. None. This unit is a new migration (SQL, no new Postgres extension beyond what's
  already enabled) plus `zip_core` Dart changes using the same `supabase_flutter` APIs
  Unit 3 already uses (`channel()`, `onBroadcast`, `sendBroadcastMessage`, `subscribe`)
  — no new package. **(recommended)**
- B. Other (write in)

[Answer]: A

## PBT

### Q6: PBT scope for this unit?

- A. No new PBT suite — `SignalingCodec`'s own round-trip PBT (Unit 3) is unaffected
  (message shapes didn't change, only routing). The one correctness property specific
  to this unit (channel isolation) is a security/integration property best verified by
  Q4's real-backend test, not a generated-input property test — there's no meaningful
  "generate random inputs" angle to "can Viewer B read Viewer A's channel," the answer
  is a fixed yes/no per RLS policy, not a space worth exploring with generated data.
  **(recommended)**
- B. Other (write in)

[Answer]: A
