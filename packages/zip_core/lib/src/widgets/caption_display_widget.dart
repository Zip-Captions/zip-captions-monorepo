import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final target =
        widget.settings.scrollDirection == ScrollDirection.bottomToTop
            ? _scrollController.position.maxScrollExtent
            : 0.0;
    unawaited(
      _scrollController.animateTo(
        target,
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
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToLatest());
    }

    final textStyle = settings.captionTextSize
        .resolve(Theme.of(context).textTheme)
        ?.copyWith(fontFamily: settings.captionFont.fontFamily);

    return ListView.builder(
      controller: _scrollController,
      reverse: settings.scrollDirection == ScrollDirection.bottomToTop,
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final entry = entries[i];
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
