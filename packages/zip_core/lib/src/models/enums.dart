import 'package:flutter/material.dart';

/// Controls the flow direction of caption text on screen.
enum ScrollDirection {
  /// New captions appear at top, older captions scroll down.
  topToBottom,

  /// New captions appear at bottom, older captions scroll up (default).
  bottomToTop,
}

/// User preference for app color scheme.
///
/// Named `ThemeModeSetting` to avoid collision with Flutter's built-in
/// [ThemeMode] enum. Maps directly to [ThemeMode] at the widget layer.
enum ThemeModeSetting {
  /// Follow OS light/dark setting.
  system,

  /// Force dark theme (Monolith Editorial dark palette).
  dark,

  /// Force light theme (Monolith Editorial light palette).
  light,
}

/// Semantic text size tiers for caption display.
///
/// Maps to Material 3 [TextTheme] styles at render time, inheriting system
/// accessibility scaling via `MediaQuery.textScaleFactor`.
enum CaptionTextSize {
  /// Maps to [TextTheme.bodySmall].
  xs,

  /// Maps to [TextTheme.bodyLarge].
  sm,

  /// Maps to [TextTheme.headlineSmall] (default).
  md,

  /// Maps to [TextTheme.headlineMedium].
  lg,

  /// Maps to [TextTheme.headlineLarge].
  xl,

  /// Maps to [TextTheme.displaySmall].
  xxl;

  /// Returns the [TextStyle] from the given [textTheme] that corresponds
  /// to this size tier.
  TextStyle? resolve(TextTheme textTheme) {
    return switch (this) {
      CaptionTextSize.xs => textTheme.bodySmall,
      CaptionTextSize.sm => textTheme.bodyLarge,
      CaptionTextSize.md => textTheme.headlineSmall,
      CaptionTextSize.lg => textTheme.headlineMedium,
      CaptionTextSize.xl => textTheme.headlineLarge,
      CaptionTextSize.xxl => textTheme.displaySmall,
    };
  }
}

/// User-selectable caption display fonts.
///
/// These are the v1 fonts, all available as Google Fonts under OFL license,
/// bundled as `.ttf` assets in the app packages. Inter is the UI chrome font
/// and is not included here — this enum applies only to caption display text.
enum CaptionFont {
  /// Atkinson Hyperlegible — designed for legibility (default).
  atkinsonHyperlegible('Atkinson Hyperlegible'),

  /// Poppins — geometric sans-serif.
  poppins('Poppins'),

  /// Lexend — designed for reading proficiency.
  lexend('Lexend'),

  /// Raleway — elegant sans-serif.
  raleway('Raleway'),

  /// Comic Neue — casual, dyslexia-friendly alternative.
  comicNeue('Comic Neue'),

  /// Noto Sans — broad Unicode coverage.
  notoSans('Noto Sans'),

  /// Cousine — monospace.
  cousine('Cousine'),

  /// Inconsolata — monospace.
  inconsolata('Inconsolata');

  const CaptionFont(this.fontFamily);

  /// The font family name as registered in the app's `pubspec.yaml` assets.
  final String fontFamily;
}

/// Indicates whether a recording error should halt the state machine or be
/// surfaced as a transient notification.
enum RecordingErrorSeverity {
  /// Process halted; recording cannot continue.
  /// Transitions state to `idle`; accumulated data preserved in error.
  fatal,

  /// Momentary issue; recording continues.
  /// No state transition; error surfaced to UI for display.
  transient,
}
