// Channel contract (G6): the method-channel segmented recogniser bridge.
//
// The bridge is pure transport between `zip_core`'s `SegmentedRecognizerBridge`
// and the Android runner (G8). These tests pin the contract both ways: the
// channel names, method names and argument keys and types the runner must
// see, and the event-map decoding the runner must be able to send. An
// unknown type or a malformed map is dropped and logged by type name only —
// never with any recognised text (SECURITY-03).
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_captions/src/services/method_channel_segmented_recognizer_bridge.dart';
import 'package:zip_core/zip_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel(
    MethodChannelSegmentedRecognizerBridge.methodChannelName,
  );
  const eventChannel = EventChannel(
    MethodChannelSegmentedRecognizerBridge.eventChannelName,
  );

  final calls = <MethodCall>[];
  Exception? methodError;
  MockStreamHandlerEventSink? eventSink;

  setUp(() {
    calls.clear();
    methodError = null;
    eventSink = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          calls.add(call);
          if (methodError != null) throw methodError!;
          if (call.method == 'supportedLocales') {
            return <String>['en-US', 'fr-CA', 'cmn-CN'];
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          eventChannel,
          MockStreamHandler.inline(
            onListen: (arguments, sink) => eventSink = sink,
          ),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(methodChannel, null)
      ..setMockStreamHandler(eventChannel, null);
  });

  /// Listens to [bridge] and lets the mock stream handler record the sink.
  Future<List<SegmentedRecognizerEvent>> listen(
    MethodChannelSegmentedRecognizerBridge bridge,
  ) async {
    final received = <SegmentedRecognizerEvent>[];
    bridge.events.listen(received.add);
    await pumpEventQueue();
    return received;
  }

  group('channel names', () {
    test('the method and event channels are the agreed pair', () {
      expect(
        MethodChannelSegmentedRecognizerBridge.methodChannelName,
        'app.zipcaptions/segmented_speech',
      );
      expect(
        MethodChannelSegmentedRecognizerBridge.eventChannelName,
        'app.zipcaptions/segmented_speech/events',
      );
    });
  });

  group('method calls', () {
    test('start carries localeId as String and minimumLengthMs as int',
        () async {
      final bridge = MethodChannelSegmentedRecognizerBridge();

      expect(
        await bridge.start(localeId: 'en-CA', minimumLengthMs: 3600000),
        isTrue,
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'start');
      final args = calls.single.arguments! as Map<Object?, Object?>;
      expect(args.keys.toSet(), {'localeId', 'minimumLengthMs'});
      expect(args['localeId'], 'en-CA');
      expect(args['localeId'], isA<String>());
      expect(
        args['minimumLengthMs'],
        3600000,
        reason: 'the Android service ignores a Long: the value must be an '
            'Int (Amendment 03 section 1)',
      );
      expect(args['minimumLengthMs'], isA<int>());
    });

    test('stop, cancel, recreate and dispose use the pinned method names',
        () async {
      final bridge = MethodChannelSegmentedRecognizerBridge();

      await bridge.stop();
      await bridge.cancel();
      await bridge.recreate();
      await bridge.dispose();

      expect(
        calls.map((call) => call.method),
        ['stop', 'cancel', 'recreate', 'dispose'],
      );
    });

    test('supportedLocales is part of the SegmentedRecognizerBridge contract',
        () async {
      final SegmentedRecognizerBridge bridge =
          MethodChannelSegmentedRecognizerBridge();

      expect(await bridge.supportedLocales(), ['en-US', 'fr-CA', 'cmn-CN']);
      expect(calls.single.method, 'supportedLocales');
      expect(calls.single.arguments, isNull);
    });

    test('supportedLocales replies with the runner list as List<String>',
        () async {
      final bridge = MethodChannelSegmentedRecognizerBridge();

      final locales = await bridge.supportedLocales();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'supportedLocales');
      expect(locales, ['en-US', 'fr-CA', 'cmn-CN']);
      expect(locales, isA<List<String>>());
    });
  });

  group('start answers', () {
    test('a successful native call answers true', () async {
      final bridge = MethodChannelSegmentedRecognizerBridge();

      expect(
        await bridge.start(localeId: 'en-US', minimumLengthMs: 1000),
        isTrue,
      );
    });

    test('a PlatformException from the runner answers false', () async {
      final bridge = MethodChannelSegmentedRecognizerBridge();
      methodError = PlatformException(code: 'recogniser_busy');

      expect(
        await bridge.start(localeId: 'en-US', minimumLengthMs: 1000),
        isFalse,
        reason: 'a refusal is a start the engine must retry or report',
      );
    });

    test('any other error from the runner propagates to the engine',
        () async {
      final bridge = MethodChannelSegmentedRecognizerBridge();
      methodError = MissingPluginException('no runner handler');

      await expectLater(
        bridge.start(localeId: 'en-US', minimumLengthMs: 1000),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });

  group('other methods propagate exceptions', () {
    test('stop, cancel, recreate and dispose let a PlatformException '
        'through: the engine owns fail-closed', () async {
      final bridge = MethodChannelSegmentedRecognizerBridge();
      methodError = PlatformException(code: 'service_dead');

      await expectLater(bridge.stop(), throwsA(isA<PlatformException>()));
      await expectLater(bridge.cancel(), throwsA(isA<PlatformException>()));
      await expectLater(bridge.recreate(), throwsA(isA<PlatformException>()));
      await expectLater(bridge.dispose(), throwsA(isA<PlatformException>()));
    });

    test('supportedLocales lets a PlatformException through', () async {
      final bridge = MethodChannelSegmentedRecognizerBridge();
      methodError = PlatformException(code: 'cannot_check_support');

      await expectLater(
        bridge.supportedLocales(),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('event decoding', () {
    test('each event map decodes to its sealed event', () async {
      final bridge = MethodChannelSegmentedRecognizerBridge();
      final received = await listen(bridge);
      final sink = eventSink!;

      <Map<String, Object?>>[
        {'type': 'ready'},
        {'type': 'partial', 'text': 'hello'},
        {'type': 'segment', 'text': ' hello there'},
        {'type': 'endOfSession'},
        {'type': 'error', 'code': 6},
      ].forEach(sink.success);
      await pumpEventQueue();

      expect(received, hasLength(5));
      expect(received[0], isA<SegmentedReady>());
      expect((received[1] as SegmentedPartial).text, 'hello');
      expect((received[2] as SegmentedSegment).text, ' hello there');
      expect(received[3], isA<SegmentedEndOfSession>());
      expect((received[4] as SegmentedError).code, 6);
    });

    test('an unknown type is dropped and logged by type name only',
        () async {
      final bridge = MethodChannelSegmentedRecognizerBridge();
      final received = await listen(bridge);
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      final previous = Logger.root.level;
      Logger.root.level = Level.ALL;
      addTearDown(() => Logger.root.level = previous);

      // An unknown type never reaches the stream, and its log line may
      // carry the type name only — never a text or code value.
      eventSink!.success(
        <String, Object?>{'type': 'bogus_type', 'text': 'secret phrase'},
      );
      await pumpEventQueue();

      expect(received, isEmpty);
      expect(records, hasLength(1));
      expect(records.single.message, contains('bogus_type'));
      expect(
        records.single.message,
        isNot(contains('secret')),
        reason: 'SECURITY-03: nothing but the type name is logged',
      );
      expect(records.single.error, isNull);
    });

    test('a malformed map is dropped and logged by type name only', () async {
      final bridge = MethodChannelSegmentedRecognizerBridge();
      final received = await listen(bridge);
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      final previous = Logger.root.level;
      Logger.root.level = Level.ALL;
      addTearDown(() => Logger.root.level = previous);

      final sink = eventSink!;
      // No type at all, then not a map at all, then a partial without text,
      // an error without a code, and a partial whose text is not a String.
      <Object>[
        <String, Object?>{'text': 'secret words'},
        'secret words',
        <String, Object?>{'type': 'partial'},
        <String, Object?>{'type': 'error'},
        <String, Object?>{'type': 'partial', 'text': 7},
      ].forEach(sink.success);
      await pumpEventQueue();

      expect(received, isEmpty);
      expect(records, hasLength(5));
      for (final record in records) {
        expect(
          record.message,
          isNot(contains('secret')),
          reason: 'SECURITY-03: malformed input is never logged with its '
              'content',
        );
      }
      // The type name is allowed in the line where there is one.
      expect(records[2].message, contains('partial'));
      expect(records[3].message, contains('error'));
    });
  });
}
