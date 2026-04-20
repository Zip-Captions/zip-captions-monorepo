import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/screens/recording_screen.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/fake_recording_state_notifier.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal router with the routes that RecordingScreen can navigate to.
GoRouter _router() => GoRouter(
      initialLocation: '/recording',
      routes: [
        GoRoute(path: '/', builder: (ctx, s) => const SizedBox()),
        GoRoute(
          path: '/recording',
          builder: (ctx, s) => const RecordingScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (ctx, s) => const SizedBox(key: Key('history-screen')),
        ),
        GoRoute(path: '/settings', builder: (ctx, s) => const SizedBox()),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  FakeRecordingStateNotifier notifier,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        recordingStateNotifierProvider.overrideWith(() => notifier),
        onScreenCaptionTargetProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RecordingScreen — entry behavior', () {
    testWidgets('calls start() when entered in idle state', (tester) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle());
      await _pump(tester, notifier);

      expect(notifier.calls, contains('start'));
      expect(notifier.calls, isNot(contains('clearSession')));
    });

    testWidgets(
        'calls clearSession() then start() when entered in stopped state',
        (tester) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.stopped(sessionId: 'prior-session'),
      );
      await _pump(tester, notifier);

      expect(notifier.calls, containsAllInOrder(['clearSession', 'start']));
    });

    testWidgets(
        'does not call start() or clearSession() when entered '
        'in recording state',
        (tester) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(tester, notifier);

      expect(notifier.calls, isNot(contains('start')));
      expect(notifier.calls, isNot(contains('clearSession')));
    });

    testWidgets(
        'does not call start() or clearSession() when entered in paused state',
        (tester) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.paused(sessionId: 'active'),
      );
      await _pump(tester, notifier);

      expect(notifier.calls, isNot(contains('start')));
      expect(notifier.calls, isNot(contains('clearSession')));
    });
  });

  group('RecordingScreen — stop navigation', () {
    testWidgets('navigates to /history when state transitions to stopped',
        (tester) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(tester, notifier);

      await notifier.stop();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-screen')), findsOneWidget);
    });
  });
}
