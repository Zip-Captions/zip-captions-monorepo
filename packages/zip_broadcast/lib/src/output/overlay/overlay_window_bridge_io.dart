import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_window_bridge.dart';

/// The real sub-engine channel, over `desktop_multi_window` (ID-2).
///
/// This is the only file on the sub-engine side that touches the plugin: it
/// installs the method handler that receives `captionUpdate` from the main
/// engine and sends `overlayReady` back to window `0`.
///
/// Nothing here inspects or logs the payload: caption text travels through as
/// an already-encoded string and is never written to a log line (BR-U8-18).
class DesktopMultiWindowBridge implements OverlayWindowBridge {
  @override
  void listen(void Function(String method, Object? arguments) onCall) {
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      onCall(call.method, call.arguments);
      return null;
    });
  }

  @override
  void send(Object? arguments) {
    // Fire-and-forget: the main engine treats readiness as an event, and a
    // failed send means the host is gone, which the ready timeout covers.
    unawaited(DesktopMultiWindow.invokeMethod(0, 'overlayReady', arguments));
  }
}
