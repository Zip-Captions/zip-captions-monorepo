import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zip_broadcast/src/models/overlay_position.dart';

part 'overlay_config.freezed.dart';

/// Configuration for a caption overlay window creation request.
@freezed
abstract class OverlayConfig with _$OverlayConfig {
  /// Creates an [OverlayConfig] instance.
  const factory OverlayConfig({
    /// Which display to open the overlay on. `null` = primary display.
    String? targetDisplayId,

    /// Where to position the overlay window.
    @Default(OverlayPositionBottom()) OverlayPosition position,

    /// Window opacity from 0.0 (transparent) to 1.0 (opaque).
    @Default(0.9) double opacity,
  }) = _OverlayConfig;
}
