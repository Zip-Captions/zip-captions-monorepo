import 'dart:ui';

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

  /// Moves and resizes the child window to [frame].
  ///
  /// [frame] is logical top-left, as reported by `DisplayInfo.bounds`; the io
  /// implementation converts it into platform-native coordinates with
  /// `toPlatformFrame` (B-1, B-2).
  Future<void> setFrame(int windowId, Rect frame);

  /// Shows the child window with [windowId].
  Future<void> show(int windowId);

  /// Whether the current platform supports multi-window desktop APIs.
  bool get isSupported;
}
