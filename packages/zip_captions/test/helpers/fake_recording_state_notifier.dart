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

  /// Ordered log of method names called on this notifier since creation.
  final calls = <String>[];

  @override
  RecordingState build() => _initial;

  @override
  Future<void> start({String? localeId}) async {
    calls.add('start');
    state = const RecordingState.recording(sessionId: 'test-session');
  }

  @override
  void clearSession() {
    calls.add('clearSession');
    state = const RecordingState.idle();
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    state = const RecordingState.stopped(sessionId: 'test-session');
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
