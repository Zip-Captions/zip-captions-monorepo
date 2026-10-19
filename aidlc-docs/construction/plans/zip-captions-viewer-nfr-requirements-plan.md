# NFR Requirements Plan: Zip Captions Viewer (Unit 7)

**Prior stage**: Functional Design, approved 2026-10-18
**Run mode**: unattended (`.agent/overnight-pipeline.md` adaptation A2). Every
question below is answered here with the recommended option and recorded in
`audit.md` as `approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-18) — subject to morning review`.

## Context

Functional Design fixed the orchestration (`ViewerSessionNotifier.join()`/`leave()`,
the 10-variant `ViewerSessionState`, the Rule 3 transport-retries/notifier-gives-up
split, Rule 5's exhaustive failure mapping, Rule 14's no-notifier-retry rule) and the
two `zip_captions` screens plus their routes. Like Unit 6, this unit adds no
infrastructure, no persisted data, no server-side surface and no dependency: it is
orchestration over already-shipped `zip_core` services (Units 2/3/3.1/5) plus two
screens. The open NFR questions are therefore concentrated in **testability** (a
notifier whose every collaborator is a tested shipped component, plus a state machine
with a 10-state reference model), **reliability** (exception-safety of the teardown
path and of the window-expiry sequence, both of which can be reached by real failures),
**accessibility** (S-19 makes screen-reader announcement an acceptance criterion, which
raises the project's first accessibility convention), and confirmations carried forward
from established patterns (logging, dependency footprint, PBT framework).

**Scalability**: N/A. No new capacity, queue, or resource pool. The viewer holds one
transport, one bus, one registry, one target and at most one status-watch subscription
(domain-entities invariant 2). `maxViewers`/`presenceTimeout`/`reconnectWindow` are
consumed as-is from `defaultBroadcastLimits`; this unit defines no new limit.

**Performance**: largely carried forward. NFR-1.3's join-to-first-caption and
reconnection targets remain Spike 2.1 TBDs (the same treatment Unit 5 gave them:
documented aspirable targets, not testable NFRs in a fake-backed suite). The one
latency value this unit *does* own is the reconnect-window policy, and that is a fixed
120s constant, not a measured target.

**Verified against source** (2026-10-18, before writing questions):

- `BroadcastLink.baseUrl` is still a hardcoded `'https://zipcaptions.app/b/'`
  (`zip_core/lib/src/models/broadcast_link.dart`); `parseInput` is host-agnostic and
  never throws. Callers of `toUrl` are `BroadcastSessionNotifier` (the broadcaster's
  `LiveBroadcast.url`), `zip_broadcast`'s setup screen, and two test files — so the
  env-driven change touches **zip_broadcast** behaviour too (`toUrl`), which makes it
  a cross-package change, not a viewer-only one.
- `ConnectFailure` (`zip_core/lib/src/models/connect_failure.dart`) is the shipped
  four-variant sealed class with hand-written `==`/`hashCode`; no `CannotConnect`
  variant exists yet.
- `BroadcastResolver.resolve` is documented total ("Never throws"); `IceServerProvider.iceServersFor`
  is documented to propagate failures uncaught. Both match the FD's F-7.2 mapping.
- `ViewerTransport.connect()` awaits `channel.open()`, `peerConnectionFactory.create()`
  and `submitJoinRequest()` inside `_attemptConnect`, so the FD's "a raw throw from
  `connect()` maps to `CannotConnect(IceFailed)`" has real, reachable failure modes.
- `RemoteCaptionReceiver.dispose()` / `CaptionBus.dispose()` are synchronous and
  internally `unawaited`; `CaptionOutputTargetRegistry.remove()` disposes the target and
  logs `runtimeType` only. So teardown steps have mixed sync/async shapes — a detail
  that decides how the shared teardown helper is written (Q3).
- `OnScreenCaptionTarget` takes an optional `TranscriptRepository?` and every persist
  path is gated on it; `repository: null` is a supported construction, not a workaround.
- There is **no `glados`** in any `pubspec.yaml`; `test/helpers/pbt.dart` is the
  in-tree shim (`Generator<T>`, `any`, `Glados<T>(gen).test(desc, body)` with 100
  seeded trials, async bodies supported). `fake_async: ^1.3.2` and `mocktail: ^1.0.4`
  are `zip_core` dev dependencies; `zip_captions` dev dependencies are
  `flutter_test`, `build_runner`, `drift`, `riverpod_generator`, `very_good_analysis`
  — no `mocktail`, no `fake_async`.
- `zip_captions` has **no `flutter_localizations`**, no generated `l10n/` Dart, no
  `generate: true`, and no `l10n.yaml`; its only ARB file is `l10n/arb/app_en.arb`
  and `ZipCaptionsApp`/the existing screens hold hardcoded strings. The FD says the
  viewer's copy is externalized "like every other string"; today there is no mechanism
  on this side. → Q8.
- `zip_captions` already depends on `flutter_riverpod`, `go_router`, `supabase_flutter`
  and `zip_core`; nothing the viewer screens need is missing.

## Planned Steps

- [x] Testability: collaborator fake strategy for `ViewerSessionNotifier` (Q1)
- [x] Testability: widget-test scope and seam for the two screens (Q2)
- [x] Reliability: teardown and window-expiry exception safety (Q3)
- [x] Reliability/Usability: the reconnect-window `Timer`'s testability (Q4)
- [x] Security: logging constraints for the viewer's new surfaces (Q5)
- [x] Tech stack: dependency footprint (Q6)
- [x] PBT: framework decision and property scope (Q7)
- [x] Accessibility: screen-reader announcement, the project's first convention (Q8)
- [x] Tech stack: where the env-driven `broadcastBaseUrl` lands (Q9)
- [x] Generate `nfr-requirements.md`, `tech-stack-decisions.md`, `handoff-summary.md`

## Testability

### Q1: How is `ViewerSessionNotifier` tested — what gets faked, and where do the fakes live?

The notifier calls six collaborators: `BroadcastResolver` (shipped, total),
`SignalingService` (needs only `statusChannel(id)`), `IceServerProvider` (one method),
`ViewerTransport` (via the new `viewerTransportFactoryProvider`), `RemoteCaptionReceiver`
(a concrete class over a real `CaptionBus`), and the viewer-scoped
`CaptionBus`/`CaptionOutputTargetRegistry`/`OnScreenCaptionTarget` trio. Unit 6's
precedent: fakes for every collaborator, reuse of already-written fakes where the
interface matches.

A) Hand-written fakes for every collaborator, extending the existing shared helper file
   rather than starting a parallel one: `fake_broadcast_session_collaborators.dart`
   already contains `FakeStatusChannel`, `FakeBroadcastSignalingService`,
   `FakeBroadcastTransport`, `FakeIceServerProvider`, `FakeBroadcastIdentityRepository`;
   `fake_signaling_service.dart` contains the per-viewer channel machinery. Add
   `FakeBroadcastResolver` (a scripted resolution), a `FakeViewerTransport` (push
   `status`/`messages` events, record `connect`/`restart`/`disconnect` calls), and a
   `FakeSignalingService`-shaped adapter that returns that `FakeStatusChannel` from
   `statusChannel(id)` and throws nothing else. `RemoteCaptionReceiver` is **not**
   faked: it is a thin pass-through (decode → bus/activity/ended) whose own behaviour is
   already tested in Unit 5, and using the real one through the fake transport is what
   makes the F-7.3 caption-flow assertions meaningful. The `CaptionBus`/registry/target
   trio is likewise real (in-memory, no I/O). No real Supabase stack, no real
   `flutter_webrtc`, no device. **(recommended — matches Unit 6's "test the seam, not
   the already-tested dependency" pattern; extending the existing helper file avoids the
   two-divergent-fakes problem Unit 6's own NFR Requirements explicitly warned about)**

B) Hand-written fakes in a new `test/helpers/fake_viewer_session_collaborators.dart`
   file, leaving the Unit 6 helper untouched
C) Other (write in)

[Answer]: A

### Q2: What is the widget-test seam for `JoinBroadcastScreen` and `BroadcastViewerScreen`, and how deep is the coverage?

`frontend-components.md` names the surface ("one widget test per approved state") and
the seam ("against a fake `ViewerSessionNotifier`"). It does not say whether the fake
is a hand-written `ViewerSessionNotifier` subclass (Unit 6's `FakeBroadcastSessionNotifier`
pattern) or a fake state provider, nor whether the fixture drives the real router.

A) A hand-written `FakeViewerSessionNotifier extends ViewerSessionNotifier` that overrides
   `build()` to return a fixed `ViewerSessionState` and records `join`/`leave` calls —
   the exact `FakeBroadcastSessionNotifier`/`FakeRecordingStateNotifier` precedent —
   injected through `viewerSessionProvider.overrideWith(...)`. Coverage: Proto-14
   default + invalid-input (asserting **no navigation** and **no `join()` call** on
   invalid); Proto-15's eight states plus both cannot-connect copy variants and
   `InvalidInput`; the paused/inactive inline notice appearing and clearing in place;
   the confirm dialog in the four active states and its absence in the terminal ones;
   the back path; "Try again" present for every reason except `NotFound`; a real
   `MaterialApp.router` with a minimal route table (the `recording_screen_test.dart`
   precedent) so navigation assertions are real. No golden tests (this project has
   none). **(recommended — one test per acceptance-criterion-bearing state, the Unit 6
   bar, with the deep-link/form navigation actually exercised rather than assumed)**

B) Provider-state only: override `viewerSessionProvider` with a `Notifier` returning the
   state, skipping the notifier subclass
C) Other (write in)

[Answer]: A

## Reliability

### Q3: What happens when a teardown step, or the window-expiry sequence, itself throws?

`leave()` (F-7.7) runs eight ordered steps of mixed shape (cancel `Timer`; cancel the
status-watch subscription and `close()` the channel; `transport.disconnect()`;
`receiver.dispose()`; target `dispose()`; registry `dispose()`; bus `dispose()`; null
`_resources`; state → `Idle`). `transport.disconnect()` is async and can fail; closing a
Realtime channel can fail. F-7.4 step 4's expiry path additionally awaits
`transport.disconnect()` before setting `CannotConnect(IceFailed)`. A naive
implementation can strand the notifier in `ReconnectingState` (never reachable back to
`Idle` by the Rule 1 idempotent `leave()` if the first call half-failed) or leave
`_ViewerResources` non-null in an idle state, breaking invariant 1 and leaking a transport.

A) One shared private teardown helper (an `_ViewerResources.disposeAll(Logger)`-shaped
   method, mirroring `SessionResources.disposeAll`) that attempts every step in order,
   catching and logging each individually (runtime type only — Q5), and never throwing;
   the terminal transition (`IdleState`, or `CannotConnect(IceFailed)` at window
   expiry) always happens last and unconditionally. Applied identically by `leave()`,
   by the terminal-state transitions (`Ended`, `Full`, `CannotConnect`, the
   different-broadcast implicit leave), and by F-7.4's expiry sequence — one
   implementation, not four inline copies. **(recommended — Unit 6 NFR Requirements Q3's
   exact decision, which this project has already applied once to a same-shaped holder;
   a stranded `Reconnecting`/leaked transport is strictly worse than a logged leak)**

B) Let a teardown exception propagate (same rejected option as Unit 6 Q3)
C) Other (write in)

[Answer]: A

### Q4: How is the reconnect-window `Timer` made testable, and does the notifier take a clock?

The FD fixes the mechanism ("one plain `Timer` per interruption, tested with
`fakeAsync()`") but not the seam for the *time source*. Two adjacent questions: whether
the window's own "elapsed" bookkeeping needs an injectable clock (Unit 5's
`ViewerAdmission` uses an optional `DateTime Function()? now`), and whether
`ReconnectPolicy.nextDelay` — whose `elapsed` argument the FD says is not consulted —
gets its own test.

A) No new clock seam. The window is a single `Timer(reconnectWindow)` with no elapsed
   arithmetic in the notifier (`ReconnectPolicy` owns the arithmetic and is a pure
   function tested directly); tests drive it with `fakeAsync()`/`tester.pump(Duration)`,
   the `supabase_auth_service.dart` precedent the FD cites. `ReconnectPolicy` gets a
   small example-based unit suite (positive remaining, exactly-at-window → `null`,
   past-window → `null`, and `attempt` not affecting the result) plus an invariant PBT
   row (see Q7). **(recommended — the only time source is the `Timer` itself, so a clock
   seam would add a parameter with exactly one implementation and no test that a
   `fakeAsync()` clock cannot already express)**

B) Add the optional `DateTime Function()? now` seam to the notifier too, for symmetry
   with `ViewerAdmission`
C) Other (write in)

[Answer]: A

## Security

### Q5: Logging constraints for the viewer's new log call sites?

The notifier logs state transitions, the give-up decision, and teardown failures. The
join input is user-supplied text that may be a URL containing arbitrary content, and
`InvalidInputState` deliberately carries no data.

A) No new logging infrastructure. `Logger('zip_core.ViewerSessionNotifier')` (and one for
   each new class that needs it) may log: state names, `ConnectFailure`/`BroadcastResolution`
   variant names, `BroadcastId` values, `sessionId`, `ConnectionType`, and the
   `runtimeType` of a caught exception. It must **not** log: caption text, the raw join
   input (not even on parse failure — log "invalid input" plus the input's length only if
   a value is genuinely needed for diagnosis), signaling payloads, TURN credentials, or
   an exception's full `toString()`/stack trace from a network path. This is the existing
   project rule (FD Rule 8) restated at the call sites it will actually be used.
   **(recommended — no new mechanism, consistent with every prior unit's identical
   confirmation)**

B) Other (write in)

[Answer]: A

## Tech Stack

### Q6: Does this unit introduce any new dependency?

The notifier, the two screens, the three additive `ConnectFailure` variants, the
`viewerTransportFactoryProvider` and the env-driven `broadcastBaseUrl` all build on
`flutter`, `flutter_riverpod`/`riverpod_annotation`, `freezed`, `go_router`, `logging`,
`supabase_flutter` and `zip_core` — every one already declared in `zip_captions` or
`zip_core`.

A) No new dependency. Q8's accessibility work uses Flutter's built-in
   `SemanticsService.announce`/`Semantics` — no package. Q1/Q2's fakes are plain Dart
   classes; the `zip_core` tests get `mocktail`/`fake_async` for free (already dev
   dependencies), and the `zip_captions` widget tests need neither (a hand-written
   notifier subclass plus `pumpAndSettle`). Q8's copy resolution (see Q8) is the only
   item that could plausibly need something, and it does not: Flutter's own
   `flutter_localizations`/`intl` is an SDK package, not a pub dependency, and is
   discussed as a Q8 mechanism choice rather than a dependency. **(recommended)**

B) Other (write in)

[Answer]: A

## PBT

### Q7: What is the PBT framework decision, and what is the property scope?

PBT-09 requires a documented framework selection. The FD's handoff carries the reality
check: there is no `glados`; `test/helpers/pbt.dart` is the in-tree shim. Properties the
FD identified: PBT-02 (URL/ID round-trip through `BroadcastLink.parseInput`), PBT-06
(stateful `ViewerSessionState` against the reference model), and Rule 5's exhaustive
mapping (example-based table `test`), with PBT-04 (`leave()` idempotence) riding on the
stateful model.

A) **PBT-09 decision: the in-tree shim is the framework.** Record `Glados<T>`/`Generator<T>`/
   `any` from `test/helpers/pbt.dart` as this unit's (and the project's, retroactively)
   PBT framework, with its known limits documented honestly: fixed seed range `0..99`
   (deterministic, so a failure is reproducible by seed number without a printed seed),
   no automatic shrinking (a failing trial reports the seed; the minimal case is reduced
   by hand and pinned as an example test per PBT-10). Property scope: (1) PBT-02
   round-trip for every generated `BroadcastId` × {bare ID, `host/b/{id}`, full URL under
   a generated base} and the invalid-input `null` property — extending the existing
   `test/pbt/broadcast_link_test.dart`, including URLs built from the *configured*
   `broadcastBaseUrl` so the Q9 change cannot silently break parsing; (2) PBT-06 the
   stateful suite, generated command sequences over the Q1 fakes and `fakeAsync` clocks,
   asserting the transition table and invariants 1-5 after **every** command, sequences
   of varying length including the empty sequence; (3) PBT-04 `leave()` idempotence
   asserted inside (2)'s sequences and once directly; (4) an invariant row for
   `ReconnectPolicy.nextDelay` (Q4). Example-based tests keep Rule 5's seven-row table,
   the eight state-rendering rows, and the three window-expiry outcomes explicit per
   PBT-10. **(recommended — records reality rather than re-selecting an absent package;
   there is no approval to add one and Q6 forbids it)**

B) Other (write in)

[Answer]: A

## Usability / Accessibility

### Q8: S-19 makes screen-reader announcement an acceptance criterion. What is the testable form, and how is the new copy resolved in `zip_captions`?

Two coupled decisions. (a) Rule 13 requires a distinct icon + text per state *and* an
announcement on every state change; the FD defers the Flutter mechanism to Code
Generation but NFR Requirements must fix the **testable** requirement. (b) Every new
string (state titles, five new cannot-connect copies, the confirm dialog, the join
screen's error) is specified as ARB-externalized, but `zip_captions` today has no
localization mechanism at all (no `flutter_localizations`, no generated bindings, no
`l10n.yaml`; screens hardcode English). Getting this wrong means either an unplanned
SDK wiring change across the whole app or strings that fail the project's
externalization constraint.

A) **Announcement, testable form:** every state change must (1) render the current state's
   status text inside a `Semantics` container that is findable in a widget test via
   `find.bySemanticsLabel`, and (2) emit the new status text through the announcement
   channel. The test seam is a single injectable announcer — a
   `ViewerAnnouncer`/`SemanticsAnnouncement` `void Function(String)`-shaped provider
   (default: `SemanticsService.announce` with `TextDirection` from the ambient locale),
   overridden in widget tests with a recording fake so "the announcement fires on each
   transition and carries the new state's text" is asserted deterministically (the
   `tester.ensureSemantics()`/`SemanticsController` path is used only for the container
   assertion). No announcement for same-state in-place updates whose status text is
   unchanged (`LiveView` activity flip is a notice, announced too — one rule: announce
   whenever the rendered status text changes). **Copy resolution:** do **not** introduce
   a localization framework in this unit. `zip_captions` uses its existing ARB file as
   the single external string source, read through a small generated-or-plain Dart
   `Strings`/`ZcStrings` class (generation mechanism is a Code Generation detail: either
   `flutter gen-l10n` with the minimum SDK wiring added here, or a plain lookup class
   over the ARB keys) — the **constraint** recorded here is: all viewer copy lives in
   `l10n/arb/app_en.arb` with no string literal in the viewer widgets, and a widget test
   asserts a representative sample of the copy comes from that source rather than being
   inline. **(recommended — gives NFR-5.2 a mechanical assertion instead of a judgement
   call, and keeps the app-wide localization decision at its own scale rather than
   smuggling it in through one unit)**

B) Defer the announcement to a project-wide accessibility pass (Unit 6 Q7's answer) —
   not viable for this unit: S-19 names screen-reader announcement as an acceptance
   criterion, so deferring it would ship a known-unmet story condition
C) Other (write in)

[Answer]: A

## Tech Stack (continued)

### Q9: Where does the env-driven `broadcastBaseUrl` land, and what does it replace?

FD Rule 11 names the mechanism (`String.fromEnvironment('BROADCAST_BASE_URL', ...)`) and
requires `parseInput` to stay host-agnostic. Source shows `BroadcastLink.toUrl` is used
by `BroadcastSessionNotifier` (broadcaster-side `LiveBroadcast.url`), by
`zip_broadcast`'s setup screen, and by two tests — so this is cross-package work inside
a viewer unit that must not change Unit 3/5/6 behaviour. `BroadcastLink.baseUrl` is a
`static const String` today; whether it stays a member or moves to a constants file
following `supabase_config.dart`/`turn_config.dart` is the open detail.

A) Move the value to `zip_core/lib/src/constants/broadcast_link_config.dart` as
   `const broadcastBaseUrl = String.fromEnvironment('BROADCAST_BASE_URL', defaultValue:
   'https://zipcaptions.app/b/')`, exactly mirroring `supabase_config.dart`;
   `BroadcastLink.toUrl` interpolates it; `BroadcastLink.baseUrl` is **removed** (it has
   no external consumer — the grep above shows every use is `toUrl`) rather than kept as
   a deprecated alias, since keeping two sources defeats the point. To preserve the
   *default* behaviour exactly, the constant's default is the same string as today, so
   every existing test and call site is unchanged unless a `--dart-define` supplies
   another value. Scheduled as explicit Code Generation steps with their own tests
   (`toUrl` under a supplied base; `parseInput` of a v2-subdomain URL; the broadcaster's
   URL row still rendering). **(recommended — one source of truth, the project's
   existing config-file pattern, no behaviour change without configuration)**

B) Keep `BroadcastLink.baseUrl` as a getter that returns `broadcastBaseUrl` (compat
   alias), adding the constants file
C) Other (write in)

[Answer]: A

## Approval

All nine questions answered with the recommended option under the run-configuration
pre-approval. No answer was ambiguous enough to need a follow-up clarification, and no
question was left open. Recorded in `audit.md` with the approval line and carried into
`nfr-requirements.md`, `tech-stack-decisions.md`, and `handoff-summary.md`.