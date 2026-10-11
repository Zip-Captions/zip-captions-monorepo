import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/ice_server.dart';
import 'package:zip_core/src/services/signaling/signaling_service.dart';
import 'package:zip_core/src/services/webrtc/viewer_admission.dart';

/// Everything `BroadcastTransport.start()` needs (fixed shape, Application
/// Design Q5, **revised 2026-10-07** against Unit 3.1's final signaling
/// design).
///
/// Carries [signalingService]/[broadcastId] instead of a pre-opened
/// channel — there is no single shared channel to pass anymore.
/// `WebRtcBroadcastTransport` calls `signalingService.joinRequests(
/// broadcastId)` to learn about joins, then
/// `signalingService.sessionChannel(sessionId, peerId)` per accepted
/// viewer. Constructed by the caller (`BroadcastSessionNotifier`, Unit 6)
/// from values already available to it — this unit does not resolve these
/// itself.
class BroadcastTransportContext {
  /// Creates a [BroadcastTransportContext].
  const BroadcastTransportContext({
    required this.sessionId,
    required this.broadcastId,
    required this.signalingService,
    required this.iceServers,
    required this.admission,
  });

  /// The ephemeral session id this broadcast is running under.
  final String sessionId;

  /// The broadcaster's permanent broadcast id.
  final BroadcastId broadcastId;

  /// The signaling service used to learn about joins and open per-viewer
  /// channels.
  final SignalingService signalingService;

  /// ICE servers for every peer connection this broadcast creates.
  final List<IceServer> iceServers;

  /// Capacity admission tracking for this broadcast.
  final ViewerAdmission admission;
}
