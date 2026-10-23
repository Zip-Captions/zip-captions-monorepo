import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_captions/src/app.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart';

/// Forwards all [package:logging] records to [dart:developer.log] so that
/// every Logger call in zip_core appears in the Flutter DevTools Logging tab.
void _initLogging() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = kDebugMode ? Level.ALL : Level.WARNING;
  Logger.root.onRecord.listen((record) {
    developer.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
}

/// Starts Zip Captions, routing an overlay launch to its own engine first.
///
/// BR-U8.1-06: a pop-out or external-display window is a caption surface, not
/// an app. It must not configure Google Fonts, install the logging bridge,
/// open `SharedPreferences`, initialise Supabase, build a `ProviderContainer`
/// or pre-warm the transcript repository. The branch sits before all of them,
/// mirroring Zip Broadcast's shipped ordering, so the whole sub-engine start
/// is one call to [overlayWindowMain].
///
/// [runApp] and [isWeb] are parameters so a test can record what an overlay
/// launch does and does not do without a platform.
Future<void> runZipCaptions(
  List<String> args, {
  void Function(Widget app)? runApp,
  bool? isWeb,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isOverlayWindowLaunch(args)) {
    // The window is pumped by the same `runApp` the app uses, so a test sees
    // the launch frame through the one seam it recorded.
    await overlayWindowMain(
      args,
      pump: runApp == null ? null : (widget) async => runApp(widget),
    );
    return;
  }

  GoogleFonts.config.allowRuntimeFetching = false;
  _initLogging();
  final prefs = await SharedPreferences.getInstance();

  // Wired identically to zip_broadcast for Phase 3 auth reuse readiness
  // (Unit 2, FR-1.1) — this app has no sign-in UI in Phase 2 and never
  // calls AuthNotifier.signIn.
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    authOptions: (isWeb ?? kIsWeb)
        ? const FlutterAuthClientOptions()
        : const FlutterAuthClientOptions(
            localStorage: SecureDesktopLocalStorage(),
          ),
  );

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseClientProvider.overrideWithValue(Supabase.instance.client),
    ],
  );

  if (kDebugMode) {
    container.read(sttEngineRegistryProvider).register(FakeSttEngine());
  }
  // Pre-warm the repository so transcriptWriterTargetProvider sees
  // AsyncValue.data on its first build and registers the target
  // synchronously — no provider rebuild required.
  await container.read(transcriptRepositoryProvider.future);
  container.read(transcriptWriterTargetProvider);

  (runApp ?? _runApp)(
    UncontrolledProviderScope(
      container: container,
      child: const ZipCaptionsApp(),
    ),
  );
}

/// [runApp] itself, with the framework's own signature.
void _runApp(Widget app) => runApp(app);
