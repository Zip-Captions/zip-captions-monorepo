# Tech Stack Decisions — Zip Broadcast Broadcast UI (Unit 6)

## Dependencies

No new dependency. Every new class in this unit (`BroadcastSessionNotifier`,
`BroadcastSettingsNotifier`, `CaptioningStarter`, `BroadcastSetupScreen`, the live
dashboard, `ZbAppShell`'s new `InheritedWidget`) is built entirely from packages
already present in `zip_core`'s/`zip_broadcast`'s `pubspec.yaml`s: `flutter`,
`riverpod`/`riverpod_annotation`, `freezed`, `uuid` (session ID generation, same
mechanism as `peerId()`), `shared_preferences` (settings persistence, Phase 1
pattern), and `intl`/the project's ARB localization files (validation error messages).

If accessibility semantics beyond Flutter's built-in `Semantics`/`MergeSemantics`
widgets are ever needed (deferred per NFR Requirements Q7's Backlog item), that would
be a new dependency finding requiring FR-9.5's human-approval/supply-chain
justification — not assumed or pre-approved here.

## Test Tooling

No new test dependency. `glados` (this project's PBT framework since Unit 2) and
`mocktail` (every prior unit's mocking library, where used) cover this unit's full test
suite. The hand-written fakes (`FakeSignalingService`, `FakeCaptioningStarter`, the
fake `BroadcastTransport`, and simple stubs for `BroadcastIdentityRepository`/
`IceServerProvider`) are plain Dart classes, not a library dependency — `FakeSignalingService`
reuses Unit 5's existing `test/helpers/fake_signaling_service.dart` interface where it
already covers what this unit needs, rather than introducing a second fake for the same
contract.

## Migration

None. This unit is `zip_core`/`zip_broadcast`-only — no `zip_supabase` migration, no
RLS policy change, no new SQL function.

## Component Placement

- `zip_core`:
  - `lib/src/services/broadcast/` (existing directory, per
    `phase2-component-methods.md`'s placement for `BroadcastSessionNotifier`) —
    `BroadcastSessionNotifier`, `BroadcastSettingsNotifier`.
  - `lib/src/services/caption/` or an equivalent existing location — the new
    `CaptioningStarter` interface and its default (zip_captions-parity)
    implementation, plus the `captioningStarterProvider`.
  - `lib/src/models/` — `BroadcastSettings`, `BroadcasterSessionState` (and its five
    variants), `LiveBroadcast` (8 fields, including `startedAt`), `BroadcastFailure`
    (already fixed, unchanged).
  - Additive methods on Unit 5's existing shipped files: `RemoteBroadcastTarget.primeActivity()`
    (`lib/src/services/caption/remote_broadcast_target.dart` or wherever Unit 5 placed
    it) and `BroadcastTransport.sendBroadcastEnded()` (the `BroadcastTransport`
    interface and its `WebRtcBroadcastTransport` implementation, Unit 5's existing
    `lib/src/services/webrtc/` directory) — no new files for these, edits to Unit 5's
    shipped ones.
- `zip_broadcast`:
  - `lib/src/screens/` (existing convention) — `BroadcastSetupScreen`, the live
    dashboard screen (naming TBD at Code Generation per Functional Design Q8's single-
    route design).
  - `lib/src/widgets/` or `ZbAppShell`'s own file — the new `InheritedWidget` exposing
    `requestSignOut()` (Q6 of the Functional Design plan).
  - `main.dart` — the `captioningStarterProvider` override (mirrors the existing
    `authServiceProvider`/`supabaseClientProvider` override pattern, Unit 2).
  - `AccountSection` (existing file, `SettingsScreen`) — sign-out button call site
    switched from the direct `authNotifierProvider.notifier.signOut()` call to the new
    shell-scoped `requestSignOut()`.
- No change to `lib/src/services/signaling/`, `lib/src/services/webrtc/` (beyond the
  two additive methods above), or any `zip_supabase` file — this unit consumes Units
  3/3.1/4/5's shipped components as already-built dependencies.
