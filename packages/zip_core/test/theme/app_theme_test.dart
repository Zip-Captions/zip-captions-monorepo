import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('dark returns valid ThemeData', () {
      final theme = AppTheme.dark();
      expect(theme, isNotNull);
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
    });

    test('light returns valid ThemeData', () {
      final theme = AppTheme.light();
      expect(theme, isNotNull);
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
    });

    test('dark theme has Monolith Editorial color tokens', () {
      final cs = AppTheme.dark().colorScheme;
      expect(cs.surface, const Color(0xFF0B141D));
      expect(cs.primary, const Color(0xFF9ACBFF));
      expect(cs.onSurface, const Color(0xFFDAE3F0));
      expect(cs.error, const Color(0xFFFFB4AB));
    });

    test('light theme has adjusted color tokens for AAA', () {
      final cs = AppTheme.light().colorScheme;
      expect(cs.surface, const Color(0xFFFAFCFF));
      expect(cs.primary, const Color(0xFF1A5A8C));
      expect(cs.onSurface, const Color(0xFF0B141D));
      expect(cs.error, const Color(0xFFA8191F));
    });

    test('both themes have non-null TextTheme styles', () {
      for (final theme in [AppTheme.dark(), AppTheme.light()]) {
        final tt = theme.textTheme;
        expect(tt.displaySmall, isNotNull);
        expect(tt.headlineLarge, isNotNull);
        expect(tt.headlineMedium, isNotNull);
        expect(tt.headlineSmall, isNotNull);
        expect(tt.bodyLarge, isNotNull);
        expect(tt.bodySmall, isNotNull);
        expect(tt.labelSmall, isNotNull);
        expect(tt.labelMedium, isNotNull);
      }
    });
  });
}
