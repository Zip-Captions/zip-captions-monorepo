import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:zip_broadcast/src/output/overlay/desktop_window_service.dart';
import 'package:zip_broadcast/src/output/overlay/display_enumerator.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_window_controller.dart';
import 'package:zip_broadcast/src/output/overlay/screen_retriever_display_enumerator.dart';

/// Production [DesktopWindowService] backed by the `desktop_multi_window`
/// platform channel.
///
/// Supported on macOS, Windows, and Linux. On unsupported platforms,
/// [isSupported] returns `false` and callers must guard before invoking
/// window APIs.
class DesktopMultiWindowService implements DesktopWindowService {
  /// Creates the production service.
  ///
  /// [enumerator] is the seam that supplies the platform inputs the frame
  /// conversion needs (the primary's full height on macOS). Production callers
  /// pass nothing and get the `screen_retriever` adapter; tests pass a fake.
  /// This service never imports the plugin itself: the conditional export
  /// supplies it (F03).
  @visibleForTesting
  DesktopMultiWindowService({DisplayEnumerator? enumerator})
      : enumerator = enumerator ?? ScreenRetrieverDisplayEnumerator();

  /// The display enumerator that supplies the frame conversion's platform
  /// inputs.
  final DisplayEnumerator enumerator;

  @override
  Future<int> createWindow(String arguments) async {
    final controller = await DesktopMultiWindow.createWindow(arguments);
    return controller.windowId;
  }

  @override
  Future<void> closeWindow(int windowId) =>
      WindowController.fromWindowId(windowId).close();

  @override
  Future<void> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) =>
      DesktopMultiWindow.invokeMethod(windowId, method, arguments);

  @override
  Future<void> setFrame(int windowId, Rect frame) {
    final converted = toPlatformFrame(frame, defaultTargetPlatform);
    return WindowController.fromWindowId(windowId).setFrame(converted);
  }

  @override
  Future<void> show(int windowId) =>
      WindowController.fromWindowId(windowId).show();

  @override
  bool get isSupported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}

/// Converts a logical top-left frame into the coordinates `setFrame` wants on
/// [target] (B-1, B-2).
///
/// `screen_retriever` 0.2.2 reports logical top-left pixels on all three
/// backends, but `desktop_multi_window`'s `setFrame` does not consume them:
///
/// - macOS builds an `NSRect` for `NSWindow.setFrame`, which is Cocoa
///   bottom-left, so `y` is flipped against the **primary's full** height
///   (menu bar included). A display positioned below the primary correctly
///   yields a negative `y`.
/// - Windows calls `MoveWindow`, which under the runner's `PerMonitorV2`
///   manifest takes physical pixels, so every edge is multiplied by *that
///   display's* scale factor.
/// - Linux takes the values as top-left logical, so this is the identity.
///
/// Pure: no I/O, no platform calls. The platform inputs are arguments, which
/// is what makes it testable without a runner. A `displayScaleFactor` of `0`
/// or `null` is treated as `1`; a `null` `primaryFullHeight` is treated as
/// `0`.
Rect toPlatformFrame(
  Rect frame,
  TargetPlatform target, {
  double? primaryFullHeight,
  double? displayScaleFactor,
}) {
  switch (target) {
    case TargetPlatform.macOS:
      final fullHeight = primaryFullHeight ?? 0;
      return Rect.fromLTWH(
        frame.left,
        fullHeight - frame.top - frame.height,
        frame.width,
        frame.height,
      );
    case TargetPlatform.windows:
      final scale = displayScaleFactor == null || displayScaleFactor == 0
          ? 1.0
          : displayScaleFactor;
      return Rect.fromLTWH(
        frame.left * scale,
        frame.top * scale,
        frame.width * scale,
        frame.height * scale,
      );
    case TargetPlatform.linux:
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      // Desktop-only unit; other targets never reach `setFrame` and are the
      // identity here so the function stays total.
      return frame;
  }
}

/// The production [OverlayMethodHandlerInstaller].
///
/// Wraps the plugin's single static handler slot, adapting its `MethodCall`
/// and `fromWindowId` into the controller's handler signature. Passing `null`
/// uninstalls.
const OverlayMethodHandlerInstaller overlayMethodHandlerInstaller =
    _installMethodHandler;

void _installMethodHandler(OverlayMethodHandler? handler) {
  if (handler == null) {
    DesktopMultiWindow.setMethodHandler(null);
    return;
  }
  DesktopMultiWindow.setMethodHandler(
    (call, fromWindowId) => handler(call.method, fromWindowId),
  );
}
