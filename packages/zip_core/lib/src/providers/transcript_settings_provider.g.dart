// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$transcriptSettingsNotifierHash() =>
    r'b6384a90eb4499d5012f27fb00b116e89e5dc58f';

/// Manages the transcript capture toggle.
///
/// Persists a boolean in SharedPreferences under `transcript.captureEnabled`.
/// Default: `true` (capture enabled).
///
/// Copied from [TranscriptSettingsNotifier].
@ProviderFor(TranscriptSettingsNotifier)
final transcriptSettingsNotifierProvider =
    NotifierProvider<TranscriptSettingsNotifier, bool>.internal(
      TranscriptSettingsNotifier.new,
      name: r'transcriptSettingsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transcriptSettingsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TranscriptSettingsNotifier = Notifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
