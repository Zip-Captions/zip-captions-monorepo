import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/providers/active_locale_id_provider.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';
import 'package:zip_core/src/providers/device_locales_provider.dart';
import 'package:zip_core/src/providers/locale_info_provider.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';

/// Builds a container with a supported locale list, device tags and an
/// optional persisted explicit choice, fully resolved.
Future<ProviderContainer> _container({
  required List<String> supported,
  required List<String> device,
  String? active,
}) async {
  SharedPreferences.setMockInitialValues(
    active == null ? <String, Object>{} : {'stt.activeLocaleId': active},
  );
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      deviceLocalesProvider.overrideWithValue(device),
      localeInfoProvider.overrideWith(
        (_) async => [
          for (final id in supported)
            SpeechLocale(localeId: id, displayName: id),
        ],
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(localeInfoProvider.future);
  return container;
}

Future<String> _resolve({
  required List<String> supported,
  required List<String> device,
  String? active,
}) async {
  final container = await _container(
    supported: supported,
    device: device,
    active: active,
  );
  return container.read(resolvedLocaleIdProvider);
}

void main() {
  // The five prior tests. Two change expectations because Amendment 03
  // section 6 replaces the Phase 1 "first supported locale when no explicit
  // selection" rule and makes en-CA the fallback:
  //  - 'returns en-US when no engine and no selection' now expects 'en-CA';
  //  - 'returns first supported locale when no explicit selection' now
  //    expects 'en-CA' (the list's first entry is never picked).
  // The other three keep their expectations; all five gain a
  // `deviceLocalesProvider.overrideWithValue(const [])` so the new device
  // step cannot be influenced by the test runner's own locale list.
  group('resolvedLocaleIdProvider', () {
    test(
      'returns en-CA when no engine, no selection and no device locale',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            deviceLocalesProvider.overrideWithValue(const []),
            localeInfoProvider.overrideWith(
              (_) async => const <SpeechLocale>[],
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(resolvedLocaleIdProvider), 'en-CA');
      },
    );

    test('uses the en-CA rules, not the first supported locale, when there is '
        'no explicit selection', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocalesProvider.overrideWithValue(const []),
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
      expect(result, 'en-CA');
    });

    test('returns exact match when activeLocaleId matches', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocalesProvider.overrideWithValue(const []),
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
      final notifier = container.read(activeLocaleIdNotifierProvider.notifier);
      await notifier.setLocaleId('de-DE');

      await container.read(localeInfoProvider.future);
      final result = container.read(resolvedLocaleIdProvider);
      expect(result, 'de-DE');
    });

    test(
      'falls back to language-only match when exact locale is unavailable',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            deviceLocalesProvider.overrideWithValue(const []),
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
      },
    );

    test('returns activeLocaleId when supportedLocales is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocalesProvider.overrideWithValue(const []),
          localeInfoProvider.overrideWith((_) async => const <SpeechLocale>[]),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(activeLocaleIdNotifierProvider.notifier);
      await notifier.setLocaleId('zh-CN');

      final result = container.read(resolvedLocaleIdProvider);
      expect(result, 'zh-CN');
    });
  });

  // Amendment 03 section 6 (TP-25), table-driven.
  group('resolvedLocaleId — explicit choice (step 1)', () {
    test('beats the device preference', () async {
      final result = await _resolve(
        supported: const ['en-US', 'en-CA', 'de-DE'],
        device: const ['en-US'],
        active: 'de',
      );
      expect(result, 'de-DE');
    });

    test('exact match is separator- and case-insensitive and returns the '
        "supported list's own id", () async {
      final result = await _resolve(
        supported: const ['de-DE'],
        device: const [],
        active: 'DE_de',
      );
      expect(result, 'de-DE');
    });

    test('language-only match applies the CA-then-US tie-break', () async {
      final result = await _resolve(
        supported: const ['en-GB', 'en-US', 'en-CA'],
        device: const [],
        active: 'en-AU',
      );
      expect(result, 'en-CA');
    });

    test('passes the choice through when nothing matches', () async {
      final result = await _resolve(
        supported: const ['fr-FR'],
        device: const ['fr-FR'],
        active: 'zh-CN',
      );
      expect(result, 'zh-CN');
    });

    test('passes the choice through while the list is loading', () async {
      final result = await _resolve(
        supported: const [],
        device: const ['fr-FR'],
        active: 'zh-CN',
      );
      expect(result, 'zh-CN');
    });
  });

  group('resolvedLocaleId — device preference (step 2)', () {
    test('beats the en-CA default', () async {
      final result = await _resolve(
        supported: const ['en-CA', 'fr-FR'],
        device: const ['fr-FR'],
      );
      expect(result, 'fr-FR');
    });

    test('device tags are tried in order', () async {
      final result = await _resolve(
        supported: const ['en-US', 'de-DE'],
        device: const ['de-DE', 'en-US'],
      );
      expect(result, 'de-DE');
    });

    test('a device tag gets a language-only match too', () async {
      final result = await _resolve(
        supported: const ['en-US', 'fr-FR'],
        device: const ['en-GB'],
      );
      expect(result, 'en-US');
    });

    test('device matching is separator- and case-insensitive', () async {
      final result = await _resolve(
        supported: const ['en-US'],
        device: const ['EN_us'],
      );
      expect(result, 'en-US');
    });

    test('regression: a cmn-led supported list with an en-US phone resolves '
        'to en_US, not cmn_CN', () async {
      final result = await _resolve(
        supported: const ['cmn_CN', 'en_US', 'fr_FR'],
        device: const ['en-US'],
      );
      expect(result, 'en_US');
    });
  });

  group('resolvedLocaleId — en-CA default (steps 3 and 4)', () {
    test('exact en-CA match when the device list is empty', () async {
      final result = await _resolve(
        supported: const ['fr-FR', 'en-CA'],
        device: const [],
      );
      expect(result, 'en-CA');
    });

    test('language-only en tie prefers CA', () async {
      final result = await _resolve(
        supported: const ['en-US', 'en-GB', 'en-CA'],
        device: const [],
      );
      expect(result, 'en-CA');
    });

    test('language-only en tie then prefers US', () async {
      final result = await _resolve(
        supported: const ['en-GB', 'en-US'],
        device: const [],
      );
      expect(result, 'en-US');
    });

    test('language-only en tie finally takes the first listed', () async {
      final result = await _resolve(
        supported: const ['en-GB', 'en-AU'],
        device: const [],
      );
      expect(result, 'en-GB');
    });

    test('passes en-CA through when nothing matches — never an arbitrary '
        'first supported locale', () async {
      final result = await _resolve(
        supported: const ['fr-FR', 'de-DE', 'cmn-CN'],
        device: const [],
      );
      expect(result, 'en-CA');
    });
  });

  group('resolvedLocaleId — while the list is loading (step 5)', () {
    test('uses the first device locale', () async {
      final result = await _resolve(
        supported: const [],
        device: const ['fr-FR', 'de-DE'],
      );
      expect(result, 'fr-FR');
    });

    test('uses en-CA when there is no device locale', () async {
      final result = await _resolve(
        supported: const [],
        device: const [],
      );
      expect(result, 'en-CA');
    });
  });

  group('resolvedLocaleId — wiring', () {
    test('recomputes when the device locales change (it watches the '
        'device-locales provider)', () async {
      var deviceTags = const ['en-US'];
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocalesProvider.overrideWith((_) => deviceTags),
          localeInfoProvider.overrideWith(
            (_) async => const [
              SpeechLocale(localeId: 'en-US', displayName: 'English'),
              SpeechLocale(localeId: 'de-DE', displayName: 'German'),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(localeInfoProvider.future);

      expect(container.read(resolvedLocaleIdProvider), 'en-US');

      deviceTags = const ['de-DE'];
      container.invalidate(deviceLocalesProvider);
      expect(
        container.read(resolvedLocaleIdProvider),
        'de-DE',
        reason:
            'a keepAlive resolver that does not watch deviceLocales '
            'would still answer en-US',
      );
    });
  });
}
