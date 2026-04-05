import 'package:freezed_annotation/freezed_annotation.dart';

part 'stt_result.freezed.dart';

/// Immutable value object representing a single speech recognition result.
///
/// Carries all metadata needed for the caption pipeline: text, finality,
/// confidence, timing, and source identification for multi-input.
///
/// **Security (SECURITY-03)**: [text] contains transcript content that
/// must never be logged or surfaced outside the caption pipeline.
@freezed
abstract class SttResult with _$SttResult {
  /// Creates an [SttResult] instance.
  const factory SttResult({
    /// Recognized speech text.
    required String text,

    /// Whether this is a final (committed) result or interim/partial.
    required bool isFinal,

    /// Recognition confidence (0.0-1.0).
    /// Engines that don't report confidence should use 1.0.
    required double confidence,

    /// When the utterance was recognized (UTC).
    required DateTime timestamp,

    /// Identifies the input source for multi-input disambiguation.
    /// Single-input apps use 'default'.
    required String sourceId,

    /// Optional speaker tag for future diarization.
    String? speakerTag,
  }) = _SttResult;
}
