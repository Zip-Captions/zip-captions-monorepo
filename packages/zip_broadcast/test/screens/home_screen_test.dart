import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';

import '../helpers/fake_notifiers.dart';
import '../helpers/zb_test_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('HomeScreen', () {
    testWidgets(
        'Start Broadcast button disabled when no audio inputs configured',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          overrides: [
            audioInputConfigNotifierProvider
                .overrideWith(FakeEmptyAudioInputConfigNotifier.new),
            broadcastRecordingNotifierProvider
                .overrideWith(FakeIdleBroadcastRecordingNotifier.new),
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Broadcast'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets(
        'Start Broadcast button enabled when 1+ inputs configured and idle',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          overrides: [
            audioInputConfigNotifierProvider
                .overrideWith(FakeOneInputAudioInputConfigNotifier.new),
            broadcastRecordingNotifierProvider
                .overrideWith(FakeIdleBroadcastRecordingNotifier.new),
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Broadcast'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Status summary shows correct input count', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          overrides: [
            audioInputConfigNotifierProvider
                .overrideWith(FakeOneInputAudioInputConfigNotifier.new),
            broadcastRecordingNotifierProvider
                .overrideWith(FakeIdleBroadcastRecordingNotifier.new),
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('1 input'), findsOneWidget);
    });

    testWidgets('ComingSoonCard for Remote Viewers is present',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          overrides: [
            audioInputConfigNotifierProvider
                .overrideWith(FakeEmptyAudioInputConfigNotifier.new),
            broadcastRecordingNotifierProvider
                .overrideWith(FakeIdleBroadcastRecordingNotifier.new),
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Remote Viewers'), findsOneWidget);
      expect(find.text('Coming soon'), findsAtLeastNWidgets(1));
    });

    testWidgets('Output targets section shown', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          overrides: [
            audioInputConfigNotifierProvider
                .overrideWith(FakeEmptyAudioInputConfigNotifier.new),
            broadcastRecordingNotifierProvider
                .overrideWith(FakeIdleBroadcastRecordingNotifier.new),
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Output targets'), findsOneWidget);
    });

    testWidgets('No audio inputs text shown when empty', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          overrides: [
            audioInputConfigNotifierProvider
                .overrideWith(FakeEmptyAudioInputConfigNotifier.new),
            broadcastRecordingNotifierProvider
                .overrideWith(FakeIdleBroadcastRecordingNotifier.new),
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No audio inputs configured.'), findsOneWidget);
    });
  });
}
