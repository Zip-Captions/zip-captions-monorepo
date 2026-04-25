import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_broadcast/src/screens/audio_source_config_screen.dart';
import 'package:zip_broadcast/src/screens/home_screen.dart';
import 'package:zip_broadcast/src/screens/recording_screen.dart';
import 'package:zip_broadcast/src/screens/settings_screen.dart';
import 'package:zip_broadcast/src/shell/zb_app_shell.dart';

/// Application router for Zip Broadcast.
///
/// All routes are nested inside a [ShellRoute] that renders [ZbAppShell]
/// as the persistent navigation chrome (Q3=B).
final zbRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ZbAppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/recording',
          builder: (context, state) => const RecordingScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/audio-inputs',
          builder: (context, state) => const AudioSourceConfigScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const _HistoryPlaceholder(),
        ),
      ],
    ),
  ],
);

class _HistoryPlaceholder extends StatelessWidget {
  const _HistoryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('History')));
  }
}
