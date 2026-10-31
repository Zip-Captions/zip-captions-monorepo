// Review fix F4 (Unit 10): a device language change re-resolves the locale
// (Amendment 03 section 6), so deviceLocalesProvider must follow the system.
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';
import 'package:zip_core/src/providers/device_locales_provider.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';

void main() {
  testWidgets('F4: a system locale change rebuilds deviceLocales and '
      'resolvedLocaleId', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'CA')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(deviceLocalesProvider), ['en-CA']);
    expect(container.read(resolvedLocaleIdProvider), 'en-CA');

    tester.platformDispatcher.localesTestValue = const [
      Locale('fr', 'CA'),
      Locale('en', 'US'),
    ];

    expect(container.read(deviceLocalesProvider), ['fr-CA', 'en-US']);
    expect(container.read(resolvedLocaleIdProvider), 'fr-CA');
    // Let the container's own refresh timer run before the test ends.
    await tester.pump(Duration.zero);
  });

  testWidgets('F4: disposing the container stops following the system', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'CA')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final container = ProviderContainer();
    expect(container.read(deviceLocalesProvider), ['en-CA']);

    container.dispose();

    // The observer was removed with the provider: a later change is harmless.
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    expect(tester.takeException(), isNull);
  });
}
