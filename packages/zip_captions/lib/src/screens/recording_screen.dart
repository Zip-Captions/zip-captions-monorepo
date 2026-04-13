import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_captions/src/providers/settings_notifier.dart';
import 'package:zip_captions/src/widgets/appearance_panel.dart';
import 'package:zip_captions/src/widgets/recording_controls_bar.dart';
import 'package:zip_core/zip_core.dart';

/// Recording screen — shows the live caption feed and playback controls.
///
/// Auto-navigates to `/history` when [RecordingState] transitions to
/// [StoppedState] (BR-U5-01). Invalidates [transcriptSessionListProvider]
/// before navigation so HistoryScreen loads fresh data (REL-U5.1, NFR-DQ2=A).
class RecordingScreen extends ConsumerStatefulWidget {
  /// Creates a [RecordingScreen].
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  bool _showAppearancePanel = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingStateNotifierProvider);
    final entriesAsync = ref.watch(onScreenCaptionTargetProvider);
    final settings = ref.watch(displaySettingsProvider);
    final notifier = ref.read(displaySettingsProvider.notifier);
    final recordingNotifier =
        ref.read(recordingStateNotifierProvider.notifier);

    ref.listen<RecordingState>(recordingStateNotifierProvider, (prev, next) {
      if (next is StoppedState && context.mounted) {
        ref.invalidate(transcriptSessionListProvider);
        context.go('/history');
      }
    });

    final entries = entriesAsync.valueOrNull ?? const [];

    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showAppearancePanel = false),
            child: Column(
              children: [
                Expanded(
                  child: CaptionDisplayWidget(
                    entries: entries,
                    settings: settings,
                  ),
                ),
                RecordingControlsBar(
                  state: state,
                  onPause: recordingNotifier.pause,
                  onResume: recordingNotifier.resume,
                  onStop: recordingNotifier.stop,
                ),
              ],
            ),
          ),
          if (_showAppearancePanel)
            Positioned(
              bottom: 80,
              right: 16,
              child: AppearancePanel(
                settings: settings,
                notifier: notifier,
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'Appearance',
        onPressed: () =>
            setState(() => _showAppearancePanel = !_showAppearancePanel),
        child: const Icon(Icons.text_fields),
      ),
    );
  }
}
