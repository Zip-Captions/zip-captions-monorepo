import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';

void main() {
  group('CaptionEvent', () {
    test('SttResultEvent wraps an SttResult', () {
      final result = SttResult(
        text: 'hello',
        isFinal: true,
        confidence: 1.0,
        timestamp: DateTime.utc(2026),
        sourceId: 'default',
      );
      final event = SttResultEvent(result);

      expect(event, isA<CaptionEvent>());
      expect(event, isA<SttResultEvent>());
      expect(event.result, same(result));
    });

    test('SessionStateEvent wraps a RecordingState', () {
      const state = RecordingState.recording(sessionId: 'abc');
      const event = SessionStateEvent(state);

      expect(event, isA<CaptionEvent>());
      expect(event, isA<SessionStateEvent>());
      expect(event.state, isA<RecordingActiveState>());
    });

    test('exhaustive pattern matching covers all variants', () {
      final events = <CaptionEvent>[
        SttResultEvent(SttResult(
          text: 'test',
          isFinal: false,
          confidence: 0.8,
          timestamp: DateTime.utc(2026),
          sourceId: 'default',
        )),
        const SessionStateEvent(RecordingState.idle()),
      ];

      for (final event in events) {
        final label = switch (event) {
          SttResultEvent() => 'result',
          SessionStateEvent() => 'state',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
