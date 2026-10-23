// Tests for Unit 8.1 (S-21): the method-handler router that multiplexes the
// engine's single static handler slot between both controllers (NFR-R §10.4
// layer 1; BR-U8.1-04; FD BLM §4.1).
//
// N-01. The install slot is a recorder, so no plugin object is constructed.
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/output/overlay/overlay_method_router.dart';
import 'package:zip_core/src/output/overlay/overlay_window_controller.dart'
    show OverlayMethodHandler;

/// Records what the router installs into the engine's one static slot.
class _RecordingSlot {
  /// Every install call in order: `install` or `uninstall`.
  final List<String> calls = <String>[];

  OverlayMethodHandler? current;

  /// The installer the router is given.
  void install(OverlayMethodHandler? handler) {
    current = handler;
    calls.add(handler == null ? 'uninstall' : 'install');
  }

  /// Drives the installed dispatch function as the plugin would.
  Future<void> deliver(String method, int fromWindowId) async {
    await current!(method, fromWindowId);
  }
}

OverlayMethodHandler _recorder(List<String> log, String name) =>
    (method, fromWindowId) async => log.add('$name:$method:$fromWindowId');

void main() {
  late _RecordingSlot slot;
  late OverlayMethodRouter router;

  setUp(() {
    slot = _RecordingSlot();
    router = OverlayMethodRouter(installSlot: slot.install);
  });

  test('each id reaches its own handler', () async {
    final seen = <String>[];
    var aWindow = <int?>[7];
    var bWindow = <int?>[9];
    router
      ..register(() => aWindow.single, _recorder(seen, 'a'))
      ..register(() => bWindow.single, _recorder(seen, 'b'));

    await slot.deliver('captionUpdate', 7);
    expect(seen, ['a:captionUpdate:7']);

    await slot.deliver('captionUpdate', 9);
    expect(seen, ['a:captionUpdate:7', 'b:captionUpdate:9']);

    aWindow = [];
    bWindow = [];
  });

  test('unregistering one leaves the other', () async {
    final seen = <String>[];
    final aToken = router.register(() => 7, _recorder(seen, 'a'));
    router
      ..register(() => 9, _recorder(seen, 'b'))
      ..unregister(aToken);
    await slot.deliver('overlayReady', 7);
    await slot.deliver('overlayReady', 9);

    expect(seen, ['b:overlayReady:9']);
  });

  test('the first register installs and the last unregister clears', () {
    final a = router.register(() => 7, _recorder([], 'a'));
    final b = router.register(() => 9, _recorder([], 'b'));
    expect(slot.calls, ['install']);

    router.unregister(a);
    expect(slot.calls, ['install']);

    router.unregister(b);
    expect(slot.calls, ['install', 'uninstall']);
    expect(slot.current, isNull);
  });

  test('a duplicate unregister is a no-op', () {
    final a = router.register(() => 7, _recorder([], 'a'));
    router
      ..unregister(a)
      ..unregister(a);

    expect(slot.calls, ['install', 'uninstall']);
  });

  test('a null windowIdOf never matches', () async {
    final seen = <String>[];
    router.register(() => null, _recorder(seen, 'a'));

    await slot.deliver('overlayReady', 7);
    await slot.deliver('overlayReady', 0);

    expect(seen, isEmpty);
  });

  test('an id that matches no handler is dropped', () async {
    final seen = <String>[];
    router.register(() => 7, _recorder(seen, 'a'));

    await slot.deliver('captionUpdate', 11);

    expect(seen, isEmpty);
  });

  test('installerFor maps null to its own token only', () async {
    final seen = <String>[];
    final a = router.register(() => 7, _recorder(seen, 'a'));
    final installer = router.installerFor(a);
    router.register(() => 9, _recorder(seen, 'b'));

    // The controller's dispose() calls the installer with null.
    installer(null);
    await slot.deliver('captionUpdate', 7);
    await slot.deliver('captionUpdate', 9);

    expect(seen, ['b:captionUpdate:9']);
    expect(slot.calls, ['install']);
  });

  test('installerFor replaces only its own handler', () async {
    final seen = <String>[];
    final a = router.register(() => 7, _recorder(seen, 'old'));
    final installer = router.installerFor(a);
    router.register(() => 9, _recorder(seen, 'b'));

    installer(_recorder(seen, 'new'));
    await slot.deliver('captionUpdate', 7);

    expect(seen, ['new:captionUpdate:7']);
  });

  test('dispose clears the slot unconditionally', () {
    router
      ..register(() => 7, _recorder([], 'a'))
      ..dispose();

    expect(slot.calls, ['install', 'uninstall']);
    expect(slot.current, isNull);
  });
}
