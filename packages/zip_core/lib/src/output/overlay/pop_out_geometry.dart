import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zip_core/src/models/display_settings.dart';
import 'package:zip_core/src/output/overlay/display_info.dart';

/// The pop-out window's numbers, all in logical pixels.
///
/// Content size semantics: [popOutSize] describes the **content** the caption
/// surface needs (two lines plus the in-surface toggle row), and
/// [chromeAllowance] is added separately, once, by [computePopOutFrame]
/// (NFR-D §2.3, FD BLM §3.4). The minimum size is content size too.
abstract final class PopOutGeometry {
  /// The share of the display work area's width the window asks for.
  static const double widthFraction = 0.75;

  /// The number of caption lines the surface shows.
  static const int visibleLines = 2;

  /// Minimum content width (FD domain-entities §3.3).
  static const double minWidth = 320;

  /// Minimum content height.
  static const double minHeight = 96;

  /// The gap kept between the window and the bottom of the work area.
  static const double bottomMargin = 0;

  /// Vertical padding around the caption text.
  static const double captionVerticalPadding = 8;

  /// Extra leading between the two lines.
  static const double captionLineSpacing = 4;

  /// The height of the in-surface toggle row (the NFR-R §6 44x44 hit target).
  static const double toggleRowHeight = 44;
}

/// The title bar and border chrome a decorated window adds around its content.
///
/// **These are documented estimates, unverified until the Unit 9 measurement**
/// (NFR-D §2.3's P3 correction; `pip-ux-parity.md` §8.8 item 13). The Linux
/// value is a default for a conventional title bar; a GNOME header bar or a
/// themed MATE title bar measures differently, so Unit 9 records what it
/// actually saw and on which desktop.
///
/// Returns `EdgeInsets.zero` for any platform that is not a desktop, and for
/// anything the const set does not name.
EdgeInsets chromeAllowance(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.macOS:
      // The window is created `.titled, .fullSizeContentView` with the title
      // hidden and the bar transparent, so the content draws under it.
      return const EdgeInsets.only(top: _chromeTopInsetMacos);
    case TargetPlatform.windows:
      // 31 title bar + 8 borders.
      return const EdgeInsets.only(top: _chromeTopInsetWindows);
    case TargetPlatform.linux:
      // 37 title bar + 1 border.
      return const EdgeInsets.only(top: _chromeTopInsetLinux);
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return EdgeInsets.zero;
  }
}

const double _chromeTopInsetMacos = 28;
const double _chromeTopInsetWindows = 39;
const double _chromeTopInsetLinux = 38;

/// The content size for a pop-out showing [settings]' two lines in
/// [textTheme].
///
/// Height is the toggle row, plus [PopOutGeometry.visibleLines] line heights,
/// plus the leading between them, plus the caption's vertical padding. Width is
/// [PopOutGeometry.widthFraction] of [workAreaWidth], clamped to at least
/// [PopOutGeometry.minWidth] and never wider than the work area.
Size popOutSize(
  DisplaySettings settings,
  TextTheme textTheme, {
  double textScaler = 1,
  double workAreaWidth = double.infinity,
}) {
  final lineHeight = _resolvedLineHeight(settings, textTheme) * textScaler;
  final height = PopOutGeometry.toggleRowHeight +
      PopOutGeometry.visibleLines * lineHeight +
      (PopOutGeometry.visibleLines - 1) * PopOutGeometry.captionLineSpacing +
      2 * PopOutGeometry.captionVerticalPadding;

  final requestedWidth = PopOutGeometry.widthFraction * workAreaWidth;
  final upperBound = math.max(PopOutGeometry.minWidth, workAreaWidth);
  final width = requestedWidth.isFinite
      ? requestedWidth.clamp(PopOutGeometry.minWidth, upperBound)
      : PopOutGeometry.minWidth;

  return Size(width, math.max(height, PopOutGeometry.minHeight));
}

double _resolvedLineHeight(DisplaySettings settings, TextTheme textTheme) {
  final style = settings.captionTextSize.resolve(textTheme);
  final fontSize = style?.fontSize ?? 16;
  final heightFactor = style?.height ?? 1.2;
  return fontSize * heightFactor;
}

/// The frame and the display a pop-out should open on.
///
/// The display id names the `DisplayInfo` the frame was computed against.
///
/// `displayId` is null when no display is known, which means "let the platform
/// place the window": the caller then opens without a frame and the plugin's
/// own placement stands.
///
/// [mainWindowCentre] is null in production this unit (NFR-R §10.3): the
/// documented fallback picks the primary display. The parameter exists so a
/// later unit can pass a real centre without changing this function's shape.
///
/// The frame is the **outer** frame: the content size plus
/// [chromeAllowance]'s top inset for [platform]. Placement is bottom-anchored
/// and horizontally centred in the chosen display's work area, then clamped
/// inside it so a small display cannot push the window off-screen. The window
/// is framed once at open; later display or settings changes do not move it.
({Rect frame, String? displayId}) computePopOutFrame({
  required List<DisplayInfo> displays,
  required Offset? mainWindowCentre,
  required DisplaySettings settings,
  required TextTheme textTheme,
  required double textScaler,
  required TargetPlatform platform,
}) {
  final display = _resolveDisplay(displays, mainWindowCentre);
  if (display == null) {
    return (frame: Rect.zero, displayId: null);
  }

  // `DisplayInfo.bounds` *is* the work area in logical pixels, top-left
  // based (D-3), so no per-platform conversion happens here.
  final workArea = display.bounds;
  final inset = chromeAllowance(platform);
  final content = popOutSize(
    settings,
    textTheme,
    textScaler: textScaler,
    workAreaWidth: workArea.width,
  );

  final width = math.min(content.width, workArea.width);
  final height = math.min(
    content.height + inset.top + inset.bottom,
    workArea.height,
  );

  final left = (workArea.center.dx - width / 2)
      .clamp(workArea.left, math.max(workArea.left, workArea.right - width));
  final top = (workArea.bottom - height - PopOutGeometry.bottomMargin)
      .clamp(workArea.top, math.max(workArea.top, workArea.bottom - height));

  return (
    frame: Rect.fromLTWH(left.toDouble(), top.toDouble(), width, height),
    displayId: display.id,
  );
}

DisplayInfo? _resolveDisplay(
  List<DisplayInfo> displays,
  Offset? mainWindowCentre,
) {
  if (displays.isEmpty) return null;
  if (mainWindowCentre != null) {
    for (final display in displays) {
      if (display.bounds.contains(mainWindowCentre)) return display;
    }
  }
  for (final display in displays) {
    if (display.isPrimary) return display;
  }
  return displays.first;
}
