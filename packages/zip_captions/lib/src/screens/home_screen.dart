import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_core/zip_core.dart';

/// Home screen — entry point for starting a captioning session.
///
/// Shows a "Start Captioning" button and, when paused, a "Resume" button.
/// Navigates to `/recording` on Start or Resume, `/history` on View History.
class HomeScreen extends ConsumerWidget {
  /// Creates a [HomeScreen].
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingStateNotifierProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Spacer(),
            const Icon(Icons.closed_caption, size: 72),
            const SizedBox(height: 16),
            Text(
              'Real-time captions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/recording'),
              child: const Text('Start Captioning'),
            ),
            if (state is PausedState) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/recording'),
                child: const Text('Resume'),
              ),
            ],
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/history'),
              child: const Text('View History'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
