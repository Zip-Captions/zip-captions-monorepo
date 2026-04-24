import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/screens/audio_source_config_screen.dart';
import 'package:zip_broadcast/src/screens/home_screen.dart';
import 'package:zip_broadcast/src/screens/recording_screen.dart';
import 'package:zip_broadcast/src/screens/settings_screen.dart';
import 'package:zip_broadcast/src/shell/zb_app_shell.dart';
import 'package:zip_core/zip_core.dart';

/// Builds a testable [MaterialApp.router] wrapping the full Zip Broadcast shell
/// and routes (Pattern 5 from NFR Design).
///
/// Creates a fresh [GoRouter] per call to prevent route-state bleed between
/// tests. Pass [overrides] to inject fakes/mocks via [ProviderScope].
/// Pass [prefs] so that [sharedPreferencesProvider] is satisfied — required
/// by [BaseSettingsNotifier] subclasses used in every screen.
Widget buildZbApp({
  List<Override> overrides = const [],
  String initialLocation = '/',
  SharedPreferences? prefs,
}) {
  final prefsOverride = prefs != null
      ? [sharedPreferencesProvider.overrideWithValue(prefs)]
      : <Override>[];
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => ZbAppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/recording',
            builder: (_, __) => const RecordingScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/audio-inputs',
            builder: (_, __) => const AudioSourceConfigScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('HistoryStub')),
            ),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [...prefsOverride, ...overrides],
    child: MaterialApp.router(
      // Use InkRipple to avoid InkSparkle shader failures in tests.
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      routerConfig: router,
    ),
  );
}
