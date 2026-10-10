import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:zip_core/src/models/ice_server.dart';
import 'package:zip_core/src/services/webrtc/peer_connection_factory.dart';
import 'package:zip_core/src/services/webrtc/peer_connection_handle.dart';

/// A hand-written [RTCDataChannel] fake backed by real
/// `StreamController`s. Two instances are always created as a linked pair
/// via [linkedPair] — sending on one delivers to the other's
/// [messageStream] (NFR Requirements Q5: "two sides wired directly
/// together in memory... they're already connected by construction").
///
/// `RTCDataChannel` is a plain `abstract class` (not
/// `abstract interface class`), so `implements` inherits no member
/// bodies — every member is re-implemented here. The nullable callback
/// fields mirror the base class's parameter lists exactly: a field
/// override's type must stand in for the base's on both the getter and
/// setter sides, which fixes the parameter shapes while leaving the
/// return as a top type (`void` here); this fake never invokes them.
class FakeDataChannel implements RTCDataChannel {
  FakeDataChannel._(this.label) {
    // Assigned once, in the constructor body — `implements` requires both
    // the implicit getter and setter of the base's mutable `late` fields.
    stateChangeStream = _stateController.stream;
    messageStream = _messageController.stream;
  }

  /// Creates two [FakeDataChannel]s linked to each other.
  static (FakeDataChannel, FakeDataChannel) linkedPair(String label) {
    final a = FakeDataChannel._(label);
    final b = FakeDataChannel._(label);
    a._peer = b;
    b._peer = a;
    return (a, b);
  }

  late FakeDataChannel _peer;
  @override
  final String label;
  RTCDataChannelState _state = RTCDataChannelState.RTCDataChannelConnecting;
  final _stateController = StreamController<RTCDataChannelState>.broadcast();
  final _messageController =
      StreamController<RTCDataChannelMessage>.broadcast();

  @override
  RTCDataChannelState? get state => _state;

  @override
  int? get id => 0;

  @override
  int? get bufferedAmount => 0;

  @override
  late Stream<RTCDataChannelState> stateChangeStream;

  @override
  late Stream<RTCDataChannelMessage> messageStream;

  @override
  int? bufferedAmountLowThreshold;

  @override
  void Function(RTCDataChannelState state)? onDataChannelState;

  @override
  void Function(RTCDataChannelMessage data)? onMessage;

  @override
  void Function(int currentAmount, int changedAmount)? onBufferedAmountChange;

  @override
  void Function(int currentAmount)? onBufferedAmountLow;

  @override
  Future<void> send(RTCDataChannelMessage message) async {
    // No self-echo: a message only ever reaches the *linked* channel.
    _peer._messageController.add(message);
  }

  @override
  Future<int> getBufferedAmount() async => bufferedAmount ?? 0;

  @override
  Future<void> close() async {
    _state = RTCDataChannelState.RTCDataChannelClosed;
    _stateController.add(_state);
    await _stateController.close();
    await _messageController.close();
  }

  /// Transitions this channel to `open` and emits on
  /// [stateChangeStream]. Called by [FakePeerConnectionHandle] shortly
  /// after both sides of a pair exist — not called by test code directly
  /// in the normal case.
  void open() {
    _state = RTCDataChannelState.RTCDataChannelOpen;
    _stateController.add(_state);
  }
}

/// A hand-written [PeerConnectionHandle] fake "wired together in memory"
/// with the peer [FakePeerConnectionHandle] from
/// [createLinkedFakePeerConnectionPair] — no real SDP/ICE negotiation.
///
/// [createDataChannel] creates a linked [FakeDataChannel] pair, keeps one
/// half, and delivers the other to the peer handle's [onDataChannel]
/// stream; both halves open shortly after. The delivery happens in a
/// `scheduleMicrotask` (not synchronously), and the opens happen in a
/// *further-nested* `scheduleMicrotask` inside that one — two levels, not
/// one — because the real `WebRtcBroadcastTransport`/
/// `WebRtcViewerTransport` each attach their `stateChangeStream` listener
/// in a microtask of their own (the broadcaster's await-continuation
/// right after `createDataChannel`; the viewer's `onDataChannel`
/// callback), and those listener-attaching microtasks are themselves
/// queued ahead of anything scheduled from inside the delivery microtask.
/// Opening in the same (outer) microtask as delivery, or even in a single
/// level of nesting shared with delivery, fires before those listeners
/// exist and the event is silently dropped by the broadcast stream.
class FakePeerConnectionHandle implements PeerConnectionHandle {
  FakePeerConnectionHandle();

  /// Set by [createLinkedFakePeerConnectionPair] — the other side this
  /// connection is wired to.
  late FakePeerConnectionHandle peer;

  final _iceController = StreamController<RTCIceConnectionState>.broadcast();
  final _dataChannelController = StreamController<RTCDataChannel>.broadcast();

  @override
  Future<RTCDataChannel> createDataChannel(String label) async {
    final (mine, theirs) = FakeDataChannel.linkedPair(label);
    scheduleMicrotask(() {
      peer._dataChannelController.add(theirs);
      // Nested, not inline: this call's own Future already queued the
      // await-continuation microtask (the caller attaching a listener on
      // `mine`) before this outer microtask started running, and
      // `add(theirs)` just queued the peer's `onDataChannel` listener's
      // microtask (which attaches a listener on `theirs`) the same way —
      // both land ahead of this nested microtask, so by the time it runs,
      // both sides have already had their chance to listen.
      scheduleMicrotask(() {
        mine.open();
        theirs.open();
      });
    });
    return mine;
  }

  @override
  Future<RTCSessionDescription> createOffer() async =>
      RTCSessionDescription('fake-offer-sdp', 'offer');

  @override
  Future<RTCSessionDescription> createAnswer() async =>
      RTCSessionDescription('fake-answer-sdp', 'answer');

  @override
  Future<void> setLocalDescription(RTCSessionDescription sdp) async {}

  @override
  Future<void> setRemoteDescription(RTCSessionDescription sdp) async {}

  @override
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {}

  @override
  Stream<RTCIceConnectionState> get iceConnectionState => _iceController.stream;

  @override
  Stream<RTCDataChannel> get onDataChannel => _dataChannelController.stream;

  /// Lets a test simulate an ICE state transition directly — there is no
  /// real ICE negotiation to derive this from.
  void emitIceState(RTCIceConnectionState state) => _iceController.add(state);

  @override
  Future<void> close() async {
    await _iceController.close();
    await _dataChannelController.close();
  }
}

/// Creates two [FakePeerConnectionHandle]s wired to each other as peers.
(FakePeerConnectionHandle, FakePeerConnectionHandle)
createLinkedFakePeerConnectionPair() {
  final a = FakePeerConnectionHandle();
  final b = FakePeerConnectionHandle();
  a.peer = b;
  b.peer = a;
  return (a, b);
}

/// A [PeerConnectionFactory] fake that pairs up *sequential* `create()`
/// calls: the 1st and 2nd calls are linked to each other, the 3rd and
/// 4th calls are linked to each other, and so on.
///
/// Sufficient for one join at a time: the real join sequence is strictly
/// ordered for one join (the viewer's transport calls `create()` first,
/// the broadcaster's transport only after receiving the viewer's
/// `JoinRequest`), and neither call carries any parameter identifying the
/// peer — call order is the only correlation available.
class FakePeerConnectionFactory implements PeerConnectionFactory {
  FakePeerConnectionHandle? _pendingFirstOfPair;

  @override
  Future<PeerConnectionHandle> create(List<IceServer> iceServers) async {
    if (_pendingFirstOfPair == null) {
      final (a, b) = createLinkedFakePeerConnectionPair();
      _pendingFirstOfPair = b;
      return a;
    }
    final second = _pendingFirstOfPair!;
    _pendingFirstOfPair = null;
    return second;
  }
}
