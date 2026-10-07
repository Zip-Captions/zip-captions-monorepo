# NFR Design Plan: Signaling Channel Privacy (Unit 3.1)

**Prior stage**: NFR Requirements, approved 2026-10-05

## Context

Most of this unit's design is already fixed at Functional Design/SR-04 (channel
topology, RLS policies, interface shapes) and NFR Requirements (verification
approach for Q1/Q4). Genuinely open at this stage: one resilience gap
business-logic-model.md didn't cover (what happens if the broadcaster never responds to
a `JoinRequest` at all), plus the logical component list and dependency diagram.

## Planned Steps

- [ ] Resilience: viewer-side `JoinRequest` timeout/retry
- [ ] Scalability/Performance: restate from NFR Requirements (no new question)
- [ ] Security: restate from SR-04 (no new question)
- [ ] Logical Components: component list and dependency diagram
- [ ] Generate `nfr-design-patterns.md`, `logical-components.md`

## Resilience

### Q1: What happens if the broadcaster never subscribes to the viewer's per-viewer channel at all (e.g. it never saw the `JoinRequest`, or crashed between receiving it and subscribing)?

business-logic-model.md's join sequence describes the happy path (broadcaster receives
`JoinRequest`, subscribes, exchange proceeds) but not what bounds a viewer's wait if
nothing ever happens — unlike Unit 5's join-ack timer (which bounds *data-channel*
confirmation after SDP/ICE has already started), there's currently no bound on this
earlier, signaling-only wait.

- A. The viewer resends `JoinRequest` on the lobby channel at 2s, 5s, then 10s (3
  attempts total) if no response (an `SdpOffer`/`JoinAccepted`/`JoinRejected` arriving
  on its own per-viewer channel) appears. If all 3 attempts produce nothing, the viewer
  treats this as `ConnectFailure.Timeout` (Unit 5's existing variant, domain-entities.md)
  — no new failure type needed, since "the broadcaster never responded" and "the
  broadcaster responded but the data channel never confirmed" are both, from the
  viewer's own perspective, "I asked to connect and nothing came of it within a bounded
  wait." **(recommended — reuses Unit 5's existing `Timeout` variant rather than
  inventing a signaling-specific one, and a resend is cheap/idempotent since the
  broadcaster's lobby-side processing of a duplicate `JoinRequest` for a `peerId` it's
  already subscribed to is a harmless no-op)**
- B. Other (write in)

[Answer]: A - and the UI should show the user a "Joining..." progress message in the case that it's backing off so they understand that there's a process underway and they just need to wait.

**Resolution**: no new state needed in this unit's own model. The entire resend/backoff
window (2s/5s/10s) stays within `ConnectionStatus.Connecting` — already one of FR-7.4's
fixed viewer-visible states, entered the moment `connect()` is called and held until
either success (`Connected`) or exhausted retries (`Failed(Timeout)`). Rendering a
"Joining..." message for `Connecting` is Unit 7's (Zip Captions Viewer) job, not
something this unit's domain model needs to add — flagged here so Unit 7's own
Functional Design picks it up as the expected copy for that state, distinct from a bare
spinner.

## Scalability / Performance (restated, no new question)

Per NFR Requirements Q1/Q2: the up-to-51-concurrent-channel load gets empirically
verified at Code Generation (not a new design pattern — a verification step), and the
two-hop join sequence's added latency folds into Unit 5's existing NFR-1.3 target. No
new pattern decision belongs at this stage.

## Security (restated, no new question)

SR-04 already fixes every RLS policy and the lobby's ownership-check mechanism. Nothing
left open for this stage to decide.

## Logical Components

### Q2: Component placement and naming?

- A. `zip_supabase`: the new migration only (RLS policy changes, Section 3 of SR-04) —
  no SQL function, matching this unit's "no new `SECURITY DEFINER`" NFR Requirements
  finding. `zip_core` (`lib/src/services/signaling/`, same directory as Unit 3's
  existing signaling code): `LobbyChannel` (interface) + `SupabaseLobbyChannel` (impl),
  revised `SessionSignalingChannel`/`SupabaseSessionSignalingChannel` (presence removed,
  now keyed by `peerId`), revised `SignalingService`/`SupabaseSignalingService` (gains
  `lobbyChannel()`). `PeerId` generation: a small top-level function (not a value-object
  class like `BroadcastId` — domain-entities.md already specifies it's a plain `String`
  with an entropy requirement, not a validated format worth wrapping in a class).
  **(recommended — matches Unit 3's existing file layout exactly, no new directory)**
- B. Other (write in)

[Answer]: A
