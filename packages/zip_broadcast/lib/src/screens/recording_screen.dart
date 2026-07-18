import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart';
import 'package:zip_broadcast/src/models/obs_connection_status.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
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
/// Displays current broadcast state and exposes Start / Pause / Resume / Stop
/// controls. Does not alter broadcast state on navigation — the user drives all
/// lifecycle transitions explicitly. Auto-navigates to `/history` (transcripts
/// on) or `/` (transcripts off) when [BroadcastRecordingNotifier] transitions
/// to [BroadcastStoppedState] (E10 / I3).
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
    // Clear stale stopped-session display so the screen shows idle state
    // if the user re-enters after a broadcast has already stopped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(broadcastRecordingNotifierProvider);
      if (current is BroadcastStoppedState) {
        ref.read(broadcastRecordingNotifierProvider.notifier).clearSession();
      }
    });
  }

  Future<void> _startAndHandleError() async {
    final notifier = ref.read(broadcastRecordingNotifierProvider.notifier);
    await notifier.start();
    if (!mounted) return;
    final state = ref.read(broadcastRecordingNotifierProvider);
    if (state is BroadcastIdleState && state.lastError != null) {
      final l10n = ZipBroadcastLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.recordingStartError(state.lastError!.toString())),
        ),
      );
    }
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
    final transcriptSettings = ref.watch(transcriptSettingsNotifierProvider);
    final hasAudioInputs = ref.watch(audioInputConfigNotifierProvider).isNotEmpty;

    ref.listen<BroadcastSessionState>(
      broadcastRecordingNotifierProvider,
      (prev, next) {
        if (!context.mounted) return;
        if (next is BroadcastStoppedState) {
          ref.invalidate(transcriptSessionListProvider(''));
          final goToHistory = transcriptSettings.captureEnabled;
          // Reset to idle now — this screen's initState only clears a
          // stale stopped session on re-entry, which never happens when
          // navigating home, leaving Home's Start button stuck disabled.
          recordingNotifier.clearSession();
          if (goToHistory) {
            context.go('/history');
          } else {
            context.go('/');
          }
        } else if (next is BroadcastIdleState && next.lastError != null) {
          final l10n = ZipBroadcastLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.recordingStartError(next.lastError!.toString()),
              ),
            ),
          );
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
                  behavior: HitTestBehavior.translucent,
                  onTap: _showAppearancePanel
                      ? () => setState(
                            () => _showAppearancePanel = false,
                          )
                      : null,
                  child: CaptionDisplayWidget(
                    entries: entries,
                    settings: settings,
                  ),
                ),
              ),
              ZbRecordingControlsBar(
                state: sessionState,
                onStart: hasAudioInputs
                    ? () => unawaited(_startAndHandleError())
                    : null,
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
                        Text(
                          ZipBroadcastLocalizations.of(context)!
                              .recordingPaused,
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: recordingNotifier.resume,
                          child: Text(
                            ZipBroadcastLocalizations.of(context)!
                                .recordingResume,
                          ),
                        ),
                      ],
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
        tooltip: ZipBroadcastLocalizations.of(context)!.recordingAppearance,
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
              label: ZipBroadcastLocalizations.of(context)!.statusPillObs,
              color: _obsColor(obsStatus),
            ),
            const SizedBox(width: 12),
            StatusPill(
              label: ZipBroadcastLocalizations.of(context)!
                  .statusPillBrowserSource,
              color: outputSettings.browserSourceEnabled
                  ? Colors.green
                  : Colors.grey,
            ),
            const SizedBox(width: 12),
            StatusPill(
              label: ZipBroadcastLocalizations.of(context)!.statusPillOverlay,
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
