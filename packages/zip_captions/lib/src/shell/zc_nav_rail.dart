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
    this.headerAction,
    super.key,
  });

  /// Index of the currently selected rail destination
  /// (0 = Home, 1 = Caption, 2 = History). -1 when on a non-rail screen.
  final int selectedIndex;

  /// Called when a rail destination is tapped.
  final ValueChanged<int> onDestinationSelected;

  /// Called when the Settings icon is tapped.
  final VoidCallback onSettingsTap;

  /// A control pinned above the destinations (the pop-out toggle, UX-PIP-01).
  ///
  /// Null renders nothing, which is what the web build and the widget tests
  /// that predate the pop-out pass.
  final Widget? headerAction;

  /// The width the rail's `leading` slot needs for a labelled control.
  ///
  /// `NavigationRailLabelType.all` sizes the rail to its destination labels,
  /// and the leading slot is unconstrained; without an explicit width a
  /// labelled control's `Text` asks for the whole rail.
  static const double _leadingWidth = 72;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex < 0 ? null : selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.all,
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
