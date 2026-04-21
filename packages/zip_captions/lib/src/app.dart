import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_captions/src/providers/settings_notifier.dart';
import 'package:zip_captions/src/routing/zc_router.dart';
import 'package:zip_core/zip_core.dart';

/// Root widget for the Zip Captions app.
class ZipCaptionsApp extends ConsumerWidget {
  /// Creates the root Zip Captions application widget.
  const ZipCaptionsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(displaySettingsProvider);
    final themeMode = switch (settings.themeModeSetting) {
      ThemeModeSetting.light => ThemeMode.light,
      ThemeModeSetting.dark => ThemeMode.dark,
      ThemeModeSetting.system => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'Zip Captions',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: zcRouter,
    );
  }
}
