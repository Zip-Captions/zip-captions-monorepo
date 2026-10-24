import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_captions/src/providers/settings_notifier.dart';
import 'package:zip_captions/src/widgets/appearance_panel.dart';
import 'package:zip_captions/src/widgets/pop_out_controls.dart';
import 'package:zip_captions/src/widgets/pop_out_scope.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(recordingStateNotifierProvider.notifier);
      final current = ref.read(recordingStateNotifierProvider);
      if (current is StoppedState) {
        notifier.clearSession();
        unawaited(notifier.start());
      } else if (current is IdleState) {
        unawaited(notifier.start());
      }
      // recording / paused / reconnecting: a session is already active — leave it.
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingStateNotifierProvider);
    final entriesAsync = ref.watch(onScreenCaptionTargetProvider);
    final settings = ref.watch(displaySettingsProvider);
    final notifier = ref.read(displaySettingsProvider.notifier);
    final recordingNotifier = ref.read(recordingStateNotifierProvider.notifier);

    ref.listen<RecordingState>(recordingStateNotifierProvider, (prev, next) {
      if (next is StoppedState && context.mounted) {
        ref.invalidate(transcriptSessionListProvider);
        context.go('/history');
      }
    });

    final entries = entriesAsync.valueOrNull ?? const [];
    final popOut = PopOutScope.of(context);

    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showAppearancePanel = false),
            child: Column(
              children: [
                // UX-PIP-05 as v1 ships it: while popped out the captions are
                // in the pop-out, so the hint and the return action take the
                // caption surface's place in the main window. They go with
                // the flag (R-M6: every close path except the lazy `'-1'`
                // fallback). The caption target stays watched above, so the
                // pop-out keeps its source.
                if (popOut?.enabled ?? false)
                  Expanded(child: PopOutBanner(onReturn: popOut!.onToggle))
                else
                  Expanded(
                    child: CaptionDisplayWidget(
                      entries: entries,
                      settings: settings,
                      // UX-PIP-04 / BR-U8.1-11: on a platform that cannot host
                      // a sub-window nothing renders, not even a disabled pill.
                      controls: popOut == null || !popOut.visible
                          ? null
                          : PopOutInSurfaceToggle(
                              isPoppedOut: popOut.enabled,
                              enabled: popOut.available,
                              onToggle: popOut.onToggle,
                            ),
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
