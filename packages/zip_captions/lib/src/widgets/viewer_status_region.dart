import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_captions/src/providers/viewer_announcer_provider.dart';
import 'package:zip_core/zip_core.dart';

/// The single live region that describes viewer status (Rule 13).
///
/// Renders exactly one status line for the current state and announces a
/// change once per transition — never once per rebuild, and never from the
/// notifier. The region is exposed as a live region and as a heading so a
/// screen reader finds it without moving focus.
class ViewerStatusRegion extends ConsumerStatefulWidget {
  /// Creates the status region.
  const ViewerStatusRegion({
    required this.state,
    required this.text,
    this.body,
    super.key,
  });

  /// The state the region describes.
  final ViewerSessionState state;

  /// The one-line status title.
  final String text;

  /// Optional supporting copy shown under the title.
  final String? body;

  @override
  ConsumerState<ViewerStatusRegion> createState() => _ViewerStatusRegionState();
}

class _ViewerStatusRegionState extends ConsumerState<ViewerStatusRegion> {
  String? _announced;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _announceIfChanged();
    });
  }

  @override
  void didUpdateWidget(ViewerStatusRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _announceIfChanged();
      });
    }
  }

  void _announceIfChanged() {
    final text = widget.text;
    if (text == _announced) return;
    _announced = text;
    // When the platform opts out of announcements, the live region below
    // still carries the status for a reader consuming it in document order;
    // the explicit announcement would duplicate it (NFR-5.2).
    if (!MediaQuery.supportsAnnounceOf(context)) return;
    ref.read(viewerAnnouncerProvider)(View.of(context), text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = widget.body;

    return Semantics(
      liveRegion: true,
      container: true,
      label: body == null ? widget.text : '${widget.text}. $body',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.text, style: theme.textTheme.titleMedium),
            if (body != null) ...[
              const SizedBox(height: 4),
              Text(body, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
