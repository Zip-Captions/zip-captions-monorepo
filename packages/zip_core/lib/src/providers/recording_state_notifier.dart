import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/models/recording_error.dart';
import 'package:zip_core/src/models/recording_state.dart';

part 'recording_state_notifier.g.dart';

/// Recording state machine (BR-01, BR-02, BR-03).
///
/// Phase 0: stub transitions only (no STT wiring).
///
/// Invalid transitions are silently ignored (no exception, no error).
/// This prevents UI race conditions (e.g., user double-taps a button).
///
/// **Security (SR-01)**: No method may log, emit, or surface any text
/// content from speech recognition results. State transitions may be
/// logged at debug level; segment text may not appear in any log output.
@Riverpod(keepAlive: true)
class RecordingStateNotifier extends _$RecordingStateNotifier {
  RecordingError? _lastError;

  /// The most recent error, if any.
  ///
  /// Cleared on successful [start] or [clearSession].
  RecordingError? get lastError => _lastError;

  @override
  RecordingState build() {
    return const RecordingState.idle();
  }

  /// Transitions idle -> recording.
  ///
  /// Phase 0: immediate stub transition.
  Future<void> start({String? localeId}) async {
    if (state is! IdleState) return;
    _lastError = null;
    state = const RecordingState.recording();
  }

  /// Transitions recording -> paused (BR-02).
  Future<void> pause() async {
    if (state is! RecordingActiveState) return;
    state = const RecordingState.paused();
  }

  /// Transitions paused -> recording (BR-02).
  Future<void> resume() async {
    if (state is! PausedState) return;
    state = const RecordingState.recording();
  }

  /// Transitions recording|paused -> stopped.
  Future<void> stop() async {
    if (state is! RecordingActiveState && state is! PausedState) {
      return;
    }
    state = const RecordingState.stopped();
  }

  /// Transitions stopped -> idle; clears accumulated data.
  void clearSession() {
    if (state is! StoppedState) return;
    _lastError = null;
    state = const RecordingState.idle();
  }
}
