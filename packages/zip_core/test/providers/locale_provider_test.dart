import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';
import 'package:zip_core/src/providers/locale_provider.dart';

void main() {
  group('LocaleNotifier', () {
    test('loads persisted locale', () async {
      SharedPreferences.setMockInitialValues({
        'app_locale': 'fr',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final locale = container.read(localeNotifierProvider);
      expect(locale.languageCode, 'fr');
    });

    test('falls back to device locale when not persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final locale = container.read(localeNotifierProvider);
      // In test environment, device locale is valid
      expect(locale.languageCode, isNotEmpty);
    });

    test('setLocale persists and updates state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        localeNotifierProvider.notifier,
      );
      await notifier.setLocale(const Locale('de'));

      expect(
        container.read(localeNotifierProvider).languageCode,
        'de',
      );
      expect(prefs.getString('app_locale'), 'de');
    });

    test('round-trip: set then reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        localeNotifierProvider.notifier,
      );
      await notifier.setLocale(const Locale('es'));

      // Create a fresh container to simulate app restart
      final container2 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container2.dispose);

      expect(
        container2.read(localeNotifierProvider).languageCode,
        'es',
      );
    });
  });
}
