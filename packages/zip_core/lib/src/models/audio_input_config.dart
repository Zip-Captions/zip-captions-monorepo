import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_input_config.freezed.dart';

/// Visual differentiation for multi-input caption rendering.
///
/// Uses [colorValue] (ARGB int) instead of `Color` to keep the model
/// layer free of Flutter UI imports. UI code converts via `Color(colorValue)`.
@freezed
abstract class AudioInputVisualStyle with _$AudioInputVisualStyle {
  /// Creates an [AudioInputVisualStyle] instance.
  const factory AudioInputVisualStyle({
    /// Caption text color for this source (ARGB int).
    required int colorValue,

    /// Optional display label shown alongside captions.
    String? label,
  }) = _AudioInputVisualStyle;
}

/// Configuration for a single audio input source.
///
/// Defined in Unit 1 for use by RecordingState and multi-input references.
/// Full audio capture implementation is Unit 2.
@freezed
abstract class AudioInputConfig with _$AudioInputConfig {
  /// Creates an [AudioInputConfig] instance.
  const factory AudioInputConfig({
    /// Unique identifier for this input.
    required String inputId,

    /// Platform audio device identifier (null = default mic).
    String? sourceDeviceId,

    /// User-assigned label (e.g., "Teacher", "Student Mic").
    required String speakerLabel,

    /// Color/indicator for rendering this source's captions.
    required AudioInputVisualStyle visualStyle,

    /// Whether this input is currently capturing.
    @Default(true) bool isActive,
  }) = _AudioInputConfig;
}
