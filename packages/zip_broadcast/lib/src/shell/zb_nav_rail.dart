import 'package:flutter/material.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';

/// Persistent navigation rail for desktop (width > 768 px).
///
/// Shows 3 primary destinations: Home, Recording, History.
/// Settings is a trailing icon button, not a rail destination (mirrors
/// BR-U5-03/BR-U5-06 from zip_captions). Audio Inputs is reachable only via
/// Settings, not as its own nav item.
class ZbNavRail extends StatelessWidget {
  /// Creates a [ZbNavRail].
  const ZbNavRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onSettingsTap,
    this.isBroadcastActive = false,
    this.headerAction,
    super.key,
  });

  /// Index of the currently selected destination (0=Home, 1=Recording,
  /// 2=History). -1 when on a non-rail screen.
  final int selectedIndex;

  /// Called when a primary rail destination is tapped.
  final ValueChanged<int> onDestinationSelected;

  /// Called when the Settings icon is tapped.
  final VoidCallback onSettingsTap;

  /// When true, a live-broadcast indicator is shown on the Broadcast
  /// destination regardless of which screen is active.
  final bool isBroadcastActive;

  /// A control pinned above the destinations (the pop-out toggle, UX-PIP-01).
  ///
  /// Null renders nothing, which is what the web build and the widget tests
  /// that predate the pop-out pass.
  final Widget? headerAction;

  /// The width the rail's `leading` slot needs for a labelled control.
  ///
  /// `NavigationRailLabelType.all` sizes the rail to its destination labels,
  /// and the leading slot is unconstrained; without an explicit width the
  /// control's `Text` asks for the whole rail.
  static const double _leadingWidth = 72;

  @override
  Widget build(BuildContext context) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    final broadcastIcon = isBroadcastActive
        ? Badge(
            backgroundColor: Theme.of(context).colorScheme.error,
            smallSize: 8,
            child: const Icon(Icons.radio),
          )
        : const Icon(Icons.radio_outlined);

    final broadcastSelectedIcon = isBroadcastActive
        ? Badge(
            backgroundColor: Theme.of(context).colorScheme.error,
            smallSize: 8,
            child: const Icon(Icons.radio),
          )
        : const Icon(Icons.radio);

    return NavigationRail(
      selectedIndex: selectedIndex < 0 ? null : selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.all,
      // The rail's own column is narrower than a labelled `TextButton.icon`
      // and `NavigationRail` hands its `leading` a loose width, so the control
      // is given the rail's width explicitly instead of sizing itself.
      leading: headerAction == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: SizedBox(width: _leadingWidth, child: headerAction),
            ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: onSettingsTap,
                ),
              ],
            ),
          ),
        ),
      ),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: Text(l10n.appTitleDefault),
        ),
        NavigationRailDestination(
          icon: broadcastIcon,
          selectedIcon: broadcastSelectedIcon,
          label: Text(l10n.appTitleBroadcast),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.history_outlined),
          selectedIcon: const Icon(Icons.history),
          label: Text(l10n.appTitleHistory),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.podcasts_outlined),
          selectedIcon: const Icon(Icons.podcasts),
          label: Text(l10n.appTitleGoLive),
        ),
      ],
    );
  }
}
