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

  /// Presence-derived viewer count.
  ///
  /// **Not restricted to the broadcaster at the RLS layer** — RLS cannot
  /// check "does this caller own this session" without a persisted
  /// session-owner mapping, which FR-2.6 rules out (no session records in
  /// Postgres). Any authenticated caller on this session can read this
  /// stream (anon cannot). Per-role viewer-count privacy, if needed, is
  /// Unit 5's transport-layer responsibility, the same RLS-can't-express-it
  /// split SR-02 §4 already uses for message-type authorization — this
  /// interface does not enforce it. (Corrected 2026-10-01, PR #24 review —
  /// the previous doc comment claimed an RLS guarantee that never existed.)
  Stream<PresenceSnapshot> get presence;

  /// Leaves the channel and releases its underlying Realtime subscription.
  Future<void> close();
}
