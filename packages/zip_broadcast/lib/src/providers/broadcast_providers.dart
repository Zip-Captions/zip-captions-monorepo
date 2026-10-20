import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/models/obs_settings.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/output/overlay/caption_position.dart';

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
  static const _verifiedKey = 'obs.connectionVerified';

  static const _secureStorage = FlutterSecureStorage();

  Future<void>? _loadFuture;

  @override
  ObsSettings build() {
    _loadFuture = _loadAsync();
    return const ObsSettings();
  }

  /// Updates OBS connection settings and persists them.
  ///
  /// Resets [ObsSettings.connectionVerified] to false whenever host, port, or
  /// password change, forcing the user to re-test before enabling OBS.
  Future<void> update({
    String? host,
    int? port,
    String? password,
  }) async {
    await _loadFuture;
    final credentialsChanged = (host != null && host != state.host) ||
        (port != null && port != state.port) ||
        (password != null && password != state.password);
    final next = state.copyWith(
      host: host ?? state.host,
      port: port ?? state.port,
      password: password ?? state.password,
      connectionVerified: !credentialsChanged && state.connectionVerified,
    );
    state = next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, next.host);
    await prefs.setInt(_portKey, next.port);
    if (credentialsChanged) {
      await prefs.setBool(_verifiedKey, false);
    }
    if (password != null) {
      await _secureStorage.write(key: _passwordKey, value: next.password);
    }
  }

  /// Marks the current OBS credentials as verified (connection test passed).
  Future<void> markConnectionVerified() async {
    await _loadFuture;
    state = state.copyWith(connectionVerified: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_verifiedKey, true);
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
    final verified = prefs.getBool(_verifiedKey) ?? false;
    state = ObsSettings(
      host: host,
      port: port,
      password: password,
      connectionVerified: verified,
    );
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
  static const _externalDisplayIdKey = 'output.externalDisplayId';
  static const _externalDisplayCaptionPositionKey =
      'output.externalDisplayCaptionPosition';

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
    // An absent id means "primary"; removing the key keeps that meaning
    // distinct from an empty string (BR-U8-07).
    final externalDisplayId = settings.externalDisplayId;
    if (externalDisplayId == null) {
      await prefs.remove(_externalDisplayIdKey);
    } else {
      await prefs.setString(_externalDisplayIdKey, externalDisplayId);
    }
    await prefs.setString(
      _externalDisplayCaptionPositionKey,
      settings.externalDisplayCaptionPosition.name,
    );
  }

  Future<void> _loadAsync() async {
    final prefs = await SharedPreferences.getInstance();
    state = OutputTargetSettings(
      onScreenEnabled:
          prefs.getBool(_onScreenKey) ?? state.onScreenEnabled,
      obsEnabled: prefs.getBool(_obsKey) ?? state.obsEnabled,
      browserSourceEnabled:
          prefs.getBool(_browserSourceKey) ?? state.browserSourceEnabled,
      // overlayEnabled is deliberately not read back: it keeps the model's
      // `false` default, so the switch always starts off whatever was stored
      // (D-6, BR-U8-21). Only the display id and the caption position survive
      // a relaunch.
      browserSourcePort:
          prefs.getInt(_browserPortKey) ?? state.browserSourcePort,
      externalDisplayId: prefs.getString(_externalDisplayIdKey),
      externalDisplayCaptionPosition: _captionPositionFrom(
        prefs.getString(_externalDisplayCaptionPositionKey),
      ),
    );
  }

  /// An unknown or absent stored value falls back to the default (bottom):
  /// the codec, not the settings loader, is the strict decoding boundary.
  static CaptionPosition _captionPositionFrom(String? stored) =>
      CaptionPosition.values.firstWhere(
        (position) => position.name == stored,
        orElse: () => CaptionPosition.bottom,
      );
}
