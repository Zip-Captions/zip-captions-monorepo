import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/models/transcript_save_result.dart';

part 'transcript_save_outcome_provider.g.dart';

/// How the session that most recently stopped turned out (Amendment 03
/// section 7, Q-2; Amendment 06, BR-U10-60).
///
/// `null` means no outcome has been recorded yet, or the writer target was
/// not active for that session. Otherwise it is one of the three
/// [TranscriptSaveResult] values: `saved`, `nothingRecognised` (zero segments,
/// so no row was ever created) or `saveFailed`.
///
/// The transcript writer target provider's stop callback writes this just
/// before the stopped state is published, which lets `RecordingScreen` show
/// the matching one-time notice when the state becomes stopped, without any
/// `RecordingState` or `RecordingStateNotifier` API change. The notifier also
/// sets `saveFailed` when its bounded Stop gives up before the finalise
/// completes (BR-U10-58).
///
/// Kept alive for the app lifetime; it carries a single enum value, no
/// transcript content.
@Riverpod(keepAlive: true)
class TranscriptSaveOutcome extends _$TranscriptSaveOutcome {
  @override
  TranscriptSaveResult? build() => null;

  /// The most recently recorded outcome, or `null` when unknown.
  TranscriptSaveResult? get outcome => state;

  /// Records the outcome of the session just ended, or `null` for "unknown".
  set outcome(TranscriptSaveResult? value) => state = value;

  /// Forgets the recorded outcome (back to "unknown").
  void clear() => state = null;
}
