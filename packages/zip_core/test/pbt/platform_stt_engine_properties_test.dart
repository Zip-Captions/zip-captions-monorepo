import 'dart:async';
import 'dart:math';

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
import '../helpers/pbt.dart' as pbt;

// Property tests for the engine's continuous-listening loop and on-device
// guard (Unit 10): TP-11 and TP-15 (stateful model), TP-13, TP-14, TP-17.
//
// The shim in `../helpers/pbt.dart` runs fixed seeds 0 to 99, has no
// shrinking and prints no seed. A failing sequence is therefore reproduced
// from the fixed seed plus the command list printed in the failure message.

const _silenceCodes = ['error_no_match', 'error_speech_timeout'];
const _transientCodes = [
  'error_busy',
  'error_client',
  'error_audio_error',
  'error_network',
  'error_network_timeout',
  'error_server',
  'error_server_disconnected',
  'error_too_many_requests',
  'error_unknown (9)',
  'error_retry',
  'error_listen_failed',
];
const _lastingCodes = <String, SttEngineErrorKind>{
  'error_permission': SttEngineErrorKind.permissionRevoked,
  'error_language_unavailable': SttEngineErrorKind.onDeviceModelMissing,
  'error_language_not_supported': SttEngineErrorKind.localeUnsupported,
  'error_speech_recognizer_request_not_authorized':
      SttEngineErrorKind.permissionRevoked,
  'error_assets_not_installed': SttEngineErrorKind.onDeviceModelMissing,
  'error_speech_recognizer_disabled': SttEngineErrorKind.recognizerUnavailable,
};

enum _Kind {
  start,
  stop,
  pause,
  resume,
  interim,
  finalResult,
  tick,
  errorOnly,
  endQuiet,
  endSilence,
  endTransient,
  endFast,
  endLasting,
  setCheck,
  setListen,
}

enum _Slot { ok, no, throws }

class _Cmd {
  const _Cmd(
    this.kind, {
    this.code = '',
    this.ms = 0,
    this.slot = _Slot.ok,
    this.text = '',
  });

  final _Kind kind;
  final String code;
  final int ms;
  final _Slot slot;
  final String text;

  @override
  String toString() => switch (kind) {
    _Kind.tick => 'tick(${ms}ms)',
    _Kind.errorOnly || _Kind.endLasting => '${kind.name}($code)',
    _Kind.setCheck || _Kind.setListen => '${kind.name}(${slot.name})',
    _ => kind.name,
  };
}

pbt.Generator<_Cmd> get _commandGenerator {
  final lastingCodes = _lastingCodes.keys.toList();
  final text = pbt.any.letterOrDigits;
  final weighted = <_Cmd Function(Random)>[
    for (var i = 0; i < 3; i++) (r) => const _Cmd(_Kind.start),
    (r) => const _Cmd(_Kind.stop),
    (r) => const _Cmd(_Kind.pause),
    for (var i = 0; i < 2; i++) (r) => const _Cmd(_Kind.resume),
    for (var i = 0; i < 2; i++) (r) => _Cmd(_Kind.interim, text: 'i${text(r)}'),
    (r) => _Cmd(_Kind.finalResult, text: 'f${text(r)}'),
    (r) => _Cmd(
      _Kind.tick,
      ms: const [10, 100, 300, 2500, 60000][r.nextInt(5)],
    ),
    (r) => _Cmd(
      _Kind.errorOnly,
      code:
          [
            ..._silenceCodes,
            ..._transientCodes,
            ...lastingCodes,
          ][r.nextInt(
            _silenceCodes.length + _transientCodes.length + lastingCodes.length,
          )],
    ),
    for (var i = 0; i < 3; i++) (r) => const _Cmd(_Kind.endQuiet),
    (r) => _Cmd(_Kind.endSilence, code: _silenceCodes[r.nextInt(2)]),
    for (var i = 0; i < 3; i++)
      (r) => _Cmd(
        _Kind.endTransient,
        code: _transientCodes[r.nextInt(_transientCodes.length)],
      ),
    (r) => const _Cmd(_Kind.endFast),
    (r) => _Cmd(
      _Kind.endLasting,
      code: lastingCodes[r.nextInt(lastingCodes.length)],
    ),
    (r) => _Cmd(_Kind.setCheck, slot: _Slot.values[r.nextInt(3)]),
    (r) => _Cmd(_Kind.setListen, slot: r.nextBool() ? _Slot.ok : _Slot.throws),
  ];
  return (r) => weighted[r.nextInt(weighted.length)](r);
}

/// The simplified reference model (PBT-06): what the engine should have done
/// after each command, written from the rules rather than from the code.
class _Model {
  static const cap = 3; // defaultSttListeningLimits.restartCap
  static const windowMs = 2000; // immediateFailureWindow
  static const pauseMs = 1500; // iosSegmentPause

  String intent = 'idle'; // idle, listening, paused, stopped, failed
  int count = 0;
  int listens = 0;

  int checks = 0;

  int finals = 0;
  final errors = <SttEngineErrorKind>[];

  // Per-session record.
  bool pending = false;

  /// Milliseconds since the latest interim, while it is pending (BR-U10-68).
  int pendingMs = 0;
  bool delivered = false;
  int age = 0;
  int worst = 0; // 0 none, 1 silence, 2 transient

  final checkQueue = <_Slot>[];
  final listenQueue = <_Slot>[];

  /// How many listen() outcomes the model has issued (the engine counts a
  /// listen() at its call, even one that is still held open).
  int listenIssued = 0;

  /// What a guarded listen came to: 'started', 'refused' or 'threw'.
  String _attempt() {
    final check = checkQueue.isEmpty ? _Slot.ok : checkQueue.removeAt(0);
    checks++;
    if (check != _Slot.ok) {
      errors.add(SttEngineErrorKind.onDeviceModelMissing);
      return 'refused';
    }
    listens++;
    listenIssued++;
    final listen = listenQueue.isEmpty ? _Slot.ok : listenQueue.removeAt(0);
    return listen == _Slot.throws ? 'threw' : 'started';
  }

  void _newSession() {
    pending = false;
    delivered = false;
    age = 0;
    worst = 0;
  }

  void start({required bool resuming}) {
    final outcome = _attempt();
    if (outcome == 'started') {
      intent = 'listening';
      count = 0;
      _newSession();
    }
  }

  /// BR-U10-55: a stop or pause of a live session waits for the last phrase;
  /// the fake plugin sends none, so the wait ends at the deadline and a
  /// pending interim is flushed once as final.
  void _drain() {
    if (intent == 'listening' && pending) finals++;
    pending = false;
  }

  void stop() {
    _drain();
    intent = 'stopped';
  }

  void pause() {
    _drain();
    intent = 'paused';
  }

  void result({required bool isFinal}) {
    // After a stop or a pause (outside a drain) a result is dropped, since
    // BR-U10-55 moved the delivery of the last phrase into the drain. In every
    // other intent the result reaches the app, but only a listening
    // session's results update the loop's bookkeeping.
    if (intent == 'stopped' || intent == 'paused') return;
    if (isFinal) finals++;
    if (intent != 'listening') return;
    delivered = true;
    count = 0;
    pending = !isFinal;
    pendingMs = 0;
  }

  void tick(int ms) {
    if (intent != 'listening') return;
    age += ms;
    // BR-U10-68 (Amendment 08): a pending interim with no new result for
    // `iosSegmentPause` is delivered once as final, and nothing restarts.
    if (pending) {
      pendingMs += ms;
      if (pendingMs >= pauseMs) {
        finals++;
        pending = false;
      }
    }
  }

  void errorOnly(String code) {
    if (intent != 'listening') return;
    final lasting = _lastingCodes[code];
    if (lasting != null) {
      errors.add(lasting);
      intent = 'failed';
      return;
    }
    worst = max(worst, _silenceCodes.contains(code) ? 1 : 2);
  }

  /// A `done` status, with an optional extra error class already emitted.
  void done() {
    if (intent != 'listening') return;
    if (pending) {
      finals++;
      pending = false;
    }
    final fastAndEmpty = worst == 0 && !delivered && age < windowMs;
    if ((worst == 2 || fastAndEmpty) && _countReachedCap()) return;
    _newSession();
    _restart();
  }

  bool _countReachedCap() {
    count++;
    if (count < cap) return false;
    errors.add(SttEngineErrorKind.restartCapReached);
    intent = 'failed';
    return true;
  }

  void _restart() {
    switch (_attempt()) {
      case 'started':
        _newSession();
      case 'refused':
        intent = 'failed';
      case _:
        if (_countReachedCap()) return;
        _restart();
    }
  }
}

class _Run {
  _Run(this.async) {
    when(() => audio.currentPreferredDeviceId).thenReturn(null);
    engine = PlatformSttEngine(
      stt: stt,
      deviceService: audio,
      onDeviceSupportChecker: checker.call,
      now: async.getClock(DateTime(2026)).now,
    )..setErrorListener(errors.add);
  }

  final FakeAsync async;
  final log = CallLog();
  final audio = MockAudioDeviceService();
  late final FakeSpeechToText stt = FakeSpeechToText(log);
  late final FakeOnDeviceChecker checker = FakeOnDeviceChecker(log);
  late final PlatformSttEngine engine;
  final errors = <SttEngineError>[];
  final results = <SttResult>[];

  /// Completes [future] under fake time. A stop or a pause of a live session
  /// waits for the BR-U10-55 drain, and the fake plugin sends nothing in it,
  /// so those pass [drained] to let the deadline pass.
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
    expect(done, isTrue);
    return value as T;
  }

  /// Initialises the engine and starts listening for `en-US`.
  void startEngine() {
    await_(engine.initialize());
    await_(engine.startListening(localeId: 'en-US', onResult: onResult));
  }

  void onResult(SttResult r) {
    results.add(r);
    log.add(r.isFinal ? 'result:final' : 'result:interim');
  }

  /// Lets every pending restart attempt (including retries) run.
  void settle() {
    for (var i = 0; i < 6; i++) {
      async
        ..elapse(
          defaultSttListeningLimits.restartDelay +
              const Duration(milliseconds: 1),
        )
        ..flushMicrotasks();
    }
  }

  void endWith({String? code, int tickMs = 0}) {
    async.elapse(Duration(milliseconds: tickMs));
    if (code != null) stt.emitError(code);
    stt
      ..emitStatus('notListening')
      ..emitStatus('done');
    async.flushMicrotasks();
    settle();
  }
}

// Coverage counters across all seeds, so the model test cannot pass
// vacuously (for example if the generator stopped producing restarts).

var _coveredListens = 0;
var _coveredRestarts = 0;
var _coveredErrors = 0;

void main() {
  group('TP-11 / TP-15 stateful model: the continuous-listening loop and the '
      'on-device guard', () {
    tearDownAll(() {
      expect(_coveredListens, greaterThan(300), reason: 'listen() calls');
      expect(_coveredRestarts, greaterThan(100), reason: 'restarts');
      expect(_coveredErrors, greaterThan(50), reason: 'reported errors');
    });

    pbt.Glados<List<_Cmd>>(
      pbt.any.listWithLengthInRange(0, 40, _commandGenerator),
    ).test(
      'the engine matches the reference model after every command',
      (commands) {
        fakeAsync((async) {
          final run = _Run(async);
          final model = _Model();
          final executed = <_Cmd>[];

          // (a) The listen count at the moment a stop or pause took effect;
          // null while listening is allowed.
          int? blockedAt;

          for (final cmd in commands) {
            executed.add(cmd);
            switch (cmd.kind) {
              case _Kind.start:
                if (model.intent == 'listening' || model.intent == 'paused') {
                  continue;
                }
                run.startEngine();
                model.start(resuming: false);
                // The next start (or resume) lifts the block, whether or not
                // its own listen() succeeds.
                blockedAt = null;
              case _Kind.stop:
                run.await_(run.engine.stopListening(), drained: true);
                model.stop();
                blockedAt ??= run.stt.listenCalls.length;
              case _Kind.pause:
                if (model.intent != 'listening') continue;
                run.await_(run.engine.pause(), drained: true);
                model.pause();
                blockedAt ??= run.stt.listenCalls.length;
              case _Kind.resume:
                if (model.intent != 'paused') continue;
                run.await_(run.engine.resume());
                model.start(resuming: true);
                blockedAt = null;
              case _Kind.interim:
                if (run.stt.listenCalls.isEmpty) continue;
                run.stt.emitResult(cmd.text, isFinal: false);
                model.result(isFinal: false);
              case _Kind.finalResult:
                if (run.stt.listenCalls.isEmpty) continue;
                run.stt.emitResult(cmd.text, isFinal: true);
                model.result(isFinal: true);
              case _Kind.tick:
                run.async
                  ..elapse(Duration(milliseconds: cmd.ms))
                  ..flushMicrotasks();
                model.tick(cmd.ms);
              case _Kind.errorOnly:
                run.stt.emitError(cmd.code);
                run.async.flushMicrotasks();
                model.errorOnly(cmd.code);
              case _Kind.endQuiet:
                run.endWith(tickMs: 2500);
                model.tick(2500);
                model.done();
              case _Kind.endSilence:
                run.endWith(code: cmd.code);
                model
                  ..errorOnly(cmd.code)
                  ..done();
              case _Kind.endTransient:
                run.endWith(code: cmd.code, tickMs: 2500);
                model
                  ..tick(2500)
                  ..errorOnly(cmd.code)
                  ..done();
              case _Kind.endFast:
                run.endWith();
                model.done();
              case _Kind.endLasting:
                run.endWith(code: cmd.code);
                model
                  ..errorOnly(cmd.code)
                  ..done();
              case _Kind.setCheck:
                run.checker.script.add(switch (cmd.slot) {
                  _Slot.ok => true,
                  _Slot.no => false,
                  _Slot.throws => Exception('checker threw'),
                });
                model.checkQueue.add(cmd.slot);
              case _Kind.setListen:
                run.stt.listenOutcomes.add(
                  cmd.slot == _Slot.throws
                      ? ListenFailedException('listen threw')
                      : null,
                );
                model.listenQueue.add(cmd.slot);
            }
            final why = 'after ${executed.length} commands: $executed';
            expect(
              run.stt.listenCalls.length,
              model.listens,
              reason: 'listen count $why',
            );
            expect(
              run.checker.localesChecked.length,
              model.checks,
              reason: 'check count $why',
            );
            expect(
              run.errors.map((e) => e.kind).toList(),
              model.errors,
              reason: 'errors $why',
            );
            expect(
              run.results.where((r) => r.isFinal).length,
              model.finals,
              reason: 'final results $why',
            );
            // TP-11 (a): while stopped or paused, no listen() happens.
            if (blockedAt != null) {
              expect(run.stt.listenCalls.length, blockedAt, reason: why);
            }
          }

          _coveredListens += run.stt.listenCalls.length;
          _coveredErrors += run.errors.length;
          // A restart is a listen() that is not the first after a start.
          _coveredRestarts += max(
            0,
            run.stt.listenCalls.length - run.stt.initializeCalls,
          );

          // TP-15: every listen() is immediately preceded by a check for the
          // same locale that returned true, and is never skipped or reused.
          final entries = run.log.entries;
          for (var i = 0; i < entries.length; i++) {
            if (entries[i] != 'listen') continue;
            expect(
              i,
              greaterThan(0),
              reason: 'listen with no check: $executed',
            );
            expect(
              entries[i - 1],
              'check:en-US:true',
              reason:
                  'a listen() without a true check just before it: '
                  '$executed',
            );
          }
        });
      },
    );
  });

  group('TP-14: the final-first flush', () {
    pbt.Glados<List<String>>(
      pbt.any.listWithLengthInRange(1, 6, pbt.any.letterOrDigits),
    ).test(
      'a pending interim is delivered as final at most once, before the next '
      'listen(), and never again',
      (texts) {
        fakeAsync((async) {
          final run = _Run(async)..startEngine();
          for (final t in texts) {
            run.stt.emitResult('w$t', isFinal: false);
          }
          run.stt.emitStatus('notListening');
          expect(run.results.where((r) => r.isFinal), isEmpty);

          run.stt
            ..emitStatus('done')
            ..emitStatus('done');
          run.settle();

          final finals = run.results.where((r) => r.isFinal).toList();
          expect(finals, hasLength(1));
          expect(finals.single.text, 'w${texts.last}');

          final entries = run.log.entries;
          final finalAt = entries.indexOf('result:final');
          final secondListenAt = entries.lastIndexOf('listen');
          expect(finalAt, greaterThanOrEqualTo(0));
          expect(
            secondListenAt,
            greaterThan(finalAt),
            reason: 'the flush comes before the restart listen()',
          );
        });
      },
    );
  });

  group('TP-13: the code classes are total', () {
    pbt.Glados<String>(pbt.any.letterOrDigits).test(
      'an unrecognised error code is transient: it restarts and counts toward '
      'the cap',
      (suffix) {
        fakeAsync((async) {
          final run = _Run(async)..startEngine();
          final code = 'x_$suffix';
          for (var i = 0; i < 2; i++) {
            run.endWith(code: code, tickMs: 2500);
            expect(run.errors, isEmpty);
          }
          expect(run.stt.listenCalls, hasLength(3));
          run.endWith(code: code, tickMs: 2500);
          expect(run.errors.map((e) => e.kind), [
            SttEngineErrorKind.restartCapReached,
          ]);
        });
      },
    );

    test('every lasting code maps to exactly one kind and stops', () {
      for (final entry in _lastingCodes.entries) {
        fakeAsync((async) {
          final run = _Run(async)
            ..startEngine()
            ..endWith(code: entry.key);
          expect(
            run.errors.map((e) => e.kind),
            [entry.value],
            reason: entry.key,
          );
          expect(run.stt.listenCalls, hasLength(1), reason: entry.key);
        });
      }
    });
  });

  group('TP-17: refusal and throwing listen during a restart', () {
    pbt.Glados<int>(pbt.any.intInRange(0, 3)).test(
      'a throwing listen is transient and its retry is checked first; if '
      'support has gone the retry is exactly one lasting refusal',
      (throwsBeforeRefusal) {
        fakeAsync((async) {
          final run = _Run(async)..startEngine();
          // The restart listen() throws, then the next check refuses.
          for (var i = 0; i < throwsBeforeRefusal; i++) {
            run.checker.script.add(true);
            run.stt.listenOutcomes.add(ListenFailedException('x'));
          }
          run.checker.script.add(false);
          run.endWith(tickMs: 2500);

          // Every listen() had a true check immediately before it.
          final entries = run.log.entries;
          for (var i = 0; i < entries.length; i++) {
            if (entries[i] == 'listen') {
              expect(entries[i - 1], 'check:en-US:true');
            }
          }
          // Either the cap was hit first (3 throws) or the refusal came: in
          // both cases exactly one lasting error, and nothing listens after.
          expect(run.errors, hasLength(1));
          final listensAfter = run.stt.listenCalls.length;
          run.settle();
          expect(run.stt.listenCalls.length, listensAfter);
          expect(run.errors, hasLength(1));
        });
      },
    );
  });
}
