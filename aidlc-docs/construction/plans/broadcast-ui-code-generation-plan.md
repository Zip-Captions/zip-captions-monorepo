# Code Generation Plan: Zip Broadcast Broadcast UI (Unit 6)

**Prior stage**: NFR Design, approved 2026-10-13. Infrastructure Design skipped (no
infrastructure change in this unit).

**Story**: S-17. **Branch**: `feature/broadcast-ui` (off `develop`).

## Scope

Everything fixed at Application Design, elaborated by this unit's own Functional
Design/NFR stages: `BroadcastSettings`, `BroadcasterSessionState` (renamed, Functional
Design Q2), `LiveBroadcast` (8 fields, Functional Design Q3), `BroadcastFailure`,
`BroadcastSessionNotifier` (+ the new `_SessionResources` holder, NFR Design Q1),
`BroadcastSettingsNotifier`, the new `CaptioningStarter` seam, the two screens
(`BroadcastSetupScreen`/live dashboard, implemented as one route per Functional Design
Q8), and `ZbAppShell`'s new sign-out guard (Rule 9, NFR Design Q2's no-await-between
rule). Plus two additive, non-breaking methods on Unit 5's already-shipped
`RemoteBroadcastTarget` and `BroadcastTransport`/`WebRtcBroadcastTransport`.
`zip_core` + `zip_broadcast` — no `zip_supabase` migration, no new dependency.

**Not in scope**: Unit 7's viewer-side screens/orchestration (don't exist yet); any
change to Units 2/3/3.1/4/5's own files beyond the two named additive methods.

## Steps

### `packages/zip_core/` — models

1. [x] `lib/src/models/broadcast_settings.dart` (+ `.freezed.dart` via
   `build_runner`) — `BroadcastSettings { String sessionName; bool
   autoStartCaptioning }` (defaults: `''`, `false`) with the static
   `validateSessionName(String name)` validator (Rule 7): returns a localized-error
   *key* string (`'empty'` / `'tooLong'` / `'controlChar'`) or `null`; trims before
   the empty check; length limit 100 code units (NFR Requirements-approved Q7
   recommendation from Functional Design); control-character check covers
   U+0000–U+001F and U+007F anywhere in the untrimmed string.
2. [x] `lib/src/models/broadcaster_session_state.dart` (+ `.freezed.dart`) — sealed
   `BroadcasterSessionState` with variants `OfflineState`, `StartingState`,
   `LiveState(LiveBroadcast broadcast)`, `EndingState`,
   `BroadcastFailedState(BroadcastFailure reason)` (`domain-entities.md`). `build()`
   returns `OfflineState`.
3. [x] `lib/src/models/live_broadcast.dart` (+ `.freezed.dart`) — `LiveBroadcast`
   (8 fields: `broadcastId`, `url`, `sessionId`, `sessionName`, `captionActivity`,
   `viewers`, `maxViewers`, `startedAt`).
4. [x] `lib/src/models/broadcast_failure.dart` — `BroadcastFailure` enum
   (`signedOut`, `signalingUnavailable`, `relayUnavailable`, `identityUnavailable`,
   `unknown`), fixed at Application Design, not yet materialized as a file by any
   prior unit.

### `packages/zip_core/` — services

5. [x] `lib/src/services/caption/captioning_starter.dart` — `CaptioningStarter`
   interface (`CaptionActivity get currentActivity`; `Future<void> start()`) +
   `DefaultCaptioningStarter` wrapping `RecordingStateNotifier`'s `RecordingState`
   via the same `_mapActivity` mapping `RemoteBroadcastTarget` already uses
   (`active`/`paused`/`inactive`); `start()` is a no-op unless `currentActivity ==
   inactive` (mirrors `RecordingStateNotifier`'s own guard — do not duplicate logic,
   just read its state and delegate the call).
6. [x] `lib/src/providers/captioning_starter_provider.dart` (riverpod_generator,
   keepAlive) — `captioningStarterProvider`, default value
   `DefaultCaptioningStarter(ref.read(recordingStateNotifierProvider.notifier))` (or
   equivalent reading the current `RecordingStateNotifier` instance) + run
   `build_runner` for the `.g.dart`.
7. [x] `lib/src/services/broadcast/session_resources.dart` (public class
   `SessionResources` — Dart privacy is per-file, so a true `_`-prefixed
   class in its own file would be unreachable from
   `broadcast_session_notifier.dart`; "internal" here means simply never
   exported from `zip_core.dart`'s barrel, not language-level privacy) —
   `SessionResources` (NFR Design Q1): holds `StatusChannel statusChannel`,
   `ViewerAdmission admission`, `BroadcastTransport transport`,
   `RemoteBroadcastTarget target`, `StreamSubscription<CaptionActivity>
   activitySub`, `StreamSubscription<List<ViewerConnectionInfo>> viewersSub`; one
   method `Future<void> disposeAll(Logger log)` running the four teardown steps in
   order (status channel close → `registry.remove(target)` → `transport.stop()` →
   cancel both subscriptions), each individually wrapped in `try`/`on Object catch
   (e)` → `log.warning('...: ${e.runtimeType}')`, never rethrowing, never leaving a
   step unattempted because an earlier one threw.
8. [x] `lib/src/services/broadcast/broadcast_session_notifier.dart`
   (riverpod_generator, keepAlive) — `BroadcastSessionNotifier`:
   - `build()` → `OfflineState`.
   - `goLive()` implementing F-6.2/Rule 1/Rule 2 exactly: synchronous
     `state = StartingState()` before any `await` (Rule 1); pre-flight
     `BroadcastSettings.validateSessionName` check (no-op on invalid, per Rule 1
     step 0); the F2-1..F2-9 sequence against `authNotifierProvider`,
     `broadcastIdentityRepositoryProvider`, `iceServerProviderProvider` (fresh
     `sessionId` via `uuid`'s `Uuid().v4()`), a `broadcastTransportFactoryProvider`
     (new, see correction note below) wrapping `TransportSelector().broadcastTransport()`,
     `RemoteBroadcastTarget` + `registry.add`/`primeActivity`,
     `signalingServiceProvider.statusChannel(broadcastId).publishLive(...)`, the
     Rule 3 auto-start-captioning call, then constructing the initial
     `LiveBroadcast` (`startedAt: DateTime.now()`) and transitioning to `LiveState`,
     starting the two owned subscriptions into a freshly-built `_SessionResources`.
     On failure at any step: call `_SessionResources.disposeAll` (if any resources
     were created) then `state = BroadcastFailedState(reason)` per Rule 2's mapping
     table — unconditionally, as the last action, regardless of `disposeAll`'s
     per-step outcomes (NFR Requirements Q3 / NFR Design Q1).
   - `endBroadcast()` implementing F-6.6/Rule 5: no-op unless `LiveState`
     (idempotent from `EndingState`, no-op from any other state); `state =
     EndingState()`; `transport.sendToAll(const Ended())` then
     `transport.sendBroadcastEnded()` (Q5's additive method); `_SessionResources
     .disposeAll`; `state = OfflineState()` unconditionally afterward.
   - Private `_resources` field: `_SessionResources?`, non-null only between a
     successful `goLive()` and the start of its own disposal.
9. [x] `lib/src/services/broadcast/broadcast_settings_notifier.dart`
   (riverpod_generator, keepAlive) — `BroadcastSettingsNotifier`: `build()` reads
   both `SharedPreferences` keys (`broadcast.sessionName`, `broadcast
   .autoStartCaptioning`) via `ref.read(sharedPreferencesProvider)` (zip_core's own
   provider — matching `locale_provider.dart`'s/`wake_lock_settings_provider.dart`'s
   existing idiom, not `zip_broadcast`'s separate `SharedPreferences.getInstance()`
   pattern), falling back to `BroadcastSettings`'s defaults; `updateSessionName`/
   `setAutoStartCaptioning` persist immediately on write.

**Correction found during Step 8's implementation**: an initial
`transportSelectorProvider` (returning `TransportSelector` directly) turned out to be
untestable — `TransportSelector.broadcastTransport()`'s declared return type is the
concrete `WebRtcBroadcastTransport` (fixed shape, Unit 5), not the `BroadcastTransport`
interface, so overriding that provider in a test could never substitute a
`FakeBroadcastTransport`. Replaced with `lib/src/providers/broadcast_transport_factory_provider.dart`
— `broadcastTransportFactoryProvider`, declared to return `BroadcastTransport
Function()` (the real closure still just calls `TransportSelector().broadcastTransport()`;
no cast needed, only a wider declared type on the provider itself). Does not touch
`transport_selector.dart` (Unit 5's shipped file) at all — purely a new, additive
provider in this unit.

### `packages/zip_core/` — additive changes to Unit 5's shipped files

10. [x] `lib/src/services/caption/remote_broadcast_target.dart` — add
    `void primeActivity(CaptionActivity activity)`: sets `_currentActivity =
    activity` directly, with **no** `activityChanges` emission (this seeds the
    initial value before any viewer has joined or any real state-change event has
    fired — emitting here would be a spurious change notification with no prior
    value to compare against). No change to the existing constructor or any other
    method.
11. [x] `lib/src/services/webrtc/broadcast_transport.dart` — add
    `Future<void> sendBroadcastEnded();` to the `BroadcastTransport` interface.
12. [x] `lib/src/services/webrtc/web_rtc_broadcast_transport.dart` — implement
    `sendBroadcastEnded()`: iterate `_sessions.values` where `connectedAt != null`
    and call `channel.send(const BroadcastEnded())` on each (mirrors `sendToAll`'s
    existing skip-unconfirmed-viewers logic, but through the signaling channel
    rather than the data channel — `SignalingMessage.BroadcastEnded` already exists,
    Unit 5 shipped, currently only referenced in `_handleViewerMessage`'s
    drop-if-received-from-a-viewer branch).

### `packages/zip_core/` — barrel export

13. [x] `lib/zip_core.dart` — add exports for `broadcast_settings.dart`,
    `broadcaster_session_state.dart`, `live_broadcast.dart`, `broadcast_failure.dart`,
    `captioning_starter.dart`, `captioning_starter_provider.dart`,
    `broadcast_session_notifier.dart`, `broadcast_settings_notifier.dart` (not
    `_session_resources.dart` — stays private to the `broadcast` services
    directory).

### `packages/zip_core/` — test helpers

14. [x] `test/helpers/fake_captioning_starter.dart` — `FakeCaptioningStarter
    implements CaptioningStarter` with a settable `currentActivity` and a
    `startCalls` counter.
15. [x] `test/helpers/fake_broadcast_session_collaborators.dart` — simple
    value-returning fakes for `BroadcastIdentityRepository` (`FakeBroadcastIdentityRepository`,
    settable return value or throw) and `IceServerProvider`
    (`FakeIceServerProvider`, same shape); a controllable `FakeBroadcastTransport
    implements BroadcastTransport` exposing manually-fireable `viewers`/
    `viewerJoined`/`viewerLeft` streams and settable `start()`/`sendBroadcastEnded()`
    call-recording (no real ack-timeout/admission logic — this unit's own tests
    drive `BroadcastSessionNotifier`'s sequencing, not Unit 5's transport behavior).
    Reuse Unit 5's `test/helpers/fake_signaling_service.dart` as-is for
    `SignalingService` — check its interface already covers `statusChannel`/
    `joinRequests`/`submitJoinRequest`/`sessionChannel` before writing anything new
    here (NFR Requirements Q1); only extend it in place if a method is missing,
    never fork a second divergent fake.

### `packages/zip_core/` — business logic unit testing

16. [x] `test/models/broadcast_settings_test.dart` — example-based tests for the
    three named `validateSessionName` categories (empty after trim, over 100 code
    units, embedded control character) plus the valid case, per PBT-10
    (complementary to the PBT suite below, not a replacement).
17. [x] `test/models/broadcast_settings_pbt_test.dart` — using
    `test/helpers/pbt.dart`'s `Glados`/`any` generators (this project's Dart-3
    shim for `glados`, per every prior unit's precedent): a generator producing
    adversarial session-name strings (empty/whitespace-only, exactly-at-100,
    101+, embedded control characters, Unicode, plain ASCII) and an invariant
    assertion that `validateSessionName` never returns more than one error
    category for a single input (PBT-03, NFR Requirements Q6).
18. [x] `test/services/broadcast/broadcast_session_notifier_test.dart` —
    example-based tests against the Step 15 fakes, covering: Rule 1 (no-op from
    non-idle states, concurrent `goLive()` calls, synchronous `StartingState`
    before the first await); each row of Rule 2's failure-mapping table with
    `disposeAll` verified called; Rule 3 (auto-start on/off, idle/non-idle
    `currentActivity`, `goLive()` unaffected by a `start()` failure); Rule 4
    (`primeActivity` called once per `goLive()` with the right value; subsequent
    activity changes come only from the owned subscription); Rule 5 (idempotent
    `endBroadcast()`, no-op from every other state, exactly-once disposal); Rule 6
    (status channel stays open across the whole `LiveState` lifetime, closed only
    on the two documented paths); F-6.7 (a second `goLive()` reuses the same
    `BroadcastId` but a fresh `sessionId`).
19. [x] `test/services/broadcast/broadcast_session_notifier_pbt_test.dart` — the
    model-based/stateful suite (PBT-06, NFR Requirements Q6): a simplified
    reference model mirroring `domain-entities.md`'s state diagram, generated
    sequences of `goLive`/`endBroadcast` calls against the real
    `BroadcastSessionNotifier` + Step 15 fakes, asserting the state machine only
    ever makes the documented transitions and that two consecutive `endBroadcast()`
    calls from `LiveState` end in the same state as one.
20. [x] `test/services/caption/remote_broadcast_target_test.dart` (existing file,
    modify in-place) — added a `primeActivity` group: sets `currentActivity`
    immediately without emitting on `activityChanges`, a subsequent real
    `onCaptionEvent`-driven change still emits normally afterward, and a
    newly-joined viewer's snapshot uses the primed value. 3 new tests, all
    passing.
21. [x] **Correction**: no `test/services/webrtc/web_rtc_broadcast_transport_test.dart`
    file exists — `WebRtcBroadcastTransport` is exercised only via the fake-pair
    integration harness. Added the `sendBroadcastEnded()` test to
    `test/integration/webrtc_transport_fake_pair_test.dart` instead (existing
    file, modify in-place), matching that file's own established pattern: a
    confirmed viewer (via the real `WebRtcViewerTransport`) and a pending,
    never-acked viewer, each observed through a bystander
    `FakeSessionSignalingChannel` on the same topic — confirms the confirmed
    viewer receives a `BroadcastEnded` and the pending one never does. 1 new
    test, passing (26 total in the file, 0 regressions).
22. [x] `test/services/caption/captioning_starter_test.dart` — `DefaultCaptioningStarter`'s
    mapping matches `RemoteBroadcastTarget._mapActivity` exactly for every
    `RecordingState` variant; `start()` calls through only when idle.

### `packages/zip_core/` — business logic summary

23. [x] `aidlc-docs/construction/broadcast-ui/code/unit6-zip-core-summary.md`
    (markdown only) — lists every file created/modified in Steps 1–22, final test
    counts, `dart analyze --fatal-infos` result.

### `packages/zip_broadcast/` — l10n

24. [x] `l10n/arb/app_en.arb` — add every new user-facing string this unit needs
    (session-name field label + the three validation-error messages; Go Live
    button label + progress state; the signed-out overlay copy; the stable-URL
    row + copy-to-clipboard action/confirmation; each F-6.4 banner-matrix string
    — captions-never-started, captions-stopped, captions-paused; the
    broadcast-full banner; the Duration/viewer-count/connection-type dashboard
    labels; the End Broadcast action + confirmation; the Rule 9 sign-out-refused
    snackbar text) — **edit this file directly, never the generated
    `zip_broadcast_localizations*.dart` files**. Then run `flutter gen-l10n`
    (per `l10n.yaml`) to regenerate.

### `packages/zip_broadcast/` — frontend components

25. [x] `lib/src/shell/zb_app_shell.dart` (existing file, modify in-place) — new
    `ZbSignOutScope extends InheritedWidget` (Functional Design Q6) exposing
    `Future<void> requestSignOut(BuildContext context)` (static lookup helper,
    matching Flutter's standard `InheritedWidget.of(context)` convention) backed
    by `_ZbAppShellState`'s own method: reads
    `ref.read(broadcastSessionNotifierProvider)` and, in the **same synchronous
    span** (NFR Design Q2 — no `await` between the read and the act), either
    calls `ref.read(authNotifierProvider.notifier).signOut()` (from
    `OfflineState`/`BroadcastFailedState`) or shows the refusal
    `ScaffoldMessenger` snackbar (from `StartingState`/`LiveState`/`EndingState`)
    and returns without calling `signOut()`. `ZbAppShell.build()` wraps
    `widget.child` in this new `InheritedWidget`.
26. [x] `lib/src/screens/account_section.dart` (existing file, modify in-place)
    — `_SignedInCard`'s sign-out button `onPressed` switches from
    `ref.read(authNotifierProvider.notifier).signOut()` to
    `ZbSignOutScope.requestSignOut(context)`.
27. [x] `lib/main.dart` (existing file, modify in-place) — add
    `captioningStarterProvider.overrideWith(...)` to the `ProviderScope.overrides`
    list, backed by a `BroadcastRecordingNotifier`-wrapping implementation
    (mirrors the existing `authServiceProvider` override immediately above it).
28. [x] `lib/src/screens/broadcast_screen.dart` (new file) — `BroadcastScreen`
    (one route, Functional Design Q8): reads `broadcastSessionNotifierProvider`
    and switches its body between `_SetupView` (Offline/Starting/BroadcastFailed
    — the Proto-11 form: output-targets grid reusing the existing
    `OutputTargetsPanel`, session-name field bound to
    `broadcastSettingsNotifierProvider` with live `validateSessionName` inline
    errors, the signed-out overlay gated on `authNotifierProvider`, the stable
    URL row fetched once per mount via
    `broadcastIdentityRepositoryProvider.getOrCreateMine()` while signed in, the
    Go Live button calling `goLive()`) and `_LiveDashboardView` (Live/Ending —
    the Proto-12 dashboard: viewer count vs. `maxViewers`, the F-6.4 banner
    matrix read from `LiveBroadcast.captionActivity`, the broadcast-full banner,
    per-viewer rows rendering `ViewerConnectionInfo` as-is, the caption preview
    from `captionBusProvider`, the Duration stat card computed from `startedAt`,
    the Start/Pause/Resume captioning controls calling
    `broadcastRecordingNotifierProvider.notifier` directly, and the End
    Broadcast action calling `endBroadcast()`) — mirrors `SettingsScreen`'s
    existing `AnimatedSwitcher`-between-internal-views pattern rather than two
    separate route-level screen files. Every interactive element gets a stable
    `Key`/`data-testid`-style key (e.g. `Key('broadcast-go-live-button')`,
    `Key('broadcast-session-name-field')`, `Key('broadcast-end-button')`),
    matching `AccountSection`'s existing `Key('sign-in-...')` convention.
29. [x] `lib/src/routing/zb_router.dart` (existing file, modify in-place) — add
    `GoRoute(path: '/broadcast', builder: (_, _) => const BroadcastScreen())`
    inside the existing `ShellRoute`.
30. [x] `lib/src/shell/zb_nav_rail.dart` and `lib/src/shell/zb_nav_drawer.dart`
    (existing files, modify in-place) — add one new destination (icon:
    `Icons.podcasts`, matching `AccountSection`'s existing icon choice for the
    broadcast feature) routing to `/broadcast`, alongside the existing Home/
    Recording/History entries. Does not touch either widget's existing
    `isBroadcastActive` parameter (that name refers to Phase 1's local
    multi-engine recording state, a pre-existing and unrelated usage — Rule 9
    this unit is not Rule 9's own `BroadcasterSessionState`).

### `packages/zip_broadcast/` — frontend component testing

31. [x] `test/helpers/zb_test_harness.dart` (existing file, modify in-place) —
    add the `/broadcast` route to `buildZbApp`'s router, matching
    `zb_router.dart`'s Step 29 addition exactly (keeps the two route tables from
    drifting apart, the existing convention every prior route addition in this
    file already follows).
32. [x] `test/screens/broadcast_screen_test.dart` (new file) — one widget test
    per approved Proto-11/Proto-12 state reachable via `ProviderScope` overrides
    on `broadcastSessionNotifierProvider`/`broadcastSettingsNotifierProvider`
    (NFR Requirements Q2): signed-out overlay; each of the three
    `validateSessionName` error categories plus the valid case rendered inline;
    the Go Live progress spinner (`StartingState`); each F-6.4 banner-matrix row;
    the broadcast-full banner; the viewer list render; a `BroadcastFailedState`
    retry affordance. No golden-image tests (NFR Requirements Q2 — this project
    has none today).
33. [x] `test/widgets/account_section_test.dart` (existing file, modify
    in-place) — the sign-out button test now asserts it calls through
    `ZbSignOutScope.requestSignOut` rather than `authNotifierProvider.notifier
    .signOut()` directly; add this screen's test harness wraps `AccountSection`
    in a real `ZbAppShell` (or the minimal `ZbSignOutScope` ancestor it needs)
    rather than only a bare `ProviderScope`, since the guard now lives one level
    up.
34. [x] `test/shell/zb_app_shell_test.dart` (new file — confirmed no existing
    test file for `ZbAppShell` today) — the Rule 9 guard itself: `requestSignOut()` calls `signOut()` from
    `OfflineState`/`BroadcastFailedState`; refuses (no `signOut()` call, snackbar
    shown) from `StartingState`/`LiveState`/`EndingState`; the NFR Design Q2
    no-await-between behavior (state check and act happen before any other
    scheduled call, e.g. a concurrently-dispatched `goLive()`, can run).

### `packages/zip_broadcast/` — frontend component summary

35. [x] `aidlc-docs/construction/broadcast-ui/code/unit6-zip-broadcast-summary.md`
    (markdown only) — lists every file created/modified in Steps 24–34, final
    test counts, `dart analyze --fatal-infos` result, widget-test state coverage
    mapped against S-17's acceptance criteria.

### Documentation Generation

36. [x] Update `aidlc-docs/aidlc-state.md`'s Unit 6 entry and Backlog as
    generation proceeds (per the per-unit loop's standing requirement — not a
    separate deliverable file).

## Deployment Artifacts

None. No new build target, CI job, or infrastructure change — this unit's two
packages already build/test in the existing pipeline unchanged.

## Story Traceability

All steps implement S-17 (acceptance criteria AC1–AC11, mapped explicitly in Steps 18
and 32's test lists above). No other story is touched by this unit.
