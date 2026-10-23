import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'display_info.freezed.dart';

/// One connected display, as reported by the platform.
///
/// [bounds] is the display's **work area** in logical pixels, top-left based,
/// covering the region the window may occupy (D-3). The per-platform
/// conversion to native coordinates happens in the io window adapter, never
/// here (B-1/B-2).
@freezed
abstract class DisplayInfo with _$DisplayInfo {
  /// Creates a [DisplayInfo].
  const factory DisplayInfo({
    /// Opaque, non-empty id. The only display fact persisted across launches.
    required String id,

    /// Human-readable name; may be empty. Never used as a key.
    required String label,

    /// Work-area rectangle in logical pixels, top-left origin.
    required Rect bounds,

    /// The display's scale factor. `0` or a missing value is treated as `1`
    /// by the Windows frame conversion.
    required double scaleFactor,

    /// Whether this is the primary display. Exactly one entry of a non-empty
    /// list is primary.
    required bool isPrimary,
  }) = _DisplayInfo;
}
