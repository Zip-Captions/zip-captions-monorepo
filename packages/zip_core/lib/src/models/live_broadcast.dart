import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/viewer_connection_info.dart';

part 'live_broadcast.freezed.dart';

/// A live broadcast's full dashboard state (fixed shape plus one approved
/// addition, Functional Design Q3). The first seven fields are fixed at
/// Application Design; [startedAt] is an approved deviation (Q3, option
/// B) — not in the fixed 7-field shape.
@freezed
abstract class LiveBroadcast with _$LiveBroadcast {
  /// Creates a [LiveBroadcast].
  const factory LiveBroadcast({
    /// The broadcaster's permanent broadcast id — identical across all of
    /// this broadcaster's broadcasts.
    required BroadcastId broadcastId,

    /// The stable, shareable broadcast URL — always consistent with
    /// [broadcastId] (`BroadcastLink.toUrl`).
    required Uri url,

    /// A fresh id per `goLive()` — never an account identifier.
    required String sessionId,

    /// The validated name from `BroadcastSettings` (Rule 7).
    required String sessionName,

    /// This broadcast's current caption activity — drives the
    /// captions-inactive banner (FR-6.7).
    required CaptionActivity captionActivity,

    /// An exact mirror of `BroadcastTransport.viewers` — ack-confirmed
    /// viewers only (`business-rules.md` Rule 11).
    required List<ViewerConnectionInfo> viewers,

    /// This broadcast's viewer capacity ceiling
    /// (`defaultBroadcastLimits.maxViewers`).
    required int maxViewers,

    /// When this broadcast went live — stamped once, at `goLive()`'s F2-9
    /// step, never reused across sessions (Functional Design Q3, approved
    /// deviation from the fixed 7-field shape).
    required DateTime startedAt,
  }) = _LiveBroadcast;
}
