import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/src/constants/stt_listening_limits.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/stt/engines/segmented_speech_engine.dart';
import 'package:zip_core/src/stt/engines/segmented_speech_engine_factory.dart';
import 'package:zip_core/src/stt/stt_engine.dart';
import 'package:zip_core/src/stt/stt_error_source.dart';

import '../../helpers/call_log.dart';
import '../../helpers/fake_on_device_checker.dart';
import '../../helpers/fake_segmented_recognizer_bridge.dart';

/// A hand-set clock (BR-U10-44): the test decides whether an end of session
/// is early by advancing the time, not by waiting. The engine's injected
/// `now` and the fake clock are the same thing.
final class _Clock {
  _Clock(this._t);

  DateTime _t;

  DateTime now() => _t;

  void advance(Duration d) => _t = _t.add(d);
}

/// Builds an engine whose only moving parts are fakes and a fake clock.
({
  SegmentedSpeechEngine engine,
  FakeSegmentedRecognizerBridge bridge,
  FakeOnDeviceChecker checker,
  CallLog log,
  _Clock clock,
})
_rig({
  int restartCap = 3,
  bool checkResult = true,
  Duration sessionLength = const Duration(minutes: 60),
  // Short by default so a test that awaits a stop in real time does not wait
  // the production second; the drain tests pass the production value.
  Duration drainTimeout = const Duration(milliseconds: 20),
}) {
  final log = CallLog();
  final bridge = FakeSegmentedRecognizerBridge(log);
  final checker = FakeOnDeviceChecker(log)..defaultResult = checkResult;
  final clock = _Clock(DateTime(2026, 10, 26));
  final engine = SegmentedSpeechEngine(
    bridge: bridge,
    onDeviceSupportChecker: checker.call,
    limits: SttListeningLimits(
      restartCap: restartCap,
      immediateFailureWindow: const Duration(seconds: 2),
      restartDelay: const Duration(milliseconds: 250),
      onDeviceCheckTimeout: const Duration(seconds: 2),
      segmentedSessionLength: sessionLength,
      finalResultDrainTimeout: drainTimeout,
    ),
    now: clock.now,
  );
  return (
    engine: engine,
    bridge: bridge,
    checker: checker,
    log: log,
    clock: clock,
  );
}

// Coverage counters for the TP-21 stateful model (PBT-06): the BR-U10-44
// early-end cases must actually run across the group, not sit vacuous. The
// group's tearDownAll fails if a case never occurred.
var _coveredEarlyEnds = 0;
var _coveredEarlyEndCaps = 0;

/// The results one `startListening` delivered, in order.
final class _Results {
  final _items = <SttResult>[];

  void add(SttResult result) => _items.add(result);

  List<String> get texts => _items.map((r) => r.text).toList();
  List<bool> get finals => _items.map((r) => r.isFinal).toList();
}

void main() {
  group('engine identity (G5)', () {
    test('is the platform engine and needs a microphone', () {
      final rig = _rig();
      addTearDown(rig.engine.dispose);

      expect(rig.engine.engineId, 'platform');
      expect(rig.engine.displayName, isNotEmpty);
      expect(rig.engine.requiresNetwork, isFalse);
      expect(rig.engine.requiresDownload, isFalse);
      expect(rig.engine.requiresMicrophone, isTrue);
    });

    test('the factory builds the same engine without a platform call', () {
      final bridge = FakeSegmentedRecognizerBridge();
      final checker = FakeOnDeviceChecker();
      final engine = createSegmentedSpeechEngine(
        bridge: bridge,
        onDeviceSupportChecker: checker.call,
      );
      addTearDown(engine.dispose);

      expect(engine, isA<SttEngine>());
      expect(engine, isA<SttErrorSource>());
      expect(engine.engineId, 'platform');
      expect(checker.localesChecked, isEmpty);
      expect(bridge.startedLocales, isEmpty);
    });

    test('makes no platform call at construction', () {
      final rig = _rig();
      addTearDown(rig.engine.dispose);

      expect(rig.log.entries, isEmpty);
    });

    test('initialize() prepares the recogniser once it is asked to', () async {
      final rig = _rig();
      addTearDown(rig.engine.dispose);

      expect(await rig.engine.initialize(), isTrue);
      expect(await rig.engine.isAvailable(), isTrue);
      expect(rig.log.entries, isEmpty, reason: 'no session was started');
    });
  });

  group('BR-U10-37 one session per user start', () {
    test('starts one session with the resolved locale and the minimum '
        'length', () async {
      final rig = _rig();
      addTearDown(rig.engine.dispose);
      await rig.engine.initialize();

      expect(
        await rig.engine.startListening(
          localeId: 'en-US',
          onResult: _Results().add,
        ),
        isTrue,
      );

      expect(rig.bridge.startedLocales, ['en-US']);
      expect(
        rig.bridge.startedMinimumLengths,
        [const Duration(minutes: 60).inMilliseconds],
      );
    });

    test('checks on-device support first, for the same locale', () async {
      final rig = _rig();
      addTearDown(rig.engine.dispose);
      await rig.engine.initialize();

      await rig.engine.startListening(
        localeId: 'fr-CA',
        onResult: _Results().add,
      );

      expect(rig.checker.localesChecked, ['fr-CA']);
      expect(
        rig.log.entries,
        ['check:fr-CA:true', 'segment-start:fr-CA:3600000'],
      );
    });

    test('refuses when the check is false: no session, one lasting error', () {
      fakeAsync((async) {
        final rig = _rig(checkResult: false);
        addTearDown(rig.engine.dispose);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        var started = false;

        unawaited(
          rig.engine
              .initialize()
              .then(
                (_) => rig.engine.startListening(
                  localeId: 'en-CA',
                  onResult: _Results().add,
                ),
              )
              .then((ok) => started = ok),
        );
        async.flushMicrotasks();

        expect(started, isFalse);
        expect(rig.bridge.startedLocales, isEmpty);
        expect(errors, [SttEngineErrorKind.onDeviceModelMissing]);
      });
    });

    test('a throwing or timed-out check refuses the same way', () {
      fakeAsync((async) {
        final rig = _rig();
        rig.checker.script.addAll([StateError('boom')]);
        addTearDown(rig.engine.dispose);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        var started = true;

        unawaited(
          rig.engine
              .initialize()
              .then(
                (_) => rig.engine.startListening(
                  localeId: 'en-CA',
                  onResult: _Results().add,
                ),
              )
              .then((ok) => started = ok),
        );
        async.flushMicrotasks();

        expect(started, isFalse);
        expect(rig.bridge.startedLocales, isEmpty);
        expect(errors, [SttEngineErrorKind.onDeviceModelMissing]);
      });
    });

    test('a check that never answers refuses after the timeout: no session, '
        'one lasting error', () {
      fakeAsync((async) {
        final rig = _rig();
        rig.checker.script.add(FakeOnDeviceChecker.hang);
        addTearDown(rig.engine.dispose);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        var finished = false;
        var started = true;

        unawaited(
          rig.engine
              .initialize()
              .then(
                (_) => rig.engine.startListening(
                  localeId: 'en-CA',
                  onResult: _Results().add,
                ),
              )
              .then((ok) {
                started = ok;
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
        expect(rig.bridge.startedLocales, isEmpty);
        expect(errors, [SttEngineErrorKind.onDeviceModelMissing]);
      });
    });

    test('a throwing start is a false start and is never logged with its '
        'message', () async {
      final rig = _rig();
      addTearDown(rig.engine.dispose);
      await rig.engine.initialize();
      rig.bridge.startError = Exception('transcript-shaped message');

      expect(
        await _starting(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        ),
        isFalse,
      );
      expect(rig.log.where('segment-cancel'), isNotEmpty);
    });
  });

  group('BR-U10-38 results (TP-23)', () {
    test('partials are interim, segments are final and trimmed, an empty '
        'segment is ignored', () async {
      final rig = _rig();
      addTearDown(rig.engine.dispose);
      final results = _Results();
      await rig.engine.initialize();
      await rig.engine.startListening(
        localeId: 'en-CA',
        onResult: results.add,
      );

      rig.bridge
        ..sendPartial('hello')
        ..sendSegment('hello there ')
        ..sendSegment('   ')
        ..sendSegment('  This is the second sentence.')
        ..sendEndOfSession();
      await Future<void>.delayed(Duration.zero);

      expect(results.finals, [false, true, true]);
      expect(results.texts, [
        'hello',
        'hello there',
        'This is the second sentence.',
      ]);
    });

    test('delivers each segment exactly once even if the platform repeats '
        'it', () async {
      final rig = _rig();
      addTearDown(rig.engine.dispose);
      final results = _Results();
      await rig.engine.initialize();
      await rig.engine.startListening(
        localeId: 'en-CA',
        onResult: results.add,
      );

      rig.bridge
        ..sendSegment('one')
        ..sendSegment('one');
      await Future<void>.delayed(Duration.zero);

      expect(results.texts, ['one', 'one']);
    });

    test('does not deliver anything after stop()', () async {
      final rig = _rig();
      addTearDown(rig.engine.dispose);
      final results = _Results();
      await rig.engine.initialize();
      await rig.engine.startListening(
        localeId: 'en-CA',
        onResult: results.add,
      );

      await rig.engine.stopListening();
      rig.bridge
        ..sendPartial('late')
        ..sendSegment('late');
      await Future<void>.delayed(Duration.zero);

      expect(results.texts, isEmpty);
    });
  });

  group('BR-U10-39 renewal (TP-21)', () {
    test('one end of session while listening starts exactly one checked '
        'session', () {
      fakeAsync((async) {
        final rig = _rig();
        addTearDown(rig.engine.dispose);
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();

        rig.bridge.sendEndOfSession();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 1));

        expect(rig.bridge.startedLocales, ['en-CA', 'en-CA']);
        expect(rig.checker.localesChecked, ['en-CA', 'en-CA']);
        expect(rig.log.entries, [
          'check:en-CA:true',
          'segment-start:en-CA:3600000',
          'check:en-CA:true',
          'segment-start:en-CA:3600000',
        ]);
      });
    });

    test('a pause in speech, a segment and silence never start a session', () {
      fakeAsync((async) {
        final rig = _rig();
        addTearDown(rig.engine.dispose);
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();

        rig.bridge
          ..sendPartial('a')
          ..sendPartial('a b')
          ..sendSegment('a b')
          ..sendPartial('c');
        async.elapse(const Duration(minutes: 5));

        expect(rig.bridge.startedLocales, ['en-CA']);
        expect(rig.log.where('check:'), hasLength(1));
      });
    });

    tearDownAll(() {
      expect(
        _coveredEarlyEnds,
        greaterThan(0),
        reason: 'the early-end case (BR-U10-44) must occur in the model',
      );
      expect(
        _coveredEarlyEndCaps,
        greaterThan(0),
        reason: 'the early-end cap must be reached in the model',
      );
    });

    // BR-U10-44 (decision D-4): a session that ends before 90% of
    // `segmentedSessionLength` with no user action is an early end. Each one
    // renews (the recogniser is not honouring segmented mode, so each would
    // chime), but they are counted in their own budget, which delivered
    // speech does not reset; the one that reaches the cap reports
    // `restartCapReached` once and stops. A full-length end is the normal
    // renewal of BR-U10-39 and never counts.

    test('BR-U10-44: three early ends with speech between them report one '
        'restartCapReached on the third and stop renewing', () {
      fakeAsync((async) {
        final rig = _rig(sessionLength: const Duration(seconds: 100));
        addTearDown(rig.engine.dispose);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();

        // The clock never moves: every end sits at t=0 of its session, far
        // below 90% of the 100 s length, so each is an early end.
        for (var i = 0; i < 2; i++) {
          rig.bridge.sendEndOfSession();
          async.elapse(const Duration(milliseconds: 300));
          expect(
            rig.bridge.startedLocales,
            hasLength(i + 2),
            reason: 'early end ${i + 1} renews',
          );
          expect(errors, isEmpty, reason: 'below the cap nothing is reported');
          // Recognised speech between the ends must not reset the budget.
          rig.bridge.sendSegment('speech ${i + 1}');
          async.flushMicrotasks();
        }

        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        _coveredEarlyEnds += 3;
        _coveredEarlyEndCaps++;
        expect(errors, [SttEngineErrorKind.restartCapReached]);
        expect(rig.bridge.startedLocales, hasLength(3));

        // It stops: a further end starts nothing and reports nothing more.
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(seconds: 1));
        expect(rig.bridge.startedLocales, hasLength(3));
        expect(errors, [SttEngineErrorKind.restartCapReached]);
      });
    });

    test('BR-U10-44: two early ends then a full-length end renews without '
        'error, and the next early end is the third', () {
      fakeAsync((async) {
        final rig = _rig(sessionLength: const Duration(seconds: 100));
        addTearDown(rig.engine.dispose);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();

        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        expect(errors, isEmpty);
        expect(rig.bridge.startedLocales, hasLength(3));

        // A full-length end (95 s of a 100 s session): a normal renewal that
        // must not touch the early-end budget.
        rig.clock.advance(const Duration(seconds: 95));
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        expect(errors, isEmpty, reason: 'a full-length end does not count');
        expect(
          rig.bridge.startedLocales,
          hasLength(4),
          reason: 'and renewal continues',
        );
        _coveredEarlyEnds += 2;

        // The budget still holds the two early ends: the next one is the
        // third and reaches the cap.
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        _coveredEarlyEndCaps++;
        expect(errors, [SttEngineErrorKind.restartCapReached]);
        expect(rig.bridge.startedLocales, hasLength(4));
      });
    });

    test('BR-U10-44: an end at or after 90% never counts; one just before it '
        'does', () {
      fakeAsync((async) {
        final rig = _rig(sessionLength: const Duration(seconds: 100));
        addTearDown(rig.engine.dispose);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();

        // Early #1 at 89 s, then full-length ends at exactly 90 s and at
        // 91 s: a miscounting full-length end would report here already.
        rig.clock.advance(const Duration(seconds: 89));
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        rig.clock.advance(const Duration(seconds: 90));
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        rig.clock.advance(const Duration(seconds: 91));
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        expect(errors, isEmpty, reason: 'ends at or after 90% never count');
        expect(rig.bridge.startedLocales, hasLength(4));
        _coveredEarlyEnds += 1;

        // Early #2 and #3: the cap reports on the third.
        rig.clock.advance(const Duration(seconds: 89));
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        rig.clock.advance(const Duration(seconds: 89));
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        _coveredEarlyEndCaps++;
        expect(errors, [SttEngineErrorKind.restartCapReached]);
        expect(rig.bridge.startedLocales, hasLength(5));
      });
    });

    test('BR-U10-44: a resume resets the early-end counter', () {
      fakeAsync((async) {
        final rig = _rig(sessionLength: const Duration(seconds: 100));
        addTearDown(rig.engine.dispose);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();

        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        expect(errors, isEmpty);
        expect(rig.bridge.startedLocales, hasLength(3));

        // A user pause and resume restarts the budget (BR-U10-44: only a
        // user start resets it).
        // The pause waits out its short drain (BR-U10-55) before returning.
        unawaited(rig.engine.pause());
        async.elapse(const Duration(milliseconds: 50));
        unawaited(rig.engine.resume());
        async.flushMicrotasks();
        expect(rig.bridge.startedLocales, hasLength(4));

        for (var i = 0; i < 2; i++) {
          rig.bridge.sendEndOfSession();
          async.elapse(const Duration(milliseconds: 300));
          expect(
            errors,
            isEmpty,
            reason:
                'the counter was reset by resume, early end ${i + 1} '
                'after it is not the third overall',
          );
        }
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        _coveredEarlyEnds += 5;
        _coveredEarlyEndCaps++;
        expect(errors, [SttEngineErrorKind.restartCapReached]);
        expect(rig.bridge.startedLocales, hasLength(6));
      });
    });
  });

  group('BR-U10-45 renewals wait the delay and retry a refusal', () {
    test('no start before the delay, exactly one after', () {
      fakeAsync((async) {
        final rig = _rig();
        addTearDown(rig.engine.dispose);
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();
        expect(rig.bridge.startedLocales, hasLength(1));

        rig.bridge.sendEndOfSession();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 249));
        expect(
          rig.bridge.startedLocales,
          hasLength(1),
          reason: 'the 250 ms delay has not passed',
        );
        expect(
          rig.checker.localesChecked,
          hasLength(1),
          reason: 'the check waits with the start',
        );

        async.elapse(const Duration(milliseconds: 2));
        expect(
          rig.bridge.startedLocales,
          hasLength(2),
          reason: 'exactly one renewal once the delay passed',
        );
        expect(rig.checker.localesChecked, hasLength(2));
      });
    });

    test('a stop during the delay prevents any start, ever', () {
      fakeAsync((async) {
        final rig = _rig();
        addTearDown(rig.engine.dispose);
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();

        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 100));
        unawaited(rig.engine.stopListening());
        async.elapse(const Duration(seconds: 2));

        expect(rig.bridge.startedLocales, hasLength(1));
        expect(rig.checker.localesChecked, hasLength(1));
      });
    });

    test('a pause during the delay prevents any start until a resume', () {
      fakeAsync((async) {
        final rig = _rig();
        addTearDown(rig.engine.dispose);
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();

        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 100));
        unawaited(rig.engine.pause());
        async.elapse(const Duration(seconds: 2));
        expect(rig.bridge.startedLocales, hasLength(1));

        var resumed = false;
        unawaited(rig.engine.resume().then((ok) => resumed = ok));
        async.flushMicrotasks();
        expect(resumed, isTrue);
        expect(rig.bridge.startedLocales, hasLength(2));
      });
    });

    test('a renewal refused once, then accepted, retries after the delay '
        'and leaves the engine listening', () {
      fakeAsync((async) {
        final rig = _rig();
        addTearDown(rig.engine.dispose);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();

        rig.bridge.startOk = false;
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        expect(
          rig.bridge.startedLocales,
          hasLength(2),
          reason: 'the renewal was attempted and refused',
        );
        expect(errors, isEmpty, reason: 'below the cap a refusal is silent');

        rig.bridge.startOk = true;
        async.elapse(const Duration(milliseconds: 300));
        expect(
          rig.bridge.startedLocales,
          hasLength(3),
          reason: 'the refusal was retried once after the delay',
        );
        expect(errors, isEmpty);

        // Still listening: a further end renews again.
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(milliseconds: 300));
        expect(rig.bridge.startedLocales, hasLength(4));
        expect(errors, isEmpty);
      });
    });

    test('renewals refused to the cap report restartCapReached exactly once '
        'and stop', () {
      fakeAsync((async) {
        final rig = _rig();
        addTearDown(rig.engine.dispose);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();

        rig.bridge.startOk = false;
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(seconds: 2));
        expect(
          rig.bridge.startedLocales,
          hasLength(4),
          reason: 'initial start plus three refused renewals reach the cap',
        );
        expect(errors, [SttEngineErrorKind.restartCapReached]);

        // And no further start after the cap.
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(seconds: 2));
        expect(rig.bridge.startedLocales, hasLength(4));
        expect(errors, hasLength(1), reason: 'reported exactly once');
      });
    });

    test('a throwing renewal behaves like a refused one', () {
      fakeAsync((async) {
        final rig = _rig();
        addTearDown(rig.engine.dispose);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();

        rig.bridge.startError = Exception('platform-shaped failure');
        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(seconds: 2));
        expect(
          rig.bridge.startedLocales,
          hasLength(4),
          reason: 'initial start plus three throwing renewals reach the cap',
        );
        expect(errors, [SttEngineErrorKind.restartCapReached]);

        rig.bridge.sendEndOfSession();
        async.elapse(const Duration(seconds: 2));
        expect(rig.bridge.startedLocales, hasLength(4));
        expect(errors, hasLength(1), reason: 'reported exactly once');
      });
    });
  });

  group('BR-U10-40 error classes (TP-22)', () {
    test('codes 6 and 7 renew on a full-length session and are never '
        'counted', () {
      for (final code in [6, 7]) {
        fakeAsync((async) {
          final rig = _rig(restartCap: 1);
          addTearDown(rig.engine.dispose);
          final errors = <SttEngineErrorKind>[];
          rig.engine.setErrorListener((e) => errors.add(e.kind));
          unawaited(rig.engine.initialize());
          async.flushMicrotasks();
          unawaited(
            rig.engine.startListening(
              localeId: 'en-CA',
              onResult: _Results().add,
            ),
          );
          async.flushMicrotasks();

          // Past 90% of the 60-minute length: a silence code on a
          // full-length session is the normal renewal of BR-U10-39, and a
          // cap of 1 proves the silence path never counts (the transient
          // budget would have reported at once).
          rig.clock.advance(const Duration(minutes: 55));
          rig.bridge.sendError(code);
          async.elapse(const Duration(seconds: 1));

          expect(
            rig.bridge.startedLocales,
            ['en-CA', 'en-CA'],
            reason: 'code $code renews',
          );
          expect(errors, isEmpty, reason: 'code $code is silence');
        });
      }
    });

    test('lasting codes report one error and never start again', () {
      const expectations = {
        9: SttEngineErrorKind.permissionRevoked,
        12: SttEngineErrorKind.localeUnsupported,
        13: SttEngineErrorKind.onDeviceModelMissing,
        14: SttEngineErrorKind.onDeviceModelMissing,
        15: SttEngineErrorKind.onDeviceModelMissing,
      };
      for (final entry in expectations.entries) {
        fakeAsync((async) {
          final rig = _rig();
          addTearDown(rig.engine.dispose);
          final errors = <SttEngineErrorKind>[];
          rig.engine.setErrorListener((e) => errors.add(e.kind));
          unawaited(rig.engine.initialize());
          async.flushMicrotasks();
          unawaited(
            rig.engine.startListening(
              localeId: 'en-CA',
              onResult: _Results().add,
            ),
          );
          async.flushMicrotasks();

          rig.bridge.sendError(entry.key);
          async.flushMicrotasks();
          rig.bridge.sendEndOfSession();
          async.elapse(const Duration(seconds: 5));

          expect(errors, [entry.value], reason: 'code ${entry.key}');
          expect(
            rig.bridge.startedLocales,
            ['en-CA'],
            reason: 'code ${entry.key} is lasting',
          );
        });
      }
    });

    test('every other code, and an unknown one, is transient and counts '
        'towards the cap', () {
      // Codes 5 and 11 recreate before the retry (BR-U10-41, TP-24), so one
      // of their two failures is spent on that branch; the rest count
      // directly.
      for (final code in [1, 2, 3, 4, 8, 10, 99]) {
        fakeAsync((async) {
          final rig = _rig(restartCap: 2);
          addTearDown(rig.engine.dispose);
          final errors = <SttEngineErrorKind>[];
          rig.engine.setErrorListener((e) => errors.add(e.kind));
          unawaited(rig.engine.initialize());
          async.flushMicrotasks();
          unawaited(
            rig.engine.startListening(
              localeId: 'en-CA',
              onResult: _Results().add,
            ),
          );
          async.flushMicrotasks();

          // Two failing ends of session reach the cap and report once.
          rig.bridge.sendError(code);
          rig.bridge.sendEndOfSession();
          async.elapse(const Duration(seconds: 1));
          rig.bridge
            ..sendError(code)
            ..sendEndOfSession();
          async.elapse(const Duration(seconds: 1));

          expect(
            errors,
            [SttEngineErrorKind.restartCapReached],
            reason: 'code $code counts towards the cap',
          );
          expect(rig.bridge.startedLocales, hasLength(2), reason: 'code $code');
        });
      }
    });
  });

  group('BR-U10-40 a lone transient code is retried then capped', () {
    test('without an end of session, each code retries once and the second '
        'reaches the cap', () {
      for (final code in [1, 2, 3, 4, 8, 10, 99]) {
        fakeAsync((async) {
          final rig = _rig(restartCap: 2);
          addTearDown(rig.engine.dispose);
          final errors = <SttEngineErrorKind>[];
          rig.engine.setErrorListener((e) => errors.add(e.kind));
          unawaited(rig.engine.initialize());
          async.flushMicrotasks();
          unawaited(
            rig.engine.startListening(
              localeId: 'en-CA',
              onResult: _Results().add,
            ),
          );
          async.flushMicrotasks();

          rig.bridge.sendError(code);
          async.elapse(const Duration(seconds: 1));
          expect(
            rig.bridge.startedLocales,
            hasLength(2),
            reason: 'code $code alone schedules the retry',
          );
          expect(errors, isEmpty, reason: 'code $code is below the cap');

          rig.bridge.sendError(code);
          async.elapse(const Duration(seconds: 1));
          expect(
            errors,
            [SttEngineErrorKind.restartCapReached],
            reason: 'code $code reaches the cap',
          );
          expect(rig.bridge.startedLocales, hasLength(2), reason: 'code $code');
        });
      }
    });
  });

  group('BR-U10-41 recreate after a dead service (TP-24)', () {
    test('codes 5 and 11 recreate before the retry', () {
      for (final code in [5, 11]) {
        fakeAsync((async) {
          final rig = _rig();
          addTearDown(rig.engine.dispose);
          unawaited(rig.engine.initialize());
          async.flushMicrotasks();
          unawaited(
            rig.engine.startListening(
              localeId: 'en-CA',
              onResult: _Results().add,
            ),
          );
          async.flushMicrotasks();

          rig.bridge
            ..sendError(code)
            ..sendEndOfSession();
          async.elapse(const Duration(seconds: 1));

          expect(
            rig.log.entries,
            [
              'check:en-CA:true',
              'segment-start:en-CA:3600000',
              'segment-recreate',
              'check:en-CA:true',
              'segment-start:en-CA:3600000',
            ],
            reason: 'code $code recreates',
          );
        });
      }
    });

    test('no other code recreates', () {
      for (final code in [1, 2, 3, 4, 6, 7, 8, 10, 12, 13, 14, 15, 99]) {
        fakeAsync((async) {
          final rig = _rig();
          addTearDown(rig.engine.dispose);
          unawaited(rig.engine.initialize());
          async.flushMicrotasks();
          unawaited(
            rig.engine.startListening(
              localeId: 'en-CA',
              onResult: _Results().add,
            ),
          );
          async.flushMicrotasks();

          rig.bridge.sendError(code);
          async.elapse(const Duration(seconds: 1));

          expect(rig.log.where('segment-recreate'), isEmpty, reason: '$code');
        });
      }
    });
  });

  group('BR-U10-42 stop, pause and resume win over every await', () {
    test('a stop while the check is held prevents the start', () {
      fakeAsync((async) {
        final rig = _rig();
        addTearDown(rig.engine.dispose);
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        final held = Completer<void>();
        rig.checker.hangNext = held.future;
        var started = true;

        unawaited(
          rig.engine
              .startListening(localeId: 'en-CA', onResult: _Results().add)
              .then((ok) => started = ok),
        );
        async.flushMicrotasks();
        unawaited(rig.engine.stopListening());
        async.flushMicrotasks();
        held.complete();
        async.flushMicrotasks();

        expect(started, isFalse);
        expect(rig.bridge.startedLocales, isEmpty);
      });
    });

    test('a stop while the start is held cancels the session it began', () {
      fakeAsync((async) {
        final rig = _rig();
        addTearDown(rig.engine.dispose);
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        final held = Completer<void>();
        rig.bridge.startGate = held.future;
        var started = true;

        unawaited(
          rig.engine
              .startListening(localeId: 'en-CA', onResult: _Results().add)
              .then((ok) => started = ok),
        );
        async.flushMicrotasks();
        unawaited(rig.engine.stopListening());
        async.flushMicrotasks();
        held.complete();
        async.flushMicrotasks();

        expect(started, isFalse);
        expect(rig.log.where('segment-cancel'), isNotEmpty);
      });
    });

    test('a pause stops the session and a resume starts a checked one', () {
      fakeAsync((async) {
        final rig = _rig();
        addTearDown(rig.engine.dispose);
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();

        var paused = false;
        unawaited(rig.engine.pause().then((ok) => paused = ok));
        // The pause waits out its short drain (BR-U10-55) before returning.
        async.elapse(const Duration(milliseconds: 50));
        expect(paused, isTrue);
        expect(rig.log.where('segment-stop'), isNotEmpty);

        var resumed = false;
        unawaited(rig.engine.resume().then((ok) => resumed = ok));
        async.flushMicrotasks();
        expect(resumed, isTrue);
        expect(rig.bridge.startedLocales, ['en-CA', 'en-CA']);
        expect(rig.checker.localesChecked, ['en-CA', 'en-CA']);
      });
    });

    test('a resume without a session is false', () async {
      final rig = _rig();
      addTearDown(rig.engine.dispose);
      expect(await rig.engine.resume(), isFalse);
    });

    test('stopListening stops the session', () async {
      final rig = _rig();
      addTearDown(rig.engine.dispose);
      await rig.engine.initialize();
      await rig.engine.startListening(
        localeId: 'en-CA',
        onResult: _Results().add,
      );

      await rig.engine.stopListening();

      expect(rig.log.where('segment-stop'), hasLength(1));
    });
  });

  group('BR-U10-55 the last phrase is drained (TP-34)', () {
    final production = defaultSttListeningLimits.finalResultDrainTimeout;

    /// Starts a session inside the fake-async zone.
    void startSession(
      FakeAsync async,
      ({
        SegmentedSpeechEngine engine,
        FakeSegmentedRecognizerBridge bridge,
        FakeOnDeviceChecker checker,
        CallLog log,
        _Clock clock,
      })
      rig,
      _Results results,
    ) {
      unawaited(rig.engine.initialize());
      async.flushMicrotasks();
      unawaited(
        rig.engine.startListening(localeId: 'en-CA', onResult: results.add),
      );
      async.flushMicrotasks();
    }

    test('the default drain timeout is one second', () {
      expect(production, const Duration(seconds: 1));
    });

    for (final pause in [false, true]) {
      final name = pause ? 'pause' : 'stop';

      test('a final segment after $name() is delivered once, before the call '
          'returns', () {
        fakeAsync((async) {
          final rig = _rig(drainTimeout: production);
          addTearDown(rig.engine.dispose);
          final results = _Results();
          startSession(async, rig, results);
          final order = <String>[];

          unawaited(
            (pause ? rig.engine.pause() : rig.engine.stopListening()).then(
              (_) => order.add('returned'),
            ),
          );
          async.flushMicrotasks();
          expect(order, isEmpty, reason: 'waiting for the last phrase');
          rig.bridge.sendSegment(' the last phrase ');
          async.flushMicrotasks();
          order.add('after');

          expect(results.texts, ['the last phrase']);
          expect(results.finals, [true]);
          expect(order, ['returned', 'after']);
          // The platform session is cancelled on stop and left on pause.
          expect(
            rig.log.where('segment-cancel'),
            pause ? isEmpty : hasLength(1),
          );
          expect(rig.bridge.startedLocales, ['en-CA'], reason: 'no restart');
        });
      });

      test('a result after the $name() deadline is never delivered', () {
        fakeAsync((async) {
          final rig = _rig(drainTimeout: production);
          addTearDown(rig.engine.dispose);
          final results = _Results();
          startSession(async, rig, results);
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

          rig.bridge
            ..sendSegment('too late')
            ..sendPartial('too late');
          async.elapse(const Duration(seconds: 5));
          expect(results.texts, isEmpty);
          expect(rig.bridge.startedLocales, ['en-CA']);
        });
      });

      test('a pending partial with no final is delivered once as final at '
          'the end of the $name() wait', () {
        fakeAsync((async) {
          final rig = _rig(drainTimeout: production);
          addTearDown(rig.engine.dispose);
          final results = _Results();
          startSession(async, rig, results);
          rig.bridge.sendPartial('almost there');
          async.flushMicrotasks();

          unawaited(pause ? rig.engine.pause() : rig.engine.stopListening());
          async.elapse(production + const Duration(milliseconds: 1));

          expect(results.texts, ['almost there', 'almost there']);
          expect(results.finals, [false, true]);
        });
      });

      test('a partial that arrives during the $name() wait is flushed as '
          'final too, and only once', () {
        fakeAsync((async) {
          final rig = _rig(drainTimeout: production);
          addTearDown(rig.engine.dispose);
          final results = _Results();
          startSession(async, rig, results);

          unawaited(pause ? rig.engine.pause() : rig.engine.stopListening());
          async.flushMicrotasks();
          rig.bridge.sendPartial('during the wait');
          async.elapse(production + const Duration(seconds: 3));

          // The drain remembers a partial; it does not show it as interim.
          expect(results.texts, ['during the wait']);
          expect(results.finals, [true]);
        });
      });

      test('the end of session ends the $name() wait early and renews '
          'nothing', () {
        fakeAsync((async) {
          final rig = _rig(drainTimeout: production);
          addTearDown(rig.engine.dispose);
          final errors = <SttEngineErrorKind>[];
          rig.engine.setErrorListener((e) => errors.add(e.kind));
          startSession(async, rig, _Results());
          var returned = false;

          unawaited(
            (pause ? rig.engine.pause() : rig.engine.stopListening()).then(
              (_) => returned = true,
            ),
          );
          async.flushMicrotasks();
          rig.bridge.sendEndOfSession();
          async.flushMicrotasks();

          expect(returned, isTrue, reason: 'no need to wait the full second');
          async.elapse(const Duration(seconds: 10));
          expect(rig.bridge.startedLocales, ['en-CA']);
          expect(rig.checker.localesChecked, ['en-CA']);
          expect(errors, isEmpty);
        });
      });

      test('an error code during the $name() wait ends it and counts, '
          'recreates and reports nothing', () {
        fakeAsync((async) {
          // A cap of 1 would report on any counted failure.
          final rig = _rig(restartCap: 1, drainTimeout: production);
          addTearDown(rig.engine.dispose);
          final errors = <SttEngineErrorKind>[];
          rig.engine.setErrorListener((e) => errors.add(e.kind));
          startSession(async, rig, _Results());
          var returned = false;

          unawaited(
            (pause ? rig.engine.pause() : rig.engine.stopListening()).then(
              (_) => returned = true,
            ),
          );
          async.flushMicrotasks();
          rig.bridge.sendError(5);
          async.flushMicrotasks();

          expect(returned, isTrue);
          async.elapse(const Duration(seconds: 10));
          expect(rig.bridge.startedLocales, ['en-CA']);
          expect(rig.log.where('segment-recreate'), isEmpty);
          expect(errors, isEmpty);
        });
      });
    }

    test('only the first final segment of a drain is delivered', () {
      fakeAsync((async) {
        final rig = _rig(drainTimeout: production);
        addTearDown(rig.engine.dispose);
        final results = _Results();
        startSession(async, rig, results);

        unawaited(rig.engine.stopListening());
        async.flushMicrotasks();
        rig.bridge
          ..sendSegment('first')
          ..sendSegment('second');
        async.elapse(const Duration(seconds: 2));

        expect(results.texts, ['first']);
      });
    });

    test('an empty segment does not end the wait', () {
      fakeAsync((async) {
        final rig = _rig(drainTimeout: production);
        addTearDown(rig.engine.dispose);
        final results = _Results();
        startSession(async, rig, results);

        unawaited(rig.engine.stopListening());
        async.flushMicrotasks();
        rig.bridge
          ..sendSegment('   ')
          ..sendSegment('real');
        async.flushMicrotasks();

        expect(results.texts, ['real']);
      });
    });

    test('a stop whose platform call returns after a new start does not '
        'cancel the new session (Amendment 06 revision 3)', () {
      fakeAsync((async) {
        final rig = _rig(drainTimeout: production);
        addTearDown(rig.engine.dispose);
        final results = _Results();
        startSession(async, rig, results);
        final stalled = Completer<void>();
        rig.bridge.stopGate = stalled.future;

        unawaited(rig.engine.stopListening());
        async.flushMicrotasks();
        // The user starts again while the stop is stuck in the platform.
        var restarted = false;
        unawaited(
          rig.engine
              .startListening(localeId: 'en-CA', onResult: results.add)
              .then((ok) => restarted = ok),
        );
        async.flushMicrotasks();
        final startsBefore = rig.log.where('segment-start').length;
        final afterNewStart = rig.log.entries.length;

        stalled.complete();
        async.elapse(const Duration(seconds: 2));

        expect(restarted, isTrue, reason: 'replacement start');
        expect(rig.bridge.startedLocales, ['en-CA', 'en-CA']);
        expect(rig.log.where('segment-start').length, startsBefore);
        expect(
          rig.log.entries.skip(afterNewStart),
          isNot(contains('segment-cancel')),
          reason: 'the late cancel would end the new session',
        );
      });
    });

    // Amendment 06 revision 3: abandoned work never touches a new session. A
    // stop or pause stuck in the platform keeps its drain open; a new session
    // must not run inside it.
    for (final isPause in [false, true]) {
      final name = isPause ? 'pause' : 'stop';

      test('a new session started while a hung $name() is pending is not '
          'held in its drain (Amendment 06 revision 3)', () {
        fakeAsync((async) {
          final rig = _rig(drainTimeout: production);
          addTearDown(rig.engine.dispose);
          final results = _Results();
          startSession(async, rig, results);
          final stalled = Completer<void>();
          rig.bridge.stopGate = stalled.future;

          unawaited(isPause ? rig.engine.pause() : rig.engine.stopListening());
          async.flushMicrotasks();
          unawaited(
            isPause
                ? rig.engine.resume()
                : rig.engine.startListening(
                    localeId: 'en-CA',
                    onResult: results.add,
                  ),
          );
          async.flushMicrotasks();
          final cancelsBefore = rig.log.where('segment-cancel').length;

          rig.bridge
            ..sendPartial('hello')
            ..sendSegment('hello there')
            ..sendSegment('and more')
            ..sendPartial('tail');
          async.flushMicrotasks();
          expect(
            results.texts,
            ['hello', 'hello there', 'and more', 'tail'],
            reason: 'the new session is shown as it speaks',
          );
          expect(results.finals, [false, true, true, false]);

          stalled.complete();
          async.flushMicrotasks();
          expect(
            results.texts,
            ['hello', 'hello there', 'and more', 'tail'],
            reason: 'the old stop delivers nothing',
          );
          expect(rig.log.where('segment-cancel').length, cancelsBefore);

          // The new session's pending partial survived the old stop.
          unawaited(rig.engine.stopListening());
          async.elapse(const Duration(seconds: 2));
          expect(results.texts.last, 'tail');
          expect(results.finals.last, isTrue);
          expect(results.texts, hasLength(5));
        });
      });
    }

    // BR-U10-55: a Stop that arrives inside Pause's open drain joins it, so
    // the last phrase is not lost.
    for (final withFinal in [true, false]) {
      test('a stop during the pause() drain keeps the last phrase '
          '(${withFinal ? 'a final arrives' : 'no final arrives'})', () {
        fakeAsync((async) {
          final rig = _rig(drainTimeout: production);
          addTearDown(rig.engine.dispose);
          final results = _Results();
          startSession(async, rig, results);
          rig.bridge.sendPartial('hello');
          async.flushMicrotasks();
          var pauseDone = false;
          var stopDone = false;

          unawaited(rig.engine.pause().then((_) => pauseDone = true));
          async.flushMicrotasks();
          unawaited(rig.engine.stopListening().then((_) => stopDone = true));
          async.flushMicrotasks();

          expect(stopDone, isFalse, reason: 'the stop waits for the drain');
          expect(
            rig.log.where('segment-cancel').length,
            0,
            reason: 'no cancel before the drain',
          );

          if (withFinal) {
            rig.bridge.sendSegment('hello there');
            async.flushMicrotasks();
          } else {
            async.elapse(const Duration(seconds: 2));
          }

          expect(pauseDone, isTrue);
          expect(stopDone, isTrue);
          expect(
            rig.log.where('segment-cancel').length,
            1,
            reason: 'cancel after the drain',
          );
          final last = withFinal ? 'hello there' : 'hello';
          final expected = ['hello', last];
          expect(results.texts, expected);
          expect(results.finals, [false, true]);

          async.elapse(const Duration(seconds: 5));
          expect(
            results.texts,
            expected,
            reason: 'nothing is delivered twice',
          );
        });
      });
    }

    test('a stop with no live session does not wait', () {
      fakeAsync((async) {
        final rig = _rig(drainTimeout: production);
        addTearDown(rig.engine.dispose);
        var returned = false;

        unawaited(rig.engine.stopListening().then((_) => returned = true));
        async.flushMicrotasks();

        expect(returned, isTrue);
      });
    });

    test('a resume after a drained pause starts a fresh checked session', () {
      fakeAsync((async) {
        final rig = _rig(drainTimeout: production);
        addTearDown(rig.engine.dispose);
        final results = _Results();
        startSession(async, rig, results);

        unawaited(rig.engine.pause());
        async.flushMicrotasks();
        rig.bridge.sendSegment('kept');
        async.flushMicrotasks();
        var resumed = false;
        unawaited(rig.engine.resume().then((ok) => resumed = ok));
        async.flushMicrotasks();

        expect(resumed, isTrue);
        expect(results.texts, ['kept']);
        expect(rig.bridge.startedLocales, ['en-CA', 'en-CA']);
      });
    });
  });

  group('review fix #5: the stream onError honours the live-session guard', () {
    /// Starts a session and returns the rig.
    ({
      SegmentedSpeechEngine engine,
      FakeSegmentedRecognizerBridge bridge,
      FakeOnDeviceChecker checker,
      CallLog log,
      _Clock clock,
    })
    liveRig(FakeAsync async, {Duration? drain}) {
      final rig = _rig(restartCap: 1, drainTimeout: drain ?? Duration.zero);
      addTearDown(rig.engine.dispose);
      unawaited(rig.engine.initialize());
      async.flushMicrotasks();
      unawaited(
        rig.engine.startListening(localeId: 'en-CA', onResult: _Results().add),
      );
      async.flushMicrotasks();
      return rig;
    }

    test(
      'a stream error while listening still counts as a transient failure',
      () {
        fakeAsync((async) {
          final rig = liveRig(async);
          final errors = <SttEngineErrorKind>[];
          rig.engine.setErrorListener((e) => errors.add(e.kind));

          rig.bridge.sendStreamError(StateError('channel'));
          async.flushMicrotasks();

          expect(errors, [SttEngineErrorKind.restartCapReached]);
        });
      },
    );

    test('a stream error after stop counts nothing, reports nothing and '
        'starts nothing', () {
      fakeAsync((async) {
        final rig = liveRig(async);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        unawaited(rig.engine.stopListening());
        async.elapse(const Duration(seconds: 1));

        rig.bridge.sendStreamError(StateError('channel'));
        async.elapse(const Duration(seconds: 5));

        expect(errors, isEmpty);
        expect(rig.bridge.startedLocales, ['en-CA']);
      });
    });

    test('a stream error after pause counts nothing and starts nothing', () {
      fakeAsync((async) {
        final rig = liveRig(async);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        unawaited(rig.engine.pause());
        async.elapse(const Duration(seconds: 1));

        rig.bridge.sendStreamError(StateError('channel'));
        async.elapse(const Duration(seconds: 5));

        expect(errors, isEmpty);
        expect(rig.bridge.startedLocales, ['en-CA']);
      });
    });

    test('a stream error while a resume is in flight counts nothing', () {
      fakeAsync((async) {
        final rig = liveRig(async);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        unawaited(rig.engine.pause());
        async.flushMicrotasks();
        final held = Completer<void>();
        rig.checker.hangNext = held.future;
        unawaited(rig.engine.resume());
        async.flushMicrotasks();

        rig.bridge.sendStreamError(StateError('channel'));
        async.elapse(const Duration(seconds: 1));

        expect(errors, isEmpty);
        held.complete();
        async.flushMicrotasks();
      });
    });

    test('a stream error during a drain ends the wait without a count', () {
      fakeAsync((async) {
        final rig = liveRig(
          async,
          drain: defaultSttListeningLimits.finalResultDrainTimeout,
        );
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        var returned = false;
        unawaited(rig.engine.stopListening().then((_) => returned = true));
        async.flushMicrotasks();

        rig.bridge.sendStreamError(StateError('channel'));
        async.flushMicrotasks();

        expect(returned, isTrue);
        expect(errors, isEmpty);
        async.elapse(const Duration(seconds: 5));
        expect(rig.bridge.startedLocales, ['en-CA']);
      });
    });
  });

  group('spike pin (Amendment 03 section 1)', () {
    test('two phrases eight seconds apart arrive as two final segments and '
        'the session renews at the requested length', () {
      fakeAsync((async) {
        final rig = _rig(sessionLength: const Duration(seconds: 40));
        addTearDown(rig.engine.dispose);
        final results = _Results();
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(localeId: 'en-US', onResult: results.add),
        );
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 3));
        rig.bridge.sendPartial('Hello there');
        async.elapse(const Duration(milliseconds: 600));
        rig.bridge.sendSegment('Hello there.');
        async.elapse(const Duration(seconds: 11));
        rig.bridge
          ..sendPartial(' This is the second sentence')
          ..sendSegment(' This is the second sentence.');
        async.elapse(const Duration(seconds: 26));
        // The session reached its requested length (40 s), so this is a
        // full-length end (BR-U10-39), not an early one (BR-U10-44). The
        // renewal waits restartDelay (BR-U10-45).
        rig.clock.advance(const Duration(seconds: 40));
        rig.bridge.sendEndOfSession();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 300));

        // BR-U10-38 trims segments only. A partial keeps the platform's
        // leading space, and the segment that follows it is its final.
        expect(results.texts, [
          'Hello there',
          'Hello there.',
          ' This is the second sentence',
          'This is the second sentence.',
        ]);
        expect(results.finals, [false, true, false, true]);
        expect(rig.bridge.startedMinimumLengths.first, 40000);
        expect(rig.bridge.startedLocales, ['en-US', 'en-US']);
      });
    });
  });

  group('BR-U10-50 supportedLocales (TP-31)', () {
    test('maps each tag to a SpeechLocale, in order', () async {
      final rig = _rig();
      addTearDown(rig.engine.dispose);
      rig.bridge.supportedLocaleTags = ['en-US', 'fr-CA', 'de'];

      final locales = await rig.engine.supportedLocales();

      expect(locales.map((l) => l.localeId), ['en-US', 'fr-CA', 'de']);
      expect(locales.map((l) => l.displayName), ['en-US', 'fr-CA', 'de']);
    });

    test('an empty runner list is an empty list', () async {
      final rig = _rig();
      addTearDown(rig.engine.dispose);

      expect(await rig.engine.supportedLocales(), isEmpty);
    });

    test(
      'a throwing bridge gives an empty list and logs the type only',
      () async {
        final rig = _rig();
        addTearDown(rig.engine.dispose);
        rig.bridge.supportedLocalesError = const FormatException(
          'secret words',
        );
        final records = <LogRecord>[];
        Logger.root.level = Level.ALL;
        final sub = Logger.root.onRecord.listen(records.add);
        addTearDown(sub.cancel);

        expect(await rig.engine.supportedLocales(), isEmpty);
        expect(
          records.map((r) => r.message),
          contains(contains('FormatException')),
        );
        // Nothing on any record, not only its message, carries the secret.
        for (final r in records) {
          expect(r.message, isNot(contains('secret words')));
          expect(r.object?.toString() ?? '', isNot(contains('secret words')));
          expect(r.error?.toString() ?? '', isNot(contains('secret words')));
          expect(
            r.stackTrace?.toString() ?? '',
            isNot(contains('secret words')),
          );
        }
      },
    );
  });

  group('review fix F1: codes 5 and 11 are counted', () {
    test('a service that dies with the code after every successful start '
        'reaches the cap once and stops', () {
      for (final code in [5, 11]) {
        fakeAsync((async) {
          final rig = _rig();
          addTearDown(rig.engine.dispose);
          final errors = <SttEngineErrorKind>[];
          rig.engine.setErrorListener((e) => errors.add(e.kind));
          unawaited(rig.engine.initialize());
          async.flushMicrotasks();
          unawaited(
            rig.engine.startListening(
              localeId: 'en-CA',
              onResult: _Results().add,
            ),
          );
          async.flushMicrotasks();

          // Every renewal starts successfully and the service dies again.
          for (var i = 0; i < 10; i++) {
            rig.bridge.sendError(code);
            async.elapse(const Duration(seconds: 1));
          }

          expect(
            errors,
            [SttEngineErrorKind.restartCapReached],
            reason: 'code $code reports exactly once',
          );
          expect(
            rig.bridge.startedLocales,
            hasLength(3),
            reason: 'code $code: no start after the cap',
          );
          expect(
            rig.log.where('segment-recreate'),
            hasLength(2),
            reason:
                'code $code: the failure that reaches the cap does not '
                'recreate',
          );
        });
      }
    });
  });

  group('review fix F2: late events from a superseded session', () {
    test('an end and errors arriving while a resume is held open start '
        'nothing and count nothing', () {
      fakeAsync((async) {
        final rig = _rig(restartCap: 2);
        addTearDown(rig.engine.dispose);
        final errors = <SttEngineErrorKind>[];
        rig.engine.setErrorListener((e) => errors.add(e.kind));
        unawaited(rig.engine.initialize());
        async.flushMicrotasks();
        unawaited(
          rig.engine.startListening(
            localeId: 'en-CA',
            onResult: _Results().add,
          ),
        );
        async.flushMicrotasks();
        unawaited(rig.engine.pause());
        async.flushMicrotasks();

        final held = Completer<void>();
        rig.checker.hangNext = held.future;
        var resumed = false;
        unawaited(rig.engine.resume().then((ok) => resumed = ok));
        async.flushMicrotasks();

        // The previous session's trailing events, mid-resume.
        rig.bridge
          ..sendEndOfSession()
          ..sendError(7)
          ..sendError(1);
        async.elapse(const Duration(seconds: 1));
        expect(
          rig.bridge.startedLocales,
          hasLength(1),
          reason: 'no renewal runs beside the held resume',
        );

        held.complete();
        async.flushMicrotasks();
        expect(resumed, isTrue);
        expect(rig.bridge.startedLocales, hasLength(2));
        async.elapse(const Duration(seconds: 5));
        expect(rig.bridge.startedLocales, hasLength(2));
        expect(errors, isEmpty, reason: 'nothing was counted');
      });
    });
  });

  group('dispose', () {
    test('cancels the session and releases the bridge', () async {
      final rig = _rig();
      await rig.engine.initialize();
      await rig.engine.startListening(
        localeId: 'en-CA',
        onResult: _Results().add,
      );

      rig.engine.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(rig.log.where('segment-cancel'), isNotEmpty);
      expect(rig.log.where('segment-dispose'), isNotEmpty);
    });
  });
}

/// Runs [start] and returns its answer, whatever the engine does with an
/// exception from the bridge.
Future<bool> _starting(Future<bool> start) async {
  try {
    return await start;
  } on Object {
    return false;
  }
}
