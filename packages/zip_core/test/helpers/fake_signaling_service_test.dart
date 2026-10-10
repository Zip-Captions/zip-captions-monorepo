// Tests for S-14, S-16, S-18: `FakeSignalingService` — the shared,
// in-memory `SignalingService` fake the later WebRTC transport
// integration test drives both the broadcaster-side and viewer-side
// transports through (one instance standing in for "the backend").
// This file sanity-checks the fake itself, independent of any real
// transport class: same-topic channels deliver to each other but never
// to their own sender (no self-echo), session topics are isolated by
// the full `(sessionId, peerId)` pair, and join requests are isolated
// per `BroadcastId` on a broadcast stream.
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/signaling_message.dart';

import 'fake_signaling_service.dart';

void main() {
  late FakeSignalingService signaling;

  setUp(() {
    signaling = FakeSignalingService();
  });

  tearDown(() async {
    await signaling.dispose();
  });

  group('FakeSignalingService.sessionChannel', () {
    test(
      'a message sent on one shared-topic channel arrives on the other '
      "channel's messages stream",
      () async {
        final a = signaling.sessionChannel('s1', 'p1');
        final b = signaling.sessionChannel('s1', 'p1');
        await a.open();
        await b.open();

        final received = <SignalingMessage>[];
        b.messages.listen(received.add);

        const message = SdpOffer(
          fromPeerId: 'broadcaster',
          toPeerId: 'p1',
          sdp: 'v=0',
        );
        await a.send(message);

        await pumpEventQueue();
        expect(received, [message]);
      },
    );

    test(
      'the sending channel never receives its own message (no self-echo)',
      () async {
        final a = signaling.sessionChannel('s1', 'p1');
        final b = signaling.sessionChannel('s1', 'p1');
        await a.open();
        await b.open();

        final receivedOnA = <SignalingMessage>[];
        final receivedOnB = <SignalingMessage>[];
        a.messages.listen(receivedOnA.add);
        b.messages.listen(receivedOnB.add);

        const message = IceRestart(fromPeerId: 'broadcaster', toPeerId: 'p1');
        await a.send(message);

        await pumpEventQueue();
        expect(receivedOnA, isEmpty);
        expect(receivedOnB, [message]);
      },
    );

    test(
      'a channel for a different peerId on the same sessionId never '
      'receives what the (s1, p1) topic sent (topics are isolated by the '
      'full pair, not just the sessionId)',
      () async {
        final p1 = signaling.sessionChannel('s1', 'p1');
        final p2 = signaling.sessionChannel('s1', 'p2');
        await p1.open();
        await p2.open();

        final receivedOnP2 = <SignalingMessage>[];
        p2.messages.listen(receivedOnP2.add);

        const message = Leave(fromPeerId: 'p1');
        await p1.send(message);

        await pumpEventQueue();
        expect(receivedOnP2, isEmpty);
      },
    );
  });

  group('FakeSignalingService join requests', () {
    test(
      'submitJoinRequest delivers the JoinRequest to a joinRequests '
      'listener for the same BroadcastId',
      () async {
        final broadcastId = BroadcastId.parse('ABC123');
        final received = <JoinRequest>[];
        signaling.joinRequests(broadcastId).listen(received.add);

        await signaling.submitJoinRequest(broadcastId, 'peer-x');

        await pumpEventQueue();
        expect(received, [const JoinRequest(fromPeerId: 'peer-x')]);
      },
    );

    test(
      'a joinRequests listener for a different BroadcastId never receives '
      'the submission (join-request topics are isolated per BroadcastId)',
      () async {
        final broadcastId = BroadcastId.parse('ABC123');
        final other = BroadcastId.parse('XYZ789');
        final receivedOnOther = <JoinRequest>[];
        signaling.joinRequests(other).listen(receivedOnOther.add);

        await signaling.submitJoinRequest(broadcastId, 'peer-x');

        await pumpEventQueue();
        expect(receivedOnOther, isEmpty);
      },
    );

    test(
      'two joinRequests listeners for the same BroadcastId both receive '
      'the submission (broadcast stream, not single-subscription)',
      () async {
        final broadcastId = BroadcastId.parse('ABC123');
        final first = <JoinRequest>[];
        final second = <JoinRequest>[];
        signaling.joinRequests(broadcastId).listen(first.add);
        signaling.joinRequests(broadcastId).listen(second.add);

        await signaling.submitJoinRequest(broadcastId, 'peer-x');

        await pumpEventQueue();
        expect(first, [const JoinRequest(fromPeerId: 'peer-x')]);
        expect(second, [const JoinRequest(fromPeerId: 'peer-x')]);
      },
    );
  });
}
