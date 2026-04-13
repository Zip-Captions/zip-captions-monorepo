import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_captions/src/shell/zc_bottom_nav_bar.dart';
import 'package:zip_captions/src/shell/zc_nav_drawer.dart';
import 'package:zip_captions/src/shell/zc_nav_rail.dart';

/// Platform-adaptive shell wrapping all routed screens with navigation chrome.
///
/// - Width > 768px: persistent [ZcNavRail] on the left.
/// - Width ≤ 768px, tab-bar screen: [AppBar] + [ZcBottomNavBar].
/// - Width ≤ 768px, drawer screen: [AppBar] with hamburger + [ZcNavDrawer].
class ZcAppShell extends StatelessWidget {
  /// Creates a [ZcAppShell].
  const ZcAppShell({required this.child, super.key});

  /// The current route's page widget.
  final Widget child;

  static const _desktopBreakpoint = 768.0;

  /// Returns `true` for routes that show a bottom tab bar on mobile.
  static bool _isTabBarScreen(String location) =>
      location == '/' || location == '/history';

  static String _screenTitle(String location) {
    if (location == '/') return 'Zip Captions';
    if (location == '/recording') return 'Caption';
    if (location == '/settings') return 'Settings';
    if (location == '/history') return 'History';
    if (location.startsWith('/history/')) return 'Transcript';
    return 'Zip Captions';
  }

  /// Maps the current location to a rail index. Returns -1 for non-rail
  /// screens (Settings, TranscriptViewer).
  static int _railIndex(String location) {
    if (location == '/') return 0;
    if (location == '/recording') return 1;
    if (location == '/history' || location.startsWith('/history/')) return 2;
    return -1;
  }

  static String _railDestination(int index) {
    switch (index) {
      case 0:
        return '/';
      case 1:
        return '/recording';
      case 2:
        return '/history';
      default:
        return '/';
    }
  }

  /// Maps the current tab-bar location to a tab index.
  static int _tabIndex(String location) => location == '/' ? 0 : 1;

  static String _tabDestination(int index) => index == 0 ? '/' : '/history';

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.of(context).size.width;

    if (width > _desktopBreakpoint) {
      return Row(
        children: [
          ZcNavRail(
            selectedIndex: _railIndex(location),
            onDestinationSelected: (i) => context.go(_railDestination(i)),
            onSettingsTap: () => context.go('/settings'),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      );
    }

    final isTabBar = _isTabBarScreen(location);
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle(location)),
        leading: isTabBar
            ? null
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: isTabBar
          ? ZcBottomNavBar(
              currentIndex: _tabIndex(location),
              onTap: (i) => context.go(_tabDestination(i)),
            )
          : null,
      drawer: isTabBar
          ? null
          : ZcNavDrawer(
              currentLocation: location,
              onTap: (route) {
                context.go(route);
                Navigator.of(context).pop();
              },
            ),
    );
  }
}
