// Tests for Unit 8.1 (S-21): the main-engine sub-window close channel
// (NFR-D §5.2; NFR Design logical-components §5.2). N-04.
//
// The native side is a boundary and is treated as untrusted input: a wrong
// method, a non-map argument, a non-int id or a negative id is dropped with
// nothing emitted and nothing logged.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/output/overlay/sub_window_closed_channel.dart';

/// Drives the channel's handler exactly as Flutter's binary messenger would.
Future<void> _call(
  MethodChannelSubWindowClosedChannel channel,
  String method, [
  Object? arguments,
]) async {
  const codec = StandardMethodCodec();
  final data = codec.encodeMethodCall(MethodCall(method, arguments));
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    SubWindowClosedChannel.channelName,
    data,
    (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubWindowClosedChannel', () {
    late MethodChannelSubWindowClosedChannel channel;

    setUp(() {
      channel = MethodChannelSubWindowClosedChannel()..install();
    });

    tearDown(() => channel.dispose());

    test('a valid subWindowClosed emits one id', () async {
      final seen = <int>[];
      final subscription = channel.closed.listen(seen.add);

      await _call(channel, 'subWindowClosed', {'windowId': 7});
      await Future<void>.delayed(Duration.zero);

      expect(seen, [7]);
      await subscription.cancel();
    });

    test('ids arrive in arrival order', () async {
      final seen = <int>[];
      final subscription = channel.closed.listen(seen.add);

      await _call(channel, 'subWindowClosed', {'windowId': 7});
      await _call(channel, 'subWindowClosed', {'windowId': 9});
      await _call(channel, 'subWindowClosed', {'windowId': 0});
      await Future<void>.delayed(Duration.zero);

      expect(seen, [7, 9, 0]);
      await subscription.cancel();
    });

    test('a wrong method is dropped', () async {
      final seen = <int>[];
      final subscription = channel.closed.listen(seen.add);

      await _call(channel, 'windowClosed', {'windowId': 7});
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
      await subscription.cancel();
    });

    test('a non-map argument is dropped', () async {
      final seen = <int>[];
      final subscription = channel.closed.listen(seen.add);

      await _call(channel, 'subWindowClosed', 'windowId: 7');
      await _call(channel, 'subWindowClosed', 7);
      await _call(channel, 'subWindowClosed');
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
      await subscription.cancel();
    });

    test('a non-int window id is dropped', () async {
      final seen = <int>[];
      final subscription = channel.closed.listen(seen.add);

      await _call(channel, 'subWindowClosed', {'windowId': '7'});
      await _call(channel, 'subWindowClosed', {'windowId': 7.0});
      await _call(channel, 'subWindowClosed', {'windowId': null});
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
      await subscription.cancel();
    });

    test('a negative window id is dropped', () async {
      final seen = <int>[];
      final subscription = channel.closed.listen(seen.add);

      await _call(channel, 'subWindowClosed', {'windowId': -1});
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
      await subscription.cancel();
    });

    test('dispose closes the stream and is idempotent', () async {
      var done = false;
      channel.closed.listen(null, onDone: () => done = true);
      await Future<void>.delayed(Duration.zero);

      channel
        ..dispose()
        ..dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });
  });

  group('NoopSubWindowClosedChannel', () {
    test('never emits anything', () async {
      final stub = const NoopSubWindowClosedChannel()..install();

      expect(await stub.closed.isEmpty, isTrue);

      stub.dispose();
    });
  });
}
