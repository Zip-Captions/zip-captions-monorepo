import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/ice_server.dart';
import 'package:zip_core/src/services/signaling/signaling_service.dart';

/// Everything `ViewerTransport.connect()` needs (fixed shape, Application
/// Design Q5, **revised 2026-10-07** against Unit 3.1's final signaling
/// design).
///
/// Carries [signalingService]/[broadcastId] instead of a pre-opened
/// channel. `WebRtcViewerTransport.connect()`/`restart()` generates a
/// fresh peer id internally on every call (never supplied via this
/// context, never reused — Unit 3.1 `business-rules.md` Rule 5), calls
/// `signalingService.submitJoinRequest(broadcastId, peerId)`, then opens
/// its own `signalingService.sessionChannel(sessionId, peerId)`.
class ViewerTransportContext {
  /// Creates a [ViewerTransportContext].
  const ViewerTransportContext({
    required this.sessionId,
    required this.broadcastId,
    required this.signalingService,
    required this.iceServers,
  });

  /// The ephemeral session id this viewer is joining.
  final String sessionId;

  /// The broadcast's permanent broadcast id.
  final BroadcastId broadcastId;

  /// The signaling service used to submit join requests and open the
  /// per-viewer channel.
  final SignalingService signalingService;

  /// ICE servers for this viewer's peer connection.
  final List<IceServer> iceServers;
}
