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
  /// It travels in the accessible hint rather than in painted text: the chrome
  /// control shares the narrow layout's `AppBar` with the title and the menu
  /// button, where a stacked button or a second line overflows. The in-surface
  /// toggle carries the visible copy.
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
    // stacked icon-over-label button or a reason line beneath it overflows
    // that slot, so the label may ellipsize and the reason travels in the
    // hint. ARB copy with no words and no spaces ("enter") still ellipsizes,
    // deliberately: the accessible name is the semantics label, not the paint.
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

  /// The shell's toggle.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = ZcStringsScope.of(context);
    final reason = popOutAvailability(
      status: status,
      recording: recording,
      engineAvailable: engineAvailable,
    ).reason;
    final reasonText = switch (reason) {
      PopOutUnavailableReason.noSession => l10n.popOutUnavailableNoSession,
      PopOutUnavailableReason.noEngine => l10n.popOutUnavailableNoEngine,
      null => null,
    };

    // The chrome control has to fit an `AppBar` action on the narrow layout,
    // where the toolbar's height is fixed and its horizontal space is what is
    // left after the title and the menu button. That rules out a stacked
    // icon-over-label button and a reason line beneath it. One line, the same
    // `TextButton.icon` in both layouts: on the rail the label has room, and
    // in the `AppBar` the button may ellipsize, but neither clips and neither
    // overflows. The reason travels in the semantics hint and in the in-surface
    // toggle, which has the room for visible text.
    return PopOutControls(
      hint: reasonText,
      status: status,
      recording: recording,
      engineAvailable: engineAvailable,
      isPoppedOut: isPoppedOut,
      onToggle: onToggle,
    );
  }
}

/// The in-surface toggle (UX-PIP-02).
///
/// Inside the caption container, in the row above the captions, so it is
/// usable from the pop-out window itself. It carries the two labels and the
/// pill surface; the callback comes from the main window's shell or, in the
/// pop-out engine, from [onToggle] wired to the bridge.
class PopOutInSurfaceToggle extends StatelessWidget {
  /// Creates a [PopOutInSurfaceToggle].
  const PopOutInSurfaceToggle({
    required this.isPoppedOut,
    required this.onToggle,
    this.enabled = true,
    this.windowToggle = false,
    super.key,
  });

  /// Whether the pop-out is currently on.
  final bool isPoppedOut;

  /// The toggle action.
  final VoidCallback onToggle;

  /// Whether the control accepts taps.
  final bool enabled;

  /// Whether this instance lives inside the pop-out window (its own key).
  final bool windowToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = ZcStringsScope.of(context);
    final label = isPoppedOut ? l10n.popOutExit : l10n.popOutEnter;
    final scheme = Theme.of(context).colorScheme;

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
            onTap: enabled ? onToggle : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPoppedOut
                        ? Icons.picture_in_picture_alt
                        : Icons.picture_in_picture_alt_outlined,
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
      ],
    );
  }
}

/// The hint above the caption surface while the pop-out is open (UX-PIP-05).
///
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
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              l10n.popOutHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('popOutReturn'),
            onPressed: onReturn,
            child: Text(l10n.popOutReturn),
          ),
        ],
      ),
    );
  }
}
