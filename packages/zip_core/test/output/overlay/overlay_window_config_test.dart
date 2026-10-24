// Tests for Unit 8.1 (S-21): OverlayWindowConfig, the value carried over the
// `zip_core/overlay_window_configure` channel (FD §1.2.1; NFR Design §5.1).
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/overlay_window_config.dart';

void main() {
  group('OverlayWindowConfig', () {
    test('defaults are the shipped borderless surface', () {
      const config = OverlayWindowConfig();

      expect(config.floating, isFalse);
      expect(config.decorated, isFalse);
      expect(config.minWidth, 0);
      expect(config.minHeight, 0);
    });

    test('the pop-out configuration is floating, decorated and sized', () {
      const config = OverlayWindowConfig(
        floating: true,
        decorated: true,
        minWidth: 320,
        minHeight: 96,
      );

      expect(config.floating, isTrue);
      expect(config.decorated, isTrue);
      expect(config.minWidth, 320);
      expect(config.minHeight, 96);
    });

    test('equality is structural', () {
      const a = OverlayWindowConfig(
        floating: true,
        decorated: true,
        minWidth: 320,
        minHeight: 96,
      );
      const b = OverlayWindowConfig(
        floating: true,
        decorated: true,
        minWidth: 320,
        minHeight: 96,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const OverlayWindowConfig(floating: true)));
    });

    test('copyWith changes one field and keeps the rest', () {
      const base = OverlayWindowConfig(
        floating: true,
        decorated: true,
        minWidth: 320,
        minHeight: 96,
      );

      final next = base.copyWith(minHeight: 144);

      expect(next.floating, isTrue);
      expect(next.decorated, isTrue);
      expect(next.minWidth, 320);
      expect(next.minHeight, 144);
      expect(base.minHeight, 96);
    });
  });
}
