import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the current search query typed into HistoryScreen's search bar.
///
/// Empty string means no active search (shows all sessions).
/// Updated with a 300ms debounce in HistoryScreen to avoid per-keystroke
/// FTS5 queries (NFR-DQ1=B).
final transcriptSearchQueryProvider = StateProvider<String>((ref) => '');
