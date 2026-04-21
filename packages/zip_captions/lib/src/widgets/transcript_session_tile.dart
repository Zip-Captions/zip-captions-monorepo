import 'package:flutter/material.dart';
import 'package:zip_core/zip_core.dart';

/// List tile for a single [TranscriptSession] in HistoryScreen.
///
/// Shows session title (or formatted date as fallback), duration, and segment
/// count. Provides swipe-to-delete and a tap handler.
///
/// Set [isLive] when the session is currently active — the tile shows a
/// "LIVE" chip instead of duration/segment stats.
class TranscriptSessionTile extends StatelessWidget {
  /// Creates a [TranscriptSessionTile].
  const TranscriptSessionTile({
    required this.session,
    required this.onTap,
    required this.onDelete,
    this.isLive = false,
    super.key,
  });

  /// The session to display.
  final TranscriptSession session;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  /// Called when deletion is confirmed; must throw on failure.
  final Future<void> Function() onDelete;

  /// Whether this session is currently being captioned.
  final bool isLive;

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
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
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
        );
        if (confirmed != true) return false;
        try {
          await onDelete();
          return true;
        } on Object {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not delete session.')),
            );
          }
          return false;
        }
      },
      child: ListTile(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: isLive
            ? null
            : Text(
                '$dateLabel · $durationLabel'
                ' · ${session.segmentCount} segments',
              ),
        trailing: isLive
            ? Chip(
                label: const Text('LIVE'),
                backgroundColor:
                    Theme.of(context).colorScheme.error.withAlpha(30),
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )
            : const Icon(Icons.chevron_right),
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
