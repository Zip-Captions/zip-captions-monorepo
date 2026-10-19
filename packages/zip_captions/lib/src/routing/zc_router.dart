import 'package:go_router/go_router.dart';
import 'package:zip_captions/src/screens/history_screen.dart';
import 'package:zip_captions/src/screens/home_screen.dart';
import 'package:zip_captions/src/screens/join_broadcast_screen.dart';
import 'package:zip_captions/src/screens/recording_screen.dart';
import 'package:zip_captions/src/screens/settings_screen.dart';
import 'package:zip_captions/src/screens/transcript_viewer_screen.dart';
import 'package:zip_captions/src/screens/viewer_screen.dart';
import 'package:zip_captions/src/shell/zc_app_shell.dart';
import 'package:zip_captions/src/widgets/viewer_route_args.dart';

/// Application router for Zip Captions.
///
/// In-app destinations are nested inside a [ShellRoute] that renders
/// [ZcAppShell] as the persistent navigation chrome. The broadcast viewer
/// (`/b/:broadcastId`) sits outside the shell: it owns its own app bar and
/// back handling, and must not offer the app's navigation chrome.
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
          path: JoinBroadcastScreen.routePath,
          builder: (context, state) => const JoinBroadcastScreen(),
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
    GoRoute(
      path: ViewerScreen.routePath,
      name: ViewerScreen.routeName,
      builder: (context, state) => ViewerScreen(
        broadcastId: state.pathParameters['broadcastId']!,
        initialBroadcastId: switch (state.extra) {
          final ViewerRouteArgs args => args.broadcastId,
          _ => null,
        },
      ),
    ),
  ],
);
