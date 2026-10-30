# NFR Design Plan: Zip Captions Viewer (Unit 7)

**Prior stage**: NFR Requirements, approved 2026-10-18
**Run mode**: unattended (`.agent/overnight-pipeline.md` adaptation A2). Every
question below is answered here with the recommended option and recorded in
`audit.md` as `approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-18) — subject to morning review`.

## Context

NFR Requirements fixed *what* has to be true — one catch-and-continue teardown
(`_ViewerResources.disposeAll`), no clock seam, an injectable announcement seam, ARB
copy through one `ZcStrings` class, the in-tree PBT shim, `broadcastBaseUrl` in a new
constants file — but not *how* the implementation is shaped to make those true, and it
left three details explicitly open for this stage (announcement seam kind and
placement, the `zip_captions` string-resolution mechanism, and the exact
`_ViewerResources` field set/nulling order). Scalability and Performance introduce no
new pattern (restated below, not reopened), exactly as in Unit 6.

**Verified against source** (2026-10-18, before writing questions):

- `SessionResources` (`zip_core/lib/src/services/broadcast/session_resources.dart`)
  is the shipped Unit 6 precedent for the holder: a plain class with `final` fields,
  one `Future<void> disposeAll(Logger log)`, each step in its own `try`/`on Object`
  logging `${e.runtimeType}` only. It is package-internal (not in the barrel). The
  viewer's holder must add the reconnect `Timer` and the status-watch subscription,
  which the broadcaster's holder does not have.
- `BroadcastSessionNotifier` has **no `ref.onDispose`**: it holds `_resources`
  privately, nulls it after `disposeAll(_log)`, and sets terminal state last
  (`endBroadcast()`). Unit 7 copies this rather than inventing a disposal hook, but
  must add one deliberate difference: a keepAlive notifier can be rebuilt (e.g. a
  provider override swap), and a leaked transport on rebuild would never be reaped —
  the viewer therefore registers `ref.onDispose(leave)` as a last-resort net (Design Q8).
- `RemoteCaptionReceiver.dispose()`, `CaptionBus.dispose()` and
  `CaptionOutputTargetRegistry.dispose()` are all **synchronous**;
  `StatusChannel.close()`, `transport.disconnect()`, subscription `cancel()` and
  `Timer.cancel()` are sync-or-async. `registry.remove(target)` disposes the target
  itself. So step shape genuinely is mixed — the helper must be `async` and await
  each step inside its own `try`.
- `CaptionOutputTargetRegistry.dispose()` disposes every target it still holds and
  catches per target; calling `remove(target)` then `registry.dispose()` is safe
  (second dispose is a no-op on an already-removed target) but redundant — F-7.7's
  eight steps stay as written (target `dispose()` then registry `dispose()`), which
  is idempotent on the registry side.
- `OnScreenCaptionTarget` takes `repository: null` and exposes
  `visibleCaptions` + `onVisibleCaptionsChanged` (50ms debounce `Timer` internally),
  so a viewer-scoped target has its own timer — the holder's teardown must dispose it,
  which `dispose()` already does (cancels its debounce timer).
- `BroadcastSessionNotifier.goLive()` constructs `statusChannel` **before**
  publishing live, so a publish failure unwinds the channel via `SessionResources`.
  Unit 7 never publishes; its status channel is only ever `watch()`ed.
- `BroadcastLink` (`broadcast_link.dart`) `toUrl` callers are exactly:
  `BroadcastSessionNotifier` (`LiveBroadcast.url`), `zip_broadcast`'s
  `broadcast_screen.dart:262`, and three test files (`broadcast_screen_test.dart`,
  `zb_app_shell_test.dart`, `test/pbt/broadcast_link_test.dart`). No `baseUrl`
  consumer outside `toUrl`, so Q9's removal is safe as recorded.
- `zip_captions` has no `l10n.yaml`, no `flutter_localizations`, no `generate: true`
  and **no code anywhere reads `app_en.arb`** (grep: the ARB's `appName` /
  `homePlaceholder` keys are never referenced; screens hardcode English). So the ARB
  is currently a dead artifact and Q8's `ZcStrings` class will be the first consumer
  — its test is the first proof the file is wired at all.
- `zip_captions` providers are `riverpod_generator`-generated today
  (`device_auth_provider.dart`, `transcript_search_query_provider.dart`) plus one
  hand-written `displaySettingsProvider` (`providers/settings_notifier.dart`). The
  closest precedent for a callback-shaped provider is
  `broadcastTransportFactoryProvider` (`@Riverpod` function returning a closure), so
  the announcement seam (Q1, accessibility) follows that shape rather than a
  hand-written `Provider`.
- `zip_captions` dev dependencies are `flutter_test`, `build_runner`, `drift`,
  `riverpod_generator`, `very_good_analysis` — no `mocktail`, no `fake_async`; the
  widget tests must therefore rely on `pump`/`pumpAndSettle` and a hand-written
  notifier subclass (already fixed by NFR Requirements Q2).
- `test/helpers/fake_broadcast_session_collaborators.dart` already has
  `FakeStatusChannel`, `FakeBroadcastSignalingService` (takes a `FakeStatusChannel`),
  `FakeIceServerProvider`, `FakeBroadcastIdentityRepository`, `FakeBroadcastTransport`.
  `FakeBroadcastResolver` and `FakeViewerTransport` do not exist yet.
- `arbitraryBroadcastId`, `arbitraryLinkInput`, `arbitraryBroadcastSessionCommandSequence`
  live in `test/helpers/generators.dart`; the stateful PBT pattern is
  `ProviderContainer(overrides: [...])` + per-command expectations
  (`broadcast_session_state_machine_properties_test.dart`), with no `fakeAsync` used
  there today (Unit 6's commands are all synchronous-await). Unit 7's command set
  includes timer expiry, so the viewer's stateful suite wraps the container loop in
  `fakeAsync` (Design Q7).

## Planned Steps

- [x] Resilience: the `_ViewerResources` field set, step order and single-writer rule (Design Q1)
- [x] Resilience: window-timer ownership and the cancel-on-every-exit discipline (Design Q2)
- [x] Resilience: idempotent `join()`/`leave()` re-entrancy under async interleaving (Design Q3)
- [x] Security: terminal-state teardown split (transport released early, caption pipeline kept) (Design Q4)
- [x] Performance/Scalability: restated from NFR Requirements, no new pattern
- [x] Accessibility: announcement seam kind, placement, and announce-trigger rule (Design Q5)
- [x] Accessibility/i18n: the `ZcStrings` resolution mechanism and its test (Design Q6)
- [x] Testability: the fake set, `FakeViewerTransport` shape, and the stateful PBT harness (Design Q7)
- [x] Logical components: final component list, file placement, dependency diagram (Design Q8)
- [x] Generate `nfr-design-patterns.md`, `logical-components.md`, `handoff-summary.md`

## Resilience

### Design Q1: How is the NFR Requirements Q3 holder (`_ViewerResources.disposeAll`) shaped — what fields, what order, who nulls it?

NFR Requirements fixed the *existence* of one shared catch-and-continue
`disposeAll`, the step **order** (F-7.7's eight steps), and the invariant (non-null in
every state except `Idle`/`InvalidInput`). It did not fix the field set or the rule
"exactly one writer nulls the holder". Unit 6's `SessionResources` is the precedent;
the viewer's set differs (a `Timer` and a status-watch subscription instead of an
admission object and two broadcaster subscriptions).

A) A plain (non-`freezed`) package-internal class
   `_ViewerResources`-shaped `ViewerSessionResources` in
   `zip_core/lib/src/services/broadcast/viewer_session_resources.dart`, with `final`
   fields: `broadcastId` (`BroadcastId`), `sessionId` (`String?` — null until a `live`
   resolution provides one), `transport` (`ViewerTransport`), `receiver`
   (`RemoteCaptionReceiver`), `bus` (`CaptionBus`), `registry`
   (`CaptionOutputTargetRegistry`), `target` (`OnScreenCaptionTarget`),
   `statusChannel` (`StatusChannel`), `statusWatch` (`StreamSubscription<BroadcastStatus>?`
   — attached when `watch()` is subscribed), `statusSub`
   (`StreamSubscription<ConnectionStatus>`), `activitySub`
   (`StreamSubscription<CaptionActivity>`), `endedSub`
   (`StreamSubscription<void>`), and a mutable `Timer? windowTimer` plus a mutable
   `BroadcastStatus? lastStatus` (the audit trail F-7.4 step 4 reads). `disposeAll(Logger log)`
   runs F-7.7's order exactly: cancel `windowTimer` -> cancel `statusWatch` and
   `await statusChannel.close()` -> `await transport.disconnect()` -> `receiver.dispose()`
   -> `registry.remove(target)` -> `registry.dispose()` -> `bus.dispose()`; each step
   in its own `try`/`on Object` logging `runtimeType` only; then the caller sets
   `_resources = null` and the terminal state. `disposeAll` **does not** null
   `_resources` — the notifier does, immediately after it returns, so the invariant
   has exactly one writer (the notifier) and the helper has no way to leave a
   half-nulled field. **(recommended — the direct Unit 6 shape plus the three fields
   the viewer genuinely adds; keeping `statusChannel.close()` outside the stream
   cancel is required because closing a Realtime channel is the only thing that
   releases the presence topic)**
B) Make the holder `freezed`/`copyWith`-able so `leave()` can replace it
   (rejected: a mutable `Timer`/`lastStatus` pair and a `StreamSubscription` set have
   no value semantics; `copyWith` would invite a second holder instance)
C) Other (write in)

[Answer]: A

### Design Q2: Where does the reconnect-window `Timer` live, and what guarantees it is cancelled on every exit?

NFR Requirements Q4 fixed "no clock seam, one `Timer(reconnectWindow)` driven by
`fakeAsync`", and the FD (Rule 3) fixes "started on entry to `ReconnectingState`,
cancelled on `Connected`, `leave()`, or any terminal transition". It does not say
whether the `Timer` is a notifier field or a holder field, nor how "every exit from
`Reconnecting`" is mechanically enforced rather than remembered.

A) The `Timer` is a field of the holder (`holder.windowTimer`), not of the notifier.
   The notifier's single `_enterReconnecting()` helper cancels-and-restarts it, and
   **every** state assignment goes through one private `_setState(next)` method that
   first calls `_cancelWindowIfLeavingReconnecting()` (cancel whenever `next` is not
   `ReconnectingState`). `disposeAll` also cancels it defensively. A stateful test
   asserts after every command that `holder.windowTimer` is null or inactive whenever
   the state is not `Reconnecting`. **(recommended — makes Rule 3's "cancel on every
   exit" structural instead of a list of call sites that a future edit can miss; the
   Unit 6 `goLive()` bug in this project's own history was exactly a remembered-step
   omission)**
B) The `Timer` is a notifier field; each transition out of `Reconnecting` cancels it
   inline at its own call site (four sites: `Connected`, status-channel offline,
   terminal, `leave()`)
C) Other (write in)

[Answer]: A

### Design Q3: How is `join()`/`leave()` made idempotent and safe against re-entrancy given `join()` awaits three times?

Rule 1 requires "`join()` for the current broadcast is a no-op" and "`leave()` twice
equals once", and FD F-7.2's flow awaits `resolve()`, `iceServersForBroadcast()` and
`connect()`. Between those awaits, a second `join()` or a `leave()` can be
interleaved (the back gesture during `Resolving`, "Try again" double-tapped). Unit 6
solved the equivalent with synchronous state assignment before the first await; Unit
7 has three awaits and a terminal `leave()` that can legitimately race a join in
flight, so the design must say what a stale resume does.

A) A monotonic `int _sessionEpoch` incremented by **every** `join()` start, every
   implicit leave, and every `leave()`. After each `await` inside `join()`, the
   method re-reads `_sessionEpoch`; if it changed, it returns immediately without
   touching state or constructing resources (a "stale resume" is dropped). The
   `_resources` constructed for a stale epoch are never built (the epoch is checked
   before F-7.2 step 4, which is the first step that allocates). `leave()`
   additionally follows Rule 1: any state other than the six non-idle ones returns
   immediately, and `disposeAll` is only reached when `_resources != null`.
   `_setState` is the only state writer, so a stale resume can never resurrect a
   terminal state. **(recommended — one counter, no lock, and the check points are
   exactly the await boundaries; without it, "Try again" during a slow resolve races
   the previous attempt's `connect()` and can leave two transports alive)**
B) An `bool _joining` guard that ignores any `join()` while a previous one is in
   flight
C) Other (write in)

[Answer]: A

## Security

### Design Q4: On a terminal transition (`Ended`/`Full`/`CannotConnect`), how much is torn down before `leave()` — and how does that stay exception-safe?

FD F-7.5 step 2 says the transport is `disconnect()`ed and the status watch closed on
`Ended`, but the bus/registry/target stay alive "until `leave()`". Invariant 1 says the
holder is **non-null** in all four terminal states. So a terminal transition performs a
*partial* teardown of a live holder, and a second `disposeAll` at `leave()` must not
double-disconnect in a way that throws.

A) `disposeAll` is given a `({bool releaseTransport})` parameter, defaulting to
   `true`. Terminal transitions call `disposeAll(log, releaseTransport: true)` **and**
   keep the holder (via a `_releaseTransportAndWatch()` private step that awaits
   `disconnect()`, cancels `statusWatch`, closes `statusChannel`, cancels `statusSub`
   and `windowTimer`, and nulls those fields on the holder but leaves
   bus/registry/target/receiver intact), while `leave()` calls `disposeAll(log)` for
   the remaining steps. `disposeAll` treats an already-null field as done (each step is
   `final x = field; if (x != null) { try { ... } }`), so a second call is a no-op for
   released resources, never an error. Every step remains individually caught, so a
   throwing `disconnect()` cannot prevent `EndedState`/`FullState`/`CannotConnectState`
   from being set (last, unconditionally). **(recommended — one helper, two modes, and
   "already released" is represented by a null field rather than a boolean the two
   paths could disagree on; the FD's F-7.5 "last captions remain visible" is preserved
   because the target and its buffer survive until `leave()`)**
B) Keep two helpers — a terminal-transition `_release()` and a `leave()` `_dispose()` —
   sharing nothing
C) Other (write in)

## Performance / Scalability (restated from NFR Requirements, no new pattern)

Nothing new to design. NFR Requirements fixed scalability as N/A (one viewer holds
one transport/bus/registry/target; no new limit) and performance as carried forward
(NFR-1.3 remains Spike 2.1's aspirational target; the only latency value this unit
owns is the fixed 120s `reconnectWindow`). This stage adds no cache, queue, batching,
pool, or circuit breaker. Confirmed: the viewer-scoped `OnScreenCaptionTarget` inherits
the 50ms debounce unchanged, so no viewer-side throttling is introduced.

## Accessibility

### Design Q5 (announcement seam): What exactly is the announcement seam — its type, provider kind, and trigger rule?

NFR Requirements Q8 fixed the *properties* (announce on every rendered-status-text
change; status text findable via `find.bySemanticsLabel`; injectable) but left three
details open: whether the seam is a `Provider<void Function(String)>`, how the default
is implemented without a `BuildContext`, and where the "announce when the text changes"
logic lives (`BroadcastViewerScreen` vs a status widget).

A) A `@Riverpod(keepAlive: true)` function provider
   `viewerAnnouncer(Ref ref) => (String message) => SemanticsService.announce(message, TextDirection.ltr)`
   in `zip_captions/lib/src/providers/viewer_announcer_provider.dart`, declared as
   `typedef ViewerAnnouncer = void Function(String message)`. `TextDirection.ltr` is
   fixed (not ambient) because the project is English-only and the viewer copy is
   English; this keeps the default a pure function with no `BuildContext`. A single
   `_ViewerStatusRegion` widget inside `BroadcastViewerScreen` owns the trigger: it
   holds `String? _lastAnnounced`, and in `didChangeDependencies`/build-time comparison
   of the current state's status text it calls `ref.read(viewerAnnouncerProvider)(text)`
   only when `text != _lastAnnounced`, then assigns. One rule, one place. Widget tests
   override `viewerAnnouncerProvider` with a recorder. **(recommended — the callback
   seams in this repo are `@Riverpod` function providers returning closures
   (`broadcastTransportFactoryProvider`), `TextDirection.ltr` is honest for an
   English-only build, and a `String? _lastAnnounced` is the simplest correct
   "announce on change only, including the paused/reconnect notices" implementation)**
B) A hand-written `Provider<void Function(String)>` in the same file (no generator)
C) Other (write in)

[Answer]: A

### Design Q6 (string resolution mechanism): `flutter gen-l10n` wiring, or a plain ARB-backed `ZcStrings` class?

NFR Requirements Q8 requires "all viewer copy in `l10n/arb/app_en.arb`, no literals in
viewer widgets" and left the mechanism to this stage. Verified fact: `zip_captions`
has **no** localization mechanism at all, and **nothing currently reads
`app_en.arb`** (the two keys are dead). `flutter gen-l10n` would require
`flutter_localizations` (SDK), `generate: true`, an `l10n.yaml`, and would generate an
`AppLocalizations` class for the whole app — a project-wide change smuggled in through
one unit, plus it would replace (or sit beside) the existing dead ARB keys.

A) A plain, hand-written, `const`-constructible `ZcStrings` class in
   `zip_captions/lib/src/l10n/zc_strings.dart` that loads `app_en.arb` once at startup
   (`rootBundle.loadString`) through a synchronous-after-load lookup
   (`ZcStrings.of(context)` via an `InheritedWidget`, or a `ZcStringsNotifier` provider
   `AsyncValue`), with one getter per viewer key (`viewerConnecting`, `viewerLive`,
   `viewerCannotConnectRateLimited`, ...) and no `intl` dependency. A widget test
   asserts a representative viewer string is **not** present as a literal in the
   widget tree when the ARB is loaded with a sentinel value (i.e. the screen renders
   the ARB value, not an inline string). No SDK wiring, no `l10n.yaml`, no
   `generate: true`, no `flutter_localizations`. **(recommended — matches the NFR
   Requirements constraint's "minimum needed", touches only the viewer's copy, and is
   the first (and only) reader of an ARB that is currently dead; `gen-l10n` is a
   proper choice for the future project-wide localization Backlog item, not for one
   unit)**
B) `flutter gen-l10n`: add `flutter_localizations`, `flutter.generate: true`,
   `l10n.yaml`, switch `ZipCaptionsApp` to `AppLocalizations`, and add the viewer keys
   to the generated class
C) Other (write in)

[Answer]: A

## Testability

### Design Q7: What is the exact fake set and the stateful PBT harness for `ViewerSessionNotifier`?

NFR Requirements Q1/Q2 fixed fakes-for-everything and the widget-test subclass, and
Q7 fixed the framework (in-tree shim) and property scope (PBT-02/04/06 + `ReconnectPolicy`
invariant). Open: the `FakeViewerTransport` shape (what it records, how a test drives
status/messages), whether a `FakeBroadcastResolver` scripts one result or a queue, and
how `fakeAsync` composes with `ProviderContainer` for the stateful suite.

A) Three new hand-written fakes appended to `test/helpers/fake_broadcast_session_collaborators.dart`
   (no new file): (1) `FakeBroadcastResolver implements BroadcastResolver` with a
   `List<BroadcastResolution> results` queue plus a single `result` default, and
   `int resolveCalls`; (2) `FakeViewerTransport implements ViewerTransport` with two
   broadcast controllers (`status`, `messages`), `emitStatus`/`emitMessage` helpers,
   `int connectCalls`/`restartCalls`/`disconnectCalls`, a nullable `connectError`
   (thrown by `connect()` after recording the call) and a nullable
   `disconnectError`; `restart()` records and does nothing else (Rule 3: the session
   layer never calls it — the test asserts `restartCalls == 0`); (3) reuse
   `FakeStatusChannel` + `FakeBroadcastSignalingService` unchanged, but extend the fake
   with a `publishStatus(BroadcastStatus)`/`emitWatch` helper if `watch()`'s
   single-subscription controller shape needs it (today `FakeStatusChannel.watch()`
   returns a broadcast stream already). All fakes record, throw only when scripted,
   and are `dispose`d in `tearDown`. The stateful suite follows
   `broadcast_session_state_machine_properties_test.dart`'s
   `ProviderContainer(overrides: ...)` shape but wraps each Glados trial body in
   `fakeAsync((async) { ... async.flushMicrotasks(); async.elapse(window); ... })`, with
   `arbitraryViewerSessionCommandSequence` (new, in `generators.dart`) producing
   `join(valid | invalid | different)`, `transportStatus(Connecting | Connected |
   Interrupted | Failed(f))`, `activity(a)`, `ended`, `statusEvent(live | offline)`,
   `advanceWindow` and `leave()` commands. **(recommended — records-and-scripts is the
   existing fake idiom; a resolver *queue* is what makes the "Try again after
   resolutionFailed" and "auto-join with a new session id" sequences expressible; the
   `fakeAsync` wrapper is the only addition to Unit 6's harness shape, needed because
   Unit 7's command set contains timer expiry)**
B) Put the new fakes in a new `fake_viewer_session_collaborators.dart` and keep
   `FakeViewerTransport` local to the PBT file
C) Other (write in)

## Logical Components

### Design Q8: Final component list, file placement, and dependency diagram?

A) Confirms `tech-stack-decisions.md`'s placement with the details this stage fixes:
   - `zip_core`, `lib/src/services/broadcast/`:
     `viewer_session_notifier.dart` (+ `.g.dart`),
     `viewer_session_resources.dart` (package-internal, `ViewerSessionResources`, not
     exported).
   - `zip_core`, `lib/src/models/`: `viewer_session_state.dart` (+ `.freezed.dart`,
     `.g.dart` if needed — `freezed` sealed family with `IdleState`..`InvalidInputState`),
     `reconnect_policy.dart`; additive edit to `connect_failure.dart` (three new
     `final class` variants); edit to `broadcast_link.dart` (interpolate
     `broadcastBaseUrl`, delete `baseUrl`).
   - `zip_core`, `lib/src/constants/broadcast_link_config.dart` (new, `broadcastBaseUrl`).
   - `zip_core`, `lib/src/providers/`: `viewer_transport_factory_provider.dart` (+ `.g.dart`),
     mirroring `broadcast_transport_factory_provider.dart`; `providers.dart` barrel line.
   - `zip_captions`, `lib/src/screens/`: `join_broadcast_screen.dart`,
     `broadcast_viewer_screen.dart`; `lib/src/widgets/viewer_status_region.dart` (the
     announce-trigger widget, Design Q5) and any notice widgets extracted from the
     screen; `lib/src/providers/viewer_announcer_provider.dart` (+ `.g.dart`);
     `lib/src/l10n/zc_strings.dart` (+ its `InheritedWidget` or notifier);
     `lib/src/routing/zc_router.dart` (two routes), `zc_nav_drawer.dart`,
     `home_screen.dart` (entry affordances); `l10n/arb/app_en.arb` (viewer keys).
   - New make-or-break seam: `ref.onDispose(leave)` registered in
     `ViewerSessionNotifier.build()` (keepAlive notifier; a rebuilt container leaks a
     transport otherwise — this is the one place Unit 7 deliberately diverges from
     `BroadcastSessionNotifier`, which has no `onDispose`). **(recommended — the
     dependency diagram every prior unit's NFR Design produces, updated for the three
     files this stage adds; recorded so Code Generation does not re-derive placement)**
B) Other (write in)

[Answer]: A

## Approval

All eight Design questions answered with the recommended option under the
run-configuration pre-approval (Design Q1–Q8). No answer was ambiguous enough to
need follow-up, and none changes the shape of the approved FD or the settled NFR
Requirements answers — each only fills a detail those documents explicitly deferred.
Recorded in `audit.md` with the approval line and carried into
`nfr-design/nfr-design-patterns.md`, `nfr-design/logical-components.md`, and
`nfr-design/handoff-summary.md`.