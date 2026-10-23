/// What the external display window shows.
///
/// Selected by the recognition state in the main engine (D-5). Recognition
/// events change only this value; they never open or close the window
/// (BR-U8-17).
enum OverlayActivity {
  /// Recognition idle or stopped: theme background, no text.
  standby,

  /// Recognition active: final entries plus the interim line.
  live,

  /// Recognition paused: the last captions stay visible.
  paused,
}
