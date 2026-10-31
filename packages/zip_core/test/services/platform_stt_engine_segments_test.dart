import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:zip_core/src/constants/stt_listening_limits.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/stt/engines/platform_stt_engine.dart';

import '../helpers/fake_on_device_checker.dart';
import '../helpers/fake_speech_to_text.dart';
import '../helpers/mock_audio_device_service.dart';
import '../helpers/pbt.dart' as pbt;

// Unit 10, Amendment 08: a pause ends a segment (BR-U10-68), later text is
// trimmed by committed word count (BR-U10-69), the drain applies to the
// trimmed text (BR-U10-70) and the listen call asks for punctuation
// (BR-U10-71). TP-45 to TP-48.

void main() {
  const pause = Duration(milliseconds: 1500);
  final drain = defaultSttListeningLimits.finalResultDrainTimeout;

  ({
    PlatformSttEngine engine,
    FakeSpeechToText stt,
    List<SttResult> results,
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
    unawaited(engine.initialize());
    async.flushMicrotasks();
    unawaited(
      engine.startListening(localeId: 'en-US', onResult: results.add),
    );
    async.flushMicrotasks();
    return (engine: engine, stt: stt, results: results);
  }

  List<String> finals(List<SttResult> results) =>
      results.where((r) => r.isFinal).map((r) => r.text).toList();

  test('iosSegmentPause defaults to 1.5 s (BR-U10-68)', () {
    expect(defaultSttListeningLimits.iosSegmentPause, pause);
  });

  group('pause commit (BR-U10-68, TP-45)', () {
    test('interim then 1.5 s of silence gives exactly one final, and the '
        'plugin is neither stopped nor cancelled', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult('hello', isFinal: false);
        async.elapse(const Duration(milliseconds: 400));
        rig.stt.emitResult('hello there', isFinal: false);
        async.elapse(pause - const Duration(milliseconds: 1));
        expect(finals(rig.results), isEmpty, reason: 'timer re-armed');
        async.elapse(const Duration(milliseconds: 1));

        expect(finals(rig.results), ['hello there']);
        expect(rig.stt.stopCalls, 0);
        expect(rig.stt.cancelCalls, 0);
        expect(rig.stt.listenCalls, hasLength(1));
        async.elapse(const Duration(seconds: 10));
        expect(finals(rig.results), ['hello there'], reason: 'delivered once');
      });
    });

    test('more interim text after a commit gives a final of only the new '
        'words', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult('Hello, world.', isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult('Hello, world. How are', isFinal: false);
        async.elapse(const Duration(milliseconds: 200));
        rig.stt.emitResult('Hello, world. How are you?', isFinal: false);
        async.elapse(pause);

        expect(finals(rig.results), ['Hello, world.', 'How are you?']);
        // Interims after the commit carry only the new words too.
        expect(
          rig.results.where((r) => !r.isFinal).map((r) => r.text),
          ['Hello, world.', 'How are', 'How are you?'],
        );
        expect(rig.stt.stopCalls, 0);
        expect(rig.stt.cancelCalls, 0);
      });
    });

    test('a pause with no pending text delivers nothing', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        async.elapse(const Duration(seconds: 10));
        expect(rig.results, isEmpty);

        rig.stt.emitResult('one two', isFinal: false);
        async.elapse(pause);
        // Same cumulative text again: no new words, nothing delivered.
        rig.stt.emitResult('one two', isFinal: false);
        async.elapse(const Duration(seconds: 10));

        expect(rig.results.map((r) => r.text), ['one two', 'one two']);
        expect(finals(rig.results), ['one two']);
      });
    });

    test('a plugin final cancels the pause timer', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt
          ..emitResult('a b', isFinal: false)
          ..emitResult('a b c', isFinal: true);
        async.elapse(const Duration(seconds: 10));

        expect(finals(rig.results), ['a b c']);
      });
    });

    for (final name in ['stop', 'pause']) {
      test('$name() cancels the pause timer', () {
        fakeAsync((async) {
          final rig = live(async);
          addTearDown(rig.engine.dispose);
          rig.stt.emitResult('a b', isFinal: false);
          async.elapse(const Duration(milliseconds: 500));

          unawaited(
            name == 'stop' ? rig.engine.stopListening() : rig.engine.pause(),
          );
          async.flushMicrotasks();
          rig.stt.emitStatus('done');
          async.elapse(const Duration(seconds: 10));

          // The drain flush is the only final; the timer added no second one.
          expect(finals(rig.results), ['a b']);
        });
      });
    }

    test('a lasting error cancels the pause timer', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);
        rig.stt.emitResult('a b', isFinal: false);
        async.flushMicrotasks();

        rig.stt.emitError('error_permission');
        async.elapse(const Duration(seconds: 10));

        expect(finals(rig.results), isEmpty);
      });
    });

    test('dispose cancels the pause timer', () {
      fakeAsync((async) {
        final rig = live(async);
        rig.stt.emitResult('a b', isFinal: false);
        async.flushMicrotasks();

        rig.engine.dispose();
        async.elapse(const Duration(seconds: 10));

        expect(finals(rig.results), isEmpty);
      });
    });

    test('the engine uses the injected iosSegmentPause', () {
      fakeAsync((async) {
        final stt = FakeSpeechToText();
        final audio = MockAudioDeviceService();
        when(() => audio.currentPreferredDeviceId).thenReturn(null);
        final engine = PlatformSttEngine(
          stt: stt,
          deviceService: audio,
          onDeviceSupportChecker: FakeOnDeviceChecker().call,
          limits: const SttListeningLimits(
            restartCap: 3,
            immediateFailureWindow: Duration(seconds: 2),
            restartDelay: Duration(milliseconds: 250),
            onDeviceCheckTimeout: Duration(seconds: 2),
            segmentedSessionLength: Duration(minutes: 5),
            iosSegmentPause: Duration(milliseconds: 300),
          ),
        );
        addTearDown(engine.dispose);
        final results = <SttResult>[];
        unawaited(engine.initialize());
        async.flushMicrotasks();
        unawaited(
          engine.startListening(localeId: 'en-US', onResult: results.add),
        );
        async.flushMicrotasks();

        stt.emitResult('quick', isFinal: false);
        async.elapse(const Duration(milliseconds: 300));

        expect(finals(results), ['quick']);
      });
    });
  });

  group('trim by committed word count (BR-U10-69, TP-46)', () {
    test('a plugin final at the session end delivers only the uncommitted '
        'words, or nothing', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult('a b c', isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult('a b c d e', isFinal: false);
        async.elapse(const Duration(milliseconds: 100));
        rig.stt.emitResult('a b c d e', isFinal: true);
        async.flushMicrotasks();

        expect(finals(rig.results), ['a b c', 'd e']);
      });
    });

    test(
      'a plugin final with every word already committed delivers nothing',
      () {
        fakeAsync((async) {
          final rig = live(async);
          addTearDown(rig.engine.dispose);

          rig.stt.emitResult('a b c', isFinal: false);
          async.elapse(pause);
          rig.stt.emitResult('a b c', isFinal: true);
          async.elapse(const Duration(seconds: 10));

          expect(finals(rig.results), ['a b c']);
        });
      },
    );

    test('a restart (done then a new listen) resets the count', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult('one two three', isFinal: false);
        async.elapse(pause);
        rig.stt.emitStatus('done');
        async.elapse(const Duration(seconds: 1));
        expect(rig.stt.listenCalls, hasLength(2), reason: 'restarted');

        rig.stt.emitResult('four five', isFinal: false);
        async.elapse(pause);

        expect(finals(rig.results), ['one two three', 'four five']);
      });
    });

    test('a resume resets the count', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult('one two', isFinal: false);
        async.elapse(pause);
        unawaited(rig.engine.pause());
        async.elapse(drain + const Duration(milliseconds: 1));
        unawaited(rig.engine.resume());
        async.flushMicrotasks();
        expect(rig.stt.listenCalls, hasLength(2));

        rig.stt.emitResult('three', isFinal: false);
        async.elapse(pause);

        expect(finals(rig.results), ['one two', 'three']);
      });
    });

    test("the words keep the plugin's punctuation and capitals", () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult('Dr. Smith, said:', isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult(
          'Dr. Smith, said: "Hello,\n  World!"',
          isFinal: true,
        );
        async.flushMicrotasks();

        expect(finals(rig.results), ['Dr. Smith, said:', '"Hello, World!"']);
      });
    });

    const tokens = [
      'Hello,',
      'world.',
      'and',
      'The',
      'quick?',
      'fox',
      '42',
      'a',
    ];

    pbt.Glados(
      pbt.any.listWithLengthInRange(
        1,
        20,
        pbt.any.combine2<int, bool, (int, bool)>(
          pbt.any.intInRange(1, 5),
          pbt.any.boolGen,
          (words, committed) => (words, committed),
        ),
      ),
    ).test(
      'delivered finals joined equal the last cumulative text, across '
      'commits',
      (steps) {
        fakeAsync((async) {
          final rig = live(async);
          final cumulative = <String>[];
          var n = 0;
          for (final (words, long) in steps) {
            for (var i = 0; i < words; i++) {
              cumulative.add(tokens[n++ % tokens.length]);
              rig.stt.emitResult(cumulative.join(' '), isFinal: false);
              async.elapse(const Duration(milliseconds: 200));
            }
            // A long gap commits; a short one leaves the text pending.
            async.elapse(
              long ? pause : const Duration(milliseconds: 300),
            );
          }
          async.elapse(pause);

          expect(finals(rig.results).join(' '), cumulative.join(' '));
          expect(rig.stt.stopCalls, 0);
          expect(rig.stt.cancelCalls, 0);
          rig.engine.dispose();
        });
      },
    );
  });

  group('reset of the cumulative text (BR-U10-69 revision 2, TP-46)', () {
    const first = 'one two three four five six';

    test('a shorter result that does not continue the committed words is '
        'delivered whole', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult(first, isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult('alpha beta', isFinal: false);
        async.elapse(pause);

        expect(finals(rig.results), [first, 'alpha beta']);
      });
    });

    test('a longer result that does not continue the committed words is '
        'delivered whole', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult(first, isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult(
          'alpha beta gamma delta epsilon zeta eta theta',
          isFinal: false,
        );
        async.elapse(pause);

        expect(finals(rig.results), [
          first,
          'alpha beta gamma delta epsilon zeta eta theta',
        ]);
      });
    });

    test('after a reset the plugin continues the reset text, and only the '
        'new words follow', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult(first, isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult('alpha beta', isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult('alpha beta gamma', isFinal: false);
        async.elapse(pause);

        expect(finals(rig.results), [first, 'alpha beta', 'gamma']);
      });
    });

    test('a revised committed word (case, punctuation or a different word) '
        'still counts as a continuation', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult(first, isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult(
          'One, two three four five six seven',
          isFinal: false,
        );
        async.elapse(pause);

        expect(finals(rig.results), [first, 'seven']);

        rig.stt.emitResult(
          'One, two three four five six seven eight',
          isFinal: false,
        );
        async.elapse(pause);
        rig.stt.emitResult(
          'one two tree four five six seven eight nine',
          isFinal: false,
        );
        async.elapse(pause);

        expect(finals(rig.results), [first, 'seven', 'eight', 'nine']);
      });
    });

    pbt.Glados(
      pbt.any.listWithLengthInRange(
        1,
        10,
        pbt.any.combine2<int, bool, (int, bool)>(
          pbt.any.intInRange(1, 5),
          pbt.any.boolGen,
          (words, continues) => (words, continues),
        ),
      ),
    ).test(
      'delivered finals joined equal the phrases joined, whether each phrase '
      'continues the cumulative text or resets it',
      (steps) {
        fakeAsync((async) {
          final rig = live(async);
          final cumulative = <String>[];
          final spoken = <String>[];
          var n = 0;
          for (final (words, continues) in steps) {
            // A reset starts the plugin's cumulative text afresh.
            if (!continues) cumulative.clear();
            for (var i = 0; i < words; i++) {
              // Every word is distinct, so no phrase shares words with another.
              final word = 'w${n++}';
              cumulative.add(word);
              spoken.add(word);
              rig.stt.emitResult(cumulative.join(' '), isFinal: false);
              async.elapse(const Duration(milliseconds: 200));
            }
            async.elapse(pause);
          }

          expect(finals(rig.results).join(' '), spoken.join(' '));
          rig.engine.dispose();
        });
      },
    );
  });

  group('languages without spaces (BR-U10-69 revision 3, TP-46)', () {
    test('Dart accepts the script escapes the tokenizer relies on', () {
      final scripts = RegExp(
        r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}'
        r'\p{Script=Thai}\p{Script=Lao}\p{Script=Khmer}\p{Script=Myanmar}]',
        unicode: true,
      );
      for (final char in ['你', 'い', 'カ', 'ก', 'ກ', 'ក', 'က']) {
        expect(scripts.hasMatch(char), isTrue, reason: char);
      }
      expect(scripts.hasMatch('a'), isFalse);
      expect(scripts.hasMatch('，'), isFalse);
    });

    test('Chinese: a commit, then the cumulative text, delivers only the '
        'new characters', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult('你好', isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult('你好世界', isFinal: false);
        async.elapse(pause);

        expect(finals(rig.results), ['你好', '世界']);
      });
    });

    test('Chinese punctuation added later does not shift the cut', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult('你好', isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult('你好，世界。', isFinal: false);
        async.elapse(pause);

        expect(finals(rig.results), ['你好', '世界。']);
      });
    });

    test('Japanese with kanji and kana', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult('今日は', isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult('今日はいい天気', isFinal: false);
        async.elapse(pause);

        expect(finals(rig.results), ['今日は', 'いい天気']);
      });
    });

    test('Thai: each character is a token, marks included', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult('สวัสดี', isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult('สวัสดีครับ', isFinal: false);
        async.elapse(pause);

        expect(finals(rig.results), ['สวัสดี', 'ครับ']);
      });
    });

    test('a reset in Chinese is delivered whole', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult('你好世界', isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult('谢谢', isFinal: false);
        async.elapse(pause);

        expect(finals(rig.results), ['你好世界', '谢谢']);
      });
    });

    test('one revised character still counts as a continuation', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult('一二三四', isFinal: false);
        async.elapse(pause);
        // The fourth character is revised and two are new.
        rig.stt.emitResult('一二三五六七', isFinal: false);
        async.elapse(pause);

        expect(finals(rig.results), ['一二三四', '六七']);
      });
    });

    pbt.Glados(
      pbt.any.listWithLengthInRange(
        1,
        10,
        pbt.any.combine2<int, bool, (int, bool)>(
          pbt.any.intInRange(1, 6),
          pbt.any.boolGen,
          (chars, continues) => (chars, continues),
        ),
      ),
    ).test(
      'delivered finals joined equal the characters spoken, whether each '
      'phrase continues the cumulative text or resets it',
      (steps) {
        fakeAsync((async) {
          final rig = live(async);
          final cumulative = <String>[];
          final spoken = <String>[];
          var n = 0;
          for (final (chars, continues) in steps) {
            if (!continues) cumulative.clear();
            for (var i = 0; i < chars; i++) {
              // Every character is distinct, so no phrase repeats another.
              final char = String.fromCharCode(0x4E00 + n++);
              cumulative.add(char);
              spoken.add(char);
              rig.stt.emitResult(cumulative.join(), isFinal: false);
              async.elapse(const Duration(milliseconds: 200));
            }
            async.elapse(pause);
          }

          expect(finals(rig.results).join(), spoken.join());
          rig.engine.dispose();
        });
      },
    );
  });

  group('drain after a commit (BR-U10-70, TP-47)', () {
    for (final isPause in [false, true]) {
      final name = isPause ? 'pause' : 'stop';

      test('$name() after a commit delivers only the new words, once', () {
        fakeAsync((async) {
          final rig = live(async);
          addTearDown(rig.engine.dispose);

          rig.stt.emitResult('one two', isFinal: false);
          async.elapse(pause);
          rig.stt.emitResult('one two three', isFinal: false);
          async.flushMicrotasks();

          unawaited(isPause ? rig.engine.pause() : rig.engine.stopListening());
          async.elapse(drain + const Duration(milliseconds: 1));

          expect(finals(rig.results), ['one two', 'three']);
          async.elapse(const Duration(seconds: 10));
          expect(finals(rig.results), ['one two', 'three']);
        });
      });

      test('a plugin final during the $name() drain is trimmed', () {
        fakeAsync((async) {
          final rig = live(async);
          addTearDown(rig.engine.dispose);

          rig.stt.emitResult('one two', isFinal: false);
          async.elapse(pause);

          unawaited(isPause ? rig.engine.pause() : rig.engine.stopListening());
          async.flushMicrotasks();
          rig.stt.emitResult('one two three four', isFinal: true);
          async.elapse(const Duration(seconds: 5));

          expect(finals(rig.results), ['one two', 'three four']);
        });
      });

      test('$name() with everything committed delivers nothing more', () {
        fakeAsync((async) {
          final rig = live(async);
          addTearDown(rig.engine.dispose);

          rig.stt.emitResult('one two', isFinal: false);
          async.elapse(pause);

          unawaited(isPause ? rig.engine.pause() : rig.engine.stopListening());
          async.flushMicrotasks();
          rig.stt.emitResult('one two', isFinal: true);
          async.elapse(const Duration(seconds: 5));

          expect(finals(rig.results), ['one two']);
        });
      });
    }

    test('the status done flushes only the uncommitted words', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        rig.stt.emitResult('one two', isFinal: false);
        async.elapse(pause);
        rig.stt.emitResult('one two three', isFinal: false);
        async.flushMicrotasks();
        rig.stt.emitStatus('done');
        async.flushMicrotasks();

        expect(finals(rig.results), ['one two', 'three']);
      });
    });
  });

  group('listen options (BR-U10-71, TP-48)', () {
    test('listens on-device with punctuation and dictation mode', () {
      fakeAsync((async) {
        final rig = live(async);
        addTearDown(rig.engine.dispose);

        final options = rig.stt.listenCalls.single.listenOptions!;
        expect(options.onDevice, isTrue);
        expect(options.autoPunctuation, isTrue);
        expect(options.listenMode, ListenMode.dictation);
        expect(options.partialResults, isTrue);
        expect(options.cancelOnError, isFalse);
      });
    });
  });
}
