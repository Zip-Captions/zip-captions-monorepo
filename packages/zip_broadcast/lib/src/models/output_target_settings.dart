import 'package:freezed_annotation/freezed_annotation.dart';

part 'output_target_settings.freezed.dart';

/// Per-target enablement toggles and browser source port.
///
/// Persisted via `SharedPreferences`.
@freezed
abstract class OutputTargetSettings with _$OutputTargetSettings {
  /// Creates an [OutputTargetSettings] instance.
  const factory OutputTargetSettings({
    /// Whether on-screen caption rendering is active.
    @Default(true) bool onScreenEnabled,

    /// Whether OBS WebSocket output is active.
    @Default(false) bool obsEnabled,

    /// Whether the browser source server is active.
    @Default(false) bool browserSourceEnabled,

    /// Whether the caption overlay window is active.
    @Default(false) bool overlayEnabled,

    /// HTTP port for the browser source server. Valid range: 1024–65535.
    @Default(8080) int browserSourcePort,
  }) = _OutputTargetSettings;
}
