import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/stt_result.dart';

void main() {
  group('SttResult', () {
    test('creates with all required fields', () {
      final result = SttResult(
        text: 'hello world',
        isFinal: true,
        confidence: 0.95,
        timestamp: DateTime.utc(2026),
        sourceId: 'default',
      );

      expect(result.text, 'hello world');
      expect(result.isFinal, isTrue);
      expect(result.confidence, 0.95);
      expect(result.sourceId, 'default');
      expect(result.speakerTag, isNull);
    });

    test('creates with optional speakerTag', () {
      final result = SttResult(
        text: 'test',
        isFinal: false,
        confidence: 0.5,
        timestamp: DateTime.utc(2026),
        sourceId: 'mic-1',
        speakerTag: 'Speaker A',
      );

      expect(result.speakerTag, 'Speaker A');
    });

    test('equality works for identical values', () {
      final timestamp = DateTime.utc(2026);
      final a = SttResult(
        text: 'same',
        isFinal: true,
        confidence: 1.0,
        timestamp: timestamp,
        sourceId: 'default',
      );
      final b = SttResult(
        text: 'same',
        isFinal: true,
        confidence: 1.0,
        timestamp: timestamp,
        sourceId: 'default',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith creates modified copy', () {
      final original = SttResult(
        text: 'original',
        isFinal: false,
        confidence: 0.5,
        timestamp: DateTime.utc(2026),
        sourceId: 'default',
      );
      final modified = original.copyWith(isFinal: true, confidence: 0.99);

      expect(modified.text, 'original');
      expect(modified.isFinal, isTrue);
      expect(modified.confidence, 0.99);
    });
  });
}
