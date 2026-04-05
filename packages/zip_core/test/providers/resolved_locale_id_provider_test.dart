import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/providers/active_locale_id_provider.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';
import 'package:zip_core/src/providers/locale_info_provider.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';

void main() {
  group('resolvedLocaleIdProvider', () {
    test('returns en-US when no engine and no selection', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localeInfoProvider.overrideWith((_) async => const <SpeechLocale>[]),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(resolvedLocaleIdProvider), 'en-US');
    });

    test('returns first supported locale when no explicit selection', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localeInfoProvider.overrideWith(
            (_) async => const [
              SpeechLocale(
                localeId: 'fr-FR',
                displayName: 'French',
                // languageCode is computed from localeId
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      // Wait for the async provider to resolve.
      await container.read(localeInfoProvider.future);

      final result = container.read(resolvedLocaleIdProvider);
      expect(result, 'fr-FR');
    });

    test('returns exact match when activeLocaleId matches', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localeInfoProvider.overrideWith(
            (_) async => const [
              SpeechLocale(
                localeId: 'en-US',
                displayName: 'English',
                // languageCode is computed from localeId
              ),
              SpeechLocale(
                localeId: 'de-DE',
                displayName: 'German',
                // languageCode is computed from localeId
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      // Set active locale.
      final notifier =
          container.read(activeLocaleIdNotifierProvider.notifier);
      await notifier.setLocaleId('de-DE');

      await container.read(localeInfoProvider.future);
      final result = container.read(resolvedLocaleIdProvider);
      expect(result, 'de-DE');
    });

    test('falls back to language-only match when exact locale is unavailable',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localeInfoProvider.overrideWith(
            (_) async => const [
              SpeechLocale(
                localeId: 'en-US',
                displayName: 'English (US)',
              ),
              SpeechLocale(
                localeId: 'de-DE',
                displayName: 'German',
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(activeLocaleIdNotifierProvider.notifier)
          .setLocaleId('en-AU');
      await container.read(localeInfoProvider.future);

      expect(container.read(resolvedLocaleIdProvider), 'en-US');
    });

    test('returns activeLocaleId when supportedLocales is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localeInfoProvider.overrideWith((_) async => const <SpeechLocale>[]),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(activeLocaleIdNotifierProvider.notifier);
      await notifier.setLocaleId('zh-CN');

      final result = container.read(resolvedLocaleIdProvider);
      expect(result, 'zh-CN');
    });
  });
}
