import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/models/transcript_save_result.dart';
import 'package:zip_core/src/models/transcript_segment.dart';
import 'package:zip_core/src/models/transcript_settings.dart';
import 'package:zip_core/src/output/transcript_writer_target.dart';

import '../helpers/generators.dart';
import '../helpers/mock_transcript_repository.dart';
import '../helpers/pbt.dart' hide any;

SttResultEvent _finalEvent({
  String text = 'hello',
  String sourceId = 'default',
}) => SttResultEvent(
  SttResult(
    text: text,
    isFinal: true,
    confidence: 1,
    timestamp: DateTime.utc(2026),
    sourceId: sourceId,
  ),
);

SessionStateEvent _recordingEvent(String sessionId) =>
    SessionStateEvent(RecordingState.recording(sessionId: sessionId));

SessionStateEvent _stoppedEvent(String sessionId) =>
    SessionStateEvent(RecordingState.stopped(sessionId: sessionId));

void _stubRepo(MockTranscriptRepository repo) {
  // A microtask-backed success, not `.thenAnswer((_) async {})`: under
  // `fakeAsync` an async closure's future completes through a timer, which
  // `elapse(Duration.zero)` and `flushMicrotasks()` do not run. The writer's
  // ordered write chain is microtask-only, so the stubs complete in a
  // microtask too, and one `Future.delayed(Duration.zero)` drains the chain
  // in both a real event loop and `fakeAsync`.
  Future<void> ok() => Future<void>.microtask(() {});
  when(() => repo.createSession(any(), any())).thenAnswer((_) => ok());
  when(() => repo.saveSegment(any(), any())).thenAnswer((_) => ok());
  when(
    () => repo.finalizeSession(
      any(),
      durationMs: any(named: 'durationMs'),
      segmentCount: any(named: 'segmentCount'),
    ),
  ).thenAnswer((_) => ok());
}

void main() {
  late TranscriptWriterTarget target;
  late MockTranscriptRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(
      const TranscriptSegment(
        segmentId: 'fallback',
        sessionId: 'fallback',
        text: '',
        sourceId: '',
        startTimeMs: 0,
        endTimeMs: 0,
      ),
    );
  });

  setUp(() {
    mockRepo = MockTranscriptRepository();
    _stubRepo(mockRepo);
    target = TranscriptWriterTarget(
      repository: mockRepo,
      settings: const TranscriptSettings(),
      now: () => clock.now(),
    );
  });

  tearDown(() {
    target.dispose();
    mockRepo.disposeController();
  });

  group('a failed session create', () {
    setUp(() {
      when(
        () => mockRepo.createSession(any(), any()),
      ).thenAnswer((_) => Future<void>.error(StateError('create failed')));
    });

    test('finalizeCurrentSession reports not saved', () async {
      target
        ..onCaptionEvent(_recordingEvent('s1'))
        ..onCaptionEvent(_finalEvent());

      final result = await target.finalizeCurrentSession();

      expect(result, TranscriptSaveResult.saveFailed);
      // The create never succeeded, so there is no row to finalise.
      verifyNever(
        () => mockRepo.finalizeSession(
          any(),
          durationMs: any(named: 'durationMs'),
          segmentCount: any(named: 'segmentCount'),
        ),
      );
    });

    test('no segment write follows it, new or merged (foreign keys are on, '
        'so each would fail)', () async {
      target
        ..onCaptionEvent(_recordingEvent('s1'))
        // Within the merge window, so the second final is a merge.
        ..onCaptionEvent(_finalEvent(text: 'a'))
        ..onCaptionEvent(_finalEvent(text: 'b'));

      final result = await target.finalizeCurrentSession();

      expect(result, TranscriptSaveResult.saveFailed);
      verifyNever(() => mockRepo.saveSegment(any(), any()));
    });
  });

  // TP-38 (BR-U10-60): each way a session can end maps to one outcome.
  group('the save outcome (BR-U10-60, TP-38)', () {
    Future<TranscriptSaveResult> finishAfter(
      void Function() events, {
      void Function()? arrange,
    }) async {
      arrange?.call();
      events();
      return target.finalizeCurrentSession();
    }

    test('no segment: nothingRecognised', () async {
      final result = await finishAfter(
        () => target.onCaptionEvent(_recordingEvent('s1')),
      );

      expect(result, TranscriptSaveResult.nothingRecognised);
    });

    test('no session at all: nothingRecognised', () async {
      expect(
        await target.finalizeCurrentSession(),
        TranscriptSaveResult.nothingRecognised,
      );
    });

    test('created and saved: saved', () async {
      final result = await finishAfter(() {
        target
          ..onCaptionEvent(_recordingEvent('s1'))
          ..onCaptionEvent(_finalEvent());
      });

      expect(result, TranscriptSaveResult.saved);
    });

    test('create failed: saveFailed', () async {
      final result = await finishAfter(
        () {
          target
            ..onCaptionEvent(_recordingEvent('s1'))
            ..onCaptionEvent(_finalEvent());
        },
        arrange: () => when(
          () => mockRepo.createSession(any(), any()),
        ).thenAnswer((_) => Future<void>.error(StateError('create failed'))),
      );

      expect(result, TranscriptSaveResult.saveFailed);
    });

    test('created but every save failed: saveFailed', () async {
      final result = await finishAfter(
        () {
          target
            ..onCaptionEvent(_recordingEvent('s1'))
            ..onCaptionEvent(_finalEvent());
        },
        arrange: () => when(
          () => mockRepo.saveSegment(any(), any()),
        ).thenAnswer((_) => Future<void>.error(StateError('save failed'))),
      );

      expect(result, TranscriptSaveResult.saveFailed);
      // The row exists, so it is still finalised.
      verify(
        () => mockRepo.finalizeSession(
          's1',
          durationMs: any(named: 'durationMs'),
          segmentCount: 1,
        ),
      ).called(1);
    });

    test('one save failed and a later merge succeeded: saved', () {
      fakeAsync((fake) {
        var calls = 0;
        when(() => mockRepo.saveSegment(any(), any())).thenAnswer((_) {
          calls++;
          return calls == 1
              ? Future<void>.error(StateError('first save failed'))
              : Future<void>.microtask(() {});
        });
        target
          ..onCaptionEvent(_recordingEvent('s1'))
          ..onCaptionEvent(_finalEvent(text: 'a'));
        fake.elapse(const Duration(milliseconds: 500));
        // Within the merge window: this goes through the merge path.
        target.onCaptionEvent(_finalEvent(text: 'b'));
        TranscriptSaveResult? result;
        unawaited(target.finalizeCurrentSession().then((v) => result = v));
        fake.flushMicrotasks();

        expect(calls, 2, reason: 'the first save and the merge');
        expect(result, TranscriptSaveResult.saved);
      });
    });
  });

  group('saveSegment on final result', () {
    test('final result calls saveSegment immediately', () async {
      target
        ..onCaptionEvent(_recordingEvent('s1'))
        ..onCaptionEvent(_finalEvent());

      await Future<void>.delayed(Duration.zero);

      verify(() => mockRepo.saveSegment(any(), any())).called(1);
    });

    test('interim result does not call saveSegment', () async {
      target
        ..onCaptionEvent(_recordingEvent('s1'))
        ..onCaptionEvent(
          SttResultEvent(
            SttResult(
              text: 'hel',
              isFinal: false,
              confidence: 0.5,
              timestamp: DateTime.utc(2026),
              sourceId: 'default',
            ),
          ),
        );

      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockRepo.saveSegment(any(), any()));
    });

    test(
      'second final within 2s same source → merged text via saveSegment',
      () {
        fakeAsync((fake) {
          target
            ..onCaptionEvent(_recordingEvent('s1'))
            ..onCaptionEvent(_finalEvent());
          fake.elapse(const Duration(milliseconds: 500));
          target.onCaptionEvent(_finalEvent(text: 'world'));
          fake.elapse(Duration.zero);

          final captured = verify(
            () => mockRepo.saveSegment(any(), captureAny()),
          ).captured;
          // Two saveSegment calls: 'hello', then merged 'hello world'.
          expect(captured, hasLength(2));
          final second = captured.last as TranscriptSegment;
          expect(second.text, equals('hello world'));
        });
      },
    );

    test(
      'final results >2s apart → two separate saveSegment calls',
      () {
        fakeAsync((fake) {
          target
            ..onCaptionEvent(_recordingEvent('s1'))
            ..onCaptionEvent(_finalEvent(text: 'first'));
          fake.elapse(const Duration(seconds: 3));
          target.onCaptionEvent(_finalEvent(text: 'second'));
          fake.elapse(Duration.zero);

          final captured = verify(
            () => mockRepo.saveSegment(any(), captureAny()),
          ).captured;
          expect(captured, hasLength(2));
          expect((captured[0] as TranscriptSegment).text, equals('first'));
          expect((captured[1] as TranscriptSegment).text, equals('second'));
        });
      },
    );
  });

  group('session lifecycle', () {
    test(
      'recording event alone creates nothing (Q-2: the row is lazy)',
      () async {
        target.onCaptionEvent(_recordingEvent('s1'));

        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockRepo.createSession(any(), any()));
        verifyNever(() => mockRepo.saveSegment(any(), any()));
        verifyNever(
          () => mockRepo.finalizeSession(
            any(),
            durationMs: any(named: 'durationMs'),
            segmentCount: any(named: 'segmentCount'),
          ),
        );
      },
    );

    test(
      'stopped event calls finalizeSession with correct segment count',
      () {
        fakeAsync((fake) {
          // Two distinct segments: different sources, so no merge.
          target
            ..onCaptionEvent(_recordingEvent('s1'))
            ..onCaptionEvent(_finalEvent(text: 'a'))
            ..onCaptionEvent(_finalEvent(text: 'b', sourceId: 'mic-1'));
          fake.elapse(Duration.zero);
          target.onCaptionEvent(_stoppedEvent('s1'));
          fake.elapse(Duration.zero);

          final captured = verify(
            () => mockRepo.finalizeSession(
              any(),
              durationMs: captureAny(named: 'durationMs'),
              segmentCount: captureAny(named: 'segmentCount'),
            ),
          ).captured;
          // captured[0] = durationMs value, captured[1] = segmentCount value
          expect(captured[1] as int, equals(2));
        });
      },
    );

    test('capture disabled → saveSegment never called', () async {
      TranscriptWriterTarget(
          repository: mockRepo,
          settings: const TranscriptSettings(captureEnabled: false),
        )
        ..onCaptionEvent(_recordingEvent('s1'))
        ..onCaptionEvent(_finalEvent())
        ..dispose();

      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockRepo.saveSegment(any(), any()));
      verifyNever(() => mockRepo.createSession(any(), any()));
    });
  });

  // Q-2 (Amendment 03 section 7): the row exists only once a segment is
  // saved, so a session with no captioned text leaves nothing behind.
  group('no empty transcripts (Q-2)', () {
    test('zero segments → no createSession and no finalizeSession', () async {
      target
        ..onCaptionEvent(_recordingEvent('s1'))
        ..onCaptionEvent(_stoppedEvent('s1'));

      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockRepo.createSession(any(), any()));
      verifyNever(
        () => mockRepo.finalizeSession(
          any(),
          durationMs: any(named: 'durationMs'),
          segmentCount: any(named: 'segmentCount'),
        ),
      );
    });

    test(
      'finalizeCurrentSession with zero segments reports nothingRecognised and '
      'calls nothing',
      () async {
        target.onCaptionEvent(_recordingEvent('s1'));
        await Future<void>.delayed(Duration.zero);

        expect(
          await target.finalizeCurrentSession(),
          TranscriptSaveResult.nothingRecognised,
        );

        verifyNever(() => mockRepo.createSession(any(), any()));
        verifyNever(() => mockRepo.saveSegment(any(), any()));
        verifyNever(
          () => mockRepo.finalizeSession(
            any(),
            durationMs: any(named: 'durationMs'),
            segmentCount: any(named: 'segmentCount'),
          ),
        );
      },
    );

    test(
      'finalizeCurrentSession after a segment reports saved and finalises',
      () async {
        target
          ..onCaptionEvent(_recordingEvent('s1'))
          ..onCaptionEvent(_finalEvent());

        expect(
          await target.finalizeCurrentSession(),
          TranscriptSaveResult.saved,
        );

        verify(
          () => mockRepo.finalizeSession(
            's1',
            durationMs: any(named: 'durationMs'),
            segmentCount: 1,
          ),
        ).called(1);
      },
    );

    test(
      'first segment: createSession then saveSegment, in that order — '
      'the segment never precedes its row',
      () async {
        target
          ..onCaptionEvent(_recordingEvent('s1'))
          ..onCaptionEvent(_finalEvent());

        await Future<void>.delayed(Duration.zero);

        verifyInOrder([
          () => mockRepo.createSession('s1', any()),
          () => mockRepo.saveSegment('s1', any()),
        ]);
      },
    );

    test('the row is created with the session start date', () {
      fakeAsync((fake) {
        final start = clock.now();
        target.onCaptionEvent(_recordingEvent('s1'));
        fake.elapse(const Duration(seconds: 5));
        target.onCaptionEvent(_finalEvent());
        fake.elapse(Duration.zero);

        final captured = verify(
          () => mockRepo.createSession('s1', captureAny()),
        ).captured;
        expect(captured.single as DateTime, equals(start));
      });
    });

    test(
      'a session abandoned mid-way (killed before any segment) creates '
      'nothing',
      () async {
        target
          ..onCaptionEvent(_recordingEvent('s1'))
          ..dispose();

        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockRepo.createSession(any(), any()));
        verifyNever(() => mockRepo.saveSegment(any(), any()));
        verifyNever(
          () => mockRepo.finalizeSession(
            any(),
            durationMs: any(named: 'durationMs'),
            segmentCount: any(named: 'segmentCount'),
          ),
        );
      },
    );

    test('merges after the first segment do not create the row again', () {
      fakeAsync((fake) {
        target
          ..onCaptionEvent(_recordingEvent('s1'))
          ..onCaptionEvent(_finalEvent(text: 'a'));
        fake.elapse(const Duration(milliseconds: 500));
        target.onCaptionEvent(_finalEvent(text: 'b'));
        fake.elapse(Duration.zero);

        verify(() => mockRepo.createSession('s1', any())).called(1);
        verify(() => mockRepo.saveSegment(any(), any())).called(2);
      });
    });
  });

  // Q-4 (Amendment 03 section 8): a re-published RecordingActiveState with
  // the SAME sessionId (resume, REL-U2.1 recovery) is a continuation; a
  // different sessionId is a new session.
  group('continuity of a re-published session (Q-4)', () {
    test(
      'pause then resume keeps the count and the duration from the '
      'original start',
      () {
        fakeAsync((fake) {
          target
            ..onCaptionEvent(_recordingEvent('s1'))
            ..onCaptionEvent(_finalEvent(text: 'a'))
            ..onCaptionEvent(_finalEvent(text: 'b', sourceId: 'mic-1'));
          fake.elapse(const Duration(seconds: 1));
          target.onCaptionEvent(
            const SessionStateEvent(RecordingState.paused(sessionId: 's1')),
          );
          fake.elapse(const Duration(seconds: 1));
          // The notifier republishes RecordingActiveState on resume.
          target.onCaptionEvent(_recordingEvent('s1'));
          fake.elapse(const Duration(seconds: 1));
          target.onCaptionEvent(_stoppedEvent('s1'));
          fake.elapse(Duration.zero);

          final captured = verify(
            () => mockRepo.finalizeSession(
              's1',
              durationMs: captureAny(named: 'durationMs'),
              segmentCount: captureAny(named: 'segmentCount'),
            ),
          ).captured;
          expect(
            captured[1] as int,
            equals(2),
            reason: 'the resume must not reset the segment count',
          );
          expect(
            captured[0] as int,
            equals(3000),
            reason: 'the duration must run from the original start',
          );
          verify(() => mockRepo.createSession('s1', any())).called(1);
        });
      },
    );

    test(
      'the REL-U2.1 recovery republish keeps the count and the duration',
      () {
        fakeAsync((fake) {
          target
            ..onCaptionEvent(_recordingEvent('s1'))
            ..onCaptionEvent(_finalEvent(text: 'a'));
          fake.elapse(const Duration(seconds: 1));
          // Recovery restarts the engine and republishes the same session.
          target.onCaptionEvent(_recordingEvent('s1'));
          fake.elapse(const Duration(seconds: 1));
          target.onCaptionEvent(_stoppedEvent('s1'));
          fake.elapse(Duration.zero);

          final captured = verify(
            () => mockRepo.finalizeSession(
              's1',
              durationMs: captureAny(named: 'durationMs'),
              segmentCount: captureAny(named: 'segmentCount'),
            ),
          ).captured;
          expect(captured[1] as int, equals(1));
          expect(captured[0] as int, equals(2000));
          verify(() => mockRepo.createSession('s1', any())).called(1);
        });
      },
    );

    test(
      'the resume keeps the merge state: a final just after it merges with '
      'the final just before it',
      () {
        fakeAsync((fake) {
          target
            ..onCaptionEvent(_recordingEvent('s1'))
            ..onCaptionEvent(_finalEvent(text: 'a'));
          fake.elapse(const Duration(milliseconds: 500));
          target.onCaptionEvent(
            const SessionStateEvent(RecordingState.paused(sessionId: 's1')),
          );
          fake.elapse(const Duration(milliseconds: 500));
          target.onCaptionEvent(_recordingEvent('s1'));
          // 1.5 s after the earlier final: inside the 2 s merge window.
          fake.elapse(const Duration(milliseconds: 1000));
          target.onCaptionEvent(_finalEvent(text: 'a2'));
          fake.elapse(Duration.zero);

          final captured = verify(
            () => mockRepo.saveSegment(any(), captureAny()),
          ).captured;
          final last = captured.last as TranscriptSegment;
          expect(
            last.text,
            equals('a a2'),
            reason: 'the resume must not clear the merge state',
          );
        });
      },
    );

    test(
      'a different sessionId is a new session',
      () {
        fakeAsync((fake) {
          target
            ..onCaptionEvent(_recordingEvent('s1'))
            ..onCaptionEvent(_finalEvent(text: 'a'));
          fake.elapse(Duration.zero);
          target
            ..onCaptionEvent(_recordingEvent('s2'))
            ..onCaptionEvent(_finalEvent(text: 'b'));
          fake.elapse(Duration.zero);
          target.onCaptionEvent(_stoppedEvent('s2'));
          fake.elapse(Duration.zero);

          verify(() => mockRepo.createSession('s1', any())).called(1);
          verify(() => mockRepo.createSession('s2', any())).called(1);
          final captured = verify(
            () => mockRepo.finalizeSession(
              's2',
              durationMs: any(named: 'durationMs'),
              segmentCount: captureAny(named: 'segmentCount'),
            ),
          ).captured;
          expect(
            captured.single as int,
            equals(1),
            reason: 'the count restarts for a new sessionId',
          );
        });
      },
    );
  });

  // Step 29b follow-up: every repository write for a session goes through
  // one ordered chain, so a write that arrives while an earlier one is still
  // in flight cannot reach the repository first.
  group('write ordering (one chain per session)', () {
    /// Holds `createSession` open, recording the calls that get through
    /// while it is held.
    Completer<void> holdCreateSession() {
      final gate = Completer<void>();
      when(() => mockRepo.createSession(any(), any())).thenAnswer(
        (_) => gate.future,
      );
      return gate;
    }

    test(
      'a merge that arrives while the first save is pending reaches the '
      'repository last, with the merged text',
      () async {
        final gate = holdCreateSession();
        target
          ..onCaptionEvent(_recordingEvent('s1'))
          ..onCaptionEvent(_finalEvent());
        await Future<void>.delayed(const Duration(microseconds: 1));
        // Nothing reached the repository: the create is still held.
        verifyNever(() => mockRepo.saveSegment(any(), any()));

        target.onCaptionEvent(_finalEvent(text: 'world'));
        gate.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // The order the repository saw, captured while the calls are still
        // unverified (the verifications below mark them).
        final order = verify(
          () => mockRepo.createSession('s1', any()),
        ).callCount;
        expect(order, 1);
        final saved = verify(
          () => mockRepo.saveSegment('s1', captureAny()),
        ).captured.cast<TranscriptSegment>();
        expect(saved.map((s) => s.text), ['hello', 'hello world']);
        expect(saved.first.segmentId, equals(saved.last.segmentId));
      },
    );

    test(
      'a second segment that arrives while the first save is pending is '
      'saved after it',
      () async {
        final gate = holdCreateSession();
        target
          ..onCaptionEvent(_recordingEvent('s1'))
          ..onCaptionEvent(_finalEvent(text: 'first'));
        await Future<void>.delayed(Duration.zero);

        // More than the 2 s merge window later, so this is a new segment.
        fakeAsync((fake) {
          fake.elapse(const Duration(seconds: 3));
          target.onCaptionEvent(_finalEvent(text: 'second'));
        });
        gate.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final saved = verify(
          () => mockRepo.saveSegment('s1', captureAny()),
        ).captured.cast<TranscriptSegment>();
        expect(saved.map((s) => s.text), ['first', 'second']);
      },
    );

    test(
      'finalizeCurrentSession waits for the pending saves and finalises '
      'after the last one',
      () async {
        final gate = holdCreateSession();
        target
          ..onCaptionEvent(_recordingEvent('s1'))
          ..onCaptionEvent(_finalEvent(text: 'one'));
        await Future<void>.delayed(Duration.zero);

        var finalized = false;
        final done = target.finalizeCurrentSession().then((v) {
          finalized = true;
          return v;
        });
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(finalized, isFalse, reason: 'the chain is still held');
        verifyNever(
          () => mockRepo.finalizeSession(
            any(),
            durationMs: any(named: 'durationMs'),
            segmentCount: any(named: 'segmentCount'),
          ),
        );

        gate.complete();
        expect(await done, TranscriptSaveResult.saved);
        // Both the save and the finalise happened, the save first.
        verifyInOrder([
          () => mockRepo.saveSegment('s1', any()),
          () => mockRepo.finalizeSession(
            's1',
            durationMs: any(named: 'durationMs'),
            segmentCount: 1,
          ),
        ]);
      },
    );

    test('a failing write does not block the writes after it', () async {
      var saves = 0;
      when(() => mockRepo.saveSegment(any(), any())).thenAnswer((_) {
        saves++;
        return saves == 1
            ? Future<void>.error(Exception('save failed'))
            : Future<void>.value();
      });
      target
        ..onCaptionEvent(_recordingEvent('s1'))
        ..onCaptionEvent(_finalEvent(text: 'a'));
      await Future<void>.delayed(Duration.zero);
      // More than the merge window later, so the next final is a new segment
      // rather than a merge of the first.
      fakeAsync((fake) {
        fake.elapse(const Duration(seconds: 3));
        target.onCaptionEvent(_finalEvent(text: 'b'));
      });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(() => mockRepo.saveSegment('s1', any())).called(2);
    });
  });

  group('PBT — merge invariant', () {
    Glados(arbitraryNonEmptyWordList).test(
      'all words within 2s → final segment text equals space-joined inputs',
      (words) {
        fakeAsync((fake) {
          final localRepo = MockTranscriptRepository();
          _stubRepo(localRepo);

          final t = TranscriptWriterTarget(
            repository: localRepo,
            settings: const TranscriptSettings(),
          )..onCaptionEvent(_recordingEvent('pbt-session'));

          // Fire all words with 100ms gaps — well within the 2s merge window.
          for (final word in words) {
            t.onCaptionEvent(_finalEvent(text: word));
            fake.elapse(const Duration(milliseconds: 100));
          }
          fake.elapse(Duration.zero);

          final captured = verify(
            () => localRepo.saveSegment(any(), captureAny()),
          ).captured;
          expect(captured, isNotEmpty);
          final last = captured.last as TranscriptSegment;
          expect(last.text, equals(words.join(' ')));
          t.dispose();
          localRepo.disposeController();
        });
      },
    );
  });
}
