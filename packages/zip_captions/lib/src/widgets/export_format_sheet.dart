import 'package:flutter/material.dart';
import 'package:zip_core/zip_core.dart';

/// Modal bottom sheet for selecting the export format.
///
/// Presents TXT, SRT, and VTT options. Tapping an option calls
/// [onFormatSelected] with the chosen format.
class ExportFormatSheet extends StatelessWidget {
  /// Creates an [ExportFormatSheet].
  const ExportFormatSheet({required this.onFormatSelected, super.key});

  /// Called with the selected [ExportFormat] when the user taps a format.
  final ValueChanged<ExportFormat> onFormatSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Export as',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.text_snippet_outlined),
            title: const Text('Plain Text (.txt)'),
            onTap: () => onFormatSelected(ExportFormat.txt),
          ),
          ListTile(
            leading: const Icon(Icons.subtitles_outlined),
            title: const Text('SubRip (.srt)'),
            onTap: () => onFormatSelected(ExportFormat.srt),
          ),
          ListTile(
            leading: const Icon(Icons.closed_caption_outlined),
            title: const Text('WebVTT (.vtt)'),
            onTap: () => onFormatSelected(ExportFormat.vtt),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
