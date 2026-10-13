import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zip_core/src/models/broadcast_failure.dart';
import 'package:zip_core/src/models/live_broadcast.dart';

part 'broadcaster_session_state.freezed.dart';

/// The broadcaster's own session state (fixed shape, Application Design —
/// renamed from `BroadcastSessionState` to [BroadcasterSessionState],
/// Functional Design Q2: the Application Design name collides with an
/// unrelated, already-shipped Phase 1 model of the same name in
/// `zip_broadcast` — the local multi-engine *captioning* session machine
/// used by `BroadcastRecordingNotifier`. Purely a rename; no field/variant/
/// behavior change from the fixed shape).
///
/// State machine (PBT-06 reference model, `domain-entities.md`):
/// `OfflineState --goLive--> StartingState --success--> LiveState
/// --endBroadcast--> EndingState --done--> OfflineState`;
/// `BroadcastFailedState --goLive--> StartingState`. `goLive()` is accepted
/// only from [OfflineState]/[BroadcastFailedState] (`business-rules.md`
/// Rule 1); `endBroadcast()` only from [LiveState] (Rule 5); all other calls
/// are no-ops.
@freezed
sealed class BroadcasterSessionState with _$BroadcasterSessionState {
  /// The initial state, and the state after a complete `endBroadcast()`.
  /// No session resources exist in this state.
  const factory BroadcasterSessionState.offline() = OfflineState;

  /// Exists only between `goLive()` being accepted and its 9-step sequence
  /// (`business-logic-model.md` F-6.2) resolving. Transient; never restored
  /// across app restarts.
  const factory BroadcasterSessionState.starting() = StartingState;

  /// The broadcast is live. Caption-activity and viewer changes are
  /// in-place updates to [broadcast] within this same variant, not variant
  /// transitions.
  const factory BroadcasterSessionState.live(LiveBroadcast broadcast) =
      LiveState;

  /// Exists only during `endBroadcast()`'s sequence (F-6.6); always
  /// resolves to [OfflineState].
  const factory BroadcasterSessionState.ending() = EndingState;

  /// The terminal result of a failed `goLive()`. All completed steps were
  /// unwound in reverse (`business-rules.md` Rule 2) — no session resources
  /// exist in this state, which is why it is a legitimate retry start point
  /// and a sign-out-allowed state (Rule 9).
  const factory BroadcasterSessionState.failed(BroadcastFailure reason) =
      BroadcastFailedState;
}
