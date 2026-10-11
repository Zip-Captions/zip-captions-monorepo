import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zip_core/src/models/connection_status.dart';

part 'viewer_connection_info.freezed.dart';

/// A broadcaster-side snapshot of one connected viewer (FR-4.6).
///
/// "No viewer identity" (NFR-6.2) means exactly [peerId] (the ephemeral
/// signaling-layer id) and nothing from account/auth identity. [connectedAt]
/// is set once, at the moment a viewer is added to `BroadcastTransport.viewers`
/// — i.e. after the ack-timer confirms the viewer (`business-rules.md` Rule
/// 1), never at the raw data-channel "open" event.
@freezed
abstract class ViewerConnectionInfo with _$ViewerConnectionInfo {
  /// Creates a [ViewerConnectionInfo].
  const factory ViewerConnectionInfo({
    /// The viewer's ephemeral signaling-layer peer id.
    required String peerId,

    /// How this viewer's connection is currently routed.
    required ConnectionType connectionType,

    /// When this viewer was confirmed joined (ack-timer success).
    required DateTime connectedAt,
  }) = _ViewerConnectionInfo;
}
