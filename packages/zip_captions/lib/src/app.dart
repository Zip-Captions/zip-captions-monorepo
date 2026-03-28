import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_captions/src/home_screen.dart';
import 'package:zip_core/zip_core.dart';

/// Root widget for the Zip Captions app.
class ZipCaptionsApp extends ConsumerWidget {
  /// Creates the root Zip Captions application widget.
  const ZipCaptionsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Zip Captions',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
