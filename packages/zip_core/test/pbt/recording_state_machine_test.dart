import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide addTearDown, expect, group, test;
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';

import '../helpers/generators.dart';
import '../helpers/recording_state_model.dart';

/// Extracts sessionId from any non-idle state, or null for idle.
String? extractSessionId(RecordingState state) {
  return switch (state) {
    RecordingActiveState(:final sessionId) => sessionId,
    PausedState(:final sessionId) => sessionId,
    StoppedState(:final sessionId) => sessionId,
    IdleState() => null,
  };
}

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
        final captionBus = CaptionBus();
        final container = ProviderContainer(
          overrides: [
            captionBusProvider.overrideWithValue(captionBus),
          ],
        );
        addTearDown(() {
          container.dispose();
          captionBus.dispose();
        });

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

    Glados(arbitraryCommandSequence).test(
      'sessionId is consistent within a session',
      (commands) async {
        final captionBus = CaptionBus();
        final container = ProviderContainer(
          overrides: [
            captionBusProvider.overrideWithValue(captionBus),
          ],
        );
        addTearDown(() {
          container.dispose();
          captionBus.dispose();
        });

        final notifier = container.read(
          recordingStateNotifierProvider.notifier,
        );

        String? currentSessionId;

        for (final cmd in commands) {
          await executeCommand(notifier, cmd);
          final state = container.read(recordingStateNotifierProvider);

          final sessionId = extractSessionId(state);
          if (sessionId != null) {
            if (currentSessionId == null) {
              currentSessionId = sessionId;
              expect(currentSessionId, isNotEmpty);
            } else {
              expect(
                sessionId,
                equals(currentSessionId),
                reason: 'sessionId changed within session after $cmd',
              );
            }
          } else if (state is IdleState) {
            currentSessionId = null;
          }
        }
      },
    );
  });
}
