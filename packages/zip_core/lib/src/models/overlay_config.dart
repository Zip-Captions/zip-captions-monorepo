import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zip_core/src/models/overlay_position.dart';
import 'package:zip_core/src/models/overlay_window_config.dart';
import 'package:zip_core/src/output/overlay/overlay_window_mode.dart';

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

    /// The pop-out's toggle label, localized by the app that opens it.
    ///
    /// `zip_core` has no ARB (FD BLM §7 shape change 1), so the app passes its
    /// copy through the launch payload; the default is the shipped English
    /// wording. The external display ignores it: it renders no toggle.
    String? popOutToggleLabel,

    /// Shipped Phase 1 field. **Never applied:** the external display renders
    /// an opaque surface (B-8, BR-U8-26).
    @Default(0.9) double opacity,
  }) = _OverlayConfig;
}

/// The window properties a config implies (FD §1.2.1, BR-U8.1-04).
///
/// Both modes ride one `configure` channel; only the values differ, so the
/// mapping lives beside the config rather than in each runner.
extension OverlayConfigWindowProperties on OverlayConfig {
  /// Floating, decorated and minimum-sized for the pop-out; borderless for the
  /// external display, exactly as Unit 8 shipped it.
  OverlayWindowConfig get windowConfig => switch (mode) {
        ExternalDisplayMode() => const OverlayWindowConfig(),
        PopOutMode() => const OverlayWindowConfig(
            floating: true,
            decorated: true,
            minWidth: 200,
            minHeight: 120,
          ),
      };
}
