import 'dart:async';

import 'package:logging/logging.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/broadcast_status.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/output/on_screen_caption_target.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';
import 'package:zip_core/src/services/caption/caption_output_target_registry.dart';
import 'package:zip_core/src/services/caption/remote_caption_receiver.dart';
import 'package:zip_core/src/services/signaling/status_channel.dart';
import 'package:zip_core/src/services/webrtc/viewer_transport.dart';

/// The resources `ViewerSessionNotifier` owns for exactly one viewing
/// session (NFR Design Q1/Q4, `business-logic-model.md` F-7.7) — the one
/// teardown implementation shared by `leave()`, every terminal transition
/// and the reconnect window's expiry.
///
/// Package-internal (not exported from the barrel, matching Unit 6's
/// `SessionResources`). Every teardown-representable field is nullable and is
/// set to `null` by the step that releases it, so "released" is represented
/// by a null field rather than a boolean and a second [disposeAll] call is a
/// no-op. [disposeAll] never assigns the notifier's holder field — the
/// notifier is the single writer of that.
class ViewerSessionResources {
  /// Creates the holder for one viewing session.
  ViewerSessionResources({
    required this.broadcastId,
    required this.sessionId,
    required this.transport,
    required this.receiver,
    required this.bus,
    required this.registry,
    required this.target,
    required this.statusChannel,
    required this.statusWatch,
    required this.statusSub,
    required this.activitySub,
    required this.endedSub,
    required this.windowTimer,
    this.lastStatus,
  });

  /// The broadcast being viewed.
  final BroadcastId broadcastId;

  /// The ephemeral session id, once a `live` resolution supplied one. Set
  /// at allocation and updated by the F-7.8 auto-join (same broadcast, new
  /// session).
  String? sessionId;

  /// The viewer-side transport.
  ViewerTransport? transport;

  /// The receiver decoding captions from [transport] onto [bus].
  RemoteCaptionReceiver? receiver;

  /// The viewer-scoped caption bus — never the app's own bus (Rule 7).
  CaptionBus? bus;

  /// The viewer-scoped target registry.
  CaptionOutputTargetRegistry? registry;

  /// The viewer-scoped on-screen target (`repository: null` by design).
  OnScreenCaptionTarget? target;

  /// The broadcast's status channel.
  StatusChannel? statusChannel;

  /// The notifier's subscription to [statusChannel]'s `watch()`.
  StreamSubscription<BroadcastStatus>? statusWatch;

  /// The notifier's subscription to [transport]'s status stream.
  StreamSubscription<ConnectionStatus>? statusSub;

  /// The notifier's subscription to [receiver]'s activity stream.
  StreamSubscription<CaptionActivity>? activitySub;

  /// The notifier's subscription to [receiver]'s ended stream.
  StreamSubscription<void>? endedSub;

  /// The single reconnect-window timer (NFR Design Q2).
  Timer? windowTimer;

  /// The most recent status-channel emission — F-7.4 step 4's audit trail.
  BroadcastStatus? lastStatus;

  /// Attempts every teardown step in F-7.7's order, catching and logging each
  /// individually: never throwing, never skipping a later step because an
  /// earlier one failed (NFR Requirements Q3).
  ///
  /// [releaseTransport] defaults to `true`: [disposeAll] is called for both
  /// the user's exit and a terminal transition, and both release the
  /// connection. A future partial-release path says `false` here.
  ///
  /// [releaseCaptionPipeline] defaults to `true` (leave) and is `false` for
  /// a terminal transition: F-7.5 step 3 keeps the viewer-scoped
  /// bus/registry/target alive so the last captions stay visible until the
  /// user leaves, and what differs per state is the sub-resource set, not
  /// the holder's presence (`business-logic-model.md`, invariant 1).
  Future<void> disposeAll(
    Logger log, {
    bool releaseTransport = true,
    bool releaseCaptionPipeline = true,
  }) async {
    final timer = windowTimer;
    windowTimer = null;
    timer?.cancel();

    // Subscriptions are cancelled synchronously and their completion is
    // detached: awaiting a broadcast-stream cancellation parks the calling
    // async function in some schedulers, which would leave a terminal state
    // unreached. The cancellation itself still happens immediately, so no
    // event can be delivered after this point.
    final watch = statusWatch;
    statusWatch = null;
    _detach(log, 'statusWatch.cancel', watch?.cancel);

    final channel = statusChannel;
    statusChannel = null;
    if (channel != null) {
      await _step(log, 'statusChannel.close', channel.close);
    }

    final transport_ = transport;
    if (releaseTransport) {
      transport = null;
      if (transport_ != null) {
        await _step(log, 'transport.disconnect', transport_.disconnect);
      }
    }

    final receiver_ = receiver;
    receiver = null;
    if (receiver_ != null) {
      await _step(log, 'receiver.dispose', receiver_.dispose);
    }

    if (releaseCaptionPipeline) {
      final registry_ = registry;
      final target_ = target;
      target = null;
      registry = null;
      if (registry_ != null && target_ != null) {
        await _step(log, 'registry.remove', () => registry_.remove(target_));
      }
      if (registry_ != null) {
        await _step(log, 'registry.dispose', registry_.dispose);
      }

      final bus_ = bus;
      bus = null;
      if (bus_ != null) {
        await _step(log, 'bus.dispose', bus_.dispose);
      }
    }

    final statusSub_ = statusSub;
    statusSub = null;
    _detach(log, 'statusSub.cancel', statusSub_?.cancel);

    final activitySub_ = activitySub;
    activitySub = null;
    _detach(log, 'activitySub.cancel', activitySub_?.cancel);

    final endedSub_ = endedSub;
    endedSub = null;
    _detach(log, 'endedSub.cancel', endedSub_?.cancel);
  }

  /// Cancels a subscription and swallows its completion/error — the
  /// subscription is already detached from the holder, so nothing can
  /// observe it again (see [disposeAll]'s note on broadcast-stream
  /// cancellations).
  void _detach(
    Logger log,
    String name,
    Future<void>? Function()? cancel,
  ) {
    if (cancel == null) return;
    try {
      final pending = cancel();
      if (pending == null) return;
      unawaited(
        pending.then<void>(
          (_) {},
          onError: (Object e) {
            log.warning('$name failed: ${e.runtimeType}');
          },
        ),
      );
    } on Object catch (e) {
      log.warning('$name failed: ${e.runtimeType}');
    }
  }

  /// Runs one teardown step, logging the exception's runtime type only —
  /// never its text (Rule 8) — and swallowing it (catch-and-continue).
  Future<void> _step(
    Logger log,
    String name,
    Object? Function()? action,
  ) async {
    if (action == null) return;
    try {
      final result = action();
      if (result is Future) await result;
    } on Object catch (e) {
      log.warning('$name failed: ${e.runtimeType}');
    }
  }
}
