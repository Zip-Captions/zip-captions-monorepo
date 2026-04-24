import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zip_broadcast/src/providers/settings_notifier.dart';
import 'package:zip_core/zip_core.dart';

/// Floating overlay panel for adjusting caption display settings.
///
/// Uses chip-based selectors per Proto-07 (E8 — intentional divergence from
/// zip_captions which uses DropdownButton). Changes take immediate effect
/// via [DisplaySettingsNotifier]; there is no Apply button (BR-U5-11).
class AppearancePanel extends StatelessWidget {
  /// Creates an [AppearancePanel].
  const AppearancePanel({
    required this.settings,
    required this.notifier,
    super.key,
  });

  /// Current display settings to reflect in the controls.
  final DisplaySettings settings;

  /// Notifier used to write setting changes.
  final DisplaySettingsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _SectionLabel('Text size'),
            Wrap(
              spacing: 4,
              children: CaptionTextSize.values.map((size) {
                return ChoiceChip(
                  label: Text(size.name.toUpperCase()),
                  selected: settings.captionTextSize == size,
                  onSelected: (_) =>
                      unawaited(notifier.setCaptionTextSize(size)),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            _SectionLabel('Font'),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: CaptionFont.values.map((font) {
                return ChoiceChip(
                  label: Text(font.fontFamily),
                  selected: settings.captionFont == font,
                  onSelected: (_) => unawaited(notifier.setCaptionFont(font)),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            _SectionLabel('Scroll direction'),
            Wrap(
              spacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('↑ New at bottom'),
                  selected: settings.scrollDirection ==
                      ScrollDirection.bottomToTop,
                  onSelected: (_) => unawaited(
                    notifier.setScrollDirection(ScrollDirection.bottomToTop),
                  ),
                ),
                ChoiceChip(
                  label: const Text('↓ New at top'),
                  selected:
                      settings.scrollDirection == ScrollDirection.topToBottom,
                  onSelected: (_) => unawaited(
                    notifier.setScrollDirection(ScrollDirection.topToBottom),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
