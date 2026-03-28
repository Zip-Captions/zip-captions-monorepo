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

    testWidgets('home screen shows app title', (tester) async {
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

      expect(find.text('Zip Captions'), findsWidgets);
    });

    testWidgets('home screen shows placeholder text', (tester) async {
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

      expect(
        find.text('Tap Start to begin captioning'),
        findsOneWidget,
      );
    });
  });
}
