import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
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
    final l10n = ZipBroadcastLocalizations.of(context)!;
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
              l10n.appearanceTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _SectionLabel(l10n.appearanceTextSize),
            Wrap(
              spacing: 4,
              children: CaptionTextSize.values.map((size) {
                return ChoiceChip(
                  label: Text(_textSizeLabel(l10n, size)),
                  selected: settings.captionTextSize == size,
                  onSelected: (_) =>
                      unawaited(notifier.setCaptionTextSize(size)),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            _SectionLabel(l10n.appearanceFont),
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
            _SectionLabel(l10n.appearanceScrollDirection),
            Wrap(
              spacing: 4,
              children: [
                ChoiceChip(
                  label: Text(l10n.appearanceNewAtBottom),
                  selected: settings.scrollDirection ==
                      ScrollDirection.bottomToTop,
                  onSelected: (_) => unawaited(
                    notifier.setScrollDirection(ScrollDirection.bottomToTop),
                  ),
                ),
                ChoiceChip(
                  label: Text(l10n.appearanceNewAtTop),
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

String _textSizeLabel(ZipBroadcastLocalizations l10n, CaptionTextSize size) {
  return switch (size) {
    CaptionTextSize.xs => l10n.appearanceTextSizeLabelXs,
    CaptionTextSize.sm => l10n.appearanceTextSizeLabelSm,
    CaptionTextSize.md => l10n.appearanceTextSizeLabelMd,
    CaptionTextSize.lg => l10n.appearanceTextSizeLabelLg,
    CaptionTextSize.xl => l10n.appearanceTextSizeLabelXl,
    CaptionTextSize.xxl => l10n.appearanceTextSizeLabelXxl,
  };
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
