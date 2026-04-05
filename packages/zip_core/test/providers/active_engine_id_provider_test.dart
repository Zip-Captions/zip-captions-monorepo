import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/providers/active_engine_id_provider.dart';

void main() {
  group('ActiveEngineIdNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(activeEngineIdNotifierProvider);
      expect(state, isNull);
    });

    test('setEngineId updates state', () async {
      final container = ProviderContainer();
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
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(activeEngineIdNotifierProvider.notifier);
      await notifier.setEngineId('platform');
      await notifier.setEngineId(null);
      expect(container.read(activeEngineIdNotifierProvider), isNull);
    });

    test('persists to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(activeEngineIdNotifierProvider.notifier);
      await notifier.setEngineId('platform');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('stt.activeEngineId'), 'platform');
    });

    test('loads persisted value on build', () async {
      SharedPreferences.setMockInitialValues({
        'stt.activeEngineId': 'sherpa-onnx',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Force the provider to build and load async.
      container.read(activeEngineIdNotifierProvider);
      // Wait for async load.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        container.read(activeEngineIdNotifierProvider),
        'sherpa-onnx',
      );
    });
  });
}
