import 'dart:ui';

import 'package:logging/logging.dart';
import 'package:zip_core/overlay.dart';

/// A pop-out controller over a recording window service and an empty display
/// list: no platform channel, no display observer, no window.
OverlayWindowController fakePopOutController({int windowId = 41}) =>
    OverlayWindowController(
      windowService: _RecordingWindowService(windowId: windowId),
      enumerator: EmptyDisplayEnumerator(),
      handlerInstaller: (_) {},
      log: Logger('test.fakePopOutController'),
      mode: const PopOutMode(),
    );

/// A pop-out controller on an unsupported platform: its synchronous status is
/// `Unsupported`, so nothing is visible before the status stream emits.
OverlayWindowController fakeUnsupportedPopOutController() =>
    OverlayWindowController(
      windowService: _UnsupportedWindowService(),
      enumerator: EmptyDisplayEnumerator(),
      handlerInstaller: (_) {},
      log: Logger('test.fakeUnsupportedPopOutController'),
      mode: const PopOutMode(),
    );

/// A platform without multi-window support.
class _UnsupportedWindowService implements DesktopWindowService {
  @override
  bool get isSupported => false;

  @override
  Future<int> createWindow(String arguments) async =>
      throw UnsupportedError('no windows');

  @override
  Future<void> closeWindow(int id) async {}

  @override
  Future<void> invokeMethod(int id, String method, dynamic arguments) async {}

  @override
  Future<void> setFrame(int id, Rect frame) async {}

  @override
  Future<void> show(int id) async {}
}

/// An enumerator that reports no displays and never emits.
class EmptyDisplayEnumerator implements DisplayEnumerator {
  @override
  Future<List<DisplayInfo>> displays() async => const <DisplayInfo>[];

  @override
  Stream<List<DisplayInfo>> get changes =>
      const Stream<List<DisplayInfo>>.empty();

  @override
  Future<Size?> primarySize() async => null;

  @override
  Future<void> dispose() async {}
}

class _RecordingWindowService implements DesktopWindowService {
  _RecordingWindowService({required this.windowId});

  final int windowId;

  /// Every call, in order, for tests that assert on the window lifecycle.
  final List<String> calls = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<int> createWindow(String arguments) async {
    calls.add('createWindow');
    return windowId;
  }

  @override
  Future<void> closeWindow(int id) async => calls.add('closeWindow');

  @override
  Future<void> invokeMethod(int id, String method, dynamic arguments) async =>
      calls.add('invokeMethod:$method');

  @override
  Future<void> setFrame(int id, Rect frame) async => calls.add('setFrame');

  @override
  Future<void> show(int id) async => calls.add('show');
}
