import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';

void main() {
  group('WakeLockSettings', () {
    test('defaults: enabled=true, releaseOnPause=true', () {
      const settings = WakeLockSettings();
      expect(settings.enabled, isTrue);
      expect(settings.releaseOnPause, isTrue);
    });

    test('can be created with custom values', () {
      const settings =
          WakeLockSettings(enabled: false, releaseOnPause: false);
      expect(settings.enabled, isFalse);
      expect(settings.releaseOnPause, isFalse);
    });

    test('equality compares all fields', () {
      const a = WakeLockSettings();
      const b = WakeLockSettings();
      const c = WakeLockSettings(enabled: false);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates a new instance with updated fields', () {
      const settings = WakeLockSettings();
      final updated = settings.copyWith(enabled: false);

      expect(updated.enabled, isFalse);
      expect(updated.releaseOnPause, isTrue);
    });
  });
}
