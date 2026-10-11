# Tech Stack Decisions — WebRTC Transport + Remote Output + Capacity (Unit 5)

## Dependencies

No new dependency. `flutter_webrtc` is already an approved dependency
(`docs/04-technical-specification.md`'s approved-deps table) — this unit only pins its
version.

### Q6: `flutter_webrtc` version pin

`flutter_webrtc: ^1.6.2+hotfix.3` — re-verified 2026-10-05 against both pub.dev's
version list and the `flutter-webrtc/flutter-webrtc` GitHub releases page directly, per
the user's explicit request to check for updates. `1.6.2+hotfix.3` (published
2026-09-15) was confirmed still the latest stable release on both sources at that time
— nothing newer existed. Not re-checked again at this stage (2026-10-07); if Code
Generation finds a newer stable release by then, re-verify before pinning.

## Test Tooling

No new test dependency. `glados` (Unit 2's PBT framework) and `mocktail` (every prior
unit's mocking library) cover this unit's full test suite — the hand-written
`PeerConnectionHandle`/`SignalingService`/`SessionSignalingChannel` fakes (Q5,
`nfr-requirements.md`) are plain Dart classes, not a new library.

## Migration

None. This unit is `zip_core`-only — no `zip_supabase` migration, no RLS policy, no
new SQL function.

## Component Placement

Everything in `zip_core`'s existing structure:
- `lib/src/constants/` — the new `defaultBroadcastLimits` constant (Q1).
- `lib/src/services/webrtc/` (new directory, mirroring `lib/src/services/signaling/`'s
  existing convention) — `WebRtcBroadcastTransport`, `WebRtcViewerTransport`,
  `PeerConnectionHandle`, `PeerConnectionFactory`, `TransportSelector`.
- `lib/src/models/` — `CaptionWireMessage`, `CaptionWireCodec`, `ConnectFailure`,
  `BroadcastTransportContext`/`ViewerTransportContext`, `ViewerConnectionInfo`.
- No change to `lib/src/services/signaling/` or `lib/src/services/broadcast/` — this
  unit consumes `SignalingService`/`IceServerProvider` (Units 3/3.1/4) as already-built
  dependencies, does not modify them.
