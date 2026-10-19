import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/app.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_core/zip_core.dart';

void main() {
  group('ZipCaptionsApp', () {
    testWidgets('renders without error', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const ZipCaptionsApp(),
        ),
      );

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('home screen shows headline', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const ZipCaptionsApp(),
        ),
      );

      expect(find.text('Real-time captions'), findsOneWidget);
    });

    testWidgets('home screen shows start button', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            zcStringsProvider.overrideWith(
              (ref) async => const ZcStrings.fromMap({
                'joinBroadcastTitle': 'Join a broadcast',
              }),
            ),
          ],
          child: const ZipCaptionsApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Captioning'), findsOneWidget);
      expect(find.text('Join a broadcast'), findsOneWidget);
    });

    testWidgets('the home join affordance reads the ARB title', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            zcStringsProvider.overrideWith(
              (ref) async => const ZcStrings.fromMap({
                'joinBroadcastTitle': 'SENTINEL-JOIN',
              }),
            ),
          ],
          child: const ZipCaptionsApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SENTINEL-JOIN'), findsOneWidget);
      expect(find.text('Join a broadcast'), findsNothing);
    });
  });
}
