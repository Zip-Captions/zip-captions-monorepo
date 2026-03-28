import 'package:freezed_annotation/freezed_annotation.dart';

part 'pause_event.freezed.dart';

/// Records a pause/resume cycle within a recording session.
///
/// Pauses represent intentional gaps where the user omitted audio from the
/// capture. These events are preserved in the session data and included in
/// transcript exports as visible markers (e.g., `[Paused 00:12 - 00:47]`).
///
/// Phase 0: model defined but not populated (stub state machine has no real
/// session timeline). Phase 1: populated by `RecordingStateNotifier` on each
/// pause/resume cycle.
@freezed

/// A single pause/resume interval within a recording session.
abstract class PauseEvent with _$PauseEvent {
  /// Creates a [PauseEvent] recording a single pause/resume cycle.
  const factory PauseEvent({
    /// When the user paused recording.
    required DateTime pausedAt,

    /// When the user resumed recording; null if session was stopped while
    /// paused.
    DateTime? resumedAt,
  }) = _PauseEvent;
}
