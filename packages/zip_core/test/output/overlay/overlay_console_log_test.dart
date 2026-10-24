// Tests for Unit 8.1 (S-21), fix round 6 finding R6-5: the overlay host's
// fixed log strings reach the console in a debug build and nowhere new in a
// release build.
//
// Both apps forward `Logger.root` to `dart:developer`'s `log`, which DevTools
// shows and `flutter run` does not, so the controller's `overlay ready timeout`
// never reached the terminal during the round-6 runtime review.
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/src/models/overlay_config.dart';
import 'package:zip_core/src/output/overlay/desktop_window_service.dart';
import 'package:zip_core/src/output/overlay/overlay_console_log.dart';
import 'package:zip_core/src/output/overlay/overlay_method_router.dart';
import 'package:zip_core/src/output/overlay/overlay_window_host.dart';
import 'package:zip_core/src/output/overlay/overlay_window_mode.dart';
import 'package:zip_core/src/output/overlay/sub_window_closed_channel.dart';
import 'package:zip_core/src/providers/overlay_window_host_provider.dart';

import '../../helpers/fake_display_enumerator.dart';

class _FakeCloseChannel implements SubWindowClosedChannel {
  final StreamController<int> _controller = StreamController<int>.broadcast();

  @override
  void install() {}

  @override
  Stream<int> get closed => _controller.stream;

  @override
  void dispose() => unawaited(_controller.close());
}

/// A window service whose `createWindow` fails, so the controller writes its
/// fixed `createWindow failed` line.
class _FailingWindow implements DesktopWindowService {
  @override
  bool get isSupported => true;

  @override
  Future<int> createWindow(String arguments) async =>
      throw StateError('no window: secret payload');

  @override
  Future<void> closeWindow(int windowId) async {}

  @override
  Future<void> invokeMethod(int windowId, String method, dynamic arguments) =>
      Future<void>.value();

  @override
  Future<void> setFrame(int windowId, Rect frame) async {}

  @override
  Future<void> show(int windowId) async {}
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String?> printed;

  setUp(() {
    printed = <String?>[];
  });

  void printer(String? message, {int? wrapWidth}) => printed.add(message);

  group('routeOverlayLogToConsole', () {
    test('prints the logger subtree in a debug build', () async {
      final log = Logger('zip_core.ConsoleTestHost');
      // Tests run in debug, so `enabled` takes its `kDebugMode` default.
      final subscription = routeOverlayLogToConsole(log, printer: printer);
      addTearDown(() => subscription?.cancel());

      Logger('zip_core.ConsoleTestHost.Child')
          .warning('overlay ready timeout', StateError('secret payload'));
      Logger('zip_core.Unrelated').warning('not overlay');
      await _settle();

      expect(subscription, isNotNull);
      expect(printed, hasLength(1));
      expect(printed.single, contains('overlay ready timeout'));
      expect(printed.single, contains('WARNING'));
      expect(printed.single, contains('zip_core.ConsoleTestHost.Child'));
      // The record's error is never printed: fixed strings only (BR-U8-18).
      expect(printed.single, isNot(contains('secret payload')));
    });

    test('wires nothing in a release build', () async {
      final log = Logger('zip_core.ConsoleTestHostRelease');
      final subscription = routeOverlayLogToConsole(
        log,
        enabled: false,
        printer: printer,
      );

      log.warning('overlay ready timeout');
      await _settle();

      expect(subscription, isNull);
      expect(printed, isEmpty);
    });
  });

  test('a host-built controller logs inside the host logger subtree', () async {
    final log = Logger('zip_core.ConsoleTestHostTree');
    final names = <String>[];
    final subscription = Logger.root.onRecord
        .where((record) => record.loggerName.startsWith('${log.fullName}.'))
        .listen((record) => names.add(record.loggerName));
    addTearDown(subscription.cancel);

    final host = OverlayWindowHost(
      enumerator: FakeDisplayEnumerator(),
      closeChannel: _FakeCloseChannel(),
      router: OverlayMethodRouter(installSlot: (_) {}),
      windowService: (_) => _FailingWindow(),
      log: log,
    );
    addTearDown(host.dispose);
    final controller = host.createController(
      mode: const PopOutMode(),
      prefix: 'zip_captions.PopOutWindowController',
    );
    addTearDown(controller.dispose);

    await controller.open(const OverlayConfig(mode: PopOutMode()));
    await _settle();

    expect(
      names,
      contains('${log.fullName}.zip_captions.PopOutWindowController'),
    );
  });

  test('the host provider routes the controller strings to debugPrint',
      () async {
    final original = debugPrint;
    debugPrint = printer;
    addTearDown(() => debugPrint = original);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(overlayWindowHostProvider);

    Logger('zip_core.OverlayWindowHost.zip_captions.PopOutWindowController')
        .warning('overlay ready timeout');
    await _settle();

    expect(printed, contains(contains('overlay ready timeout')));
  });
}
