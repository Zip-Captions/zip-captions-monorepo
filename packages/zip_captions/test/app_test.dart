import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/app.dart';
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
          ],
          child: const ZipCaptionsApp(),
        ),
      );

      expect(find.text('Start Captioning'), findsOneWidget);
    });
  });
}
