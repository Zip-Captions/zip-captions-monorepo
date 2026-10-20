/// Which intent the one secondary window is serving.
///
/// Unit 8 ships exactly one variant. The sealed hierarchy is kept because the
/// pop-out unit (a later Phase 2 unit) reuses this window machinery and must
/// not need a second window implementation (D-1).
sealed class OverlayWindowMode {
  /// Creates an [OverlayWindowMode].
  const OverlayWindowMode();
}

/// The window shows captions on a second display or projector.
final class ExternalDisplayMode extends OverlayWindowMode {
  /// Creates an [ExternalDisplayMode].
  ///
  /// [displayId] is informational — the resolved target at open time. The
  /// persisted selection (`OutputTargetSettings.externalDisplayId`) is the
  /// source of truth (BR-U8-07, D-4).
  const ExternalDisplayMode({this.displayId});

  /// The resolved display id, or `null` for the primary display.
  final String? displayId;
}
