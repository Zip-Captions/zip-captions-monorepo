# Code Summary — Unit 7: Zip Captions Viewer (`zip_core`)

## Story Implemented

- **S-19**: A viewer joins a broadcaster's live captions from a link or typed
  code and sees the captions with a status line, without any account and
  without the captions ever touching the app's own pipeline.

## Verification Results

| Check | Result |
|-------|--------|
| `dart analyze --fatal-infos` (`zip_core`) | 0 errors, 0 warnings, 0 infos |
| `flutter test` (`zip_core`) | 599 passed, 4 skipped (`@Tags(['integration-supabase'])`) |
| `dart analyze --fatal-infos` (`zip_captions`) | 0 errors, 0 warnings, 0 infos |
| `flutter test` (`zip_captions`) | 124 passed |

## Files Created

| File | Purpose |
|------|---------|
| `lib/src/constants/broadcast_link_config.dart` | `broadcastBaseUrl` from `--dart-define=BROADCAST_BASE_URL`, defaulting to the v1 apex path |
| `lib/src/models/viewer_session_state.dart` (+ `.freezed.dart`) | The 10-variant sealed viewer state; `IdleState`/`ReconnectingState` are `ViewerIdleState`/`ViewerReconnectingState` to avoid Phase 1 collisions |
| `lib/src/models/reconnect_policy.dart` | `nextDelay(attempt, elapsed)` against the fixed reconnect window; no clock, no I/O |
| `lib/src/providers/viewer_transport_factory_provider.dart` (+ `.g.dart`) | Builds the viewer transport, mirroring the broadcaster factory |
| `lib/src/services/broadcast/viewer_session_resources.dart` | The per-session holder: bus, registry, target, transport, receiver, status channel and subscriptions, one `disposeAll` |
| `lib/src/services/broadcast/viewer_session_notifier.dart` (+ `.g.dart`) | Join/resolve/connect, scoped auto-join, reconnect give-up window, idempotent `leave()` |

## Files Modified

| File | Change |
|------|--------|
| `lib/src/models/connect_failure.dart` | Added `RateLimited`, `ResolutionFailed`, `NotFound`; the original four are untouched |
| `lib/src/models/broadcast_link.dart` | `baseUrl` removed; `toUrl` interpolates `broadcastBaseUrl` |
| `lib/src/models/models.dart`, `lib/src/services/broadcast/broadcast.dart`, `lib/src/providers/providers.dart` | Barrel exports |
| `test/helpers/fake_broadcast_session_collaborators.dart` | `FakeBroadcastResolver`, `FakeViewerTransport`, `FakeStatusChannel.watchCalls`/`emitStatus` |
| `test/helpers/generators.dart` | Viewer command generators and the sealed `ViewerSessionCommand` hierarchy |
| `test/pbt/broadcast_link_test.dart` | Configured-base row, invalid-input row, default-apex pin |

## Tests Added

| File | Coverage |
|------|----------|
| `test/models/connect_failure_test.dart` | Seven variants, equality, exhaustive switch |
| `test/models/reconnect_policy_test.dart` | Window semantics and the no-timer invariant |
| `test/models/viewer_session_state_test.dart` | Variant equality/`copyWith`, no caption content |
| `test/services/broadcast/viewer_session_resources_test.dart` | Teardown completeness and idempotence |
| `test/services/broadcast/viewer_session_notifier_test.dart` | 37 rows: join, resolve outcomes, auto-join, terminal transitions, leave |
| `test/services/broadcast/viewer_session_notifier_reconnect_test.dart` | 8 rows: the give-up window and the no-notifier-retry rule |
| `test/pbt/viewer_session_state_machine_properties_test.dart` | PBT-06 transition model |
| `test/pbt/viewer_session_leave_idempotence_test.dart` | PBT-04 leave idempotence |

## Security and NFR Notes

- Remote captions flow only through the viewer-scoped bus and an
  `OnScreenCaptionTarget` constructed with `repository: null`; nothing is
  persisted and the app's own pipeline is never touched (Rule 7).
- Logs carry state names, reasons, IDs and `runtimeType` only — never caption
  text and never the raw joined input (Rule 8).
- `transport.restartCalls` stays zero across every suite: reconnection cadence
  belongs to the shipped transport, and the notifier owns only the give-up
  window (Rule 14).