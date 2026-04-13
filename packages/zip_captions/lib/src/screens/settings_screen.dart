import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_captions/src/providers/settings_notifier.dart';
import 'package:zip_core/zip_core.dart';

/// Settings screen — grouped configuration for all user-facing preferences.
///
/// All changes are persisted immediately; there is no Save button.
class SettingsScreen extends ConsumerWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displaySettings = ref.watch(displaySettingsProvider);
    final displayNotifier = ref.read(displaySettingsProvider.notifier);
    final transcriptSettings = ref.watch(transcriptSettingsNotifierProvider);
    final transcriptNotifier =
        ref.read(transcriptSettingsNotifierProvider.notifier);
    final wakeLockSettings = ref.watch(wakeLockSettingsNotifierProvider);
    final wakeLockNotifier =
        ref.read(wakeLockSettingsNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Display'),
          ListTile(
            title: const Text('Text size'),
            trailing: DropdownButton<CaptionTextSize>(
              value: displaySettings.captionTextSize,
              items: CaptionTextSize.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) unawaited(displayNotifier.setCaptionTextSize(v));
              },
            ),
          ),
          ListTile(
            title: const Text('Caption font'),
            trailing: DropdownButton<CaptionFont>(
              value: displaySettings.captionFont,
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
                if (v != null) unawaited(displayNotifier.setCaptionFont(v));
              },
            ),
          ),
          ListTile(
            title: const Text('Scroll direction'),
            trailing: SegmentedButton<ScrollDirection>(
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
              selected: {displaySettings.scrollDirection},
              onSelectionChanged: (v) =>
                  unawaited(displayNotifier.setScrollDirection(v.first)),
            ),
          ),
          ListTile(
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeModeSetting>(
              value: displaySettings.themeModeSetting,
              items: const [
                DropdownMenuItem(
                  value: ThemeModeSetting.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(
                  value: ThemeModeSetting.light,
                  child: Text('Light'),
                ),
                DropdownMenuItem(
                  value: ThemeModeSetting.dark,
                  child: Text('Dark'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  unawaited(displayNotifier.setThemeModeSetting(v));
                }
              },
            ),
          ),
          const _SectionHeader('Transcripts'),
          SwitchListTile(
            title: const Text('Save transcripts'),
            value: transcriptSettings.captureEnabled,
            onChanged: (v) =>
                unawaited(transcriptNotifier.setCaptureEnabled(value: v)),
          ),
          const _SectionHeader('Accessibility'),
          SwitchListTile(
            title: const Text('Keep screen on'),
            subtitle: const Text(
              'Prevents screen from dimming while captioning',
            ),
            value: wakeLockSettings.enabled,
            onChanged: (v) => unawaited(
              wakeLockNotifier.update(wakeLockSettings.copyWith(enabled: v)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
