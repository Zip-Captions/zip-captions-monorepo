import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/theme/app_theme.dart';

import '../helpers/contrast_utils.dart';

// WCAG AAA contrast verification for all text-on-surface color pairs.
// 16 pairs total: 8 dark theme + 8 light theme, per NFR-U2-05.
void main() {
  const min = 7.0;
  final ge = greaterThanOrEqualTo(min);

  group('Dark theme WCAG AAA contrast (>= 7:1)', () {
    final cs = AppTheme.dark().colorScheme;

    test('onSurface on surface', () {
      expect(contrastRatio(cs.onSurface, cs.surface), ge);
    });

    test('onSurface on surfaceContainerLowest', () {
      final r = contrastRatio(
        cs.onSurface,
        cs.surfaceContainerLowest,
      );
      expect(r, ge);
    });

    test('onSurface on surfaceContainerHigh', () {
      final r = contrastRatio(
        cs.onSurface,
        cs.surfaceContainerHigh,
      );
      expect(r, ge);
    });

    test('onSurface on surfaceContainerHighest', () {
      final r = contrastRatio(
        cs.onSurface,
        cs.surfaceContainerHighest,
      );
      expect(r, ge);
    });

    test('onPrimary on primary', () {
      expect(contrastRatio(cs.onPrimary, cs.primary), ge);
    });

    test('onSecondaryContainer on secondaryContainer', () {
      final r = contrastRatio(
        cs.onSecondaryContainer,
        cs.secondaryContainer,
      );
      expect(r, ge);
    });

    test('onInverseSurface on inverseSurface', () {
      final r = contrastRatio(
        cs.onInverseSurface,
        cs.inverseSurface,
      );
      expect(r, ge);
    });

    test('error on surface', () {
      expect(contrastRatio(cs.error, cs.surface), ge);
    });
  });

  group('Light theme WCAG AAA contrast (>= 7:1)', () {
    final cs = AppTheme.light().colorScheme;

    test('onSurface on surface', () {
      expect(contrastRatio(cs.onSurface, cs.surface), ge);
    });

    test('onSurface on surfaceContainerLowest', () {
      final r = contrastRatio(
        cs.onSurface,
        cs.surfaceContainerLowest,
      );
      expect(r, ge);
    });

    test('onSurface on surfaceContainerHigh', () {
      final r = contrastRatio(
        cs.onSurface,
        cs.surfaceContainerHigh,
      );
      expect(r, ge);
    });

    test('onSurface on surfaceContainerHighest', () {
      final r = contrastRatio(
        cs.onSurface,
        cs.surfaceContainerHighest,
      );
      expect(r, ge);
    });

    test('onPrimary on primary', () {
      expect(contrastRatio(cs.onPrimary, cs.primary), ge);
    });

    test('onSecondaryContainer on secondaryContainer', () {
      final r = contrastRatio(
        cs.onSecondaryContainer,
        cs.secondaryContainer,
      );
      expect(r, ge);
    });

    test('onInverseSurface on inverseSurface', () {
      final r = contrastRatio(
        cs.onInverseSurface,
        cs.inverseSurface,
      );
      expect(r, ge);
    });

    test('error on surface', () {
      expect(contrastRatio(cs.error, cs.surface), ge);
    });
  });
}
