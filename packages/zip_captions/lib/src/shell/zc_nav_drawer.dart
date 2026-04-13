import 'package:flutter/material.dart';

/// Navigation drawer shown on mobile for non-tab-bar screens
/// (Caption, Settings, TranscriptViewer).
///
/// Contains all 4 navigable targets: Home, Caption, History, Settings.
class ZcNavDrawer extends StatelessWidget {
  /// Creates a [ZcNavDrawer].
  const ZcNavDrawer({
    required this.currentLocation,
    required this.onTap,
    super.key,
  });

  /// The current route path (e.g. `/recording`).
  final String currentLocation;

  /// Called with the route path when a destination is tapped.
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Text(
              'Zip Captions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          _DrawerTile(
            icon: Icons.home_outlined,
            label: 'Home',
            route: '/',
            currentLocation: currentLocation,
            onTap: onTap,
          ),
          _DrawerTile(
            icon: Icons.closed_caption_outlined,
            label: 'Caption',
            route: '/recording',
            currentLocation: currentLocation,
            onTap: onTap,
          ),
          _DrawerTile(
            icon: Icons.history,
            label: 'History',
            route: '/history',
            currentLocation: currentLocation,
            onTap: onTap,
          ),
          _DrawerTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            route: '/settings',
            currentLocation: currentLocation,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentLocation,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String route;
  final String currentLocation;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = currentLocation == route ||
        (route != '/' && currentLocation.startsWith(route));
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      onTap: () => onTap(route),
    );
  }
}
