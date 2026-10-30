# NFR Requirements — Zip Captions Viewer (Unit 7)

**Prior stage**: Functional Design, approved 2026-10-18.
**Answers recorded**: 2026-10-18 under the run-configuration pre-approval
(`approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-18) — subject to morning review`).

## Scalability

N/A. No new capacity, concurrency, queue, or resource pool. A viewer session holds at
most one transport, one receiver, one `CaptionBus`, one registry, one target and one
status-watch subscription (`domain-entities.md` invariant 2); `maxViewers`,
`presenceTimeout` and `reconnectWindow` are consumed from `defaultBroadcastLimits`
unchanged, and this unit adds no limit of its own. A viewer is one client against a
broadcaster's `maxViewers=50` cap, which is Unit 5's and Unit 9's concern.

## Performance

- **Q-carried:** NFR-1.3's join-to-first-caption and reconnection targets remain Spike
  2.1 TBDs and are carried forward as documentation, not as testable NFRs — the same
  treatment Unit 5 applied (this unit's suite is fake-backed; a timing assertion against
  fakes would measure the test clock, not the product).
- The unit's own latency-sensitive value is the give-up window:
  `BroadcastLimits.reconnectWindow` (120s interim), owned by one `Timer` per
  interruption (FD Rule 3). It is a fixed constant, not a measured target.
- The F-7.3 caption path inherits Phase 1's 50ms debounce in `OnScreenCaptionTarget`
  unchanged; this unit adds no buffering, batching, or transformation on top.
- `BroadcastLink.parseInput` is a pure, synchronous string operation performed before
  any network action (Rule 2); no NFR is needed beyond "it stays total and never
  throws", which is a testable property (PBT below).

## Reliability (NFR-4.1 — never crash)

- **Q3 (A)**: one shared private teardown helper on the session's resource holder —
  `_ViewerResources.disposeAll(log)` — attempts every step in order, each individually
  caught and logged (runtime type only, per Q5), never throws, and the terminal state
  assignment always happens last and unconditionally. It is the single implementation
  used by `leave()` (F-7.7), by every terminal transition (`Ended`, `Full`,
  `CannotConnect`, the different-broadcast implicit leave), and by F-7.4's window-expiry
  sequence. Step order is exactly F-7.7's: cancel window `Timer` → cancel status-watch
  subscription and `close()` the channel → `transport.disconnect()` →
  `receiver.dispose()` → target `dispose()` → registry `dispose()` → bus `dispose()` →
  null the holder.
  - Because steps have mixed shape (`RemoteCaptionReceiver.dispose` and
    `CaptionBus.dispose` are synchronous; `disconnect()`/`close()` are async), the helper
    is `async` and `await`s each step inside its own `try`. A `remove()` that disposes the
    target internally is still treated as the one registry step (no double-dispose path).
  - Invariant 1 is restated as a **directly asserted** test property: the holder is
    non-null in every state except `IdleState` and `InvalidInputState`.
- **F-7.4 step 4's `await transport.disconnect()`** (the "last status live" outcome) is
  inside the same helper's discipline: a throw from `disconnect()` must not prevent
  `CannotConnect(IceFailed)` from being set.
- **F-7.2 step 5's `connect()` throw** maps to `CannotConnect(IceFailed)`; the
  `iceServersForBroadcast()` failure maps to the same. Both are reachable (`channel.open()`,
  `peerConnectionFactory.create()`, `submitJoinRequest()` are all awaited inside
  `_attemptConnect`), so both get an example test, not just a claim.
- **No window-expiry race:** the `Timer` is cancelled on *every* exit from
  `ReconnectingState` (connected, offline status event, terminal, `leave()`), so expiry
  cannot fire into a state that has moved on; asserted in the stateful suite.

## Testability (NFR-7.3-equivalent)

- **Q1 (A)**: `ViewerSessionNotifier` is tested against hand-written fakes for every
  collaborator, added to the existing `test/helpers/fake_broadcast_session_collaborators.dart`
  (not a parallel file): `FakeBroadcastResolver`, `FakeViewerTransport`, and a
  `FakeSignalingService`-shaped adapter returning the existing `FakeStatusChannel` from
  `statusChannel(id)`. `RemoteCaptionReceiver` stays real (thin, already tested in Unit
  5), and the viewer-scoped `CaptionBus`/registry/`OnScreenCaptionTarget` stay real
  (in-memory). Injected via `viewerTransportFactoryProvider` plus
  `broadcastResolverProvider`/`signalingServiceProvider`/`iceServerProviderProvider`
  overrides. No real Supabase, no `flutter_webrtc`, no device.
- **Q2 (A)**: `zip_captions` widget tests use a hand-written
  `FakeViewerSessionNotifier extends ViewerSessionNotifier` (fixed `build()`, recorded
  `join`/`leave`) through `viewerSessionProvider.overrideWith(...)`, mounted in a real
  `MaterialApp.router` with a minimal route table. One test per Proto-14/Proto-15 state,
  both cannot-connect copy variants, `InvalidInput`, the paused/inactive notice
  appearing and clearing, the confirm dialog in active vs terminal states, the back
  path, "Try again" presence by reason, and the join screen's invalid path asserting
  **no navigation and no `join()` call**. No goldens.
- `prefix`-level note: `zip_captions` has no `mocktail`/`fake_async` dev dependency and
  needs neither (hand-written subclass + `pumpAndSettle`); no test-only dependency is
  added.

## Security

- **Q5 (A)**: no new logging infrastructure. Loggable: state names, `BroadcastResolution`/
  `ConnectFailure` variant names, `BroadcastId`, `sessionId`, `ConnectionType`, caught
  exception `runtimeType`. Forbidden: caption/transcript text, the raw join input (even
  on parse failure), signaling payloads, TURN credentials, exception messages or stack
  traces sourced from network paths. FD Rule 8 restated at this unit's call sites.

### Security Baseline Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| SECURITY-01 (Encryption at rest/transit) | N/A | No new store. The viewer persists nothing — `OnScreenCaptionTarget` is constructed with `repository: null` **by design** (remote captions never persisted; the anonymous viewer has no device-auth transcript path). Network transit is Units 3/4/5's existing TLS/DTLS paths. |
| SECURITY-02 (Access logging on intermediaries) | N/A | No new route, gateway, or intermediary. The status channel and per-viewer signaling channel are Unit 3/3.1 infrastructure, consumed unchanged. |
| SECURITY-03 (Application-level logging) | Compliant (Q5) | Existing `logging` infrastructure only; caption/input exclusion restated for the viewer's call sites (Rule 8). |
| SECURITY-04 (HTTP security headers) | N/A this unit | No HTML-serving endpoint. The web route's headers are among the two S-19 web criteria deferred to Phase 5 and recorded in `aidlc-state.md`; re-opens with the web scaffold, not here. |
| SECURITY-05 (Input validation) | Compliant | `BroadcastLink.parseInput` is the single untrusted-input boundary (FD Rule 2): the join screen validates locally before navigating and the notifier re-validates before any service is touched, so an invalid input makes no network request. `InvalidInputState` carries no data (the rejected string is never stored or echoed). The deep-link path parameter goes through the same validator. |
| SECURITY-06 (Least privilege) | N/A | No IAM/role/privilege defined by this unit; the viewer runs as `anon` on Units 3/3.1/4's existing policies. |
| SECURITY-07 (Network configuration) | N/A | No firewall/routing change; ICE configuration comes from the existing `IceServerProvider` path (Unit 4). |
| SECURITY-08 (Application-level access control) | Compliant (unchanged) | No sign-in anywhere (FR-7.6, S-19) — the viewer never reads `authNotifierProvider`. Authorization remains server-side (RLS + admission), and a rejected join surfaces as `CannotConnect(SignalingRejected)` / `FullState`, never as a bypass. The client never treats its own state as an authorization decision. |
| SECURITY-09 (Hardening) | Compliant | Every failure renders a fixed `ConnectFailure` variant with the Rule 5 copy; no exception message, stack trace, or collaborator detail reaches the UI. |
| SECURITY-10 (Supply chain) | Compliant (Q6) | No new dependency. No lockfile change. |
| SECURITY-11 (Secure design, rate limiting) | Compliant | Rule 6 forbids any auto-retry on `CannotConnect`/`Full` (a retry loop against a rate-limited or unreachable endpoint is abuse); Rule 14 forbids any notifier-owned retry engine. The only repeated attempts originate with a user action or the status watch. `RateLimited` renders its own copy with a manual retry. |
| SECURITY-12 (Auth/credential management) | N/A | Manages no credential. TURN credentials are fetched per session by Unit 4's provider and never logged (Q5). |
| SECURITY-13 (Data integrity) | N/A | No persisted table, row, or local record created or mutated; `_ViewerResources` is in-memory for the session's lifetime. |
| SECURITY-14 (Alerting/monitoring) | N/A | Same standing project-wide Backlog item as every prior unit (no alerting infrastructure exists yet); this unit introduces no new security-relevant event beyond what is already deferred. |
| SECURITY-15 (Exception handling/fail-safe defaults) | Compliant (Q3) | Every teardown/expiry step is caught and logged individually; the terminal transition always completes, so the session never fails open into a stuck non-idle state or a leaked transport. `join()` is deny-by-default on invalid input. A `connect()` throw is mapped to a user-facing failure, not propagated. |

## PBT

### PBT-09 decision

**The framework is the in-tree shim `test/helpers/pbt.dart`.** There is no `glados`
dependency anywhere in the monorepo (verified against every `pubspec.yaml`), and Q6
forbids adding one. The shim provides `Generator<T>`, the `any` generators, and
`Glados<T>(generator).test(description, body)` — 100 trials with `Random(seed)` for
`seed` in `0..99`, async bodies supported. Its limits are recorded rather than hidden:
seeds are deterministic (a failure is reproducible by seed index) and there is **no
automatic shrinking** (PBT-08's shrinking clause is therefore met by "reproducible by
seed + hand-reduced counterexample pinned as an example test per PBT-10", not by
framework shrinking). This is recorded as the project-wide PBT framework decision for
Dart, superseding the earlier `glados` references in Units 2–6's documents.

### Property scope

1. **PBT-02 round-trip — `BroadcastLink`**: for every generated `BroadcastId` and every
   generated URL form (bare ID, `host/b/{id}`, full URL under the configured
   `broadcastBaseUrl`), `parseInput(toUrl(id)) == id` and `parseInput(id.value) == id`;
   for a generated invalid string, `parseInput` returns `null` and never throws.
   Extends the existing `test/pbt/broadcast_link_test.dart`; after Q9 the URL generator
   must build from the constant, so a base-URL change cannot silently break parsing.
2. **PBT-06 stateful — `ViewerSessionNotifier`**: generated command sequences (`join`
   valid / invalid / different, `Connecting`/`Connected`/`Interrupted`/`Failed(f)`
   status, activity, `ended`, status-channel `live`/`offline`, window expiry, `leave()`)
   against the Q1 fakes with `fakeAsync` clocks, checked after **every** command against
   `business-logic-model.md`'s transition table — including invariants 1–5 (holder
   presence; at most one of each resource; status watch open iff confirmed and
   non-terminal/ended/full/cannot-connect; no caption content in state; complete
   teardown on exit). Sequences of varying length, including empty.
3. **PBT-04 idempotence — `leave()`**: `leave()` twice from any state equals once
   (asserted inside (2) and once directly, mirroring Unit 6's `endBroadcast()` row).
4. **Invariant — `ReconnectPolicy.nextDelay`**: remaining = `window - elapsed` while
   positive, `null` at/past the window, independent of `attempt`.
5. **Rule 5 mapping** stays example-based: one table-driven test pins all seven
   `ConnectFailure` → (state, copy, retry) triples, plus the three window-expiry
   outcomes. Not a generated property (the mapping is a finite table).

### PBT Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| PBT-01 (Property identification) | Compliant | FD `business-logic-model.md` already carries "Testable Properties": PBT-02, PBT-06, plus the example-based Rule 5 table. |
| PBT-02 (Round-trip) | Compliant (planned) | `BroadcastLink.parseInput(toUrl(id)) == id` across generated IDs and URL forms, including the configured-base form. |
| PBT-03 (Invariant) | Compliant (planned) | `ReconnectPolicy.nextDelay`'s window invariant; `parseInput` totality; the stateful suite's invariants 1–5. |
| PBT-04 (Idempotence) | Compliant (planned) | `leave()` from any state, twice, equals once. |
| PBT-05 (Oracle) | N/A | The reference model **is** the specification (PBT-06), not a second implementation; there is no optimized-vs-brute-force pair in this unit. |
| PBT-06 (Stateful) | Compliant (planned) | The 10-state `ViewerSessionState` machine against `business-logic-model.md`'s transition table and invariants, driven by generated commands. |
| PBT-07 (Generator quality) | Compliant (planned) | Domain generators: `BroadcastId` (Crockford Base32, 6 chars — existing `arbitraryBroadcastId`), URL forms from the configured base, `ConnectFailure`/`BroadcastResolution` variant pickers, and adversarial invalid inputs (wrong length, out-of-alphabet, empty, whitespace, garbage schemes, pasted prose). Not raw strings for domain-typed parameters. |
| PBT-08 (Shrinking/reproducibility) | Compliant, with a recorded limit | Seeds are fixed (`0..99`) so every run is deterministic and every failure is reproducible by seed; the shim has **no shrinking**, so PBT-10's "pin the counterexample" step is the documented reduction path. CI runs the suite (existing `flutter test`), so PBT is not excluded. |
| PBT-09 (Framework selection) | Compliant (documented above) | In-tree shim; no framework package exists or is added. Recorded as the project's Dart PBT decision. |
| PBT-10 (Complementary testing) | Compliant (planned) | Rule 5's table, the eight widget states, the three expiry outcomes and the three `connect()` failure modes all remain explicit example tests; PBT is not the sole coverage for any business-critical path. |

## Usability / Accessibility

- **Q8 (A)**: every state change announces the new status text to assistive tech, and
  the current state's status text is always readable through a semantic container.
  - Testable form: (1) the status text is findable via
    `find.bySemanticsLabel(...)` under `tester.ensureSemantics()`; (2) a state
    transition invokes the single announcement seam with the new state's text.
  - Announcement seam: one `Notifier`/provider exposing
    `void Function(String message)`; default implementation calls
    `SemanticsService.announce(message, TextDirection.ltr)` (or the ambient direction);
    widget tests override it with a recording fake. One rule: announce whenever the
    rendered status text changes (state change, including the paused/inactive notice and
    the reconnect notice), never on unrelated rebuilds.
  - Icon + text, never color alone, per Proto-15 (NFR-5.2), unchanged.
- Copy source: all viewer strings live in `packages/zip_captions/l10n/arb/app_en.arb`
  and are resolved through a single `ZcStrings`-style class; no string literals in the
  viewer widgets. `zip_captions` today has no localization mechanism, so this unit adds
  the **minimum** needed for that (mechanism chosen at Code Generation — `flutter
  gen-l10n` wiring or a plain ARB-backed lookup class), scoped to the viewer's copy.
  A project-wide localization rollout for the existing screens is a Backlog item, not
  this unit's scope.
- **New Backlog item**: project-wide localization mechanism for `zip_captions`'s
  pre-existing screens (they hold hardcoded English strings today) — revisit with the
  broader accessibility/localization pass, separate from Unit 7.

## No Blocking Findings

Every Security Baseline verdict is Compliant, Compliant (unchanged), N/A, or N/A-this-unit
(SECURITY-04, deferred with the web work); every PBT verdict is Compliant/planned or N/A.
No blocking finding under either extension.

## Notes for Code Generation

- Q3's helper is one method on the private holder, not a free function in the notifier —
  it is the only place `_resources` is nulled, so the invariant has one writer.
- Q1's fakes go into `fake_broadcast_session_collaborators.dart`; renaming the file to
  reflect its breadth is acceptable only if every existing importer is updated in the
  same commit (prefer leaving the name alone this unit).
- Q4's `ReconnectPolicy` test is small and example-based plus one invariant row; do not
  build a separate PBT file for it if the existing pattern file can host it.
- Q8's announcement seam must be provided at the app/route level (not constructed inside
  the screen), so widget tests can override it without touching the screen's internals.
- Q9 is scheduled work with explicit steps: add the constants file, change `toUrl`,
  remove `baseUrl`, update the two test files and the broadcaster's URL row behaviour
  (no behavioural change under the default), and add a parse test for a
  non-default base.