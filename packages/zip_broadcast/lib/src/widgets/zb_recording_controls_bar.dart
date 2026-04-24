import 'package:flutter/material.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart';

/// Bottom control bar for [RecordingScreen] (E9).
///
/// Uses [BroadcastSessionState] (not [RecordingState]) since Zip Broadcast
/// manages multi-engine state. State-to-button mapping:
/// - [BroadcastIdleState] → spinner only (engines initialising)
/// - [BroadcastActiveState] → Pause + Stop
/// - [BroadcastPausedState] → Resume + Stop
/// - [BroadcastReconnectingState] → spinner + Stop
class ZbRecordingControlsBar extends StatelessWidget {
  /// Creates a [ZbRecordingControlsBar].
  const ZbRecordingControlsBar({
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    super.key,
  });

  /// Current session state driving the button layout.
  final BroadcastSessionState state;

  /// Called when the Pause button is tapped.
  final VoidCallback onPause;

  /// Called when the Resume button is tapped.
  final VoidCallback onResume;

  /// Called when the Stop button is tapped.
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    if (state is BroadcastIdleState) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state is BroadcastActiveState) ...[
              IconButton.filled(
                icon: const Icon(Icons.pause),
                tooltip: 'Pause',
                onPressed: onPause,
              ),
              const SizedBox(width: 16),
            ] else if (state is BroadcastPausedState) ...[
              IconButton.filled(
                icon: const Icon(Icons.play_arrow),
                tooltip: 'Resume',
                onPressed: onResume,
              ),
              const SizedBox(width: 16),
            ] else if (state is BroadcastReconnectingState) ...[
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
