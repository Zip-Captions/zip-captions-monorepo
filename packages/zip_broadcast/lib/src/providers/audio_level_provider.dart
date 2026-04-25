import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/zip_core.dart' show AudioDeviceService;

part 'audio_level_provider.g.dart';

/// Per-source RMS audio level map (deviceId → 0.0–1.0).
///
/// Production: wired to [AudioDeviceService] level stream when that API is
/// available. Currently returns an empty map (placeholder).
/// Tests override with a fixed map via
/// `audioLevelProvider.overrideWithValue`.
@riverpod
Map<String, double> audioLevel(Ref ref) {
  return const {};
}
