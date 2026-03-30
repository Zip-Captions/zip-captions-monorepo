import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';
import 'package:zip_core/src/providers/transcript_settings_provider.dart';

void main() {
  late ProviderContainer container;

  ProviderContainer createContainer([Map<String, Object> prefs = const {}]) {
    SharedPreferences.setMockInitialValues(prefs);
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          SharedPreferencesAsync() as SharedPreferences,
        ),
      ],
    );
  }

  group('TranscriptSettingsNotifier', () {
    test('defaults to true (capture enabled)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final value = container.read(transcriptSettingsNotifierProvider);
      expect(value, isTrue);
    });

    test('reads persisted value', () async {
      SharedPreferences.setMockInitialValues({
        'transcript.captureEnabled': false,
      });
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final value = container.read(transcriptSettingsNotifierProvider);
      expect(value, isFalse);
    });

    test('setCaptureEnabled persists and updates state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final n = container.read(transcriptSettingsNotifierProvider.notifier);
      await n.setCaptureEnabled(false);

      expect(
        container.read(transcriptSettingsNotifierProvider),
        isFalse,
      );
      expect(prefs.getBool('transcript.captureEnabled'), isFalse);
    });

    test('toggle on and off', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final n = container.read(transcriptSettingsNotifierProvider.notifier);

      await n.setCaptureEnabled(false);
      expect(container.read(transcriptSettingsNotifierProvider), isFalse);

      await n.setCaptureEnabled(true);
      expect(container.read(transcriptSettingsNotifierProvider), isTrue);
    });
  });
}
