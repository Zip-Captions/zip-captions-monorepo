import 'package:zip_core/src/models/signaling_message.dart';

/// A `signaling:{session_id}:{peerId}` channel (SR-04 §3), opened by both
/// the broadcaster (once per accepted viewer) and that one viewer for the
/// same `(sessionId, peerId)` pair — unlike Unit 3's original single
/// shared `signaling:{session_id}` channel, this one is scoped to exactly
/// two participants.
///
/// RLS establishes channel membership only; per-message-*type*
/// authorization (e.g. only the broadcaster may send `BroadcastEnded`) is
/// Unit 5's transport-layer responsibility, informed by this unit's
/// [SignalingMessage] sealed type (Rule 8, `business-rules.md` — this
/// unit's own signaling-channel-privacy rules) — this interface does not
/// enforce it.
///
/// No presence stream (dropped entirely, SR-04 §4 — Unit 5 never relied
/// on it, and Realtime presence has no per-subscriber filtering to
/// exploit even if scoped narrowly).
abstract interface class SessionSignalingChannel {
  /// Joins the underlying Realtime channel. Must be called before [send] or
  /// reading [messages].
  Future<void> open();

  /// Sends [message] to the other peer on this channel.
  Future<void> send(SignalingMessage message);

  /// Already-validated inbound messages. Malformed/unrecognized payloads
  /// are dropped before reaching this stream (`SignalingCodec.decode`,
  /// Rule 4), never surfaced as an error.
  Stream<SignalingMessage> get messages;

  /// Leaves the channel and releases its underlying Realtime subscription.
  Future<void> close();
}
