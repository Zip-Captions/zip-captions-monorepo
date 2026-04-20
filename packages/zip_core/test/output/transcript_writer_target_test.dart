import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/pbt.dart' hide any;
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/models/transcript_segment.dart';
import 'package:zip_core/src/models/transcript_settings.dart';
import 'package:zip_core/src/output/transcript_writer_target.dart';

import '../helpers/generators.dart';
import '../helpers/mock_transcript_repository.dart';

SttResultEvent _finalEvent({
  String text = 'hello',
  String sourceId = 'default',
}) =>
    SttResultEvent(
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
  when(
    () => repo.createSession(any(), any()),
  ).thenAnswer((_) async {});
  when(
    () => repo.saveSegment(any(), any()),
  ).thenAnswer((_) async {});
  when(
    () => repo.finalizeSession(
      any(),
      durationMs: any(named: 'durationMs'),
      segmentCount: any(named: 'segmentCount'),
    ),
  ).thenAnswer((_) async {});
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
    test('recording event calls createSession', () async {
      target.onCaptionEvent(_recordingEvent('s1'));

      await Future<void>.delayed(Duration.zero);

      verify(() => mockRepo.createSession('s1', any())).called(1);
    });

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
