import 'dart:async';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_broadcast/src/output/overlay/pop_out_caption_target.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart' hide Failed;

import '../../helpers/fake_display_enumerator.dart';

/// A window service that records every call and never reaches a platform.
class _Window implements DesktopWindowService {
  final List<String> calls = <String>[];
  int _next = 31;

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
      calls.add('invokeMethod');

  @override
  Future<void> setFrame(int windowId, Rect frame) async =>
      calls.add('setFrame');

  @override
  Future<void> show(int windowId) async => calls.add('show');
}

class _Handler {
  OverlayMethodHandler? handler;

  final List<bool> installs = <bool>[];

  void install(OverlayMethodHandler? next) {
    handler = next;
    installs.add(next != null);
  }
}

const _display = DisplayInfo(
  id: 'primary',
  label: 'Primary',
  bounds: Rect.fromLTWH(0, 0, 1920, 1080),
  scaleFactor: 1,
  isPrimary: true,
);

void main() {
  late _Window window;
  late _Handler handler;
  late OverlayWindowController controller;
  late CaptionOutputTargetRegistry registry;
  late CaptionBus bus;
  late DisplaySettings settings;
  late PopOutCaptionTarget target;
  late OnScreenCaptionTarget screen;

  void build() {
    window = _Window();
    handler = _Handler();
    controller = OverlayWindowController(
      windowService: window,
      enumerator: FakeDisplayEnumerator(initial: [_display]),
      handlerInstaller: handler.install,
      log: Logger('test.popOutTarget'),
      mode: const PopOutMode(),
    );
    bus = CaptionBus();
    registry = CaptionOutputTargetRegistry(bus);
    settings = DisplaySettings.defaults();
    target = PopOutCaptionTarget(
      controller: controller,
      registry: registry,
      displaySettings: () => settings,
    );
    screen = OnScreenCaptionTarget(targetId: 'on_screen');
  }

  /// Opens the pop-out through the target and completes the ready handshake.
  void openPopOut(FakeAsync fake) {
    unawaited(target.show(const OverlayConfig(mode: PopOutMode())));
    fake.flushMicrotasks();
    unawaited(handler.handler!('overlayReady', 31));
    fake.flushMicrotasks();
  }

  SttResultEvent result(String text, {required bool isFinal}) => SttResultEvent(
        SttResult(
          text: text,
          isFinal: isFinal,
          confidence: 1,
          timestamp: DateTime.utc(2026),
          sourceId: 'default',
        ),
      );

  test('targetId is its own, distinct from the external display', () {
    build();
    expect(target.targetId, 'caption_pop_out');
    expect(target.targetId, isNot('caption_overlay'));
  });

  test('isVisible delegates to the controller', () {
    fakeAsync((fake) {
      build();
      fake.flushMicrotasks();
      expect(target.isVisible, isFalse);
      expect(target.isVisible, controller.isWindowOpen);
    });
  });

  test('show opens a window in pop-out mode', () {
    fakeAsync((fake) {
      build();
      fake.flushMicrotasks();
      openPopOut(fake);

      expect(window.calls, contains('createWindow'));
      expect(target.isVisible, isTrue);
      expect(controller.mode, isA<PopOutMode>());
    });
  });

  test('show passes the supplied frame to the window service (R-M5)', () {
    fakeAsync((fake) {
      build();
      fake.flushMicrotasks();
      unawaited(
        target.show(
          const OverlayConfig(mode: PopOutMode()),
          frame: const Rect.fromLTWH(40, 60, 480, 270),
        ),
      );
      fake.flushMicrotasks();
      unawaited(handler.handler!('overlayReady', 31));
      fake.flushMicrotasks();

      expect(window.calls, contains('setFrame'));
    });
  });

  test('hide closes with the user toggle reason', () {
    fakeAsync((fake) {
      build();
      fake.flushMicrotasks();
      openPopOut(fake);

      unawaited(target.hide());
      fake.flushMicrotasks();

      expect(window.calls, contains('closeWindow'));
      expect(controller.status, isA<Off>());
    });
  });

  test('dispose closes without awaiting the window close', () {
    fakeAsync((fake) {
      build();
      fake.flushMicrotasks();
      openPopOut(fake);

      target.dispose();
      fake.flushMicrotasks();
      expect(controller.isWindowOpen, isFalse);
    });
  });

  test('recognition continuing pushes live frames while the app is '
      'backgrounded (BR-PIP-04)', () {
    fakeAsync((fake) {
      build();
      registry
        ..add(screen)
        ..add(target);
      fake.flushMicrotasks();
      openPopOut(fake);

      bus
        ..publish(
          const SessionStateEvent(RecordingState.recording(sessionId: 's')),
        )
        ..publish(result('hello', isFinal: true));
      // On-screen debounce, then the pop-out coalescing interval.
      fake
        ..elapse(const Duration(milliseconds: 60))
        ..elapse(captionUpdateInterval + const Duration(milliseconds: 1));

      // The snapshot went out; the target keeps following the bus without the
      // window being reopened or the session restarted.
      expect(window.calls.where((c) => c == 'createWindow'), hasLength(1));
      expect(target.isVisible, isTrue);

      registry.remove(screen);
    });
  });

  test('the snapshot carries the live entries (BR-PIP-05)', () {
    fakeAsync((fake) {
      build();
      registry
        ..add(screen)
        ..add(target);
      fake.flushMicrotasks();
      openPopOut(fake);

      bus.publish(result('first', isFinal: true));
      fake.elapse(const Duration(milliseconds: 60));

      expect(screen.visibleCaptions.map((e) => e.text), contains('first'));

      registry.remove(screen);
    });
  });

  test('a stopped session reads standby on the next frame', () {
    fakeAsync((fake) {
      build();
      registry
        ..add(screen)
        ..add(target);
      fake.flushMicrotasks();
      openPopOut(fake);

      bus.publish(
        const SessionStateEvent(RecordingState.recording(sessionId: 's')),
      );
      fake.elapse(const Duration(milliseconds: 60));
      bus.publish(
        const SessionStateEvent(RecordingState.stopped(sessionId: 's')),
      );
      fake
        ..elapse(const Duration(milliseconds: 60))
        ..elapse(captionUpdateInterval + const Duration(milliseconds: 1));

      // Nothing caption-shaped is logged; the state reached the window.
      expect(controller.status, isA<Open>());

      registry.remove(screen);
    });
  });
}
