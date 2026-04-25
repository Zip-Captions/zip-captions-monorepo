import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/models/audio_input_config.dart';
import 'package:zip_broadcast/src/models/audio_input_visual_style.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';

/// Screen for managing per-source [AudioInputConfig] entries (G1–G5).
///
/// Each card shows: colour dot, position, speaker label, remove button,
/// device dropdown, label text field, colour swatches. Device exclusivity
/// is enforced by removing already-assigned devices from other cards' lists.
class AudioSourceConfigScreen extends ConsumerWidget {
  /// Creates an [AudioSourceConfigScreen].
  const AudioSourceConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(audioInputConfigNotifierProvider);
    final notifier = ref.read(audioInputConfigNotifierProvider.notifier);
    final assignedDeviceIds =
        configs.map((c) => c.deviceId).toSet();

    final l10n = ZipBroadcastLocalizations.of(context)!;

    void addInput() => unawaited(
          notifier.addConfig(
            AudioInputConfig(
              deviceId: 'device_${DateTime.now().millisecondsSinceEpoch}',
              name: l10n.audioSourceNewInputName,
            ),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: configs.isEmpty
            ? Column(
                children: [
                  Expanded(
                    child: Center(child: Text(l10n.audioSourceNoInputs)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(l10n.audioSourceAddInput),
                      onPressed: addInput,
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: configs.length + 1, // +1 for Add button.
                itemBuilder: (context, index) {
                  if (index == configs.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(l10n.audioSourceAddInput),
                        onPressed: addInput,
                      ),
                    );
                  }
                  final config = configs[index];
                  return _InputCard(
                    key: ValueKey(config.deviceId),
                    config: config,
                    position: index + 1,
                    allAssignedDeviceIds: assignedDeviceIds,
                    notifier: notifier,
                  );
                },
              ),
      ),
    );
  }
}

class _InputCard extends ConsumerStatefulWidget {
  const _InputCard({
    required this.config,
    required this.position,
    required this.allAssignedDeviceIds,
    required this.notifier,
    super.key,
  });

  final AudioInputConfig config;
  final int position;
  final Set<String> allAssignedDeviceIds;
  final AudioInputConfigNotifier notifier;

  @override
  ConsumerState<_InputCard> createState() => _InputCardState();
}

class _InputCardState extends ConsumerState<_InputCard> {
  late final TextEditingController _labelCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.config.speakerLabel);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    final config = widget.config;
    final style = AudioInputVisualStyle.forIndex(config.colorIndex);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header.
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: style.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.audioSourceInputPosition(widget.position),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: l10n.audioSourceRemoveTooltip,
                  onPressed: () => unawaited(
                    widget.notifier.removeConfig(config.deviceId),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Speaker label field.
            TextField(
              controller: _labelCtrl,
              decoration: InputDecoration(
                labelText: l10n.audioSourceSpeakerLabel,
                hintText: l10n.audioSourceSpeakerLabelHint,
              ),
              onChanged: (v) => unawaited(
                widget.notifier.setSpeakerLabel(config.deviceId, v),
              ),
            ),
            const SizedBox(height: 12),
            // Colour swatches (G5).
            Text(
              l10n.audioSourceColour,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(AudioInputVisualStyle.count, (i) {
                final s = AudioInputVisualStyle.forIndex(i);
                final selected = config.colorIndex == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    label: l10n.audioSourceColourOption(i + 1),
                    selected: selected,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => unawaited(
                        widget.notifier.setColor(config.deviceId, i),
                      ),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: s.accent,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                  width: 2,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
