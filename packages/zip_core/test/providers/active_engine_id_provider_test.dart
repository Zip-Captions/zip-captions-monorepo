import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/providers/active_engine_id_provider.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';

void main() {
  group('ActiveEngineIdNotifier', () {
    test('initial state is null', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final state = container.read(activeEngineIdNotifierProvider);
      expect(state, isNull);
    });

    test('setEngineId updates state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(activeEngineIdNotifierProvider.notifier);
      await notifier.setEngineId('sherpa-onnx');
      expect(
        container.read(activeEngineIdNotifierProvider),
        'sherpa-onnx',
      );
    });

    test('setEngineId(null) clears state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(activeEngineIdNotifierProvider.notifier);
      await notifier.setEngineId('platform');
      await notifier.setEngineId(null);
      expect(container.read(activeEngineIdNotifierProvider), isNull);
    });

    test('persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(activeEngineIdNotifierProvider.notifier);
      await notifier.setEngineId('platform');

      expect(prefs.getString('stt.activeEngineId'), 'platform');
    });

    test('loads persisted value on build', () async {
      SharedPreferences.setMockInitialValues({
        'stt.activeEngineId': 'sherpa-onnx',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(activeEngineIdNotifierProvider), 'sherpa-onnx');
    });
  });
}
