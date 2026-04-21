import 'package:flutter/material.dart';

/// Bottom navigation bar for mobile tab-bar screens (Home and History).
///
/// Only rendered on tab-bar screens (`/` and `/history`).
/// Caption and Settings are not tab destinations.
class ZcBottomNavBar extends StatelessWidget {
  /// Creates a [ZcBottomNavBar].
  const ZcBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  /// Index of the currently selected tab (0 = Home, 1 = History).
  final int currentIndex;

  /// Called when the user taps a tab.
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: 'History',
        ),
      ],
    );
  }
}
