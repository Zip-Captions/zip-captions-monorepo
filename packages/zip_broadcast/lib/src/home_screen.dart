import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home screen for Zip Broadcast.
///
/// Phase 0: hello-world placeholder.
class HomeScreen extends ConsumerWidget {
  /// Creates the Zip Broadcast home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zip Broadcast'),
      ),
      body: const Center(
        child: Text('Tap Start to begin captioning'),
      ),
    );
  }
}
