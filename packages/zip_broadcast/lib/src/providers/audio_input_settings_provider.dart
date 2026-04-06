import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/zip_core.dart';

part 'audio_input_settings_provider.g.dart';

/// Manages the list of audio input configurations for Zip Broadcast.
///
/// Persists a list of preferred [AudioDevice] entries in SharedPreferences.
/// Default: a single system-default microphone entry.
///
/// Shell implementation — multi-engine wiring is deferred to Unit 6.
@Riverpod(keepAlive: true)
class AudioInputSettingsNotifier extends _$AudioInputSettingsNotifier {
  static const _key = 'zip_broadcast.audioInputDevices';
  static const _defaultDevices = [
    AudioDevice(deviceId: 'default', name: 'System Default', isDefault: true),
  ];

  Future<void>? _loadFuture;

  @override
  List<AudioDevice> build() {
    _loadFuture = _loadAsync();
    return _defaultDevices;
  }

  /// Replaces the full list of configured audio input devices.
  Future<void> setDevices(List<AudioDevice> devices) async {
    await _loadFuture;
    state = devices;
    await _persist(devices);
  }

  /// Adds a device to the configuration list.
  Future<void> addDevice(AudioDevice device) async {
    await _loadFuture;
    final updated = [...state, device];
    state = updated;
    await _persist(updated);
  }

  /// Removes a device by its [deviceId].
  Future<void> removeDevice(String deviceId) async {
    await _loadFuture;
    final updated = state.where((d) => d.deviceId != deviceId).toList();
    state = updated;
    await _persist(updated);
  }

  /// Resets to the default single system-default microphone.
  Future<void> resetToDefault() async {
    await _loadFuture;
    state = _defaultDevices;
    await _persist(_defaultDevices);
  }

  Future<void> _loadAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return;
    try {
      final list = (jsonDecode(stored) as List<dynamic>)
          .map((e) => AudioDevice.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } on Object {
      // Malformed storage — fall back to defaults already set in build().
    }
  }

  Future<void> _persist(List<AudioDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(devices.map((d) => d.toJson()).toList());
    await prefs.setString(_key, json);
  }
}
