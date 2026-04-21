import 'package:freezed_annotation/freezed_annotation.dart';

part 'transcript_segment.freezed.dart';
part 'transcript_segment.g.dart';

/// A single persisted speech segment from one final result (or merged final
/// results — see BR-U3-06).
///
/// Timestamps are offsets from session start, not wall-clock timestamps
/// (Q5=A). Export functions use these to produce `00:00:00,000`-style
/// SRT/VTT timestamps.
///
/// **Security (SEC-U3.1)**: [text] contains transcript content that must
/// never be logged.
@freezed
abstract class TranscriptSegment with _$TranscriptSegment {
  /// Creates a [TranscriptSegment] instance.
  const factory TranscriptSegment({
    /// Primary key (UUID).
    required String segmentId,

    /// Foreign key → [TranscriptSession.sessionId].
    required String sessionId,

    /// Committed speech text (never interim).
    required String text,

    /// Input source identifier.
    required String sourceId,

    /// Segment start offset from session start in milliseconds.
    required int startTimeMs,

    /// Segment end offset from session start in milliseconds.
    required int endTimeMs,
  }) = _TranscriptSegment;

  /// Deserializes from JSON.
  factory TranscriptSegment.fromJson(Map<String, dynamic> json) =>
      _$TranscriptSegmentFromJson(json);
}
