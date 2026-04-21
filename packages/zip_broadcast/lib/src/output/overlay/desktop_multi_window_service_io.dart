import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:zip_broadcast/src/output/overlay/desktop_window_service.dart';

/// Production [DesktopWindowService] backed by the `desktop_multi_window`
/// platform channel.
///
/// Supported on macOS, Windows, and Linux. On unsupported platforms,
/// [isSupported] returns `false` and callers must guard before invoking
/// window APIs.
class DesktopMultiWindowService implements DesktopWindowService {
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
  bool get isSupported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}
