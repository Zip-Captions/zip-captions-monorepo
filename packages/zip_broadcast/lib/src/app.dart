import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_broadcast/src/home_screen.dart';
import 'package:zip_core/zip_core.dart';

/// Root widget for the Zip Broadcast app.
class ZipBroadcastApp extends ConsumerWidget {
  /// Creates the root Zip Broadcast application widget.
  const ZipBroadcastApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Zip Broadcast',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
