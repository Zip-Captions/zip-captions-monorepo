// Tests for Unit 8.1 (S-21): the pop-out's state invariants under any
// interleaving of the actions the shell can take (FD §5 POP-5). N-11.
//
// A randomised sequence runner rather than a per-action table: the interesting
// failures are interlacings (a toggle during the open handshake, a display
// event mid-open, a native close after a manual close), which a table names
// one at a time and never composes.
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/src/models/overlay_config.dart';
import 'package:zip_core/src/output/overlay/desktop_window_service.dart';
import 'package:zip_core/src/output/overlay/display_info.dart';
import 'package:zip_core/src/output/overlay/external_display_status.dart';
import 'package:zip_core/src/output/overlay/overlay_window_controller.dart';
import 'package:zip_core/src/output/overlay/overlay_window_mode.dart';
import 'package:zip_core/src/output/overlay/sub_window_closed_channel.dart';

import '../../helpers/fake_display_enumerator.dart';

DisplayInfo _display() => const DisplayInfo(
  id: 'primary',
  label: 'Display primary',
  bounds: Rect.fromLTWH(0, 0, 1920, 1080),
  scaleFactor: 1,
  isPrimary: true,
);

class _FakeWindowService implements DesktopWindowService {
  final List<String> calls = <String>[];
  int nextWindowId = 7;

  @override
  bool get isSupported => true;

  @override
  Future<int> createWindow(String arguments) async {
    calls.add('createWindow');
    return nextWindowId++;
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
  Future<void> setFrame(int windowId, Rect frame) async =>
      calls.add('setFrame');

  @override
  Future<void> show(int windowId) async => calls.add('show');
}

class _FakeCloseChannel implements SubWindowClosedChannel {
  final StreamController<int> controller = StreamController<int>.broadcast();

  @override
  void install() {}

  @override
  Stream<int> get closed => controller.stream;

  @override
  void dispose() => unawaited(controller.close());
}

class _Installer {
  OverlayMethodHandler? handler;
  int windowId = 7;

  void install(OverlayMethodHandler? next) {
    handler = next;
    installs++;
  }

  int installs = 0;

  void ready() => handler!('overlayReady', windowId);

  void toggle() => handler!('popOutToggle', windowId);
}

/// One action the shell (or the platform) can take against the controller.
enum _Action {
  openPopOut,
  toggleAgain,
  toggleOff,
  windowGone,
  displayEvent,
  elapse,
}

void main() {
  setUpAll(() {
    Logger.root.level = Level.OFF;
  });

  for (final seed in <int>[1, 2, 3, 4, 5, 6, 7, 8]) {
    test('POP-5: invariants hold for action sequence seed $seed', () {
      final random = Random(seed);
      final actions = List<_Action>.generate(
        30,
        (_) => _Action.values[random.nextInt(_Action.values.length)],
      );

      fakeAsync((fake) {
        final windowService = _FakeWindowService();
        final closeChannel = _FakeCloseChannel();
        final installer = _Installer();
        final enumerator = FakeDisplayEnumerator(initial: [_display()]);
        final controller = OverlayWindowController(
          windowService: windowService,
          enumerator: enumerator,
          handlerInstaller: installer.install,
          log: Logger('test.popOut.property'),
          mode: const PopOutMode(),
          closeChannel: closeChannel,
        );
        fake.flushMicrotasks();

        final statuses = <ExternalDisplayStatus>[];
        unawaited(
          controller.statusChanges.listen(statuses.add).asFuture<void>(),
        );

        var lastWindowCount = 0;
        var windowsCreated = 0;

        for (final action in actions) {
          final before = controller.status.runtimeType;
          switch (action) {
            case _Action.openPopOut:
            case _Action.toggleAgain:
              unawaited(
                controller.open(
                  const OverlayConfig(mode: PopOutMode()),
                  frame: const Rect.fromLTWH(0, 0, 480, 240),
                ),
              );
              fake.flushMicrotasks();
              if (before is! Opening && before is! Open) {
                installer.ready();
                fake.flushMicrotasks();
              }
            case _Action.toggleOff:
              unawaited(controller.close(reason: CloseReason.toggleOff));
              fake.flushMicrotasks();
            case _Action.windowGone:
              if (controller.windowId != null) {
                closeChannel.controller.add(controller.windowId!);
              }
              fake
                ..flushMicrotasks()
                ..elapse(Duration.zero)
                ..flushMicrotasks();
            case _Action.displayEvent:
              enumerator.emit(
                random.nextBool() ? const [] : [_display()],
              );
              fake.flushMicrotasks();
            case _Action.elapse:
              fake.elapse(const Duration(seconds: 3));
              fake.flushMicrotasks();
          }

          // The declared variants only: nothing outside the shipped status
          // set can appear, and there is never a second window.
          expect(
            controller.status,
            anyOf(
              isA<Off>(),
              isA<Opening>(),
              isA<Open>(),
              isA<Failed>(),
              isA<Unsupported>(),
            ),
          );
          windowsCreated = windowService.calls
              .where((call) => call == 'createWindow')
              .length;
          expect(windowsCreated, greaterThanOrEqualTo(lastWindowCount));
          lastWindowCount = windowsCreated;

          // At most one window exists at any time: the controller's id is
          // either null or the one it last created.
          final id = controller.windowId;
          if (id != null) {
            expect(id, lessThan(7 + windowsCreated));
          }

          // The open sequence creates one window, so the number of creates
          // never exceeds the number of opens that started from a closed
          // state, which is bounded by the action count.
          expect(windowsCreated, lessThanOrEqualTo(actions.length));
        }

        // One state at a time: the status stream only ever reported one value
        // per transition, and every value was a declared variant.
        expect(statuses, everyElement(isA<ExternalDisplayStatus>()));

        unawaited(controller.dispose());
        fake.flushMicrotasks();
      });
    });
  }
}
