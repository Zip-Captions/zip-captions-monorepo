import 'package:zip_core/src/models/presence_snapshot.dart';
import 'package:zip_core/src/models/signaling_message.dart';

/// A `signaling:{session_id}` channel (SR-02 §4), role-scoped at open time
/// via `SignalingService.sessionChannel`.
///
/// RLS establishes channel membership only; per-message-*type*
/// authorization (e.g. only the broadcaster may send `BroadcastEnded`) is
/// Unit 5's transport-layer responsibility, informed by this unit's
/// [SignalingMessage] sealed type (Rule 5, `business-rules.md`) — this
/// interface does not enforce it.
abstract interface class SessionSignalingChannel {
  /// Joins the underlying Realtime channel. Must be called before [send] or
  /// reading [messages]/[presence].
  Future<void> open();

  /// Sends [message] to every other peer on this session.
  Future<void> send(SignalingMessage message);

  /// Already-validated inbound messages. Malformed/unrecognized payloads
  /// are dropped before reaching this stream (`SignalingCodec.decode`,
  /// Rule 4), never surfaced as an error.
  Stream<SignalingMessage> get messages;

  /// Presence-derived viewer count. Broadcaster role only — enforced
  /// server-side (SR-02 §4); a viewer-opened channel's `presence` stream
  /// never emits (RLS blocks the read entirely rather than this interface
  /// filtering it client-side).
  Stream<PresenceSnapshot> get presence;

  /// Leaves the channel and releases its underlying Realtime subscription.
  Future<void> close();
}
