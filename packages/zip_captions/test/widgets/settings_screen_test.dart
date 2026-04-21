/// Widget tests for SettingsScreen device-auth guard on the transcript toggle.
///
/// Covers: toggle disabled when device has no screen lock; toggle enabled and
/// functional when device is secured.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/providers/device_auth_provider.dart';
import 'package:zip_captions/src/screens/settings_screen.dart';
import 'package:zip_core/zip_core.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _pump(
  WidgetTester tester, {
  required bool deviceSecured,
  // TranscriptSettingsNotifier defaults to true when no key is stored,
  // so we always write an explicit value.
  bool captureEnabled = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'transcript.captureEnabled': captureEnabled,
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceSecuredProvider.overrideWith(
          (_) => Future.value(deviceSecured),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _noLockSubtitle =
    'Requires a screen lock (PIN, pattern, or biometrics) '
    'to protect stored data.';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SettingsScreen — transcript toggle, unauthenticated device', () {
    testWidgets('toggle is disabled when device has no screen lock',
        (tester) async {
      await _pump(tester, deviceSecured: false);

      final toggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Save transcripts'),
      );
      expect(toggle.onChanged, isNull,
          reason: 'onChanged must be null to disable the toggle');
    });

    testWidgets('toggle is off when device has no screen lock', (tester) async {
      await _pump(tester, deviceSecured: false, captureEnabled: true);

      final toggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Save transcripts'),
      );
      expect(toggle.value, isFalse,
          reason: 'value is always false when device is not secured');
    });

    testWidgets('shows explanation subtitle when device has no screen lock',
        (tester) async {
      await _pump(tester, deviceSecured: false);

      expect(
        find.text(
          _noLockSubtitle,
        ),
        findsOneWidget,
      );
    });
  });

  group('SettingsScreen — transcript toggle, secured device', () {
    testWidgets('toggle is enabled when device has a screen lock',
        (tester) async {
      await _pump(tester, deviceSecured: true);

      final toggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Save transcripts'),
      );
      expect(toggle.onChanged, isNotNull,
          reason: 'onChanged must be non-null to enable the toggle');
    });

    testWidgets('no subtitle shown when device is secured', (tester) async {
      await _pump(tester, deviceSecured: true);

      expect(
        find.text(
          _noLockSubtitle,
        ),
        findsNothing,
      );
    });

    testWidgets('toggle reflects stored captureEnabled state', (tester) async {
      await _pump(tester, deviceSecured: true, captureEnabled: true);

      final toggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Save transcripts'),
      );
      expect(toggle.value, isTrue);
    });

    testWidgets('tapping toggle calls setCaptureEnabled', (tester) async {
      await _pump(tester, deviceSecured: true);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Save transcripts'));
      await tester.pumpAndSettle();

      final toggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Save transcripts'),
      );
      expect(toggle.value, isTrue);
    });
  });
}
