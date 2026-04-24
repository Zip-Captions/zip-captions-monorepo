/// State machine for [BroadcastRecordingNotifier].
///
/// Parallel to the zip_core [RecordingState] hierarchy but extended to carry
/// per-engine state for N concurrent [SttEngine] instances.
sealed class BroadcastSessionState {
  const BroadcastSessionState();

  /// Whether at least one engine is actively producing captions.
  bool get isRecording => false;

  /// Whether the session is intentionally paused.
  bool get isPaused => false;
}

/// No active session. Initial state, also returned after [stop]/[clearSession].
class BroadcastIdleState extends BroadcastSessionState {
  /// Creates a [BroadcastIdleState].
  const BroadcastIdleState({this.lastError});

  /// Non-null when the previous start attempt failed entirely.
  final Object? lastError;
}

/// All engines initialised and at least one is actively listening.
class BroadcastActiveState extends BroadcastSessionState {
  /// Creates a [BroadcastActiveState].
  const BroadcastActiveState({
    required this.sessionId,
    required this.perEngineStates,
  });

  /// UUID v4 for this session.
  final String sessionId;

  /// Per-deviceId engine state. One entry per configured [AudioInputConfig].
  final Map<String, EngineSessionState> perEngineStates;

  @override
  bool get isRecording =>
      perEngineStates.values.any((s) => s.isActive);

  @override
  bool get isPaused => false;
}

/// Session is intentionally paused; engines have stopped listening.
class BroadcastPausedState extends BroadcastSessionState {
  /// Creates a [BroadcastPausedState].
  const BroadcastPausedState({
    required this.sessionId,
    required this.perEngineStates,
  });

  /// UUID v4 for this session.
  final String sessionId;

  /// Per-deviceId engine state at pause time.
  final Map<String, EngineSessionState> perEngineStates;

  @override
  bool get isRecording => false;

  @override
  bool get isPaused => true;
}

/// One engine crashed; attempting a transparent restart (REL-U6.1).
class BroadcastReconnectingState extends BroadcastSessionState {
  /// Creates a [BroadcastReconnectingState].
  const BroadcastReconnectingState({required this.sessionId});

  /// UUID v4 for this session.
  final String sessionId;
}

/// Session ended normally (via [BroadcastRecordingNotifier.stop]).
class BroadcastStoppedState extends BroadcastSessionState {
  /// Creates a [BroadcastStoppedState].
  const BroadcastStoppedState({required this.sessionId});

  /// UUID v4 for the ended session.
  final String sessionId;
}

// ---------------------------------------------------------------------------
// Per-engine state
// ---------------------------------------------------------------------------

/// State of a single engine within a broadcast session.
sealed class EngineSessionState {
  const EngineSessionState();

  /// Whether this engine is currently producing speech results.
  bool get isActive;
}

/// Engine initialised and listening.
class EngineActiveState extends EngineSessionState {
  /// Creates an [EngineActiveState].
  const EngineActiveState();

  @override
  bool get isActive => true;
}

/// Engine failed to initialise; other engines continue (REL-U6.1).
class EngineErrorState extends EngineSessionState {
  /// Creates an [EngineErrorState].
  const EngineErrorState(this.message);

  /// Human-readable error description.
  final String message;

  @override
  bool get isActive => false;
}
