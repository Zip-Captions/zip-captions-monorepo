// Tests for S-14, S-16, S-18: fake `PeerConnectionHandle` /
// `PeerConnectionFactory` infrastructure (webrtc-transport-remote-output-
// capacity, plan step 25 part 1) — sanity coverage of
// `fake_peer_connection.dart` itself, independent of any real transport
// class. The fakes are "wired together in memory" (NFR Requirements Q5):
// `createLinkedFakePeerConnectionPair` links two handles,
// `createDataChannel` delivers the linked counterpart on the peer
// handle's `onDataChannel` stream, data-channel messages cross the pair
// without self-echo, `FakePeerConnectionFactory` pairs sequential
// `create()` calls (1st with 2nd, 3rd with 4th), and `emitIceState`
// drives ICE state since there is no real negotiation.
//
// These are plain hand-written fakes backed by real `StreamController`s
// (the `mock_transcript_repository.dart` style), not mocktail mocks.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:zip_core/src/models/ice_server.dart';

import 'fake_peer_connection.dart';

void main() {
  group('createLinkedFakePeerConnectionPair', () {
    test("returns two handles that are each other's peer", () {
      final (a, b) = createLinkedFakePeerConnectionPair();

      expect(a.peer, same(b));
      expect(b.peer, same(a));
    });
  });

  group('FakePeerConnectionHandle.createDataChannel', () {
    test(
      "delivers a FakeDataChannel on the peer handle's onDataChannel "
      'stream once the microtask queue drains',
      () async {
        final (a, b) = createLinkedFakePeerConnectionPair();
        final delivered = <RTCDataChannel>[];
        final dataChannelSub = b.onDataChannel.listen(delivered.add);
        addTearDown(dataChannelSub.cancel);

        final mine = await a.createDataChannel('captions');
        await pumpEventQueue();

        expect(mine, isA<FakeDataChannel>());
        expect(mine.label, 'captions');
        expect(delivered, hasLength(1));
        expect(delivered.single, isA<FakeDataChannel>());
        expect(delivered.single.label, 'captions');
        expect(delivered.single, isNot(same(mine)));
      },
    );

    test(
      'both the created channel and its delivered counterpart emit '
      'RTCDataChannelOpen on stateChangeStream, observed by listeners '
      'attached the way the real transports attach them',
      () async {
        final (a, b) = createLinkedFakePeerConnectionPair();
        final delivered = <RTCDataChannel>[];
        final deliveredStates = <RTCDataChannelState>[];
        // Mirrors `WebRtcViewerTransport`: attach the `stateChangeStream`
        // listener synchronously inside the `onDataChannel` callback.
        final dataChannelSub = b.onDataChannel.listen((channel) {
          delivered.add(channel);
          channel.stateChangeStream.listen(deliveredStates.add);
        });
        addTearDown(dataChannelSub.cancel);

        // Mirrors `WebRtcBroadcastTransport`: attach the listener on the
        // statement immediately following `await createDataChannel` —
        // before the peer-open microtask (nested one level deeper than
        // delivery) has had a chance to run.
        final mine = await a.createDataChannel('captions');
        final mineStates = <RTCDataChannelState>[];
        final mineSub = mine.stateChangeStream.listen(mineStates.add);
        addTearDown(mineSub.cancel);

        await pumpEventQueue();

        expect(mine.state, RTCDataChannelState.RTCDataChannelOpen);
        expect(mineStates, [RTCDataChannelState.RTCDataChannelOpen]);
        expect(delivered.single.state, RTCDataChannelState.RTCDataChannelOpen);
        expect(
          deliveredStates,
          [RTCDataChannelState.RTCDataChannelOpen],
        );
      },
    );

    test(
      "a message sent on one channel arrives on the linked channel's "
      "messageStream with the same text and never on the sender's own "
      'stream',
      () async {
        final (a, b) = createLinkedFakePeerConnectionPair();
        final delivered = <RTCDataChannel>[];
        final dataChannelSub = b.onDataChannel.listen(delivered.add);
        addTearDown(dataChannelSub.cancel);

        final mine = await a.createDataChannel('captions');
        await pumpEventQueue();
        final theirs = delivered.single;

        final mineReceived = <RTCDataChannelMessage>[];
        final theirsReceived = <RTCDataChannelMessage>[];
        final mineSub = mine.messageStream.listen(mineReceived.add);
        final theirsSub = theirs.messageStream.listen(theirsReceived.add);
        addTearDown(mineSub.cancel);
        addTearDown(theirsSub.cancel);

        await mine.send(RTCDataChannelMessage('hello'));
        await pumpEventQueue();

        expect(theirsReceived, hasLength(1));
        expect(theirsReceived.single.text, 'hello');
        expect(theirsReceived.single.isBinary, isFalse);
        expect(mineReceived, isEmpty);
      },
    );
  });

  group('FakeDataChannel.open', () {
    test(
      'transitions the channel to open and emits on stateChangeStream',
      () async {
        final (x, y) = FakeDataChannel.linkedPair('captions');
        final xStates = <RTCDataChannelState>[];
        final yStates = <RTCDataChannelState>[];
        final xSub = x.stateChangeStream.listen(xStates.add);
        final ySub = y.stateChangeStream.listen(yStates.add);
        addTearDown(xSub.cancel);
        addTearDown(ySub.cancel);

        expect(x.state, RTCDataChannelState.RTCDataChannelConnecting);
        x.open();
        await pumpEventQueue();

        expect(x.state, RTCDataChannelState.RTCDataChannelOpen);
        expect(xStates, [RTCDataChannelState.RTCDataChannelOpen]);
        // `open()` transitions only its own half — the linked channel is
        // untouched.
        expect(y.state, RTCDataChannelState.RTCDataChannelConnecting);
        expect(yStates, isEmpty);
      },
    );
  });

  group('FakePeerConnectionFactory', () {
    test(
      'pairs sequential create() calls (1st with 2nd, 3rd with 4th) with '
      'no cross-talk between the two pairs',
      () async {
        const iceServers = [
          IceServer(urls: ['stun:localhost:3478']),
        ];
        final factory = FakePeerConnectionFactory();

        final f1 =
            (await factory.create(iceServers)) as FakePeerConnectionHandle;
        final f2 =
            (await factory.create(iceServers)) as FakePeerConnectionHandle;
        final f3 =
            (await factory.create(iceServers)) as FakePeerConnectionHandle;
        final f4 =
            (await factory.create(iceServers)) as FakePeerConnectionHandle;

        expect(f1.peer, same(f2));
        expect(f2.peer, same(f1));
        expect(f3.peer, same(f4));
        expect(f4.peer, same(f3));

        final pair1Messages = <RTCDataChannelMessage>[];
        final pair2Messages = <RTCDataChannelMessage>[];
        final f2Sub = f2.onDataChannel.listen(
          (channel) => channel.messageStream.listen(pair1Messages.add),
        );
        final f4Sub = f4.onDataChannel.listen(
          (channel) => channel.messageStream.listen(pair2Messages.add),
        );
        addTearDown(f2Sub.cancel);
        addTearDown(f4Sub.cancel);

        final channel1 = await f1.createDataChannel('captions-1');
        final channel3 = await f3.createDataChannel('captions-3');
        await pumpEventQueue();

        await channel1.send(RTCDataChannelMessage('msg-1'));
        await channel3.send(RTCDataChannelMessage('msg-2'));
        await pumpEventQueue();

        expect(pair1Messages, hasLength(1));
        expect(pair1Messages.single.text, 'msg-1');
        expect(pair2Messages, hasLength(1));
        expect(pair2Messages.single.text, 'msg-2');
      },
    );
  });

  group('FakePeerConnectionHandle.emitIceState', () {
    test(
      "is observable on the same handle's iceConnectionState stream",
      () async {
        final (a, _) = createLinkedFakePeerConnectionPair();
        final states = <RTCIceConnectionState>[];
        final sub = a.iceConnectionState.listen(states.add);
        addTearDown(sub.cancel);

        a.emitIceState(RTCIceConnectionState.RTCIceConnectionStateConnected);
        await pumpEventQueue();

        expect(states, [RTCIceConnectionState.RTCIceConnectionStateConnected]);
      },
    );
  });
}
