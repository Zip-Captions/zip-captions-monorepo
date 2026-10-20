// Tests for Unit 8 (S-20): the external display window controller's state
// machine (T1-T17), close paths, handshake, coalescer and frame handling.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_broadcast/src/models/overlay_config.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_broadcast/src/output/overlay/desktop_window_service.dart';
import 'package:zip_broadcast/src/output/overlay/display_info.dart';
import 'package:zip_broadcast/src/output/overlay/external_display_status.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_activity.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_event.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_window_controller.dart';
import 'package:zip_core/zip_core.dart' hide Failed;

import '../../helpers/fake_display_enumerator.dart';

DisplayInfo _display(String id, {bool isPrimary = false, double left = 0}) =>
    DisplayInfo(
      id: id,
      label: 'Display $id',
      bounds: Rect.fromLTWH(left, 0, 1920, 1080),
      scaleFactor: 1,
      isPrimary: isPrimary,
    );

/// Records every window call in order and can be made to fail.
class _FakeWindowService implements DesktopWindowService {
  _FakeWindowService({this.isSupportedValue = true});

  final bool isSupportedValue;
  final List<String> calls = <String>[];
  final List<Rect> frames = <Rect>[];
  final List<String> invocations = <String>[];
  int nextWindowId = 7;

  /// When set, [createWindow] throws it.
  Exception? createWindowError;

  /// When set, [invokeMethod], [setFrame] and [show] throw it.
  Exception? callError;

  bool closed = false;

  @override
  bool get isSupported => isSupportedValue;

  @override
  Future<int> createWindow(String arguments) async {
    calls.add('createWindow');
    final error = createWindowError;
    if (error != null) throw error;
    return nextWindowId;
  }

  @override
  Future<void> closeWindow(int windowId) async {
    calls.add('closeWindow');
    closed = true;
  }

  @override
  Future<void> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) async {
    calls.add('invokeMethod:$method');
    invocations.add(arguments as String);
    final error = callError;
    if (error != null) throw error;
  }

  @override
  Future<void> setFrame(int windowId, Rect frame) async {
    calls.add('setFrame');
    frames.add(frame);
    final error = callError;
    if (error != null) throw error;
  }

  @override
  Future<void> show(int windowId) async {
    calls.add('show');
    final error = callError;
    if (error != null) throw error;
  }
}

/// Records the installed handler so a test can call it directly.
class _HandlerInstaller {
  OverlayMethodHandler? handler;

  void install(OverlayMethodHandler? next) {
    handler = next;
    installs.add(next != null ? 'installed' : 'uninstalled');
  }

  final List<String> installs = <String>[];
}

CaptionOverlaySnapshot _snapshot({
  OverlayActivity activity = OverlayActivity.live,
  String text = 'hello',
}) =>
    CaptionOverlaySnapshot(
      activity: activity,
      entries: [
        CaptionDisplayEntry(
          entryId: 'e1',
          sessionId: 's',
          text: text,
          isFinal: true,
          sourceId: 'default',
          timestamp: DateTime.utc(2026),
        ),
      ],
      settings: DisplaySettings.defaults(),
    );

/// A controller wired to fakes, with the pieces a test usually needs.
class _Harness {
  _Harness({bool supported = true, bool withInstaller = true})
      : windowService = _FakeWindowService(isSupportedValue: supported) {
    installer = _HandlerInstaller();
    controller = OverlayWindowController(
      windowService: windowService,
      enumerator: enumerator,
      handlerInstaller: withInstaller ? installer.install : null,
      log: Logger('test.overlay'),
    );
  }

  final _FakeWindowService windowService;
  late final _HandlerInstaller installer;
  final FakeDisplayEnumerator enumerator = FakeDisplayEnumerator(
    initial: [_display('primary', isPrimary: true), _display('second', left: 1920)],
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

  group('bootstrap (T1-T4)', () {
    test('an unsupported platform is Unsupported and never opens', () {
      fakeAsync((fake) {
        final harness = _Harness(supported: false);
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Unsupported>());

        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Unsupported>());
        expect(harness.windowService.calls, isEmpty);
      });
    });

    test('a supported platform starts Off when displays exist', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Off>());
      });
    });

    test('no displays at bootstrap is NoDisplays', () {
      fakeAsync((fake) {
        final harness = _Harness();
        harness.enumerator.emit(const []);
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<NoDisplays>());
      });
    });

    test('a display arriving moves NoDisplays back to Off (T4)', () {
      fakeAsync((fake) {
        final harness = _Harness();
        harness.enumerator.emit(const []);
        fake.flushMicrotasks();
        expect(harness.controller.status, isA<NoDisplays>());

        harness.enumerator.emit([_display('primary', isPrimary: true)]);
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Off>());
      });
    });
  });

  group('open (T5-T8)', () {
    test('a toggle on creates, frames and shows the window on ready', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Opening>());
        expect(harness.windowService.calls, ['createWindow']);

        fake.elapse(const Duration(milliseconds: 20));
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Open>());
        expect(
          harness.windowService.calls,
          ['createWindow', 'setFrame', 'show'],
        );
        expect(harness.windowService.frames.single, const Rect.fromLTWH(0, 0, 1920, 1080));
      });
    });

    test('a createWindow throw fails the open and reports OpenFailed', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        final events = harness.collectEvents();
        harness.windowService.createWindowError = Exception('boom');

        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();

        final status = harness.controller.status;
        expect(status, isA<Failed>());
        expect((status as Failed).reason, 'create_failed');
        expect(events.single, isA<OpenFailed>());
        expect((events.single as OpenFailed).reason, 'create_failed');
      });
    });

    test('the ready timeout fails the open and closes the window', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        final events = harness.collectEvents();

        unawaited(harness.controller.open(const OverlayConfig()));
        fake
          ..flushMicrotasks()
          ..elapse(overlayReadyTimeout);

        final controller = harness.controller;
        final status = controller.status;
        expect((status as Failed).reason, 'ready_timeout');
        expect(harness.windowService.closed, isTrue);
        expect(events.single, isA<OpenFailed>());
      });
    });

    test('a ready arriving after the timeout is inert', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        unawaited(harness.controller.open(const OverlayConfig()));
        fake
          ..flushMicrotasks()
          ..elapse(overlayReadyTimeout);

        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();

        final controller = harness.controller;
        expect(controller.status, isA<Failed>());
        expect(harness.windowService.calls, isNot(contains('show')));
      });
    });

    test('a missing handler installer fails the open before createWindow', () {
      fakeAsync((fake) {
        final harness = _Harness(withInstaller: false);
        fake.flushMicrotasks();

        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Failed>());
        expect(harness.windowService.calls, isEmpty);
      });
    });

    test('a second open while opening is a no-op', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();

        expect(
          harness.windowService.calls.where((c) => c == 'createWindow').length,
          1,
        );
      });
    });

    test('a failed open retries on the next toggle (T16)', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        harness.windowService.createWindowError = Exception('boom');

        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        expect(harness.controller.status, isA<Failed>());

        harness.windowService.createWindowError = null;
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Opening>());
      });
    });
  });

  group('the held snapshot and the coalescer (P1)', () {
    test('the held snapshot is sent immediately on ready (T7)', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        harness.controller.push(_snapshot(text: 'before'));
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();

        expect(harness.windowService.invocations, hasLength(1));
        final decoded = decodeSnapshot(harness.windowService.invocations.single);
        expect(decoded!.entries.single.text, 'before');
      });
    });

    test('nothing is sent before ready', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        harness.controller.push(_snapshot());
        unawaited(harness.controller.open(const OverlayConfig()));
        fake
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 100));

        final invocations = harness.windowService.invocations;
        expect(invocations, isEmpty);
      });
    });

    test('many pushes inside one interval send exactly one update', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();
        harness.windowService.invocations.clear();

        for (var i = 0; i < 50; i++) {
          harness.controller.push(_snapshot(text: 'line $i'));
        }
        fake.elapse(const Duration(milliseconds: 17));

        expect(harness.windowService.invocations, hasLength(1));
        final decoded = decodeSnapshot(harness.windowService.invocations.single);
        expect(decoded!.entries.single.text, 'line 49');
      });
    });

    test('a push after the interval sends again', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();
        harness.windowService.invocations.clear();

        harness.controller.push(_snapshot());
        fake.elapse(const Duration(milliseconds: 17));
        harness.controller.push(_snapshot());
        fake.elapse(const Duration(milliseconds: 17));

        expect(harness.windowService.invocations, hasLength(2));
      });
    });
  });

  group('display loss keeps a name and a selection (D-4)', () {
    test('a display lost with no persisted id still names the display and '
        'emits DisplayLost', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        final events = harness.collectEvents();
        harness.enumerator.emit([
          _display('primary', isPrimary: true),
          _display('second', left: 1920),
        ]);
        fake.flushMicrotasks();

        // No persisted id: the controller opens on the primary and records it.
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();
        expect(harness.controller.selectDisplay, 'primary');

        harness.enumerator.emit([_display('second', left: 1920)]);
        fake.flushMicrotasks();

        final waiting =
            harness.controller.status as WaitingForDisplay;
        expect(waiting.displayId, 'primary');
        // The disconnected display is gone from the list, so its name comes
        // from the capture.
        expect(waiting.label, 'Display primary');
        expect(events.whereType<DisplayLost>(), hasLength(1));
      });
    });
  });

  group('close paths (T13, T14, T10)', () {
    test('toggle off closes the window and returns to Off', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();

        unawaited(harness.controller.close(reason: CloseReason.toggleOff));
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Off>());
        expect(harness.windowService.closed, isTrue);
        expect(harness.controller.isWindowOpen, isFalse);
      });
    });

    test('close(openFailed) releases the window and reports OpenFailed', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        final events = harness.collectEvents();
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();

        unawaited(harness.controller.close(reason: CloseReason.openFailed));
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Failed>());
        expect(harness.windowService.closed, isTrue);
        expect(events.whereType<OpenFailed>(), hasLength(1));
        expect(events.whereType<OpenFailed>().single.reason, 'create_failed');
      });
    });

    test('a -1 from a window call emits WindowClosed (T14)', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        final events = harness.collectEvents();
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();

        harness.windowService.callError =
            PlatformException(code: '-1', message: 'gone');
        harness.controller.push(_snapshot());
        fake.elapse(const Duration(milliseconds: 17));

        expect(events.single, isA<WindowClosed>());
        expect(harness.controller.status, isA<Off>());
      });
    });

    test('another PlatformException is logged and ignored (B-5)', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        final events = harness.collectEvents();
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();

        harness.windowService.callError =
            PlatformException(code: 'other', message: 'hiccup');
        harness.controller.push(_snapshot());
        fake.elapse(const Duration(milliseconds: 17));

        expect(events, isEmpty);
        expect(harness.controller.status, isA<Open>());
      });
    });

    test('a pre-ready -1 is ignored, leaving the timeout to resolve', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();

        // setFrame cannot run before ready; the coalescer is inert too.
        harness.controller.push(_snapshot());
        fake.elapse(const Duration(milliseconds: 17));

        expect(harness.controller.status, isA<Opening>());
        fake.elapse(overlayReadyTimeout);
        expect(harness.controller.status, isA<Failed>());
      });
    });

    test('the selected display vanishing closes and waits (T10)', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        final events = harness.collectEvents();

        unawaited(
          harness.controller.open(
            const OverlayConfig(),
            persistedDisplayId: 'second',
          ),
        );
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();
        expect(harness.controller.status, isA<Open>());

        harness.enumerator.emit([_display('primary', isPrimary: true)]);
        fake.flushMicrotasks();

        final status = harness.controller.status;
        expect(status, isA<WaitingForDisplay>());
        expect((status as WaitingForDisplay).displayId, 'second');
        expect(events.single, isA<DisplayLost>());
        expect(harness.windowService.closed, isTrue);
      });
    });

    test('the saved display returning reopens the window (T11)', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        unawaited(
          harness.controller.open(
            const OverlayConfig(),
            persistedDisplayId: 'second',
          ),
        );
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();

        harness.enumerator.emit([_display('primary', isPrimary: true)]);
        fake.flushMicrotasks();
        expect(harness.controller.status, isA<WaitingForDisplay>());

        harness.windowService.calls.clear();
        harness.enumerator.emit([
          _display('primary', isPrimary: true),
          _display('second', left: 1920),
        ]);
        fake.flushMicrotasks();

        expect(harness.windowService.calls, contains('createWindow'));
        expect(harness.controller.status, isA<Opening>());
      });
    });

    test('cancel from waiting keeps the saved id (T12)', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        unawaited(
          harness.controller.open(
            const OverlayConfig(),
            persistedDisplayId: 'second',
          ),
        );
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();
        harness.enumerator.emit([_display('primary', isPrimary: true)]);
        fake.flushMicrotasks();

        unawaited(harness.controller.close(reason: CloseReason.cancel));
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Off>());
        expect(harness.controller.selectDisplay, 'second');
      });
    });
  });

  group('rearrangement (T15)', () {
    test('a same-id display with new bounds re-frames without re-handshake',
        () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();
        harness.windowService.calls.clear();

        harness.enumerator.emit([
          _display('primary', isPrimary: true, left: 100),
          _display('second', left: 1920),
        ]);
        fake.flushMicrotasks();

        expect(harness.windowService.calls, ['setFrame']);
        expect(
          harness.windowService.frames.last,
          const Rect.fromLTWH(100, 0, 1920, 1080),
        );
        expect(harness.controller.status, isA<Open>());
      });
    });

    test('reframe applies the current work area', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();
        harness.windowService.frames.clear();

        unawaited(harness.controller.reframe());
        fake.flushMicrotasks();

        expect(
          harness.windowService.frames.single,
          const Rect.fromLTWH(0, 0, 1920, 1080),
        );
      });
    });
  });

  group('recognition activity (T9, D-5)', () {
    test('a push changes the activity without crossing the Open boundary', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();

        harness.controller.push(_snapshot(activity: OverlayActivity.paused));
        fake.elapse(const Duration(milliseconds: 17));

        final status = harness.controller.status;
        expect(status, isA<Open>());
        expect((status as Open).activity, OverlayActivity.paused);
        expect(harness.windowService.calls, isNot(contains('closeWindow')));
      });
    });
  });

  group('PBT-04 idempotence', () {
    test('closing twice from Off is harmless', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        unawaited(harness.controller.close(reason: CloseReason.toggleOff));
        unawaited(harness.controller.close(reason: CloseReason.toggleOff));
        fake.flushMicrotasks();

        expect(harness.controller.status, isA<Off>());
        expect(harness.windowService.calls, isEmpty);
      });
    });
  });

  group('dispose', () {
    test('closes the window, uninstalls the handler and disposes the '
        'enumerator', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();
        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();

        unawaited(harness.controller.dispose());
        fake.flushMicrotasks();

        expect(harness.windowService.closed, isTrue);
        expect(harness.installer.handler, isNull);
        expect(harness.enumerator.isDisposed, isTrue);
      });
    });

    test('dispose is idempotent', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        unawaited(harness.controller.dispose());
        unawaited(harness.controller.dispose());
        fake.flushMicrotasks();

        expect(harness.enumerator.isDisposed, isTrue);
      });
    });
  });

  group('resolveOpenDisplay inside open', () {
    test('an absent saved id enters WaitingForDisplay without opening', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        unawaited(
          harness.controller.open(
            const OverlayConfig(),
            persistedDisplayId: 'gone',
          ),
        );
        fake.flushMicrotasks();

        final status = harness.controller.status;
        expect(status, isA<WaitingForDisplay>());
        expect((status as WaitingForDisplay).displayId, 'gone');
        expect(harness.windowService.calls, isEmpty);
      });
    });

    test('no saved id opens on the primary', () {
      fakeAsync((fake) {
        final harness = _Harness();
        fake.flushMicrotasks();

        unawaited(harness.controller.open(const OverlayConfig()));
        fake.flushMicrotasks();
        unawaited(harness.installer.handler!('overlayReady', 7));
        fake.flushMicrotasks();

        final status = harness.controller.status;
        expect((status as Open).displayId, 'primary');
      });
    });
  });
}
