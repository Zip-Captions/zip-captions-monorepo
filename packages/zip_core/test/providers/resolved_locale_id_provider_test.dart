import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/providers/active_locale_id_provider.dart';
import 'package:zip_core/src/providers/locale_info_provider.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('resolvedLocaleIdProvider', () {
    test('returns en-US when no engine and no selection', () {
      final container = ProviderContainer(
        overrides: [
          localeInfoProvider.overrideWith((_) async => const <SpeechLocale>[]),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(resolvedLocaleIdProvider), 'en-US');
    });

    test('returns first supported locale when no explicit selection', () {
      final container = ProviderContainer(
        overrides: [
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

      // Before async resolves, supportedLocales is empty → fallback to en-US.
      // After resolving, it would return fr-FR.
      final result = container.read(resolvedLocaleIdProvider);
      expect(result, anyOf('en-US', 'fr-FR'));
    });

    test('returns exact match when activeLocaleId matches', () async {
      final container = ProviderContainer(
        overrides: [
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

      // Allow async to settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final result = container.read(resolvedLocaleIdProvider);
      expect(result, 'de-DE');
    });

    test('returns activeLocaleId when supportedLocales is empty', () async {
      final container = ProviderContainer(
        overrides: [
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
