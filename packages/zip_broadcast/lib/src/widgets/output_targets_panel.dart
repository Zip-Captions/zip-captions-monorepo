import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/models/obs_connection_status.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/browser_source_url_provider.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';
import 'package:zip_broadcast/src/widgets/coming_soon_card.dart';

/// Shared output-target toggle panel used on both the Home screen and the
/// Settings › Output Targets detail.
///
/// Renders a [Column] of [Card]-wrapped toggles. The OBS card enforces the
/// connection-verification gate and attempts a live test on enable.
class OutputTargetsPanel extends ConsumerStatefulWidget {
  /// Creates an [OutputTargetsPanel].
  const OutputTargetsPanel({super.key});

  @override
  ConsumerState<OutputTargetsPanel> createState() => _OutputTargetsPanelState();
}

class _OutputTargetsPanelState extends ConsumerState<OutputTargetsPanel> {
  bool _obsTesting = false;
  String? _obsError;

  @override
  Widget build(BuildContext context) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    final outputSettings = ref.watch(outputTargetSettingsNotifierProvider);
    final obsSettings = ref.watch(obsSettingsNotifierProvider);
    final obsStatus = ref.watch(obsConnectionNotifierProvider);
    final browserSourceUrl = ref.watch(browserSourceUrlProvider);

    final obsVerified = obsSettings.connectionVerified;
    final obsSubtitle = _obsTesting
        ? l10n.obsStatusConnecting
        : !obsVerified
            ? l10n.obsNotConfigured
            : _obsStatusLabel(l10n, obsStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TargetCard(
          icon: Icons.monitor,
          label: l10n.settingsOnScreenCaptions,
          enabled: outputSettings.onScreenEnabled,
          onToggle: (v) => unawaited(
            ref
                .read(outputTargetSettingsNotifierProvider.notifier)
                .update(outputSettings.copyWith(onScreenEnabled: v)),
          ),
        ),
        _TargetCard(
          icon: Icons.cast,
          label: l10n.settingsObs,
          subtitle: obsSubtitle,
          enabled: outputSettings.obsEnabled,
          onToggle: obsVerified && !_obsTesting ? _onObsToggle : null,
        ),
        if (_obsError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              _obsError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        _TargetCard(
          icon: Icons.public,
          label: l10n.settingsBrowserSource,
          subtitle: outputSettings.browserSourceEnabled ? browserSourceUrl : null,
          enabled: outputSettings.browserSourceEnabled,
          onToggle: (v) => unawaited(
            ref
                .read(outputTargetSettingsNotifierProvider.notifier)
                .update(outputSettings.copyWith(browserSourceEnabled: v)),
          ),
        ),
        _TargetCard(
          icon: Icons.picture_in_picture_alt,
          label: l10n.settingsCaptionOverlay,
          enabled: outputSettings.overlayEnabled,
          onToggle: (v) => unawaited(
            ref
                .read(outputTargetSettingsNotifierProvider.notifier)
                .update(outputSettings.copyWith(overlayEnabled: v)),
          ),
        ),
        _TargetCard(
          icon: Icons.description_outlined,
          label: l10n.settingsTranscriptsTarget,
          enabled: true,
          onToggle: null,
        ),
        ComingSoonCard(
          icon: Icons.people_outlined,
          label: l10n.outputTargetsRemoteViewers,
          subtitle: l10n.outputTargetsPhase2,
        ),
      ],
    );
  }

  Future<void> _onObsToggle(bool value) async {
    final outputSettings = ref.read(outputTargetSettingsNotifierProvider);

    if (!value) {
      setState(() => _obsError = null);
      unawaited(
        ref
            .read(outputTargetSettingsNotifierProvider.notifier)
            .update(outputSettings.copyWith(obsEnabled: false)),
      );
      return;
    }

    setState(() {
      _obsTesting = true;
      _obsError = null;
    });

    final status = await ref
        .read(obsConnectionNotifierProvider.notifier)
        .testConnection();

    if (!mounted) return;

    if (status == ObsConnectionStatus.connected) {
      setState(() => _obsTesting = false);
      unawaited(
        ref
            .read(outputTargetSettingsNotifierProvider.notifier)
            .update(
              ref
                  .read(outputTargetSettingsNotifierProvider)
                  .copyWith(obsEnabled: true),
            ),
      );
    } else {
      final l10n = ZipBroadcastLocalizations.of(context)!;
      setState(() {
        _obsTesting = false;
        _obsError = l10n.obsConnectionError;
      });
    }
  }

  String _obsStatusLabel(ZipBroadcastLocalizations l10n, ObsConnectionStatus s) {
    return switch (s) {
      ObsConnectionStatus.connected => l10n.obsStatusConnected,
      ObsConnectionStatus.connecting => l10n.obsStatusConnecting,
      ObsConnectionStatus.reconnecting => l10n.obsStatusReconnecting,
      ObsConnectionStatus.error => l10n.obsStatusError,
      ObsConnectionStatus.disconnected => l10n.obsStatusDisconnected,
    };
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
