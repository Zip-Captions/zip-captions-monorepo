import 'package:freezed_annotation/freezed_annotation.dart';

part 'overlay_window_config.freezed.dart';

/// The window properties a secondary window applies to itself, in its own
/// engine, over the `zip_core/overlay_window_configure` channel (FD §1.2.1).
///
/// The channel name, the method (`configure`) and these five fields are the
/// fixed contract every runner implements (NFR Design §5.1). The mode decides
/// the values: the external display is `floating: false, decorated: false`
/// (today's borderless surface, BR-U8.1-04), the pop-out is
/// `floating: true, decorated: true`.
@freezed
abstract class OverlayWindowConfig with _$OverlayWindowConfig {
  /// Creates an [OverlayWindowConfig].
  ///
  /// The defaults are the borderless external display surface Unit 8 shipped:
  /// no floating level, no decoration, no minimum size.
  const factory OverlayWindowConfig({
    /// Whether the window floats above other applications.
    @Default(false) bool floating,

    /// Whether the window has a title bar, a close button and resize handles.
    @Default(false) bool decorated,

    /// Minimum content width in logical pixels. `0` means "no minimum".
    @Default(0) double minWidth,

    /// Minimum content height in logical pixels. `0` means "no minimum".
    @Default(0) double minHeight,
  }) = _OverlayWindowConfig;
}
