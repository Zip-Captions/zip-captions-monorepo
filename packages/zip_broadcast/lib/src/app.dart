import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_broadcast/src/providers/settings_notifier.dart';
import 'package:zip_broadcast/src/routing/zb_router.dart';
import 'package:zip_core/zip_core.dart';

/// Root widget for the Zip Broadcast app.
class ZipBroadcastApp extends ConsumerWidget {
  /// Creates the root Zip Broadcast application widget.
  const ZipBroadcastApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(displaySettingsProvider);
    return MaterialApp.router(
      title: 'Zip Broadcast',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (settings.themeModeSetting) {
        ThemeModeSetting.dark => ThemeMode.dark,
        ThemeModeSetting.light => ThemeMode.light,
        ThemeModeSetting.system => ThemeMode.system,
      },
      routerConfig: zbRouter,
    );
  }
}
