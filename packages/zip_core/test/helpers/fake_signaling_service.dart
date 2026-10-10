// In-memory [SignalingService] fake for the WebRTC transport integration
// harness (S-14, S-16, S-18) — simulates the real backend's pub/sub
// behavior with no network or Supabase dependency. Both the
// broadcaster-side and viewer-side transports under test are wired to
// the *same* instance so they can actually reach each other.

import 'dart:async';

import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/services/signaling/session_signaling_channel.dart';
import 'package:zip_core/src/services/signaling/signaling_service.dart';
import 'package:zip_core/src/services/signaling/status_channel.dart';

/// In-memory [SignalingService] fake standing in for the backend.
///
/// One shared instance represents "the backend" for an entire test: both
/// the broadcaster-side and viewer-side code under test call methods on
/// the *same* instance (this is what makes it possible for them to reach
/// each other at all). Session topics are keyed by the full
/// `(sessionId, peerId)` pair; join-request topics by `BroadcastId.value`.
/// [statusChannel] is not used by the WebRTC transport classes this fake
/// exists to support.
class FakeSignalingService implements SignalingService {
  final _topics = <String, SignalingTopic>{};
  final _joinRequestControllers = <String, StreamController<JoinRequest>>{};

  SignalingTopic _topicFor(String sessionId, String peerId) =>
      _topics.putIfAbsent('$sessionId:$peerId', SignalingTopic.new);

  StreamController<JoinRequest> _joinRequestControllerFor(String broadcastId) =>
      _joinRequestControllers.putIfAbsent(
        broadcastId,
        StreamController<JoinRequest>.broadcast,
      );

  @override
  StatusChannel statusChannel(BroadcastId id) =>
      throw UnimplementedError('not used by the WebRTC transport harness');

  @override
  Future<void> submitJoinRequest(BroadcastId broadcastId, String peerId) async {
    _joinRequestControllerFor(broadcastId.value).add(
      JoinRequest(fromPeerId: peerId),
    );
  }

  @override
  Stream<JoinRequest> joinRequests(BroadcastId broadcastId) =>
      _joinRequestControllerFor(broadcastId.value).stream;

  @override
  SessionSignalingChannel sessionChannel(String sessionId, String peerId) =>
      FakeSessionSignalingChannel(_topicFor(sessionId, peerId));

  /// Closes every internal controller. Call once per test, in `tearDown`.
  Future<void> dispose() async {
    for (final topic in _topics.values) {
      await topic.controller.close();
    }
    for (final controller in _joinRequestControllers.values) {
      await controller.close();
    }
  }
}

/// Shared broadcast topic for one `(sessionId, peerId)` pair.
///
/// Public (rather than `_Topic`) because [FakeSessionSignalingChannel]'s
/// public constructor receives one — a private type in a public API trips
/// `library_private_types_in_public_api`.
///
/// Messages are tagged with the sending channel instance's identity so
/// each channel can filter its own sends out of the shared stream.
class SignalingTopic {
  final controller = StreamController<(Object, SignalingMessage)>.broadcast();
}

/// In-memory [SessionSignalingChannel] over a shared [SignalingTopic].
///
/// Every channel owns a unique [_selfId]. A [send] broadcasts onto the
/// shared topic tagged with that id, and this channel's own [messages]
/// stream drops anything tagged with its own id — so two independent
/// `sessionChannel(sessionId, peerId)` calls for the *same* pair behave
/// like two ends of one real private channel: each sees everything the
/// other sent, and never its own message (a real Realtime broadcast
/// channel never delivers a sender's own message back to itself).
class FakeSessionSignalingChannel implements SessionSignalingChannel {
  /// Creates a channel over [_topic].
  FakeSessionSignalingChannel(this._topic);

  final SignalingTopic _topic;
  final Object _selfId = Object();

  @override
  Future<void> open() async {}

  @override
  Future<void> send(SignalingMessage message) async {
    _topic.controller.add((_selfId, message));
  }

  @override
  Stream<SignalingMessage> get messages => _topic.controller.stream
      .where((tagged) => tagged.$1 != _selfId)
      .map((tagged) => tagged.$2);

  @override
  Future<void> close() async {}
}
