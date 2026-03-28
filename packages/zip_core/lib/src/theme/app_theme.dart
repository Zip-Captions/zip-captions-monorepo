import 'package:flutter/material.dart';

/// Theme factory producing Material 3 [ThemeData] for both apps.
///
/// Based on the Monolith Editorial design system. Both apps consume the same
/// theme — there are no app-specific theme overrides in Phase 0.
abstract final class AppTheme {
  /// Returns the Material 3 dark theme (Monolith Editorial dark palette).
  static ThemeData dark() {
    final colorScheme = const ColorScheme.dark(
      surface: Color(0xFF0B141D),
      surfaceContainerLowest: Color(0xFF060F18),
      surfaceContainerHigh: Color(0xFF222B34),
      surfaceContainerHighest: Color(0xFF2D3640),
      primary: Color(0xFF9ACBFF),
      onPrimary: Color(0xFF003355),
      secondaryContainer: Color(0xFF414A54),
      onSecondaryContainer: Color(0xFFE0E8F2),
      onSurface: Color(0xFFDAE3F0),
      outline: Color(0xFF8B919A),
      outlineVariant: Color(0xFF41474F),
      error: Color(0xFFFFB4AB),
      inverseSurface: Color(0xFFDAE3F0),
    ).copyWith(
      onInverseSurface: const Color(0xFF28313B),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(colorScheme),
      scaffoldBackgroundColor: colorScheme.surface,
    );
  }

  /// Returns the Material 3 light theme (Monolith Editorial light palette).
  ///
  /// Primary darkened from design spec seed #427EB5 to #1A5A8C for WCAG AAA
  /// compliance. Error darkened to #A8191F for the same reason.
  static ThemeData light() {
    final colorScheme = const ColorScheme.light(
      surface: Color(0xFFFAFCFF),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerHigh: Color(0xFFEEF2F8),
      surfaceContainerHighest: Color(0xFFE4EAF2),
      primary: Color(0xFF1A5A8C),
      secondaryContainer: Color(0xFFDAE3F0),
      onSecondaryContainer: Color(0xFF0B141D),
      onSurface: Color(0xFF0B141D),
      outline: Color(0xFF6B7380),
      outlineVariant: Color(0xFFC4CAD4),
      error: Color(0xFFA8191F),
      inverseSurface: Color(0xFF0B141D),
    ).copyWith(
      onInverseSurface: const Color(0xFFDAE3F0),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(colorScheme),
      scaffoldBackgroundColor: colorScheme.surface,
    );
  }

  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    // Inter is the UI chrome font. In Phase 0, the font is registered as an
    // asset in the app packages, not in zip_core. The font family name is
    // specified here; the app's pubspec.yaml must declare the asset.
    const fontFamily = 'Inter';

    return TextTheme(
      // Display styles
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      // Headline styles
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      // Title styles
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      // Body styles
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      // Label styles — minimum weight 500, letter-spacing +0.05em
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: colorScheme.onSurface,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: colorScheme.onSurface,
      ),
    );
  }
}
