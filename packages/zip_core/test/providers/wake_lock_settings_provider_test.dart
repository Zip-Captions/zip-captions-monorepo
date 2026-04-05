import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';
import 'package:zip_core/src/providers/wake_lock_settings_provider.dart';

void main() {
  group('WakeLockSettingsNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state has defaults (enabled=true, releaseOnPause=true)',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(wakeLockSettingsNotifierProvider);
      expect(state.enabled, isTrue);
      expect(state.releaseOnPause, isTrue);
    });

    test('update changes state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(wakeLockSettingsNotifierProvider.notifier);
      await notifier.update(
        const WakeLockSettings(enabled: false, releaseOnPause: false),
      );

      final state = container.read(wakeLockSettingsNotifierProvider);
      expect(state.enabled, isFalse);
      expect(state.releaseOnPause, isFalse);
    });

    test('persists to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(wakeLockSettingsNotifierProvider.notifier);
      await notifier.update(
        const WakeLockSettings(enabled: false),
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('wake_lock.settings');
      expect(raw, isNotNull);
      final decoded =
          WakeLockSettings.fromJson(jsonDecode(raw!) as Map<String, dynamic>);
      expect(decoded.enabled, isFalse);
    });
  });
}
