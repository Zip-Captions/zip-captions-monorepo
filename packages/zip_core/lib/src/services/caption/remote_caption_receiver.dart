import 'dart:async';

import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';
import 'package:zip_core/src/services/webrtc/viewer_transport.dart';

/// Receives caption traffic over a [ViewerTransport] and republishes it as
/// [CaptionEvent]s on a viewer-side [CaptionBus] (fixed shape, Application
/// Design).
class RemoteCaptionReceiver {
  /// Creates a [RemoteCaptionReceiver] reading from [transport] and
  /// publishing to [viewerBus].
  RemoteCaptionReceiver({
    required ViewerTransport transport,
    required CaptionBus viewerBus,
  }) : _viewerBus = viewerBus {
    _sub = transport.messages.listen(_handleMessage);
  }

  final CaptionBus _viewerBus;
  late final StreamSubscription<CaptionWireMessage> _sub;
  final _activityController = StreamController<CaptionActivity>.broadcast();
  final _endedController = StreamController<void>.broadcast();

  /// This broadcast's caption activity, as reported by the broadcaster.
  Stream<CaptionActivity> get activity => _activityController.stream;

  /// Fires once when the broadcast ends.
  Stream<void> get ended => _endedController.stream;

  void _handleMessage(CaptionWireMessage message) {
    switch (message) {
      case Caption(:final result):
        _viewerBus.publish(SttResultEvent(result));
      case CaptionActivityChanged(:final activity):
        _activityController.add(activity);
      case Ended():
        _endedController.add(null);
    }
  }

  /// Releases this receiver's subscription.
  void dispose() {
    unawaited(_sub.cancel());
    unawaited(_activityController.close());
    unawaited(_endedController.close());
  }
}
