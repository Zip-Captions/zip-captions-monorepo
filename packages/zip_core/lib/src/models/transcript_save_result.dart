/// How the transcript of a session that just ended turned out (BR-U10-60).
///
/// Replaces the earlier `bool` so a session that recognised speech but could
/// not save it is told apart from one that recognised nothing: the first needs
/// a "could not be saved" notice, the second the "nothing was recognised" one.
/// Carries no transcript content.
enum TranscriptSaveResult {
  /// The session row was created and at least one segment save or merge
  /// succeeded.
  saved,

  /// No segment was ever asked for (Q-2), so no row exists and nothing was
  /// lost.
  nothingRecognised,

  /// Speech was recognised but the save did not succeed: the row could not be
  /// created, every segment save and merge failed, or the stop (BR-U10-58) gave
  /// up before the finalise completed.
  saveFailed,
}
