# NFR Design Plan: Zip Broadcast Broadcast UI (Unit 6)

**Prior stage**: NFR Requirements, approved 2026-10-13

## Context

NFR Requirements fixed *what* has to happen (every unwind/teardown step is individually
caught and logged, Q3; fakes for every collaborator, Q1/Q2) but not *how* the
implementation is structured to make that true without duplicated logic, and not the
one correctness-adjacent detail Rule 9's guard depends on but doesn't spell out
explicitly. Scalability and Performance introduce no new pattern at this stage — both
are fully covered by NFR Requirements already (restated below, not reopened).

## Planned Steps

- [ ] Resilience: shared disposal mechanism for the per-session resource bundle
- [ ] Security: TOCTOU-avoidance rule for the Rule 9 sign-out guard
- [ ] Logical Components: final component list and dependency diagram
- [ ] Generate `nfr-design-patterns.md` and `logical-components.md`

## Resilience Patterns

### Q1: How is the Rule 2/5 catch-and-continue teardown (NFR Requirements Q3) structured so it isn't duplicated between `goLive()`'s failure unwind and `endBroadcast()`'s teardown?

`BroadcastSessionNotifier` owns five per-session resources (`StatusChannel`,
`ViewerAdmission`, the `BroadcastTransport` instance, the `RemoteBroadcastTarget`
instance, and its two stream subscriptions) that both Rule 2's unwind table and Rule
5's teardown sequence dispose of, each step individually caught and logged (NFR
Requirements Q3). Writing that catch-and-continue logic inline at both call sites would
duplicate it and risk the two copies drifting apart.

A) Introduce a small private holder (e.g. `_SessionResources`, a plain class or
   `record` on `BroadcastSessionNotifier`) grouping all five owned resources, with a
   single `Future<void> disposeAll(Logger log)` method that attempts each teardown step
   in the fixed order (status channel → target/registry → transport → subscriptions),
   catching and logging each individually, never throwing itself. `goLive()`'s unwind
   and `endBroadcast()`'s teardown both call this one method — the only difference
   between the two call sites is which terminal state they set afterward
   (`BroadcastFailedState(reason)` vs `OfflineState`), never how disposal itself
   happens. The notifier holds at most one `_SessionResources?` at a time, set in
   `goLive()`'s success path and nulled out immediately after `disposeAll()` runs
   (either path). **(recommended — one disposal implementation instead of two, and the
   nullable-single-field shape makes "no session resources exist" (the precondition for
   `BroadcastFailedState`/`OfflineState` in Rules 1 and 5) a directly checkable
   invariant: non-idle states have a non-null `_SessionResources`, idle states have
   `null`)**
B) Keep the five resources as separate nullable fields directly on
   `BroadcastSessionNotifier`, with inline try/catch blocks duplicated at both the
   `goLive()` failure path and `endBroadcast()` (not recommended — exactly the
   duplication risk described above)
C) Other (write in)

[Answer]: A

## Scalability Patterns (restated from NFR Requirements, no new pattern)

Nothing new to design — NFR Requirements already fixed this unit's scalability posture
as N/A (no new capacity/concurrency concern; `defaultBroadcastLimits` consumed as-is
from Unit 5). This stage introduces no new pattern here.

## Performance Patterns (restated from NFR Requirements, no new pattern)

Nothing new to design — NFR Requirements already fixed this unit's performance posture
as N/A beyond Unit 5/9's existing NFR-1.3 ownership. This stage introduces no new
pattern here.

## Security Patterns

### Q2: Does Rule 9's `requestSignOut()` check-then-call sequence need an explicit no-await-between rule to stay race-free?

`requestSignOut()` reads the current `BroadcasterSessionState` and then either calls
`authNotifierProvider.notifier.signOut()` or refuses. Rule 1 already establishes the
project's pattern for this exact hazard elsewhere: `goLive()` sets `StartingState`
"synchronously, before the first await," specifically so the state-check-then-act
sequence can't be interleaved with another call. `requestSignOut()`'s own read-then-act
sequence has the identical shape and needs the identical discipline, but
`business-logic-model.md`'s F-6.9 doesn't spell this out as its own rule.

A) Document as an explicit implementation rule (in `nfr-design-patterns.md`, carried
   into Code Generation): `requestSignOut()`'s `ref.read(broadcastSessionNotifierProvider)`
   and the subsequent `signOut()` call (or the refusal) MUST execute in the same
   synchronous span, with no `await` between them — mirroring Rule 1's identical
   discipline. This is not a new mechanism (Dart's single-threaded event loop already
   makes two back-to-back synchronous statements atomic with respect to any other
   code), but stating it explicitly prevents a future edit (e.g. inserting a
   confirmation dialog's `await` before the state check) from silently reopening the
   mid-`goLive()` race Rule 9 exists to close. **(recommended — costs nothing now,
   protects against a specific, identifiable future mistake)**
B) No explicit rule needed — treat this as ordinary code review vigilance, not a
   documented constraint
C) Other (write in)

[Answer]: A

## Logical Components

### Q3: Final component list and dependency diagram?

A) Confirms `tech-stack-decisions.md`'s placement, now including Q1's
   `_SessionResources` holder: `zip_core`'s `lib/src/services/broadcast/` gets
   `BroadcastSessionNotifier` (+ `_SessionResources`), `BroadcastSettingsNotifier`;
   the `CaptioningStarter` interface/default implementation and
   `captioningStarterProvider` go wherever `RecordingStateNotifier` already lives;
   `lib/src/models/` gets `BroadcastSettings`, `BroadcasterSessionState` (5 variants),
   `LiveBroadcast` (8 fields), unchanged `BroadcastFailure`. Unit 5's shipped
   `RemoteBroadcastTarget` and `BroadcastTransport`/`WebRtcBroadcastTransport` gain
   their two additive methods (`primeActivity()`, `sendBroadcastEnded()`) in place — no
   new files for those. `zip_broadcast` gets the two screens
   (`lib/src/screens/`), the new `InheritedWidget` (on `ZbAppShell`'s own file),
   `main.dart`'s `captioningStarterProvider` override, and `AccountSection`'s call-site
   switch. Dependency direction: this unit depends on `SignalingService`/
   `IceServerProvider`/`BroadcastTransport`/`RemoteBroadcastTarget` (Units 3/3.1/4/5) as
   already-built interfaces; nothing in those units depends back on Unit 6.
   **(recommended — no new information versus `tech-stack-decisions.md`, just the
   dependency-diagram form every prior unit's NFR Design produces, updated for Q1)**
B) Other (write in)

[Answer]: A
