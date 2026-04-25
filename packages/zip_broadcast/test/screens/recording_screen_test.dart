import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';

import '../helpers/fake_notifiers.dart';
import '../helpers/zb_test_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RecordingScreen', () {
    testWidgets('shows Pause and Stop buttons when recording active',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/recording',
          overrides: [
            broadcastRecordingNotifierProvider
                .overrideWith(FakeActiveBroadcastRecordingNotifier.new),
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Pause button (tooltip: 'Pause') and Stop button (tooltip: 'Stop').
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.byTooltip('Stop'), findsOneWidget);
      expect(find.byTooltip('Resume'), findsNothing);
    });

    testWidgets('shows Resume and Stop buttons when paused', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/recording',
          overrides: [
            broadcastRecordingNotifierProvider
                .overrideWith(FakePausedBroadcastRecordingNotifier.new),
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Resume'), findsOneWidget);
      expect(find.byTooltip('Stop'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsNothing);
    });

    testWidgets('Paused overlay chip visible when paused', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/recording',
          overrides: [
            broadcastRecordingNotifierProvider
                .overrideWith(FakePausedBroadcastRecordingNotifier.new),
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Paused'), findsOneWidget);
    });

    testWidgets('OBS status pill shows in status bar', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/recording',
          overrides: [
            broadcastRecordingNotifierProvider
                .overrideWith(FakeActiveBroadcastRecordingNotifier.new),
            obsConnectionNotifierProvider
                .overrideWith(FakeConnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OBS'), findsOneWidget);
    });

    testWidgets('Appearance FAB is present', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/recording',
          overrides: [
            broadcastRecordingNotifierProvider
                .overrideWith(FakeActiveBroadcastRecordingNotifier.new),
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Appearance'), findsOneWidget);
    });

    testWidgets('StoppedState listener navigates to /history', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      // Use a notifier that starts active then transitions to stopped.
      final stoppedNotifier = _ControllableRecordingNotifier();

      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/recording',
          overrides: [
            broadcastRecordingNotifierProvider
                .overrideWith(() => stoppedNotifier),
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Trigger stopped state.
      stoppedNotifier.goStopped('session-1');
      await tester.pumpAndSettle();

      // Should have navigated to /history (stub shows 'HistoryStub').
      expect(find.text('HistoryStub'), findsOneWidget);
    });
  });
}

class _ControllableRecordingNotifier extends BroadcastRecordingNotifier {
  @override
  BroadcastSessionState build() => const BroadcastActiveState(
        sessionId: 'session-0',
        perEngineStates: {'mic-0': EngineActiveState()},
      );

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  void clearSession() {}

  void goStopped(String sessionId) {
    state = BroadcastStoppedState(sessionId: sessionId);
  }
}
