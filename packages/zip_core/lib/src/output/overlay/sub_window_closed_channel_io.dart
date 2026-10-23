import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/src/output/overlay/sub_window_closed_channel_contract.dart'
    show SubWindowClosedChannel;

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
