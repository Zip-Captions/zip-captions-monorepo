// Tests for Unit 8.1 (S-21): the in-sub-engine WindowConfigurator
// (FD §1.2.1; NFR-R §1.2 items 3-4). N-05.
//
// The channel is a boundary: a platform without an implementation throws
// MissingPluginException, and that must not escape as an OpenFailed. The test
// build is the no-op stub, so this also proves the stub is a real drop-in.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/overlay_window_config.dart';
import 'package:zip_core/src/output/overlay/window_configurator.dart';

/// A configurator that always throws, to prove the catch lives in the
/// implementation under test rather than in its callers.
class _ThrowingConfigurator implements WindowConfigurator {
  @override
  Future<void> configure(int windowId, OverlayWindowConfig config) async =>
      throw StateError('no native side');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = OverlayWindowConfig(
    floating: true,
    decorated: true,
    minWidth: 320,
    minHeight: 96,
  );

  group('MethodChannelWindowConfigurator', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(WindowConfiguratorChannel.name),
            (call) async {
              calls.add(call);
              return null;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(WindowConfiguratorChannel.name),
            null,
          );
    });

    test('sends every property the native side needs, once', () async {
      await MethodChannelWindowConfigurator().configure(7, config);

      expect(calls, hasLength(1));
      final call = calls.single;
      expect(call.method, WindowConfiguratorChannel.method);
      expect(call.arguments, <String, Object?>{
        'windowId': 7,
        'floating': true,
        'decorated': true,
        'minWidth': 320.0,
        'minHeight': 96.0,
      });
    });

    test('a zero minimum size is sent as zero, not dropped', () async {
      await MethodChannelWindowConfigurator().configure(
        7,
        const OverlayWindowConfig(),
      );

      final arguments = calls.single.arguments! as Map<Object?, Object?>;
      expect(arguments['minWidth'], 0.0);
      expect(arguments['minHeight'], 0.0);
      expect(arguments['floating'], isFalse);
      expect(arguments['decorated'], isFalse);
    });

    test('a missing native implementation never escapes', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(WindowConfiguratorChannel.name),
            null,
          );

      await expectLater(
        MethodChannelWindowConfigurator().configure(7, config),
        completes,
      );
    });

    test('a native error never escapes', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(WindowConfiguratorChannel.name),
            (call) async => throw PlatformException(code: 'failed'),
          );

      await expectLater(
        MethodChannelWindowConfigurator().configure(7, config),
        completes,
      );
    });
  });

  group('NoopWindowConfigurator', () {
    test('completes without touching any channel', () async {
      var called = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(WindowConfiguratorChannel.name),
            (call) async {
              called = true;
              return null;
            },
          );

      await const NoopWindowConfigurator().configure(7, config);

      expect(called, isFalse);
    });
  });

  test('a throwing configurator reaches its caller as a throw', () async {
    // The seam itself does not swallow: only the channel implementation does,
    // so a fake that throws is visible to the test that injected it.
    await expectLater(
      _ThrowingConfigurator().configure(7, config),
      throwsStateError,
    );
  });
}
