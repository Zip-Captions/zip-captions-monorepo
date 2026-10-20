/// Where the caption block sits inside the external display surface.
///
/// Persisted as its name (`'top'`/`'bottom'`) under the
/// `output.externalDisplayCaptionPosition` key and carried to the window in
/// the launch config (B-8, BR-U8-26).
enum CaptionPosition {
  /// Captions at the top of the surface.
  top,

  /// Captions at the bottom of the surface.
  bottom,
}
