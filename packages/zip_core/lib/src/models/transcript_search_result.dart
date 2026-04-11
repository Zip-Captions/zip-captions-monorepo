import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zip_core/src/models/transcript_session.dart';

part 'transcript_search_result.freezed.dart';

/// FTS5 search result including session metadata and matched text snippets.
///
/// Returned by `TranscriptRepository.search`. Snippets use `[` and `]` as
/// match delimiters for UI highlight rendering.
@freezed
abstract class TranscriptSearchResult with _$TranscriptSearchResult {
  /// Creates a [TranscriptSearchResult] instance.
  const factory TranscriptSearchResult({
    /// The matching session's metadata.
    required TranscriptSession session,

    /// Matching excerpt strings from FTS5 `snippet()`, up to 3 per session.
    required List<String> snippets,

    /// BM25 relevance score (lower = more relevant in SQLite FTS5).
    required double relevanceScore,
  }) = _TranscriptSearchResult;
}
