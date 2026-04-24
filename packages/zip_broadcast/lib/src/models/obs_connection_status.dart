/// Simple UI-facing summary of the OBS WebSocket connection state.
///
/// Derived from the internal [ObsConnectionState] sealed class by
/// [ObsConnectionNotifier]. The UI layer uses this enum for colour-coded
/// [StatusPill] rendering.
enum ObsConnectionStatus {
  /// No connection attempt in progress.
  disconnected,

  /// Initial connection attempt under way.
  connecting,

  /// WebSocket established; captions are being forwarded.
  connected,

  /// Connection dropped; waiting for next reconnect attempt.
  reconnecting,

  /// Reconnect timeout or unrecoverable error.
  error,
}
