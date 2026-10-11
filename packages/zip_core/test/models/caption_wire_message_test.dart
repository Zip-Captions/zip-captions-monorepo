import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/stt_result.dart';

void main() {
  group('CaptionActivity', () {
    test('has exactly the three values fixed by FR-5.4', () {
      expect(
        CaptionActivity.values,
        containsAll(<CaptionActivity>[
          CaptionActivity.active,
          CaptionActivity.paused,
          CaptionActivity.inactive,
        ]),
      );
      expect(CaptionActivity.values, hasLength(3));
    });
  });

  group('CaptionWireMessage', () {
    test('Caption carries result and defaults version to 1', () {
      final result = SttResult(
        text: 'hello world',
        isFinal: true,
        confidence: 0.95,
        timestamp: DateTime.utc(2026),
        sourceId: 'default',
      );
      final message = Caption(result: result);

      expect(message, isA<Caption>());
      expect(message.result, same(result));
      expect(message.version, 1);
    });

    test('Caption equality compares version and result', () {
      final a = Caption(
        result: SttResult(
          text: 'same',
          isFinal: true,
          confidence: 1,
          timestamp: DateTime.utc(2026),
          sourceId: 'default',
        ),
      );
      final b = Caption(
        result: SttResult(
          text: 'same',
          isFinal: true,
          confidence: 1,
          timestamp: DateTime.utc(2026),
          sourceId: 'default',
        ),
      );
      final c = Caption(
        result: SttResult(
          text: 'different',
          isFinal: true,
          confidence: 1,
          timestamp: DateTime.utc(2026),
          sourceId: 'default',
        ),
      );
      final d = Caption(
        result: SttResult(
          text: 'same',
          isFinal: true,
          confidence: 1,
          timestamp: DateTime.utc(2026),
          sourceId: 'default',
        ),
        version: 2,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test(
      'CaptionActivityChanged carries activity and defaults version to 1',
      () {
        const message = CaptionActivityChanged(
          activity: CaptionActivity.paused,
        );

        expect(message, isA<CaptionActivityChanged>());
        expect(message.activity, CaptionActivity.paused);
        expect(message.version, 1);
      },
    );

    test('CaptionActivityChanged equality compares version and activity', () {
      const a = CaptionActivityChanged(activity: CaptionActivity.active);
      const b = CaptionActivityChanged(activity: CaptionActivity.active);
      const c = CaptionActivityChanged(activity: CaptionActivity.paused);
      const d = CaptionActivityChanged(
        activity: CaptionActivity.active,
        version: 2,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('Ended is a const singleton-equivalent value', () {
      const a = Ended();
      const b = Ended();
      expect(a, equals(b));
      expect(a, isA<Ended>());
    });

    test('messageType is the fixed wire discriminator for each variant', () {
      final caption = Caption(
        result: SttResult(
          text: 'hello',
          isFinal: true,
          confidence: 1,
          timestamp: DateTime.utc(2026),
          sourceId: 'default',
        ),
      );
      const activityChanged = CaptionActivityChanged(
        activity: CaptionActivity.active,
      );
      const ended = Ended();

      expect(caption.messageType, 'caption');
      expect(activityChanged.messageType, 'captionActivityChanged');
      expect(ended.messageType, 'ended');
    });

    test('distinct variants are never equal to each other', () {
      final caption = Caption(
        result: SttResult(
          text: 'hello',
          isFinal: true,
          confidence: 1,
          timestamp: DateTime.utc(2026),
          sourceId: 'default',
        ),
      );
      const activityChanged = CaptionActivityChanged(
        activity: CaptionActivity.active,
      );
      const ended = Ended();
      final variants = [caption, activityChanged, ended];
      for (final a in variants) {
        for (final b in variants) {
          if (identical(a, b)) continue;
          expect(a, isNot(equals(b)));
        }
      }
    });
  });
}
