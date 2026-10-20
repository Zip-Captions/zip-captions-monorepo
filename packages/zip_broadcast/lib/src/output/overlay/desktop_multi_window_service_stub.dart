import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:zip_broadcast/src/output/overlay/desktop_window_service.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_window_controller.dart';

/// Web/mobile stub for [DesktopWindowService].
///
/// [isSupported] always returns false. All window methods are unreachable in
/// practice because callers guard on [isSupported] before calling them.
class DesktopMultiWindowService implements DesktopWindowService {
  /// Creates the stub.
  ///
  /// The io implementation takes an `enumerator` seam; there is no display
  /// here to enumerate, so the stub accepts nothing and callers are written
  /// against the io constructor only behind `isSupported`.
  @visibleForTesting
  DesktopMultiWindowService();
  @override
  Future<int> createWindow(String arguments) =>
      throw UnsupportedError('Multi-window is not available on this platform.');

  @override
  Future<void> closeWindow(int windowId) =>
      throw UnsupportedError('Multi-window is not available on this platform.');

  @override
  Future<void> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) =>
      throw UnsupportedError('Multi-window is not available on this platform.');

  @override
  Future<void> setFrame(int windowId, Rect frame) =>
      throw UnsupportedError('Multi-window is not available on this platform.');

  @override
  Future<void> show(int windowId) =>
      throw UnsupportedError('Multi-window is not available on this platform.');

  @override
  bool get isSupported => false;
}

/// The stub's [OverlayMethodHandlerInstaller]: there is no multi-window
/// plugin, so there is nothing to install into.
const OverlayMethodHandlerInstaller overlayMethodHandlerInstaller =
    _installNothing;

void _installNothing(OverlayMethodHandler? handler) {}
