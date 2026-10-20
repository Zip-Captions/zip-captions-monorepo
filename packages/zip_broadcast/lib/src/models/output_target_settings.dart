import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zip_broadcast/src/output/overlay/caption_position.dart';

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

    /// Selected external display id (`output.externalDisplayId`). `null` means
    /// the primary display. A value no longer present in the display list is
    /// kept as-is — it is the id the waiting state waits for (BR-U8-07, D-4).
    String? externalDisplayId,

    /// Where the caption block sits in the external display surface
    /// (`output.externalDisplayCaptionPosition`, B-8).
    @Default(CaptionPosition.bottom)
    CaptionPosition externalDisplayCaptionPosition,
  }) = _OutputTargetSettings;
}
