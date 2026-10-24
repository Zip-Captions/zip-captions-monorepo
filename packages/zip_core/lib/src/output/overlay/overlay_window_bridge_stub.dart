import 'package:zip_core/src/output/overlay/overlay_window_bridge.dart';

/// The no-op bridge for platforms that cannot host a second window.
///
/// The overlay engine never starts there, so [listen] records nothing and
/// [send] does nothing (BR-U8-11).
class NoopOverlayWindowBridge implements OverlayWindowBridge {
  @override
  void listen(void Function(String method, Object? arguments) onCall) {}

  @override
  void send(Object? arguments) {}

  @override
  void sendPopOutToggle() {}
}
