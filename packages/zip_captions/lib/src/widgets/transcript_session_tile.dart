import 'package:flutter/material.dart';
import 'package:zip_core/zip_core.dart';

/// List tile for a single [TranscriptSession] in HistoryScreen.
///
/// Shows session title (or formatted date as fallback), duration, and segment
/// count. Provides swipe-to-delete and a tap handler.
class TranscriptSessionTile extends StatelessWidget {
  /// Creates a [TranscriptSessionTile].
  const TranscriptSessionTile({
    required this.session,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  /// The session to display.
  final TranscriptSession session;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  /// Called when the delete action is confirmed.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = session.date;
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final dateLabel = '${date.year}-$mm-$dd';
    final durationLabel = _formatDuration(session.durationMs);
    final title =
        session.title?.isNotEmpty ?? false ? session.title! : dateLabel;

    return Dismissible(
      key: ValueKey(session.sessionId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Theme.of(context).colorScheme.error,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete session?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '$dateLabel · $durationLabel · ${session.segmentCount} segments',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _formatDuration(int ms) {
    final total = Duration(milliseconds: ms);
    final minutes = total.inMinutes;
    final seconds = total.inSeconds.remainder(60);
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}
