import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_captions/src/output/overlay/pop_out_caption_target.dart';
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

/// One frame's worth of microtask draining, without depending on `fake_async`
/// (this app adds no dev dependency for its tests).
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Window window;
  late _Handler handler;
  late OverlayWindowController controller;
  late CaptionOutputTargetRegistry registry;
  late CaptionBus bus;
  late DisplaySettings settings;
  late RecordingState recording;
  late PopOutCaptionTarget target;
  late OnScreenCaptionTarget screen;

  void build() {
    window = _Window();
    handler = _Handler();
    controller = OverlayWindowController(
      windowService: window,
      enumerator: FakeDisplayEnumerator(initial: [_display]),
      handlerInstaller: handler.install,
      log: Logger('test.zipCaptionsPopOutTarget'),
      mode: const PopOutMode(),
    );
    bus = CaptionBus();
    registry = CaptionOutputTargetRegistry(bus);
    settings = DisplaySettings.defaults();
    recording = const RecordingState.idle();
    target = PopOutCaptionTarget(
      controller: controller,
      registry: registry,
      displaySettings: () => settings,
      recordingState: () => recording,
    );
    screen = OnScreenCaptionTarget(targetId: 'on_screen');
  }

  /// Opens the pop-out through the target and completes the ready handshake.
  Future<void> openPopOut() async {
    unawaited(target.show(const OverlayConfig(mode: PopOutMode())));
    await _settle();
    await handler.handler!('overlayReady', 31);
    await _settle();
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

  test('isVisible delegates to the controller', () async {
    build();
    await _settle();
    expect(target.isVisible, isFalse);
    expect(target.isVisible, controller.isWindowOpen);
  });

  test('show opens a window in pop-out mode', () async {
    build();
    await _settle();
    await openPopOut();

    expect(window.calls, contains('createWindow'));
    expect(target.isVisible, isTrue);
    expect(controller.mode, isA<PopOutMode>());
  });

  test('show passes the supplied frame to the window service (R-M5)', () async {
    build();
    await _settle();
    unawaited(
      target.show(
        const OverlayConfig(mode: PopOutMode()),
        frame: const Rect.fromLTWH(40, 60, 480, 270),
      ),
    );
    await _settle();
    await handler.handler!('overlayReady', 31);
    await _settle();

    expect(window.calls, contains('setFrame'));
  });

  test('hide closes with the user toggle reason', () async {
    build();
    await _settle();
    await openPopOut();

    await target.hide();
    await _settle();

    expect(window.calls, contains('closeWindow'));
    expect(controller.status, isA<Off>());
  });

  test('dispose closes without awaiting the window close', () async {
    build();
    await _settle();
    await openPopOut();

    target.dispose();
    await _settle();
    expect(controller.isWindowOpen, isFalse);
  });

  test('recognition continuing pushes live frames while the app is '
      'backgrounded (BR-PIP-04)', () async {
    build();
    registry
      ..add(screen)
      ..add(target);
    await _settle();
    await openPopOut();

    bus
      ..publish(
        const SessionStateEvent(RecordingState.recording(sessionId: 's')),
      )
      ..publish(result('hello', isFinal: true));
    await _settle();
    await _settle();

    expect(window.calls.where((c) => c == 'createWindow'), hasLength(1));
    expect(target.isVisible, isTrue);

    registry.remove(screen);
  });

  test('the snapshot carries the live entries (BR-PIP-05)', () async {
    build();
    registry
      ..add(screen)
      ..add(target);
    await _settle();
    await openPopOut();

    bus.publish(result('first', isFinal: true));
    await _settle();
    await _settle();

    expect(screen.visibleCaptions.map((e) => e.text), contains('first'));

    registry.remove(screen);
  });

  test('a stopped session leaves the window open on standby', () async {
    build();
    registry
      ..add(screen)
      ..add(target);
    await _settle();
    await openPopOut();

    bus.publish(
      const SessionStateEvent(RecordingState.recording(sessionId: 's')),
    );
    await _settle();
    bus.publish(
      const SessionStateEvent(RecordingState.stopped(sessionId: 's')),
    );
    await _settle();
    await _settle();

    final status = controller.status;
    expect(status, isA<Open>());
    expect((status as Open).activity, OverlayActivity.standby);

    registry.remove(screen);
  });

  // Review round 5, finding 2: the shell registers the target only once a
  // session is already recording, so no `SessionStateEvent` ever reaches it.
  // Without seeding, every result pushed `standby` and the window showed the
  // blank standby surface.
  test('registered after the session started pushes live, not standby',
      () async {
    build();
    // The session is recording; the target is built now, after the
    // `SessionStateEvent` the bus already published.
    recording = const RecordingState.recording(sessionId: 's');
    registry
      ..add(screen)
      ..add(target);
    await _settle();
    await openPopOut();

    bus.publish(result('first', isFinal: true));
    await _settle();
    await _settle();

    final status = controller.status;
    expect(status, isA<Open>());
    expect((status as Open).activity, OverlayActivity.live);

    registry.remove(screen);
  });
}
