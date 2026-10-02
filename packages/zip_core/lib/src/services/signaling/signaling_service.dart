import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/services/signaling/session_signaling_channel.dart';
import 'package:zip_core/src/services/signaling/status_channel.dart';

/// Role a caller opens a [SessionSignalingChannel] as — affects which
/// presence stream (`messages`) it may read, not which messages it may
/// send (RLS enforces channel membership; message-*type* authorization is
/// Unit 5's transport-layer concern, SR-02 §4).
enum SignalingRole {
  /// The broadcaster for this session.
  broadcaster,

  /// A viewer of this session.
  viewer,
}

/// Factory for the two Realtime channel types this unit defines (SR-02 §4):
/// `status:{broadcast_id}` and `signaling:{session_id}`.
abstract interface class SignalingService {
  /// Opens the status channel for [id].
  StatusChannel statusChannel(BroadcastId id);

  /// Opens the signaling channel for [sessionId], scoped by [role].
  SessionSignalingChannel sessionChannel(String sessionId, SignalingRole role);
}
