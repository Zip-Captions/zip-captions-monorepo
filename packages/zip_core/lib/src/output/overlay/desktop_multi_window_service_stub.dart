import 'dart:ui';

import 'package:zip_core/src/output/overlay/desktop_window_service.dart';
import 'package:zip_core/src/output/overlay/display_enumerator.dart';

/// Web/mobile stub for [DesktopWindowService].
///
/// [isSupported] always returns false. All window methods are unreachable in
/// practice because callers guard on [isSupported] before calling them.
class DesktopMultiWindowService implements DesktopWindowService {
  /// Creates the stub.
  ///
  /// Production callers construct it with the shared display enumerator,
  /// exactly as with the io implementation, so the conditional export stays a
  /// drop-in. The enumerator is unused here: every method throws.
  DesktopMultiWindowService.withEnumerator(this.enumerator);

  /// The display enumerator the io implementation reads; unused on web.
  final DisplayEnumerator enumerator;

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
