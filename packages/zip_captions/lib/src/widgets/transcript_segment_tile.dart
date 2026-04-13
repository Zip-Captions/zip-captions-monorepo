import 'package:flutter/material.dart';
import 'package:zip_core/zip_core.dart';

/// List tile for a single [TranscriptSegment] in TranscriptViewerScreen.
///
/// Shows the segment timestamp offset and text. Segments are displayed in
/// ascending [TranscriptSegment.startTimeMs] order per BR-U5-20.
class TranscriptSegmentTile extends StatelessWidget {
  /// Creates a [TranscriptSegmentTile].
  const TranscriptSegmentTile({required this.segment, super.key});

  /// The segment to display.
  final TranscriptSegment segment;

  @override
  Widget build(BuildContext context) {
    final timestamp = _formatTimestamp(segment.startTimeMs);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              timestamp,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(segment.text),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int ms) {
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
