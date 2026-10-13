import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_core/zip_core.dart';

/// `zip_broadcast`'s override of `zip_core`'s `captioningStarterProvider`
/// (Functional Design Q1) — backed by [BroadcastRecordingNotifier]'s
/// multi-engine state machine instead of `zip_captions`' single-engine
/// `RecordingStateNotifier`. Same override pattern as `authServiceProvider`
/// (Unit 2).
class BroadcastCaptioningStarter implements CaptioningStarter {
  /// Creates a [BroadcastCaptioningStarter] reading
  /// `broadcastRecordingNotifierProvider` through [_ref].
  BroadcastCaptioningStarter(this._ref);

  final Ref _ref;

  @override
  CaptionActivity get currentActivity =>
      switch (_ref.read(broadcastRecordingNotifierProvider)) {
        BroadcastActiveState() => CaptionActivity.active,
        BroadcastPausedState() ||
        BroadcastReconnectingState() => CaptionActivity.paused,
        BroadcastIdleState() || BroadcastStoppedState() =>
          CaptionActivity.inactive,
      };

  @override
  Future<void> start() =>
      _ref.read(broadcastRecordingNotifierProvider.notifier).start();
}
