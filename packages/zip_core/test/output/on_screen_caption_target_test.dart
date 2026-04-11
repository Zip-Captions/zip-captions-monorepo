import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide addTearDown, any, expect, group, setUp, tearDown, test;
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/caption_display_entry.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/output/on_screen_caption_target.dart';

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

SttResultEvent _interimEvent({String text = 'hel'}) => SttResultEvent(
      SttResult(
        text: text,
        isFinal: false,
        confidence: 0.5,
        timestamp: DateTime.utc(2026),
        sourceId: 'default',
      ),
    );

SessionStateEvent _recordingEvent(String sessionId) =>
    SessionStateEvent(RecordingState.recording(sessionId: sessionId));

SessionStateEvent _stoppedEvent(String sessionId) =>
    SessionStateEvent(RecordingState.stopped(sessionId: sessionId));

void main() {
  late OnScreenCaptionTarget target;
  late MockTranscriptRepository mockRepo;

  setUp(() {
    mockRepo = MockTranscriptRepository();
    target = OnScreenCaptionTarget(
      targetId: 'test',
      repository: mockRepo,
    )..onCaptionEvent(_recordingEvent('s1'));
  });

  tearDown(() {
    target.dispose();
    mockRepo.disposeController();
  });

  group('debounce', () {
    test('10 events within 10ms → ≤2 emissions over 50ms window', () {
      fakeAsync((fake) {
        final emissions = <List<CaptionDisplayEntry>>[];
        final sub = target.onVisibleCaptionsChanged.listen(emissions.add);

        for (var i = 0; i < 10; i++) {
          target.onCaptionEvent(_finalEvent(text: 'word $i'));
        }
        fake.elapse(const Duration(milliseconds: 10));
        // Still within the debounce window — no emission yet.
        expect(emissions, isEmpty);

        fake.elapse(const Duration(milliseconds: 50));
        // Trailing emission should have fired once.
        expect(emissions.length, lessThanOrEqualTo(2));
        unawaited(sub.cancel());
      });
    });

    test('two events 60ms apart → exactly 2 emissions', () {
      fakeAsync((fake) {
        final emissions = <List<CaptionDisplayEntry>>[];
        final sub = target.onVisibleCaptionsChanged.listen(emissions.add);

        target.onCaptionEvent(_finalEvent(text: 'first'));
        fake.elapse(const Duration(milliseconds: 60));
        target.onCaptionEvent(_finalEvent(text: 'second'));
        fake.elapse(const Duration(milliseconds: 60));

        expect(emissions.length, equals(2));
        unawaited(sub.cancel());
      });
    });
  });

  group('visibleCaptions', () {
    test('returns latest state synchronously before timer fires', () {
      fakeAsync((fake) {
        target
          ..onCaptionEvent(_finalEvent(text: 'a'))
          ..onCaptionEvent(_interimEvent(text: 'b'));

        // Timer has not fired yet — getter returns latest state.
        final captions = target.visibleCaptions;
        expect(captions, hasLength(2));
        expect(captions.last.isFinal, isFalse);
        expect(captions.last.text, equals('b'));

        fake.elapse(const Duration(milliseconds: 50));
      });
    });

    test('interim entry cleared on next final result', () {
      fakeAsync((fake) {
        target.onCaptionEvent(_interimEvent(text: 'partial'));
        expect(target.visibleCaptions.last.isFinal, isFalse);

        target.onCaptionEvent(_finalEvent(text: 'final'));
        expect(target.visibleCaptions.last.isFinal, isTrue);
        expect(target.visibleCaptions.last.text, equals('final'));

        fake.elapse(const Duration(milliseconds: 50));
      });
    });
  });

  group('dispose', () {
    test('no emission after dispose', () {
      fakeAsync((fake) {
        final emissions = <List<CaptionDisplayEntry>>[];
        final sub = target.onVisibleCaptionsChanged.listen(emissions.add);

        target
          ..onCaptionEvent(_finalEvent())
          ..dispose();
        fake.elapse(const Duration(milliseconds: 100));

        expect(emissions, isEmpty);
        unawaited(sub.cancel());
      });
    });
  });

  group('session lifecycle', () {
    test('buffer cleared on new recording session', () {
      target.onCaptionEvent(_finalEvent(text: 'old'));
      expect(target.visibleCaptions, hasLength(1));

      target.onCaptionEvent(_recordingEvent('s2'));
      expect(target.visibleCaptions, isEmpty);
    });

    test('interim cleared on session stopped', () {
      fakeAsync((fake) {
        target
          ..onCaptionEvent(_interimEvent())
          ..onCaptionEvent(_stoppedEvent('s1'));
        expect(target.visibleCaptions.where((e) => !e.isFinal), isEmpty);
        fake.elapse(const Duration(milliseconds: 50));
      });
    });
  });

  group('PBT — buffer invariant', () {
    Glados(arbitraryCaptionEvent).test(
      'buffer length never exceeds maxBufferSegments',
      (event) {
        final t = OnScreenCaptionTarget(
          targetId: 'pbt',
          maxBufferSegments: 5,
        )..onCaptionEvent(_recordingEvent('pbt-session'));
        for (var i = 0; i < 10; i++) {
          t.onCaptionEvent(_finalEvent(text: 'word $i'));
        }
        expect(t.visibleCaptions.where((e) => e.isFinal).length,
            lessThanOrEqualTo(5));
        t.dispose();
      },
    );
  });

  group('loadOlderSegments', () {
    test('no-op when buffer is empty', () async {
      final emptyTarget = OnScreenCaptionTarget(
        targetId: 'empty',
        repository: mockRepo,
      )..onCaptionEvent(_recordingEvent('s1'));
      // Should not call repository.
      await emptyTarget.loadOlderSegments();
      verifyNever(() => mockRepo.getSegmentsBefore(
            sessionId: any(named: 'sessionId'),
            beforeTimestamp: any(named: 'beforeTimestamp'),
          ));
      emptyTarget.dispose();
    });
  });
}
