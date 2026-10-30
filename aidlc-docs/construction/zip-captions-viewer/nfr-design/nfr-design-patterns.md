# NFR Design Patterns — Zip Captions Viewer (Unit 7)

## Resilience

**One holder, one teardown, one writer (Design Q1)**: `ViewerSessionResources`
(`zip_core/lib/src/services/broadcast/viewer_session_resources.dart`, package-internal,
not in the barrel — same treatment as Unit 6's `SessionResources`) holds everything one
viewing session owns:

```
broadcastId        BroadcastId
sessionId          String?                     (null until a `live` resolution)
transport          ViewerTransport
receiver           RemoteCaptionReceiver
bus                CaptionBus
registry           CaptionOutputTargetRegistry
target             OnScreenCaptionTarget       (repository: null, by design)
statusChannel      StatusChannel
statusWatch        StreamSubscription<BroadcastStatus>?
statusSub          StreamSubscription<ConnectionStatus>
activitySub        StreamSubscription<CaptionActivity>
endedSub           StreamSubscription<void>
windowTimer        Timer?                      (mutable)
lastStatus         BroadcastStatus?            (mutable; F-7.4 step 4's audit trail)
```

`Future<void> disposeAll(Logger log, {bool releaseTransport = true})` attempts F-7.7's
steps in order — cancel `windowTimer`; cancel `statusWatch` then
`await statusChannel.close()`; `releaseTransport ? await transport.disconnect()`; then
`receiver.dispose()`; `registry.remove(target)` (which disposes the target, cancelling
its 50ms debounce timer); `registry.dispose()`; `bus.dispose()` — each inside its own
`try`/`on Object` logging `${e.runtimeType}` only (never `toString()`, never caption
content). It never throws. An already-released resource is represented by a **null
field**, not a boolean: each step reads its field into a local and skips when null, so a
second call (terminal transition then `leave()`) is a no-op rather than a
double-disconnect. `disposeAll` never assigns `_resources = null`; the notifier is the
only writer of that field (single-writer rule), immediately after `disposeAll` returns
and before the terminal state assignment.

Invariant (asserted in the stateful suite, NFR Requirements Q3): `_resources` is
non-null in every state except `IdleState` and `InvalidInputState`. Terminal states keep
the holder with the bus/registry/target alive (F-7.5 step 3: last captions stay visible;
teardown is the user's leave/back action) and the transport released.

**The window timer lives in the holder and is cancelled by state construction, not
by call sites (Design Q2)**: `_enterReconnecting()` does
`holder.windowTimer?.cancel(); holder.windowTimer = Timer(defaultBroadcastLimits.reconnectWindow, _onWindowExpired);`.
Every state assignment in the notifier goes through one private `_setState(next)` which,
before assigning, cancels `windowTimer` whenever `next is! ReconnectingState`. Rule 3's
"cancel on `Connected`, `leave()`, any terminal transition" is therefore structural — a
new exit path added later cannot forget it. `disposeAll` cancels it once more defensively.
`ReconnectPolicy` stays a pure object (`nextDelay(attempt, elapsed)`); only the notifier
owns time.

**Stale-resume suppression around `join()`'s awaits (Design Q3)**: `join()` awaits
`resolve()`, `iceServersForBroadcast()` and `connect()`. An `int _sessionEpoch` is incremented at
the start of every `join()`, on every implicit leave, and in `leave()`. After each await,
`join()` re-reads the epoch and returns without touching state if it changed. Because
the epoch check precedes F-7.2 step 4 (the first allocating step), a superseded join
never constructs a transport, bus, target or status channel; because `_setState` is the
only state writer and `leave()` only reaches `disposeAll` when `_resources != null`,
a stale resume cannot resurrect a terminal state. Together with Rule 1's per-broadcast
no-op and terminal-state gates, this makes `join()`/`leave()` idempotent under
interleaving (PBT-04 row).

**Terminal transition = partial release, not a second teardown path (Design Q4)**:
`_terminate(next)` runs `disposeAll(log, releaseTransport: true)` for the transport,
status watch, status channel, `statusSub` and window timer, nulls those holder fields,
then `_setState(next)` — the state assignment is last and unconditional, so a throwing
`disconnect()` can never leave `Ended`/`Full`/`CannotConnect` unreached. `leave()` runs
`disposeAll(log)` for the remainder (the already-null fields are skipped) and clears
`_resources`, `sessionName`, `currentBroadcastId`. One helper, two modes; never a
parallel teardown implementation.

**Last-resort disposal on provider rebuild (this stage's one deliberate divergence
from Unit 6)**: `ViewerSessionNotifier.build()` registers `ref.onDispose(leave)`.
`BroadcastSessionNotifier` has none, but the viewer is keepAlive and its transport holds
native WebRTC resources; a rebuilt/replaced container (test teardown, provider override
swap, hot restart) must not leak a peer connection. `leave()` is idempotent, so the hook
is safe when the session is already idle.

## Scalability / Performance (restated from NFR Requirements, no new pattern)

Nothing new to design. NFR Requirements fixed scalability as N/A (one viewer session
holds one transport, one receiver, one bus, one registry, one target, at most one status
watch; `defaultBroadcastLimits` consumed unchanged; no viewer-defined limit) and
performance as carried forward (NFR-1.3 remains Spike 2.1's aspirational target; the only
value this unit owns is the fixed 120s `reconnectWindow`). No cache, queue, pool,
batching or circuit breaker is introduced. The viewer-scoped `OnScreenCaptionTarget`
inherits the 50ms debounce unchanged, so the viewer adds no throttling of its own.

## Security

**Terminal states never fail open**: every failure path ends in a named state and a
fixed `ConnectFailure` reason; `@catch` sites are `on Object catch (e)` followed by
`${e.runtimeType}`-only logging. The viewer path never reads `authNotifierProvider`
(SECURITY-08), never persists captions (`repository: null`), and never logs the raw join
input, even on parse failure (Error path: `InvalidInputState` is data-free and the
notifier logs only the integer length, never the string).

**Announcement seam is a callback provider, not a screen-internal call (Design Q5)**:
`typedef ViewerAnnouncer = void Function(String message);` with
`@Riverpod(keepAlive: true) ViewerAnnouncer viewerAnnouncer(Ref ref) => (message) => SemanticsService.announce(message, TextDirection.ltr);`
in `zip_captions/lib/src/providers/viewer_announcer_provider.dart`. A single
`ViewerStatusRegion` widget owns the trigger: it keeps `String? _lastAnnounced` and
announces the current state's status text only when that text differs from the last one
announced — matching NFR-5.2's "announce whenever the rendered status text changes"
(including the paused/inactive notice and the reconnect notice), and never on unrelated
rebuilds. The same widget renders the status text inside a `Semantics` container so
`find.bySemanticsLabel` finds it under `tester.ensureSemantics()`. Widget tests override
`viewerAnnouncerProvider` with a recording fake; no `BuildContext` is required by the
default, and no dependency is added.

**Copy resolution without a localization framework (Design Q6)**: a hand-written
`ZcStrings` class (`zip_captions/lib/src/l10n/zc_strings.dart`) is the **only** reader of
`l10n/arb/app_en.arb`. It loads the ARB once (`rootBundle.loadString`) and exposes one
getter per viewer key; no `flutter_localizations`, no `l10n.yaml`, no `generate: true`,
no `intl` dependency. The widget test asserts a viewer screen renders the ARB value (a
sentinel injected for one key) rather than an inline literal — the first mechanical
proof that the ARB is wired at all (nothing reads it today). `gen-l10n` is recorded as
the right choice for the project-wide localization Backlog item, not for this unit.

**`broadcastBaseUrl` is the only URL source (restated)**: the new
`zip_core/lib/src/constants/broadcast_link_config.dart` holds
`const broadcastBaseUrl = String.fromEnvironment('BROADCAST_BASE_URL', defaultValue: 'https://zipcaptions.app/b/');`
mirroring `supabase_config.dart`. `BroadcastLink.toUrl` interpolates it and
`BroadcastLink.baseUrl` is deleted (verified: no consumer outside `toUrl`). Default
behaviour is byte-identical, so no existing test or call site changes unless a
`--dart-define` supplies another value; `parseInput` stays host-agnostic and untouched.

## Testability

**Fakes extend the existing helper file (Design Q7)**: three additions to
`zip_core/test/helpers/fake_broadcast_session_collaborators.dart` (no parallel file):
`FakeBroadcastResolver` (scripted result queue + default, `resolveCalls`);
`FakeViewerTransport` (`status`/`messages` controllers with `emitStatus`/`emitMessage`,
`connectCalls`/`restartCalls`/`disconnectCalls`, nullable `connectError` thrown after
recording, nullable `disconnectError`); and the existing `FakeStatusChannel` +
`FakeBroadcastSignalingService` reused unchanged (`watch()` already returns a broadcast
stream). `RemoteCaptionReceiver`, `CaptionBus`, `CaptionOutputTargetRegistry` and
`OnScreenCaptionTarget` stay real (in-memory, no I/O). `restartCalls` must remain 0 in
every suite — it is how Rule 3 / Rule 14 ("no notifier-owned retry loop") are asserted.

**Two property suites plus one pure-policy suite (PBT-02/04/06)**:
`test/pbt/viewer_session_state_machine_properties_test.dart` follows Unit 6's
`ProviderContainer(overrides: ...)` shape but wraps each Glados trial in
`fakeAsync((async) { ... })`, driving `arbitraryViewerSessionCommandSequence` (new in
`generators.dart`) and checking the FD's transition table plus invariants 1–5, holder
presence, `windowTimer` null-or-inactive outside `Reconnecting`, and
`leave()`-twice-equals-once after every command;
`test/pbt/broadcast_link_test.dart` is extended with the configured-base URL form; and
`ReconnectPolicy` gets a small example suite (positive remaining, at-window -> null,
past-window -> null, `attempt` irrelevant) plus one invariant row — no separate PBT file.
Rule 5's seven-row mapping, the eight widget states and the three window-expiry outcomes
stay explicit example tests (PBT-10).