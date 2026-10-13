import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/models/broadcast_settings.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';

part 'broadcast_settings_notifier.g.dart';

const _sessionNameKey = 'broadcast.sessionName';
const _autoStartCaptioningKey = 'broadcast.autoStartCaptioning';

/// Loads and persists [BroadcastSettings] (Phase 1 settings pattern — load
/// on build, persist on update). Read by `BroadcastSetupScreen`
/// (two-way bound form) and `BroadcastSessionNotifier` (`goLive()` reads
/// the current settings; it never writes them).
@Riverpod(keepAlive: true)
class BroadcastSettingsNotifier extends _$BroadcastSettingsNotifier {
  Future<void>? _loadFuture;

  @override
  BroadcastSettings build() {
    _loadFuture = _loadAsync();
    return const BroadcastSettings();
  }

  /// Updates and persists [sessionName].
  Future<void> updateSessionName(String sessionName) async {
    await _loadFuture;
    state = state.copyWith(sessionName: sessionName);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_sessionNameKey, sessionName);
  }

  /// Updates and persists [autoStartCaptioning].
  Future<void> setAutoStartCaptioning({
    required bool autoStartCaptioning,
  }) async {
    await _loadFuture;
    state = state.copyWith(autoStartCaptioning: autoStartCaptioning);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_autoStartCaptioningKey, autoStartCaptioning);
  }

  Future<void> _loadAsync() async {
    final prefs = ref.read(sharedPreferencesProvider);
    state = BroadcastSettings(
      sessionName: prefs.getString(_sessionNameKey) ?? state.sessionName,
      autoStartCaptioning:
          prefs.getBool(_autoStartCaptioningKey) ?? state.autoStartCaptioning,
    );
  }
}
