import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

/// The native close notification for a sub-window, on the **main** engine.
///
/// `desktop_multi_window` tears a sub-engine down inside its own close handling
/// and its window channel is plugin-private, so a runner raises the close from
/// native code on a first-party channel instead (RQ-3 A as amended; FD BLM
/// §3.2; NFR Design §5.2).
///
/// This is a process-level fan-out, not a router: every controller subscribes
/// and filters by its own window id, so an id that matches no controller
/// reaches no controller.
abstract interface class SubWindowClosedChannel {
  /// The main-engine channel name. Fixed for both apps (NFR Design L5).
  static const String channelName = 'zip_core/overlay_sub_window_events';

  /// The method the runner invokes.
  static const String method = 'subWindowClosed';

  /// Installs the method handler. Idempotent.
  void install();

  /// Window ids as they arrive, in arrival order.
  ///
  /// Broadcast: a controller subscribes in `_bootstrap`, which runs before it
  /// can open a window, so no event is missed. A malformed call is dropped
  /// silently — it is not caption data and must not become a log line.
  Stream<int> get closed;

  /// Uninstalls the handler and closes [closed]. Idempotent.
  void dispose();
}

/// The production channel, over a `MethodChannel` on the main engine.
class MethodChannelSubWindowClosedChannel implements SubWindowClosedChannel {
  /// Creates the channel.
  MethodChannelSubWindowClosedChannel({
    MethodChannel? channel,
    Logger? log,
  })  : _channel =
            channel ?? const MethodChannel(SubWindowClosedChannel.channelName),
        _log = log ?? Logger('zip_core.SubWindowClosedChannel');

  final MethodChannel _channel;
  final Logger _log;
  final StreamController<int> _closed = StreamController<int>.broadcast();
  bool _installed = false;

  @override
  Stream<int> get closed => _closed.stream;

  @override
  void install() {
    if (_installed) return;
    _installed = true;
    try {
      _channel.setMethodCallHandler(_onCall);
    } on Object catch (error) {
      // Linux records "unavailable" and lets the app continue: the `'-1'`
      // fallback covers a platform that cannot deliver the notification
      // (NFR Design §3.4).
      _log.info('sub-window close channel unavailable: ${error.runtimeType}');
    }
  }

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method != SubWindowClosedChannel.method) return null;
    final arguments = call.arguments;
    if (arguments is! Map) return null;
    final windowId = arguments['windowId'];
    if (windowId is! int || windowId < 0) return null;
    if (!_closed.isClosed) _closed.add(windowId);
    return null;
  }

  @override
  void dispose() {
    if (_installed) {
      _installed = false;
      try {
        _channel.setMethodCallHandler(null);
      } on Object {
        // Uninstalling a channel that was never installed is harmless.
      }
    }
    unawaited(_closed.close());
  }
}
