# NFR Requirements — WebRTC Transport + Remote Output + Capacity (Unit 5)

**Prior stage**: Functional Design, approved 2026-10-05, revised in place 2026-10-07
(context-shape correction against Unit 3.1's final signaling design — see
`functional-design/domain-entities.md`'s own revision note).

## Scalability

- **Q1 (A)**: Spike 2.1's interim `BroadcastLimits` values (`maxViewers=50`,
  `presenceTimeout=60s`, `reconnectWindow=120s`) ship as a single
  `defaultBroadcastLimits` top-level `const BroadcastLimits` in
  `zip_core/lib/src/constants/`, matching this project's existing constants pattern.
  `ViewerAdmission`'s constructor keeps taking a `BroadcastLimits` parameter (already
  fixed at Application Design) — callers (Unit 6) pass the constant by default, so
  revisiting these values once real beta data exists (tracked in Backlog) is a one-file
  edit, not a design change.

## Performance

- **Q2 (A)**: this unit's own tests assert logical correctness only — that a join
  completes once the fake signaling/ack exchange finishes, that a reconnect succeeds
  once the fake transport reports recovery — never a wall-clock assertion against
  NFR-1.3's 3s/5s targets, since a fake has no real network delay to measure. Those
  targets are restated here as documentation for Unit 9's real two-device test, the
  only place that can actually validate them.

## Reliability (NFR-4.1)

- **Q3 (A)**: a uniform catch-and-map exception boundary at the `PeerConnectionHandle`
  seam. Any exception thrown by a `PeerConnectionHandle` method call is caught exactly
  there, never left to propagate past the transport: on the viewer side, maps to the
  nearest `ConnectFailure` variant (`IceFailed` for anything connection-related,
  consistent with `business-rules.md` Rule 3's exhaustive mapping); on the broadcaster
  side, a per-viewer failure is treated exactly like Rule 1's ack-timeout path (release
  the slot, fire `viewerLeft`, no effect on any other viewer).

## Testability (NFR-7.3)

- **Q5 (A)** — the load-bearing item for this unit: **zero real `flutter_webrtc`
  objects are ever constructed in this unit's test suite**, not even in an
  `integration-supabase`-style tagged, skip-by-default test — unlike every prior unit,
  there is no native platform channel available in a plain `flutter test` run at all.
  All `PeerConnectionHandle` instances are hand-written fakes wiring two sides directly
  together in memory (a fake broadcaster-side handle's `createDataChannel` connects
  directly to a fake viewer-side handle's `onDataChannel`, bypassing SDP/ICE negotiation
  entirely). `SessionSignalingChannel` gets an in-memory fake pair per accepted viewer,
  plus a fake `SignalingService` exposing an in-memory `joinRequests` stream and a
  `submitJoinRequest` that feeds it (matching the 2026-10-07 context-shape revision) —
  together these let a single PBT suite drive a full broadcaster+viewer
  join/caption/leave sequence with no network and no real Supabase stack. Real
  two-device, real-TURN, and real `flutter_webrtc` platform-channel behavior is
  **entirely** Unit 9's responsibility, stated explicitly here so this is never later
  mistaken for a coverage gap.

## Security

SR-01/02/03/04 are unaffected (this unit introduces no new RLS policy, credential
issuer, or logging infrastructure). This section adds the Security Baseline compliance
pass.

### Security Baseline Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| SECURITY-01 (Encryption at rest/transit) | N/A (platform-level) | WebRTC's own mandatory DTLS/SRTP encrypts all peer-connection traffic; inherited from `flutter_webrtc`, not implemented by this unit. |
| SECURITY-02 (Access logging on intermediaries) | N/A | No new HTTP route or gateway path — peer connections traverse Coturn (Unit 4, unaffected) and direct P2P, neither touched by this unit. |
| SECURITY-03 (Application-level logging) | Compliant (Q4) | No new logging infrastructure. Where a `Logger` call exists, it may log `peerId` (non-identity-correlatable) and `ConnectionType`/`ConnectFailure` values only — never `CaptionWireMessage.Caption`'s payload or any `SttResult` field. Restates the existing project-wide rule against this unit's own new types. |
| SECURITY-04 (HTTP security headers) | N/A | No HTML-serving endpoint in this unit. |
| SECURITY-05 (Input validation) | Compliant | `CaptionWireCodec.decode`'s `null`-on-malformed boundary (Rule 7) mirrors `SignalingCodec`'s already-approved pattern exactly — a single malformed/future-version message from a misbehaving peer is dropped, never thrown. |
| SECURITY-06 (Least privilege) | N/A | No `SECURITY DEFINER`/`SECURITY INVOKER` function in this unit — pure `zip_core` business logic, no new database surface. |
| SECURITY-07 (Network configuration) | N/A | No infrastructure/firewall change — consumes Unit 4's existing Coturn/ICE server config unchanged. |
| SECURITY-08 (Application-level access control) | Compliant | Rule 4's message-type sender authorization (a carried-forward obligation from Unit 3's Business Rule 5, restated against Unit 3.1's final design) is exactly this unit's own object-level authorization layer — RLS (Unit 3.1) establishes channel membership only, never which message type a given sender may use. |
| SECURITY-09 (Hardening) | Compliant | An out-of-role message type is dropped silently (Rule 4), never surfaced as a connection error that could reveal internal state to a misbehaving peer. |
| SECURITY-10 (Supply chain) | Compliant | `flutter_webrtc` is an already-approved dependency (`docs/04-technical-specification.md`); Q6 re-verifies the version pin is current, not a new approval. |
| SECURITY-11 (Secure design, rate limiting) | N/A | No new user-facing write surface this unit owns (join/reject flows are rate-limited at the signaling layer, Unit 3.1, not here). |
| SECURITY-12 (Auth/credential management) | N/A | Consumes Unit 4's TURN credentials unchanged; manages no credentials itself. |
| SECURITY-13 (Data integrity) | N/A | No persisted table or row this unit creates or mutates. |
| SECURITY-14 (Alerting/monitoring) | N/A | Same standing project-wide Backlog item as every prior unit — no alerting infrastructure exists yet. |
| SECURITY-15 (Exception handling/fail-safe defaults) | Compliant (Q3) | The `PeerConnectionHandle`-seam exception boundary fails toward releasing a stuck viewer's slot and reporting a specific `ConnectFailure`, never toward leaving the caller in an unknown or hung state. |

## PBT Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| PBT-01 (Property identification) | Compliant | Two real properties identified: `ViewerAdmission`'s cap invariant (Rule 6 — `count` never exceeds `maxViewers` under any interleaving) and `CaptionWireCodec`'s round-trip/never-throws property (Rule 7), plus PBT-03's in-order-delivery property exercised via the Q5 fake-pair harness. |
| PBT-02 (Round-trip) | Compliant (planned) | `CaptionWireCodec` round-trip suite, mirroring `SignalingCodec`'s PBT suite from Unit 3 exactly (encode→decode recovers the original value; malformed/adversarial input always decodes to `null`, never throws). |
| PBT-03 (Invariant) | Compliant (planned) | `ViewerAdmission`'s reservation state machine (Rule 6) is written precisely enough to double as its own PBT reference model — a generated sequence of `tryAdmit`/`release` calls (including races against a reservation's expiry) must never observe `count > maxViewers`. |
| PBT-04 (Idempotence) | N/A | No pure-function idempotence claim in this unit's domain. |
| PBT-05 (Oracle) | Compliant (planned) | `ViewerAdmission`'s own state-machine model (Rule 6) is both the implementation and the reference model being checked against generated command sequences — the standard model-based pattern already used for `AuthNotifier` (Unit 2) and `SupabaseBroadcastResolver` (Unit 3). |
| PBT-06 (Stateful) | Compliant (planned) | `ViewerAdmission`'s model-based PBT suite (Rule 6) is exactly this — a stateful sequence of commands checked against a reference model, the project's established pattern. |
| PBT-07 (Generator quality) | Compliant (planned) | Generated `tryAdmit`/`release` sequences include deliberately adversarial interleavings (a reservation's expiry racing a new `tryAdmit`) specifically because Rule 6's invariant calls this out as the case that must never transiently violate the cap. |
| PBT-08 (Shrinking/reproducibility) | Compliant | `glados` (already the project's PBT framework since Unit 2) provides shrinking/reproducibility by default; no new framework. |
| PBT-09 (Framework selection) | Compliant (Q7) | `glados`, reusing the existing model-based-PBT pattern (Units 2–3) — no new framework needed for this unit's properties. |
| PBT-10 (Complementary testing) | Compliant (planned) | The Q5 fake-pair harness's example-based join/caption/leave sequence tests complement the generated-input PBT suites above, the same split every prior unit has used. |

## Notes for Code Generation

- Real two-device, real-TURN, and real `flutter_webrtc` native-stack verification is
  entirely Unit 9's job (Q5) — do not attempt to add any such test to this unit.
- `BroadcastLimits`'s interim values (Q1) are a Backlog item for post-beta revisiting
  with real usage data (see `aidlc-state.md`'s existing Backlog entry) — Code
  Generation implements the constant as specified, does not revisit the values
  themselves.
- `CaptionWireCodec`'s wire key must not reuse `'type'`/`'event'` (the `SignalingCodec`
  lesson from Unit 3.1, explicitly flagged in `aidlc-state.md` for this unit to apply).
