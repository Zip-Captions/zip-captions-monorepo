# Logical Components — WebRTC Transport + Remote Output + Capacity (Unit 5)

## Component List (Q2)

All in `packages/zip_core/` — this unit is `zip_core`-only, no UI, no migration.

| Component | Location | Notes |
|---|---|---|
| `WebRtcBroadcastTransport` | `lib/src/services/webrtc/` | Implements `BroadcastTransport` (Application Design). Uses plain `Timer`/`Future.delayed` for Rule 1's ack timer — no injected seam (Q1, corrected 2026-10-08); tested via `fakeAsync()`, matching `supabase_auth_service.dart`'s existing idiom. |
| `WebRtcViewerTransport` | `lib/src/services/webrtc/` | Implements `ViewerTransport` (Application Design). Uses plain `Timer`/`Future.delayed` for Rule 2's backoff loop — same as above. |
| `PeerConnectionHandle` | `lib/src/services/webrtc/` | Interface (domain-entities.md) — the one real-`flutter_webrtc` seam, fully fakeable. |
| `PeerConnectionFactory` | `lib/src/services/webrtc/` | Creates real `PeerConnectionHandle`s from Unit 4's `IceServer` list (Application Design, unchanged). |
| `TransportSelector` | `lib/src/services/webrtc/` | Trivial in Phase 2 (Application Design) — unaffected by this unit's revisions. |
| `ViewerAdmission` | `lib/src/services/webrtc/` | Constructor takes `now: DateTime Function()?` defaulting to `DateTime.now` (Q1, matching `transcript_writer_target.dart`'s identical existing idiom) — no background timer, expiry is a lazy sweep on every call. |
| `ConnectFailure` | `lib/src/models/` | Sealed type, fixed shape (domain-entities.md). |
| `BroadcastTransportContext` / `ViewerTransportContext` | `lib/src/models/` | Revised 2026-10-07 shape — carry `SignalingService`/`BroadcastId`, not a pre-opened channel. |
| `ViewerConnectionInfo` | `lib/src/models/` | Fixed shape, this unit's own invariant (domain-entities.md). |
| `CaptionWireMessage` / `CaptionWireCodec` | `lib/src/models/` | Mirrors `SignalingMessage`/`SignalingCodec`'s exact pattern (Unit 3), including the `messageType` wire-key lesson from Unit 3.1 — never reuse `'type'`/`'event'` as the discriminator key. |
| `BroadcastLimits` constant | `lib/src/constants/` | New `defaultBroadcastLimits` (NFR Requirements Q1) — Spike 2.1's interim values, revisable as a one-file edit. |

## Dependency Diagram

```
WebRtcBroadcastTransport ──┬──> SignalingService (Units 3/3.1, unchanged)
                            ├──> PeerConnectionFactory ──> IceServerProvider (Unit 4, unchanged)
                            ├──> ViewerAdmission (this unit)
                            └──> Timer/Future.delayed (plain dart:async, no injected seam)

WebRtcViewerTransport ──────┬──> SignalingService (Units 3/3.1, unchanged)
                             └──> PeerConnectionFactory ──> IceServerProvider (Unit 4, unchanged)

ViewerAdmission ────────────> BroadcastLimits constant (this unit)

CaptionWireCodec / CaptionWireMessage ── no dependency on SignalingCodec/SignalingMessage
                                          (parallel pattern, not a shared implementation)
```

Dependency direction is one-way: this unit depends on `SignalingService` (Units
3/3.1) and `IceServerProvider` (Unit 4) as already-built, unmodified interfaces.
Neither of those units' own files is touched by this unit's Code Generation.

## Testability Pattern Summary (Q1, corrected 2026-10-08, restated for Code Generation)

| Mechanism | Production implementation | Test approach |
|---|---|---|
| `WebRtcBroadcastTransport`'s ack timer (Rule 1) | plain `Timer`/`Future.delayed`, no injected seam | `fakeAsync()` + `fake.elapse(...)`, matching `supabase_auth_service_test.dart`'s idiom |
| `WebRtcViewerTransport`'s backoff loop (Rule 2) | plain `Timer`/`Future.delayed`, no injected seam | `fakeAsync()`, same as above |
| `ViewerAdmission`'s reservation expiry (Rule 6) | `DateTime Function()? now` defaulting to `DateTime.now`, matching `transcript_writer_target.dart`'s idiom | fake `now`, advanced deterministically — lazy sweep, no background `Timer`, no `fakeAsync` needed |
