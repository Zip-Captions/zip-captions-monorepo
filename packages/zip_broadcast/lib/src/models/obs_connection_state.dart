/// The OBS WebSocket connection state machine.
///
/// Sealed for exhaustive matching in the UI layer.
sealed class ObsConnectionState {
  const ObsConnectionState();
}

/// No active connection; user must enable OBS output to connect.
class ObsDisconnected extends ObsConnectionState {
  /// Creates an [ObsDisconnected] instance.
  const ObsDisconnected();
}

/// Initial connection attempt in progress.
class ObsConnecting extends ObsConnectionState {
  /// Creates an [ObsConnecting] instance.
  const ObsConnecting();
}

/// WebSocket established; captions are being sent.
class ObsConnected extends ObsConnectionState {
  /// Creates an [ObsConnected] instance.
  const ObsConnected();
}

/// Connection dropped; waiting for next retry.
class ObsReconnecting extends ObsConnectionState {
  /// Creates an [ObsReconnecting] instance.
  const ObsReconnecting({required this.attempt, required this.nextRetryMs});

  /// Current retry attempt number (1-based).
  final int attempt;

  /// Milliseconds until the next connection attempt.
  final int nextRetryMs;
}

/// Connection gave up (10-minute timeout exhausted) or unrecoverable error.
class ObsError extends ObsConnectionState {
  /// Creates an [ObsError] instance.
  const ObsError({required this.message});

  /// Human-readable error description. Must not contain the OBS password.
  final String message;
}
