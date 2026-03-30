import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_error.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';

part 'recording_state_notifier.g.dart';

const _uuid = Uuid();

/// Recording state machine (BR-01, BR-02, BR-03).
///
/// Phase 1: generates session IDs, publishes [SessionStateEvent]s to the
/// [CaptionBus], and handles STT results via [handleSttResult].
///
/// Invalid transitions are silently ignored (no exception, no error).
/// This prevents UI race conditions (e.g., user double-taps a button).
///
/// **Security (SR-01)**: No method may log, emit, or surface any text
/// content from speech recognition results. State transitions may be
/// logged at debug level; segment text may not appear in any log output.
@Riverpod(keepAlive: true)
class RecordingStateNotifier extends _$RecordingStateNotifier {
  static final _log = Logger('zip_core.RecordingStateNotifier');

  late final CaptionBus _captionBus;
  RecordingError? _lastError;

  /// The most recent error, if any.
  ///
  /// Cleared on successful [start] or [clearSession].
  RecordingError? get lastError => _lastError;

  @override
  RecordingState build() {
    _captionBus = ref.read(captionBusProvider);
    return const RecordingState.idle();
  }

  /// Transitions idle -> recording.
  ///
  /// Generates a new sessionId and publishes a [SessionStateEvent].
  /// STT engine start is deferred to Unit 2.
  Future<void> start({String? localeId}) async {
    if (state is! IdleState) return;
    _lastError = null;
    final sessionId = _uuid.v4();
    _log.info('Session started: $sessionId');
    state = RecordingState.recording(sessionId: sessionId);
    _captionBus.publish(SessionStateEvent(state));
  }

  /// Transitions recording -> paused (BR-02).
  ///
  /// Preserves sessionId and currentSegment.
  Future<void> pause() async {
    final current = state;
    if (current is! RecordingActiveState) return;
    _log.info('Session paused');
    state = RecordingState.paused(
      sessionId: current.sessionId,
      currentSegment: current.currentSegment,
    );
    _captionBus.publish(SessionStateEvent(state));
  }

  /// Transitions paused -> recording (BR-02).
  ///
  /// Preserves sessionId; resets currentSegment.
  Future<void> resume() async {
    final current = state;
    if (current is! PausedState) return;
    _log.info('Session resumed');
    state = RecordingState.recording(
      sessionId: current.sessionId,
    );
    _captionBus.publish(SessionStateEvent(state));
  }

  /// Transitions recording|paused -> stopped.
  ///
  /// Preserves sessionId.
  Future<void> stop() async {
    final current = state;
    final String sessionId;
    if (current is RecordingActiveState) {
      sessionId = current.sessionId;
    } else if (current is PausedState) {
      sessionId = current.sessionId;
    } else {
      return;
    }
    _log.info('Session stopped');
    state = RecordingState.stopped(
      sessionId: sessionId,
    );
    _captionBus.publish(SessionStateEvent(state));
  }

  /// Transitions stopped -> idle; clears accumulated data.
  void clearSession() {
    if (state is! StoppedState) return;
    _lastError = null;
    _log.info('Session cleared');
    state = const RecordingState.idle();
  }

  /// Handle an STT result from the active engine.
  ///
  /// Updates [currentSegment] on the current state and publishes
  /// an [SttResultEvent] to the bus. Wired to [SttEngine.onResult]
  /// in Unit 2.
  ///
  /// **Security (SECURITY-03)**: Must never log result.text.
  void handleSttResult(SttResult result) {
    final current = state;
    if (current is! RecordingActiveState) return;

    if (result.isFinal) {
      state = RecordingActiveState(
        sessionId: current.sessionId,
        currentSegment: '',
      );
    } else {
      state = RecordingActiveState(
        sessionId: current.sessionId,
        currentSegment: result.text,
      );
    }

    _captionBus.publish(SttResultEvent(result));
  }
}
