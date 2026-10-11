# NFR Design Patterns — WebRTC Transport + Remote Output + Capacity (Unit 5)

## Resilience

**Timer/schedule testability patterns (Q1, corrected 2026-10-08)**: three mechanisms
involve real time passing and must stay testable in a `flutter test` run that finishes
in seconds, not the minutes their real schedules would take. An earlier draft of this
answer proposed injecting a `delay: Future<void> Function(Duration)` constructor
seam — checked against this codebase's own existing convention and found
unnecessary: `supabase_auth_service.dart` (Unit 2) already solves the identical
problem with plain `Timer(...)` and no injected delay function at all, tested via
`fakeAsync()` (the `fake_async` package, already a dev dependency) fast-forwarding the
real timer. That is simpler and already proven in this codebase, so this unit follows
it exactly rather than inventing a parallel pattern:

- `WebRtcBroadcastTransport`'s 5s ack timer (Rule 1) and `WebRtcViewerTransport`'s
  1s/2s/4s/8s/8s… backoff loop (Rule 2) both use plain `Timer`/`Future.delayed`
  directly — no injected delay seam. Tests wrap the relevant call in `fakeAsync((fake)
  { ...; fake.elapse(Duration(...)); })`, matching `supabase_auth_service_test.dart`'s
  own idiom exactly, so a full ack-timeout or multi-attempt backoff sequence is driven
  without the test itself taking any real wall-clock time.
- `ViewerAdmission`'s `reservedUntil` deadline (Rule 6) is checked against an
  optional, nullable `DateTime Function()? now` constructor parameter, defaulting to
  `DateTime.now` — matching `transcript_writer_target.dart`'s identical existing
  idiom (`_now = now ?? DateTime.now`) exactly, not a newly-invented shape. **Expiry
  is a lazy sweep performed at the start of every `tryAdmit`/`release`/`count` call,
  never a background `Timer` per reservation** — a literal reading of Rule 6's own
  invariant wording ("expiry must be checked and applied before a new `tryAdmit` can
  consume the freed slot"), and it means `ViewerAdmission` owns no timer lifecycle at
  all: nothing to cancel in `stop()`, nothing that can leak or fire after the
  transport is gone. Tests supply a fake `now` they control directly (no `fakeAsync`
  needed here, since nothing in `ViewerAdmission` itself waits on a `Timer`), making
  Rule 6's described race (an expiry and a new `tryAdmit` arriving at the same
  instant) trivially reproducible on demand.

No other resilience pattern is new at this stage — Rule 1/2/6's exact schedules were
already fixed at Functional Design; this stage only decides how those schedules are
made testable, and does so by reusing this codebase's own existing conventions rather
than introducing a new one.

## Scalability / Performance (restated from NFR Requirements, no new pattern)

Nothing new to design — NFR Requirements Q1 (a plain `const BroadcastLimits`) and Q2
(fakes validate logical correctness only, NFR-1.3's wall-clock targets deferred to
Unit 9) are this unit's complete scalability/performance posture.

## Security (restated from SR-01–04, no new pattern)

This unit introduces no new RLS policy, credential issuer, or logging mechanism — it
consumes Units 3/3.1/4's already-approved security posture unchanged.
