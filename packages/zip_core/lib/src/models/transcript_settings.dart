import 'package:freezed_annotation/freezed_annotation.dart';

part 'transcript_settings.freezed.dart';

/// User preference for transcript capture.
///
/// Persisted via `SharedPreferences`.
@freezed
abstract class TranscriptSettings with _$TranscriptSettings {
  /// Creates a [TranscriptSettings] instance.
  const factory TranscriptSettings({
    /// Whether transcript capture is active.
    @Default(true) bool captureEnabled,
  }) = _TranscriptSettings;
}
