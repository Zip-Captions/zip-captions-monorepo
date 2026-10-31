import 'dart:async';

import 'package:zip_core/zip_core.dart';

/// Test double for `RecordingStateNotifier`.
///
/// Starts in the given initial state and records all method calls. Does not
/// touch
/// engines, permissions, wake locks, or the caption bus — safe to use in any
/// widget test without additional provider setup for those services.
class FakeRecordingStateNotifier extends RecordingStateNotifier {
  /// Creates a fake notifier that opens in the given initial state.
  FakeRecordingStateNotifier(this._initial);

  final RecordingState _initial;

  /// When set, `stop()` publishes [StoppedState] and then waits for this,
  /// so a test can release the stop only after the writer recorded its
  /// outcome (the order zip_core's stop callback has). Left unset, `stop()`
  /// publishes and returns in one turn, like a fake with no gate at all.
  Completer<void>? stopGate;

  /// When set, `stop()` waits for this before publishing [StoppedState], the
  /// order the real notifier has: finalise (which records the outcome), then
  /// publish. Used to drive a writer's record from the stop callback's place.
  Completer<void>? beforeStopGate;

  /// Ordered log of method names called on this notifier since creation.
  final calls = <String>[];

  /// How many times `start()` was called (Q-1: one per screen entry).
  int get startCalls => calls.where((c) => c == 'start').length;

  @override
  RecordingState build() => _initial;

  /// When set, `start()` leaves the state in [IdleState] and exposes this as
  /// `lastError`, the way a refused start does.
  RecordingError? startError;

  /// When set, `start()` waits for this before completing, so a test can
  /// observe the screen while `start()` is still in flight.
  Future<void>? startGate;

  @override
  RecordingError? get lastError => _lastErrorOverride ?? super.lastError;

  RecordingError? _lastErrorOverride;

  @override
  Future<void> start({String? localeId}) async {
    calls.add('start');

    final gate = startGate;
    if (gate != null) await gate;
    final error = startError;
    if (error != null) {
      _lastErrorOverride = error;
      state = const RecordingState.idle();
      return;
    }
    state = const RecordingState.recording(sessionId: 'test-session');
  }

  /// Moves to [StoppedState] carrying [error] as `lastError`, which is what
  /// the notifier does when a session stops because of an engine error.
  void stopWithError(RecordingError error) {
    _lastErrorOverride = error;
    state = RecordingState.stopped(sessionId: nextSessionIdOnStop);
  }

  @override
  void clearSession() {
    calls.add('clearSession');
    state = const RecordingState.idle();
  }

  /// The session id the next stop or stop-with-error reports.
  ///
  /// Unique per stop, so a test can tell one session's StoppedState from the
  /// next one's, the way the real notifier's uuid does.
  String nextSessionIdOnStop = 'test-session';

  @override
  Future<void> stop() async {
    calls.add('stop');
    final before = beforeStopGate;
    if (before != null) await before.future;
    state = RecordingState.stopped(sessionId: nextSessionIdOnStop);
    final gate = stopGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    final s = state;
    if (s is RecordingActiveState) {
      state = RecordingState.paused(sessionId: s.sessionId);
    }
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    final s = state;
    if (s is PausedState) {
      state = RecordingState.recording(sessionId: s.sessionId);
    }
  }
}
