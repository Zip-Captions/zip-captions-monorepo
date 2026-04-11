/// Supported export formats for transcript sessions.
enum ExportFormat {
  /// Plain text, one line per segment, no timestamps.
  txt,

  /// SubRip subtitle format with relative timestamps.
  srt,

  /// WebVTT subtitle format with relative timestamps.
  vtt,
}
