/// Which intent the one secondary window is serving.
///
/// Unit 8 shipped one variant; Unit 8.1 adds [PopOutMode], which reuses the
/// same window machinery rather than a second implementation (D-1). The mode
/// is fixed at controller construction and decides the window's configuration,
/// framing and display-consulting branches (FD BLM §2, §4.1).
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

/// The window mirrors the caption surface above the other application
/// windows (S-21, UX-PIP-01).
///
/// It carries no fields: placement is computed from the work area and the
/// caption settings (Q9 amended), and there is no persisted selection to
/// resolve (Q10 B). The values the mode implies are
/// `floating: true, decorated: true`, applied in the sub-engine over the
/// `configure` channel (FD BLM §3.2).
final class PopOutMode extends OverlayWindowMode {
  /// Creates a [PopOutMode].
  const PopOutMode();
}
