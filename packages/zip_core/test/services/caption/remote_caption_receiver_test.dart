// Tests for S-14, S-16, S-18: `RemoteCaptionReceiver` (WebRTC Transport,
// Remote Broadcast Output Target, Viewer Capacity) — republishes decoded
// wire messages from a mocked `ViewerTransport` onto a real viewer-side
// `CaptionBus`.
//
// The mock backs `messages` with a real broadcast `StreamController` and
// overrides the getter directly (not via `when`/`thenAnswer`): the
// receiver subscribes to it in its constructor, before any stubbing is
// possible — same pattern as `test/helpers/mock_transcript_repository.dart`.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';
import 'package:zip_core/src/services/caption/remote_caption_receiver.dart';
import 'package:zip_core/src/services/webrtc/viewer_transport.dart';

/// Mocktail mock for [ViewerTransport].
class MockViewerTransport extends Mock implements ViewerTransport {
  final _messagesController = StreamController<CaptionWireMessage>.broadcast();

  @override
  Stream<CaptionWireMessage> get messages => _messagesController.stream;

  /// Emits [message] on [messages].
  void emitMessage(CaptionWireMessage message) =>
      _messagesController.add(message);

  /// Closes the internal stream controller.
  void disposeController() => _messagesController.close();
}

void main() {
  late MockViewerTransport transport;
  late CaptionBus bus;
  late RemoteCaptionReceiver receiver;

  SttResult makeSttResult([String text = 'hello']) => SttResult(
    text: text,
    isFinal: true,
    confidence: 1,
    timestamp: DateTime.utc(2026),
    sourceId: 'default',
  );

  setUp(() {
    transport = MockViewerTransport();
    // A real `CaptionBus`, never mocked: the point is to assert what the
    // receiver publishes, using the bus's own test idiom (listen, pump,
    // then assert on the collected list).
    bus = CaptionBus();
    receiver = RemoteCaptionReceiver(transport: transport, viewerBus: bus);
  });

  tearDown(() {
    receiver.dispose();
    bus.dispose();
    transport.disposeController();
  });

  group('RemoteCaptionReceiver', () {
    test(
      'Caption message publishes one SttResultEvent with the same result',
      () async {
        final events = <CaptionEvent>[];
        bus.stream.listen(events.add);
        final result = makeSttResult();

        transport.emitMessage(Caption(result: result));
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        // SttResultEvent has no value equality, so unwrap and compare the
        // freezed result.
        expect(events.single, isA<SttResultEvent>());
        expect((events.single as SttResultEvent).result, result);
      },
    );

    test(
      'CaptionActivityChanged message emits the activity on activity',
      () async {
        final activities = <CaptionActivity>[];
        receiver.activity.listen(activities.add);

        transport.emitMessage(
          const CaptionActivityChanged(activity: CaptionActivity.paused),
        );
        await Future<void>.delayed(Duration.zero);

        expect(activities, [CaptionActivity.paused]);
      },
    );

    test('Ended message emits once on ended', () async {
      var endCount = 0;
      receiver.ended.listen((_) => endCount++);

      transport.emitMessage(const Ended());
      await Future<void>.delayed(Duration.zero);

      expect(endCount, 1);
    });

    test(
      'dispose stops publishing to the bus and emitting on streams',
      () async {
        final events = <CaptionEvent>[];
        final activities = <CaptionActivity>[];
        var endCount = 0;
        bus.stream.listen(events.add);
        receiver.activity.listen(activities.add);
        receiver.ended.listen((_) => endCount++);

        receiver.dispose();
        transport
          ..emitMessage(Caption(result: makeSttResult()))
          ..emitMessage(
            const CaptionActivityChanged(activity: CaptionActivity.active),
          )
          ..emitMessage(const Ended());
        await Future<void>.delayed(Duration.zero);

        expect(events, isEmpty);
        expect(activities, isEmpty);
        expect(endCount, 0);
      },
    );
  });
}
