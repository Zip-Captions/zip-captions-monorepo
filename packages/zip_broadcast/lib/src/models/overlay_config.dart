import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zip_broadcast/src/models/overlay_position.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_window_mode.dart';

part 'overlay_config.freezed.dart';

/// Configuration for a caption overlay window creation request.
@freezed
abstract class OverlayConfig with _$OverlayConfig {
  /// Creates an [OverlayConfig] instance.
  const factory OverlayConfig({
    /// Which intent the window serves; carries the resolved display id.
    @Default(ExternalDisplayMode()) OverlayWindowMode mode,

    /// Where the caption text sits inside the surface (top/bottom).
    @Default(OverlayPositionBottom()) OverlayPosition position,

    /// Shipped Phase 1 field. **Never applied:** the external display renders
    /// an opaque surface (B-8, BR-U8-26).
    @Default(0.9) double opacity,
  }) = _OverlayConfig;
}
