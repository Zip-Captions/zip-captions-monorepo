# NFR Requirements Plan: WebRTC Transport + Remote Output + Capacity (Unit 5)

**Prior stage**: Functional Design, approved 2026-10-05

## Context

Functional Design fixed the business logic and rules (join-ack timing, reconnection
backoff, the `ViewerAdmission`/`reconnectWindow` state machine, message-type
authorization). This stage covers scalability/performance targets, reliability/error
boundaries, security/logging constraints, tech stack (the `flutter_webrtc` version pin),
and — the one genuinely unusual question for this unit — what "testable with fakes"
(NFR-7.3) actually means when the real dependency (`flutter_webrtc`) requires native
platform channels that don't exist in a `flutter test` run at all.

## Planned Steps

- [ ] Scalability: how `BroadcastLimits`/Spike 2.1 interim values are delivered
- [ ] Performance: scope of NFR-1.3 timing validation in this unit
- [ ] Reliability: exception boundary at the `PeerConnectionHandle` seam
- [ ] Security: logging/telemetry constraints (NFR-6.2, SECURITY-03)
- [ ] Testability: fake architecture and the real limit of what this unit can test
- [ ] Tech stack: `flutter_webrtc` version pin
- [ ] PBT: framework and property scope confirmation
- [ ] Generate `nfr-requirements.md` and `tech-stack-decisions.md`

## Scalability

### Q1: How are `BroadcastLimits`'s Spike-2.1-interim values delivered to `ViewerAdmission`?

`maxViewers=50`, `presenceTimeout=60s`, `reconnectWindow=120s` are explicitly
tentative (Spike 2.1's own recommendation: "implement as a project constant... so it can
move without a design change once real beta data exists").

- A. A single `defaultBroadcastLimits` top-level `const BroadcastLimits` in
  `zip_core/lib/src/constants/`, following this project's existing constants pattern
  (`supabaseUrl`, `iceServerUrls` — `String.fromEnvironment`-style where override-by-build
  matters; here, a plain Dart `const` is enough since there's no need to override this
  per-build, only per-code-change when Spike 2.1 resumes or real data arrives).
  `ViewerAdmission`'s constructor keeps taking a `BroadcastLimits` parameter (already
  fixed) — callers (Unit 6) pass the constant by default, so changing the interim values
  later is a one-file edit, not a design change. **(recommended — matches Spike 2.1's own
  stated intent exactly, no new mechanism)**
- B. Other (write in)

[Answer]: A

## Performance

### Q2: How much of NFR-1.3 (join-to-first-caption ≤3s, reconnection ≤5s) does this unit itself validate?

Both targets are explicitly "interim target, not measured" per Spike 2.1 — this unit's
own Notes already say "two-device and TURN verification against the real stack happens
in Unit 9."

- A. This unit's own tests (fakes only, see Q5) assert **logical** correctness only —
  that a join completes once the fake signaling/ack exchange finishes, that a reconnect
  succeeds once the fake transport reports recovery — never a wall-clock assertion
  against the 3s/5s targets, since a fake has no real network delay to measure in the
  first place. The 3s/5s targets are carried forward as documentation (restated in
  `nfr-requirements.md`) for Unit 9's real two-device test to actually validate, not
  something this unit's test suite can meaningfully assert on fakes. **(recommended —
  asserting a wall-clock target against a fake that has no real latency would be a
  tautological test, not a real validation)**
- B. Other (write in)

[Answer]: A

## Reliability

### Q3: Exception boundary at the `PeerConnectionHandle`/transport seam — what's the rule?

NFR-4.1: "Transport, signaling and auth failures never crash either app. Each surfaces a
specific, user-understandable state." `PeerConnectionHandle`'s methods are `Future`s that
could throw (a real `flutter_webrtc` call failing natively) — need the rule for how
`WebRtcBroadcastTransport`/`WebRtcViewerTransport` handle that.

- A. Every call into a `PeerConnectionHandle` method from within a transport
  implementation is wrapped; any thrown exception is caught at that boundary and mapped
  to the nearest fixed failure type — a viewer-side failure maps to the relevant
  `ConnectFailure` variant (`IceFailed` for anything connection-related, consistent with
  `business-rules.md` Rule 3's exhaustive mapping); a broadcaster-side per-viewer failure
  is treated exactly like Rule 1's ack-timeout path (release the slot, fire
  `viewerLeft`, don't touch other viewers). Nothing from this seam ever propagates
  uncaught past the transport boundary. **(recommended — turns NFR-4.1's requirement
  into a concrete, uniform rule applied at exactly one seam, rather than scattered
  try/catch at every call site)**
- B. Other (write in)

[Answer]: A

## Security

### Q4: Logging/telemetry constraints for this unit specifically?

The project-wide rule (component-methods.md's header note, SECURITY-03) already bars
caption text and tokens/TURN credentials from any log. NFR-6.2 further restricts
transport-type/connection-success metrics to "no caption content and no viewer
identity." Does this unit introduce any logging of its own that needs an explicit rule?

- A. No new logging infrastructure in this unit. Where a `Logger` call is useful for
  debugging (e.g. a `WebRtcBroadcastTransport` logging a viewer's `ConnectionType`
  transition), it may log `peerId` (already established as non-identity-correlatable,
  domain-entities.md) and `ConnectionType`/`ConnectFailure` values only — never
  `CaptionWireMessage.Caption`'s payload, never anything from `SttResult`. This is a
  restatement of the existing project-wide rule applied to this unit's own new types,
  not a new policy. **(recommended — no new mechanism needed, just confirms the
  existing rule covers this unit's new types correctly)**
- B. Other (write in)

[Answer]: A

## Testability

### Q5: What does "testable with fakes" (NFR-7.3) actually mean here, given `flutter_webrtc` requires native platform channels?

Unlike `SupabaseClient` (real HTTP, works fine in a Dart-VM `flutter test`), a real
`RTCPeerConnection` cannot be constructed at all in a plain `flutter test` run — there is
no platform channel. This unit's own Notes already say two-device/TURN verification
happens in Unit 9, but this needs to be explicit about what that implies for *this
unit's* test suite specifically, since it changes the usual "unit tests + one
integration-tagged real-backend test" shape every prior unit has used (Units 2–4).

- A. **No real `flutter_webrtc` object is ever constructed in this unit's test suite —
  not even in an `integration-supabase`-style tagged, skip-by-default test.** All
  `PeerConnectionHandle` instances in tests are hand-written fakes that directly wire two
  sides together in memory (a fake broadcaster-side handle's `createDataChannel` is
  connected directly to a fake viewer-side handle's `onDataChannel`, bypassing SDP/ICE
  negotiation entirely — they're already "connected" by construction). Likewise
  `SessionSignalingChannel` gets an in-memory fake pair (mirroring the "both protocol
  sides are tested together against fakes" language already in this unit's Notes) so a
  single PBT suite can drive a full broadcaster+viewer join/caption/leave sequence
  without a network or a real Supabase stack. Real two-device, real-TURN, and real
  `flutter_webrtc` platform-channel behavior is **entirely** Unit 9's responsibility —
  this unit has zero test coverage of the actual native WebRTC stack, by necessity, not
  oversight. **(recommended — the only option that's actually possible, given a real
  peer connection can't run in `flutter test` at all; stated explicitly so this isn't
  mistaken for a coverage gap later)**
- B. Other (write in)

[Answer]: A

## Tech Stack

### Q6: `flutter_webrtc` version pin?

Already an approved dependency (`docs/04-technical-specification.md`'s approved-deps
table) — this is a version-pin decision, not a new-dependency approval.

- A. `flutter_webrtc: ^1.6.2+hotfix.3` — confirmed as the current latest stable release
  on pub.dev (checked directly, not assumed), matching this project's convention of
  pinning to a specific version rather than an open range for infrastructure-adjacent
  dependencies. **(recommended — verified current, not guessed)**
- B. Other (write in)

[Answer]: A — **re-verified 2026-10-05 per the user's request to check for updates**: cross-checked both pub.dev's version list and the `flutter-webrtc/flutter-webrtc` GitHub releases page directly. `1.6.2+hotfix.3` (published 2026-09-15) is still the latest stable release on both sources — nothing newer exists. No change from the original recommendation; confirmed current as of this check, not just asserted.

## PBT

### Q7: PBT framework and property scope — carry forward unchanged?

`business-rules.md` Rule 5/6 already specify the in-order-delivery and cap-invariant
properties precisely enough to serve as reference models.

- A. `glados` (already the project's PBT framework since Unit 2), plus the
  model-based/stateful pattern already used for `AuthNotifier`'s state machine (Unit 2)
  and `SupabaseBroadcastResolver`'s outcome mapping (Unit 3) — applied here to
  `ViewerAdmission`'s reservation state machine (Rule 6) and a wire-codec round-trip
  suite for `CaptionWireCodec` (mirroring `SignalingCodec`'s PBT suite from Unit 3
  exactly). The in-order-delivery property (Rule 5) is exercised via the Q5 fake-pair
  harness: a generated sequence of captions sent while viewers join/leave at generated
  points, asserting every still-connected viewer's received order matches the sent order
  from its own join point onward. **(recommended — no new framework, direct reuse of
  two already-established patterns)**
- B. Other (write in)

[Answer]: A
