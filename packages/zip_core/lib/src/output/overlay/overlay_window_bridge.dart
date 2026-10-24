/// The sub-engine's only channel to its host process (ID-2).
///
/// The overlay window runs in its own Flutter engine, created by
/// `desktop_multi_window`. It receives `captionUpdate` calls from the main
/// engine and sends `overlayReady` back to it. Everything that touches the
/// plugin sits behind this seam, so the window entry point stays testable with
/// a plain fake.
abstract interface class OverlayWindowBridge {
  /// Starts delivering calls from the main engine to [onCall].
  ///
  /// [onCall] receives the method name and its already-decoded argument.
  void listen(void Function(String method, Object? arguments) onCall);

  /// Sends an [arguments] payload to the main engine.
  void send(Object? arguments);

  /// Asks the main engine to close the pop-out (UX-PIP-02, FD BLM §3.3).
  ///
  /// The sub-engine never closes its own window: the main engine owns the
  /// lifecycle, so the close arrives through the normal toggle-off path. The
  /// message carries no payload and no caption text.
  void sendPopOutToggle();
}
