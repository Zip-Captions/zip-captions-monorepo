// Channel contract (H3, TP-30): the method-channel language-pack service.
//
// Pins both directions: the channel names, method names and argument keys and
// types the runners must see, and the status and event decoding the runners
// must be able to send. An unknown or malformed reply is `unknown`; an unknown
// or malformed event is dropped and logged by type name only (SECURITY-03).
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_captions/src/services/method_channel_language_pack_service.dart';
import 'package:zip_core/zip_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('app.zipcaptions/language_pack');
  const eventChannel = EventChannel('app.zipcaptions/language_pack/events');

  final calls = <MethodCall>[];
  Object? statusReply;
  Exception? statusError;
  Exception? downloadError;
  MockStreamHandlerEventSink? eventSink;

  setUp(() {
    calls.clear();
    statusReply = null;
    statusError = null;
    downloadError = null;
    eventSink = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          calls.add(call);
          if (call.method == 'status') {
            if (statusError != null) throw statusError!;
            return statusReply;
          }
          if (call.method == 'download') {
            if (downloadError != null) throw downloadError!;
            return null;
          }
          throw MissingPluginException();
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

  group('channel names', () {
    test('are the Amendment 04 pair', () {
      expect(
        MethodChannelLanguagePackService.methodChannelName,
        'app.zipcaptions/language_pack',
      );
      expect(
        MethodChannelLanguagePackService.eventChannelName,
        'app.zipcaptions/language_pack/events',
      );
    });
  });

  group('status', () {
    test('sends {localeId: String} on the method "status"', () async {
      statusReply = <String, Object?>{
        'status': 'installed',
        'displayName': 'English (United States)',
      };

      await MethodChannelLanguagePackService().status('en-US');

      expect(calls, hasLength(1));
      expect(calls.single.method, 'status');
      expect(calls.single.arguments, <String, Object?>{'localeId': 'en-US'});
    });

    for (final status in LanguagePackStatus.values) {
      test('maps "${status.name}" with its display name', () async {
        statusReply = <String, Object?>{
          'status': status.name,
          'displayName': 'Français (Canada)',
        };

        final info = await MethodChannelLanguagePackService().status('fr-CA');

        expect(info.status, status);
        expect(info.displayName, 'Français (Canada)');
      });
    }

    test('an unknown status string is unknown, with the locale as name',
        () async {
      statusReply = <String, Object?>{
        'status': 'bogus',
        'displayName': 'English',
      };

      final info = await MethodChannelLanguagePackService().status('en-US');

      expect(info.status, LanguagePackStatus.unknown);
      expect(info.displayName, 'en-US');
    });

    final malformed = <String, Object?>{
      'a null reply': null,
      'a string reply': 'installed',
      'a list reply': <Object?>['installed'],
      'a map without status': <String, Object?>{'displayName': 'English'},
      'a non-string status': <String, Object?>{
        'status': 3,
        'displayName': 'English',
      },
    };
    // The table reads better as a named declaration than as a cascade.
    // ignore: cascade_invocations
    malformed.forEach((name, reply) {
      test('$name is unknown, with the locale as name', () async {
        statusReply = reply;

        final info = await MethodChannelLanguagePackService().status('en-US');

        expect(info.status, LanguagePackStatus.unknown);
        expect(info.displayName, 'en-US');
      });
    });

    test('a valid status with a missing or empty name keeps the status',
        () async {
      statusReply = <String, Object?>{'status': 'downloadable'};
      var info = await MethodChannelLanguagePackService().status('de-DE');
      expect(info.status, LanguagePackStatus.downloadable);
      expect(info.displayName, 'de-DE');

      statusReply = <String, Object?>{
        'status': 'downloadable',
        'displayName': '',
      };
      info = await MethodChannelLanguagePackService().status('de-DE');
      expect(info.status, LanguagePackStatus.downloadable);
      expect(info.displayName, 'de-DE');
    });

    test('a PlatformException is unknown, with the locale as name', () async {
      statusError = PlatformException(code: 'boom', message: 'secret words');

      final info = await MethodChannelLanguagePackService().status('en-US');

      expect(info.status, LanguagePackStatus.unknown);
      expect(info.displayName, 'en-US');
    });
  });

  group('download', () {
    test('sends {localeId: String} on the method "download"', () async {
      await MethodChannelLanguagePackService().download('en-US');

      expect(calls, hasLength(1));
      expect(calls.single.method, 'download');
      expect(calls.single.arguments, <String, Object?>{'localeId': 'en-US'});
    });

    test('a PlatformException propagates', () async {
      downloadError = PlatformException(code: 'unsupported_version');

      await expectLater(
        MethodChannelLanguagePackService().download('en-US'),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('events', () {
    late List<LanguagePackEvent> received;
    late StreamSubscription<LanguagePackEvent> sub;
    late List<LogRecord> records;
    late StreamSubscription<LogRecord> logSub;

    setUp(() async {
      received = [];
      records = [];
      Logger.root.level = Level.ALL;
      logSub = Logger.root.onRecord.listen(records.add);
      sub = MethodChannelLanguagePackService().events.listen(received.add);
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() async {
      await sub.cancel();
      await logSub.cancel();
    });

    Future<void> send(Object? raw) async {
      eventSink!.success(raw);
      await Future<void>.delayed(Duration.zero);
    }

    test('progress with a percent', () async {
      await send(<String, Object?>{
        'type': 'progress',
        'localeId': 'en-US',
        'percent': 42,
      });

      expect(received, hasLength(1));
      final e = received.single as LanguagePackProgress;
      expect(e.localeId, 'en-US');
      expect(e.percent, 42);
    });

    test('progress without a percent', () async {
      await send(<String, Object?>{'type': 'progress', 'localeId': 'en-US'});

      final e = received.single as LanguagePackProgress;
      expect(e.percent, isNull);
    });

    test('scheduled', () async {
      await send(<String, Object?>{'type': 'scheduled', 'localeId': 'en-US'});

      expect(received.single, isA<LanguagePackScheduled>());
      expect(received.single.localeId, 'en-US');
    });

    test('done', () async {
      await send(<String, Object?>{'type': 'done', 'localeId': 'en-US'});

      expect(received.single, isA<LanguagePackDone>());
      expect(received.single.localeId, 'en-US');
    });

    test('failed with and without a code', () async {
      await send(<String, Object?>{
        'type': 'failed',
        'localeId': 'en-US',
        'code': 9,
      });
      await send(<String, Object?>{'type': 'failed', 'localeId': 'fr-CA'});

      expect(received, hasLength(2));
      expect((received[0] as LanguagePackFailed).code, 9);
      expect((received[1] as LanguagePackFailed).code, isNull);
      expect(received[1].localeId, 'fr-CA');
    });

    test('an unknown type is dropped and logged by type name only', () async {
      await send(<String, Object?>{
        'type': 'sparkle',
        'localeId': 'en-US',
      });

      expect(received, isEmpty);
      expect(records.map((r) => r.message).join(), contains('sparkle'));
      expect(records.map((r) => r.message).join(), isNot(contains('en-US')));
    });

    final malformed = <String, Object?>{
      'not a map': 'done',
      'no type': <String, Object?>{'localeId': 'en-US'},
      'no locale': <String, Object?>{'type': 'done'},
      'a non-string locale': <String, Object?>{'type': 'done', 'localeId': 7},
      'a non-int percent': <String, Object?>{
        'type': 'progress',
        'localeId': 'en-US',
        'percent': '40',
      },
      'a non-int code': <String, Object?>{
        'type': 'failed',
        'localeId': 'en-US',
        'code': 'x',
      },
    };
    // The table reads better as a named declaration than as a cascade.
    // ignore: cascade_invocations
    malformed.forEach((name, raw) {
      test('$name is dropped without the payload in the log', () async {
        await send(raw);

        expect(received, isEmpty);
        expect(records, isNotEmpty);
        final text = records.map((r) => r.message).join();
        expect(text, isNot(contains('en-US')));
        expect(text, isNot(contains('"40"')));
      });
    });
  });
}
