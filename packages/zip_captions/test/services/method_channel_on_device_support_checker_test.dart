// Checker channel contract (P1, P10): the method-channel on-device support
// checker.
//
// The checker only *asks* the platform. It deliberately does not swallow
// errors: the engine owns the fail-closed guard (Step 7), and a checker that
// returned `false` on its own would hide a broken channel behind a misleading
// "not supported" message.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_captions/src/services/method_channel_on_device_support_checker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    MethodChannelOnDeviceSupportChecker.channelName,
  );

  final calls = <MethodCall>[];
  Exception? throwOnCall;

  setUp(() {
    calls.clear();
    throwOnCall = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (throwOnCall != null) throw throwOnCall!;
          return call.arguments == 'supported-locale';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('checker channel contract (P1, P10)', () {
    test('uses the agreed channel name, method and argument', () async {
      const checker = MethodChannelOnDeviceSupportChecker();

      await checker('en-US');

      expect(
        MethodChannelOnDeviceSupportChecker.channelName,
        'app.zipcaptions/speech_support',
      );
      expect(calls, hasLength(1));
      expect(calls.single.method, 'isOnDeviceSupported');
      expect(calls.single.arguments, 'en-US');
    });

    test('AC: returns the platform boolean', () async {
      const checker = MethodChannelOnDeviceSupportChecker();

      expect(await checker('supported-locale'), isTrue);
      expect(await checker('other'), isFalse);
    });

    test('AC: a platform exception is not swallowed here', () async {
      const checker = MethodChannelOnDeviceSupportChecker();
      throwOnCall = PlatformException(code: 'boom');

      await expectLater(
        checker('en-US'),
        throwsA(isA<PlatformException>()),
      );
    });

    test('AC: a missing plugin is not swallowed here either', () async {
      const checker = MethodChannelOnDeviceSupportChecker();
      throwOnCall = MissingPluginException('no runner handler');

      await expectLater(
        checker('en-US'),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('AC: a non-boolean reply fails closed as an error, not a false',
        () async {
      // A handler that answers null (the shape a stub channel returns) must
      // surface as an error, not silently become "unsupported": the engine
      // decides, and it logs the failure type.
      const checker = MethodChannelOnDeviceSupportChecker();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);

      await expectLater(checker('en-US'), throwsA(isA<TypeError>()));
    });
  });
}
