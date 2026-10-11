import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/models/viewer_transport_context.dart';

/// The viewer-side WebRTC transport (fixed shape, Application Design).
abstract interface class ViewerTransport {
  /// Connects to the broadcast described by [context].
  Future<void> connect(ViewerTransportContext context);

  /// ICE restart / re-signal after a network change
  /// (`business-rules.md` Rule 2).
  Future<void> restart();

  /// Disconnects explicitly — the one caller-initiated path to
  /// `ConnectionStatus.Failed` (`business-rules.md` Rule 2).
  Future<void> disconnect();

  /// Incoming caption messages, already decoded.
  Stream<CaptionWireMessage> get messages;

  /// This viewer's own connection status changes.
  Stream<ConnectionStatus> get status;
}
