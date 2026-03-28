import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/app.dart';
import 'package:zip_core/zip_core.dart';

void main() {
  group('ZipBroadcastApp', () {
    testWidgets('renders without error', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const ZipBroadcastApp(),
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
          child: const ZipBroadcastApp(),
        ),
      );

      expect(find.text('Zip Broadcast'), findsWidgets);
    });

    testWidgets('home screen shows placeholder text', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const ZipBroadcastApp(),
        ),
      );

      expect(
        find.text('Tap Start to begin captioning'),
        findsOneWidget,
      );
    });
  });
}
