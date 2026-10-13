import 'dart:async';

import 'package:logging/logging.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/viewer_connection_info.dart';
import 'package:zip_core/src/services/caption/caption_output_target_registry.dart';
import 'package:zip_core/src/services/caption/remote_broadcast_target.dart';
import 'package:zip_core/src/services/signaling/status_channel.dart';
import 'package:zip_core/src/services/webrtc/broadcast_transport.dart';
import 'package:zip_core/src/services/webrtc/viewer_admission.dart';

/// The resources `BroadcastSessionNotifier` owns for exactly one live
/// session (NFR Design Q1) — a shared disposal mechanism so
/// `goLive()`'s unwind (`business-rules.md` Rule 2) and `endBroadcast()`'s
/// teardown (Rule 5) never duplicate the catch-and-continue logic each one
/// needs (NFR Requirements Q3).
///
/// `BroadcastSessionNotifier` holds at most one [SessionResources]
/// instance at a time (held privately, not exported from the package
/// barrel — internal to this unit's implementation): non-null for every
/// non-idle
/// `BroadcasterSessionState` (`StartingState`/`LiveState`/`EndingState`),
/// `null` for every idle one (`OfflineState`/`BroadcastFailedState`) — the
/// precondition both Rules 1 and 5 rely on for those being legal retry/
/// sign-out points.
class SessionResources {
  /// Creates a [SessionResources] bundle for one live session.
  SessionResources({
    required this.statusChannel,
    required this.admission,
    required this.transport,
    required this.target,
    required this.registry,
    required this.activitySub,
    required this.viewersSub,
  });

  /// The broadcaster's `status:{broadcast_id}` presence channel.
  final StatusChannel statusChannel;

  /// Capacity admission tracking for this session.
  final ViewerAdmission admission;

  /// The WebRTC broadcaster-side transport for this session.
  final BroadcastTransport transport;

  /// The caption output target forwarding to [transport].
  final RemoteBroadcastTarget target;

  /// The registry [target] was registered with — needed to remove it.
  final CaptionOutputTargetRegistry registry;

  /// The notifier's own subscription to [target].activityChanges.
  final StreamSubscription<CaptionActivity> activitySub;

  /// The notifier's own subscription to [transport].viewers.
  final StreamSubscription<List<ViewerConnectionInfo>> viewersSub;

  /// Attempts every teardown step in order, catching and logging each
  /// individually — never throwing itself, never skipping a later step
  /// because an earlier one failed (NFR Requirements Q3, NFR Design Q1).
  Future<void> disposeAll(Logger log) async {
    try {
      await statusChannel.close();
    } on Object catch (e) {
      log.warning('statusChannel.close() failed: ${e.runtimeType}');
    }
    try {
      registry.remove(target);
    } on Object catch (e) {
      log.warning('registry.remove(target) failed: ${e.runtimeType}');
    }
    try {
      await transport.stop();
    } on Object catch (e) {
      log.warning('transport.stop() failed: ${e.runtimeType}');
    }
    try {
      await activitySub.cancel();
    } on Object catch (e) {
      log.warning('activitySub.cancel() failed: ${e.runtimeType}');
    }
    try {
      await viewersSub.cancel();
    } on Object catch (e) {
      log.warning('viewersSub.cancel() failed: ${e.runtimeType}');
    }
  }
}
