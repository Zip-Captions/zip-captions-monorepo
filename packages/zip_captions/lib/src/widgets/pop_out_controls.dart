import 'package:flutter/material.dart';
import 'package:zip_captions/src/widgets/pop_out_scope.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart' hide Failed;

/// The chrome toggle that enters and leaves the pop-out (UX-PIP-01).
///
/// Zip Captions' copy of the Zip Broadcast control: the two apps differ only
/// in how they read their strings (`ZcStrings` here, the generated
/// localizations there), so the widget shape, keys and rules are identical.
///
/// Shown in the app's header in both layouts. The rule it renders is
/// [popOutAvailability], the same pure function the in-surface toggle uses, so
/// the two can never disagree about whether the pop-out is available.
///
/// A disabled control still reads "Picture in Picture" and keeps its icon: the
/// user should be able to see the feature exists (BR-PIP-12). The reason is
/// visible text beneath the control, never a tooltip alone.
class PopOutControls extends StatelessWidget {
  /// Creates a [PopOutControls].
  const PopOutControls({
    required this.status,
    required this.recording,
    required this.engineAvailable,
    required this.isPoppedOut,
    required this.onToggle,
    this.hint,
    super.key,
  });

  /// The pop-out controller's status.
  final ExternalDisplayStatus status;

  /// The app's recording state.
  final RecordingState recording;

  /// Whether this app can start captioning at all (§3.1 of domain-entities).
  final bool engineAvailable;

  /// Whether the pop-out is currently on.
  final bool isPoppedOut;

  /// The shell's toggle.
  final VoidCallback onToggle;

  /// The disabled reason, when the control is disabled (BR-PIP-13).
  ///
  /// The chrome control carries it as its accessible hint; [PopOutChrome]
  /// renders the same string as the visible `Text` beneath the control, which
  /// is FD frontend-components §3's contract.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final availability = popOutAvailability(
      status: status,
      recording: recording,
      engineAvailable: engineAvailable,
    );
    if (!availability.visible) return const SizedBox.shrink();

    final l10n = ZcStringsScope.of(context);
    final label = isPoppedOut ? l10n.popOutExit : l10n.popOutEnter;
    final icon = isPoppedOut
        ? Icons.picture_in_picture_alt
        : Icons.picture_in_picture_alt_outlined;
    // One line: the chrome control shares the `AppBar` with the title and the
    // menu button on the narrow layout, and its toolbar height is fixed. A
    // stacked icon-over-label button does not fit that slot, so the label may
    // ellipsize. ARB copy with no words and no spaces ("enter") still
    // ellipsizes, deliberately: the accessible name is the semantics label,
    // not the paint. The reason renders as visible text in [PopOutChrome].
    return Semantics(
      button: true,
      enabled: availability.enabled,
      label: label,
      hint: hint,
      child: TextButton.icon(
        key: const Key('popOutToggle'),
        onPressed: availability.enabled ? onToggle : null,
        icon: Icon(icon),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// The chrome toggle plus its status lines (UX-PIP-01, BR-PIP-03 R-M8).
///
/// The status lines belong with the control because both say the same thing
/// about the same state, and both are cleared by the same transition: a
/// failure is shown next to the toggle while the controller reports it, and it
/// disappears when the status next leaves `Failed`. Layout-neutral, so the
/// wide rail and the narrow `AppBar` render the identical widget.
class PopOutChrome extends StatelessWidget {
  /// Creates a [PopOutChrome].
  const PopOutChrome({
    required this.status,
    required this.recording,
    required this.engineAvailable,
    required this.isPoppedOut,
    required this.reason,
    required this.onToggle,
    super.key,
  });

  /// The pop-out controller's status.
  final ExternalDisplayStatus status;

  /// The app's recording state.
  final RecordingState recording;

  /// Whether this app can start captioning at all.
  final bool engineAvailable;

  /// Whether the pop-out is currently on.
  final bool isPoppedOut;

  /// The disabled reason the shell already computed, or null when enabled.
  ///
  /// The shell computes `popOutAvailability` once per build and passes the
  /// result here, so the chrome does not recompute it (review round 4, n4).
  final PopOutUnavailableReason? reason;

  /// The shell's toggle.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = ZcStringsScope.of(context);
    final reasonText = switch (reason) {
      PopOutUnavailableReason.noSession => l10n.popOutUnavailableNoSession,
      PopOutUnavailableReason.noEngine => l10n.popOutUnavailableNoEngine,
      null => null,
    };

    // The chrome control has to fit an `AppBar` action on the narrow layout,
    // where the toolbar's height is fixed and its horizontal space is what is
    // left after the title and the menu button. That rules out a stacked
    // icon-over-label button and a plainly sized reason line beneath it: the
    // toolbar cannot grow, so the line is `Flexible` and capped at two lines
    // (measured: a fixed-height line overflowed by 8 px). The button itself is
    // one line, the same `TextButton.icon` in both layouts: on the rail the
    // label has room, and in the `AppBar` it may ellipsize, but neither clips
    // and neither overflows. FD frontend-components §3 requires the reason as
    // visible text with `Key('popOutToggleReason')`, so it is here.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PopOutControls(
          hint: reasonText,
          status: status,
          recording: recording,
          engineAvailable: engineAvailable,
          isPoppedOut: isPoppedOut,
          onToggle: onToggle,
        ),
        if (reasonText != null)
          // Flexible so the line wraps instead of overflow the narrow
          // `AppBar`'s fixed height; two lines fit inside the toolbar.
          Flexible(
            child: Text(
              key: const Key('popOutToggleReason'),
              reasonText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        // The open-failure line is the in-surface toggle's, not this one's:
        // the wide layout has no chrome control (fix round 6).
      ],
    );
  }
}

/// The in-surface toggle (UX-PIP-02).
///
/// Inside the caption container, in the row above the captions, so it is
/// usable from the pop-out window itself. It carries the two labels and the
/// pill surface; the callback comes from the main window's shell or, in the
/// pop-out engine, from the bridge.
///
/// Its icon and label say what it does: enter while the main window shows,
/// exit inside the pop-out, which only exists while the session is active.
/// [enabled] is FD frontend-components §4's `enabled`; the main window passes
/// the shell's availability result, so it obeys §3's rule exactly, while the
/// pop-out leaves it `true` (the window only exists because a session is on).
class PopOutInSurfaceToggle extends StatelessWidget {
  /// Creates a [PopOutInSurfaceToggle].
  const PopOutInSurfaceToggle({
    required this.isPoppedOut,
    required this.onToggle,
    this.enabled = true,
    this.windowToggle = false,
    this.reason,
    this.openFailed = false,
    super.key,
  });

  /// Whether the pop-out is currently on.
  final bool isPoppedOut;

  /// The toggle action, or null when the caller has no bridge yet.
  final VoidCallback? onToggle;

  /// Whether the control accepts taps.
  final bool enabled;

  /// Whether this instance lives inside the pop-out window (its own key).
  final bool windowToggle;

  /// Why the control is disabled, rendered as visible text beneath it
  /// (BR-PIP-13). The wide layout has no chrome control (fix round 6), so
  /// this is where the reason is seen there.
  final PopOutUnavailableReason? reason;

  /// Whether the last open failed: `popOutOpenFailed` renders beneath the
  /// control while the controller reports `Failed` (FD frontend-components
  /// §5, R-M8, moved here in fix round 6).
  final bool openFailed;

  @override
  Widget build(BuildContext context) {
    final copy = ZcStringsScope.of(context);
    final text = isPoppedOut ? copy.popOutExit : copy.popOutEnter;
    final scheme = Theme.of(context).colorScheme;
    // Popped out means "leave", wherever the toggle is drawn.
    final icon = isPoppedOut
        ? Icons.picture_in_picture_alt
        : Icons.picture_in_picture_alt_outlined;
    final canTap = enabled && onToggle != null;
    final reasonText = switch (reason) {
      PopOutUnavailableReason.noSession => copy.popOutUnavailableNoSession,
      PopOutUnavailableReason.noEngine => copy.popOutUnavailableNoEngine,
      null => null,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(99),
          child: InkWell(
            key: windowToggle
                ? const Key('popOutInSurfaceToggleWindow')
                : const Key('popOutInSurfaceToggle'),
            borderRadius: BorderRadius.circular(99),
            onTap: canTap ? onToggle : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: canTap ? scheme.onSurface : scheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: canTap ? scheme.onSurface : scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (reasonText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              key: const Key('popOutInSurfaceReason'),
              reasonText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.outline,
              ),
            ),
          ),
        if (openFailed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              key: const Key('popOutOpenFailed'),
              copy.popOutOpenFailed,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// The hint and return action that replace the caption surface while the
/// pop-out is open (UX-PIP-05, as v1 ships it).
///
/// The captions are in the pop-out, so the main window does not repeat them.
/// Main window only: the pop-out has no room for it and its own toggle is the
/// way back (the same toggle that opened it).
class PopOutBanner extends StatelessWidget {
  /// Creates a [PopOutBanner].
  const PopOutBanner({required this.onReturn, super.key});

  /// The same action the chrome toggle runs.
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final l10n = ZcStringsScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: const Key('popOutBanner'),
      width: double.infinity,
      alignment: Alignment.center,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.picture_in_picture_alt,
            size: 40,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.popOutHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('popOutReturn'),
            onPressed: onReturn,
            child: Text(l10n.popOutReturn),
          ),
        ],
      ),
    );
  }
}
