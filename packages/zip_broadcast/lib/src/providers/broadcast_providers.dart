import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/models/obs_settings.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';

part 'broadcast_providers.g.dart';

/// Manages [ObsSettings] persistence.
///
/// Host and port are stored in `SharedPreferences` (`obs.host`, `obs.port`).
/// Password is stored in `FlutterSecureStorage` key `obs.password` — never
/// logged (SEC-U3.2).
@Riverpod(keepAlive: true)
class ObsSettingsNotifier extends _$ObsSettingsNotifier {
  static const _hostKey = 'obs.host';
  static const _portKey = 'obs.port';
  static const _passwordKey = 'obs.password';

  static const _secureStorage = FlutterSecureStorage();

  @override
  ObsSettings build() {
    unawaited(_loadAsync());
    return const ObsSettings();
  }

  /// Updates all OBS connection settings and persists them.
  Future<void> update({
    String? host,
    int? port,
    String? password,
  }) async {
    final next = state.copyWith(
      host: host ?? state.host,
      port: port ?? state.port,
      password: password ?? state.password,
    );
    state = next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, next.host);
    await prefs.setInt(_portKey, next.port);
    if (password != null) {
      await _secureStorage.write(key: _passwordKey, value: next.password);
    }
  }

  Future<void> _loadAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_hostKey) ?? state.host;
    final port = prefs.getInt(_portKey) ?? state.port;
    var password = state.password;
    try {
      password =
          await _secureStorage.read(key: _passwordKey) ?? state.password;
    } on Object {
      // Secure storage unavailable — use default empty password.
    }
    state = ObsSettings(host: host, port: port, password: password);
  }
}

/// Manages [OutputTargetSettings] persistence via `SharedPreferences`.
@Riverpod(keepAlive: true)
class OutputTargetSettingsNotifier extends _$OutputTargetSettingsNotifier {
  static const _onScreenKey = 'output.onScreenEnabled';
  static const _obsKey = 'output.obsEnabled';
  static const _browserSourceKey = 'output.browserSourceEnabled';
  static const _overlayKey = 'output.overlayEnabled';
  static const _browserPortKey = 'output.browserSourcePort';

  @override
  OutputTargetSettings build() {
    unawaited(_loadAsync());
    return const OutputTargetSettings();
  }

  /// Persists and applies a complete settings update.
  Future<void> update(OutputTargetSettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onScreenKey, settings.onScreenEnabled);
    await prefs.setBool(_obsKey, settings.obsEnabled);
    await prefs.setBool(_browserSourceKey, settings.browserSourceEnabled);
    await prefs.setBool(_overlayKey, settings.overlayEnabled);
    await prefs.setInt(_browserPortKey, settings.browserSourcePort);
  }

  Future<void> _loadAsync() async {
    final prefs = await SharedPreferences.getInstance();
    state = OutputTargetSettings(
      onScreenEnabled:
          prefs.getBool(_onScreenKey) ?? state.onScreenEnabled,
      obsEnabled: prefs.getBool(_obsKey) ?? state.obsEnabled,
      browserSourceEnabled:
          prefs.getBool(_browserSourceKey) ?? state.browserSourceEnabled,
      overlayEnabled:
          prefs.getBool(_overlayKey) ?? state.overlayEnabled,
      browserSourcePort:
          prefs.getInt(_browserPortKey) ?? state.browserSourcePort,
    );
  }
}
