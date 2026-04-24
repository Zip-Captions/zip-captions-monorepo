import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';

import '../helpers/fake_notifiers.dart';
import '../helpers/zb_test_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SettingsScreen', () {
    testWidgets('shows all 5 category rows in list view', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/settings',
          overrides: [
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      for (final label in [
        'Appearance',
        'OBS WebSocket',
        'Output Targets',
        'Audio Inputs',
        'Transcripts & Behaviour',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '$label not found');
      }
    });

    testWidgets('tapping OBS WebSocket shows OBS detail view', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/settings',
          overrides: [
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OBS WebSocket'));
      await tester.pumpAndSettle();

      expect(find.text('Host'), findsOneWidget);
      expect(find.text('Port'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Test Connection'), findsOneWidget);
    });

    testWidgets('OBS password field uses obscureText', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/settings',
          overrides: [
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OBS WebSocket'));
      await tester.pumpAndSettle();

      final passwordField = tester.widget<TextField>(
        find
            .ancestor(
              of: find.text('Password'),
              matching: find.byType(TextField),
            )
            .first,
      );
      expect(passwordField.obscureText, isTrue);
    });

    testWidgets('back button from OBS detail returns to list', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/settings',
          overrides: [
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OBS WebSocket'));
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Back in list view — all category rows visible again.
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('OBS WebSocket'), findsOneWidget);
    });

    testWidgets('tapping Appearance shows Appearance detail', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/settings',
          overrides: [
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();

      expect(find.text('Text size'), findsOneWidget);
    });

    testWidgets('Output Targets detail contains ComingSoonCard for Remote Viewers',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/settings',
          overrides: [
            obsConnectionNotifierProvider
                .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Output Targets'));
      await tester.pumpAndSettle();

      expect(find.text('Remote Viewers'), findsOneWidget);
      expect(find.text('Coming soon'), findsAtLeastNWidgets(1));
    });
  });
}
