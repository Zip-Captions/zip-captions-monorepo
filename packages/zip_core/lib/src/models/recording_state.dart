/// Represents the recording state machine.
///
/// Five states; no error state (errors are handled separately via
/// `RecordingError`). Phase 1 adds [ActiveSessionState] mixin with
/// `sessionId` and `currentSegment` to non-idle variants.
sealed class RecordingState {
  const RecordingState();

  /// No active session. Initial state.
  const factory RecordingState.idle() = IdleState;

  /// Actively capturing speech.
  const factory RecordingState.recording({
    required String sessionId,
    String currentSegment,
  }) = RecordingActiveState;

  /// Session paused; user is intentionally omitting audio.
  const factory RecordingState.paused({
    required String sessionId,
    String currentSegment,
  }) = PausedState;

  /// Engine crashed; attempting one automatic restart (REL-U2.1).
  const factory RecordingState.reconnecting({
    required String sessionId,
    String currentSegment,
  }) = ReconnectingState;

  /// Session ended.
  const factory RecordingState.stopped({
    required String sessionId,
    String currentSegment,
  }) = StoppedState;
}

/// Mixin providing session fields for active (non-idle) recording states.
///
/// Consumers can check `if (state is ActiveSessionState)` to access
/// [sessionId] and [currentSegment] without knowing the specific variant.
mixin ActiveSessionState {
  /// UUID v4 generated when transitioning from idle to recording.
  String get sessionId;

  /// Accumulated interim text for the current recognition segment.
  /// Cleared when a final result is committed.
  String get currentSegment;
}

/// {@macro recording_state.idle}
class IdleState extends RecordingState {
  /// Creates an idle recording state.
  const IdleState();
}

/// {@macro recording_state.recording}
class RecordingActiveState extends RecordingState with ActiveSessionState {
  /// Creates a recording active state.
  const RecordingActiveState({
    required this.sessionId,
    this.currentSegment = '',
  });

  @override
  final String sessionId;
  @override
  final String currentSegment;
}

/// {@macro recording_state.paused}
class PausedState extends RecordingState with ActiveSessionState {
  /// Creates a paused recording state.
  const PausedState({
    required this.sessionId,
    this.currentSegment = '',
  });

  @override
  final String sessionId;
  @override
  final String currentSegment;
}

/// {@macro recording_state.reconnecting}
class ReconnectingState extends RecordingState with ActiveSessionState {
  /// Creates a reconnecting state.
  const ReconnectingState({
    required this.sessionId,
    this.currentSegment = '',
  });

  @override
  final String sessionId;
  @override
  final String currentSegment;
}

/// {@macro recording_state.stopped}
class StoppedState extends RecordingState with ActiveSessionState {
  /// Creates a stopped recording state.
  const StoppedState({
    required this.sessionId,
    this.currentSegment = '',
  });

  @override
  final String sessionId;
  @override
  final String currentSegment;
}
