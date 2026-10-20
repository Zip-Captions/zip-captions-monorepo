import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_broadcast/src/app.dart';
import 'package:zip_broadcast/src/auth/auth_provider_config.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_window_entry.dart';
import 'package:zip_broadcast/src/providers/broadcast_captioning_starter.dart';
import 'package:zip_core/zip_core.dart';

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

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // An external display window is its own engine: it must not initialise
  // Supabase, logging for the main app, or anything network-facing (ID-1).
  if (isOverlayWindowLaunch(args)) {
    await overlayWindowMain(args);
    return;
  }

  GoogleFonts.config.allowRuntimeFetching = false;
  _initLogging();
  final prefs = await SharedPreferences.getInstance();

  // Desktop uses SecureDesktopLocalStorage for session storage (SR-01 §4);
  // web keeps the SDK's default storage.
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    authOptions: kIsWeb
        ? const FlutterAuthClientOptions()
        : const FlutterAuthClientOptions(
            localStorage: SecureDesktopLocalStorage(),
          ),
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(Supabase.instance.client),
        authServiceProvider.overrideWithValue(
          SupabaseAuthService(
            client: Supabase.instance.client,
            providerConfig: zipBroadcastAuthProviderConfig,
          ),
        ),
        captioningStarterProvider.overrideWith(BroadcastCaptioningStarter.new),
      ],
      child: const ZipBroadcastApp(),
    ),
  );
}
