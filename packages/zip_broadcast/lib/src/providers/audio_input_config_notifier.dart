import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/models/audio_input_config.dart';
import 'package:zip_broadcast/src/models/audio_input_visual_style.dart';
import 'package:zip_broadcast/src/providers/audio_input_settings_provider.dart' show AudioInputSettingsNotifier;

part 'audio_input_config_notifier.g.dart';

/// Manages [List<AudioInputConfig>] with SharedPreferences persistence.
///
/// Replaces the Unit 5 shell [AudioInputSettingsNotifier] for Zip Broadcast.
/// Key: `zip_broadcast.audioInputConfigs`. JSON-serialised list (Q9=A).
@Riverpod(keepAlive: true)
class AudioInputConfigNotifier extends _$AudioInputConfigNotifier {
  static const _key = 'zip_broadcast.audioInputConfigs';
  static final _log = Logger('zip_broadcast.AudioInputConfigNotifier');

  static const _defaultConfig = [
    AudioInputConfig(
      deviceId: 'default',
      name: 'System Default',
    ),
  ];

  Future<void>? _loadFuture;

  /// Completes when the initial async SharedPreferences load has finished.
  Future<void> get loadFuture => _loadFuture ?? Future.value();

  // Serializes concurrent _persist() calls so disk writes never interleave.
  Future<void> _persistQueue = Future.value();

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
    await _enqueuePersist(updated);
  }

  /// Removes the config with [deviceId].
  Future<void> removeConfig(String deviceId) async {
    await _loadFuture;
    final updated = state.where((c) => c.deviceId != deviceId).toList();
    state = updated;
    await _enqueuePersist(updated);
  }

  /// Updates the display label for [deviceId].
  Future<void> setLabel(String deviceId, String label) async {
    await _loadFuture;
    final updated = state
        .map((c) => c.deviceId == deviceId
            ? c.copyWith(label: label)
            : c)
        .toList();
    state = updated;
    await _enqueuePersist(updated);
  }

  /// Updates the colour index for [deviceId].
  Future<void> setColor(String deviceId, int colorIndex) async {
    await _loadFuture;
    final updated = state
        .map(
          (c) => c.deviceId == deviceId
              ? c.copyWith(colorIndex: colorIndex)
              : c,
        )
        .toList();
    state = updated;
    await _enqueuePersist(updated);
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
    await _enqueuePersist(updated);
  }

  Future<void> _loadAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      if (stored == null) return;
      final list = (jsonDecode(stored) as List<dynamic>)
          .map((e) => AudioInputConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } on Object {
      // Platform error or malformed storage — keep defaults.
    }
  }

  Future<void> _enqueuePersist(List<AudioInputConfig> configs) {
    return _persistQueue = _persistQueue
        .then((_) => _persist(configs))
        .onError<Object>((e, st) {
          _log.warning('AudioInputConfig persist failed', e, st);
        });
  }

  Future<void> _persist(List<AudioInputConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(configs.map((c) => c.toJson()).toList()),
    );
  }
}
