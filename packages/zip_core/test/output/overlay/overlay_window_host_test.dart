// Tests for Unit 8.1 (S-21): the host that owns the engine-wide resources
// (NFR Design §2). One router, one enumerator, one close channel, however many
// controllers.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/src/output/overlay/overlay_method_router.dart';
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

void main() {
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
    final host = OverlayWindowHost(
      enumerator: enumerator,
      closeChannel: channel,
      router: OverlayMethodRouter(),
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
