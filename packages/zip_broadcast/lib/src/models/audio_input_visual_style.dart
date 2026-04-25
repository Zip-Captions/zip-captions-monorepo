import 'package:flutter/material.dart';

/// Maps a colour index (0–3) to a pair of accent and label colours for an
/// audio input track.
///
/// Blue=0, Green=1, Purple=2, Orange=3.
class AudioInputVisualStyle {
  /// Creates an [AudioInputVisualStyle].
  const AudioInputVisualStyle({required this.accent, required this.label});

  /// Primary accent colour for the track bar and swatch.
  final Color accent;

  /// Label text colour used on dark backgrounds.
  final Color label;

  static const _styles = [
    AudioInputVisualStyle(accent: Colors.blue, label: Colors.lightBlue),
    AudioInputVisualStyle(accent: Colors.green, label: Colors.lightGreen),
    AudioInputVisualStyle(accent: Colors.purple, label: Colors.purpleAccent),
    AudioInputVisualStyle(accent: Colors.orange, label: Colors.orangeAccent),
  ];

  /// Returns the style for [colorIndex], clamping out-of-range values.
  static AudioInputVisualStyle forIndex(int colorIndex) =>
      _styles[colorIndex.clamp(0, _styles.length - 1)];

  /// The number of available colour slots.
  static int get count => _styles.length;
}
