import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transcript_save_outcome_provider.g.dart';

/// Whether the session that most recently stopped saved a transcript
/// (Amendment 03 section 7, Q-2).
///
/// `null` means no outcome has been recorded yet, or the writer target was
/// not active for that session. `true` means the session reached at least
/// one saved segment; `false` means it ended with zero segments, so no row
/// was ever created.
///
/// The transcript writer target provider's stop callback writes this just
/// before the stopped state is published, which lets `RecordingScreen` show
/// the one-time "no transcript was saved" notice when the state becomes
/// stopped, without any `RecordingState` or `RecordingStateNotifier` API
/// change.
///
/// Kept alive for the app lifetime; it carries a single bool, no transcript
/// content.
@Riverpod(keepAlive: true)
class TranscriptSaveOutcome extends _$TranscriptSaveOutcome {
  @override
  bool? build() => null;

  /// The most recently recorded outcome, or `null` when unknown.
  bool? get saved => state;

  /// Records the outcome of the session just ended: `true` when it saved a
  /// transcript row, `false` when it saved nothing, `null` for "unknown".
  set saved(bool? value) => state = value;

  /// Forgets the recorded outcome (back to "unknown").
  void clear() => state = null;
}
