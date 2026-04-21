import 'package:zip_broadcast/src/output/overlay/desktop_window_service.dart';

/// Web/mobile stub for [DesktopWindowService].
///
/// [isSupported] always returns false. All window methods are unreachable in
/// practice because callers guard on [isSupported] before calling them.
class DesktopMultiWindowService implements DesktopWindowService {
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
  bool get isSupported => false;
}
