import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart';
import 'package:zip_broadcast/src/models/obs_connection_status.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';
import 'package:zip_broadcast/src/providers/settings_notifier.dart';
import 'package:zip_broadcast/src/widgets/appearance_panel.dart';
import 'package:zip_broadcast/src/widgets/audio_level_row.dart';
import 'package:zip_broadcast/src/widgets/status_pill.dart';
import 'package:zip_broadcast/src/widgets/zb_recording_controls_bar.dart';
import 'package:zip_core/zip_core.dart';

/// Live captioning screen for Zip Broadcast (E1–E10).
///
/// Starts the broadcast session on navigation (E2). Auto-navigates to
/// `/history` when [BroadcastRecordingNotifier] transitions to
/// [BroadcastStoppedState] (E10 / I3).
class RecordingScreen extends ConsumerStatefulWidget {
  /// Creates a [RecordingScreen].
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  bool _showAppearancePanel = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier =
          ref.read(broadcastRecordingNotifierProvider.notifier);
      final current = ref.read(broadcastRecordingNotifierProvider);
      if (current is BroadcastStoppedState) {
        notifier.clearSession();
        unawaited(notifier.start());
      } else if (current is BroadcastIdleState) {
        unawaited(notifier.start());
      }
      // active / paused / reconnecting: leave existing session running.
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(broadcastRecordingNotifierProvider);
    final entriesAsync = ref.watch(onScreenCaptionTargetProvider);
    final settings = ref.watch(displaySettingsProvider);
    final displayNotifier = ref.read(displaySettingsProvider.notifier);
    final recordingNotifier =
        ref.read(broadcastRecordingNotifierProvider.notifier);
    final obsStatus = ref.watch(obsConnectionNotifierProvider);
    final outputSettings = ref.watch(outputTargetSettingsNotifierProvider);

    ref.listen<BroadcastSessionState>(
      broadcastRecordingNotifierProvider,
      (prev, next) {
        if (next is BroadcastStoppedState && context.mounted) {
          ref.invalidate(transcriptSessionListProvider);
          context.go('/history');
        }
      },
    );

    final entries = entriesAsync.valueOrNull ?? const [];
    final isPaused = sessionState.isPaused;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _StatusBar(
                obsStatus: obsStatus,
                outputSettings: outputSettings,
              ),
              AudioLevelRow(visible: !isPaused),
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _showAppearancePanel = false),
                  child: CaptionDisplayWidget(
                    entries: entries,
                    settings: settings,
                  ),
                ),
              ),
              ZbRecordingControlsBar(
                state: sessionState,
                onPause: recordingNotifier.pause,
                onResume: recordingNotifier.resume,
                onStop: recordingNotifier.stop,
              ),
            ],
          ),
          // Appearance panel overlay (E7).
          if (_showAppearancePanel)
            Positioned(
              top: 56,
              right: 16,
              child: AppearancePanel(
                settings: settings,
                notifier: displayNotifier,
              ),
            ),
          // Paused overlay chip (E7).
          if (isPaused)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: false,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pause_circle_outline),
                          const SizedBox(width: 8),
                          const Text('Paused'),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: recordingNotifier.resume,
                            child: const Text('Resume'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      // Appearance toggle in AppBar area (E4).
      floatingActionButtonLocation:
          FloatingActionButtonLocation.miniEndTop,
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'Appearance',
        onPressed: () =>
            setState(() => _showAppearancePanel = !_showAppearancePanel),
        child: const Icon(Icons.text_fields),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.obsStatus,
    required this.outputSettings,
  });

  final ObsConnectionStatus obsStatus;
  final OutputTargetSettings outputSettings;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            StatusPill(
              label: 'OBS',
              color: _obsColor(obsStatus),
            ),
            const SizedBox(width: 12),
            StatusPill(
              label: 'Browser Source',
              color: outputSettings.browserSourceEnabled
                  ? Colors.green
                  : Colors.grey,
            ),
            const SizedBox(width: 12),
            StatusPill(
              label: 'Overlay',
              color: outputSettings.overlayEnabled
                  ? Colors.green
                  : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Color _obsColor(ObsConnectionStatus status) {
    return switch (status) {
      ObsConnectionStatus.connected => Colors.green,
      ObsConnectionStatus.connecting ||
      ObsConnectionStatus.reconnecting =>
        Colors.orange,
      ObsConnectionStatus.error => Colors.red,
      ObsConnectionStatus.disconnected => Colors.grey,
    };
  }
}
