import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/providers/active_locale_id_provider.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';

void main() {
  group('ActiveLocaleIdNotifier', () {
    test('initial state is null', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final state = container.read(activeLocaleIdNotifierProvider);
      expect(state, isNull);
    });

    test('setLocaleId updates state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(activeLocaleIdNotifierProvider.notifier);
      await notifier.setLocaleId('fr-FR');
      expect(container.read(activeLocaleIdNotifierProvider), 'fr-FR');
    });

    test('setLocaleId(null) clears state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(activeLocaleIdNotifierProvider.notifier);
      await notifier.setLocaleId('en-US');
      await notifier.setLocaleId(null);
      expect(container.read(activeLocaleIdNotifierProvider), isNull);
    });

    test('persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(activeLocaleIdNotifierProvider.notifier);
      await notifier.setLocaleId('ja-JP');

      expect(prefs.getString('stt.activeLocaleId'), 'ja-JP');
    });

    test('loads persisted value on build', () async {
      SharedPreferences.setMockInitialValues({
        'stt.activeLocaleId': 'de-DE',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(activeLocaleIdNotifierProvider), 'de-DE');
    });
  });
}
