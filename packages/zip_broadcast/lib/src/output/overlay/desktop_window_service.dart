/// Abstract interface for desktop window management.
///
/// `CaptionOverlayTarget` depends on this interface rather than on
/// `desktop_multi_window` directly, enabling test injection via
/// `MockDesktopWindowService` (Pattern 7, TEST-U3.2).
abstract class DesktopWindowService {
  /// Creates a new child window and returns its window ID.
  Future<int> createWindow(String arguments);

  /// Closes the child window with [windowId].
  Future<void> closeWindow(int windowId);

  /// Invokes [method] on the child window with [windowId].
  Future<void> invokeMethod(int windowId, String method, dynamic arguments);

  /// Whether the current platform supports multi-window desktop APIs.
  bool get isSupported;
}
