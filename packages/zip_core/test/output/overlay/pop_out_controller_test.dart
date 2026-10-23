// Tests for Unit 8.1 (S-21): the seven permitted controller deviations
// (FD BLM §2/§3.2/§3.3/§3.4/§4.1). N-10.
//
// One group per deviation, so a failure names which permission was exceeded.
// The controller is wired to the same fakes the moved Unit 8 suite uses, with
// the close channel and the injected frame as the two additions.
import 'dart:async';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/src/models/overlay_config.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_core/src/output/overlay/desktop_window_service.dart';
import 'package:zip_core/src/output/overlay/display_info.dart';
import 'package:zip_core/src/output/overlay/external_display_status.dart';
import 'package:zip_core/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/src/output/overlay/overlay_event.dart';
import 'package:zip_core/src/output/overlay/overlay_window_controller.dart';
import 'package:zip_core/src/output/overlay/overlay_window_mode.dart';
import 'package:zip_core/src/output/overlay/sub_window_closed_channel.dart';
import 'package:zip_core/zip_core.dart' hide Failed;

import '../../helpers/fake_display_enumerator.dart';

DisplayInfo _display(String id, {bool isPrimary = false}) => DisplayInfo(
  id: id,
  label: 'Display $id',
  bounds: const Rect.fromLTWH(0, 0, 1920, 1080),
  scaleFactor: 1,
  isPrimary: isPrimary,
);

class _FakeWindowService implements DesktopWindowService {
  final List<String> calls = <String>[];
  final List<Rect> frames = <Rect>[];
  int nextWindowId = 7;

  @override
  bool get isSupported => true;

  @override
  Future<int> createWindow(String arguments) async {
    calls.add('createWindow');
    return nextWindowId;
  }

  @override
  Future<void> closeWindow(int windowId) async => calls.add('closeWindow');

  @override
  Future<void> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) async => calls.add('invokeMethod:$method');

  @override
  Future<void> setFrame(int windowId, Rect frame) async {
    calls.add('setFrame');
    frames.add(frame);
  }

  @override
  Future<void> show(int windowId) async => calls.add('show');
}

/// A close channel a test can push ids into.
class _FakeCloseChannel implements SubWindowClosedChannel {
  final StreamController<int> controller = StreamController<int>.broadcast();
  bool installed = false;
  bool disposed = false;

  @override
  void install() => installed = true;

  @override
  Stream<int> get closed => controller.stream;

  @override
  void dispose() {
    disposed = true;
    unawaited(controller.close());
  }
}

class _HandlerInstaller {
  OverlayMethodHandler? handler;
  final List<String> installs = <String>[];

  void install(OverlayMethodHandler? next) {
    handler = next;
    installs.add(next != null ? 'installed' : 'uninstalled');
  }

  void call(String method, int fromWindowId) => handler!(method, fromWindowId);
}

CaptionOverlaySnapshot _snapshot() => CaptionOverlaySnapshot(
  activity: OverlayActivity.live,
  entries: const [],
  settings: DisplaySettings.defaults(),
);

class _Harness {
  _Harness({
    bool modeIsPopOut = true,
    bool withInstaller = true,
  }) {
    installer = _HandlerInstaller();
    controller = OverlayWindowController(
      windowService: windowService,
      enumerator: enumerator,
      handlerInstaller: withInstaller ? installer.install : null,
      log: Logger('test.popOut'),
      mode: modeIsPopOut ? const PopOutMode() : const ExternalDisplayMode(),
      closeChannel: closeChannel,
    );
  }

  final _FakeWindowService windowService = _FakeWindowService();
  final _FakeCloseChannel closeChannel = _FakeCloseChannel();
  late final _HandlerInstaller installer;
  final FakeDisplayEnumerator enumerator = FakeDisplayEnumerator(
    initial: const <DisplayInfo>[],
  );
  late final OverlayWindowController controller;

  List<ExternalDisplayStatus> collectStatuses() {
    final statuses = <ExternalDisplayStatus>[];
    unawaited(controller.statusChanges.listen(statuses.add).asFuture<void>());
    return statuses;
  }

  List<OverlayEvent> collectEvents() {
    final events = <OverlayEvent>[];
    unawaited(controller.events.listen(events.add).asFuture<void>());
    return events;
  }
}

void main() {
  setUpAll(() {
    Logger.root.level = Level.OFF;
  });

  group('deviation 1: a pop-out never follows a display', () {
    test('a display event while open keeps the window and the frame', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        unawaited(
          harness.controller.open(
            const OverlayConfig(mode: PopOutMode()),
            frame: const Rect.fromLTWH(10, 10, 400, 200),
          ),
        );
        fake.flushMicrotasks();
        harness.installer.call('overlayReady', 7);
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Open>());
        final framesBefore = harness.windowService.frames.length;

        harness.enumerator.emit([_display('other')]);
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Open>());
        expect(harness.windowService.frames.length, framesBefore);
      });
    });

    test('an empty display list while open does not close the window', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        unawaited(
          harness.controller.open(
            const OverlayConfig(mode: PopOutMode()),
            frame: const Rect.fromLTWH(0, 0, 400, 200),
          ),
        );
        fake.flushMicrotasks();
        harness.installer.call('overlayReady', 7);
        fake.flushMicrotasks();

        harness.enumerator.emit(const []);
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Open>());
        expect(harness.windowService.calls, isNot(contains('closeWindow')));
      });
    });

    test('an empty display list while opening does not fail the open', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        unawaited(
          harness.controller.open(
            const OverlayConfig(mode: PopOutMode()),
            frame: const Rect.fromLTWH(0, 0, 400, 200),
          ),
        );
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Opening>());

        harness.enumerator.emit(const []);
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Opening>());
      });
    });

    test('bootstrap needs no display at all', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Off>());
        expect(harness.controller.status, isNot(isA<NoDisplays>()));
      });
    });

    test('open and ready never report NoDisplays', () {
      fakeAsync((fake) {
        final harness = _Harness();
        final statuses = harness.collectStatuses();
        fake.flushMicrotasks();

        unawaited(
          harness.controller.open(
            const OverlayConfig(mode: PopOutMode()),
            frame: const Rect.fromLTWH(0, 0, 400, 200),
          ),
        );
        fake.flushMicrotasks();
        harness.installer.call('overlayReady', 7);
        fake.flushMicrotasks();

        expect(statuses.whereType<NoDisplays>(), isEmpty);
        expect(harness.controller.status, isA<Open>());
      });
    });
  });

  group('deviation 3: the frame comes from the caller', () {
    test('ready applies the supplied frame', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        const frame = Rect.fromLTWH(100, 200, 480, 240);
        unawaited(
          harness.controller.open(
            const OverlayConfig(mode: PopOutMode()),
            frame: frame,
          ),
        );
        fake.flushMicrotasks();
        harness.installer.call('overlayReady', 7);
        fake.flushMicrotasks();

        expect(harness.windowService.frames, [frame]);
      });
    });

    test('a null frame logs once at FINE, skips setFrame, stays Open', () {
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      Logger.root.level = Level.ALL;

      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        unawaited(
          harness.controller.open(const OverlayConfig(mode: PopOutMode())),
        );
        fake.flushMicrotasks();
        harness.installer.call('overlayReady', 7);
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Open>());
        expect(harness.windowService.calls, isNot(contains('setFrame')));
        final fine = records.where((r) => r.level == Level.FINE).toList();
        expect(fine, hasLength(1));
        expect(fine.single.message, contains('frame'));
      });

      Logger.root.level = Level.OFF;
    });
  });

  group('deviation 4: the mode is fixed at construction', () {
    test('open with the other mode config fails as create_failed', () {
      fakeAsync((fake) {
        final harness = _Harness();
        final events = harness.collectEvents();
        fake.flushMicrotasks();

        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Failed>());
        expect(harness.windowService.calls, isEmpty);
        expect(events.whereType<OpenFailed>(), hasLength(1));
      });
    });

    test('the mode is readable and is the one supplied', () {
      final harness = _Harness();
      expect(harness.controller.mode, isA<PopOutMode>());
      expect(harness.controller.windowId, isNull);
    });
  });

  group('deviation 6 and 7: the native close channel', () {
    test('a matching id ends the window as WindowClosed + Off', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        unawaited(
          harness.controller.open(
            const OverlayConfig(mode: PopOutMode()),
            frame: const Rect.fromLTWH(0, 0, 400, 200),
          ),
        );
        fake.flushMicrotasks();
        harness.installer.call('overlayReady', 7);
        fake.flushMicrotasks();

        final events = harness.collectEvents();
        final statuses = harness.collectStatuses();
        harness.closeChannel.controller.add(7);
        // The stream is asynchronous, so the fields are drained before the
        // close's own microtasks run.
        fake
          ..flushMicrotasks()
          ..elapse(Duration.zero)
          ..flushMicrotasks();

        expect(harness.controller.status, isA<Off>());
        expect(events.whereType<WindowClosed>(), hasLength(1));
        expect(statuses.last, isA<Off>());
        expect(harness.windowService.calls, contains('closeWindow'));
      });
    });

    test('an unknown id is dropped', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        unawaited(
          harness.controller.open(
            const OverlayConfig(mode: PopOutMode()),
            frame: const Rect.fromLTWH(0, 0, 400, 200),
          ),
        );
        fake.flushMicrotasks();
        harness.installer.call('overlayReady', 7);
        fake.flushMicrotasks();

        harness.closeChannel.controller.add(99);
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Open>());
        expect(harness.windowService.calls, isNot(contains('closeWindow')));
      });
    });

    test('a late event after the window was taken is dropped', () {
      fakeAsync((fake) {
        final harness = _Harness();
        final events = harness.collectEvents();
        fake.flushMicrotasks();
        unawaited(
          harness.controller.open(
            const OverlayConfig(mode: PopOutMode()),
            frame: const Rect.fromLTWH(0, 0, 400, 200),
          ),
        );
        fake.flushMicrotasks();
        harness.installer.call('overlayReady', 7);
        fake.flushMicrotasks();

        unawaited(harness.controller.close(reason: CloseReason.toggleOff));
        fake.flushMicrotasks();
        expect(harness.controller.windowId, isNull);

        harness.closeChannel.controller.add(7);
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Off>());
        // A toggle-off close emits no WindowClosed (Unit 8's rule), and the
        // late native event for the released id adds none either.
        expect(events.whereType<WindowClosed>(), isEmpty);
      });
    });

    test('the channel is subscribed at bootstrap and cancelled on dispose', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        expect(harness.closeChannel.controller.hasListener, isTrue);

        unawaited(harness.controller.dispose());
        fake.flushMicrotasks();

        expect(harness.closeChannel.controller.hasListener, isFalse);
      });
    });
  });

  group('deviation 2: the in-surface toggle', () {
    test("'popOutToggle' emits PopOutToggled", () {
      fakeAsync((fake) {
        final harness = _Harness();
        final events = harness.collectEvents();
        fake.flushMicrotasks();
        unawaited(
          harness.controller.open(
            const OverlayConfig(mode: PopOutMode()),
            frame: const Rect.fromLTWH(0, 0, 400, 200),
          ),
        );
        fake.flushMicrotasks();
        harness.installer.call('overlayReady', 7);
        fake.flushMicrotasks();

        harness.installer.call('popOutToggle', 7);
        fake.flushMicrotasks();

        expect(events.whereType<PopOutToggled>(), hasLength(1));
        // The controller only reports; the window stays open for the shell.
        expect(harness.controller.status, isA<Open>());
      });
    });
  });

  group('deviation 5: the token-bound installer', () {
    test('dispose uninstalls its own handler', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        expect(harness.installer.installs, ['installed']);

        unawaited(harness.controller.dispose());
        fake.flushMicrotasks();

        expect(harness.installer.installs, ['installed', 'uninstalled']);
      });
    });
  });

  group('the launch payload', () {
    test('a pop-out encodes and decodes as a pop-out', () {
      final launch = OverlayWindowLaunch(
        config: const OverlayConfig(mode: PopOutMode()),
        snapshot: _snapshot(),
      );

      final decoded = decodeLaunch(encodeLaunch(launch));

      expect(decoded!.config.mode, isA<PopOutMode>());
      expect(decoded.snapshot.contentMode, PopOutContentMode.originalOnly);
    });

    test('the snapshot encoder carries the content mode', () {
      final encoded = encodeSnapshot(
        CaptionOverlaySnapshot(
          activity: OverlayActivity.live,
          entries: const [],
          settings: DisplaySettings.defaults(),
          contentMode: PopOutContentMode.originalAndTranslated,
        ),
      );

      expect(
        decodeSnapshot(encoded)!.contentMode,
        PopOutContentMode.originalAndTranslated,
      );
    });

    test('_snapshot helper builds a valid frame', () {
      expect(_snapshot().activity, OverlayActivity.live);
    });
  });
}
