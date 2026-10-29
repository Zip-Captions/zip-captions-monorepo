// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_save_outcome_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$transcriptSaveOutcomeHash() =>
    r'e8bb31ee24e58b7999ad2dc6db8d97f3b50f0a85';

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
///
/// Copied from [TranscriptSaveOutcome].
@ProviderFor(TranscriptSaveOutcome)
final transcriptSaveOutcomeProvider =
    NotifierProvider<TranscriptSaveOutcome, bool?>.internal(
      TranscriptSaveOutcome.new,
      name: r'transcriptSaveOutcomeProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transcriptSaveOutcomeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TranscriptSaveOutcome = Notifier<bool?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
