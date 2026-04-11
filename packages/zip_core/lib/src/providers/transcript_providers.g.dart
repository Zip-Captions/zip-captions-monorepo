// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$transcriptRepositoryHash() =>
    r'19c2053913c1d645c9bfa19c4bf2451ce6538e6c';

/// Provides a file-backed [TranscriptRepository] for the session lifetime.
///
/// Opens `transcripts.db` in the application documents directory.
/// Corruption is handled by [TranscriptDatabase.open]; the repository
/// emits a `RepositoryEvent.corruption` event when recovery occurs.
///
/// Copied from [transcriptRepository].
@ProviderFor(transcriptRepository)
final transcriptRepositoryProvider =
    FutureProvider<TranscriptRepository>.internal(
      transcriptRepository,
      name: r'transcriptRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transcriptRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TranscriptRepositoryRef = FutureProviderRef<TranscriptRepository>;
String _$transcriptSettingsNotifierHash() =>
    r'd900138569b30a1822856961657bb9f30e3bccd8';

/// Manages [TranscriptSettings] persistence via `SharedPreferences`.
///
/// Copied from [TranscriptSettingsNotifier].
@ProviderFor(TranscriptSettingsNotifier)
final transcriptSettingsNotifierProvider =
    NotifierProvider<TranscriptSettingsNotifier, TranscriptSettings>.internal(
      TranscriptSettingsNotifier.new,
      name: r'transcriptSettingsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transcriptSettingsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TranscriptSettingsNotifier = Notifier<TranscriptSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
