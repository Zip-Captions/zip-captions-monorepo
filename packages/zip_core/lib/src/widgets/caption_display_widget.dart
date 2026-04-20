import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zip_core/src/models/caption_display_entry.dart';
import 'package:zip_core/src/models/display_settings.dart';
import 'package:zip_core/src/models/enums.dart';

/// Renders the live caption buffer as a scrollable list.
///
/// Shared by `zip_captions` and `zip_broadcast` RecordingScreens.
/// Auto-scrolls to the newest entry after each buffer growth event using
/// [WidgetsBinding.addPostFrameCallback] (never during build).
///
/// Interim captions ([CaptionDisplayEntry.isFinal] == false) are rendered at
/// opacity 0.8 per BR-U5-13. Final captions render at full opacity.
class CaptionDisplayWidget extends ConsumerStatefulWidget {
  /// Creates a [CaptionDisplayWidget].
  const CaptionDisplayWidget({
    required this.entries,
    required this.settings,
    super.key,
  });

  /// The caption entries to display, oldest first.
  final List<CaptionDisplayEntry> entries;

  /// Display settings controlling font, size, and scroll direction.
  final DisplaySettings settings;

  @override
  ConsumerState<CaptionDisplayWidget> createState() =>
      _CaptionDisplayWidgetState();
}

class _CaptionDisplayWidgetState extends ConsumerState<CaptionDisplayWidget> {
  final _scrollController = ScrollController();
  int _lastEntryCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    unawaited(
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final settings = widget.settings;

    if (entries.length != _lastEntryCount) {
      _lastEntryCount = entries.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }

    final baseStyle = settings.captionTextSize.resolve(
      Theme.of(context).textTheme,
    );
    final textStyle = baseStyle != null
        ? GoogleFonts.getFont(
            settings.captionFont.fontFamily,
            textStyle: baseStyle,
            fontWeight: FontWeight.w500,
          )
        : null;

    return ListView.builder(
      controller: _scrollController,
      reverse: settings.scrollDirection == ScrollDirection.bottomToTop,
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[entries.length - 1 - i];
        if (entry.sourceId == '__pause__') {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'paused',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          );
        }
        return Opacity(
          opacity: entry.isFinal ? 1.0 : 0.8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(entry.text, style: textStyle),
          ),
        );
      },
    );
  }
}
