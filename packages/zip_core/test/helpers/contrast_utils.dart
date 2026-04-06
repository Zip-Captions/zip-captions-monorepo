import 'dart:math';

import 'package:flutter/material.dart';

/// WCAG 2.1 relative luminance and contrast ratio computation (LC-03).
///
/// Test-only utility for verifying WCAG AAA (7:1) contrast compliance.

/// Computes the relative luminance of [color] per WCAG 2.1.
///
/// Returns a value between 0.0 (black) and 1.0 (white).
double relativeLuminance(Color color) {
  final r = _linearize(color.r);
  final g = _linearize(color.g);
  final b = _linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Computes the contrast ratio between [foreground] and [background].
///
/// Returns a value >= 1.0. WCAG AAA requires >= 7.0 for normal text.
double contrastRatio(Color foreground, Color background) {
  final lum1 = relativeLuminance(foreground);
  final lum2 = relativeLuminance(background);
  final lighter = max(lum1, lum2);
  final darker = min(lum1, lum2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Linearizes an sRGB channel value (0.0-1.0) to linear RGB.
double _linearize(double channel) {
  return channel <= 0.04045
      ? channel / 12.92
      : pow((channel + 0.055) / 1.055, 2.4).toDouble();
}
