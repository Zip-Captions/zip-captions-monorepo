import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/connect_failure.dart';
import 'package:zip_core/src/models/connection_status.dart';

part 'viewer_session_state.freezed.dart';

/// The viewer's own session state (fixed shape, Application Design; variant
/// meanings in `domain-entities.md`).
///
/// State machine (PBT-06 reference model, `business-logic-model.md`):
/// `IdleState --join(valid)--> ResolvingState --resolution--> ConnectingState
/// / NotBroadcastingState / CannotConnectState`; transport status drives
/// `ConnectingState`/`ReconnectingState`/`LiveViewState`/`FullState`; the
/// receiver's `ended` and any user leave end in `EndedState`/`IdleState`.
/// Named `LiveViewState` because Unit 6's [BroadcasterSessionState] already
/// owns a `LiveState` variant in this package.
///
/// No variant carries caption or join-input content: `InvalidInputState` is
/// data-free and the live variant carries only activity/routing metadata
/// (`business-rules.md` Rule 8).
@freezed
sealed class ViewerSessionState with _$ViewerSessionState {
  /// The initial state and the state after `leave()`. No session resources
  /// exist here.
  const factory ViewerSessionState.idle() = IdleState;

  /// Between `join()` accepting a parsed input and the resolver returning.
  /// Precedes resource allocation, so no session resources exist here.
  const factory ViewerSessionState.resolving() = ResolvingState;

  /// Resolution returned `live`; the join handshake is in flight.
  const factory ViewerSessionState.connecting() = ConnectingState;

  /// Connected. Both fields update in place within this same variant as the
  /// broadcaster's activity changes or the connection re-routes — there is
  /// no separate "paused" variant (`domain-entities.md`).
  const factory ViewerSessionState.liveView({
    required CaptionActivity captionActivity,
    required ConnectionType connectionType,
  }) = LiveViewState;

  /// The transport reports `Interrupted`; reconnection is underway and the
  /// last received captions remain visible.
  const factory ViewerSessionState.reconnecting() = ReconnectingState;

  /// The broadcast exists but no broadcaster is live. The status watch
  /// stays open and auto-joins on a live emission (`business-rules.md`
  /// Rule 4a).
  const factory ViewerSessionState.notBroadcasting() = NotBroadcastingState;

  /// The broadcaster ended the broadcast. Terminal with respect to
  /// auto-behaviour (Rule 6).
  const factory ViewerSessionState.ended() = EndedState;

  /// The broadcaster refused the join as full. Terminal with respect to
  /// auto-behaviour; retry is manual only.
  const factory ViewerSessionState.full() = FullState;

  /// "Cannot connect, with a specific reason" (FR-7.4). Each reason maps to
  /// exactly one rendering and retry affordance (Rule 5).
  const factory ViewerSessionState.cannotConnect(ConnectFailure reason) =
      CannotConnectState;

  /// Deep-link input that failed `BroadcastLink.parseInput`; no network
  /// request was made. Data-free by design (Rule 8).
  const factory ViewerSessionState.invalidInput() = InvalidInputState;
}