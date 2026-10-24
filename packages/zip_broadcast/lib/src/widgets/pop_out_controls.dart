import 'package:flutter/material.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart' hide Failed;

/// The chrome toggle that enters and leaves the pop-out (UX-PIP-01).
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

    final l10n = ZipBroadcastLocalizations.of(context)!;
    final label = isPoppedOut ? l10n.popOutExit : l10n.popOutEnter;
    final icon = isPoppedOut
        ? Icons.picture_in_picture_alt
        : Icons.picture_in_picture_alt_outlined;
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
    final l10n = ZipBroadcastLocalizations.of(context)!;
    final theme = Theme.of(context);
    final reasonText = switch (reason) {
      PopOutUnavailableReason.noSession => l10n.popOutUnavailableNoSession,
      PopOutUnavailableReason.noEngine => l10n.popOutUnavailableNoEngine,
      null => null,
    };

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
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        if (status is Failed)
          Text(
            key: const Key('popOutOpenFailed'),
            l10n.popOutOpenFailed,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
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

  /// The toggle action, or null when there is no shell or bridge to call.
  final VoidCallback? onToggle;

  /// Whether the control accepts taps.
  final bool enabled;

  /// Whether this instance lives inside the pop-out window (its own key).
  final bool windowToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    final label = isPoppedOut ? l10n.popOutExit : l10n.popOutEnter;
    final scheme = Theme.of(context).colorScheme;
    // Popped out means "leave", wherever the toggle is drawn (FD §4).
    final icon = isPoppedOut
        ? Icons.picture_in_picture_alt
        : Icons.picture_in_picture_alt_outlined;
    final canTap = enabled && onToggle != null;

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
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: canTap ? scheme.onSurface : scheme.outline,
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
    final l10n = ZipBroadcastLocalizations.of(context)!;
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
