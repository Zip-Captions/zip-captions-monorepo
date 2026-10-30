import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_error.dart';
import 'package:zip_core/src/models/recording_error_factories.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/models/transcript_save_result.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';
import 'package:zip_core/src/providers/session_stop_callback_provider.dart';
import 'package:zip_core/src/providers/session_stop_reason_provider.dart';
import 'package:zip_core/src/providers/speech_inactivity_timeout_provider.dart';
import 'package:zip_core/src/providers/stop_finalise_timeout_provider.dart';
import 'package:zip_core/src/providers/stt_engine_provider.dart';
import 'package:zip_core/src/providers/stt_session_manager_provider.dart';
import 'package:zip_core/src/providers/transcript_save_outcome_provider.dart';
import 'package:zip_core/src/providers/wake_lock_service_provider.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';

import '../helpers/mock_stt_engine.dart';
import '../helpers/mock_stt_session_manager.dart';
import '../helpers/mock_wake_lock_service.dart';

SttResult _result(String text, {bool isFinal = true}) => SttResult(
  text: text,
  isFinal: isFinal,
  confidence: 1,
  timestamp: DateTime.utc(2026),
  sourceId: 'platform',
);

/// A compact name for each bus event, so a test can assert the order.
String _describe(CaptionEvent event) => switch (event) {
  SttResultEvent(:final result) => 'result:${result.text}',
  SessionStateEvent(:final state) => switch (state) {
    RecordingActiveState() => 'state:recording',
    PausedState() => 'state:paused',
    ReconnectingState() => 'state:reconnecting',
    StoppedState() => 'state:stopped',
    IdleState() => 'state:idle',
  },
};

void main() {
  late CaptionBus captionBus;
  late MockSttSessionManager manager;
  late MockWakeLockService wakeLock;
  late MockSttEngine engine;
  late ProviderContainer container;
  late List<String> events;

  void Function(SttResult)? onResult;
  void Function(RecordingError)? onError;

  /// Builds the container; [stopTimeout] and [inactivity] are overridden so
  /// timing tests are short.
  void build({
    Duration stopTimeout = const Duration(milliseconds: 60),
    Duration inactivity = const Duration(minutes: 5),
  }) {
    container = ProviderContainer(
      overrides: [
        captionBusProvider.overrideWithValue(captionBus),
        sttSessionManagerProvider.overrideWithValue(manager),
        wakeLockServiceProvider.overrideWithValue(wakeLock),
        sttEngineProvider.overrideWithValue(engine),
        resolvedLocaleIdProvider.overrideWithValue('en-US'),
        stopFinaliseTimeoutProvider.overrideWithValue(stopTimeout),
        speechInactivityTimeoutProvider.overrideWithValue(inactivity),
      ],
    );
  }

  RecordingStateNotifier notifier() =>
      container.read(recordingStateNotifierProvider.notifier);
  RecordingState state() => container.read(recordingStateNotifierProvider);

  setUpAll(() {
    registerFallbackValue(RecordingErrorFactories.engineStartFailed());
  });

  setUp(() {
    captionBus = CaptionBus();
    manager = MockSttSessionManager();
    wakeLock = MockWakeLockService();
    engine = MockSttEngine();
    onResult = null;
    onError = null;
    events = [];
    captionBus.stream.listen((e) => events.add(_describe(e)));

    when(
      () => manager.initialize(
        engineId: any(named: 'engineId'),
        localeId: any(named: 'localeId'),
        onResult: any(named: 'onResult'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((invocation) async {
      onResult =
          invocation.namedArguments[#onResult] as void Function(SttResult);
      onError =
          invocation.namedArguments[#onError] as void Function(RecordingError);
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
    build();
  });

  tearDown(() {
    container.dispose();
    captionBus.dispose();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('BR-U10-56 the drained phrase is published first (TP-35)', () {
    test('on Stop it reaches the bus before the transcript finalise', () async {
      final order = <String>[];
      captionBus.stream.listen((e) {
        if (e is SttResultEvent) order.add('bus:${e.result.text}');
      });
      container.read(sessionStopCallbackProvider).callback = () async {
        order.add('finalise');
      };
      await notifier().start();
      when(() => manager.stop()).thenAnswer((_) async {
        // The engine delivers the drained phrase before stop() returns.
        onResult!(_result('the last phrase'));
      });

      await notifier().stop();
      await settle();

      expect(order, ['bus:the last phrase', 'finalise']);
      expect(state(), isA<StoppedState>());
    });

    test(
      'on Pause it reaches the bus before PausedState is published',
      () async {
        await notifier().start();
        events.clear();
        when(() => manager.pause()).thenAnswer((_) async {
          onResult!(_result('the last phrase'));
          return true;
        });

        await notifier().pause();
        await settle();

        expect(events, ['result:the last phrase', 'state:paused']);
        expect(state(), isA<PausedState>());
      },
    );
  });

  group('BR-U10-57 the recovery is re-armed (TP-36)', () {
    final error = RecordingErrorFactories.engineStartFailed();

    test(
      'a second error before any non-empty result stops the session',
      () async {
        await notifier().start();
        onError!(error);
        await settle();
        expect(state(), isA<RecordingActiveState>(), reason: 'recovered');

        onError!(error);
        await settle();

        expect(state(), isA<StoppedState>());
        verify(() => manager.handleEngineError(any())).called(1);
        verify(() => manager.stop()).called(1);
      },
    );

    test('an empty result does not re-arm it', () async {
      await notifier().start();
      onError!(error);
      await settle();

      onResult!(_result('   ', isFinal: false));
      onError!(error);
      await settle();

      expect(state(), isA<StoppedState>());
      verify(() => manager.handleEngineError(any())).called(1);
    });

    test(
      'a second error after a non-empty result gets its own recovery',
      () async {
        await notifier().start();
        onError!(error);
        await settle();

        onResult!(_result('words'));
        onError!(error);
        await settle();

        expect(state(), isA<RecordingActiveState>(), reason: 'recovered again');
        verify(() => manager.handleEngineError(any())).called(2);
        verifyNever(() => manager.stop());
      },
    );

    test('the result must follow a recovery: one before the first error does '
        'not pre-arm a second', () async {
      await notifier().start();
      onResult!(_result('before any error'));
      onError!(error);
      await settle();
      onError!(error);
      await settle();

      expect(state(), isA<StoppedState>());
      verify(() => manager.handleEngineError(any())).called(1);
    });

    test('start() still resets the flag for a new session', () async {
      await notifier().start();
      onError!(error);
      await settle();
      await notifier().stop();
      notifier().clearSession();

      await notifier().start();
      onError!(error);
      await settle();

      expect(state(), isA<RecordingActiveState>(), reason: 'fresh recovery');
      verify(() => manager.handleEngineError(any())).called(2);
    });
  });

  group('BR-U10-58 Stop is bounded (TP-37)', () {
    Future<void> hang() => Completer<void>().future;

    test('an engine stop that never completes: Stopped at the bound, once, '
        'and the outcome is saveFailed', () async {
      var finalised = 0;
      container.read(sessionStopCallbackProvider).callback = () async {
        finalised++;
      };
      await notifier().start();
      events.clear();
      when(() => manager.stop()).thenAnswer((_) => hang());
      final watch = Stopwatch()..start();

      await notifier().stop();
      await settle();

      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(55));
      expect(watch.elapsedMilliseconds, lessThan(1000));
      expect(state(), isA<StoppedState>());
      expect(events.where((e) => e == 'state:stopped'), hasLength(1));
      verify(() => wakeLock.release()).called(1);
      expect(
        container.read(transcriptSaveOutcomeProvider),
        TranscriptSaveResult.saveFailed,
      );
      expect(finalised, 0, reason: 'the engine stop never let it start');
    });

    test('a finalise that never completes: Stopped at the bound, once, and '
        'the outcome is saveFailed', () async {
      container.read(sessionStopCallbackProvider).callback = hang;
      await notifier().start();
      events.clear();

      await notifier().stop();
      await settle();

      expect(state(), isA<StoppedState>());
      expect(events.where((e) => e == 'state:stopped'), hasLength(1));
      verify(() => wakeLock.release()).called(1);
      expect(
        container.read(transcriptSaveOutcomeProvider),
        TranscriptSaveResult.saveFailed,
      );
    });

    test('a hung stop with no transcript writer registered leaves the '
        'outcome alone', () async {
      await notifier().start();
      when(() => manager.stop()).thenAnswer((_) => hang());

      await notifier().stop();

      expect(state(), isA<StoppedState>());
      expect(container.read(transcriptSaveOutcomeProvider), isNull);
    });

    test('both completing in time: no timeout, the outcome is as the '
        'finaliser set it', () async {
      container.read(sessionStopCallbackProvider).callback = () async {
        container.read(transcriptSaveOutcomeProvider.notifier).outcome =
            TranscriptSaveResult.saved;
      };
      await notifier().start();

      await notifier().stop();

      expect(state(), isA<StoppedState>());
      expect(
        container.read(transcriptSaveOutcomeProvider),
        TranscriptSaveResult.saved,
      );
    });

    test(
      'the abandoned finalise completing later changes nothing here',
      () async {
        final lateDone = Completer<void>();
        container.read(sessionStopCallbackProvider).callback = () =>
            lateDone.future;
        await notifier().start();

        await notifier().stop();
        lateDone.complete();
        await settle();

        expect(state(), isA<StoppedState>());
        verify(() => wakeLock.release()).called(1);
      },
    );
  });

  group(
    'BR-U10-61 a throwing engine stop never strands the session (TP-40)',
    () {
      test('an Error from the engine stop still ends in Stopped once, with one '
          'event, one release and the finalise attempted', () async {
        var finalised = 0;
        container.read(sessionStopCallbackProvider).callback = () async {
          finalised++;
        };
        await notifier().start();
        events.clear();
        when(() => manager.stop()).thenThrow(StateError('platform exploded'));

        await notifier().stop();
        await settle();

        expect(state(), isA<StoppedState>());
        expect(events.where((e) => e == 'state:stopped'), hasLength(1));
        verify(() => wakeLock.release()).called(1);
        expect(finalised, 1);
      });

      test(
        'an Error from an asynchronous engine stop is handled the same',
        () async {
          await notifier().start();
          when(() => manager.stop()).thenAnswer((_) async {
            throw StateError('platform exploded');
          });

          await notifier().stop();

          expect(state(), isA<StoppedState>());
          verify(() => wakeLock.release()).called(1);
        },
      );

      test('a later stop() completes normally', () async {
        await notifier().start();
        when(() => manager.stop()).thenThrow(StateError('platform exploded'));
        await notifier().stop();

        await notifier().stop();

        expect(state(), isA<StoppedState>());
      });
    },
  );

  group('BR-U10-62 results during a start or a resume are kept (TP-39)', () {
    test('results delivered while startListening is pending reach the bus '
        'once, in order, after the Recording state', () async {
      final gate = Completer<bool>();
      when(() => manager.startListening()).thenAnswer((_) => gate.future);

      final starting = notifier().start();
      await settle();
      onResult!(_result('one', isFinal: false));
      onResult!(_result('two'));
      await settle();
      expect(events, isEmpty, reason: 'held, not published');

      gate.complete(true);
      await starting;
      await settle();

      expect(events, ['state:recording', 'result:one', 'result:two']);
      expect(
        (state() as RecordingActiveState).currentSegment,
        isEmpty,
        reason: 'the final result cleared the segment',
      );
    });

    test('they are dropped when the start fails', () async {
      final gate = Completer<bool>();
      when(() => manager.startListening()).thenAnswer((_) => gate.future);

      final starting = notifier().start();
      await settle();
      onResult!(_result('lost'));
      gate.complete(false);
      await starting;
      await settle();

      expect(events, isEmpty);
      expect(state(), isA<IdleState>());

      // And they do not leak into the next, successful start.
      when(() => manager.startListening()).thenAnswer((_) async => true);
      await notifier().start();
      await settle();
      expect(events, ['state:recording']);
    });

    test(
      'they are dropped when an error was captured during the start',
      () async {
        final gate = Completer<bool>();
        when(() => manager.startListening()).thenAnswer((_) => gate.future);

        final starting = notifier().start();
        await settle();
        onResult!(_result('lost'));
        onError!(RecordingErrorFactories.engineStartFailed());
        gate.complete(true);
        await starting;
        await settle();

        expect(events, isEmpty);
        expect(state(), isA<IdleState>());
      },
    );

    test('results delivered while resume is pending reach the bus once, in '
        'order, after the Recording state', () async {
      await notifier().start();
      await notifier().pause();
      events.clear();
      final gate = Completer<bool>();
      when(() => manager.resume()).thenAnswer((_) => gate.future);

      final resuming = notifier().resume();
      await settle();
      onResult!(_result('one'));
      onResult!(_result('two'));
      await settle();
      expect(events, isEmpty);

      gate.complete(true);
      await resuming;
      await settle();

      expect(events, ['state:recording', 'result:one', 'result:two']);
    });

    test('they are dropped when a stop lands first', () async {
      await notifier().start();
      await notifier().pause();
      events.clear();
      final gate = Completer<bool>();
      when(() => manager.resume()).thenAnswer((_) => gate.future);

      final resuming = notifier().resume();
      await settle();
      onResult!(_result('lost'));
      await notifier().stop();
      gate.complete(true);
      await resuming;
      await settle();

      expect(events, ['state:stopped']);
    });

    test('they are dropped when the resume is refused with an error', () async {
      await notifier().start();
      await notifier().pause();
      events.clear();
      final gate = Completer<bool>();
      when(() => manager.resume()).thenAnswer((_) => gate.future);

      final resuming = notifier().resume();
      await settle();
      onResult!(_result('lost'));
      onError!(RecordingErrorFactories.engineStartFailed());
      gate.complete(false);
      await resuming;
      await settle();

      expect(events, ['state:stopped']);
    });

    test('no log record holds their text', () async {
      final records = <LogRecord>[];
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);
      final gate = Completer<bool>();
      when(() => manager.startListening()).thenAnswer((_) => gate.future);

      final starting = notifier().start();
      await settle();
      onResult!(_result('SECRETPHRASE'));
      gate.complete(true);
      await starting;
      await settle();

      expect(events, contains('result:SECRETPHRASE'));
      for (final r in records) {
        expect(r.message, isNot(contains('SECRETPHRASE')));
        expect(r.error?.toString() ?? '', isNot(contains('SECRETPHRASE')));
      }
    });
  });

  group('BR-U10-63 a throwing pause keeps the session usable (TP-41)', () {
    test('an Error from the engine pause leaves the session Recording with '
        'the inactivity timer armed', () async {
      container.dispose();
      build(inactivity: const Duration(milliseconds: 60));
      await notifier().start();
      when(() => manager.pause()).thenThrow(StateError('platform exploded'));

      await notifier().pause();

      expect(state(), isA<RecordingActiveState>());
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(state(), isA<StoppedState>(), reason: 'the timer was armed');
      expect(
        container.read(sessionStopReasonNotifierProvider),
        SessionStopReason.inactivity,
      );
    });

    test(
      'a pause on an old session cannot arm a timer for the new one',
      () async {
        container.dispose();
        build(inactivity: const Duration(milliseconds: 80));
        await notifier().start();
        final oldId = (state() as RecordingActiveState).sessionId;
        final gate = Completer<bool>();
        when(() => manager.pause()).thenAnswer((_) => gate.future);

        final pausing = notifier().pause();
        await notifier().stop();
        notifier().clearSession();
        await notifier().start();
        final newId = (state() as RecordingActiveState).sessionId;
        expect(newId, isNot(oldId));

        gate.completeError(StateError('platform exploded'));
        await pausing;
        await Future<void>.delayed(const Duration(milliseconds: 250));

        // The new session's own timer fired, not one armed for the old id.
        expect((state() as StoppedState).sessionId, newId);
      },
    );

    test('a throwing pause after a stop does not arm anything', () async {
      container.dispose();
      build(inactivity: const Duration(milliseconds: 60));
      await notifier().start();
      final gate = Completer<bool>();
      when(() => manager.pause()).thenAnswer((_) => gate.future);

      final pausing = notifier().pause();
      await notifier().stop();
      gate.completeError(StateError('platform exploded'));
      await pausing;
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(state(), isA<StoppedState>());
      expect(
        container.read(sessionStopReasonNotifierProvider),
        isNull,
        reason: 'no inactivity stop ran',
      );
    });
  });
}
