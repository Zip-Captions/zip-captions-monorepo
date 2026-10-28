import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/enums.dart';
import 'package:zip_core/src/models/recording_error.dart';
import 'package:zip_core/src/models/recording_error_factories.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';
import 'package:zip_core/src/providers/session_stop_callback_provider.dart';
import 'package:zip_core/src/providers/stt_engine_provider.dart';
import 'package:zip_core/src/providers/stt_session_manager_provider.dart';
import 'package:zip_core/src/providers/wake_lock_service_provider.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';

import '../helpers/mock_stt_engine.dart';
import '../helpers/mock_stt_session_manager.dart';
import '../helpers/mock_wake_lock_service.dart';

/// Unit 10 tests for `RecordingStateNotifier`: TP-1 (every start failure
/// leaves its error), TP-16 (first error wins), TP-20 (a refused resume),
/// TP-2 (the reconnect path, driven by engine errors) and TP-2b (a session
/// is finalised and stopped exactly once).
void main() {
  late ProviderContainer container;
  late CaptionBus captionBus;
  late MockSttSessionManager manager;
  late MockWakeLockService wakeLock;
  late List<CaptionEvent> events;
  late void Function(RecordingError) emitError;
  late int finalizeCalls;

  setUp(() {
    captionBus = CaptionBus();
    manager = MockSttSessionManager();
    wakeLock = MockWakeLockService();
    events = [];
    finalizeCalls = 0;
    emitError = (_) => fail('onError was not captured');
    captionBus.stream.listen(events.add);

    when(
      () => manager.initialize(
        engineId: any(named: 'engineId'),
        localeId: any(named: 'localeId'),
        onResult: any(named: 'onResult'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((inv) async {
      emitError = inv.namedArguments[#onError] as void Function(RecordingError);
      return true;
    });
    when(() => manager.startListening()).thenAnswer((_) async => true);
    when(() => manager.pause()).thenAnswer((_) async => true);
    when(() => manager.resume()).thenAnswer((_) async => true);
    when(() => manager.stop()).thenAnswer((_) async {});
    when(() => manager.handleEngineError(any())).thenAnswer((_) async => true);
    when(() => wakeLock.acquire()).thenAnswer((_) async {});
    when(() => wakeLock.release()).thenAnswer((_) async {});
    when(() => wakeLock.onPause()).thenAnswer((_) async {});
    when(() => wakeLock.settings).thenReturn(const WakeLockSettings());

    container = _container(
      captionBus: captionBus,
      manager: manager,
      wakeLock: wakeLock,
      engine: MockSttEngine(),
    );
    container.read(sessionStopCallbackProvider).callback = () async {
      finalizeCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    };
  });

  tearDown(() {
    container.dispose();
    captionBus.dispose();
  });

  RecordingStateNotifier notifier() =>
      container.read(recordingStateNotifierProvider.notifier);
  RecordingState state() => container.read(recordingStateNotifierProvider);

  Future<void> flush() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  int stoppedEvents() => events
      .whereType<SessionStateEvent>()
      .where((e) => e.state is StoppedState)
      .length;

  /// The shared TP-1 outcome of any failed start.
  void expectFailedStart(RecordingError expected) {
    expect(state(), isA<IdleState>());
    expect(notifier().lastError, isNotNull);
    expect(notifier().lastError!.message, expected.message);
    expect(notifier().lastError!.severity, RecordingErrorSeverity.fatal);
    verifyNever(() => wakeLock.acquire());
    expect(events.whereType<SessionStateEvent>(), isEmpty);
  }

  group('TP-1: every start failure leaves its error in lastError', () {
    test('no engine registered -> engineInitFailed', () async {
      final c = _container(
        captionBus: captionBus,
        manager: manager,
        wakeLock: wakeLock,
        engine: null,
      );
      addTearDown(c.dispose);
      final n = c.read(recordingStateNotifierProvider.notifier);
      await n.start();

      expect(c.read(recordingStateNotifierProvider), isA<IdleState>());
      expect(
        n.lastError!.message,
        RecordingErrorFactories.engineInitFailed().message,
      );
      verifyNever(() => wakeLock.acquire());
      expect(events.whereType<SessionStateEvent>(), isEmpty);
    });

    final initFailures = <String, RecordingError Function()>{
      'microphone permission denied -> permissionDenied':
          RecordingErrorFactories.permissionDenied,
      'microphone permanently denied (before or after the request) -> '
          'permissionPermanentlyDenied':
          RecordingErrorFactories.permissionPermanentlyDenied,
      'initialize() returns false -> engineInitFailed':
          RecordingErrorFactories.engineInitFailed,
    };
    for (final entry in initFailures.entries) {
      test(entry.key, () async {
        when(
          () => manager.initialize(
            engineId: any(named: 'engineId'),
            localeId: any(named: 'localeId'),
            onResult: any(named: 'onResult'),
            onError: any(named: 'onError'),
          ),
        ).thenAnswer((inv) async {
          (inv.namedArguments[#onError] as void Function(RecordingError))(
            entry.value(),
          );
          return false;
        });

        await notifier().start();
        expectFailedStart(entry.value());
      });
    }

    test('initialize() throws -> engineInitFailed (fail closed)', () async {
      when(
        () => manager.initialize(
          engineId: any(named: 'engineId'),
          localeId: any(named: 'localeId'),
          onResult: any(named: 'onResult'),
          onError: any(named: 'onError'),
        ),
      ).thenThrow(Exception('boom'));

      await notifier().start();
      expectFailedStart(RecordingErrorFactories.engineInitFailed());
    });

    test('startListening() returns false -> engineStartFailed', () async {
      when(() => manager.startListening()).thenAnswer((_) async {
        emitError(RecordingErrorFactories.engineStartFailed());
        return false;
      });
      await notifier().start();
      expectFailedStart(RecordingErrorFactories.engineStartFailed());
      verify(() => manager.stop()).called(1);
    });

    test('startListening() throws -> engineStartFailed (fail closed)',
        () async {
      when(() => manager.startListening()).thenThrow(Exception('boom'));
      await notifier().start();
      expectFailedStart(RecordingErrorFactories.engineStartFailed());
    });

    test('an engine error arrives while start() is still running, after '
        'startListening() returned true -> that error, session stopped',
        () async {
      when(() => manager.startListening()).thenAnswer((_) async {
        emitError(RecordingErrorFactories.onDeviceRecognitionUnavailable());
        return true;
      });

      await notifier().start();

      expectFailedStart(
        RecordingErrorFactories.onDeviceRecognitionUnavailable(),
      );
      verify(() => manager.stop()).called(1);
    });

    test('a later success clears the error', () async {
      when(() => manager.startListening()).thenAnswer((_) async => false);
      await notifier().start();
      expect(notifier().lastError, isNotNull);

      when(() => manager.startListening()).thenAnswer((_) async => true);
      await notifier().start();
      expect(state(), isA<RecordingActiveState>());
      expect(notifier().lastError, isNull);
    });
  });

  group('TP-16: the first error wins during start()', () {
    test('a specific on-device error is not replaced by the generic '
        'start failure that follows it', () async {
      when(() => manager.startListening()).thenAnswer((_) async {
        emitError(RecordingErrorFactories.onDeviceRecognitionUnavailable());
        // The session manager reports its own generic error when
        // startListening() returns false.
        emitError(RecordingErrorFactories.engineStartFailed());
        return false;
      });

      await notifier().start();

      expectFailedStart(
        RecordingErrorFactories.onDeviceRecognitionUnavailable(),
      );
    });

    test('and the order does not matter: the first reported is kept',
        () async {
      when(() => manager.startListening()).thenAnswer((_) async {
        emitError(RecordingErrorFactories.permissionDenied());
        emitError(RecordingErrorFactories.onDeviceRecognitionUnavailable());
        return false;
      });

      await notifier().start();

      expectFailedStart(RecordingErrorFactories.permissionDenied());
    });

    test("start()'s own generic assignment does not overwrite a captured "
        'error when startListening() returns false without reporting one',
        () async {
      // Nothing is captured, so the generic error is used.
      when(() => manager.startListening()).thenAnswer((_) async => false);
      await notifier().start();
      expectFailedStart(RecordingErrorFactories.engineStartFailed());
    });
  });

  group('TP-20: a refused resume() stops the session', () {
    Future<String> startAndPause() async {
      await notifier().start();
      await notifier().pause();
      return (state() as PausedState).sessionId;
    }

    test('a refusal reported during resume() stops once and keeps the error',
        () async {
      await startAndPause();
      events.clear();
      when(() => manager.resume()).thenAnswer((_) async {
        emitError(RecordingErrorFactories.onDeviceRecognitionUnavailable());
        return false;
      });

      await notifier().resume();
      await flush();

      expect(state(), isA<StoppedState>());
      expect(
        notifier().lastError!.message,
        RecordingErrorFactories.onDeviceRecognitionUnavailable().message,
      );
      expect(finalizeCalls, 1);
      expect(stoppedEvents(), 1);
      verify(() => wakeLock.release()).called(1);
    });

    test('a resume() that returns false with no captured error stays Paused',
        () async {
      await startAndPause();
      when(() => manager.resume()).thenAnswer((_) async => false);

      await notifier().resume();

      expect(state(), isA<PausedState>());
      expect(notifier().lastError, isNull);
      expect(finalizeCalls, 0);
    });

    test('an error captured while a resume() succeeds also stops the session',
        () async {
      await startAndPause();
      when(() => manager.resume()).thenAnswer((_) async {
        emitError(RecordingErrorFactories.permissionDenied());
        return true;
      });

      await notifier().resume();
      await flush();

      expect(state(), isA<StoppedState>());
      expect(finalizeCalls, 1);
    });
  });

  group('TP-2c: a stop that lands while resume() is awaiting', () {
    Future<String> startAndPause() async {
      await notifier().start();
      await notifier().pause();
      return (state() as PausedState).sessionId;
    }

    test('the stop wins: stopped state, one finalise, wake lock released',
        () async {
      await startAndPause();
      events.clear();

      final gate = Completer<bool>();
      when(() => manager.resume()).thenAnswer((_) => gate.future);

      final resuming = notifier().resume();
      await flush();

      await notifier().stop();
      gate.complete(true);
      await resuming;
      await flush();

      expect(state(), isA<StoppedState>());
      expect(finalizeCalls, 1);
      expect(stoppedEvents(), 1);
      verify(() => wakeLock.release()).called(1);
      // Only pause() acquired the wake lock; the superseded resume() did not
      // acquire it a second time.
      verify(() => wakeLock.acquire()).called(1);
    });

    test('no engine listening remains after the stop', () async {
      await startAndPause();

      final gate = Completer<bool>();
      when(() => manager.resume()).thenAnswer((_) => gate.future);

      final resuming = notifier().resume();
      await flush();

      await notifier().stop();
      gate.complete(true);
      await resuming;
      await flush();

      // The manager was stopped and never left resuming behind the stop.
      verify(() => manager.stop()).called(greaterThanOrEqualTo(1));
      expect(state(), isNot(isA<RecordingActiveState>()));
    });

    test('a resume() that answers after the stop does not overwrite Stopped',
        () async {
      await startAndPause();

      final gate = Completer<bool>();
      when(() => manager.resume()).thenAnswer((_) => gate.future);

      final resuming = notifier().resume();
      await flush();

      await notifier().stop();
      gate.complete(true);
      await resuming;
      await flush();
      // A second flush lets any late publish land.
      await flush();

      expect(state(), isA<StoppedState>());
      expect(finalizeCalls, 1);
      // Exactly one stopped event: the resume must not publish a second.
      expect(stoppedEvents(), 1);
    });
  });

  group('TP-2d: finalisation that throws still stops the session', () {
    test('a throwing stop callback still reaches StoppedState, publishes the '
        'event and releases the wake lock', () async {
      container.read(sessionStopCallbackProvider).callback = () async {
        finalizeCalls++;
        throw StateError('finalise exploded');
      };
      await notifier().start();

      await notifier().stop();
      await flush();

      expect(state(), isA<StoppedState>());
      expect(finalizeCalls, 1);
      expect(stoppedEvents(), 1);
      verify(() => wakeLock.release()).called(1);
    });

    test('the engine is stopped and the error is not left in lastError',
        () async {
      container.read(sessionStopCallbackProvider).callback = () async {
        throw StateError('finalise exploded');
      };
      await notifier().start();
      events.clear();

      await notifier().stop();
      await flush();

      verify(() => manager.stop()).called(greaterThanOrEqualTo(1));
      expect(notifier().lastError, isNull);
    });
  });

  group('TP-2: the reconnect path, driven by engine errors', () {
    const error = RecordingErrorFactories.engineStartFailed;

    Future<void> startRecording() => notifier().start();

    test('an error while recording goes to reconnecting; a successful restart '
        'returns to recording and clears lastError', () async {
      await startRecording();
      emitError(error());
      expect(state(), isA<ReconnectingState>());
      await flush();
      expect(state(), isA<RecordingActiveState>());
      expect(notifier().lastError, isNull);
      expect(finalizeCalls, 0);
    });

    test('a failed restart stops: finalised, stopped event, wake lock released',
        () async {
      when(() => manager.handleEngineError(any()))
          .thenAnswer((_) async => false);
      await startRecording();
      emitError(error());
      await flush();

      expect(state(), isA<StoppedState>());
      expect(finalizeCalls, 1);
      expect(stoppedEvents(), 1);
      verify(() => wakeLock.release()).called(1);
    });

    test('a second error after the one restart attempt stops', () async {
      final recovery = Completer<bool>();
      when(() => manager.handleEngineError(any()))
          .thenAnswer((_) => recovery.future);
      await startRecording();
      emitError(error()); // attempt 1: reconnecting
      emitError(error()); // already attempted: stop
      await flush();

      expect(state(), isA<StoppedState>());
      recovery.complete(true); // the late recovery must not undo the stop
      await flush();
      expect(state(), isA<StoppedState>());
      expect(finalizeCalls, 1);
      expect(stoppedEvents(), 1);
    });

    test('an error while paused or after stop is ignored', () async {
      await startRecording();
      await notifier().pause();
      emitError(error());
      await flush();
      expect(state(), isA<PausedState>());

      await notifier().stop();
      emitError(error());
      await flush();
      expect(state(), isA<StoppedState>());
      expect(finalizeCalls, 1);
    });

    test('a user stop during recovery is not overwritten', () async {
      final recovery = Completer<bool>();
      when(() => manager.handleEngineError(any()))
          .thenAnswer((_) => recovery.future);
      await startRecording();
      emitError(error());
      expect(state(), isA<ReconnectingState>());

      await notifier().stop();
      expect(state(), isA<StoppedState>());

      recovery.complete(true);
      await flush();
      expect(state(), isA<StoppedState>());
      expect(finalizeCalls, 1);
    });
  });

  group('TP-2b: a session is finalised and stopped exactly once', () {
    void expectOnce() {
      expect(state(), isA<StoppedState>());
      expect(finalizeCalls, 1, reason: 'one transcript finalisation');
      expect(stoppedEvents(), 1, reason: 'one StoppedState event');
      verify(() => wakeLock.release()).called(1);
    }

    test('a refusal during the REL-U2.1 restart: one finalise and one stopped '
        "event, and the recovery future's later false adds nothing",
        () async {
      final recovery = Completer<bool>();
      when(() => manager.handleEngineError(any())).thenAnswer((_) {
        // The restart's engine start is refused (a lasting error) while the
        // state is Reconnecting and the one attempt is already used.
        emitError(RecordingErrorFactories.onDeviceRecognitionUnavailable());
        return recovery.future;
      });
      await notifier().start();
      emitError(RecordingErrorFactories.engineStartFailed());
      await Future<void>.delayed(Duration.zero);
      recovery.complete(false);
      await flush();

      expectOnce();
    });

    test('a recovery exception and a user stop together', () async {
      final recovery = Completer<bool>();
      when(() => manager.handleEngineError(any()))
          .thenAnswer((_) => recovery.future);
      await notifier().start();
      emitError(RecordingErrorFactories.engineStartFailed());

      final stopping = notifier().stop();
      recovery.completeError(Exception('recovery blew up'));
      await stopping;
      await flush();

      expectOnce();
    });

    test('an error-branch stop and a user stop together', () async {
      final recovery = Completer<bool>();
      when(() => manager.handleEngineError(any()))
          .thenAnswer((_) => recovery.future);
      await notifier().start();
      emitError(RecordingErrorFactories.engineStartFailed());
      emitError(RecordingErrorFactories.engineStartFailed()); // finish starts
      final stopping = notifier().stop(); // the user taps Stop during it
      await stopping;
      recovery.complete(true);
      await flush();

      expectOnce();
    });

    test('a recovery failure and a user stop together', () async {
      final recovery = Completer<bool>();
      when(() => manager.handleEngineError(any()))
          .thenAnswer((_) => recovery.future);
      await notifier().start();
      emitError(RecordingErrorFactories.engineStartFailed());

      final stopping = notifier().stop();
      recovery.complete(false);
      await stopping;
      await flush();

      expectOnce();
    });

    test('stop() twice finalises once', () async {
      await notifier().start();
      await Future.wait([notifier().stop(), notifier().stop()]);
      await flush();

      expectOnce();
    });

    test('stop() calls the session manager first, before finalising',
        () async {
      await notifier().start();
      final order = <String>[];
      when(() => manager.stop()).thenAnswer((_) async {
        order.add('manager.stop');
      });
      container.read(sessionStopCallbackProvider).callback = () async {
        order.add('finalize');
      };

      await notifier().stop();

      expect(order, ['manager.stop', 'finalize']);
    });
  });
  group('Q-1 start() single-flight', () {
    test('two concurrent starts initialize once and end consistent', () async {
      final gate = Completer<bool>();
      var initCalls = 0;
      when(
        () => manager.initialize(
          engineId: any(named: 'engineId'),
          localeId: any(named: 'localeId'),
          onResult: any(named: 'onResult'),
          onError: any(named: 'onError'),
        ),
      ).thenAnswer((_) async {
        initCalls++;
        return gate.future;
      });

      final n = notifier();
      final first = n.start();
      final second = n.start();
      // Let both calls reach the guard before the manager answers.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      gate.complete(true);
      await Future.wait([first, second]);
      await flush();

      expect(initCalls, 1, reason: 'initialize must run once for two starts');
      expect(state(), isA<RecordingActiveState>());
      expect(n.lastError, isNull);
      // The losing call never stopped the winner.
      verifyNever(() => manager.stop());
      expect(stoppedEvents(), 0);
    });

    final permissionFailures = <String, RecordingError Function()>{
      'permissionDenied': RecordingErrorFactories.permissionDenied,
      'permissionPermanentlyDenied':
          RecordingErrorFactories.permissionPermanentlyDenied,
    };
    for (final entry in permissionFailures.entries) {
      test(
          'two concurrent starts report ${entry.key}, never engineInitFailed',
          () async {
        // The second, overlapping attempt is what permission_handler
        // rejects ("already running"), so the manager throws on the second
        // call. That is the exact shape Q-1 was observed in.
        var initCalls = 0;
        when(
          () => manager.initialize(
            engineId: any(named: 'engineId'),
            localeId: any(named: 'localeId'),
            onResult: any(named: 'onResult'),
            onError: any(named: 'onError'),
          ),
        ).thenAnswer((inv) async {
          initCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          if (initCalls > 1) throw Exception('already running');
          (inv.namedArguments[#onError] as void Function(RecordingError))(
            entry.value(),
          );
          return false;
        });

        final n = notifier();
        await Future.wait([n.start(), n.start()]);
        await flush();

        expect(state(), isA<IdleState>());
        expect(n.lastError, isNotNull);
        expect(n.lastError!.message, entry.value().message);
        expect(
          n.lastError!.message,
          isNot(RecordingErrorFactories.engineInitFailed().message),
        );
      });
    }

    test('two concurrent successful starts act once', () async {
      final n = notifier();
      await Future.wait([n.start(), n.start()]);
      await flush();

      verify(() => manager.startListening()).called(1);
      expect(state(), isA<RecordingActiveState>());
      final sessionEvents =
          events.whereType<SessionStateEvent>().where(
                (e) => e.state is RecordingActiveState,
              );
      expect(sessionEvents, hasLength(1));
      verify(() => wakeLock.acquire()).called(1);
      verifyNever(() => manager.stop());
    });

    test('the guard resets after a success', () async {
      final n = notifier();
      await n.start();
      await n.stop();
      await flush();
      n.clearSession();

      await n.start();
      await flush();

      verify(() => manager.startListening()).called(2);
      expect(state(), isA<RecordingActiveState>());
    });

    test('the guard resets after a failure', () async {
      when(() => manager.startListening()).thenAnswer((_) async => false);
      final n = notifier();
      await n.start();
      await flush();
      expect(state(), isA<IdleState>());

      when(() => manager.startListening()).thenAnswer((_) async => true);
      await n.start();
      await flush();

      expect(state(), isA<RecordingActiveState>());
    });

    test('the guard resets after the manager throws', () async {
      var first = true;
      when(() => manager.startListening()).thenAnswer((_) async {
        if (first) {
          first = false;
          throw Exception('thrown once');
        }
        return true;
      });
      final n = notifier();
      await n.start();
      await flush();
      expect(state(), isA<IdleState>());

      await n.start();
      await flush();

      expect(state(), isA<RecordingActiveState>());
    });

    test('two concurrent resumes resume once', () async {
      when(() => manager.pause()).thenAnswer((_) async => true);
      final n = notifier();
      await n.start();
      await n.pause();
      await flush();
      expect(state(), isA<PausedState>());

      final secondResumeGate = Completer<void>();
      when(() => manager.resume()).thenAnswer((_) async {
        await secondResumeGate.future;
        return true;
      });

      final first = n.resume();
      final second = n.resume();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      secondResumeGate.complete();
      await Future.wait([first, second]);
      await flush();

      verify(() => manager.resume()).called(1);
      expect(state(), isA<RecordingActiveState>());
    });
  });

}

ProviderContainer _container({
  required CaptionBus captionBus,
  required MockSttSessionManager manager,
  required MockWakeLockService wakeLock,
  required MockSttEngine? engine,
}) =>
    ProviderContainer(
      overrides: [
        captionBusProvider.overrideWithValue(captionBus),
        sttSessionManagerProvider.overrideWithValue(manager),
        wakeLockServiceProvider.overrideWithValue(wakeLock),
        sttEngineProvider.overrideWithValue(engine),
        resolvedLocaleIdProvider.overrideWithValue('en-US'),
      ],
    );
