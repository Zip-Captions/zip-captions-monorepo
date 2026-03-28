// Pure-function reference model for RecordingStateNotifier (LC-02).
//
// Used by PBT-06 stateful model-based tests to verify the real notifier
// matches expected behavior. Intentionally minimal — a single pure function
// implementing the BR-01 transition table.

/// Simplified state representation for the model.
enum ModelState { idle, recording, paused, stopped }

/// Commands that can be applied to the state machine.
enum Command { start, pause, resume, stop, clearSession }

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
