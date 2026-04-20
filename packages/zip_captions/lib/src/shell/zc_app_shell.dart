import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_captions/src/shell/zc_nav_drawer.dart';
import 'package:zip_captions/src/shell/zc_nav_rail.dart';
import 'package:zip_core/zip_core.dart';

/// Platform-adaptive shell wrapping all routed screens with navigation chrome.
///
/// - Width > 768px: persistent [ZcNavRail] on the left.
/// - Width ≤ 768px: [AppBar] with hamburger + [ZcNavDrawer] on every screen.
class ZcAppShell extends ConsumerWidget {
  /// Creates a [ZcAppShell].
  const ZcAppShell({required this.child, super.key});

  /// The current route's page widget.
  final Widget child;

  static const _desktopBreakpoint = 768.0;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep transcriptWriterTargetProvider subscribed so it rebuilds eagerly
    // when captureEnabled changes (e.g. user re-enables Save Transcripts).
    ref.watch(transcriptWriterTargetProvider);

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

    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle(location)),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      body: child,
      drawer: ZcNavDrawer(
        currentLocation: location,
        onTap: (route) {
          context.go(route);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
