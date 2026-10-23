import 'package:flutter/material.dart';
import 'package:zip_core/src/models/caption_display_entry.dart';
import 'package:zip_core/src/models/display_settings.dart';
import 'package:zip_core/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/src/widgets/caption_display_widget.dart';

/// The pop-out toggle's shipped English labels.
///
/// `zip_core` has no ARB (FD BLM §7 shape change 1), so the window passes its
/// app's copy in whole, the same way the unavailable frame does.
/// These are the defaults, and both apps' ARB carries the identical wording
/// for `popOutEnter` and `popOutExit`.
const String popOutWindowEnterLabel = 'Picture in Picture';

/// The label the pop-out's toggle carries: inside the window the action is
/// always to leave.
const String popOutWindowExitLabel = 'Exit Picture in Picture';

/// What the pop-out window renders (FD frontend-components §7).
///
/// Opaque, themed, bottom-anchored captions through the shared
/// `CaptionDisplayWidget`, with the in-surface toggle passed in as the
/// widget's `controls` so it sits **outside** the scrolling list (R-M4) and
/// stays visible however many captions arrive.
///
/// The pop-out has no banner: UX-PIP-05's hint belongs to the main window. The
/// toggle is the way back, and it is the only one, so it renders the exit
/// action with its own icon and label (`windowToggle`, FD §4).
class PopOutWindowBody extends StatelessWidget {
  /// Creates a [PopOutWindowBody].
  const PopOutWindowBody({
    required this.activity,
    required this.entries,
    required this.interim,
    required this.settings,
    this.onTogglePopOut,
    this.toggleLabel = popOutWindowExitLabel,
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

  /// The toggle's visible label, [popOutWindowExitLabel] by default.
  final String toggleLabel;

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
                    label: toggleLabel,
                    onPressed: onTogglePopOut,
                  ),
                ),
              ),
      ),
    );
  }
}

/// The pop-out's own in-surface toggle (FD frontend-components §4).
///
/// The pop-out is by definition popped out, so this is always the exit action:
/// the filled glyph and the given label. The main window's copy of the toggle
/// lives in each app, because only the apps have ARB (BR-U8-22, R-M7 keeps
/// `zip_core.dart` free of the app widgets).
class _InSurfaceToggle extends StatelessWidget {
  const _InSurfaceToggle({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          key: const Key('popOutInSurfaceToggleWindow'),
          borderRadius: BorderRadius.circular(99),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.picture_in_picture_alt,
                  size: 18,
                  color: enabled ? scheme.onSurface : scheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: enabled ? scheme.onSurface : scheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
