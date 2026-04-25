import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_input_config.freezed.dart';
part 'audio_input_config.g.dart';

/// Composite configuration for a single audio input source in a broadcast
/// session.
///
/// Persisted to SharedPreferences as JSON under
/// `zip_broadcast.audioInputConfigs`.
@freezed
abstract class AudioInputConfig with _$AudioInputConfig {
  /// Creates an [AudioInputConfig] instance.
  const factory AudioInputConfig({
    /// Platform device identifier, used as the STT sourceId.
    required String deviceId,

    /// Human-readable device name from the OS.
    required String name,

    /// Speaker label assigned by the user (e.g. "Speaker A").
    @Default('') String speakerLabel,

    /// Colour index (0–3) selecting from AudioInputVisualStyle.
    @Default(0) int colorIndex,
  }) = _AudioInputConfig;

  /// Deserialises from a JSON map.
  factory AudioInputConfig.fromJson(Map<String, dynamic> json) =>
      _$AudioInputConfigFromJson(json);
}
