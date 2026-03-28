import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide addTearDown, expect, group, test;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';
import 'package:zip_core/src/providers/locale_provider.dart';

import '../helpers/generators.dart';

void main() {
  group('Locale round-trip PBT', () {
    Glados(arbitraryLocaleId).test(
      'setLocale then fresh build returns same language code',
      (localeId) async {
        // Extract language code the same way Locale does.
        final langCode = localeId.contains(RegExp('[_-]'))
            ? localeId.substring(0, localeId.indexOf(RegExp('[_-]')))
            : localeId;
        final locale = Locale(langCode);

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
        await notifier.setLocale(locale);

        // Simulate app restart with a fresh container.
        final container2 = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container2.dispose);

        final reloaded = container2.read(localeNotifierProvider);
        expect(
          reloaded.languageCode,
          locale.languageCode,
        );
      },
    );

    test('fallback always returns a valid Locale', () async {
      // Missing key — should fall back to device or English.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final locale = container.read(localeNotifierProvider);
      expect(locale.languageCode, isNotEmpty);
    });

    test('corrupt locale key falls back gracefully', () async {
      SharedPreferences.setMockInitialValues({
        'app_locale': '',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final locale = container.read(localeNotifierProvider);
      expect(locale.languageCode, isNotEmpty);
    });
  });
}
