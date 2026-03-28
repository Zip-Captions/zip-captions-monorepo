import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/models/app_settings.dart';
import 'package:zip_core/src/models/enums.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';

import '../helpers/prefs_helpers.dart';

// Concrete test subclass of BaseSettingsNotifier.
class TestSettingsNotifier extends BaseSettingsNotifier {
  @override
  String get keyPrefix => 'test';
}

// Hand-written provider for the test notifier.
final testSettingsProvider =
    NotifierProvider<TestSettingsNotifier, AppSettings>(
  TestSettingsNotifier.new,
);

void main() {
  group('BaseSettingsNotifier', () {
    test('loads defaults when SharedPreferences is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final settings = container.read(testSettingsProvider);
      expect(settings, equals(AppSettings.defaults()));
    });

    test('loads persisted values', () async {
      const saved = AppSettings(
        scrollDirection: ScrollDirection.topToBottom,
        captionTextSize: CaptionTextSize.xl,
        captionFont: CaptionFont.poppins,
        themeModeSetting: ThemeModeSetting.dark,
        maxVisibleLines: 5,
      );
      SharedPreferences.setMockInitialValues(
        validPrefsMap('test', saved),
      );
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final settings = container.read(testSettingsProvider);
      expect(settings.scrollDirection, ScrollDirection.topToBottom);
      expect(settings.captionTextSize, CaptionTextSize.xl);
      expect(settings.captionFont, CaptionFont.poppins);
      expect(settings.themeModeSetting, ThemeModeSetting.dark);
      expect(settings.maxVisibleLines, 5);
    });

    test('recovers defaults for corrupt fields (BR-05)', () async {
      SharedPreferences.setMockInitialValues({
        'test.scrollDirection': 'diagonal',
        'test.captionTextSize': 42,
        'test.captionFont': 'papyrus',
        // themeModeSetting missing
        'test.maxVisibleLines': 'not_a_number',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final settings = container.read(testSettingsProvider);
      final defaults = AppSettings.defaults();
      expect(settings.scrollDirection, defaults.scrollDirection);
      expect(settings.captionTextSize, defaults.captionTextSize);
      expect(settings.captionFont, defaults.captionFont);
      expect(settings.themeModeSetting, defaults.themeModeSetting);
      expect(settings.maxVisibleLines, defaults.maxVisibleLines);
    });

    test('set and persist scroll direction', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(testSettingsProvider.notifier);
      await notifier.setScrollDirection(
        ScrollDirection.topToBottom,
      );

      expect(
        container.read(testSettingsProvider).scrollDirection,
        ScrollDirection.topToBottom,
      );
      expect(
        prefs.getString('test.scrollDirection'),
        'topToBottom',
      );
    });

    test('reset clears all keys and restores defaults', () async {
      SharedPreferences.setMockInitialValues(
        validPrefsMap('test', const AppSettings(
          scrollDirection: ScrollDirection.topToBottom,
          captionTextSize: CaptionTextSize.xxl,
          captionFont: CaptionFont.cousine,
          themeModeSetting: ThemeModeSetting.light,
          maxVisibleLines: 10,
        )),
      );
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(testSettingsProvider.notifier);
      await notifier.reset();

      expect(
        container.read(testSettingsProvider),
        equals(AppSettings.defaults()),
      );
      // Keys should be removed
      expect(prefs.getString('test.scrollDirection'), isNull);
    });

    test('key prefix isolates settings', () async {
      SharedPreferences.setMockInitialValues({
        'test.scrollDirection': 'topToBottom',
        'other.scrollDirection': 'bottomToTop',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final settings = container.read(testSettingsProvider);
      expect(settings.scrollDirection, ScrollDirection.topToBottom);
    });
  });
}
