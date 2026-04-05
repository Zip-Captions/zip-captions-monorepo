import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/providers/active_locale_id_provider.dart';

void main() {
  group('ActiveLocaleIdNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(activeLocaleIdNotifierProvider);
      expect(state, isNull);
    });

    test('setLocaleId updates state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(activeLocaleIdNotifierProvider.notifier);
      await notifier.setLocaleId('fr-FR');
      expect(container.read(activeLocaleIdNotifierProvider), 'fr-FR');
    });

    test('setLocaleId(null) clears state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(activeLocaleIdNotifierProvider.notifier);
      await notifier.setLocaleId('en-US');
      await notifier.setLocaleId(null);
      expect(container.read(activeLocaleIdNotifierProvider), isNull);
    });

    test('persists to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(activeLocaleIdNotifierProvider.notifier);
      await notifier.setLocaleId('ja-JP');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('stt.activeLocaleId'), 'ja-JP');
    });

    test('loads persisted value on build', () async {
      SharedPreferences.setMockInitialValues({
        'stt.activeLocaleId': 'de-DE',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(activeLocaleIdNotifierProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(activeLocaleIdNotifierProvider), 'de-DE');
    });
  });
}
