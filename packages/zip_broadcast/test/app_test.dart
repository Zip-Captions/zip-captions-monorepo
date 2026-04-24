import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/app.dart';
import 'package:zip_broadcast/src/providers/stt_engine_factory_provider.dart';
import 'package:zip_core/zip_core.dart';

void main() {
  group('ZipBroadcastApp', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pumpApp(WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      // Override each engine instance that could be requested during the test.
      // The home screen does not start a session so the factory is not called;
      // this override is a safety net for any eager reads.
      final engineOverride = sttEngineFactoryProvider('default')
          .overrideWith((_) => FakeSttEngine());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            engineOverride,
          ],
          child: const ZipBroadcastApp(),
        ),
      );
    }

    testWidgets('renders without error', (tester) async {
      await pumpApp(tester);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('shows Start Broadcast button on home screen', (tester) async {
      await pumpApp(tester);
      await tester.pump();
      expect(find.text('Start Broadcast'), findsOneWidget);
    });

    testWidgets('shows output targets section on home screen', (tester) async {
      await pumpApp(tester);
      await tester.pump();
      expect(find.text('Output targets'), findsOneWidget);
    });
  });
}
