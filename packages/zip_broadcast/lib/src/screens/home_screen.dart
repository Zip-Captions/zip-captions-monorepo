import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/models/audio_input_config.dart';
import 'package:zip_broadcast/src/models/audio_input_visual_style.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart';
import 'package:zip_broadcast/src/models/obs_connection_status.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';
import 'package:zip_broadcast/src/widgets/output_targets_panel.dart';

/// Home screen — start button, status summary, output target grid, and audio
/// inputs list (D1–D4).
class HomeScreen extends ConsumerWidget {
  /// Creates a [HomeScreen].
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(broadcastRecordingNotifierProvider);
    final configs = ref.watch(audioInputConfigNotifierProvider);
    final outputSettings = ref.watch(outputTargetSettingsNotifierProvider);
    final obsStatus = ref.watch(obsConnectionNotifierProvider);

    final l10n = ZipBroadcastLocalizations.of(context)!;
    final isIdle = sessionState is BroadcastIdleState;
    final canStart = isIdle && configs.isNotEmpty;

    final activeTargetCount = [
      outputSettings.onScreenEnabled,
      outputSettings.obsEnabled && obsStatus == ObsConnectionStatus.connected,
      outputSettings.browserSourceEnabled,
      outputSettings.overlayEnabled,
    ].where((e) => e).length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status pill (D2).
              _StatusSummary(
                inputCount: configs.length,
                activeTargetCount: activeTargetCount,
              ),
              const SizedBox(height: 24),
              // Start button (D1).
              FilledButton.icon(
                icon: const Icon(Icons.radio),
                label: Text(l10n.homeStartBroadcast),
                onPressed: canStart ? () => context.go('/recording') : null,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.homeOutputTargets,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              // Output target grid (D3).
              const OutputTargetsPanel(),
              const SizedBox(height: 24),
              // Audio inputs summary (D4).
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.homeAudioInputs,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/audio-inputs'),
                    child: Text(l10n.homeManage),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (configs.isEmpty)
                Text(l10n.homeNoAudioInputs)
              else
                for (final config in configs) _AudioInputRow(config: config),
            ],
          ),
        ),
      ),
    );
  }

}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.inputCount,
    required this.activeTargetCount,
  });

  final int inputCount;
  final int activeTargetCount;

  @override
  Widget build(BuildContext context) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          l10n.homeStatusSummary(inputCount, activeTargetCount),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _AudioInputRow extends StatelessWidget {
  const _AudioInputRow({required this.config});

  final AudioInputConfig config;

  @override
  Widget build(BuildContext context) {
    final style = AudioInputVisualStyle.forIndex(config.colorIndex);
    return ListTile(
      leading: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: style.accent,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        config.label.isNotEmpty ? config.label : config.name,
      ),
      subtitle: config.label.isNotEmpty ? Text(config.name) : null,
      dense: true,
    );
  }
}
