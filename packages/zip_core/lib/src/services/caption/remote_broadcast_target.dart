import 'dart:async';

import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/services/caption/caption_output_target.dart';
import 'package:zip_core/src/services/webrtc/broadcast_transport.dart';

/// Forwards caption events to every connected viewer over
/// [BroadcastTransport] (fixed shape, Application Design).
///
/// Caption activity mapping (fixed at Application Design):
/// [RecordingActiveState] → [CaptionActivity.active];
/// [PausedState]/[ReconnectingState] → [CaptionActivity.paused];
/// [IdleState]/[StoppedState] → [CaptionActivity.inactive]. Before any
/// `SessionStateEvent` arrives, [currentActivity] defaults to
/// [CaptionActivity.inactive].
class RemoteBroadcastTarget implements CaptionOutputTarget {
  /// Creates a [RemoteBroadcastTarget] sending through [_transport].
  ///
  /// Fixed single-argument constructor (Application Design) — before the
  /// first `SessionStateEvent` arrives, [currentActivity] defaults to
  /// [CaptionActivity.inactive]; the caller is expected to register this
  /// target only once a session actually exists, at which point the
  /// first real state event supersedes this default immediately.
  RemoteBroadcastTarget(this._transport)
      : _currentActivity = CaptionActivity.inactive {
    _joinedSub = _transport.viewerJoined.listen((peerId) {
      _transport.sendTo(
        peerId,
        CaptionActivityChanged(activity: _currentActivity),
      );
    });
  }

  final BroadcastTransport _transport;
  CaptionActivity _currentActivity;
  late final StreamSubscription<String> _joinedSub;
  final _activityController = StreamController<CaptionActivity>.broadcast();

  @override
  String get targetId => 'remote_broadcast';

  /// This broadcast's current caption activity.
  CaptionActivity get currentActivity => _currentActivity;

  /// Seeds [currentActivity] from the app's actual recording state at
  /// registration time (Functional Design Q4 — additive, non-breaking).
  ///
  /// The fixed single-argument constructor always defaults
  /// [currentActivity] to [CaptionActivity.inactive]; if captioning was
  /// already running when `goLive()` registers this target, no
  /// `SessionStateEvent` will ever fire to correct that default, so newly
  /// joined viewers would get a wrong `inactive` snapshot. Sets the value
  /// directly — deliberately **does not** emit on [activityChanges]: this
  /// seeds the initial value before any real state-change event, so there
  /// is no prior value for a change notification to be relative to.
  // ignore: use_setters_to_change_properties
  void primeActivity(CaptionActivity activity) {
    _currentActivity = activity;
  }

  /// Fires whenever [currentActivity] changes — drives the dashboard
  /// captions-inactive banner.
  Stream<CaptionActivity> get activityChanges => _activityController.stream;

  @override
  void onCaptionEvent(CaptionEvent event) {
    switch (event) {
      case SttResultEvent(:final result):
        _transport.sendToAll(Caption(result: result));
      case SessionStateEvent(:final state):
        final next = _mapActivity(state);
        if (next == _currentActivity) return;
        _currentActivity = next;
        _transport.sendToAll(CaptionActivityChanged(activity: next));
        _activityController.add(next);
    }
  }

  @override
  void dispose() {
    unawaited(_joinedSub.cancel());
    unawaited(_activityController.close());
  }

  static CaptionActivity _mapActivity(RecordingState state) => switch (state) {
        RecordingActiveState() => CaptionActivity.active,
        PausedState() || ReconnectingState() => CaptionActivity.paused,
        IdleState() || StoppedState() => CaptionActivity.inactive,
      };
}
