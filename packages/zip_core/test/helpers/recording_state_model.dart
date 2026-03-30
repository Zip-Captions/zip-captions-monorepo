// Pure-function reference model for RecordingStateNotifier (LC-02).
//
// Used by PBT-06 stateful model-based tests to verify the real notifier
// matches expected behavior. Intentionally minimal — a single pure function
// implementing the BR-01 transition table.
//
// Phase 1: tracks sessionId consistency across transitions.

/// Simplified state representation for the model.
enum ModelState { idle, recording, paused, stopped }

/// Commands that can be applied to the state machine.
enum Command { start, pause, resume, stop, clearSession }

/// Result of applying a command: the new state and the sessionId.
class ModelResult {
  const ModelResult(this.state, this.sessionId);
  final ModelState state;
  final String? sessionId;
}

/// Applies [cmd] to [current] state per BR-01 transition rules.
///
/// Invalid transitions return [current] unchanged (silent no-op).
ModelState applyCommand(ModelState current, Command cmd) {
  return switch ((current, cmd)) {
    (ModelState.idle, Command.start) => ModelState.recording,
    (ModelState.recording, Command.pause) => ModelState.paused,
    (ModelState.paused, Command.resume) => ModelState.recording,
    (ModelState.recording, Command.stop) => ModelState.stopped,
    (ModelState.paused, Command.stop) => ModelState.stopped,
    (ModelState.stopped, Command.clearSession) => ModelState.idle,
    _ => current,
  };
}

/// Applies [cmd] to [current] state with sessionId tracking.
///
/// When transitioning from idle to recording, a new sessionId is assigned.
/// The sessionId persists through pause/resume/stop within a session.
/// clearSession resets sessionId to null.
ModelResult applyCommandWithSession(
  ModelState current,
  String? currentSessionId,
  Command cmd,
  String Function() generateSessionId,
) {
  final newState = applyCommand(current, cmd);

  // Generate new sessionId on idle -> recording
  if (current == ModelState.idle && newState == ModelState.recording) {
    return ModelResult(newState, generateSessionId());
  }

  // Clear sessionId on stopped -> idle
  if (current == ModelState.stopped && newState == ModelState.idle) {
    return ModelResult(newState, null);
  }

  // Preserve sessionId for all other transitions
  return ModelResult(newState, currentSessionId);
}
