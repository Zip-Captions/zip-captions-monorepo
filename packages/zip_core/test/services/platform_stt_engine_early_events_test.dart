// Review fix F3 (Unit 10): events the plugin delivers while the first start
// or a resume `listen()` is still in flight must not be lost (Amendment 01,
// BR-U10-15 to 19), and a stop that lands in that window still wins.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/stt/engines/platform_stt_engine.dart';
import 'package:zip_core/src/stt/stt_error_source.dart';

import '../helpers/fake_on_device_checker.dart';
import '../helpers/fake_speech_to_text.dart';
import '../helpers/mock_audio_device_service.dart';

void main() {
  late CallLog log;
  late FakeSpeechToText stt;
  late FakeOnDeviceChecker checker;
  late PlatformSttEngine engine;
  late List<SttEngineError> errors;

  setUp(() {
    log = CallLog();
    stt = FakeSpeechToText(log);
    checker = FakeOnDeviceChecker(log);
    final audio = MockAudioDeviceService();
    when(() => audio.currentPreferredDeviceId).thenReturn(null);
    engine = PlatformSttEngine(
      stt: stt,
      deviceService: audio,
      onDeviceSupportChecker: checker.call,
    );
    errors = [];
    engine.setErrorListener(errors.add);
  });

  tearDown(() => engine.dispose());

  /// Starts with `listen()` held open and returns the gate and a result box.
  ({Completer<void> gate, List<bool> started}) startHeld(FakeAsync async) {
    final gate = Completer<void>();
    stt.listenGate = gate.future;
    final started = <bool>[];
    unawaited(
      engine
          .initialize()
          .then(
            (_) => engine.startListening(localeId: 'en-US', onResult: (_) {}),
          )
          .then(started.add),
    );
    async.flushMicrotasks();
    expect(stt.listenCalls, hasLength(1), reason: 'listen() is in flight');
    return (gate: gate, started: started);
  }

  test(
    'F3: a lasting error before listen() returns is reported exactly once',
    () {
      fakeAsync((async) {
        final held = startHeld(async);

        stt.emitError('error_language_unavailable');
        held.gate.complete();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 5));

        expect(held.started, [true]);
        expect(errors, [
          const SttEngineError(SttEngineErrorKind.onDeviceModelMissing),
        ]);
        expect(stt.listenCalls, hasLength(1), reason: 'no restart after it');
      });
    },
  );

  test(
    'F3: done before listen() returns causes exactly one checked restart',
    () {
      fakeAsync((async) {
        final held = startHeld(async);

        stt.emitStatus('done');
        held.gate.complete();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 1));

        expect(held.started, [true]);
        expect(stt.listenCalls, hasLength(2));
        expect(checker.localesChecked, ['en-US', 'en-US']);
        expect(
          log.entries.sublist(log.entries.length - 2),
          ['check:en-US:true', 'listen'],
          reason: 'the restart is checked first',
        );
        expect(errors, isEmpty);

        async.elapse(const Duration(seconds: 5));
        expect(stt.listenCalls, hasLength(2), reason: 'exactly one restart');
      });
    },
  );

  test('F3: a stop during listen() wins: no restart and no error', () {
    fakeAsync((async) {
      final held = startHeld(async);

      unawaited(engine.stopListening());
      async.flushMicrotasks();
      stt
        ..emitError('error_language_unavailable')
        ..emitStatus('done');
      held.gate.complete();
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 5));

      expect(held.started, [false]);
      expect(stt.listenCalls, hasLength(1));
      expect(errors, isEmpty);
    });
  });

  test(
    'F3: a lasting error before a resume listen() returns is reported once',
    () {
      fakeAsync((async) {
        unawaited(
          engine.initialize().then(
            (_) => engine.startListening(
              localeId: 'en-US',
              onResult: (_) {},
            ),
          ),
        );
        async.flushMicrotasks();
        unawaited(engine.pause());
        async.flushMicrotasks();

        final gate = Completer<void>();
        stt.listenGate = gate.future;
        var resumed = false;
        unawaited(engine.resume().then((ok) => resumed = ok));
        async.flushMicrotasks();
        expect(stt.listenCalls, hasLength(2), reason: 'resume is in flight');

        stt.emitError('error_language_unavailable');
        gate.complete();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 5));

        expect(resumed, isTrue);
        expect(errors, [
          const SttEngineError(SttEngineErrorKind.onDeviceModelMissing),
        ]);
        expect(stt.listenCalls, hasLength(2));
      });
    },
  );

  test('F3: a pause during listen() wins too', () {
    fakeAsync((async) {
      final held = startHeld(async);

      unawaited(engine.pause());
      async.flushMicrotasks();
      stt.emitStatus('done');
      held.gate.complete();
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 5));
      expect(held.started, [false]);
      expect(stt.listenCalls, hasLength(1), reason: 'no restart while paused');
    });
  });
}
