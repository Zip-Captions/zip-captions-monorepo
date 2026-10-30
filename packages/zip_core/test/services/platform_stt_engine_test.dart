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
import '../helpers/mock_speech_to_text.dart';
import '../helpers/pbt.dart' as pbt;

void main() {
  late MockSpeechToText mockStt;
  late MockAudioDeviceService mockAudioService;
  late PlatformSttEngine engine;

  setUp(() {
    mockStt = MockSpeechToText();
    mockAudioService = MockAudioDeviceService();
    engine = PlatformSttEngine(
      stt: mockStt,
      deviceService: mockAudioService,
      onDeviceSupportChecker: FakeOnDeviceChecker().call,
    );
  });

  group('PlatformSttEngine', () {
    test('engineId is "platform"', () {
      expect(engine.engineId, 'platform');
    });

    test('displayName is human-readable', () {
      expect(engine.displayName, isNotEmpty);
    });

    test('requiresNetwork is false', () {
      expect(engine.requiresNetwork, isFalse);
    });

    test('requiresDownload is false', () {
      expect(engine.requiresDownload, isFalse);
    });

    group('initialize', () {
      test('returns true when SpeechToText initializes', () async {
        when(() => mockStt.initialize()).thenAnswer((_) async => true);

        final ok = await engine.initialize();
        expect(ok, isTrue);
        verify(() => mockStt.initialize()).called(1);
      });

      test('returns false when SpeechToText fails', () async {
        when(() => mockStt.initialize()).thenAnswer((_) async => false);

        final ok = await engine.initialize();
        expect(ok, isFalse);
      });
    });

    group('isAvailable', () {
      test('delegates to SpeechToText', () async {
        when(() => mockStt.initialize()).thenAnswer((_) async => true);
        when(() => mockStt.isAvailable).thenReturn(true);
        await engine.initialize();

        expect(await engine.isAvailable(), isTrue);
        verify(() => mockStt.isAvailable).called(1);
      });
    });

    group('supportedLocales', () {
      test('returns locales from SpeechToText', () async {
        when(() => mockStt.initialize()).thenAnswer((_) async => true);
        when(() => mockStt.locales()).thenAnswer(
          (_) async => [
            LocaleName('en_US', 'English (US)'),
            LocaleName('fr_FR', 'French'),
          ],
        );
        await engine.initialize();

        final locales = await engine.supportedLocales();
        expect(locales, hasLength(2));
        expect(locales.first.localeId, 'en_US');
      });
    });

    group('startListening', () {
      test('sets preferred device before starting', () async {
        when(() => mockStt.initialize()).thenAnswer((_) async => true);
        when(
          () => mockStt.listen(
            onResult: any(named: 'onResult'),
            localeId: any(named: 'localeId'),
            listenOptions: any(named: 'listenOptions'),
          ),
        ).thenAnswer((_) async {});
        when(() => mockAudioService.currentPreferredDeviceId).thenReturn(null);

        await engine.initialize();
        final results = <SttResult>[];
        final ok = await engine.startListening(
          localeId: 'en-US',
          onResult: results.add,
        );

        expect(ok, isTrue);
      });
    });

    group('dispose', () {
      test('cancels SpeechToText', () async {
        when(() => mockStt.initialize()).thenAnswer((_) async => true);
        when(() => mockStt.cancel()).thenAnswer((_) async {});

        await engine.initialize();
        engine.dispose();

        verify(() => mockStt.cancel()).called(1);
      });
    });
  });

  // ---- Amendment 06: BR-U10-55 the last phrase is drained (TP-34) ---------

  group('PlatformSttEngine drain (BR-U10-55, TP-34)', () {
    final production = defaultSttListeningLimits.finalResultDrainTimeout;

    /// An engine with a started session, inside the fake-async zone.
    ({
      PlatformSttEngine engine,
      FakeSpeechToText stt,
      List<SttResult> results,
      List<SttEngineError> errors,
    })
    live(FakeAsync async) {
      final stt = FakeSpeechToText();
      final audio = MockAudioDeviceService();
      when(() => audio.currentPreferredDeviceId).thenReturn(null);
      final engine = PlatformSttEngine(
        stt: stt,
        deviceService: audio,
        onDeviceSupportChecker: FakeOnDeviceChecker().call,
      );
      final results = <SttResult>[];
      final errors = <SttEngineError>[];
      engine.setErrorListener(errors.add);
      unawaited(engine.initialize());
      async.flushMicrotasks();
      unawaited(
        engine.startListening(localeId: 'en-US', onResult: results.add),
      );
      async.flushMicrotasks();
      return (engine: engine, stt: stt, results: results, errors: errors);
    }

    for (final pause in [false, true]) {
      final name = pause ? 'pause' : 'stop';

      test('a final result after $name() is delivered once, before the call '
          'returns, and nothing restarts', () {
        fakeAsync((async) {
          final rig = live(async);
          addTearDown(rig.engine.dispose);
          final order = <String>[];

          unawaited(
            (pause ? rig.engine.pause() : rig.engine.stopListening()).then(
              (_) => order.add('returned'),
            ),
          );
          async.flushMicrotasks();
          expect(order, isEmpty, reason: 'waiting for the last phrase');
          rig.stt.emitResult('the last phrase', isFinal: true);
          async.flushMicrotasks();
          order.add('after');

          expect(rig.results.map((r) => r.text), ['the last phrase']);
          expect(rig.results.map((r) => r.isFinal), [true]);
          expect(order, ['returned', 'after']);
          expect(rig.stt.stopCalls, 1);
          // Stop cancels the plugin after the wait; pause leaves it stopped.
          expect(rig.stt.cancelCalls, pause ? 0 : 1);
          async.elapse(const Duration(seconds: 5));
          expect(rig.stt.listenCalls, hasLength(1), reason: 'no restart');
        });
      });

      test('a result after the $name() deadline is never delivered', () {
        fakeAsync((async) {
          final rig = live(async);
          addTearDown(rig.engine.dispose);
          var returned = false;

          unawaited(
            (pause ? rig.engine.pause() : rig.engine.stopListening()).then(
              (_) => returned = true,
            ),
          );
          async.elapse(production - const Duration(milliseconds: 1));
          expect(returned, isFalse, reason: 'still inside the window');
          async.elapse(const Duration(milliseconds: 2));
          expect(returned, isTrue);

          rig.stt.emitResult('too late', isFinal: true);
          rig.stt.emitResult('too late', isFinal: false);
          async.elapse(const Duration(seconds: 5));
          expect(rig.results, isEmpty);
        });
      });

      test('a pending interim with no final is delivered once as final at '
          'the end of the $name() wait', () {
        fakeAsync((async) {
          final rig = live(async);
          addTearDown(rig.engine.dispose);
          rig.stt.emitResult('almost there', isFinal: false);
          async.flushMicrotasks();

          unawaited(pause ? rig.engine.pause() : rig.engine.stopListening());
          async.elapse(production + const Duration(milliseconds: 1));

          expect(
            rig.results.map((r) => r.text),
            ['almost there', 'almost there'],
          );
          expect(rig.results.map((r) => r.isFinal), [false, true]);
        });
      });

      test('the status done ends the $name() wait early, flushes the interim '
          'and restarts nothing', () {
        fakeAsync((async) {
          final rig = live(async);
          addTearDown(rig.engine.dispose);
          rig.stt.emitResult('tail', isFinal: false);
          async.flushMicrotasks();
          var returned = false;

          unawaited(
            (pause ? rig.engine.pause() : rig.engine.stopListening()).then(
              (_) => returned = true,
            ),
          );
          async.flushMicrotasks();
          rig.stt.emitStatus('done');
          async.flushMicrotasks();

          expect(returned, isTrue, reason: 'no need to wait the full second');
          expect(rig.results.map((r) => r.isFinal), [false, true]);
          async.elapse(const Duration(seconds: 10));
          expect(rig.stt.listenCalls, hasLength(1));
          expect(rig.errors, isEmpty);
        });
      });

      test('an error ends the $name() wait early and reports, counts and '
          'restarts nothing', () {
        fakeAsync((async) {
          final rig = live(async);
          addTearDown(rig.engine.dispose);
          var returned = false;

          unawaited(
            (pause ? rig.engine.pause() : rig.engine.stopListening()).then(
              (_) => returned = true,
            ),
          );
          async.flushMicrotasks();
          rig.stt.emitError('error_permission');
          async.flushMicrotasks();

          expect(returned, isTrue);
          async.elapse(const Duration(seconds: 10));
          expect(rig.stt.listenCalls, hasLength(1));
          expect(rig.errors, isEmpty);
        });
      });
    }

    test('only the first final result of a drain is delivered', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        unawaited(rig.engine.stopListening());
        async.flushMicrotasks();
        rig.stt
          ..emitResult('first', isFinal: true)
          ..emitResult('second', isFinal: true);
        async.elapse(const Duration(seconds: 2));

        expect(rig.results.map((r) => r.text), ['first']);
      });
    });

    test('a stop whose plugin call returns after a new start does not '
        'cancel the new session (Amendment 06 revision 3)', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);
        final stalled = Completer<void>();
        rig.stt.stopGate = stalled.future;

        unawaited(rig.engine.stopListening());
        async.flushMicrotasks();
        // The user starts again while the stop is stuck in the plugin.
        unawaited(
          rig.engine.startListening(localeId: 'en-US', onResult: (_) {}),
        );
        async.flushMicrotasks();
        expect(rig.stt.listenCalls, hasLength(2));
        final cancelsBefore = rig.stt.cancelCalls;

        stalled.complete();
        async.elapse(const Duration(seconds: 2));

        expect(
          rig.stt.cancelCalls,
          cancelsBefore,
          reason: 'the late cancel would end the new session',
        );
      });
    });

    test('a stop with no live session does not wait', () {
      fakeAsync((async) {
        final stt = FakeSpeechToText();
        final audio = MockAudioDeviceService();
        final engine = PlatformSttEngine(
          stt: stt,
          deviceService: audio,
          onDeviceSupportChecker: FakeOnDeviceChecker().call,
        );
        addTearDown(engine.dispose);
        var returned = false;

        unawaited(engine.stopListening().then((_) => returned = true));
        async.flushMicrotasks();

        expect(returned, isTrue);
        expect(stt.cancelCalls, 1);
      });
    });

    test('a resume after a drained pause listens again', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        unawaited(rig.engine.pause());
        async.flushMicrotasks();
        rig.stt.emitResult('kept', isFinal: true);
        async.flushMicrotasks();
        var resumed = false;
        unawaited(rig.engine.resume().then((ok) => resumed = ok));
        async.flushMicrotasks();

        expect(resumed, isTrue);
        expect(rig.results.map((r) => r.text), ['kept']);
        expect(rig.stt.listenCalls, hasLength(2));
      });
    });
  });

  // ---- Unit 10: on-device guard, listen options and listener wiring ------

  group('PlatformSttEngine (Unit 10 guard)', () {
    late CallLog log;
    late FakeSpeechToText stt;
    late FakeOnDeviceChecker checker;
    late MockAudioDeviceService audio;
    late PlatformSttEngine guarded;
    late List<SttEngineError> errors;

    setUp(() {
      log = CallLog();
      stt = FakeSpeechToText(log);
      checker = FakeOnDeviceChecker(log);
      audio = MockAudioDeviceService();
      when(() => audio.currentPreferredDeviceId).thenReturn(null);
      guarded = PlatformSttEngine(
        stt: stt,
        deviceService: audio,
        onDeviceSupportChecker: checker.call,
      );
      errors = [];
      guarded.setErrorListener(errors.add);
    });

    Future<bool> start([String locale = 'en-US']) async {
      await guarded.initialize();
      return guarded.startListening(
        localeId: locale,
        onResult: (_) {},
      );
    }

    test('is an SttErrorSource', () {
      expect(guarded, isA<SttErrorSource>());
    });

    group('listen options (BR-U10-20, 32)', () {
      test(
        'listens on-device with partial results and no cancelOnError',
        () async {
          expect(await start(), isTrue);

          final call = stt.listenCalls.single;
          expect(call.localeId, 'en-US');
          expect(call.listenOptions, isNotNull);
          expect(call.listenOptions!.onDevice, isTrue);
          // BR-U10-71 (Amendment 08): punctuation and the dictation hint.
          expect(call.listenOptions!.autoPunctuation, isTrue);
          expect(call.listenOptions!.listenMode, ListenMode.dictation);
          expect(call.listenOptions!.partialResults, isTrue);
          expect(call.listenOptions!.cancelOnError, isFalse);
          expect(call.usedDeprecatedArguments, isFalse);
        },
      );

      test('never passes plugin options (so no androidIntentLookup)', () async {
        await start();
        expect(stt.lastInitializeOptions, isNull);
      });
    });

    group('plugin listeners (BR-U10-24)', () {
      test('the engine assigns the plugin listener fields itself', () async {
        await guarded.initialize();
        expect(stt.statusListener, isNotNull);
        expect(stt.errorListener, isNotNull);
      });

      test('they are still assigned after a second initialize() '
          '(a repeat call to the plugin returns before assigning)', () async {
        await guarded.initialize();
        stt
          ..statusListener = null
          ..errorListener = null;
        await guarded.initialize();
        expect(stt.initializeCalls, 2);
        expect(stt.statusListener, isNotNull);
        expect(stt.errorListener, isNotNull);
      });
    });

    group('check before every listen (BR-U10-26)', () {
      test('a true check immediately precedes listen()', () async {
        await start('fr-FR');
        final lastTwo = log.entries.sublist(log.entries.length - 2);
        expect(lastTwo, ['check:fr-FR:true', 'listen']);
        expect(checker.localesChecked, ['fr-FR']);
      });

      test('the check is not cached across listens', () async {
        await guarded.initialize();
        await guarded.startListening(localeId: 'en-US', onResult: (_) {});
        await guarded.startListening(localeId: 'en-US', onResult: (_) {});
        expect(checker.localesChecked, hasLength(2));
        expect(stt.listenCalls, hasLength(2));
      });
    });

    group('refuse when unsupported (BR-U10-27, 29)', () {
      Future<void> expectRefusal(Future<bool> Function() run) async {
        final started = await run();
        expect(started, isFalse);
        expect(stt.listenCalls, isEmpty, reason: 'no listen() on a refusal');
        expect(
          errors,
          [const SttEngineError(SttEngineErrorKind.onDeviceModelMissing)],
          reason: 'exactly one lasting error',
        );
      }

      test(
        'iOS: a false check means no listen and one lasting error',
        () async {
          checker.defaultResult = false;
          await expectRefusal(start);
        },
      );

      test(
        'Android API 30: unsupported (false) is refused the same way',
        () async {
          checker.script.add(false);
          await expectRefusal(start);
        },
      );

      test('a throwing checker fails closed', () async {
        checker.script.add(Exception('channel exploded'));
        await expectRefusal(start);
      });

      test('a checker that never answers fails closed after the timeout', () {
        fakeAsync((async) {
          checker.script.add(FakeOnDeviceChecker.hang);
          var finished = false;
          var started = true;
          unawaited(
            start().then((v) {
              started = v;
              finished = true;
            }),
          );
          async.flushMicrotasks();
          expect(finished, isFalse, reason: 'still waiting for the checker');
          async
            ..elapse(
              defaultSttListeningLimits.onDeviceCheckTimeout +
                  const Duration(milliseconds: 1),
            )
            ..flushMicrotasks();
          expect(finished, isTrue);
          expect(started, isFalse);
          expect(stt.listenCalls, isEmpty);
          expect(errors, [
            const SttEngineError(SttEngineErrorKind.onDeviceModelMissing),
          ]);
        });
      });
    });

    group('a listen() that throws (BR-U10-30, 31; TP-18)', () {
      pbt.Glados<String>(pbt.any.letterOrDigits).test(
        'any ListenFailedException message is cancelled at once and treated '
        'as transient (no lasting error at start)',
        (message) async {
          final localLog = CallLog();
          final localStt = FakeSpeechToText(localLog)
            ..listenOutcomes.add(ListenFailedException(message));
          final localErrors = <SttEngineError>[];
          final localEngine = PlatformSttEngine(
            stt: localStt,
            deviceService: audio,
            onDeviceSupportChecker: FakeOnDeviceChecker(localLog).call,
          )..setErrorListener(localErrors.add);

          await localEngine.initialize();
          final started = await localEngine.startListening(
            localeId: 'en-US',
            onResult: (_) {},
          );

          expect(started, isFalse);
          // listen threw, then cancel() came straight after, before anything
          // else the engine did.
          final tail = localLog.entries.sublist(localLog.entries.length - 2);
          expect(tail, ['listen', 'cancel']);
          expect(localErrors, isEmpty, reason: 'transient, not lasting');
        },
      );

      test("even the plugin's on-device wording is not matched", () async {
        stt.listenOutcomes.add(
          ListenFailedException(
            'on device recognition is not supported on this device',
          ),
        );
        final started = await start();
        expect(started, isFalse);
        expect(stt.cancelCalls, 1);
        expect(errors, isEmpty);
      });
    });

    // A stop or a pause that arrives while startListening() is awaiting must
    // win: the microphone is never left live. Each await in the path is held
    // open by a gate, the interrupt runs to completion, and only then is the
    // held await released.
    group('a stop or pause during startListening (BR-U10-19)', () {
      /// Builds the engine inside [body] so every held future belongs to the
      /// fake-async zone, then runs [body] with the gates.
      void held({
        required String awaitAt,
        required bool pause,
        required void Function(
          FakeAsync async,
          PlatformSttEngine engine,
          FakeSpeechToText stt,
          List<SttEngineError> errors,
          Completer<void> gate,
        )
        body,
      }) {
        fakeAsync((async) {
          final log = CallLog();
          final localStt = FakeSpeechToText(log);
          final checker = FakeOnDeviceChecker(log);
          final audio = MockAudioDeviceService();
          final deviceGate = Completer<void>();
          final checkerGate = Completer<void>();
          final listenGate = Completer<void>();
          when(() => audio.currentPreferredDeviceId).thenReturn('mic-1');
          // Only the await this test holds is gated; the ones before it must
          // resolve immediately or the engine never reaches the gate.
          when(() => audio.setPreferredInputDevice('mic-1')).thenAnswer(
            (_) => awaitAt == 'device preference'
                ? deviceGate.future
                : Future<void>.value(),
          );
          final gate = switch (awaitAt) {
            'device preference' => deviceGate,
            'the on-device check' => checkerGate,
            'listen()' => listenGate,
            _ => throw ArgumentError(awaitAt),
          };
          if (awaitAt == 'the on-device check') {
            checker.hangNext = checkerGate.future;
          }
          if (awaitAt == 'listen()') localStt.listenGate = listenGate.future;
          final localErrors = <SttEngineError>[];
          final engine = PlatformSttEngine(
            stt: localStt,
            deviceService: audio,
            onDeviceSupportChecker: checker.call,
          )..setErrorListener(localErrors.add);

          var started = true;
          var finished = false;
          unawaited(engine.initialize());
          async.flushMicrotasks();
          unawaited(
            engine.startListening(localeId: 'en-US', onResult: (_) {}).then((
              v,
            ) {
              started = v;
              finished = true;
            }),
          );
          async.flushMicrotasks();
          expect(gate.isCompleted, isFalse, reason: 'held at the gate');

          // The interrupt must run to completion before the held await is
          // released, so the stop/pause reaches the plugin first.
          final interrupt = pause ? engine.pause() : engine.stopListening();
          async.flushMicrotasks();
          gate.complete();
          async.flushMicrotasks();
          unawaited(interrupt);
          async
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 5))
            ..flushMicrotasks();
          expect(finished, isTrue);
          expect(started, isFalse, reason: 'startListening() reports false');
          expect(localErrors, isEmpty, reason: 'an interrupt is not an error');
          body(async, engine, localStt, localErrors, gate);
        });
      }

      for (final awaitAt in [
        'device preference',
        'the on-device check',
        'listen()',
      ]) {
        // Before the plugin call, the engine guarantees no listen() at all;
        // if the interrupt lands while listen() is already awaiting its
        // reply, the call cannot be un-made, so exactly one stands and is
        // cancelled.
        final listenCountWhenStopWins = awaitAt == 'listen()'
            ? hasLength(1)
            : isEmpty;

        test('stop during $awaitAt: no listen() once the stop has won', () {
          held(
            awaitAt: awaitAt,
            pause: false,
            body: (async, engine, stt, errors, gate) {
              expect(stt.listenCalls, listenCountWhenStopWins);
              if (awaitAt == 'listen()') {
                expect(stt.log.entries.last, 'cancel');
              }
              // A late `done` from the plugin must not restart anything.
              stt.emitStatus('done');
              async
                ..elapse(const Duration(seconds: 5))
                ..flushMicrotasks();
              expect(stt.listenCalls, listenCountWhenStopWins);
            },
          );
        });

        test('pause during $awaitAt: no start, and the plugin is stopped', () {
          held(
            awaitAt: awaitAt,
            pause: true,
            body: (async, engine, stt, errors, gate) {
              expect(stt.stopCalls, 1);
              expect(stt.listenCalls, listenCountWhenStopWins);
              // A late `done` from the plugin must not restart anything.
              stt.emitStatus('done');
              async
                ..elapse(const Duration(seconds: 5))
                ..flushMicrotasks();
              expect(stt.listenCalls, listenCountWhenStopWins);
            },
          );
        });
      }

      test('stop during listen() cancels the plugin it already started', () {
        held(
          awaitAt: 'listen()',
          pause: false,
          body: (async, engine, stt, errors, gate) {
            expect(stt.listenCalls, hasLength(1));
            // Exactly two cancels: stopListening()'s own (no session was live
            // yet, so there is no drain and it cancels straight after
            // stop()), and the superseded startListening()'s, which cancels
            // the session its in-flight listen() began. The last thing the
            // plugin saw must be a cancel.
            expect(stt.cancelCalls, 2);
            expect(stt.log.entries.last, 'cancel');
          },
        );
      });

      test('pause during listen() leaves the session resumable', () {
        held(
          awaitAt: 'listen()',
          pause: true,
          body: (async, engine, stt, errors, gate) {
            var resumed = false;
            unawaited(engine.resume().then((v) => resumed = v));
            async.flushMicrotasks();

            expect(resumed, isTrue);
            expect(stt.listenCalls, hasLength(2));
          },
        );
      });
    });
  });
}
