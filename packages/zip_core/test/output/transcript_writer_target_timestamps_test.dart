import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/models/transcript_segment.dart';
import 'package:zip_core/src/models/transcript_settings.dart';
import 'package:zip_core/src/output/transcript_writer_target.dart';

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

SttResultEvent _interimEvent({
  String text = 'hel',
  String sourceId = 'default',
}) =>
    SttResultEvent(
      SttResult(
        text: text,
        isFinal: false,
        confidence: 0.5,
        timestamp: DateTime.utc(2026),
        sourceId: sourceId,
      ),
    );

SessionStateEvent _recordingEvent(String sessionId) =>
    SessionStateEvent(RecordingState.recording(sessionId: sessionId));

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

  group('segment timestamps', () {
    test(
      'startTimeMs uses interim arrival time; '
          'endTimeMs uses final arrival time',
      () {
        fakeAsync((fake) {
          target.onCaptionEvent(_recordingEvent('s1'));
          // Interim arrives 500ms into session.
          fake.elapse(const Duration(milliseconds: 500));
          target.onCaptionEvent(_interimEvent());
          // Final arrives 1000ms later (1500ms total).
          fake.elapse(const Duration(milliseconds: 1000));
          target.onCaptionEvent(_finalEvent());
          fake.elapse(Duration.zero);

          final captured = verify(
            () => mockRepo.saveSegment(any(), captureAny()),
          ).captured;
          expect(captured, hasLength(1));
          final seg = captured.first as TranscriptSegment;
          expect(seg.startTimeMs, equals(500));
          expect(seg.endTimeMs, equals(1500));
        });
      },
    );

    test(
      'startTimeMs falls back to final arrival time when no interim was seen',
      () {
        fakeAsync((fake) {
          target.onCaptionEvent(_recordingEvent('s1'));
          fake.elapse(const Duration(milliseconds: 800));
          target.onCaptionEvent(_finalEvent());
          fake.elapse(Duration.zero);

          final captured = verify(
            () => mockRepo.saveSegment(any(), captureAny()),
          ).captured;
          final seg = captured.first as TranscriptSegment;
          // With no interim, both timestamps are the final arrival time.
          expect(seg.startTimeMs, equals(800));
          expect(seg.endTimeMs, equals(800));
        });
      },
    );

    test(
      'multiple interim results for one utterance do not advance startTimeMs',
      () {
        fakeAsync((fake) {
          target.onCaptionEvent(_recordingEvent('s1'));
          // First interim at 200ms — this is the start.
          fake.elapse(const Duration(milliseconds: 200));
          target.onCaptionEvent(_interimEvent(text: 'h'));
          // Second interim at 400ms — must not overwrite the start.
          fake.elapse(const Duration(milliseconds: 200));
          target.onCaptionEvent(_interimEvent(text: 'he'));
          // Final at 600ms.
          fake.elapse(const Duration(milliseconds: 200));
          target.onCaptionEvent(_finalEvent());
          fake.elapse(Duration.zero);

          final captured = verify(
            () => mockRepo.saveSegment(any(), captureAny()),
          ).captured;
          final seg = captured.first as TranscriptSegment;
          expect(seg.startTimeMs, equals(200));
          expect(seg.endTimeMs, equals(600));
        });
      },
    );

    test(
      'merged segment preserves startTimeMs of the original segment',
      () {
        fakeAsync((fake) {
          target.onCaptionEvent(_recordingEvent('s1'));
          // First utterance: interim at 300ms, final at 700ms.
          fake.elapse(const Duration(milliseconds: 300));
          target.onCaptionEvent(_interimEvent());
          fake.elapse(const Duration(milliseconds: 400));
          target.onCaptionEvent(_finalEvent());

          // Second utterance within merge window:
          // interim at 900ms, final at 1100ms.
          fake.elapse(const Duration(milliseconds: 200));
          target.onCaptionEvent(_interimEvent());
          fake.elapse(const Duration(milliseconds: 200));
          target.onCaptionEvent(_finalEvent(text: 'world'));
          fake.elapse(Duration.zero);

          final captured = verify(
            () => mockRepo.saveSegment(any(), captureAny()),
          ).captured;
          expect(captured, hasLength(2));
          final merged = captured.last as TranscriptSegment;
          // startTimeMs stays at 300ms (first utterance start), not 900ms.
          expect(merged.startTimeMs, equals(300));
          expect(merged.endTimeMs, equals(1100));
          expect(merged.text, equals('hello world'));
        });
      },
    );

    test(
      'pending start is cleared after final; next utterance gets a fresh start',
      () {
        fakeAsync((fake) {
          target.onCaptionEvent(_recordingEvent('s1'));

          // First utterance: interim at 200ms, final at 500ms.
          fake.elapse(const Duration(milliseconds: 200));
          target.onCaptionEvent(_interimEvent());
          fake.elapse(const Duration(milliseconds: 300));
          target.onCaptionEvent(_finalEvent(text: 'first'));

          // Second utterance starts >2s later so it does not merge.
          // Interim at 3000ms, final at 3500ms.
          fake.elapse(const Duration(milliseconds: 2500));
          target.onCaptionEvent(_interimEvent());
          fake.elapse(const Duration(milliseconds: 500));
          target.onCaptionEvent(_finalEvent(text: 'second'));
          fake.elapse(Duration.zero);

          final captured = verify(
            () => mockRepo.saveSegment(any(), captureAny()),
          ).captured;
          expect(captured, hasLength(2));
          final first = captured[0] as TranscriptSegment;
          final second = captured[1] as TranscriptSegment;
          expect(first.startTimeMs, equals(200));
          expect(second.startTimeMs, equals(3000));
        });
      },
    );
  });
}
