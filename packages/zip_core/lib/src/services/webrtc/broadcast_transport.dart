import 'package:zip_core/src/models/broadcast_transport_context.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/viewer_connection_info.dart';

/// The broadcaster-side WebRTC transport (fixed shape, Application
/// Design).
abstract interface class BroadcastTransport {
  /// Starts accepting joins for the broadcast described by [context].
  Future<void> start(BroadcastTransportContext context);

  /// Closes every peer connection and releases all native resources.
  Future<void> stop();

  /// Sends [message] to every connected viewer; a slow or closed channel on
  /// one viewer never blocks delivery to any other (NFR-4.2).
  void sendToAll(CaptionWireMessage message);

  /// Sends [message] to exactly one viewer, identified by [peerId].
  void sendTo(String peerId, CaptionWireMessage message);

  /// The current set of connected (ack-confirmed) viewers, updated on every
  /// join/leave.
  Stream<List<ViewerConnectionInfo>> get viewers;

  /// Fires with a viewer's `peerId` once it's ack-confirmed joined
  /// (`business-rules.md` Rule 1) — used for the caption-activity snapshot
  /// (Rule 8).
  Stream<String> get viewerJoined;

  /// Fires with a viewer's `peerId` once it's left (clean or unclean).
  Stream<String> get viewerLeft;
}
