import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';

/// All events that flow through the CaptionBus.
///
/// Sealed for exhaustive pattern matching — consumers use `switch (event)`
/// with [SttResultEvent] and [SessionStateEvent] cases.
sealed class CaptionEvent {
  const CaptionEvent();
}

/// A speech recognition result from an STT engine.
///
/// **Security (SECURITY-03)**: [result] contains transcript content
/// that must never be logged.
class SttResultEvent extends CaptionEvent {
  /// Creates an [SttResultEvent] wrapping the given [result].
  const SttResultEvent(this.result);

  /// The speech recognition result.
  final SttResult result;
}

/// A session lifecycle state change (start, pause, resume, stop).
class SessionStateEvent extends CaptionEvent {
  /// Creates a [SessionStateEvent] wrapping the given [state].
  const SessionStateEvent(this.state);

  /// The new recording state.
  final RecordingState state;
}
