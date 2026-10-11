# NFR Design Plan: WebRTC Transport + Remote Output + Capacity (Unit 5)

**Prior stage**: NFR Requirements, approved 2026-10-08

## Context

Functional Design already fixed the exact resilience *schedules* (Rule 1's 5s ack
timer, Rule 2's 1s/2s/4s/8s/8s… backoff, Rule 6's reservation state machine) and NFR
Requirements fixed the exception boundary and the "zero real `flutter_webrtc` objects
in tests" constraint. What's left for this stage is genuinely an NFR Design-level
question this project's prior units have all faced: **how is a schedule/timer-driven
mechanism made testable without a real test actually waiting out real wall-clock
time**, plus the standard component-placement pass.

## Planned Steps

- [ ] Resilience: testability seam for timer/schedule-driven mechanisms
- [ ] Component placement and dependency diagram
- [ ] Generate `nfr-design-patterns.md` and `logical-components.md`

## Resilience

### Q1: How are Rule 1's ack timer, Rule 2's backoff retry loop, and Rule 6's reservation-expiry check made testable without real waits?

NFR Requirements Q5 already fixed "zero real `flutter_webrtc` objects in tests" — but
these three mechanisms involve real *time* passing (a 5s timer, an 8s-repeating
backoff, a 120s reservation window), which a test suite cannot practically wait out
wall-clock-for-real even with a fake `PeerConnectionHandle`.

- A. (original answer, **corrected 2026-10-08** — see below) Inject time as a seam at
  every point one of these mechanisms needs it: an injectable
  `Future<void> Function(Duration) delay` for the ack timer/backoff loop, and an
  injectable `DateTime Function() now` for `ViewerAdmission`'s expiry sweep.
- B. Other (write in)

**Corrected 2026-10-08, before Code Generation began**: checked this answer against
the codebase's own existing conventions before acting on it, and found the `delay`
seam unnecessary — `supabase_auth_service.dart` (Unit 2) already solves the identical
"timer-driven code must be testable without a real wait" problem with a plain
`Timer(...)` and no injected delay function at all, tested via `fakeAsync()` (the
`fake_async` package, already a dev dependency). Revised answer: `WebRtcBroadcastTransport`'s
ack timer (Rule 1) and `WebRtcViewerTransport`'s backoff loop (Rule 2) use plain
`Timer`/`Future.delayed` directly, tested with `fakeAsync()` matching
`supabase_auth_service_test.dart`'s own idiom exactly — no new pattern invented.
`ViewerAdmission`'s `now` seam stands as originally answered, but as an **optional,
nullable** `DateTime Function()? now` defaulting to `DateTime.now`, matching
`transcript_writer_target.dart`'s identical existing idiom rather than a
newly-invented required-parameter shape. Expiry is still a lazy sweep on every
`tryAdmit`/`release`/`count` call, never a background `Timer`.

[Answer]: A (corrected)

## Scalability / Performance (restated from NFR Requirements, no new pattern)

Nothing new to design — Q1/Q2 of NFR Requirements already fully specify this unit's
scalability/performance posture (a plain constant for `BroadcastLimits`, fakes-only
logical-correctness testing). This stage introduces no new pattern here.

## Security (restated from SR-01–04, no new pattern)

This unit introduces no new RLS policy, credential issuer, or logging mechanism — it
consumes Units 3/3.1/4's already-approved security posture unchanged. Nothing new to
design here.

## Component Placement

### Q2: Final component list and dependency direction?

- A. Confirms `tech-stack-decisions.md`'s placement: new `lib/src/services/webrtc/`
  directory (`WebRtcBroadcastTransport`, `WebRtcViewerTransport`,
  `PeerConnectionHandle`, `PeerConnectionFactory`, `TransportSelector`, the new
  `delay`/`now` seams from Q1 as constructor parameters on the two transport classes
  and on `ViewerAdmission` respectively); new models in `lib/src/models/`
  (`CaptionWireMessage`, `CaptionWireCodec`, `ConnectFailure`,
  `BroadcastTransportContext`/`ViewerTransportContext`, `ViewerConnectionInfo`); the
  new constant in `lib/src/constants/`. Dependency direction: this unit depends on
  `SignalingService` (Units 3/3.1) and `IceServerProvider` (Unit 4) as already-built
  interfaces, never the reverse — no existing file in either of those units is
  modified. **(recommended — no new information versus `tech-stack-decisions.md`,
  just the dependency-diagram form every prior unit's NFR Design produces)**
- B. Other (write in)

[Answer]: A
