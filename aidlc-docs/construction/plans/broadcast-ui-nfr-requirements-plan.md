# NFR Requirements Plan: Zip Broadcast Broadcast UI (Unit 6)

**Prior stage**: Functional Design, approved 2026-10-12

## Context

Functional Design fixed the orchestration sequence (`goLive()`/`endBroadcast()`, the
`BroadcasterSessionState` machine, the two screens' data sources, the Rule 9 sign-out
guard). This unit introduces no new infrastructure, no new persisted data, and no new
concurrency — it is pure orchestration (explicit calls into already-shipped `zip_core`
services from Units 3/3.1/4/5) plus two screens that read notifier/provider state. The
open NFR questions are concentrated in **testability** (how to test an orchestrator
whose every dependency is already its own tested component), **reliability**
(exception-safety of the unwind/teardown sequences Rules 2 and 5 depend on), and a few
confirmations (PBT scope, logging, dependency footprint, accessibility) carried forward
from this project's established patterns rather than reopened from scratch.

**Scalability**: N/A for this unit — no new capacity, concurrency, or scaling concern.
`LiveBroadcast.viewers`/`maxViewers` are consumed as-is from Unit 5's `BroadcastTransport`
and Unit 5's `defaultBroadcastLimits`; this unit adds no new limit, queue, or resource pool.

**Performance**: N/A beyond what's already fixed. NFR-1.3's 3s/5s targets are Unit 5's
and Unit 9's concern (already carried forward in Unit 5's own NFR Requirements, Q2); this
unit adds no new latency-sensitive path of its own — the dashboard's duration/viewer
count are computed synchronously from state already held in memory.

## Planned Steps

- [ ] Testability: test strategy for `BroadcastSessionNotifier` (fakes vs real collaborators)
- [ ] Testability: widget-test scope for the two screens
- [ ] Reliability: exception-safety of `goLive()`'s unwind and `endBroadcast()`'s teardown
- [ ] Security: logging constraints for this unit's new surfaces
- [ ] Tech stack: confirm no new dependency is introduced
- [ ] PBT: framework and property scope for `BroadcasterSessionState` and `validateSessionName`
- [ ] Usability: accessibility semantics for the banner/stat-card surfaces
- [ ] Generate `nfr-requirements.md` and `tech-stack-decisions.md`

## Testability

### Q1: Test strategy for `BroadcastSessionNotifier` — fakes for every collaborator, or a mix with real providers?

`goLive()`/`endBroadcast()` call into six already-shipped collaborators
(`authNotifierProvider`, `broadcastIdentityRepositoryProvider`, `signalingServiceProvider`,
`iceServerProviderProvider`, `TransportSelector`/`BroadcastTransport`,
`captioningStarterProvider`) plus the new `ViewerAdmission`/`StatusChannel`/
`RemoteBroadcastTarget` instances it owns per session. Each collaborator already has its
own test suite in its owning unit (Units 2–5) — this unit's job is to test the
*sequencing and state transitions* (Rules 1, 2, 3, 4, 5, 6), not re-verify any
collaborator's own internal correctness.

A) Hand-written fakes for every collaborator (mirrors Unit 5's own precedent for
   `PeerConnectionHandle`/`SignalingService`) — a `FakeSignalingService` (reuse Unit 5's
   `test/helpers/fake_signaling_service.dart` where the same interface is exercised),
   `FakeCaptioningStarter`, a fake `BroadcastTransport` exposing controllable `viewers`/
   ack-timeout behavior, and fakes for `BroadcastIdentityRepository`/`IceServerProvider`
   (simple value-returning stubs, no behavior to fake). No real Supabase stack, no real
   `flutter_webrtc`, no real-backend integration test — this unit's own logic is provable
   entirely in-memory, and the collaborators it calls are already proven elsewhere.
   **(recommended — matches the project's established "test the seam, not the already-
   tested dependency" pattern; the alternative would re-test Units 3/3.1/4/5's own
   responsibilities inside Unit 6)**
B) Other (write in)

[Answer]: A

### Q2: Widget-test scope for `BroadcastSetupScreen` and the live dashboard?

Proto-11/Proto-12's approved states give a concrete list of renderable states, but the
depth of widget-test coverage (every state vs a representative subset) isn't fixed.

A) One widget test per approved Proto-11/Proto-12 state reachable by provider overrides
   (signed-out overlay; empty/invalid/valid session-name validation per Rule 7's three
   categories; Go Live progress spinner; each banner-matrix row from F-6.4 step 4;
   broadcast-full banner; viewer list render; the Rule 9 sign-out refusal snackbar) —
   using `ProviderScope` overrides on `broadcastSessionNotifierProvider`/
   `broadcastSettingsNotifierProvider`, the existing Phase 1 widget-test pattern
   (`HomeScreen`'s own tests). No golden-image tests (this project has none today).
   **(recommended — matches S-17's own acceptance criteria one-to-one, so every AC has
   a reachable, asserted widget test)**
B) Other (write in)

[Answer]: A

## Reliability

### Q3: What happens if a step *within* `goLive()`'s unwind (Rule 2) or `endBroadcast()`'s teardown (Rule 5) itself throws?

Rule 2's unwind table and Rule 5's teardown sequence both assume each step
(`transport.stop()`, `registry.remove(target)`, `statusChannel.close()`) succeeds. Unit 5's
own `transport.stop()`/registry disposal are documented as best-effort in their own
units, but nothing in this unit's Functional Design says what the notifier does if one of
*these* calls throws mid-unwind — a naive implementation could leave the state machine
stuck in `StartingState`/`EndingState` forever (unreachable by Rule 1's retry gate, and a
state the Rule 9 guard treats as non-idle — so sign-out would also become permanently
blocked).

A) Each unwind/teardown step is wrapped individually (catch, log via the existing
   `Logger`, continue to the next step regardless) — the state transition to
   `BroadcastFailedState`/`OfflineState` always happens as the last action, unconditionally,
   once every step has been *attempted* (not necessarily succeeded). This guarantees the
   state machine can never get stuck in a non-idle state because of a teardown-step
   failure, at the cost of a possible resource leak (e.g. a transport that failed to
   stop cleanly) that's then only discoverable via the logged exception, not a app-visible
   state. **(recommended — a stuck non-idle state silently breaking Rule 1's retry and
   Rule 9's sign-out is worse than a logged, non-fatal leak on an already-unusual error
   path)**
B) Let the exception propagate uncaught — the state machine can get stuck in a non-idle
   state on a teardown-step failure; accept this as an extremely rare, acceptable risk
   (not recommended — contradicts SECURITY-15's fail-safe-defaults rule)
C) Other (write in)

[Answer]: A

## Security

### Q4: Logging constraints for this unit's new surfaces — any new rule needed?

`business-rules.md` Rule 10 already restates the project-wide no-caption-content/
no-token rule for this unit's fields. Does anything about `goLive()`/`endBroadcast()`'s
own lifecycle (success/failure logging) need a rule beyond that restatement?

A) No new logging infrastructure. Where a `Logger` call is useful (e.g. logging a
   `goLive()` failure's `BroadcastFailure` variant, or Q3's unwind-step exceptions), it
   may log `broadcastId`, `sessionId`, the failure/exception type, and non-content state
   values only — never caption text, never the raw exception's full `toString()` if that
   could ever embed request/response bodies from a collaborator (defensive: log the
   exception type and message, not arbitrary nested data). Pure restatement of the
   existing project-wide rule for this unit's own log call sites.
   **(recommended — no new mechanism, consistent with every prior unit's identical
   confirmation)**
B) Other (write in)

[Answer]: A

## Tech Stack

### Q5: Does this unit introduce any new dependency?

The Rule 9 `InheritedWidget` mechanism, the two screens, and `BroadcastSessionNotifier`/
`BroadcastSettingsNotifier` all use packages already present (`flutter`, `riverpod`/
`riverpod_annotation`, `freezed`, `uuid`, `shared_preferences`, `intl`/ARB localization).

A) No new dependency anywhere in this unit — confirmed by checking every new class
   against the existing `pubspec.yaml`s for `zip_core`/`zip_broadcast`. If accessibility
   semantics (Q7) end up needing something beyond Flutter's built-in `Semantics`/
   `MergeSemantics` widgets, that would be a new finding requiring FR-9.5's approval —
   not assumed here. **(recommended)**
B) Other (write in)

[Answer]: A

## PBT

### Q6: PBT framework and property scope for this unit?

`domain-entities.md` and `business-logic-model.md` already describe
`BroadcasterSessionState`'s transitions as a "PBT-06 reference model" (Functional
Design's own PBT-01 property identification). `BroadcastSettings.validateSessionName`
has three mutually-exclusive error categories (Rule 7) — a good candidate for an
invariant-style property (exactly one category matches, or none, never more than one)
rather than only example-based tests for the three named cases.

A) `glados` (this project's established framework since Unit 2), applied to two
   properties: (1) a model-based/stateful PBT suite for `BroadcasterSessionState`
   (PBT-06) — generated `goLive`/`endBroadcast` call sequences against the fake
   collaborators from Q1, asserting the state machine only ever makes the transitions in
   `domain-entities.md`'s diagram and that Rule 5's idempotence holds
   (`endBroadcast()` called twice in a row from `LiveState` is equivalent in end-state to
   once); (2) an invariant PBT for `validateSessionName` (PBT-03) — for any generated
   string, exactly zero or one error category is returned, never more than one, with the
   three named example cases (empty/too-long/control-char) kept as explicit example-based
   tests per PBT-10 (complementary, not replaced). No new framework.
   **(recommended — direct reuse of the established pattern, and Functional Design
   already anticipated the state-machine property)**
B) Other (write in)

[Answer]: A

## Usability

### Q7: Accessibility semantics for the banner/stat-card surfaces — in scope for this unit, or deferred?

Proto-11/Proto-12 are approved as visual mockups; neither speaks to screen-reader
behavior for the captions-inactive banner (F-6.4), the broadcast-full banner (F-6.5), or
the Duration stat card. This project has not established an accessibility-testing
convention anywhere in prior units' NFR Requirements.

A) Defer: ship with Flutter's default widget semantics (a `Text` widget's content is
   read by screen readers by default; no explicit `Semantics`/live-region wrapping added
   in this unit). Revisit as a project-wide accessibility pass if/when one is scoped —
   consistent with how this project has deferred other cross-cutting, not-yet-adopted
   concerns (crash reporting, operational alerting) rather than deciding them narrowly
   under one unit. **(recommended — no prior unit has established an accessibility
   pattern to extend, and inventing one unilaterally for just this unit's two screens
   would be a narrow, ad hoc policy)**
B) Add explicit `Semantics`(`liveRegion: true`) wrapping on the banners specifically (so
   a screen-reader user is notified when the captioning-inactive/broadcast-full state
   appears without needing to re-focus the element), as a scoped exception to Option A
C) Other (write in)

[Answer]: A
