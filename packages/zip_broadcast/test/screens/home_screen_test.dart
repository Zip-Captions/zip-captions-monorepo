import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';

import '../helpers/fake_notifiers.dart';
import '../helpers/zb_test_harness.dart';

Future<void> _pump(
  WidgetTester tester, {
  required AudioInputConfigNotifier Function() audioOverride,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    buildZbApp(
      prefs: prefs,
      overrides: [
        audioInputConfigNotifierProvider.overrideWith(audioOverride),
        broadcastRecordingNotifierProvider
            .overrideWith(FakeIdleBroadcastRecordingNotifier.new),
        obsConnectionNotifierProvider
            .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('HomeScreen', () {
    testWidgets(
        'Start Broadcast button disabled when no audio inputs configured',
        (tester) async {
      await _pump(tester, audioOverride: FakeEmptyAudioInputConfigNotifier.new);

      final buttonFinder = find.ancestor(
        of: find.text('Start Broadcast'),
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      expect(buttonFinder, findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(buttonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets(
        'Start Broadcast button enabled when 1+ inputs configured and idle',
        (tester) async {
      await _pump(
        tester,
        audioOverride: FakeOneInputAudioInputConfigNotifier.new,
      );

      final buttonFinder = find.ancestor(
        of: find.text('Start Broadcast'),
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      expect(buttonFinder, findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(buttonFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Status summary shows correct input count', (tester) async {
      await _pump(
        tester,
        audioOverride: FakeOneInputAudioInputConfigNotifier.new,
      );

      expect(find.textContaining('1 input'), findsOneWidget);
    });

    testWidgets('ComingSoonCard for Remote Viewers is present',
        (tester) async {
      await _pump(tester, audioOverride: FakeEmptyAudioInputConfigNotifier.new);

      expect(find.text('Remote Viewers'), findsOneWidget);
      expect(find.text('Coming soon'), findsAtLeastNWidgets(1));
    });

    testWidgets('Output targets section shown', (tester) async {
      await _pump(tester, audioOverride: FakeEmptyAudioInputConfigNotifier.new);

      expect(find.text('Output targets'), findsOneWidget);
    });

    testWidgets('No audio inputs text shown when empty', (tester) async {
      await _pump(tester, audioOverride: FakeEmptyAudioInputConfigNotifier.new);

      expect(find.text('No audio inputs configured.'), findsOneWidget);
    });
  });
}
