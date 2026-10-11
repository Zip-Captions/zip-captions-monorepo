import 'package:zip_core/src/services/webrtc/web_rtc_broadcast_transport.dart';
import 'package:zip_core/src/services/webrtc/web_rtc_viewer_transport.dart';

/// Selects the transport implementation for this broadcast/viewer (fixed
/// shape, Application Design).
///
/// Phase 2: always WebRTC. Later phases add relay / local WebSocket / BLE
/// GATT — this class is the one seam that will need to grow when they
/// arrive; nothing else in this unit depends on the selection logic.
class TransportSelector {
  /// Creates a [TransportSelector].
  const TransportSelector();

  /// Returns the broadcaster-side transport for Phase 2.
  WebRtcBroadcastTransport broadcastTransport() =>
      WebRtcBroadcastTransport();

  /// Returns the viewer-side transport for Phase 2.
  WebRtcViewerTransport viewerTransport() => WebRtcViewerTransport();
}
