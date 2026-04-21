import 'package:freezed_annotation/freezed_annotation.dart';

part 'repository_event.freezed.dart';

/// Events emitted by `TranscriptRepository` for UI-layer notification.
///
/// Currently a single variant; structured as a union for future extensibility.
@freezed
abstract class RepositoryEvent with _$RepositoryEvent {
  /// Emitted when the database was found corrupt at startup and replaced with a
  /// fresh database. The corrupt file is preserved at [corruptFilePath] for
  /// potential recovery.
  const factory RepositoryEvent.corruption({
    required String corruptFilePath,
  }) = CorruptionEvent;
}
