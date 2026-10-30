// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_save_outcome_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$transcriptSaveOutcomeHash() =>
    r'4f96605669d62520a2e1dd3ddfa74e172888c3d1';

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
///
/// Copied from [TranscriptSaveOutcome].
@ProviderFor(TranscriptSaveOutcome)
final transcriptSaveOutcomeProvider =
    NotifierProvider<TranscriptSaveOutcome, TranscriptSaveResult?>.internal(
      TranscriptSaveOutcome.new,
      name: r'transcriptSaveOutcomeProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transcriptSaveOutcomeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TranscriptSaveOutcome = Notifier<TranscriptSaveResult?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
