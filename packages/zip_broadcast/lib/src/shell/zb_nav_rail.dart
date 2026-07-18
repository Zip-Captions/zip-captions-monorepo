import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
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
        const NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: broadcastIcon,
          selectedIcon: broadcastSelectedIcon,
          label: const Text('Broadcast'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: Text('History'),
        ),
      ],
    );
  }
}
