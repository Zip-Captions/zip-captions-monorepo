import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/display_settings.dart';
import 'package:zip_core/src/models/enums.dart';

void main() {
  group('DisplaySettings', () {
    test('defaults returns canonical default values (BR-04)', () {
      final defaults = DisplaySettings.defaults();

      expect(defaults.scrollDirection, ScrollDirection.bottomToTop);
      expect(defaults.captionTextSize, CaptionTextSize.md);
      expect(defaults.captionFont, CaptionFont.atkinsonHyperlegible);
      expect(defaults.themeModeSetting, ThemeModeSetting.system);
      expect(defaults.maxVisibleLines, 0);
    });

    test('copyWith creates a new instance with updated fields', () {
      final defaults = DisplaySettings.defaults();
      final updated = defaults.copyWith(
        scrollDirection: ScrollDirection.topToBottom,
        captionTextSize: CaptionTextSize.xl,
      );

      expect(updated.scrollDirection, ScrollDirection.topToBottom);
      expect(updated.captionTextSize, CaptionTextSize.xl);
      // Unchanged fields preserved
      expect(updated.captionFont, CaptionFont.atkinsonHyperlegible);
      expect(updated.themeModeSetting, ThemeModeSetting.system);
      expect(updated.maxVisibleLines, 0);
    });

    test('equality compares all fields', () {
      final a = DisplaySettings.defaults();
      final b = DisplaySettings.defaults();
      final c = a.copyWith(captionFont: CaptionFont.poppins);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('defaults factory always returns equivalent instances', () {
      expect(DisplaySettings.defaults(), equals(DisplaySettings.defaults()));
    });
  });
}
