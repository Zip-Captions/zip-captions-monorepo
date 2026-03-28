import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zip_core/src/models/enums.dart';

part 'recording_error.freezed.dart';

/// Represents an error that occurred during recording.
///
/// The [severity] determines the state machine impact: fatal errors halt
/// recording, transient errors are surfaced without changing state.
///
/// Security constraint (SR-02): [message] must contain only operational
/// information. It must never include text recognized by the STT engine.
@freezed

/// An error that occurred during a recording session.
abstract class RecordingError with _$RecordingError {
  /// Creates a [RecordingError] with the given message and severity.
  const factory RecordingError({
    /// Human-readable error description (never contains transcript text).
    required String message,

    /// Whether this error halts recording or is transient.
    required RecordingErrorSeverity severity,

    /// When the error occurred.
    required DateTime timestamp,
  }) = _RecordingError;
}
