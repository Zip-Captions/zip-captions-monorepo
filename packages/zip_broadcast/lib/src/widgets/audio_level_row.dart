import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_broadcast/src/models/audio_input_config.dart';
import 'package:zip_broadcast/src/models/audio_input_visual_style.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
import 'package:zip_broadcast/src/providers/audio_level_provider.dart';

/// Horizontal row of per-source audio level bars.
///
/// One track per [AudioInputConfig], coloured by [AudioInputVisualStyle].
/// Hidden when [visible] is false (E6 — hidden when paused).
/// Excluded from semantics: decorative progress indicators (ACC-U6.2).
class AudioLevelRow extends ConsumerWidget {
  /// Creates an [AudioLevelRow].
  const AudioLevelRow({this.visible = true, super.key});

  /// Whether the row is shown. Pass `false` when session is paused.
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible) return const SizedBox.shrink();

    final configs = ref.watch(audioInputConfigNotifierProvider);
    final levels = ref.watch(audioLevelProvider);

    final children = <Widget>[];
    for (var i = 0; i < configs.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 8));
      children.add(
        Expanded(
          child: _LevelTrack(
            config: configs[i],
            level: levels[configs[i].deviceId] ?? 0.0,
          ),
        ),
      );
    }

    return ExcludeSemantics(
      child: SizedBox(
        height: 32,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: children),
        ),
      ),
    );
  }
}

class _LevelTrack extends StatelessWidget {
  const _LevelTrack({required this.config, required this.level});

  final AudioInputConfig config;
  final double level;

  @override
  Widget build(BuildContext context) {
    final style = AudioInputVisualStyle.forIndex(config.colorIndex);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: level.clamp(0.0, 1.0),
        backgroundColor: style.accent.withAlpha(51),
        valueColor: AlwaysStoppedAnimation<Color>(style.accent),
        minHeight: 16,
      ),
    );
  }
}
