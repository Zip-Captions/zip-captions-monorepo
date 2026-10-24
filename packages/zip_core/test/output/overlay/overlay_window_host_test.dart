// Tests for Unit 8.1 (S-21): the host that owns the engine-wide resources
// (NFR Design §2). One router, one enumerator, one close channel, however many
// controllers.
//
// Review round 5 finding 1: a host-built controller must reach the router's
// dispatch function, or nothing on the main engine ever hears the sub-window's
// `overlayReady` and every open ends in `ready_timeout`.
import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/src/models/overlay_config.dart';
import 'package:zip_core/src/output/overlay/desktop_window_service.dart';
import 'package:zip_core/src/output/overlay/display_info.dart';
import 'package:zip_core/src/output/overlay/external_display_status.dart';
import 'package:zip_core/src/output/overlay/overlay_method_router.dart';
import 'package:zip_core/src/output/overlay/overlay_window_controller.dart'
    show OverlayMethodHandler;
import 'package:zip_core/src/output/overlay/overlay_window_host.dart';
import 'package:zip_core/src/output/overlay/overlay_window_mode.dart';
import 'package:zip_core/src/output/overlay/sub_window_closed_channel.dart';

import '../../helpers/fake_display_enumerator.dart';

class _FakeCloseChannel implements SubWindowClosedChannel {
  final StreamController<int> controller = StreamController<int>.broadcast();
  int installs = 0;
  bool disposed = false;

  @override
  void install() => installs++;

  @override
  Stream<int> get closed => controller.stream;

  @override
  void dispose() {
    disposed = true;
    unawaited(controller.close());
  }
}

const _display = DisplayInfo(
  id: 'primary',
  label: 'Primary',
  bounds: Rect.fromLTWH(0, 0, 1920, 1080),
  scaleFactor: 1,
  isPrimary: true,
);

/// Records what the router installs into the engine's one static slot.
class _RecordingSlot {
  /// The dispatcher the router last installed, or `null` when cleared.
  OverlayMethodHandler? current;

  /// Every install call in order.
  final List<bool> calls = <bool>[];

  void install(OverlayMethodHandler? handler) {
    current = handler;
    calls.add(handler != null);
  }

  /// Drives the installed dispatch function as the plugin would.
  Future<void> deliver(String method, int fromWindowId) async {
    await current!(method, fromWindowId);
  }
}

/// A window service that records and hands out increasing ids.
class _Window implements DesktopWindowService {
  _Window({int start = 7}) : _next = start;

  final List<String> calls = <String>[];
  int _next;

  @override
  bool get isSupported => true;

  @override
  Future<int> createWindow(String arguments) async {
    calls.add('createWindow');
    return _next++;
  }

  @override
  Future<void> closeWindow(int windowId) async => calls.add('closeWindow');

  @override
  Future<void> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) async =>
      calls.add('invokeMethod:$method');

  @override
  Future<void> setFrame(int windowId, Rect frame) async =>
      calls.add('setFrame');

  @override
  Future<void> show(int windowId) async => calls.add('show');
}

/// Drains the microtasks the open path queues.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  // The router's production slot is a method channel: the old
  // `createController` test only passed because nothing was registered, so
  // nothing touched the plugin. Every host test now needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Logger.root.level = Level.OFF;
  });

  test('initials the one of everything and exposes the display list', () {
    final enumerator = FakeDisplayEnumerator();
    final channel = _FakeCloseChannel();
    final host = OverlayWindowHost(
      enumerator: enumerator,
      closeChannel: channel,
      router: OverlayMethodRouter(),
    );
    addTearDown(host.dispose);

    expect(channel.installs, 1);
    expect(identical(host.displays, enumerator.changes), isFalse);
    expect(host.isDisposed, isFalse);
  });

  test('createController wires a lease, a token-bound installer and the '
      'channel', () {
    final enumerator = FakeDisplayEnumerator();
    final channel = _FakeCloseChannel();
    final slot = _RecordingSlot();
    final host = OverlayWindowHost(
      enumerator: enumerator,
      closeChannel: channel,
      router: OverlayMethodRouter(installSlot: slot.install),
    );
    addTearDown(host.dispose);

    final controller = host.createController(
      mode: const PopOutMode(),
      prefix: 'zip_broadcast.PopOutWindowController',
    );
    addTearDown(controller.dispose);

    expect(controller.mode, isA<PopOutMode>());
    // The lease is the controller's enumerator, not the shared instance.
    expect(identical(controller.enumerator, enumerator), isFalse);
    expect(channel.controller.hasListener, isTrue);
  });

  // Review round 5, finding 1: the host handed the controller a token that it
  // had never registered, so the router never wrote its dispatcher into the
  // slot and no sub-window message was heard.
  test('a host-built controller reaches Open over a delivered overlayReady',
      () async {
    final slot = _RecordingSlot();
    final window = _Window();
    final host = OverlayWindowHost(
      enumerator: FakeDisplayEnumerator(initial: const [_display]),
      closeChannel: _FakeCloseChannel(),
      router: OverlayMethodRouter(installSlot: slot.install),
      windowService: (_) => window,
    );
    addTearDown(host.dispose);

    final controller = host.createController(
      mode: const PopOutMode(),
      prefix: 'zip_captions.PopOutWindowController',
    );
    addTearDown(controller.dispose);

    // Registering with the router is what installs the dispatcher.
    expect(slot.current, isNotNull, reason: 'the router never installed');
    expect(slot.calls, [true]);

    unawaited(controller.open(const OverlayConfig(mode: PopOutMode())));
    await _settle();

    expect(controller.status, isA<Opening>());
    final id = controller.windowId!;
    await slot.deliver('overlayReady', id);
    await _settle();

    expect(controller.status, isA<Open>());
  });

  // Review round 5, finding 1: the external display and the pop-out share one
  // slot, so each must receive only its own window's messages.
  test('two host-built controllers each receive only their own message',
      () async {
    final slot = _RecordingSlot();
    final windows = <_Window>[
      _Window(),
      _Window(start: 11),
    ];
    final host = OverlayWindowHost(
      enumerator: FakeDisplayEnumerator(initial: const [_display]),
      closeChannel: _FakeCloseChannel(),
      router: OverlayMethodRouter(installSlot: slot.install),
      windowService: (lease) => windows.removeAt(0),
    );
    addTearDown(host.dispose);

    final external = host.createController(
      mode: const ExternalDisplayMode(),
      prefix: 'zip_broadcast.OverlayWindowController',
    );
    final popOut = host.createController(
      mode: const PopOutMode(),
      prefix: 'zip_broadcast.PopOutWindowController',
    );
    addTearDown(external.dispose);
    addTearDown(popOut.dispose);

    // One slot write for the engine, whatever the controller count.
    expect(slot.calls, [true]);

    // Both opens start in the same span; the controller's first display probe
    // lands after it, and an external display opening before the probe answers
    // has no display to resolve.
    await _settle();
    unawaited(
      external.open(
        const OverlayConfig(mode: ExternalDisplayMode(displayId: 'primary')),
      ),
    );
    await _settle();
    unawaited(popOut.open(const OverlayConfig(mode: PopOutMode())));
    await _settle();

    final externalId = external.windowId!;
    final popOutId = popOut.windowId!;
    expect(externalId, isNot(popOutId));

    await slot.deliver('overlayReady', popOutId);
    await _settle();

    expect(popOut.status, isA<Open>());
    expect(external.status, isA<Opening>());

    await slot.deliver('overlayReady', externalId);
    await _settle();

    expect(external.status, isA<Open>());
  });

  test('dispose releases the channel, the router and the enumerator', () async {
    final enumerator = FakeDisplayEnumerator();
    final channel = _FakeCloseChannel();
    final host = OverlayWindowHost(
      enumerator: enumerator,
      closeChannel: channel,
      router: OverlayMethodRouter(),
    );

    await host.dispose();

    expect(host.isDisposed, isTrue);
    expect(channel.disposed, isTrue);
    expect(enumerator.isDisposed, isTrue);
  });

  test('dispose is idempotent', () async {
    final host = OverlayWindowHost(
      enumerator: FakeDisplayEnumerator(),
      closeChannel: _FakeCloseChannel(),
      router: OverlayMethodRouter(),
    );

    await host.dispose();
    await host.dispose();

    expect(host.isDisposed, isTrue);
  });
}
