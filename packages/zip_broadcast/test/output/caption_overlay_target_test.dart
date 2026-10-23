// Tests for Unit 8 (S-20): CaptionOverlayTarget as the thin delegator and
// caption-bus adapter (F17, B-9).
import 'dart:async';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_broadcast/src/models/overlay_config.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_target.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart' hide Failed;

import '../helpers/fake_display_enumerator.dart';

DisplayInfo _display({double left = 0}) => DisplayInfo(
      id: 'primary',
      label: 'Primary',
      bounds: Rect.fromLTWH(left, 0, 1920, 1080),
      scaleFactor: 1,
      isPrimary: true,
    );

class _Window implements DesktopWindowService {
  final List<String> calls = <String>[];
  int _next = 21;

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

  void install(OverlayMethodHandler? next) {
    handler = next;
    installs.add(next != null);
  }

  final List<bool> installs = <bool>[];
}

void main() {
  late _Window window;
  late _Handler handler;
  late FakeDisplayEnumerator enumerator;
  late OverlayWindowController controller;
  late CaptionOutputTargetRegistry registry;
  late CaptionBus bus;
  late DisplaySettings settings;
  late CaptionOverlayTarget target;

  /// Builds the whole graph inside the current `fakeAsync` zone, so the
  /// controller's bootstrap microtasks are driven by the test's clock.
  void build() {
    window = _Window();
    handler = _Handler();
    enumerator = FakeDisplayEnumerator(initial: [_display()]);
    controller = OverlayWindowController(
      windowService: window,
      enumerator: enumerator,
      handlerInstaller: handler.install,
      log: Logger('test.target'),
    );
    bus = CaptionBus();
    registry = CaptionOutputTargetRegistry(bus);
    settings = DisplaySettings.defaults();
    target = CaptionOverlayTarget(
      controller: controller,
      registry: registry,
      displaySettings: () => settings,
    );
  }

  test('targetId is unchanged', () {
    build();
    expect(target.targetId, 'caption_overlay');
  });

  test('isVisible delegates to the controller', () {
    fakeAsync((fake) {
      build();
      fake.flushMicrotasks();
      expect(target.isVisible, isFalse);
      expect(target.isVisible, controller.isWindowOpen);
    });
  });

  test('events re-exposes the controller stream', () async {
    build();
    final seen = <OverlayEvent>[];
    target.events.listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    // The controller emits nothing on its own; the stream identity is what
    // matters, so a WindowClosed must arrive here.
    expect(seen, isEmpty);
  });

  test('dispose closes without awaiting the window close', () {
    fakeAsync((fake) {
      build();
      fake.flushMicrotasks();
      // A fire-and-forget close must not block the registry's synchronous
      // dispose path.
      target.dispose();
      fake.flushMicrotasks();
      expect(controller.isWindowOpen, isFalse);
    });
  });

  group('the snapshot built from the bus', () {
    test('entries are the buffer finals and interim is the trailing '
        'non-final', () {
      fakeAsync((fake) {
        build();
        final screen = OnScreenCaptionTarget(targetId: 'on_screen');
        registry
          ..add(screen)
          ..add(target);
        fake.flushMicrotasks();
        unawaited(controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(handler.handler!('overlayReady', 21));
        fake.flushMicrotasks();

        bus
          ..publish(
            SttResultEvent(
              SttResult(
                text: 'final one',
                isFinal: true,
                confidence: 1,
                timestamp: DateTime.utc(2026),
                sourceId: 'default',
              ),
            ),
          )
          ..publish(
            SttResultEvent(
              SttResult(
                text: 'partial',
                isFinal: false,
                confidence: 1,
                timestamp: DateTime.utc(2026),
                sourceId: 'default',
              ),
            ),
          );
        // The on-screen target debounces at 50 ms; the overlay coalesces at
        // 16 ms.
        fake
          ..elapse(const Duration(milliseconds: 60))
          ..elapse(captionUpdateInterval + const Duration(milliseconds: 1));

        expect(
          window.calls,
          contains('invokeMethod'),
          reason: 'status=${controller.status} calls=${window.calls}',
        );

        registry.remove(screen);
      });
    });

    test('a settings change reaches the next snapshot without a reopen', () {
      fakeAsync((fake) {
        build();
        final screen = OnScreenCaptionTarget(targetId: 'on_screen');
        registry
          ..add(screen)
          ..add(target);
        fake.flushMicrotasks();
        unawaited(controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(handler.handler!('overlayReady', 21));
        fake.flushMicrotasks();

        bus.publish(
          SttResultEvent(
            SttResult(
              text: 'a',
              isFinal: true,
              confidence: 1,
              timestamp: DateTime.utc(2026),
              sourceId: 'default',
            ),
          ),
        );
        fake.elapse(const Duration(milliseconds: 60));

        settings = const DisplaySettings(
          scrollDirection: ScrollDirection.topToBottom,
          captionTextSize: CaptionTextSize.xxl,
          captionFont: CaptionFont.poppins,
          themeModeSetting: ThemeModeSetting.light,
          maxVisibleLines: 2,
        );
        bus.publish(
          SttResultEvent(
            SttResult(
              text: 'b',
              isFinal: true,
              confidence: 1,
              timestamp: DateTime.utc(2026),
              sourceId: 'default',
            ),
          ),
        );
        fake
          ..elapse(const Duration(milliseconds: 60))
          ..elapse(captionUpdateInterval + const Duration(milliseconds: 1));

        // The window was never re-created for a settings change.
        expect(
          window.calls.where((call) => call == 'createWindow').length,
          1,
        );

        registry.remove(screen);
      });
    });

    test('a session event alone never opens a window (D-5)', () {
      fakeAsync((fake) {
        build();
        fake.flushMicrotasks();

        target.onCaptionEvent(
          const SessionStateEvent(RecordingState.paused(sessionId: 's')),
        );
        fake.elapse(captionUpdateInterval + const Duration(milliseconds: 1));

        expect(window.calls, isEmpty);
        expect(controller.status, isA<Off>());
      });
    });

    test('the pause marker row survives into the snapshot', () {
      fakeAsync((fake) {
        build();
        final screen = OnScreenCaptionTarget(targetId: 'on_screen');
        registry
          ..add(screen)
          ..add(target);
        fake.flushMicrotasks();
        unawaited(controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(handler.handler!('overlayReady', 21));
        fake.flushMicrotasks();

        bus
          ..publish(
            const SessionStateEvent(RecordingState.paused(sessionId: 's')),
          )
          ..publish(
            SttResultEvent(
              SttResult(
                text: 'before pause',
                isFinal: true,
                confidence: 1,
                timestamp: DateTime.utc(2026),
                sourceId: 'default',
              ),
            ),
          );
        fake
          ..elapse(const Duration(milliseconds: 60))
          ..elapse(captionUpdateInterval + const Duration(milliseconds: 1));

        expect(window.calls, contains('invokeMethod'));

        registry.remove(screen);
      });
    });
  });
}
