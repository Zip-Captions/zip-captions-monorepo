import 'package:zip_broadcast/src/models/obs_connection_status.dart';

/// Thrown when an OBS WebSocket operation fails.
class ObsConnectionException implements Exception {
  /// Creates an [ObsConnectionException].
  const ObsConnectionException(this.message);

  /// Human-readable reason. Must not contain the OBS password (SEC-U6.2).
  final String message;

  @override
  String toString() => 'ObsConnectionException: $message';
}

/// Testable interface for OBS WebSocket connection management.
///
/// The production implementation wraps the `obs_websocket` client; tests
/// inject a mock implementation of this interface.
abstract interface class ObsWebSocketTarget {
  /// Initiate a connection using pre-configured settings.
  Future<void> connect();

  /// Disconnect and cancel any pending reconnect.
  Future<void> disconnect();

  /// Attempt a one-shot test connection and return the result.
  ///
  /// Times out and returns [ObsConnectionStatus.error] after [timeout].
  Future<ObsConnectionStatus> testConnection({
    Duration timeout = const Duration(seconds: 5),
  });

  /// Send a final caption string to OBS.
  Future<void> send(String captionText);

  /// Stream of connection state changes.
  ///
  /// Emits on every state transition; the latest value is not replayed.
  Stream<ObsConnectionStatus> get statusStream;

  /// Release all resources held by this target.
  void dispose();
}
