import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/broadcast_limits.dart';

void main() {
  group('BroadcastLimits', () {
    test('creates with all required fields', () {
      const limits = BroadcastLimits(
        maxViewers: 50,
        presenceTimeout: Duration(seconds: 60),
        reconnectWindow: Duration(seconds: 120),
      );

      expect(limits.maxViewers, 50);
      expect(limits.presenceTimeout, const Duration(seconds: 60));
      expect(limits.reconnectWindow, const Duration(seconds: 120));
    });

    test('equality works for identical values', () {
      const a = BroadcastLimits(
        maxViewers: 50,
        presenceTimeout: Duration(seconds: 60),
        reconnectWindow: Duration(seconds: 120),
      );
      const b = BroadcastLimits(
        maxViewers: 50,
        presenceTimeout: Duration(seconds: 60),
        reconnectWindow: Duration(seconds: 120),
      );
      const c = BroadcastLimits(
        maxViewers: 100,
        presenceTimeout: Duration(seconds: 60),
        reconnectWindow: Duration(seconds: 120),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      const original = BroadcastLimits(
        maxViewers: 50,
        presenceTimeout: Duration(seconds: 60),
        reconnectWindow: Duration(seconds: 120),
      );
      final modified = original.copyWith(
        maxViewers: 100,
        reconnectWindow: const Duration(seconds: 300),
      );

      expect(modified.maxViewers, 100);
      expect(modified.presenceTimeout, const Duration(seconds: 60));
      expect(modified.reconnectWindow, const Duration(seconds: 300));
    });
  });

  group('AdmissionDecision', () {
    test('has exactly the two values fixed at Application Design', () {
      const variants = <AdmissionDecision>[Admitted(), Full()];

      expect(variants, hasLength(2));
      for (final variant in variants) {
        expect(variant, isA<AdmissionDecision>());
      }
    });

    test('distinct variants are never equal to each other', () {
      const variants = <AdmissionDecision>[Admitted(), Full()];
      for (final a in variants) {
        for (final b in variants) {
          if (identical(a, b)) continue;
          expect(a, isNot(equals(b)));
        }
      }
    });
  });
}
