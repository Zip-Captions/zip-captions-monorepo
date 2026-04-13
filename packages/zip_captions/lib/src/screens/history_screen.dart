import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_captions/src/providers/transcript_search_query_provider.dart';
import 'package:zip_captions/src/widgets/transcript_session_tile.dart';
import 'package:zip_core/zip_core.dart';

/// History screen — searchable list of past transcript sessions.
///
/// Uses a 300ms debounce on the search bar to avoid per-keystroke FTS5
/// queries (NFR-DQ1=B). The [TextEditingController] drives the visible field
/// instantly; [transcriptSearchQueryProvider] is updated after the debounce.
class HistoryScreen extends ConsumerStatefulWidget {
  /// Creates a [HistoryScreen].
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(transcriptSearchQueryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(transcriptSearchQueryProvider);
    final sessionsAsync = ref.watch(transcriptSessionListProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search transcripts…',
              onChanged: _onSearchChanged,
            ),
          ),
        ),
      ),
      body: sessionsAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => const Center(child: Text('Error loading sessions')),
        data: (list) {
          if (list.isEmpty) {
            return _EmptyHistoryPlaceholder(
              hasQuery: query.trim().isNotEmpty,
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final session = list[i];
              return TranscriptSessionTile(
                session: session,
                onTap: () => context.go('/history/${session.sessionId}'),
                onDelete: () async {
                  final repo =
                      await ref.read(transcriptRepositoryProvider.future);
                  await repo.deleteSession(session.sessionId);
                  ref.invalidate(transcriptSessionListProvider);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyHistoryPlaceholder extends StatelessWidget {
  const _EmptyHistoryPlaceholder({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final message = hasQuery
        ? 'No results for this search.'
        : 'No transcripts yet. Start captioning to save your first session.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
