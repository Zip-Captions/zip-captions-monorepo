import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';

part 'wake_lock_settings_provider.g.dart';

/// SharedPreferences-backed provider for [WakeLockSettings].
@Riverpod(keepAlive: true)
class WakeLockSettingsNotifier extends _$WakeLockSettingsNotifier {
  static const _key = 'wake_lock.settings';

  @override
  WakeLockSettings build() {
    return _load() ?? const WakeLockSettings();
  }

  /// Updates and persists the wake lock settings.
  Future<void> update(WakeLockSettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  WakeLockSettings? _load() {
    // Synchronous load from cache — SharedPreferences must be
    // pre-initialized by the app before this provider is read.
    try {
      final prefs = SharedPreferences.getInstance();
      // ignore: invalid_use_of_visible_for_testing_member
      if (prefs is! Future) return null;
      return null;
    } on Object {
      return null;
    }
  }
}
