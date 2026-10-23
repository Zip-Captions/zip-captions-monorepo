import 'package:flutter/material.dart';
import 'package:zip_core/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/zip_core.dart';

/// What the pop-out window renders (FD frontend-components §7).
///
/// Opaque, themed, bottom-anchored captions through the shared
/// `CaptionDisplayWidget`, with the in-surface toggle passed in as the
/// widget's `controls` so it sits **outside** the scrolling list (R-M4) and
/// stays visible however many captions arrive.
///
/// The pop-out has no banner and no chrome toggle: UX-PIP-05's hint belongs to
/// the main window and a two-line window cannot host app chrome.
class PopOutWindowBody extends StatelessWidget {
  /// Creates a [PopOutWindowBody].
  const PopOutWindowBody({
    required this.activity,
    required this.entries,
    required this.interim,
    required this.settings,
    this.onTogglePopOut,
    super.key,
  });

  /// What the session is doing, which decides whether captions are shown.
  final OverlayActivity activity;

  /// The final captions, oldest first.
  final List<CaptionDisplayEntry> entries;

  /// The trailing non-final caption, if any.
  final CaptionDisplayEntry? interim;

  /// The caption appearance settings.
  final DisplaySettings settings;

  /// Invoked by the in-surface toggle.
  ///
  /// The sub-engine's implementation sends `popOutToggle` to the main engine
  /// (FD BLM §3.3); the main engine decides, so the widget itself never closes
  /// anything.
  final VoidCallback? onTogglePopOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: ColoredBox(
        color: scheme.surface,
        child: activity == OverlayActivity.standby
            ? const SizedBox.expand()
            : SafeArea(
                child: CaptionDisplayWidget(
                  entries: [...entries, ?interim],
                  settings: settings,
                  controls: _InSurfaceToggle(
                    onPressed: onTogglePopOut,
                  ),
                ),
              ),
      ),
    );
  }
}

/// The pop-out's own in-surface toggle.
///
/// `zip_core` has no ARB, so the window passes this pill in whole: the label
/// carries the label; this widget draws the icon.
/// When no callback is supplied (a widget test, or a caller with no bridge)
/// the control still renders so the layout is unchanged.
class _InSurfaceToggle extends StatelessWidget {
  const _InSurfaceToggle({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Icon(Icons.picture_in_picture_alt_outlined),
          ),
        ),
      ),
    );
  }
}
