# NFR Requirements — Zip Broadcast Broadcast UI (Unit 6)

**Prior stage**: Functional Design, approved 2026-10-12.

## Scalability

N/A for this unit. No new capacity, concurrency, or scaling concern is introduced —
`LiveBroadcast.viewers`/`maxViewers` are consumed as-is from Unit 5's
`BroadcastTransport` and Unit 5's `defaultBroadcastLimits`; this unit adds no new
limit, queue, or resource pool of its own.

## Performance

N/A beyond what's already fixed elsewhere. NFR-1.3's 3s/5s targets remain Unit 5's and
Unit 9's concern (already carried forward in Unit 5's own NFR Requirements, Q2); this
unit's dashboard computes duration/viewer-count synchronously from state already held
in memory, with no latency-sensitive path of its own.

## Reliability (NFR-4.1)

- **Q3 (A)**: every step within `goLive()`'s unwind (Rule 2) and `endBroadcast()`'s
  teardown (Rule 5) is wrapped individually — caught, logged via the existing `Logger`,
  then execution continues unconditionally to the next step. The terminal state
  transition (`BroadcastFailedState(reason)` for an unwind; `OfflineState` for a
  teardown) always happens as the last action, once every step has been *attempted*,
  regardless of whether any individual step actually succeeded. This guarantees the
  state machine can never get stuck in `StartingState`/`EndingState` because of a
  single failing teardown call — which would otherwise silently break both Rule 1's
  retry gate and Rule 9's sign-out guard (both treat those states as non-idle). The
  accepted cost is a possible resource leak (e.g. a transport that failed to stop
  cleanly) that is then only discoverable via the logged exception, never from
  app-visible state. Applies identically to both call sites — no special-casing between
  the `goLive()` unwind table and the `endBroadcast()` teardown sequence.

## Testability (NFR-7.3-equivalent for this unit)

- **Q1 (A)**: `BroadcastSessionNotifier` is tested entirely against hand-written fakes
  for every collaborator it calls — `FakeSignalingService` (reusing Unit 5's
  `test/helpers/fake_signaling_service.dart` interface), a new `FakeCaptioningStarter`,
  a fake `BroadcastTransport` with controllable `viewers`/ack-timeout behavior, and
  simple value-returning stubs for `BroadcastIdentityRepository`/`IceServerProvider`.
  No real Supabase stack, no real `flutter_webrtc`, no real-backend integration test —
  this unit's own responsibility is the *sequencing and state-transition* logic (Rules
  1–6), and every collaborator it calls already has its own test suite in its owning
  unit (Units 2–5). Re-testing a collaborator's internal correctness here would
  duplicate, not add, coverage.
- **Q2 (A)**: widget tests cover one test per approved Proto-11/Proto-12 state reachable
  via `ProviderScope` overrides — signed-out overlay; the three `validateSessionName`
  error categories plus the valid case; the Go Live progress spinner; each row of the
  F-6.4 banner matrix; the broadcast-full banner; the viewer list render; and the Rule 9
  sign-out-refusal snackbar. This is the existing Phase 1 widget-test pattern
  (`HomeScreen`'s own tests), with no golden-image tests — this project has none today,
  and goldens are brittle across Flutter/engine versions without an established
  re-approval workflow here. Coverage maps one-to-one onto S-17's own acceptance
  criteria.

## Security

SR-01–04 are unaffected — this unit introduces no new RLS policy, credential issuer,
or server-side logging infrastructure. This section adds the Security Baseline
compliance pass.

- **Q4 (A)**: no new logging infrastructure. Where a `Logger` call is useful (a
  `goLive()` failure's `BroadcastFailure` variant; Q3's unwind/teardown-step
  exceptions), it may log `broadcastId`, `sessionId`, the failure/exception type, and
  non-content state values only — never caption text, never an exception's full
  `toString()` without first confirming it can't embed a collaborator's
  request/response body. Pure restatement of the existing project-wide rule
  (`business-rules.md` Rule 10) against this unit's own log call sites.

### Security Baseline Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| SECURITY-01 (Encryption at rest/transit) | N/A | No new data store — this unit persists only `BroadcastSettings` via the existing `SharedPreferences` mechanism (Phase 1 pattern, unchanged), and reads/writes no new network-transiting data of its own. |
| SECURITY-02 (Access logging on intermediaries) | N/A | No new HTTP route, gateway, or network intermediary — this unit is Flutter-side orchestration only. |
| SECURITY-03 (Application-level logging) | Compliant (Q4) | No new logging infrastructure; existing `Logger` reused with the content/token exclusion restated for this unit's own call sites (Rule 10). |
| SECURITY-04 (HTTP security headers) | N/A | No HTML-serving endpoint — this unit ships Flutter screens, not a web server response path. |
| SECURITY-05 (Input validation) | Compliant | `BroadcastSettings.validateSessionName` (Rule 7) is the single validator, enforced both at the UI (live inline) and at `goLive()`'s pre-flight boundary — no invalid name can reach the state machine or `publishLive` through any call path. |
| SECURITY-06 (Least privilege) | N/A | No IAM policy, role, or database privilege defined by this unit. |
| SECURITY-07 (Network configuration) | N/A | No firewall, routing, or network topology change — consumes Units 3/3.1/4/5's existing signaling/TURN/transport paths unchanged. |
| SECURITY-08 (Application-level access control) | Compliant | Rule 9's sign-out guard is exactly this: `ZbAppShell` is the sole call path to `AuthNotifier.signOut()`, refusing outright (not merely disabling a button) while `BroadcasterSessionState` is non-idle — deny-by-default enforced at the one gate, server-side token validation remains Unit 2's unchanged responsibility. |
| SECURITY-09 (Hardening) | Compliant | `goLive()`/`endBroadcast()` failures surface only the fixed `BroadcastFailure` enum variant to the UI (Rule 2) — never a raw exception, stack trace, or collaborator-internal detail. |
| SECURITY-10 (Supply chain) | Compliant (Q5) | No new dependency anywhere in this unit — confirmed against the existing `zip_core`/`zip_broadcast` `pubspec.yaml`s. |
| SECURITY-11 (Secure design, rate limiting) | N/A | No new user-facing write surface this unit owns — `goLive()`/`endBroadcast()` are local orchestration calls, not public-facing API endpoints; rate limiting of the underlying signaling calls is Units 3/3.1's unchanged responsibility. |
| SECURITY-12 (Auth/credential management) | N/A | Consumes `authNotifierProvider`'s existing sign-in state (Unit 2) unchanged; manages no credentials itself. |
| SECURITY-13 (Data integrity) | N/A | No persisted table or row this unit creates or mutates — `BroadcastSettings`'s `SharedPreferences` keys are local-only, non-critical UI preferences, not audited data. |
| SECURITY-14 (Alerting/monitoring) | N/A | Same standing project-wide Backlog item as every prior unit (no alerting infrastructure exists yet) — this unit introduces no new security-relevant event that would need one beyond what's already deferred. |
| SECURITY-15 (Exception handling/fail-safe defaults) | Compliant (Q3) | Every unwind/teardown step is individually caught and logged; the terminal state transition always completes regardless of individual step outcomes, so the notifier never fails open into a stuck non-idle state. `goLive()`'s own pre-`LiveState` failure path denies broadcasting by construction (no path reaches `LiveState` without every required step completing). |

## Tech Stack

- **Q5 (A)**: no new dependency. See `tech-stack-decisions.md`.

## PBT

- **Q6 (A)**: `glados` (this project's established PBT framework since Unit 2), applied
  to two properties: (1) a model-based/stateful suite for `BroadcasterSessionState`
  (PBT-06) — generated `goLive`/`endBroadcast` call sequences against the Q1 fakes,
  asserting the state machine only ever makes the transitions in
  `domain-entities.md`'s diagram, and that Rule 5's idempotence holds (`endBroadcast()`
  called twice in a row from `LiveState` ends in the same state as calling it once);
  (2) an invariant suite for `validateSessionName` (PBT-03) — for any generated string,
  exactly zero or one error category is returned, never more than one, with the three
  named example cases (empty/too-long/control-char) kept as explicit example-based
  tests per PBT-10. No new framework.

### PBT Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| PBT-01 (Property identification) | Compliant | Two properties identified: `BroadcasterSessionState`'s transition/idempotence invariant (already flagged as a "PBT-06 reference model" in Functional Design itself) and `validateSessionName`'s mutual-exclusivity invariant (Q6). |
| PBT-02 (Round-trip) | N/A | No serialization, encoding, or parsing pair exists in this unit's own domain. |
| PBT-03 (Invariant) | Compliant (planned) | `validateSessionName`'s "exactly zero or one category, never more than one" invariant, checked against generated strings including boundary cases (empty, exactly-at-length-limit, embedded control characters, Unicode). |
| PBT-04 (Idempotence) | Compliant (planned) | `endBroadcast()`'s idempotence (Rule 5) — calling it twice in a row from `LiveState` produces the same end state as once — is asserted as part of the Q6 stateful suite's command sequences. |
| PBT-05 (Oracle) | N/A | No optimized-vs-brute-force or legacy-vs-refactored algorithm pair exists in this unit — the state machine's own specification (`domain-entities.md`) serves as the reference model for PBT-06, not a separate oracle comparison. |
| PBT-06 (Stateful) | Compliant (planned) | `BroadcasterSessionState`'s model-based suite (Q6) — generated command sequences of `goLive`/`endBroadcast` checked against the fixed state diagram, including the no-op cases (Rule 1's concurrent-call rejection, Rule 5's idempotent repeat). |
| PBT-07 (Generator quality) | Compliant (planned) | Session-name generator includes deliberately adversarial inputs (empty/whitespace-only, exactly-at-boundary length, embedded control characters, Unicode) rather than only ASCII happy-path strings — the three error categories exist specifically to catch these. |
| PBT-08 (Shrinking/reproducibility) | Compliant | `glados` provides shrinking/reproducibility by default; no new framework, no override of its shrinking mechanism. |
| PBT-09 (Framework selection) | Compliant (Q6) | `glados` — no new framework needed for this unit's properties. |
| PBT-10 (Complementary testing) | Compliant (planned) | The three named `validateSessionName` example cases and the Q2 widget-test suite's concrete states remain explicit example-based tests alongside the generated-input PBT suites — PBT is not the sole coverage for any business-critical path in this unit. |

## Usability

- **Q7 (A)**: accessibility semantics are deferred for this unit. It ships with
  Flutter's default widget semantics (a `Text` widget's content is read by screen
  readers by default) with no explicit `Semantics`/live-region wrapping added. No prior
  unit has established an accessibility-testing convention to extend, and this project
  has consistently deferred other cross-cutting, not-yet-adopted concerns (crash
  reporting, operational alerting — both in `aidlc-state.md`'s Backlog) as project-wide
  decisions rather than deciding them narrowly under one unit. **New Backlog item**:
  revisit accessibility semantics for the captions-inactive/broadcast-full banners and
  the Duration stat card if/when a project-wide accessibility pass is scoped.

## No Blocking Findings

All Security Baseline and PBT rule verdicts above are Compliant, Compliant (planned),
or N/A — no blocking finding under either extension.

## Notes for Code Generation

- Q3's catch-and-continue applies identically to `goLive()`'s unwind table (Rule 2) and
  `endBroadcast()`'s teardown sequence (Rule 5) — implement as one shared private
  helper the notifier calls from both paths, not duplicated inline logic.
- The Q1 fake collaborators (`FakeSignalingService`, `FakeCaptioningStarter`, the fake
  `BroadcastTransport`) are new test helpers for this unit; `FakeSignalingService`
  should extend/reuse Unit 5's existing one if its interface already covers what this
  unit needs, rather than writing a second, divergent fake for the same interface.
- The new Backlog item from Q7 (accessibility semantics) must be added to
  `aidlc-state.md`'s Backlog section at stage approval, per this project's existing
  pattern for every other deferred cross-cutting concern.
