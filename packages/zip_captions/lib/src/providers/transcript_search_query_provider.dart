import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transcript_search_query_provider.g.dart';

/// Holds the current search query typed into HistoryScreen's search bar.
///
/// Empty string means no active search (shows all sessions).
/// Updated with a 300ms debounce in HistoryScreen to avoid per-keystroke
/// FTS5 queries (NFR-DQ1=B).
@Riverpod(keepAlive: true)
class TranscriptSearchQuery extends _$TranscriptSearchQuery {
  @override
  String build() => '';

  /// The current search query string.
  String get query => state;

  /// Updates the active transcript search query.
  set query(String value) => state = value;

  /// Clears the active transcript search query.
  void clear() => state = '';
}
