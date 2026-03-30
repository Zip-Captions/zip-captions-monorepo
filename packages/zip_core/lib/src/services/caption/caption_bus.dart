import 'dart:async';

import 'package:zip_core/src/models/caption_event.dart';

/// Pub-sub bus for caption events using a broadcast [StreamController].
///
/// All [CaptionEvent]s flow through this bus — STT results and session
/// state changes. The [CaptionOutputTargetRegistry] subscribes to
/// [stream] and fans out events to individual targets.
///
/// Held by a `keepAlive` Riverpod provider for app-lifetime persistence.
class CaptionBus {
  final StreamController<CaptionEvent> _controller =
      StreamController<CaptionEvent>.broadcast();

  /// Publish an event to all subscribers.
  ///
  /// No-op if the controller has been closed via [dispose].
  void publish(CaptionEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  /// The broadcast stream for subscribers.
  Stream<CaptionEvent> get stream => _controller.stream;

  /// Close the internal [StreamController].
  /// No further events can be published after this call.
  void dispose() {
    _controller.close();
  }
}
