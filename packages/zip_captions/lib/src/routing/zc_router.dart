import 'package:go_router/go_router.dart';
import 'package:zip_captions/src/screens/history_screen.dart';
import 'package:zip_captions/src/screens/home_screen.dart';
import 'package:zip_captions/src/screens/recording_screen.dart';
import 'package:zip_captions/src/screens/settings_screen.dart';
import 'package:zip_captions/src/screens/transcript_viewer_screen.dart';
import 'package:zip_captions/src/shell/zc_app_shell.dart';

/// Application router for Zip Captions.
///
/// All routes are nested inside a [ShellRoute] that renders [ZcAppShell]
/// as the persistent navigation chrome.
final zcRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ZcAppShell(child: child),
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
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
          routes: [
            GoRoute(
              path: ':sessionId',
              builder: (context, state) => TranscriptViewerScreen(
                sessionId: state.pathParameters['sessionId']!,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
