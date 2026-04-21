import 'package:freezed_annotation/freezed_annotation.dart';

part 'transcript_session.freezed.dart';
part 'transcript_session.g.dart';

/// Persisted session metadata. Does not contain segment text.
///
/// [title] is auto-derived from the first final segment's text (first 50
/// characters), set by `TranscriptRepository` at flush time if still null.
@freezed
abstract class TranscriptSession with _$TranscriptSession {
  /// Creates a [TranscriptSession] instance.
  const factory TranscriptSession({
    /// Primary key (UUID).
    required String sessionId,

    /// Session start time (UTC).
    required DateTime date,

    /// Session duration in milliseconds.
    required int durationMs,

    /// Number of committed final segments.
    required int segmentCount,

    /// Auto-derived display title; null until the first final segment arrives.
    String? title,
  }) = _TranscriptSession;

  /// Deserializes from JSON.
  factory TranscriptSession.fromJson(Map<String, dynamic> json) =>
      _$TranscriptSessionFromJson(json);
}
