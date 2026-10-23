/// The desired screen position for the caption overlay window.
///
/// Sealed for exhaustive matching.
sealed class OverlayPosition {
  const OverlayPosition();
}

/// Position the overlay at the top of the display.
class OverlayPositionTop extends OverlayPosition {
  /// Creates an [OverlayPositionTop] instance.
  const OverlayPositionTop();
}

/// Position the overlay at the bottom of the display (default).
class OverlayPositionBottom extends OverlayPosition {
  /// Creates an [OverlayPositionBottom] instance.
  const OverlayPositionBottom();
}

/// Position the overlay at a specific coordinate on the display.
class OverlayPositionCustom extends OverlayPosition {
  /// Creates an [OverlayPositionCustom] instance.
  const OverlayPositionCustom({required this.x, required this.y});

  /// Horizontal position in logical pixels from the left edge.
  final double x;

  /// Vertical position in logical pixels from the top edge.
  final double y;
}
