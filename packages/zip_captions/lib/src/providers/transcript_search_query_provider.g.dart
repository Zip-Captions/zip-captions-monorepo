// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_search_query_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$transcriptSearchQueryHash() =>
    r'ccca50e2f866820640018fd8fae367c539a3c552';

/// Holds the current search query typed into HistoryScreen's search bar.
///
/// Empty string means no active search (shows all sessions).
/// Updated with a 300ms debounce in HistoryScreen to avoid per-keystroke
/// FTS5 queries (NFR-DQ1=B).
///
/// Copied from [TranscriptSearchQuery].
@ProviderFor(TranscriptSearchQuery)
final transcriptSearchQueryProvider =
    NotifierProvider<TranscriptSearchQuery, String>.internal(
      TranscriptSearchQuery.new,
      name: r'transcriptSearchQueryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transcriptSearchQueryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TranscriptSearchQuery = Notifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
