import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/transcript_settings.dart';

void main() {
  group('TranscriptSettings', () {
    test('defaults: captureEnabled=true', () {
      const settings = TranscriptSettings();
      expect(settings.captureEnabled, isTrue);
    });

    test('copyWith creates a new instance with updated fields', () {
      const settings = TranscriptSettings();
      final updated = settings.copyWith(captureEnabled: false);

      expect(updated.captureEnabled, isFalse);
      // copyWith must not mutate the original instance.
      expect(settings.captureEnabled, isTrue);
    });

    test('equality compares all fields', () {
      // copyWith constructs a fresh object on each call, so a and b are
      // distinct runtime instances with equal field values. This matters
      // because identical const expressions canonicalize to one object,
      // which would let object identity satisfy the checks below instead
      // of freezed's generated ==/hashCode.
      final a = const TranscriptSettings().copyWith(captureEnabled: false);
      final b = const TranscriptSettings().copyWith(captureEnabled: false);
      const c = TranscriptSettings();

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
