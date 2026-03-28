import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide addTearDown, expect, group, test;
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';

import '../helpers/generators.dart';
import '../helpers/recording_state_model.dart';

/// Maps a [ModelState] to the corresponding [RecordingState] type.
bool statesMatch(RecordingState real, ModelState model) {
  return switch ((real, model)) {
    (IdleState(), ModelState.idle) => true,
    (RecordingActiveState(), ModelState.recording) => true,
    (PausedState(), ModelState.paused) => true,
    (StoppedState(), ModelState.stopped) => true,
    _ => false,
  };
}

/// Executes a [Command] on the real [RecordingStateNotifier].
Future<void> executeCommand(
  RecordingStateNotifier notifier,
  Command cmd,
) async {
  switch (cmd) {
    case Command.start:
      await notifier.start();
    case Command.pause:
      await notifier.pause();
    case Command.resume:
      await notifier.resume();
    case Command.stop:
      await notifier.stop();
    case Command.clearSession:
      notifier.clearSession();
  }
}

void main() {
  group('RecordingStateNotifier model-based PBT', () {
    Glados(arbitraryCommandSequence).test(
      'real notifier matches pure model after every command',
      (commands) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(
          recordingStateNotifierProvider.notifier,
        );

        var modelState = ModelState.idle;

        for (final cmd in commands) {
          await executeCommand(notifier, cmd);
          modelState = applyCommand(modelState, cmd);

          final realState = container.read(
            recordingStateNotifierProvider,
          );
          expect(
            statesMatch(realState, modelState),
            isTrue,
            reason: 'After $cmd: expected $modelState, '
                'got ${realState.runtimeType}',
          );
        }
      },
    );
  });
}
