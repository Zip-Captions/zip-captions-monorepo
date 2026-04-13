import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zip_core/zip_core.dart';

/// Floating overlay panel for adjusting caption display settings.
///
/// Rendered in a [Stack] above [CaptionDisplayWidget] inside RecordingScreen.
/// Changes take immediate effect via [BaseSettingsNotifier]; there is no
/// Apply button (BR-U5-11).
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
  final BaseSettingsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 240,
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
            Text(
              'Text size',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            DropdownButton<CaptionTextSize>(
              isExpanded: true,
              value: settings.captionTextSize,
              items: CaptionTextSize.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) unawaited(notifier.setCaptionTextSize(v));
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Font',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            DropdownButton<CaptionFont>(
              isExpanded: true,
              value: settings.captionFont,
              items: CaptionFont.values
                  .map(
                    (f) => DropdownMenuItem(
                      value: f,
                      child: Text(
                        f.fontFamily,
                        style: TextStyle(fontFamily: f.fontFamily),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) unawaited(notifier.setCaptionFont(v));
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Scroll direction',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            SegmentedButton<ScrollDirection>(
              segments: const [
                ButtonSegment(
                  value: ScrollDirection.bottomToTop,
                  label: Text('↑ New'),
                ),
                ButtonSegment(
                  value: ScrollDirection.topToBottom,
                  label: Text('↓ New'),
                ),
              ],
              selected: {settings.scrollDirection},
              onSelectionChanged: (v) =>
                  unawaited(notifier.setScrollDirection(v.first)),
            ),
          ],
        ),
      ),
    );
  }
}
