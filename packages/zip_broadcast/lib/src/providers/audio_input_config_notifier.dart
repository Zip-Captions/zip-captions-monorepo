import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/models/audio_input_config.dart';
import 'package:zip_broadcast/src/models/audio_input_visual_style.dart';

part 'audio_input_config_notifier.g.dart';

/// Manages [List<AudioInputConfig>] with SharedPreferences persistence.
///
/// Replaces the Unit 5 shell [AudioInputSettingsNotifier] for Zip Broadcast.
/// Key: `zip_broadcast.audioInputConfigs`. JSON-serialised list (Q9=A).
@Riverpod(keepAlive: true)
class AudioInputConfigNotifier extends _$AudioInputConfigNotifier {
  static const _key = 'zip_broadcast.audioInputConfigs';

  static const _defaultConfig = [
    AudioInputConfig(
      deviceId: 'default',
      name: 'System Default',
      speakerLabel: '',
      colorIndex: 0,
    ),
  ];

  Future<void>? _loadFuture;

  @override
  List<AudioInputConfig> build() {
    _loadFuture = _loadAsync();
    return _defaultConfig;
  }

  /// Adds a new config, auto-assigning the first free colour index.
  Future<void> addConfig(AudioInputConfig config) async {
    await _loadFuture;
    final usedColors = state.map((c) => c.colorIndex).toSet();
    final nextColor = List.generate(AudioInputVisualStyle.count, (i) => i)
        .firstWhere((i) => !usedColors.contains(i), orElse: () => 0);
    final updated = [...state, config.copyWith(colorIndex: nextColor)];
    state = updated;
    await _persist(updated);
  }

  /// Removes the config with [deviceId].
  Future<void> removeConfig(String deviceId) async {
    await _loadFuture;
    final updated = state.where((c) => c.deviceId != deviceId).toList();
    state = updated;
    await _persist(updated);
  }

  /// Updates the speaker label for [deviceId].
  Future<void> setSpeakerLabel(String deviceId, String label) async {
    await _loadFuture;
    final updated = state
        .map((c) => c.deviceId == deviceId ? c.copyWith(speakerLabel: label) : c)
        .toList();
    state = updated;
    await _persist(updated);
  }

  /// Updates the colour index for [deviceId].
  Future<void> setColor(String deviceId, int colorIndex) async {
    await _loadFuture;
    final updated = state
        .map(
          (c) => c.deviceId == deviceId ? c.copyWith(colorIndex: colorIndex) : c,
        )
        .toList();
    state = updated;
    await _persist(updated);
  }

  /// Updates the device selection for an existing config at [oldDeviceId].
  Future<void> setDevice(
    String oldDeviceId,
    AudioInputConfig newConfig,
  ) async {
    await _loadFuture;
    final updated = state
        .map((c) => c.deviceId == oldDeviceId ? newConfig : c)
        .toList();
    state = updated;
    await _persist(updated);
  }

  Future<void> _loadAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return;
    try {
      final list = (jsonDecode(stored) as List<dynamic>)
          .map((e) => AudioInputConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) state = list;
    } on Object {
      // Malformed storage — keep defaults.
    }
  }

  Future<void> _persist(List<AudioInputConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(configs.map((c) => c.toJson()).toList()),
    );
  }
}
