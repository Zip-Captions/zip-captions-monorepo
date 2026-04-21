import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_captions/src/providers/device_auth_provider.dart';
import 'package:zip_captions/src/services/transcript_export.dart';
import 'package:zip_captions/src/widgets/export_format_sheet.dart';
import 'package:zip_captions/src/widgets/transcript_segment_tile.dart';
import 'package:zip_core/zip_core.dart';

/// Transcript viewer screen — shows all segments for a session and allows
/// export to TXT, SRT, or VTT.
///
/// Handles concurrent deletion gracefully by showing a "Session not found"
/// error state (BR-U5-19).
class TranscriptViewerScreen extends ConsumerWidget {
  /// Creates a [TranscriptViewerScreen].
  const TranscriptViewerScreen({required this.sessionId, super.key});

  /// The session to display.
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(transcriptSessionProvider(sessionId));
    final segmentsAsync = ref.watch(transcriptSegmentsProvider(sessionId));

    final isDesktop = MediaQuery.of(context).size.width > 768;
    final canExport =
        !kIsWeb && sessionAsync.valueOrNull != null;

    return Scaffold(
      appBar: isDesktop
          ? AppBar(
              title: sessionAsync.maybeWhen(
                data: (s) {
                  if (s == null) return const Text('Transcript');
                  final d = s.date;
                  final mm = d.month.toString().padLeft(2, '0');
                  final dd = d.day.toString().padLeft(2, '0');
                  final dateStr = '${d.year}-$mm-$dd';
                  return Text(
                    s.title?.isNotEmpty ?? false ? s.title! : dateStr,
                  );
                },
                orElse: () => const Text('Transcript'),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Export',
                  onPressed:
                      canExport ? () => _showExportSheet(context, ref) : null,
                ),
              ],
            )
          : null,
      floatingActionButton: !isDesktop
          ? FloatingActionButton(
              tooltip: 'Export',
              onPressed:
                  canExport ? () => _showExportSheet(context, ref) : null,
              child: const Icon(Icons.ios_share),
            )
          : null,
      body: sessionAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) =>
            const Center(child: Text('Could not load session')),
        data: (session) {
          if (session == null) {
            return _SessionNotFound(onBack: () => Navigator.of(context).pop());
          }
          return segmentsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) =>
                const Center(child: Text('Could not load transcript')),
            data: (segments) => ListView.builder(
              itemCount: segments.length,
              itemBuilder: (_, i) =>
                  TranscriptSegmentTile(segment: segments[i]),
            ),
          );
        },
      ),
    );
  }

  void _showExportSheet(BuildContext context, WidgetRef ref) {
    // Capture share origin before the sheet appears; iOS rejects a zero rect.
    Rect? shareOrigin;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final size = MediaQuery.sizeOf(context);
      shareOrigin = Rect.fromLTWH(size.width - 72, size.height - 100, 56, 56);
    }
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => ExportFormatSheet(
          onFormatSelected: (format) async {
            Navigator.of(context).pop();
            await _runExport(context, ref, format, shareOrigin: shareOrigin);
          },
        ),
      ),
    );
  }

  Future<void> _runExport(
    BuildContext context,
    WidgetRef ref,
    ExportFormat format, {
    Rect? shareOrigin,
  }) async {
    final secured =
        await ref.read(deviceSecuredProvider.future).catchError((_) => false);
    if (!context.mounted) return;
    if (!secured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Export requires a screen lock to protect transcript data.',
          ),
        ),
      );
      return;
    }
    try {
      final repo = await ref.read(transcriptRepositoryProvider.future);
      final content = await repo.exportSession(sessionId, format);
      final isMobile = defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android;
      await exportTranscript(
        content: content,
        sessionId: sessionId,
        format: format,
        isMobile: isMobile,
        shareOrigin: shareOrigin,
      );
    } on Object catch (e, st) {
      debugPrint('Export error: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    }
  }
}

class _SessionNotFound extends StatelessWidget {
  const _SessionNotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          const Text('Session not found'),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onBack,
            child: const Text('Back to History'),
          ),
        ],
      ),
    );
  }
}
