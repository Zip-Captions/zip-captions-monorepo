import 'package:flutter/material.dart';

/// Navigation drawer shown at mobile widths.
///
/// Lists the primary destinations plus Settings (pinned to the bottom, same
/// grouping as the desktop nav rail). Audio Inputs is reachable only via
/// Settings, not as its own nav item.
class ZbNavDrawer extends StatelessWidget {
  /// Creates a [ZbNavDrawer].
  const ZbNavDrawer({
    required this.currentLocation,
    required this.onTap,
    this.isBroadcastActive = false,
    super.key,
  });

  /// Current route path (e.g. `/recording`).
  final String currentLocation;

  /// Called with the route path when a destination is tapped.
  final ValueChanged<String> onTap;

  /// When true, a live-broadcast indicator is shown on the Broadcast tile.
  final bool isBroadcastActive;

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
              trailing: isBroadcastActive
                  ? Badge(
                      backgroundColor:
                          Theme.of(context).colorScheme.error,
                      smallSize: 8,
                      child: const SizedBox.shrink(),
                    )
                  : null,
            ),
            _DrawerTile(
              icon: Icons.history_outlined,
              label: 'History',
              route: '/history',
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
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String route;
  final String currentLocation;
  final ValueChanged<String> onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final selected = currentLocation == route ||
        (route != '/' && currentLocation.startsWith('$route/'));
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: trailing,
      selected: selected,
      // Already on this route: just close the drawer instead of
      // re-navigating (avoids growing the back stack with a duplicate).
      onTap: () {
        if (selected) {
          Navigator.of(context).pop();
          return;
        }
        onTap(route);
      },
    );
  }
}
