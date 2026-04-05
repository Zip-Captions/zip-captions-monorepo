import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';

part 'wake_lock_settings_provider.g.dart';

/// SharedPreferences-backed provider for [WakeLockSettings].
@Riverpod(keepAlive: true)
class WakeLockSettingsNotifier extends _$WakeLockSettingsNotifier {
  static const _key = 'wake_lock.settings';

  @override
  WakeLockSettings build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final stored = prefs.getString(_key);
    if (stored == null) return const WakeLockSettings();
    try {
      return WakeLockSettings.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
    } on Object {
      return const WakeLockSettings();
    }
  }

  /// Updates and persists the wake lock settings.
  Future<void> update(WakeLockSettings settings) async {
    state = settings;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
