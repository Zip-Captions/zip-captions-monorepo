# Code Generation Plan: WebRTC Transport + Remote Output + Capacity (Unit 5)

**Prior stage**: NFR Design, approved 2026-10-08 (Q1 corrected same day against existing
codebase convention — plain `Timer`/`fakeAsync()`, not an injected `delay` seam).

## Scope

Everything fixed at Application Design (`phase2-component-methods.md` §4–5) plus this
unit's own Functional Design/NFR stages: `BroadcastTransport`/`ViewerTransport` and
their WebRTC implementations, `PeerConnectionFactory`/`PeerConnectionHandle`,
`TransportSelector`, `CaptionWireMessage`/`CaptionWireCodec`, `RemoteBroadcastTarget`/
`RemoteCaptionReceiver`, `BroadcastLimits`/`ViewerAdmission`,
`BroadcastTransportContext`/`ViewerTransportContext`, `ConnectFailure`,
`ViewerConnectionInfo`. `zip_core`-only — no `zip_supabase` migration, no UI.
**Not in scope**: wiring `BroadcastSessionNotifier`/the viewer-side session
orchestrator to actually call any of this (Units 6/7, which don't exist yet) — this
unit ships the transport layer itself, not its callers.

## Steps

### `packages/zip_core/` — dependency

1. [x] Add `flutter_webrtc: ^1.6.2+hotfix.3` to `pubspec.yaml` (already an approved
   dependency per `docs/04-technical-specification.md`; this is the first unit to
   actually declare it). Re-verify it's still the latest stable release on pub.dev
   before pinning (NFR Requirements Q6 already did this 2026-10-05; re-check only if
   meaningful time has passed by the time this step actually runs). **Done
   2026-10-08**: re-checked, a newer patch existed (`+hotfix.4`, published ~40h
   earlier) — pinned to that instead.

### `packages/zip_core/` — models

2. [x] `lib/src/models/connect_failure.dart` — `ConnectFailure` sealed type (4
   variants: `BroadcastFull`, `IceFailed`, `SignalingRejected`, `Timeout`).
3. [x] `lib/src/models/connection_status.dart` — `ConnectionStatus` sealed type
   (`Connecting`, `Connected(ConnectionType)`, `Interrupted`, `Failed(ConnectFailure)`)
   and `ConnectionType` enum (`p2pDirect`, `turnRelayed`, `connecting`,
   `disconnected`).
4. [x] `lib/src/models/viewer_connection_info.dart` — `ViewerConnectionInfo` (`peerId`,
   `connectionType`, `connectedAt`).
5. [x] `lib/src/models/caption_wire_message.dart` — `CaptionWireMessage` sealed type
   (`Caption` wrapping `SttResult` fields per ADR-005, `CaptionActivityChanged`,
   `Ended`) and `CaptionActivity` enum.
6. [x] `lib/src/models/caption_wire_codec.dart` — `CaptionWireCodec.encode`/`decode`,
   mirroring `SignalingCodec`'s exact pattern (version 1, `null`-on-malformed/
   unsupported-version, never throws) — **apply Unit 3.1's wire-key lesson explicitly**:
   use a discriminator key that cannot collide with anything Realtime or any other
   envelope injects (e.g. `messageType`, matching `SignalingCodec`'s own fix — not
   `'type'`/`'event'`).
7. [x] `lib/src/models/broadcast_limits.dart` — `BroadcastLimits` (`maxViewers`,
   `presenceTimeout`, `reconnectWindow`) and `AdmissionDecision` sealed type
   (`Admitted`, `Full`).
8. [x] `lib/src/constants/broadcast_limits_default.dart` — `defaultBroadcastLimits`, a
   top-level `const BroadcastLimits(maxViewers: 50, presenceTimeout: Duration(seconds:
   60), reconnectWindow: Duration(seconds: 120))` (NFR Requirements Q1 — Spike 2.1's
   interim values, revisable as a one-file edit per the existing Backlog item).
9. [x] `lib/src/models/broadcast_transport_context.dart` /
   `lib/src/models/viewer_transport_context.dart` — the 2026-10-07-revised shapes:
   `BroadcastTransportContext { sessionId, broadcastId, signalingService, iceServers,
   admission }` / `ViewerTransportContext { sessionId, broadcastId, signalingService,
   iceServers }`.
10. [x] `lib/src/models/models.dart` barrel — add exports for all of the above.

### `packages/zip_core/` — services

11. [x] `lib/src/services/webrtc/peer_connection_handle.dart` — `PeerConnectionHandle`
    interface (domain-entities.md's fixed shape). **Found during Code Generation**:
    the fixed shape omitted `setLocalDescription` — a completeness gap (WebRTC
    requires it after `createOffer`/`createAnswer`), not a design choice; added.
12. [x] `lib/src/services/webrtc/peer_connection_factory.dart` — `PeerConnectionFactory`
    interface + a real `flutter_webrtc`-backed implementation.
13. [x] `lib/src/services/webrtc/transport_selector.dart` — `TransportSelector`
    (trivial in Phase 2: always WebRTC).
14. [x] `lib/src/services/webrtc/viewer_admission.dart` — `ViewerAdmission`, with the
    `now: DateTime Function()?` seam (NFR Design Q1, corrected) and Rule 6's full
    reservation state machine (lazy expiry sweep on every call, never a background
    `Timer`).
15. [x] `lib/src/services/webrtc/web_rtc_broadcast_transport.dart` —
    `WebRtcBroadcastTransport` implementing `BroadcastTransport`: per-viewer lifecycle
    (business-logic-model.md), Rule 1's 5s ack timer via plain `Timer` (NFR Design Q1,
    corrected), opens `signalingService.sessionChannel(sessionId, peerId)` on every
    `JoinRequest` (accept or reject) per the 2026-10-07 revision, Rule 4's message-type
    sender authorization (drop anything only a viewer may originate). Also created
    `broadcast_transport.dart` (the `BroadcastTransport` interface itself — not
    previously materialized as a file anywhere).
16. [x] `lib/src/services/webrtc/web_rtc_viewer_transport.dart` —
    `WebRtcViewerTransport` implementing `ViewerTransport`: generates a fresh
    `peerId()` on every `connect()`/`restart()` (per Unit 3.1 Rule 5, never via
    context), opens its own `sessionChannel` first, then `submitJoinRequest`, Rule 2's
    backoff retry loop via plain `Timer` (NFR Design Q1, corrected), Rule 4's
    message-type sender authorization (drop anything only the broadcaster may
    originate). Also created `viewer_transport.dart` (the `ViewerTransport` interface
    itself). **Known simplification**: `ViewerConnectionInfo.connectionType` is fixed
    as `p2pDirect` for every viewer — the minimal `PeerConnectionHandle` seam has no
    candidate-pair/stats query method to derive real p2p-vs-relay routing; flagged for
    a future revisit rather than silently guessed or scope-crept into a bigger
    interface change.
17. [x] `lib/src/services/caption/remote_broadcast_target.dart` —
    `RemoteBroadcastTarget implements CaptionOutputTarget` (Rule 8's single-snapshot
    behavior on `viewerJoined`, the `RecordingActiveState`→`active`/
    `PausedState`+`ReconnectingState`→`paused`/`IdleState`+`StoppedState`→`inactive`
    caption-activity mapping fixed at Application Design). The fixed single-argument
    constructor has no way to inject the current recording state, so
    `currentActivity` defaults to `inactive` until the first real `SessionStateEvent`.
18. [x] `lib/src/services/caption/remote_caption_receiver.dart` —
    `RemoteCaptionReceiver` (wraps a `ViewerTransport` + `CaptionBus`, exposes
    `activity`/`ended` streams).
19. [x] `lib/src/services/signaling/signaling.dart` and
    `lib/src/services/webrtc/webrtc.dart` (new barrel, following the existing
    per-directory barrel convention) — export everything new. (`signaling.dart`
    needed no change — already correct from Unit 3.1.)
20. [x] `lib/src/providers/` — no new provider needed at this stage (Units 6/7 wire
    `BroadcastTransport`/`ViewerTransport` into Riverpod when they're built); confirm
    this explicitly rather than silently skipping it.

### Tests

21. [x] Dart-side unit tests for every new model (`ConnectFailure`, `ConnectionStatus`,
    `CaptionWireMessage`, `BroadcastLimits`/`AdmissionDecision`, the two context
    types). **Corrected 2026-10-08**: `CaptionWireCodec` moved entirely to Step 24 —
    checked against the actual codebase and found `SignalingCodec`/`SignalingMessage`
    have no separate example-based test file at all; the real, only precedent
    (`test/pbt/signaling_codec_test.dart`) tests a codec exclusively through
    generator-driven PBT. `CaptionWireCodec` follows that same precedent, not an
    invented parallel "example-based" style. **Done 2026-10-08** — 25 tests across 6
    files, `dart analyze --fatal-infos` clean, 433/433 full suite passing (no
    regression). Accepted as-is, no corrections.
22. [x] `ViewerAdmission` unit tests: `tryAdmit`/`release`/`count` happy paths, the
    reclaim-within-`reconnectWindow` path, the expiry-sweep-on-access behavior with a
    fake `now`. **Done 2026-10-08** — 8 tests, `dart analyze --fatal-infos` clean,
    441/441 full suite passing (no regression). Accepted as-is, no corrections.
23. [x] **`ViewerAdmission` model-based PBT suite** (NFR Requirements PBT-03/05/06):
    generated `tryAdmit`/`release` command sequences, including deliberately
    adversarial interleavings (a reservation's expiry racing a new `tryAdmit`),
    asserting `count` never exceeds `maxViewers` under any sequence — `glados`-style,
    reusing the existing model-based pattern (`test/helpers/pbt.dart`). **Done
    2026-10-08** — 100 Glados-seeded sequences, confirmed non-vacuous (Full/reclaim/
    expiry paths all genuinely exercised), `dart analyze --fatal-infos` clean, 442/442
    full suite passing (no regression). Accepted with one cosmetic formatting fix.
24. [x] **`CaptionWireCodec` test suite** (PBT-02) — the *only* test file for this
    codec (no separate example-based file, matching `SignalingCodec`'s own real
    precedent), mirroring `test/pbt/signaling_codec_test.dart` exactly: generator-driven
    round-trip (`arbitraryCaptionWireMessage`), generator-driven malformed-input
    (`arbitraryMalformedCaptionWireJson`, never throws), plus the one targeted
    oversized-nested-field regression test. **Done 2026-10-09** — 3 tests, `dart
    analyze --fatal-infos` clean, 445/445 full suite passing (no regression).
    Accepted with one minor fix (a misattributed test-name citation).
25. [x] **The load-bearing fake-pair test** (NFR Requirements Q5): hand-written fakes
    for `PeerConnectionHandle` (two sides wired directly together in memory,
    bypassing SDP/ICE negotiation) and `SignalingService`/`SessionSignalingChannel`
    (in-memory `joinRequests`/`submitJoinRequest`/per-viewer channel pairs), driving a
    full `WebRtcBroadcastTransport` + `WebRtcViewerTransport` join → caption → leave
    sequence. Confirms: Rule 1's ack-timeout path (via `fakeAsync()`), Rule 2's
    backoff retries (via `fakeAsync()`), Rule 4's message-type authorization (a
    fake peer sending an out-of-role message type is dropped silently, never crashes
    the receiver), Rule 5's in-order delivery, Rule 8's single-snapshot behavior.
    Split into three sub-steps. **25a done 2026-10-09** — `FakePeerConnectionHandle`/
    `FakePeerConnectionFactory`/`FakeDataChannel` (`test/helpers/fake_peer_connection.dart`),
    7 tests, `dart analyze --fatal-infos` clean, 467/467 full suite passing (no
    regression). Accepted with one minor fix (a microtask-ordering bug: the open
    event needs one more level of nesting than delivery, or listeners attached the
    way the real transports attach them never see it). **25b done 2026-10-09** —
    `FakeSignalingService`/`FakeSessionSignalingChannel`/`SignalingTopic`
    (`test/helpers/fake_signaling_service.dart`), 6 tests, `dart analyze --fatal-infos`
    clean, 473/473 full suite passing (no regression). Accepted as-is, no
    corrections. **25c done 2026-10-10** — the full join/caption/leave
    integration test (`test/integration/webrtc_transport_fake_pair_test.dart`)
    combining both fakes against the real `WebRtcBroadcastTransport`/
    `WebRtcViewerTransport`/`RemoteBroadcastTarget`, confirming Rules 1, 2, 4, 5,
    8. 4 tests, `dart analyze --fatal-infos` clean, 477/477 full suite passing (no
    regression). Required substantial direct fixes after Qwen's implementation: a
    real `Zone`/`fakeAsync` interaction bug (a stream subscription bound to the
    wrong zone), two incorrect test assertions (expecting the fakes to cascade a
    peer connection's own close across the link, which they correctly don't), and
    a rewrite of the Rule 2 reconnect test to plain `async`/real-time waiting
    after confirming `StreamSubscription.cancel()` doesn't resolve through
    `fakeAsync`'s queue in this SDK. Step 25 (all three parts) now complete.
26. [x] `RemoteBroadcastTarget`/`RemoteCaptionReceiver` unit tests: the
    caption-activity mapping table, `onCaptionEvent`/`activity`/`ended` wiring, mocked
    `BroadcastTransport`/`ViewerTransport`/`CaptionBus`. **Done 2026-10-09** — 15
    tests across 2 files, `dart analyze --fatal-infos` clean, 460/460 full suite
    passing (no regression). Accepted as-is, no corrections.

### Verification

27. [x] `dart analyze --fatal-infos` clean in `zip_core`. **Done 2026-10-10** — no issues found.
28. [x] All new + existing `zip_core` tests passing. **Done 2026-10-10** — 477/477
    passing (4 pre-existing skips), zero regressions across the whole unit.
29. [x] Confirm via `grep` that no stale `LobbyChannel`/`SignalingRole`/single-`channel`-field
    reference survived from before the 2026-10-07 revision anywhere in the new code.
    **Done 2026-10-10** — `LobbyChannel` matches are historical doc comments only
    (explaining its removal); `SignalingRole` has zero matches; the one bare
    `channel` field (`_ViewerSession.channel` in `web_rtc_broadcast_transport.dart`)
    is a per-viewer-session field consistent with the revised per-viewer-channel
    design, not a reintroduced single shared channel.

## Delegation Note

Per this project's standard process, Part 2 (generation) proceeds after this plan is
approved. Candidate for delegation: Step 21 (model unit tests, well-specified,
single-package, mirrors existing patterns exactly) — the rest (transport
implementations, the fake-pair harness, PBT suites) stays with the orchestrator given
how load-bearing and interdependent they are.

## Traceability

| Step | FR/NFR |
|---|---|
| 1 | NFR Requirements Q6 (tech stack) |
| 2–10 | Functional Design domain-entities.md (Q3–Q7), revised 2026-10-07 (Q5) |
| 11–16 | Functional Design business-logic-model.md/business-rules.md Rules 1–6; NFR Design Q1 (corrected)/Q2 |
| 17–18 | Application Design §5 (fixed contracts) |
| 19–20 | NFR Design Q2 (component placement) |
| 21–22 | Standard unit-test coverage |
| 23 | PBT-03/05/06 (NFR Requirements) |
| 24 | PBT-02 (NFR Requirements) |
| 25 | NFR Requirements Q5 (the real-proof half, fakes-only) |
| 26 | Application Design §5 |
| 27–29 | Project-wide `dart analyze`/test conventions; this unit's own staleness-check discipline |
