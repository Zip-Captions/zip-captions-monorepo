/// The main-engine close notification for a sub-window (NFR Design §5.2).
///
/// Split from its implementations so the contract is reachable from every
/// platform: the interface names no plugin and imports nothing, while the
/// `_io` implementation is the one that reaches for
/// `package:flutter/services.dart`.
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
