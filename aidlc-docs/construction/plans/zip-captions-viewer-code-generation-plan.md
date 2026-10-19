# Code Generation Plan: Zip Captions Viewer (Unit 7)

**Prior stage**: NFR Design, approved 2026-10-18 (unattended run; pre-approved
per `.agent/overnight-pipeline.md` A2, subject to morning review). Infrastructure
Design skipped (no infrastructure change in this unit).

**Story**: S-19. **Branch**: `feature/zip-captions-viewer` (off `develop` at
`63f7d42`; head at plan time `623bd44`).

**Run mode**: unattended. This plan is self-approved on write:
`approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-18) —
subject to morning review`. Part 2 executes this plan step by step.

## Scope

Everything fixed at Application Design (`phase2-component-methods.md` §6/§8,
`phase2-components.md` §8) and elaborated by this unit's FD / NFR Requirements /
NFR Design stages: the additively extended `ConnectFailure`, the new
`broadcastBaseUrl` constant with `BroadcastLink.baseUrl` removed, the sealed
10-variant `ViewerSessionState`, `ReconnectPolicy`, `ViewerSessionResources`,
`ViewerSessionNotifier` (three added getters, `_sessionEpoch`, `ref.onDispose`),
`viewerTransportFactoryProvider`, the two `zip_captions` screens, the `/join`
(in-shell) and `/b/:broadcastId` (out-of-shell) routes, `ViewerStatusRegion` +
`viewerAnnouncerProvider`, `ZcStrings`, the viewer ARB entries, and the
drawer/home affordances. `zip_core` + `zip_captions` — no `zip_supabase`
migration, no new dependency, no `docs/` change.

**Not in scope (hard fences, from the run configuration and FD constraints)**:
- Web: no `packages/zip_captions/web/`, no web CI job, no SECURITY-04 headers.
  The two S-19 web ACs stay deferred to Phase 5 (`aidlc-state.md`).
- No new dependency in either package. A dependency need is a BLOCKED condition.
- No `dart:io`, `dart:html`, platform-channel or native-only import in the
  viewer path (notifier, resources, screens, viewer providers, status region).
- No change to any shipped Unit 2/3/3.1/4/5/6 component's behaviour. The only
  edits to existing `zip_core` files are `connect_failure.dart` (three additive
  variants) and `broadcast_link.dart` (constant interpolation, `baseUrl`
  deleted); the only shipped `zip_captions` edits are the router, the shell's
  `_screenTitle`, the drawer, the home screen and the ARB.
- `@Tags(['integration-supabase'])` tests are not enabled. The local Supabase
  stack and Docker are not started.
- `packages/zip_broadcast` is untouched: its two `toUrl` call sites keep
  compiling and behaving identically (verified, Step 4).
- `docs/` untouched. `packages/zip_broadcast/macos/Podfile.lock` never staged.

## Verification performed before writing this plan (2026-10-18)

Every load-bearing claim below was checked against the source on this branch,
not assumed from the handoffs:

| Claim | Verified against |
|---|---|
| `ConnectFailure` still has **four** variants (`BroadcastFull`, `IceFailed`, `SignalingRejected`, `Timeout`) — all three new variants are unwritten work | `lib/src/models/connect_failure.dart` |
| `BroadcastLink.baseUrl` is still the hardcoded v1 apex; `toUrl` is its only reader | `lib/src/models/broadcast_link.dart` |
| `BroadcastLink.toUrl` callers: `BroadcastSessionNotifier` (`LiveBroadcast.url`), `zip_broadcast/lib/src/screens/broadcast_screen.dart:262`, and three test files. No `baseUrl` consumer outside `toUrl` → deleting `baseUrl` breaks no call site | repo-wide grep |
| `ViewerSessionNotifier`, `ViewerSessionState`, `ReconnectPolicy`, `viewerTransportFactoryProvider`, `broadcast_link_config.dart`, `ZcStrings`, both screens, `viewerAnnouncerProvider`, `ViewerStatusRegion` do **not** exist | file listing of `zip_core/lib/src` and `zip_captions/lib` |
| `TransportSelector.viewerTransport()` returns the concrete `WebRtcViewerTransport` → the factory seam is required | `lib/src/services/webrtc/transport_selector.dart` |
| `session_resources.dart` is the Unit 6 holder precedent (plain class, per-step `try`/`on Object` → `${e.runtimeType}`, package-internal); the viewer holder needs `Timer` + status-watch fields it lacks | `lib/src/services/broadcast/session_resources.dart` |
| `status_channel.dart` exposes `watch()`/`close()`; `broadcast_status.dart` is `live(sessionId, sessionName)`/`offline()`; `broadcast_resolution.dart` has five variants | those files |
| `RemoteCaptionReceiver` exposes `activity`/`ended`/`dispose`; `OnScreenCaptionTarget` takes `repository` nullable; `CaptionOutputTargetRegistry.remove()` disposes the target; bus/registry/target `dispose()` are synchronous | `lib/src/services/caption/`, `lib/src/output/` |
| `defaultBroadcastLimits` = 50 / 60s / 120s | `lib/src/constants/broadcast_limits_default.dart` |
| `iceServerProviderProvider` / `signalingServiceProvider` / `broadcastResolverProvider` exist under those names | `lib/src/providers/` |
| `test/helpers/pbt.dart` API: `Generator<T> = T Function(Random)`, `any.choose/boolGen/intInRange/listWithLengthInRange/combine*`, `Glados(gen).test(desc, dynamic Function(T) body)` with **100 fixed seeds**, body awaited, no shrinking; `arbitraryBroadcastId`, `arbitraryValidBroadcastIdString`, `arbitraryLinkInput` already exist | `test/helpers/pbt.dart`, `test/helpers/generators.dart` |
| `FakeStatusChannel`/`FakeBroadcastSignalingService`/`FakeIceServerProvider` exist and are reusable; `FakeBroadcastResolver`/`FakeViewerTransport` do not | `test/helpers/fake_broadcast_session_collaborators.dart` |
| `zc_router.dart` is one `ShellRoute` (`/`, `/recording`, `/settings`, `/history/:sessionId`); `ZcAppShell._screenTitle`/`_railIndex` are the two maps to extend; the drawer has four entries | those files |
| Nothing in `zip_captions` reads `app_en.arb`; `ZcStrings` will be its first reader | grep of the ARB keys |
| `zip_captions` dev deps: `flutter_test`, `build_runner`, `drift`, `riverpod_generator`, `very_good_analysis` — **no `fake_async`, no `mocktail`** | `packages/zip_captions/pubspec.yaml` |
| `DisplaySettingsNotifier` is a hand-written `NotifierProvider` over `BaseSettingsNotifier`; `displaySettingsProvider` needs a `SharedPreferences` override in widget tests; `transcriptWriterTargetProvider` is overridden to `(_) {}` in every existing widget harness | `providers/settings_notifier.dart`, widget tests |
| `RecordingScreen`'s route-reentry idiom is a `ConsumerStatefulWidget` + `addPostFrameCallback` | `screens/recording_screen.dart` |
| Precedent for a notifier subclass in a widget test: `FakeRecordingStateNotifier extends RecordingStateNotifier` (constructor-arg initial state) | `zip_captions/test/helpers/fake_recording_state_notifier.dart` |
| `aidlc-docs/audit.md` currently ends at the NFR Design entry; `aidlc-docs/aidlc-state.md`'s "Current Stage" still says "next: Code Generation Part 1" | both files |
| Unit 6's Part 1 produced **no** `construction/{unit}/code/` artifact (the `code/` directory holds only Part 2's two summaries) — precedent: match it, no Part 1 summary file | `aidlc-docs/construction/broadcast-ui/code/` |

Two verified findings that shape the plan:

1. **`_resources` field-set correction (implementation detail, not a design
   change).** The NFR Design handoff's prose says `ViewerSessionResources` holds
   12 fields and `disposeAll` nulls them; `nfr-design-patterns.md`'s field list
   actually lists **14** (it includes `lastStatus`, the F-7.4 audit trail) —
   the 14-entry list is authoritative. Second, a required final field cannot be
   nulled to represent "released" (`null` assigned to a `final` field is a
   compile error), so every released-representable field is declared
   `T?`/`late`-less nullable and assigned `= null` after its step runs. Part 2
   implements the 14-field nullable shape; this is recorded under ASSUMPTIONS
   in the stage report, not a behaviour change.
2. **`fakeAsync` cannot drive `RealtimeChannel`-free async awaits in
   `zip_captions`** — there is no `fake_async` dependency there, and the widget
   tests do not need one (NFR Requirements Q2: the screen is tested against a
   fake notifier, and the reconnect copy is an example state, not a clock
   test). Only `zip_core` (which already has `fake_async` as a dev dependency)
   wraps Glados trials in `fakeAsync`.

## Ordering rationale

The sequence is bottom-up so every step's test can be written against code that
already exists, and so no step depends on a later one:

1. **Contracts first** (Steps 1-2, 3-5): constants, model edit, additive
   `ConnectFailure` variants, `BroadcastLink` change. Everything downstream
   imports these; changing them later would ripple through every test.
2. **Pure logic next** (Steps 6-7): `ReconnectPolicy` (no clock, no I/O) and
   `viewerTransportFactoryProvider` (mirrors the Unit 6 factory). Both are
   independently testable with zero fakes.
3. **Holder before notifier** (Step 8 before Step 9-10): the notifier's
   teardown is only real once `ViewerSessionResources` exists.
4. **`zip_core` unit + PBT suites before `zip_captions`** (Steps 11-21 before
   22+): the screens read the notifier, so the notifier's behaviour must be
   pinned by its own suites first. Within `zip_core`, the example suite precedes
   the stateful PBT (the PBT reuses the fakes the example suite introduced and
   the transition table the example suite validates row by row).
5. **`ZcStrings` + ARB before the screens** (Step 24 before 25-27): the screens
   render ARB values; a sentinel-based test needs the reader in place.
6. **Widget tests last, after routes** (Steps 28-37): each widget test mounts
   the real screen through a real router, so the route table must exist first.
7. **Docs/audit/state last** (Steps 38-39): only after the gates pass.

## Steps

### `packages/zip_core/` — constants and model contracts

1. [ ] `lib/src/constants/broadcast_link_config.dart` (new) — `const
   broadcastBaseUrl = String.fromEnvironment('BROADCAST_BASE_URL',
   defaultValue: 'https://zipcaptions.app/b/');` with a doc comment that names
   the `supabase_config.dart` / `turn_config.dart` precedent, states that the
   default preserves current v1/local-dev behaviour byte-for-byte, and records
   Q9 guardrail 3 (release builds supply the v2 subdomain via `--dart-define`;
   the v2 host name appears nowhere in source). Add the export to
   `lib/src/constants/constants.dart` (the barrel `zip_core.dart` already
   re-exports it).
   *Test*: none of its own — exercised by Step 11's configured-base PBT row and
   by the existing `broadcast_session_notifier` tests (default unchanged).

2. [ ] `lib/src/models/connect_failure.dart` (existing, modify in place) — add
   three `final class`es only, matching the shipped four's hand-written
   `==`/`hashCode`/const-constructor idiom exactly: `RateLimited` (Kong 429
   from `resolve_broadcast_id`), `ResolutionFailed` (resolution / presence-read
   error, and window expiry with no status emission), `NotFound` (the code
   does not exist). Do **not** touch `BroadcastFull`/`IceFailed`/
   `SignalingRejected`/`Timeout` or the class-level doc comment's "four
   variants" claim — amend that one sentence to "seven variants" and cite
   Rule 5. The `@immutable sealed class` stays `sealed`; the new classes stay
   in the same file (a `sealed` subclass must sit in the same library).
   *Test*: Step 12 (`connect_failure_test.dart` — equality, variant identity,
   and a `switch` exhaustiveness compile check).

3. [ ] `lib/src/models/broadcast_link.dart` (existing, modify in place) — delete
   `static const String baseUrl`; `toUrl` becomes
   `Uri.parse('$broadcastBaseUrl${id.value.toLowerCase()}')` with a
   `package:zip_core/src/constants/broadcast_link_config.dart` import.
   `parseInput` is **not** touched (host-agnostic; the FD says explicitly it
   stays that way). Update the class doc comment to say the base is build-time
   configuration (Rule 11).
   *Test*: Step 13 extends `test/pbt/broadcast_link_test.dart`.

4. [ ] Verify the three `zip_broadcast`/`zip_core` `toUrl` call sites need **no**
   change: `BroadcastSessionNotifier` line 174 (imports the model, not
   `baseUrl`), `zip_broadcast/lib/src/screens/broadcast_screen.dart:262`, and
   the three test files. Confirm with `grep -rn "baseUrl" packages` returning
   only `broadcast_link_config.dart`, `supabase_config.dart` and
   `turn_config.dart` (the last two are `supabaseUrl`/`iceServerUrls`
   matches). If any real `BroadcastLink.baseUrl` consumer appears, that is a
   BLOCKED finding for morning review — do not edit `zip_broadcast`. This step
   produces no file change; it is the checkpoint that keeps the
   "one existing file edited in zip_core's models" claim honest.

### `packages/zip_core/` — models

5. [ ] `lib/src/models/viewer_session_state.dart` (new, freezed) — sealed
   `ViewerSessionState` with the **10 fixed variants** in this exact shape:
   `idle()` → `IdleState`, `resolving()` → `ResolvingState`,
   `connecting()` → `ConnectingState`,
   `liveView({required CaptionActivity captionActivity, required
   ConnectionType connectionType})` → `LiveViewState`, `reconnecting()` →
   `ReconnectingState`, `notBroadcasting()` → `NotBroadcastingState`,
   `ended()` → `EndedState`, `full()` → `FullState`,
   `cannotConnect(ConnectFailure reason)` → `CannotConnectState`,
   `invalidInput()` → `InvalidInputState`. Follow
   `broadcaster_session_state.dart`'s freezed idiom exactly (same
   `@freezed sealed class … with _$…`, same factory-named-after-variant
   convention; `freezed` is already a dependency). `InvalidInputState` carries
   no data (Rule 8 / SECURITY-05). Imports: `caption_event.dart`
   (`CaptionActivity`), `connection_status.dart` (`ConnectionType`),
   `connect_failure.dart`.
   *Test*: Step 12 (variant equality/`copyWith` and the "no caption content"
   assertion) and Step 19 (the stateful PBT's per-command expectations).

6. [ ] `lib/src/models/reconnect_policy.dart` (new, plain class — not freezed) —
   `class ReconnectPolicy { const ReconnectPolicy(); Duration? nextDelay(int
   attempt, Duration elapsed); }` with the FD's fixed signature and window
   semantics: `reconnectWindow - elapsed` while `> Duration.zero`, `null` once
   `elapsed >= reconnectWindow` (window =
   `defaultBroadcastLimits.reconnectWindow`, read from the constant, not
   passed in — the fixed signature carries only `attempt`/`elapsed`).
   `attempt` is documented as retained-but-unconsulted (fixed shape; the
   shipped transport owns the cadence, Rule 3). No clock, no `Timer`, no I/O.
   *Test*: Step 14 (example suite + one invariant row).

7. [ ] `lib/src/providers/viewer_transport_factory_provider.dart` (new) —
   `@Riverpod(keepAlive: true) ViewerTransport Function() viewerTransportFactory(Ref
   ref) => () => const TransportSelector().viewerTransport();` mirroring
   `broadcast_transport_factory_provider.dart` line for line, with the same
   "declared return type is the interface, not the concrete class" doc
   rationale. Run `build_runner` to produce `.g.dart`.
   *Test*: indirectly only. The provider is always overridden in the Step 17-20
   suites (`viewerTransportFactoryProvider.overrideWithValue(() =>
   fakeTransport)`); the default body (`TransportSelector().viewerTransport()`)
   is never invoked by any test, because doing so constructs a real
   `WebRtcViewerTransport` and is the kind of native-stack contact NFR
   Requirements keeps out of the suite. Its correctness is the one-line body
   mirroring `broadcast_transport_factory_provider.dart` (reviewed by
   inspection); the omission of a direct assertion is recorded in Part 2's
   summary.

### `packages/zip_core/` — services

8. [ ] `lib/src/services/broadcast/viewer_session_resources.dart` (new, public
   class, **not** exported from any barrel — same treatment as Unit 6's
   `SessionResources`) — `ViewerSessionResources` with the 14 fields from
   `nfr-design-patterns.md` (`broadcastId`, `sessionId`, `transport`,
   `receiver`, `bus`, `registry`, `target`, `statusChannel`, `statusWatch`,
   `statusSub`, `activitySub`, `endedSub`, `windowTimer`, `lastStatus`), every
   teardown-representable one declared nullable so "released == null field"
   holds. One method `Future<void> disposeAll(Logger log, {bool
   releaseTransport = true})` running F-7.7's steps **in order** — cancel
   `windowTimer` → cancel `statusWatch` → `await statusChannel.close()` →
   (`releaseTransport ? await transport.disconnect() : skip`) →
   `receiver.dispose()` → `registry.remove(target)` → `registry.dispose()` →
   `bus.dispose()` — each inside its own `try`/`on Object catch (e)` logging
   `${e.runtimeType}` only, never `toString()`, never throwing, nulling the
   released field after each step so a second call is a no-op. `disposeAll`
   never touches the notifier's `_resources` (single-writer rule).
   *Test*: Step 16 (per-step catch-and-continue, second-call no-op, release-
   transport flag).

9. [ ] `lib/src/services/broadcast/viewer_session_notifier.dart` (new,
   riverpod_generator, keepAlive) — `ViewerSessionNotifier`:
   - `build()` → `const ViewerSessionState.idle()`, and
     `ref.onDispose(leave)` (the NFR Design Q8 divergence from Unit 6 — the
     only hook the broadcaster notifier does not have).
   - `join(String input)` implementing F-7.2 in order: (1) `parseInput`; `null`
     → active-session no-op (log the input's integer length only, never the
     string) or `InvalidInputState` when idle/terminal; (2) implicit
     `await leave()` when `currentBroadcastId != null` and differs; (3)
     `_sessionEpoch++`, state → `ResolvingState`, epoch check,
     `await resolve(id)`; (4) map the five resolution variants per F-7.2's
     table (Step 5 of this plan's ordering: `NotFound` → `CannotConnect`
     terminal, `rateLimited`/`resolutionFailed` likewise, `offline` →
     `NotBroadcasting` + watch, `live` → continue); (5) epoch check, then —
     only from `live`/`offline` — build the holder
     (`OnScreenCaptionTarget(targetId: 'viewer', repository: null)`, a fresh
     `CaptionBus`/`CaptionOutputTargetRegistry`, `RemoteCaptionReceiver`,
     the factory transport, `signalingServiceProvider.statusChannel(id)` and
     its `watch()` subscription, the transport `status` subscription, the
     receiver `activity`/`ended` subscriptions); (6) `offline` stops there;
     `live` sets `ConnectingState`, fetches `iceServersFor(sessionId)` (catch
     → `CannotConnect(IceFailed)`), builds `ViewerTransportContext`, `await
     transport.connect(context)` (catch → `CannotConnect(IceFailed)` — never
     `Timeout`).
   - `leave()` implementing F-7.7: idempotent (`_resources == null` → if
     already `Idle` return, else `_setState(idle)`); `_sessionEpoch++`,
     `await _resources.disposeAll(_log)` (default `releaseTransport: true` —
     see the deviation note below), clear `_resources`/`sessionName`/
     `currentBroadcastId`, `_setState(idle)` last.
   - `_setState(ViewerSessionState next)` — the **only** state writer; cancels
     `holder.windowTimer` whenever `next is! ReconnectingState`, then assigns.
   - `_terminate(ViewerSessionState next)` — `await disposeAll(log,
     releaseTransport: true)`, null the released fields, `_setState(next)`
     last and unconditional (a throwing `disconnect()` cannot leave a
     terminal state unreached).
   - Status subscription handler per F-7.2 step 6 / F-7.4: `Connected(t)` →
     cancel window → `LiveViewState(_lastActivity, t)`; `Interrupted` →
     `_enterReconnecting()`; `Failed(BroadcastFull)` → `_terminate(full)`;
     `Failed(f)` → `_terminate(cannotConnect(f))`.
   - Activity handler: `_lastActivity = a`; in `LiveViewState`, in-place
     `copyWith`. Ended handler → `_terminate(ended)`. Status-watch handler per
     Rule 4's scoped split (Reconnecting + offline → immediate
     `NotBroadcasting`; LiveView + offline → no-op; NotBroadcasting + live →
     F-7.8 auto-join steps 5-6 without re-resolving; NotBroadcasting +
     offline → no-op); every handler writes `holder.lastStatus` first.
   - `_onWindowExpired()` per F-7.4 step 4's **three** outcomes: last
     `offline` → `NotBroadcasting`; no emission ever → `CannotConnect(
     ResolutionFailed)`; last `live` → `await transport.disconnect()` →
     `CannotConnect(IceFailed)`. Epoch-checked.
   - `_enterReconnecting()` — cancel/restart the single `Timer(
     defaultBroadcastLimits.reconnectWindow, …)` in the holder, `_setState(
     reconnecting)`. No `restart()` call anywhere (Rule 3/14).
   - Getters: `CaptionBus? get viewerBus`, `OnScreenCaptionTarget?
     get viewerCaptionTarget`, `String? get sessionName`, `BroadcastId?
     get currentBroadcastId`.
   - Logging: a `static final _log = Logger('zip_core.ViewerSessionNotifier')`;
     state names/reasons/IDs/runtime types only (Rule 8, NFR Q5).
   *Test*: Steps 17-19.
   *Deviation to record in Part 2's summary*: F-7.7's text has `leave()`
   calling the no-named-argument form and the exit matrix (F-7.2 step 2, Rule
   1) says a different-broadcast `join()` leaves first — i.e. `leave()` is an
   explicit user/route exit and must release the transport. The no-argument
   default therefore stays `releaseTransport: true`; the flag exists so the
   terminal-transition path (which already released it, leaving the field
   null) can call the same helper with `true` and skip the null field, and so a
   future partial-release path has one place to say `false`. This is the
   NFR Design's intent, stated here so Part 2 does not invent a
   "leave keeps the connection" reading.

10. [ ] `lib/src/services/broadcast/broadcast.dart` and `lib/src/models/models.dart`
    barrels — add `viewer_session_notifier.dart` (service barrel) and
    `viewer_session_state.dart` + `reconnect_policy.dart` (models barrel). **Do
    not** export `viewer_session_resources.dart` (package-internal, matching
    Unit 6) and do not export `broadcast_link_config.dart` from the models
    barrel (it is a constant; it goes through `constants.dart` in Step 1).
    Run `build_runner` once after Steps 5-9 (`dart run build_runner build
    --delete-conflicting-outputs`) so `.freezed.dart`/`.g.dart` land before any
    test is written.

### `packages/zip_core/` — test helpers and unit/PBT suites

11. [ ] `test/helpers/generators.dart` (existing, append) — the Unit 7
    generators, built only from `pbt.dart`'s real API:
    - `arbitraryViewerSessionCommandSequence` + a sealed
      `ViewerSessionCommand` hierarchy: `JoinCommand({bool invalid,
      bool differentBroadcast, bool throwsOnConnect})`,
      `StatusChannelEventCommand({bool live})`, `TransportStatusCommand`
      (sub-kinds `Connected`/`Interrupted`/`Failed(f)` over all seven
      `ConnectFailure` variants), `ActivityCommand(CaptionActivity)`,
      `EndedCommand`, `WindowExpiryCommand` (advances the `fakeAsync` clock
      past the window), `LeaveCommand`. Weighted so leave (~20%), join
      (~20%), transport events (~25%), status events (~15%), expiry (~10%),
      activity/ended (~10%) are all reachable, length 0-20 including empty —
      mirroring `arbitraryBroadcastSessionCommandSequence`'s weighting
      comment style.
    - `arbitraryConnectionType` (`any.choose(ConnectionType.values)`) and
      `arbitraryCaptionActivity` (`any.choose(CaptionActivity.values)`).
    - `arbitraryConfiguredBase(Random)` — a small set of realistic bases
      (`https://zipcaptions.app/b/`, `https://v2.zipcaptions.app/b/`,
      `http://localhost:8080/b/`) for PBT-02's "configured base" row. Because
      `broadcastBaseUrl` is a compile-time `const`, the configured-base row
      is *derived*: the test asserts `parseInput` recovers the id from a URL
      built with each base string independently, and that the default
      constant equals the v1 apex.
    *Test*: consumed by Steps 13, 18, 19, 20; no test of its own (Unit 6's
    generator precedent has none).

12. [ ] `test/helpers/fake_broadcast_session_collaborators.dart` (existing,
    append — no parallel file) —
    - `FakeBroadcastResolver implements BroadcastResolver`: a scripted
      result queue plus a default, `resolveCalls` (and `resolveIds`), an
      optional `error` that is **never** thrown (the real resolver is total —
      the fake maps an `error` to `resolutionFailed`, which documents the
      contract rather than letting a test accidentally rely on a throw).
    - `FakeViewerTransport implements ViewerTransport`: `connect`/`restart`/
      `disconnect` counters, `startedWith` context, `emitStatus`/
      `emitMessage` helpers, a `connectError` thrown **after** recording the
      call, a `disconnectError` that still records the call, and
      `restartCalls` (must stay 0 in every suite — Rule 3/14's assertion).
    - No new fake for `StatusChannel`/`SignalingService`/`IceServerProvider`
      — reuse the shipped `FakeStatusChannel`/`FakeBroadcastSignalingService`/
      `FakeIceServerProvider`.
    *Test*: Steps 17-20; the fake's controls are exercised by the tests
    themselves (no separate fake test — the Unit 6 precedent).

13. [ ] `test/pbt/broadcast_link_test.dart` (existing, extend) — add the PBT-02
    rows required by the FD's Testable Properties:
    - existing `toUrl → parseInput` round-trip stays (it now exercises the
      default `broadcastBaseUrl`);
    - "configured base" row: `parseInput(<base> + id.value.toLowerCase())
      == id` for every generated base in `arbitraryConfiguredBase` (PBT-02,
      the "full `https://…` with the configured base" form);
    - bare-ID row: `parseInput(id.value) == id` and lower-cased form recovers
      the same canonical id;
    - invalid-input row: `parseInput` of a generated invalid string (wrong
      length, out-of-alphabet character, garbage scheme) is `null`;
    - a plain example test pinning `broadcastBaseUrl`'s default to
      `https://zipcaptions.app/b/` (the byte-identical-default guarantee, so a
      future env change is a deliberate edit).
    Uses only `pbt.dart`/`generators.dart`.

14. [ ] `test/models/reconnect_policy_test.dart` (new) — example suite per the
    NFR Design: positive remaining at `elapsed = 0` and mid-window, exactly at
    `reconnectWindow` → `null`, past it → `null`, `attempt` irrelevant (0 and
    99 agree), and a `Duration.zero` elapsed case; then **one invariant row**
    in the same file (`PBT-03` form): for `elapsed` in `0..window+60s`,
    `nextDelay` is non-null iff `elapsed < window`, and when non-null it
    equals `window - elapsed`. Small enough not to warrant its own PBT file
    (NFR Design's explicit "one invariant row").

15. [ ] `test/models/connect_failure_test.dart` (new) — all seven variants:
    value equality (`const RateLimited() == const RateLimited()`), cross-variant
    inequality, `hashCode` consistency, and an exhaustive `switch` statement
    over a `ConnectFailure` variable that names every variant (the "Rule 5's
    mapping is exhaustive" compile-time pin; if a variant is later added the
    file stops compiling).

16. [ ] `test/services/broadcast/viewer_session_resources_test.dart` (new) —
    against hand-built real objects (a `FakeViewerTransport`, a real
    `RemoteCaptionReceiver` over a fake transport, a real `CaptionBus`/
    registry/`OnScreenCaptionTarget`, a `FakeStatusChannel`): steps run in
    order (record the sequence via the fakes' counters); each step's failure
    is caught and logged (a throwing `disconnectError`/`close` does not skip
    `receiver.dispose()`/`registry.remove`); `releaseTransport: false` skips
    `disconnect`; a second `disposeAll` is a no-op; `disposeAll` never throws.

17. [ ] `test/services/broadcast/viewer_session_notifier_test.dart` (new, the
    main example suite) — `ProviderContainer` overrides:
    `broadcastResolverProvider`, `signalingServiceProvider` (a
    `FakeBroadcastSignalingService` wrapping a `FakeStatusChannel`),
    `iceServerProviderProvider`, `viewerTransportFactoryProvider` (→ the
    `FakeViewerTransport`). Groups:
    - **Rule 1/2**: invalid input with no session → `InvalidInputState`, zero
      `resolveCalls`, zero `connectCalls`; invalid input with a live session →
      no-op (state and resources unchanged, logged length only); same-id join
      in every non-terminal state → no-op; different-id join → implicit leave
      then resolve (assert `disconnectCalls == 1` before the second
      `resolveCalls`).
    - **Rule 5 / F-7.2 table**: one test per resolution variant (`notFound` →
      `CannotConnect(NotFound)`, `offline` → `NotBroadcasting` + watch open,
      `rateLimited`, `resolutionFailed`, `live` → `Connecting`); one test per
      `ConnectionStatus.Failed(f)` for all seven variants (Full → `Full` state;
      others → `CannotConnect(f)`); `iceServersFor` throw → `IceFailed`;
      `connect()` throw → `IceFailed` (never `Timeout`).
    - **Rule 3/4/F-7.4**: `Interrupted` starts one timer and no `restart()`;
      `Connected` before expiry cancels it (`fakeAsync`, timer not pending);
      expiry + `lastStatus == offline` → `NotBroadcasting`; expiry + no
      emission → `CannotConnect(ResolutionFailed)`; expiry + `live` →
      `disconnect()` called then `CannotConnect(IceFailed)`; offline event in
      `Reconnecting` → immediate `NotBroadcasting` (timer inactive); offline
      event in `LiveView` → no change; live event in `NotBroadcasting` →
      auto-join (`Connecting` → `Connected` → `LiveView`, no second
      `resolveCalls`).
    - **F-7.5/7.7/7.8**: `ended` → `Ended`, transport released, watch closed,
      bus/registry/target still usable until `leave()`; `leave()` from every
      state → `Idle` with all resources released; `leave()` twice = one
      teardown; a stale `join()` (epoch bumped by `leave()` mid-resolve) does
      not resurrect a state (assert with a completer-driven fake resolver).
    - **Rule 7/8**: the viewer bus is a fresh instance per session and distinct
      from `captionBusProvider`; a caption published on the viewer bus reaches
      the session target and never touches the app bus or transcript
      repository (`repository: null`); `state.toString()` and the log records
      never contain caption text (capture `Logger.root` records for the
      duration of one test; assert only `${e.runtimeType}`-shaped messages).
    - **Rule 14**: `restartCalls == 0` in every test in this file (a
      `tearDown` assertion on the fake).
    Use `fakeAsync` only for the timer rows.

18. [ ] `test/services/broadcast/viewer_session_notifier_reconnect_test.dart`
    (new) — the F-7.4 three-outcome matrix and the timer ownership rules
    isolated with `fakeAsync`, one test per outcome and per cancel path
    (`Connected`, `leave()`, terminal transition, a second `Interrupted`
    restarting a single timer). Kept separate from Step 17 so the
    `fakeAsync`-only rows are readable on their own (the Unit 6 split between
    `broadcast_session_notifier_test.dart` and its PBT).

19. [ ] `test/pbt/viewer_session_state_machine_properties_test.dart` (new, the
    PBT-06 stateful suite) — the NFR Design's shape exactly:
    `ProviderContainer(overrides: …)` with the Step 12 fakes;
    `Glados(arbitraryViewerSessionCommandSequence).test(…, (commands) async {
    fakeAsync((async) { … }) })` — every Glados trial wrapped in `fakeAsync`,
    each command realized against the fake collaborators (a
    `WindowExpiryCommand` calls `async.elapse(window + 1s)` with
    `flushMicrotasks()`), and after **each** command assert against a
    simplified reference model written from the FD's transition table:
    - the documented transition (or documented no-op) occurred;
    - invariant 1: `_resources` non-null iff the state is not `Idle`/
      `InvalidInput`/`Resolving` (the NFR Design's documented
      `ResolvingState` exemption — observed through `viewerCaptionTarget !=
      null`/`viewerBus != null`, since `_resources` is private);
    - invariant 2: at most one transport/receiver/bus/registry/target (the
      fakes' counters + the `statusChannel` instance identity);
    - invariant 3: status watch open iff confirmed-live/offline and not
      terminal/idle/invalid;
    - invariant 4: no state carries caption content (no `String` field other
      than none — a `switch` exhaustiveness check on the state type);
    - invariant 5: `leave()` twice equals `leave()` once from the final state
      (command-loop tail, then a second `leave()` and equality on state +
      resource-identity).
    Sequences of varying length including empty (the generator provides 0-20).
    Counterexamples found here are hand-reduced and pinned as example tests in
    Step 17 (PBT-08's no-shrinking limit, recorded).

20. [ ] `test/pbt/viewer_session_leave_idempotence_test.dart` (new, PBT-04) —
    a focused idempotency suite: for a generated **valid** command prefix that
    reaches an arbitrary non-idle state, `await leave(); await leave();` equals
    a single `await leave();` on observable state and on the fakes'
    `disconnectCalls`/`closeCalls` (exactly one, not two), and on the
    returned caption target/bus identity (both null afterwards). Uses
    `generators.dart` only. Kept separate from Step 19 because PBT-04's
    property is "f(f(x)) = f(x)" over states rather than over the transition
    model, so a failure points at the idempotency rule directly.

### `packages/zip_captions/` — l10n and providers

21. [ ] `l10n/arb/app_en.arb` (existing, extend) — every viewer string, each
    with an `@key` description block (the file's existing convention):
    join field label ("Broadcast ID or URL"), join button ("Join"), join
    inline error (Proto-14 verbatim), the confirm dialog (title, body,
    Leave, Stay), Leave control label, `Try again`, the state titles
    (Connecting, Live, Reconnecting, Not currently broadcasting, Broadcast
    ended, Broadcast full, Can't connect, invalid-link title), the copy for
    each state (Proto-15 verbatim where approved), the four new Rule 5 copies
    (`RateLimited`, `ResolutionFailed`, `SignalingRejected`, `Timeout` plus the
    generic IceFailed copy and the reconnect-timeout copy), the paused notice
    ("Captions paused by the broadcaster"), the nameless `NotBroadcasting`/
    `Ended` fallbacks, and the "Joining {sessionName}" template with its
    placeholder. Edit the ARB **only** — no generated file exists in this
    package, and none will (Design Q6: no `gen-l10n`).
    *Test*: Step 23's sentinel test.

22. [ ] `lib/src/l10n/zc_strings.dart` (new, Design Q6) — `ZcStrings` as the
    **only** reader of `l10n/arb/app_en.arb`: a `load()`/async factory over
    `rootBundle.loadString('l10n/arb/app_en.arb')` (confirm the asset path at
    implementation time — `pubspec.yaml` does not currently declare
    `l10n/arb/` as an asset, so Step 22 also adds the `assets:` entry, which is
    a pubspec edit with no dependency change); one getter per viewer key; a
    `String joining(String sessionName)` formatter for the one placeholder.
    No `intl`, no `flutter_localizations`, no `gen-l10n`. Exposed through a
    `@Riverpod(keepAlive: true) zcStrings(Ref ref)` provider returning the
    loaded instance (the hand-written `displaySettingsProvider` precedent is a
    hand-written `NotifierProvider`; a generated function provider is the
    simpler shape and matches `caption_bus_provider.dart`) — the NFR Design's
    "provider or InheritedWidget, pick one" question resolved as **provider**
    so widget tests override it with a sentinel.
    *Test*: Step 23.

23. [ ] `lib/src/providers/viewer_announcer_provider.dart` (new, Design Q5) —
    `typedef ViewerAnnouncer = void Function(String message);`
    `@Riverpod(keepAlive: true) ViewerAnnouncer viewerAnnouncer(Ref ref) =>
    (message) => SemanticsService.announce(message,
    TextDirection.ltr);` and run `build_runner`.

### `packages/zip_captions/` — screens, routes, shell

24. [ ] `lib/src/screens/join_broadcast_screen.dart` (new) — `JoinBroadcastScreen`
    (`ConsumerStatefulWidget`, Proto-14): one `TextField`
    (`Key('join-broadcast-field')`) + a `Join` button
    (`Key('join-broadcast-submit')`); on submit `BroadcastLink.parseInput`
    **locally**; invalid → inline error (`Key('join-broadcast-error')`, ARB
    copy), button re-enabled, **no navigation and no `join()` call**; valid →
    `context.go('/b/${id.value}')`. No session state, no `ref.read` of the
    viewer notifier at all (Rule 2/F-7.1 step 3 — asserted by a widget test
    that a fake notifier records zero `join` calls). `debugTestId`
    (`Key('join-broadcast-…')`) names only, no `data-testid` (Flutter has no
    such attribute; the rule's automation intent maps to stable
    `Key`s — the Unit 6 precedent).

25. [ ] `lib/src/widgets/viewer_status_region.dart` (new, Design Q5) — renders
    the current state's status title + copy (icon + text pairs, never colour
    alone), inside a `Semantics` container so `find.bySemanticsLabel` finds it
    under `ensureSemantics()`; keeps `String? _lastAnnounced` and calls
    `viewerAnnouncerProvider` only when the rendered status text changes
    (including the paused/inactive notice and the reconnect notice, which it
    also owns). Takes the state + `ZcStrings` + session name as parameters so
    it is testable without the notifier.

26. [ ] `lib/src/screens/broadcast_viewer_screen.dart` (new) —
    `BroadcastViewerScreen({required this.input})`, a `ConsumerStatefulWidget`:
    - route-reentry `join(input)` in a post-frame callback when the notifier is
      `Idle` or `currentBroadcastId != parseInput(input)` (F-7.2 step 1's
      reentry rule; `RecordingScreen`'s idiom).
    - full-screen `Scaffold` + `AppBar` (session name or "Zip Captions"),
      leading back, trailing Leave control (`Key('viewer-leave')`).
    - body `switch` over `ViewerSessionState` per the FD's 11-row rendering
      matrix; `LiveView`/`Reconnecting` render `CaptionDisplayWidget(entries:
      notifier.viewerCaptionTarget's snapshot + stream, settings:
      displaySettingsProvider)`; the paused notice and reconnect notice come
      from `ViewerStatusRegion`; `Full` and every `CannotConnect` except
      `NotFound` get a `Try again` button
      (`Key('viewer-try-again')`) calling `join(currentInput)` (F-7.9);
      `InvalidInput` has no retry.
    - Leave/back (Rule 9): a private `_confirmLeave()` shows the ARB dialog in
      `Resolving`/`Connecting`/`LiveView`/`Reconnecting`, otherwise leaves
      immediately; both the AppBar control and a screen-level
      `BackButtonListener` call it; on confirm → `leave()` then `context.go('/')`.
    - subscribes to `viewerCaptionTarget.onVisibleCaptionsChanged` while
      mounted (and cancels in `dispose`).
    No `dart:io`, no platform import (Rule 12).

27. [ ] `lib/src/routing/zc_router.dart` (existing, modify in place) — add
    `GoRoute(path: '/join', …)` **inside** the existing `ShellRoute` and a new
    top-level `GoRoute(path: '/b/:broadcastId', …)` **outside** it (a sibling
    of the `ShellRoute` in `routes:`), builder
    `BroadcastViewerScreen(input: state.pathParameters['broadcastId']!)`.
    Plain paths only (Rule 12).

28. [ ] `lib/src/shell/zc_app_shell.dart` (existing, modify in place) — add
    `if (location == '/join') return 'Join';` to `_screenTitle`. Leave
    `_railIndex` alone (`/join` is not a rail destination — the home affordance
    is the desktop entry point, FD Q6). No back-handling change (the viewer is
    outside the shell and owns its own).

29. [ ] `lib/src/shell/zc_nav_drawer.dart` (existing, modify in place) — one
    new `_DrawerTile` (`Icons.podcasts_outlined`, label "Join a broadcast",
    route `/join`) between History and the `Spacer`.

30. [ ] `lib/src/screens/home_screen.dart` (existing, modify in place) — a
    "Join a broadcast" `TextButton` (`Key('home-join-broadcast')`) beside the
    existing "View History" action, routing to `/join`.

### `packages/zip_captions/` — test helpers and widget tests

31. [ ] `test/helpers/zc_strings_test_scope.dart` (new) — `ZcStrings` building
    for tests: a `ZcStrings` constructed from an in-memory `Map<String, String>`
    (add a named-from-map constructor to `ZcStrings` for this, so the class has
    one async asset path and one synchronous test path — no second reader
    class), plus `zcStringsWithSentinel(key)` returning a map where one viewer
    key is the literal `'SENTINEL-<key>'` and every other value is the real
    ARB-loaded value or a readable stand-in. The sentinel is how Step 34 proves
    the screen renders the ARB and not an inline literal.

32. [ ] `test/helpers/fake_viewer_session_notifier.dart` (new) — per NFR
    Requirements Q2: `FakeViewerSessionNotifier extends ViewerSessionNotifier`
    (constructor-arg initial `ViewerSessionState` + optional `sessionName`/
    `currentBroadcastId`/`viewerCaptionTarget`), `joinCalls`/`leaveCalls`
    lists, `leave()` records and sets `Idle`; `join()` records only. The
    subclass inherits `build()` and must override it to return the initial
    state, matching `FakeRecordingStateNotifier`'s shape. A
    `FakeViewerSessionNotifierFactory`-style fresh-instance helper is added only
    if a second `ProviderContainer` in the same test needs it (Unit 6's
    "already initialized" lesson).
    *Test*: Steps 34-36.

33. [ ] `test/widgets/join_broadcast_screen_test.dart` (new) — invalid input:
    error visible (`Key('join-broadcast-error')`), no navigation
    (assert the router is still on `/join`), **zero** `join()` calls on the
    overridden fake notifier, Join button re-enabled; valid bare ID → lands on
    `/b/{id}`; valid URL → same id; a `BroadcastLink`-invalid 5-char string →
    error. Mounts the real `MaterialApp.router` around a router carrying `/join`
    and a stub `/b/:broadcastId`, per NFR Requirements Q2.

34. [ ] `test/widgets/broadcast_viewer_screen_test.dart` (new) — one test per
    Proto-15 state (8) plus the two cannot-connect copy variants and the
    invalid-input state, driving the **real** `BroadcastViewerScreen` against
    `FakeViewerSessionNotifier` via `viewerSessionProvider.overrideWith` inside
    a real `MaterialApp.router` (NFR Requirements Q2). Each asserts the
    distinct icon + distinct text (`find.byIcon`, `find.text`), the status being
    findable via `find.bySemanticsLabel` under `tester.ensureSemantics()`, and —
    with `viewerAnnouncerProvider` overridden by a recording fake — exactly one
    announcement per state change and none on an unrelated rebuild. The
    reconnecting row asserts the last captions remain visible (a fake target
    with two entries). The `Full`/`CannotConnect` rows assert the Try-again
    button except `NotFound`. No goldens.

35. [ ] `test/widgets/broadcast_viewer_screen_leave_test.dart` (new) — Rule 9:
    Leave control in `Resolving`/`Connecting`/`LiveView`/`Reconnecting` shows
    the dialog (`Stay` → still mounted, no `leave()`; `Leave` → `leave()` and
    `/`); in `Idle`/`NotBroadcasting`/`Ended`/`Full`/`CannotConnect`/
    `InvalidInput` it leaves with no dialog; the screen-level
    `BackButtonListener` follows the identical two paths
    (`tester.binding.handlePopRoute()`), with a back-cancel staying on the
    screen.

36. [ ] `test/widgets/broadcast_viewer_screen_l10n_test.dart` (new) — the
    sentinel test (Design Q6's "first proof the ARB is wired"): with
    `zcStringsProvider` overridden to a sentinel map, the screen renders
    `SENTINEL-…` for that key; with the real ARB-loaded `ZcStrings`, it renders
    the ARB value. Also asserts the paused notice clears in place when
    `captionActivity` returns to `active` (F-7.3/Proto-15).

37. [ ] `test/navigation_test.dart` and/or `test/widgets/zc_app_shell_chrome_test.dart`
    (existing, extend in place — pick the file whose helper already builds the
    real `zcRouter`; `app_test.dart` also gains the home affordance assertion
    if the shell tests' stub routers do not include the new route) — `/join`
    is in-shell (drawer present, title "Join"), `/b/:broadcastId` is
    out-of-shell (no drawer, no rail — assert `find.byType(Drawer)` and
    `find.byType(NavigationRail)` are both absent at mobile and desktop
    widths), and the drawer/home affordances navigate to `/join`. The stub
    routers in the existing shell tests gain `/join` (stub body) and
    `/b/:broadcastId` (stub body) so they mirror `zc_router.dart` — the
    harness-drift rule Unit 6's Step 31 applied.

### `packages/zip_core/` — Part 1 artifact decision

38. [ ] **No `aidlc-docs/construction/zip-captions-viewer/code/` artifact for
    Part 1.** Verified against Unit 6: its `code/` directory holds only the two
    Part 2 summaries (`unit6-zip-core-summary.md`,
    `unit6-zip-broadcast-summary.md`); Part 1 produced no file and the plan
    itself was the artifact. This plan follows that precedent. Part 2's
    summaries will be `unit7-zip-core-summary.md` and
    `unit7-zip-captions-summary.md` (named in that step's plan, not this one).

### Documentation and state

39. [ ] `aidlc-docs/audit.md` (existing, append) — the Unit 7 Code Generation
    Part 1 entry, in the file's existing format: timestamp (ISO 8601),
    "User Input" = `(none — unattended run per .agent/overnight-pipeline.md;
    the kickoff prompt constitutes the standing authorization...)`, an "AI
    Response" recording what was verified against source (the table above), the
    plan's step count, the two verified findings (`_resources` 14 nullable
    fields; `fakeAsync` only in `zip_core`), the `broadcastBaseUrl` /
    `ConnectFailure` / `ZcStrings` decisions carried from NFR Design, and the
    gates; an `**Approval**: approved by: run configuration
    (.agent/overnight-pipeline.md, 2026-10-18) — subject to morning review`
    line; and a Context line "Next: Code Generation Part 2 (implementation)".
    This closes the run configuration's flagged stale-audit gap (the file
    currently ends at the NFR Design entry).

40. [ ] `aidlc-docs/aidlc-state.md` (existing, modify in place) — under the
    Unit 7 entry add a `- [x] Code Generation Part 1 (Planning) — COMPLETE
    2026-10-18 (unattended run; pre-approved per .agent/overnight-pipeline.md
    A2, subject to morning review).` bullet naming the plan file and its step
    count, and advance **Current Stage** to "Unit 7 Code Generation Part 1
    complete, next: Code Generation Part 2". Keep the deferred-web note and the
    Backlog untouched (no new Backlog item is opened by planning; the
    localization item already exists).

## Test list

| # | File | Status | Kind | Covers |
|---|---|---|---|---|
| 1 | `packages/zip_core/test/pbt/broadcast_link_test.dart` | edit | PBT-02 + example | Round-trip incl. configured base, bare ID, base default, never-throws on arbitrary input (existing) |
| 2 | `packages/zip_core/test/models/reconnect_policy_test.dart` | new | example + one invariant row | Window arithmetic (NFR Design Q4) |
| 3 | `packages/zip_core/test/models/connect_failure_test.dart` | new | example | Seven-variant equality + exhaustive `switch` |
| 4 | `packages/zip_core/test/services/broadcast/viewer_session_resources_test.dart` | new | example | F-7.7 step order, per-step catch, release flag, second-call no-op |
| 5 | `packages/zip_core/test/services/broadcast/viewer_session_notifier_test.dart` | new | example | Rules 1-8, 14's `restartCalls == 0` |
| 6 | `packages/zip_core/test/services/broadcast/viewer_session_notifier_reconnect_test.dart` | new | example (`fakeAsync`) | Rule 3/4, F-7.4's three expiry outcomes |
| 7 | `packages/zip_core/test/pbt/viewer_session_state_machine_properties_test.dart` | new | PBT-06 (stateful, `fakeAsync`) | Transition table + invariants 1-5 per command |
| 8 | `packages/zip_core/test/pbt/viewer_session_leave_idempotence_test.dart` | new | PBT-04 | `leave()` twice == once |
| 9 | `packages/zip_core/test/helpers/fake_broadcast_session_collaborators.dart` | edit | helper | `FakeBroadcastResolver`, `FakeViewerTransport` |
| 10 | `packages/zip_core/test/helpers/generators.dart` | edit | helper | `arbitraryViewerSessionCommandSequence`, bases, enums |
| 11 | `packages/zip_captions/test/helpers/zc_strings_test_scope.dart` | new | helper | Sentinel/real `ZcStrings` |
| 12 | `packages/zip_captions/test/helpers/fake_viewer_session_notifier.dart` | new | helper | `FakeViewerSessionNotifier` |
| 13 | `packages/zip_captions/test/widgets/join_broadcast_screen_test.dart` | new | widget (Proto-14) | Valid/invalid, no navigate/no network, no `join()` |
| 14 | `packages/zip_captions/test/widgets/broadcast_viewer_screen_test.dart` | new | widget (Proto-15) | 8 states + 2 copy variants + invalid; announcements; semantics labels |
| 15 | `packages/zip_captions/test/widgets/broadcast_viewer_screen_leave_test.dart` | new | widget | Rule 9 dialog matrix, both call paths |
| 16 | `packages/zip_captions/test/widgets/broadcast_viewer_screen_l10n_test.dart` | new | widget | `ZcStrings` sentinel + paused-notice clear |
| 17 | `packages/zip_captions/test/navigation_test.dart` | edit | widget | `/join` in-shell, `/b/` out-of-shell, drawer/home affordances |
| 18 | `packages/zip_captions/test/widgets/zc_app_shell_chrome_test.dart` | edit | widget | Route-table drift guard (new routes in the stub router) |

`@Tags(['integration-supabase'])` suites: none created, none enabled, none
touched.

## New dependencies

None. `freezed_annotation`/`freezed`, `riverpod_annotation`/
`riverpod_generator`, `fake_async` (zip_core dev), `flutter_test` are already
declared. `zip_captions` gains no dev dependency (NFR Requirements Q2: no
goldens, no new test dep). A need for one is a BLOCKED condition.

## Story traceability

- S-19 AC1 (ID or URL parses to the same id, starts connecting): Steps 3, 13,
  24, 33.
- S-19 AC2 (invalid input → specific message, no network): Steps 2 (parse
  boundary), 17 (Rule 2), 24, 33.
- S-19 AC3 (web `/b/{id}`) — **deferred to Phase 5**; Step 27 ships the plain
  route only.
- S-19 AC4 (viewer's own display settings): Steps 26, 34 (Rule 10).
- S-19 AC5 (paused notice clears on resume): Steps 25, 34, 36.
- S-19 AC6 (distinct status, not colour alone, announced; cannot-connect states
  its reason): Steps 2, 5, 23, 25, 34.
- S-19 AC7 (automatic rejoin within the window): Steps 6, 9, 18.
- S-19 AC8 (broadcast ended + connection released): Steps 9, 17, 34.
- S-19 AC "cannot connect specific reason" (Rule 5's seven-row table): Step 2,
  15, 17.
- S-19 SECURITY-04 headers AC — **deferred to Phase 5**.

## Security and PBT compliance (planning-stage)

- **Security Baseline**: SECURITY-04 N/A (web deferred). SECURITY-03/15
  applicable and addressed by the redaction rule (Step 9: state names/reasons/
  IDs/runtime types only; `InvalidInputState` data-free) and by the
  catch-and-continue teardown that always reaches a terminal state (Steps 8-9).
  SECURITY-05 addressed by `parseInput` being the only untrusted-input
  boundary (Steps 3, 17, 24). SECURITY-08: the viewer path reads no auth
  provider (asserted in Step 17). No blocking finding at planning.
- **PBT**: PBT-02 (Step 13), PBT-03 (Step 14's invariant row), PBT-04 (Step
  20), PBT-06 (Step 19), PBT-07 (Steps 11's domain generators), PBT-08
  (fixed seeds; no shrinking recorded, counterexamples hand-pinned), PBT-10
  (Steps 17/18 example+regression tests alongside the PBT files). PBT-05 N/A
  (no oracle). No blocking finding at planning.

## Deployment artifacts

None — no new build target, CI job or infrastructure change. The two packages
already build/test in the existing pipeline. The web scaffold, web CI job and
security headers remain out of scope (Phase 5).