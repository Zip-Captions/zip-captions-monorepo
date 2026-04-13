import 'package:flutter/material.dart';
import 'package:zip_core/zip_core.dart';

/// Bottom control bar rendered inside RecordingScreen.
///
/// Renders Pause+Stop when recording, Resume+Stop when paused,
/// and a spinner+Stop when reconnecting. Idle and stopped states
/// are never shown here — navigation occurs before they appear.
class RecordingControlsBar extends StatelessWidget {
  /// Creates a [RecordingControlsBar].
  const RecordingControlsBar({
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    super.key,
  });

  /// The current recording state.
  final RecordingState state;

  /// Called when the Pause button is tapped.
  final VoidCallback onPause;

  /// Called when the Resume button is tapped.
  final VoidCallback onResume;

  /// Called when the Stop button is tapped.
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state is RecordingActiveState) ...[
              IconButton.filled(
                icon: const Icon(Icons.pause),
                tooltip: 'Pause',
                onPressed: onPause,
              ),
              const SizedBox(width: 16),
            ] else if (state is PausedState) ...[
              IconButton.filled(
                icon: const Icon(Icons.play_arrow),
                tooltip: 'Resume',
                onPressed: onResume,
              ),
              const SizedBox(width: 16),
            ] else if (state is ReconnectingState) ...[
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(width: 16),
            ],
            IconButton.filledTonal(
              icon: const Icon(Icons.stop),
              tooltip: 'Stop',
              onPressed: onStop,
            ),
          ],
        ),
      ),
    );
  }
}
