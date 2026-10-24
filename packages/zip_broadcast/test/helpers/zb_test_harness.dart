import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/providers/pop_out_providers.dart';
import 'package:zip_broadcast/src/screens/audio_source_config_screen.dart';
import 'package:zip_broadcast/src/screens/broadcast_screen.dart';
import 'package:zip_broadcast/src/screens/home_screen.dart';
import 'package:zip_broadcast/src/screens/recording_screen.dart';
import 'package:zip_broadcast/src/screens/settings_screen.dart';
import 'package:zip_broadcast/src/shell/zb_app_shell.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart';

import 'fake_display_enumerator.dart';

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
  OverlayWindowController? popOutController,
}) {
  final prefsOverride = prefs != null
      ? [sharedPreferencesProvider.overrideWithValue(prefs)]
      : <Override>[];
  // The shell now builds a pop-out controller. On the test binding every
  // platform is supported, and a controller built from the real host opens a
  // real display observer and a real method channel per test, so the harness
  // supplies one over a fake enumerator and a recorder window service.
  final popOutOverride = [
    popOutWindowControllerProvider.overrideWithValue(
      popOutController ?? _testPopOutController(),
    ),
  ];
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => ZbAppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const HomeScreen(),
          ),
          GoRoute(
            path: '/recording',
            builder: (_, _) => const RecordingScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/audio-inputs',
            builder: (_, _) => const AudioSourceConfigScreen(),
          ),
          GoRoute(
            path: '/broadcast',
            builder: (_, _) => const BroadcastScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (_, _) => const Scaffold(
              body: Center(child: Text('HistoryStub')),
            ),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [...prefsOverride, ...popOutOverride, ...overrides],
    child: MaterialApp.router(
      // Use InkRipple to avoid InkSparkle shader failures in tests.
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      localizationsDelegates: const [
        ZipBroadcastLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: ZipBroadcastLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

/// A pop-out controller over the binding's fake enumerator and a window
/// service that records instead of creating anything.
OverlayWindowController _testPopOutController() {
  final enumerator = FakeDisplayEnumerator();
  return OverlayWindowController(
    windowService: _RecordingWindowService(),
    enumerator: enumerator,
    handlerInstaller: (_) {},
    log: Logger('test.popOut'),
    mode: const PopOutMode(),
    closeChannel: _NullCloseChannel(),
  );
}

/// Records the window calls without touching the platform.
class _RecordingWindowService implements DesktopWindowService {
  /// Every call, in order.
  final List<String> calls = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<int> createWindow(String arguments) async {
    calls.add('createWindow');
    return 1;
  }

  @override
  Future<void> closeWindow(int windowId) async => calls.add('closeWindow');

  @override
  Future<void> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) async => calls.add('invokeMethod:$method');

  @override
  Future<void> setFrame(int windowId, Rect frame) async =>
      calls.add('setFrame');

  @override
  Future<void> show(int windowId) async => calls.add('show');
}

/// A close channel that never emits.
class _NullCloseChannel implements SubWindowClosedChannel {
  @override
  void install() {}

  @override
  Stream<int> get closed => const Stream<int>.empty();

  @override
  void dispose() {}
}
