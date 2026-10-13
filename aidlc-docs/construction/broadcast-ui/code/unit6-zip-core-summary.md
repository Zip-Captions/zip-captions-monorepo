# Code Generation Summary — Unit 6 (Zip Broadcast Broadcast UI), `zip_core` half

**Plan**: `aidlc-docs/construction/plans/broadcast-ui-code-generation-plan.md` (Steps 1-23 of 36)

## What Shipped

**Models** (`lib/src/models/`)
- `broadcast_settings.dart` — `BroadcastSettings` (freezed), `SessionNameError`,
  `validateSessionName` (Rule 7)
- `broadcaster_session_state.dart` — sealed `BroadcasterSessionState` (5 variants,
  renamed from Application Design's `BroadcastSessionState`, Functional Design Q2)
- `live_broadcast.dart` — `LiveBroadcast` (8 fields, `startedAt` added per Q3)
- `broadcast_failure.dart` — `BroadcastFailure` enum (fixed shape, not previously
  materialized as a file)

**Services** (`lib/src/services/`)
- `caption/captioning_starter.dart` — `CaptioningStarter` interface +
  `DefaultCaptioningStarter` (Functional Design Q1)
- `broadcast/session_resources.dart` — `SessionResources` holder + `disposeAll()`
  (NFR Design Q1's shared catch-and-continue teardown)
- `broadcast/broadcast_session_notifier.dart` — `BroadcastSessionNotifier`
  (`goLive()`/`endBroadcast()`, `business-rules.md` Rules 1-6 implemented exactly,
  including Rule 2's deliberate per-step unwind choices)
- `broadcast/broadcast_settings_notifier.dart` — `BroadcastSettingsNotifier`
  (Phase 1 settings pattern)
- Additive, non-breaking methods on Unit 5's shipped files:
  `RemoteBroadcastTarget.primeActivity()` (Q4), `BroadcastTransport.sendBroadcastEnded()`
  + its `WebRtcBroadcastTransport` implementation (Q5)

**Providers** (`lib/src/providers/`)
- `captioning_starter_provider.dart` — `captioningStarterProvider`
- `broadcast_transport_factory_provider.dart` — `broadcastTransportFactoryProvider`
  (`BroadcastTransport Function()`) — see Deviation 1

Barrel exports updated: `models.dart`, `providers.dart`, `services/broadcast/broadcast.dart`,
`services/caption/caption.dart`. `session_resources.dart` deliberately **not** exported
(internal to this unit, per the NFR Design plan).

**Tests**: new fakes (`fake_captioning_starter.dart`,
`fake_broadcast_session_collaborators.dart` — identity repo, ICE provider, transport,
status channel, signaling service), new `BroadcastSessionCommand` generators
(`generators.dart`), `BroadcastSettings.validateSessionName` example-based (7 tests) +
PBT invariant suite (1 property, 100 generated inputs), `BroadcastSessionNotifier`
example-based suite (24 tests covering Rules 1-6 and F-6.7) + PBT-06 stateful suite
(1 property, 100 generated command sequences), `DefaultCaptioningStarter` tests
(6 tests), `RemoteBroadcastTarget.primeActivity()` tests (3 new, existing file), and
`WebRtcBroadcastTransport.sendBroadcastEnded()`'s test added to the existing fake-pair
integration harness (1 new, existing file — see Deviation 2).

**Final gates**: `dart analyze --fatal-infos` clean; full `zip_core` suite
527 passing (4 pre-existing skips, real-Supabase-stack integration tests, unrelated
to this unit), 0 regressions.

## Deviations Found and Fixed During Generation

1. **`transportSelectorProvider` replaced with `broadcastTransportFactoryProvider`**:
   `TransportSelector.broadcastTransport()`'s declared return type is the concrete
   `WebRtcBroadcastTransport` (Unit 5's fixed shape), not the `BroadcastTransport`
   interface — an override of a provider typed to the concrete class could never
   substitute a `FakeBroadcastTransport` in this unit's own tests (NFR Requirements
   Q1's whole premise). Replaced with a provider declared to return
   `BroadcastTransport Function()` instead; the real closure still just calls
   `TransportSelector().broadcastTransport()` — no cast needed, only a wider declared
   type. Does not touch Unit 5's shipped `transport_selector.dart` at all.
2. **Step 21's assumed test file didn't exist**: the plan assumed a
   `test/services/webrtc/web_rtc_broadcast_transport_test.dart` file to modify in
   place; no such file exists — `WebRtcBroadcastTransport` is only exercised via
   `test/integration/webrtc_transport_fake_pair_test.dart`'s fake-pair harness. Added
   the `sendBroadcastEnded()` test there instead, matching that file's established
   pattern (bystander `FakeSessionSignalingChannel`s observing a confirmed vs. a
   pending viewer).
3. **A shared fake-notifier instance can't back two independently-built
   `ProviderContainer`s**: Riverpod's "already initialized" guard rejects reusing one
   `_FakeAuthNotifier` object across two separate containers' `authNotifierProvider`
   overrides. `broadcast_session_notifier_test.dart`'s `buildContainer()` helper gained
   an optional fresh-factory parameter for the handful of tests that need a second,
   independent container.

No other deviation from the approved Functional Design / NFR Requirements / NFR
Design artifacts.
