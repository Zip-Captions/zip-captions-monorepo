import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_broadcast/src/models/audio_input_config.dart';
import 'package:zip_broadcast/src/models/audio_input_visual_style.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart';
import 'package:zip_broadcast/src/models/obs_connection_status.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/providers/browser_source_url_provider.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';
import 'package:zip_broadcast/src/widgets/coming_soon_card.dart';

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
    final browserSourceUrl = ref.watch(browserSourceUrlProvider);

    final isIdle = sessionState is BroadcastIdleState;
    final canStart = isIdle && configs.isNotEmpty;

    final activeTargetCount = [
      outputSettings.onScreenEnabled,
      outputSettings.obsEnabled,
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
                label: const Text('Start Broadcast'),
                onPressed: canStart ? () => context.go('/recording') : null,
              ),
              const SizedBox(height: 24),
              Text(
                'Output targets',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              // Output target grid (D3).
              _TargetCard(
                icon: Icons.monitor,
                label: 'On-Screen Captions',
                enabled: outputSettings.onScreenEnabled,
                onToggle: (v) => unawaited(
                  ref
                      .read(outputTargetSettingsNotifierProvider.notifier)
                      .update(outputSettings.copyWith(onScreenEnabled: v)),
                ),
              ),
              _TargetCard(
                icon: Icons.cast,
                label: 'OBS WebSocket',
                subtitle: _obsSubLabel(obsStatus),
                enabled: outputSettings.obsEnabled,
                onToggle: (v) => unawaited(
                  ref
                      .read(outputTargetSettingsNotifierProvider.notifier)
                      .update(outputSettings.copyWith(obsEnabled: v)),
                ),
              ),
              _TargetCard(
                icon: Icons.public,
                label: 'Browser Source',
                subtitle: outputSettings.browserSourceEnabled
                    ? browserSourceUrl
                    : null,
                enabled: outputSettings.browserSourceEnabled,
                onToggle: (v) => unawaited(
                  ref
                      .read(outputTargetSettingsNotifierProvider.notifier)
                      .update(
                        outputSettings.copyWith(browserSourceEnabled: v),
                      ),
                ),
              ),
              _TargetCard(
                icon: Icons.picture_in_picture_alt,
                label: 'Caption Overlay',
                enabled: outputSettings.overlayEnabled,
                onToggle: (v) => unawaited(
                  ref
                      .read(outputTargetSettingsNotifierProvider.notifier)
                      .update(outputSettings.copyWith(overlayEnabled: v)),
                ),
              ),
              _TargetCard(
                icon: Icons.description_outlined,
                label: 'Transcripts',
                enabled: true,
                onToggle: null, // Always active; configured in Settings.
              ),
              const ComingSoonCard(
                icon: Icons.people_outlined,
                label: 'Remote Viewers',
                subtitle: 'Phase 2',
              ),
              const SizedBox(height: 24),
              // Audio inputs summary (D4).
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Audio inputs',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/audio-inputs'),
                    child: const Text('Manage'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (configs.isEmpty)
                const Text('No audio inputs configured.')
              else
                for (final config in configs) _AudioInputRow(config: config),
            ],
          ),
        ),
      ),
    );
  }

  String _obsSubLabel(ObsConnectionStatus status) {
    return switch (status) {
      ObsConnectionStatus.connected => 'Connected',
      ObsConnectionStatus.connecting => 'Connecting…',
      ObsConnectionStatus.reconnecting => 'Reconnecting…',
      ObsConnectionStatus.error => 'Error',
      ObsConnectionStatus.disconnected => 'Disconnected',
    };
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Ready · $inputCount ${inputCount == 1 ? 'input' : 'inputs'} · '
          '$activeTargetCount ${activeTargetCount == 1 ? 'target' : 'targets'} active',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onToggle,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final ValueChanged<bool>? onToggle;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(label),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        value: enabled,
        onChanged: onToggle,
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
        config.speakerLabel.isNotEmpty ? config.speakerLabel : config.name,
      ),
      subtitle: config.speakerLabel.isNotEmpty ? Text(config.name) : null,
      dense: true,
    );
  }
}
