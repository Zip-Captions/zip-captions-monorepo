import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide addTearDown, any, expect, group, test;
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';
import 'package:zip_core/src/providers/stt_engine_provider.dart';
import 'package:zip_core/src/providers/stt_session_manager_provider.dart';
import 'package:zip_core/src/providers/wake_lock_service_provider.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';

import '../helpers/generators.dart';
import '../helpers/mock_stt_engine.dart';
import '../helpers/mock_stt_session_manager.dart';
import '../helpers/mock_wake_lock_service.dart';
import '../helpers/recording_state_model.dart';

/// Creates a [ProviderContainer] with all mock overrides needed for
/// RecordingStateNotifier PBT tests.
({ProviderContainer container, CaptionBus bus}) createTestContainer() {
  final captionBus = CaptionBus();
  final mockSessionManager = MockSttSessionManager();
  final mockWakeLockService = MockWakeLockService();
  final mockEngine = MockSttEngine();

  when(() => mockSessionManager.initialize(
        engineId: any(named: 'engineId'),
        localeId: any(named: 'localeId'),
        onResult: any(named: 'onResult'),
        onError: any(named: 'onError'),
      )).thenAnswer((_) async => true);
  when(() => mockSessionManager.startListening())
      .thenAnswer((_) async => true);
  when(() => mockSessionManager.pause()).thenAnswer((_) async => true);
  when(() => mockSessionManager.resume()).thenAnswer((_) async => true);
  when(() => mockSessionManager.stop()).thenAnswer((_) async {});
  when(() => mockWakeLockService.acquire()).thenAnswer((_) async {});
  when(() => mockWakeLockService.release()).thenAnswer((_) async {});
  when(() => mockWakeLockService.onPause()).thenAnswer((_) async {});
  when(() => mockWakeLockService.settings)
      .thenReturn(const WakeLockSettings());

  final container = ProviderContainer(
    overrides: [
      captionBusProvider.overrideWithValue(captionBus),
      sttSessionManagerProvider.overrideWithValue(mockSessionManager),
      wakeLockServiceProvider.overrideWithValue(mockWakeLockService),
      sttEngineProvider.overrideWithValue(mockEngine),
      resolvedLocaleIdProvider.overrideWithValue('en-US'),
    ],
  );

  return (container: container, bus: captionBus);
}

/// Extracts sessionId from any non-idle state, or null for idle.
String? extractSessionId(RecordingState state) {
  return switch (state) {
    RecordingActiveState(:final sessionId) => sessionId,
    PausedState(:final sessionId) => sessionId,
    ReconnectingState(:final sessionId) => sessionId,
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
    (ReconnectingState(), ModelState.reconnecting) => true,
    (StoppedState(), ModelState.stopped) => true,
    _ => false,
  };
}

/// Returns true if [cmd] is applicable to the pure model PBT test.
///
/// Engine error / reconnect commands require async side-effects that cannot
/// be exercised without full provider wiring. They are covered in
/// example-based tests instead.
bool isPureModelCommand(Command cmd) {
  return switch (cmd) {
    Command.start ||
    Command.pause ||
    Command.resume ||
    Command.stop ||
    Command.clearSession =>
      true,
    Command.engineError ||
    Command.reconnectSuccess ||
    Command.reconnectFailure =>
      false,
  };
}

/// Executes a [Command] on the real [RecordingStateNotifier].
///
/// Only supports pure state-machine commands (no engine error / reconnect).
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
    case Command.engineError:
    case Command.reconnectSuccess:
    case Command.reconnectFailure:
      break; // Handled in example-based tests.
  }
}

void main() {
  group('RecordingStateNotifier model-based PBT', () {
    Glados(arbitraryCommandSequence).test(
      'real notifier matches pure model after every command',
      (commands) async {
        final (:container, :bus) = createTestContainer();
        addTearDown(() {
          container.dispose();
          bus.dispose();
        });

        final notifier = container.read(
          recordingStateNotifierProvider.notifier,
        );

        var modelState = ModelState.idle;

        for (final cmd in commands) {
          if (!isPureModelCommand(cmd)) continue;
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
        final (:container, :bus) = createTestContainer();
        addTearDown(() {
          container.dispose();
          bus.dispose();
        });

        final notifier = container.read(
          recordingStateNotifierProvider.notifier,
        );

        String? currentSessionId;

        for (final cmd in commands) {
          if (!isPureModelCommand(cmd)) continue;
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
