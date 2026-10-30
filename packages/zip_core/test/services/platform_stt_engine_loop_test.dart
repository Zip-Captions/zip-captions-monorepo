import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:zip_core/src/constants/stt_listening_limits.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/stt/engines/platform_stt_engine.dart';
import 'package:zip_core/src/stt/stt_error_source.dart';

import '../helpers/call_log.dart';
import '../helpers/fake_on_device_checker.dart';
import '../helpers/fake_speech_to_text.dart';
import '../helpers/mock_audio_device_service.dart';

/// Example pins for the engine's continuous-listening loop (Unit 10,
/// Amendment 01 section 4). The stateful models are in
/// `test/pbt/platform_stt_engine_properties_test.dart`.
class _Harness {
  _Harness(this.async, {SttListeningLimits? limits}) {
    final audio = MockAudioDeviceService();
    when(() => audio.currentPreferredDeviceId).thenReturn(null);
    final clock = async.getClock(DateTime(2026));
    engine = PlatformSttEngine(
      stt: stt,
      deviceService: audio,
      onDeviceSupportChecker: checker.call,
      limits: limits ?? defaultSttListeningLimits,
      now: clock.now,
    )..setErrorListener(errors.add);
  }

  final FakeAsync async;
  final log = CallLog();
  late final FakeSpeechToText stt = FakeSpeechToText(log);
  late final FakeOnDeviceChecker checker = FakeOnDeviceChecker(log);
  late final PlatformSttEngine engine;
  final errors = <SttEngineError>[];
  final results = <SttResult>[];

  Duration get restartDelay => defaultSttListeningLimits.restartDelay;

  /// Completes [future] under fake time. A stop or a pause of a live session
  /// waits out the BR-U10-55 drain (nothing arrives from the fake plugin), so
  /// those pass [drained] to let the deadline pass.
  T await_<T>(Future<T> future, {bool drained = false}) {
    T? value;
    var done = false;
    unawaited(
      future.then((v) {
        value = v;
        done = true;
      }),
    );
    async.flushMicrotasks();
    if (drained) {
      async
        ..elapse(defaultSttListeningLimits.finalResultDrainTimeout)
        ..flushMicrotasks();
    }
    expect(done, isTrue, reason: 'future should complete without real time');
    return value as T;
  }

  void start({String locale = 'en-US'}) {
    expect(await_(engine.initialize()), isTrue);
    expect(
      await_(
        engine.startListening(localeId: locale, onResult: results.add),
      ),
      isTrue,
    );
  }

  /// Lets the restart timer fire and the restart's async work finish.
  void settle() {
    async
      ..elapse(restartDelay + const Duration(milliseconds: 1))
      ..flushMicrotasks();
  }

  /// A normal session end: the plugin reports `notListening` then `done`.
  void sessionEnds({Duration after = const Duration(seconds: 5)}) {
    async.elapse(after);
    stt
      ..emitStatus('notListening')
      ..emitStatus('done');
    async.flushMicrotasks();
  }

  int get listens => stt.listenCalls.length;
}

void main() {
  void scenario(String name, void Function(_Harness h) body) {
    test(name, () {
      fakeAsync((async) => body(_Harness(async)));
    });
  }

  group('restart on a normal session end', () {
    scenario('the iOS one-minute end restarts with no error', (h) {
      h.start();
      expect(h.listens, 1);
      h
        ..sessionEnds(after: const Duration(seconds: 60))
        ..settle();
      expect(h.listens, 2);
      expect(h.errors, isEmpty);
      // The restart went through the on-device check again (BR-U10-26).
      expect(h.checker.localesChecked, ['en-US', 'en-US']);
    });

    scenario('the Android pause-end (speech timeout) restarts with no error', (
      h,
    ) {
      h.start();
      h.stt.emitError('error_speech_timeout');
      h
        ..sessionEnds()
        ..settle();
      expect(h.listens, 2);
      expect(h.errors, isEmpty);
    });

    scenario('a restart reuses the locale and the result callback', (h) {
      h
        ..start(locale: 'fr-FR')
        ..sessionEnds()
        ..settle();
      expect(h.stt.listenCalls.last.localeId, 'fr-FR');
      h.stt.emitResult('bonjour', isFinal: true);
      expect(h.results.single.text, 'bonjour');
    });
  });

  group('restart on done only, once per session end', () {
    scenario('an error or notListening alone never restarts', (h) {
      h.start();
      h.stt
        ..emitError('error_busy')
        ..emitStatus('notListening');
      h.async.elapse(const Duration(seconds: 10));
      h.async.flushMicrotasks();
      expect(h.listens, 1);

      h.stt.emitStatus('done');
      h.settle();
      expect(h.listens, 2);
    });

    scenario('an error followed by done restarts exactly once', (h) {
      h.start();
      h.stt
        ..emitError('error_speech_timeout')
        ..emitStatus('notListening')
        ..emitStatus('done')
        // A duplicate done for the same session must not restart again.
        ..emitStatus('done');
      h.settle();
      expect(h.listens, 2);
    });
  });

  group('the failure budget (restartCap = 3, increment then compare)', () {
    scenario('many silence ends in a row do not trip the cap', (h) {
      h.start();
      for (var i = 0; i < 10; i++) {
        h.stt.emitError(i.isEven ? 'error_no_match' : 'error_speech_timeout');
        // Silent sessions are short, and still never count.
        h
          ..sessionEnds(after: const Duration(milliseconds: 500))
          ..settle();
      }
      expect(h.listens, 11);
      expect(h.errors, isEmpty);
    });

    scenario('permanent: true on a silence code is still silence', (h) {
      // The fake always sets permanent: true, as the real plugin does.
      h.start();
      for (var i = 0; i < 5; i++) {
        h.stt.emitError('error_no_match');
        h
          ..sessionEnds(after: const Duration(milliseconds: 100))
          ..settle();
      }
      expect(h.errors, isEmpty);
      expect(h.listens, 6);
    });

    scenario('a run of transient errors reports restartCapReached exactly once '
        'on the third counted failure', (h) {
      h.start();
      // Failure 1 and 2: restart.
      for (var i = 0; i < 2; i++) {
        h.stt.emitError('error_busy');
        h
          ..sessionEnds()
          ..settle();
        expect(h.errors, isEmpty, reason: 'failure ${i + 1} is below the cap');
      }
      expect(h.listens, 3);

      // Failure 3: the cap is reached.
      h.stt.emitError('error_client');
      h
        ..sessionEnds()
        ..settle();
      expect(
        h.errors,
        [const SttEngineError(SttEngineErrorKind.restartCapReached)],
      );
      expect(h.listens, 3, reason: 'no listen() once the cap is reached');

      // Nothing more happens until the next start.
      h
        ..sessionEnds()
        ..settle();
      expect(h.listens, 3);
      expect(h.errors, hasLength(1));
    });

    scenario('a fast end with no result and no silence code counts', (h) {
      h.start();
      // done at once, nothing said, no error: counts as immediate failure.
      for (var i = 0; i < 2; i++) {
        h
          ..sessionEnds(after: const Duration(milliseconds: 100))
          ..settle();
      }
      expect(h.errors, isEmpty);
      h.sessionEnds(after: const Duration(milliseconds: 100));
      expect(h.errors, hasLength(1));
      expect(h.errors.single.kind, SttEngineErrorKind.restartCapReached);
    });

    scenario(
      'a quiet session that lasts longer than the window does not count',
      (h) {
        h.start();
        for (var i = 0; i < 6; i++) {
          h
            ..sessionEnds()
            ..settle();
        }
        expect(h.errors, isEmpty);
        expect(h.listens, 7);
      },
    );

    scenario('a delivered result resets the count', (h) {
      h.start();
      // Two failures.
      for (var i = 0; i < 2; i++) {
        h.stt.emitError('error_busy');
        h
          ..sessionEnds()
          ..settle();
      }
      // A session with a result resets the count.
      h.stt.emitResult('hello there', isFinal: true);
      h
        ..sessionEnds()
        ..settle();
      // Two more failures are still below the cap.
      for (var i = 0; i < 2; i++) {
        h.stt.emitError('error_busy');
        h
          ..sessionEnds()
          ..settle();
      }
      expect(h.errors, isEmpty);
    });
  });

  group('lasting errors report once and stop restarting', () {
    const cases = <String, SttEngineErrorKind>{
      'error_permission': SttEngineErrorKind.permissionRevoked,
      'error_language_unavailable': SttEngineErrorKind.onDeviceModelMissing,
      'error_language_not_supported': SttEngineErrorKind.localeUnsupported,
      // iOS codes read from the locked plugin source (R5 extension).
      'error_speech_recognizer_request_not_authorized':
          SttEngineErrorKind.permissionRevoked,
      'error_assets_not_installed': SttEngineErrorKind.onDeviceModelMissing,
      'error_speech_recognizer_disabled':
          SttEngineErrorKind.recognizerUnavailable,
    };
    for (final entry in cases.entries) {
      scenario('${entry.key} -> ${entry.value.name}', (h) {
        h.start();
        h.stt.emitError(entry.key);
        expect(h.errors, [SttEngineError(entry.value)]);

        // The trailing done restarts nothing, and no second error follows.
        h
          ..sessionEnds()
          ..settle();
        expect(h.listens, 1);
        expect(h.errors, hasLength(1));
      });
    }

    scenario('an unrecognised code is transient (restarts, counts)', (h) {
      h.start();
      h.stt.emitError('error_unknown (7)');
      h
        ..sessionEnds()
        ..settle();
      expect(h.errors, isEmpty);
      expect(h.listens, 2);
    });
  });

  group('the final-first flush (BR-U10-16)', () {
    scenario('a pending interim is delivered once as final on done, not on '
        'notListening', (h) {
      h.start();
      h.stt.emitResult('hello wor', isFinal: false);
      h.stt.emitStatus('notListening');
      expect(
        h.results.where((r) => r.isFinal),
        isEmpty,
        reason: 'notListening must not flush',
      );

      h.stt.emitStatus('done');
      final finals = h.results.where((r) => r.isFinal).toList();
      expect(finals, hasLength(1));
      expect(finals.single.text, 'hello wor');

      // A duplicate done does not deliver it again.
      h.stt.emitStatus('done');
      expect(h.results.where((r) => r.isFinal), hasLength(1));
    });

    scenario('nothing is flushed when the plugin already sent a final', (h) {
      h.start();
      h.stt
        ..emitResult('hello', isFinal: false)
        ..emitResult('hello world', isFinal: true)
        ..emitStatus('done');
      expect(h.results.where((r) => r.isFinal), hasLength(1));
      expect(h.results.last.text, 'hello world');
    });

    scenario('the flush happens before the next listen()', (h) {
      h.start();
      h.stt
        ..emitResult('partial', isFinal: false)
        ..emitStatus('done');
      var finalDelivered = false;
      // The restart has not started yet when the flush has been delivered.
      finalDelivered = h.results.any((r) => r.isFinal);
      expect(finalDelivered, isTrue);
      expect(h.listens, 1);
      h.settle();
      expect(h.listens, 2);
    });
  });

  group('stop, pause and dispose win', () {
    scenario('stop cancels a pending restart', (h) {
      h.start();
      h.stt.emitStatus('done');
      // The restart timer is pending; the user stops before it fires.
      h
        ..await_(h.engine.stopListening())
        ..settle();
      expect(h.listens, 1);
    });

    scenario('the trailing done after stop never restarts', (h) {
      h
        ..start()
        ..await_(h.engine.stopListening(), drained: true);
      h.stt
        ..emitStatus('notListening')
        ..emitStatus('done');
      h.settle();
      expect(h.listens, 1);
    });

    scenario(
      'pause cancels a pending restart; resume listens again (checked)',
      (h) {
        h.start();
        h.stt.emitStatus('done');
        expect(h.await_(h.engine.pause()), isTrue);
        h.settle();
        expect(h.listens, 1, reason: 'a paused engine does not restart');

        expect(h.await_(h.engine.resume()), isTrue);
        expect(h.listens, 2);
        expect(h.checker.localesChecked, hasLength(2));
      },
    );

    scenario('dispose cancels the timer and clears the plugin listeners', (h) {
      h.start();
      h.stt.emitStatus('done');
      h.engine.dispose();
      h.settle();
      expect(h.listens, 1);
      expect(h.stt.statusListener, isNull);
      expect(h.stt.errorListener, isNull);
    });
  });

  group('a listen() that throws during a restart', () {
    scenario('is a transient session end; the retry is checked again first', (
      h,
    ) {
      h.start();
      // The restart's listen() throws; no done will follow, so the engine
      // itself schedules another attempt.
      h.stt.listenOutcomes.add(ListenFailedException('whatever'));
      h
        ..sessionEnds()
        ..settle();
      expect(h.stt.cancelCalls, 1, reason: 'cancelled at once');
      expect(h.errors, isEmpty);

      h.settle();
      expect(h.listens, 3, reason: 'the retry listened again');
      // Every listen() (including the retry) was preceded by a true check.
      final entries = h.log.entries;
      for (var i = 0; i < entries.length; i++) {
        if (entries[i] == 'listen') {
          expect(entries[i - 1], startsWith('check:en-US:true'));
        }
      }
    });

    scenario(
      'if on-device support has gone, the retry is the lasting refusal',
      (h) {
        h.start();
        h.stt.listenOutcomes.add(ListenFailedException('x'));
        h
          ..sessionEnds()
          ..settle();
        // The device lost on-device support before the retry.
        h.checker.script.add(false);
        h.settle();
        expect(
          h.errors,
          [const SttEngineError(SttEngineErrorKind.onDeviceModelMissing)],
        );
        final listensAtRefusal = h.listens;
        h.settle();
        expect(
          h.listens,
          listensAtRefusal,
          reason: 'no listen() after refusal',
        );
        expect(h.errors, hasLength(1));
      },
    );

    scenario('a false check on a normal restart is one lasting error, then '
        'failed', (h) {
      h.start();
      h.checker.script.add(false);
      h
        ..sessionEnds()
        ..settle();
      expect(
        h.errors,
        [const SttEngineError(SttEngineErrorKind.onDeviceModelMissing)],
      );
      expect(h.listens, 1);
      h
        ..sessionEnds()
        ..settle();
      expect(h.listens, 1);
      expect(h.errors, hasLength(1));
    });
  });
}
