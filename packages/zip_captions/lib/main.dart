import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/app.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  _initLogging();
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ZipCaptionsApp(),
    ),
  );
}
