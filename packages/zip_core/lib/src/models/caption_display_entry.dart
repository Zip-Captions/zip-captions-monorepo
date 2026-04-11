import 'package:freezed_annotation/freezed_annotation.dart';

part 'caption_display_entry.freezed.dart';

/// A single rendered caption entry held in the `OnScreenCaptionTarget` buffer.
///
/// Carries [sourceId] for widget-layer style lookup — styling is not the
/// target's responsibility.
///
/// **Security (SEC-U3.1)**: [text] contains transcript content that must never
/// be logged or surfaced outside the caption pipeline.
@freezed
abstract class CaptionDisplayEntry with _$CaptionDisplayEntry {
  /// Creates a [CaptionDisplayEntry] instance.
  const factory CaptionDisplayEntry({
    /// Unique entry identifier (UUID).
    required String entryId,

    /// Session this entry belongs to.
    required String sessionId,

    /// Caption text. May be empty for interim results.
    required String text,

    /// Whether this is a committed utterance (`true`) or in-progress
    /// interim (`false`).
    required bool isFinal,

    /// Input source identifier; the widget layer maps this to
    /// [AudioInputVisualStyle] via [AudioInputSettingsProvider].
    required String sourceId,

    /// When the result was recognized (UTC).
    required DateTime timestamp,
  }) = _CaptionDisplayEntry;
}
