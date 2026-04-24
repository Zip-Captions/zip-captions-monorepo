import 'package:flutter/material.dart';

/// Navigation drawer shown at mobile widths.
///
/// Lists all navigable destinations including Settings and Audio Inputs.
class ZbNavDrawer extends StatelessWidget {
  /// Creates a [ZbNavDrawer].
  const ZbNavDrawer({
    required this.currentLocation,
    required this.onTap,
    super.key,
  });

  /// Current route path (e.g. `/recording`).
  final String currentLocation;

  /// Called with the route path when a destination is tapped.
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Zip Broadcast',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                ),
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
              icon: Icons.radio_outlined,
              label: 'Broadcast',
              route: '/recording',
              currentLocation: currentLocation,
              onTap: onTap,
            ),
            _DrawerTile(
              icon: Icons.history_outlined,
              label: 'History',
              route: '/history',
              currentLocation: currentLocation,
              onTap: onTap,
            ),
            _DrawerTile(
              icon: Icons.mic_outlined,
              label: 'Audio Inputs',
              route: '/audio-inputs',
              currentLocation: currentLocation,
              onTap: onTap,
            ),
            const Spacer(),
            _DrawerTile(
              icon: Icons.settings_outlined,
              label: 'Settings',
              route: '/settings',
              currentLocation: currentLocation,
              onTap: onTap,
            ),
          ],
        ),
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
