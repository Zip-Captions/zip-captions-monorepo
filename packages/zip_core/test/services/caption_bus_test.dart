import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';

void main() {
  late CaptionBus bus;

  setUp(() {
    bus = CaptionBus();
  });

  tearDown(() {
    bus.dispose();
  });

  SttResultEvent _makeResultEvent([String text = 'test']) => SttResultEvent(
        SttResult(
          text: text,
          isFinal: false,
          confidence: 1.0,
          timestamp: DateTime.utc(2026),
          sourceId: 'default',
        ),
      );

  group('CaptionBus', () {
    test('stream delivers published events', () async {
      final events = <CaptionEvent>[];
      bus.stream.listen(events.add);

      bus.publish(_makeResultEvent());
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first, isA<SttResultEvent>());
    });

    test('multiple subscribers receive all events', () async {
      final events1 = <CaptionEvent>[];
      final events2 = <CaptionEvent>[];
      bus.stream.listen(events1.add);
      bus.stream.listen(events2.add);

      bus.publish(_makeResultEvent());
      await Future<void>.delayed(Duration.zero);

      expect(events1, hasLength(1));
      expect(events2, hasLength(1));
    });

    test('publish is no-op after dispose', () async {
      final events = <CaptionEvent>[];
      bus.stream.listen(events.add);

      bus.dispose();
      bus.publish(_makeResultEvent());
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });

    test('delivers SessionStateEvent', () async {
      final events = <CaptionEvent>[];
      bus.stream.listen(events.add);

      const stateEvent = SessionStateEvent(
        RecordingState.recording(sessionId: 'test-session'),
      );
      bus.publish(stateEvent);
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first, isA<SessionStateEvent>());
    });

    test('preserves event order', () async {
      final events = <CaptionEvent>[];
      bus.stream.listen(events.add);

      bus.publish(_makeResultEvent('first'));
      bus.publish(_makeResultEvent('second'));
      bus.publish(_makeResultEvent('third'));
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(3));
      expect((events[0] as SttResultEvent).result.text, 'first');
      expect((events[1] as SttResultEvent).result.text, 'second');
      expect((events[2] as SttResultEvent).result.text, 'third');
    });
  });
}
