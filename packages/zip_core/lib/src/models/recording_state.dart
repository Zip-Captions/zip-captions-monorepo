/// Represents the recording state machine.
///
/// Four states; no error state (errors are handled separately via
/// `RecordingError`). Phase 0: all variants are field-less. Phase 1 extends
/// `recording` and `stopped` with segment data and pause history.
sealed class RecordingState {
  const RecordingState();

  /// No active session. Initial state.
  const factory RecordingState.idle() = IdleState;

  /// Actively capturing speech. Phase 1 adds `currentSegment`.
  const factory RecordingState.recording() = RecordingActiveState;

  /// Session paused; user is intentionally omitting audio.
  const factory RecordingState.paused() = PausedState;

  /// Session ended. Phase 1 adds `segments` and `pauseEvents`.
  const factory RecordingState.stopped() = StoppedState;
}

/// {@macro recording_state.idle}
class IdleState extends RecordingState {
  /// Creates an idle recording state.
  const IdleState();
}

/// {@macro recording_state.recording}
class RecordingActiveState extends RecordingState {
  /// Creates a recording active state.
  const RecordingActiveState();
}

/// {@macro recording_state.paused}
class PausedState extends RecordingState {
  /// Creates a paused recording state.
  const PausedState();
}

/// {@macro recording_state.stopped}
class StoppedState extends RecordingState {
  /// Creates a stopped recording state.
  const StoppedState();
}
