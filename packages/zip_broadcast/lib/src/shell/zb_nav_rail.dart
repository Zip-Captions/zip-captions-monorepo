import 'package:flutter/material.dart';

/// Persistent navigation rail for desktop (width > 768 px).
///
/// Shows 3 primary destinations: Home, Recording, History.
/// Audio Inputs and Settings are trailing icon buttons, not rail destinations
/// (mirrors BR-U5-03/BR-U5-06 from zip_captions).
class ZbNavRail extends StatelessWidget {
  /// Creates a [ZbNavRail].
  const ZbNavRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onSettingsTap,
    required this.onAudioInputsTap,
    super.key,
  });

  /// Index of the currently selected destination (0=Home, 1=Recording,
  /// 2=History). -1 when on a non-rail screen.
  final int selectedIndex;

  /// Called when a primary rail destination is tapped.
  final ValueChanged<int> onDestinationSelected;

  /// Called when the Settings icon is tapped.
  final VoidCallback onSettingsTap;

  /// Called when the Audio Inputs icon is tapped.
  final VoidCallback onAudioInputsTap;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.mic_outlined),
                  tooltip: 'Audio Inputs',
                  onPressed: onAudioInputsTap,
                ),
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
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.radio_outlined),
          selectedIcon: Icon(Icons.radio),
          label: Text('Broadcast'),
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
