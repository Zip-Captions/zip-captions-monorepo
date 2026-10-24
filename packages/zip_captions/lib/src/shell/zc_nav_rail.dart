import 'package:flutter/material.dart';

/// Persistent navigation rail for desktop (width > 768px).
///
/// Shows 3 primary destinations: Home, Caption, History.
/// Settings is rendered as a trailing icon button, not a rail destination.
class ZcNavRail extends StatelessWidget {
  /// Creates a [ZcNavRail].
  const ZcNavRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onSettingsTap,
    super.key,
  });

  /// Index of the currently selected rail destination
  /// (0 = Home, 1 = Caption, 2 = History). -1 when on a non-rail screen.
  final int selectedIndex;

  /// Called when a rail destination is tapped.
  final ValueChanged<int> onDestinationSelected;

  /// Called when the Settings icon is tapped.
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex < 0 ? null : selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.all,
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: onSettingsTap,
            ),
          ),
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.closed_caption_outlined),
          selectedIcon: Icon(Icons.closed_caption),
          label: Text('Caption'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: Text('History'),
        ),
      ],
    );
  }
}
