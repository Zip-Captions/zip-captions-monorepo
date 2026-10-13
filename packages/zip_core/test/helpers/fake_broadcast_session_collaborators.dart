// In-memory fakes for `BroadcastSessionNotifier`'s own test suite (Unit 6,
// NFR Requirements Q1): simple value-returning stubs for
// [BroadcastIdentityRepository]/[IceServerProvider] (no behavior to fake),
// and a controllable [FakeBroadcastTransport] that lets a test drive
// `viewers`/`start`/`stop`/`sendBroadcastEnded` directly without any real
// admission/ack-timeout logic — that's Unit 5's own, already-tested
// concern, not this unit's.

import 'dart:async';

import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/broadcast_status.dart';
import 'package:zip_core/src/models/broadcast_transport_context.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/ice_server.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/models/viewer_connection_info.dart';
import 'package:zip_core/src/services/broadcast/broadcast_authorization_exception.dart';
import 'package:zip_core/src/services/broadcast/broadcast_identity_repository.dart';
import 'package:zip_core/src/services/signaling/session_signaling_channel.dart';
import 'package:zip_core/src/services/signaling/signaling_service.dart';
import 'package:zip_core/src/services/signaling/status_channel.dart';
import 'package:zip_core/src/services/webrtc/broadcast_transport.dart';
import 'package:zip_core/src/services/webrtc/ice_server_provider.dart';

/// Fake [BroadcastIdentityRepository]: returns [broadcastId], or throws
/// [error] if set.
class FakeBroadcastIdentityRepository implements BroadcastIdentityRepository {
  /// Creates a fake returning [broadcastId] by default.
  FakeBroadcastIdentityRepository({
    BroadcastId? broadcastId,
  }) : broadcastId = broadcastId ?? BroadcastId.parse('K7M9X2');

  /// The id [getOrCreateMine] returns, unless [error] is set.
  BroadcastId broadcastId;

  /// If set, [getOrCreateMine] throws this instead.
  BroadcastAuthorizationException? error;

  int getOrCreateMineCalls = 0;

  @override
  Future<BroadcastId> getOrCreateMine() async {
    getOrCreateMineCalls++;
    final e = error;
    if (e != null) throw e;
    return broadcastId;
  }
}

/// Fake [IceServerProvider]: returns [iceServers], or throws [error] if
/// set.
class FakeIceServerProvider implements IceServerProvider {
  /// Creates a fake returning an empty ICE server list by default.
  FakeIceServerProvider({this.iceServers = const []});

  /// The list [iceServersFor] returns, unless [error] is set.
  List<IceServer> iceServers;

  /// If set, [iceServersFor] throws this instead.
  Exception? error;

  final sessionIdsRequested = <String>[];

  @override
  Future<List<IceServer>> iceServersFor(String sessionId) async {
    sessionIdsRequested.add(sessionId);
    final e = error;
    if (e != null) throw e;
    return iceServers;
  }
}

/// Fake [BroadcastTransport]: records every call; [viewers]/[viewerJoined]/
/// [viewerLeft] are driven manually by a test via [emitViewers] etc. — no
/// real admission/ack-timeout logic (that's Unit 5's own tested concern).
class FakeBroadcastTransport implements BroadcastTransport {
  final _viewersController =
      StreamController<List<ViewerConnectionInfo>>.broadcast();
  final _viewerJoinedController = StreamController<String>.broadcast();
  final _viewerLeftController = StreamController<String>.broadcast();

  /// The context passed to [start], once called.
  BroadcastTransportContext? startedWith;

  /// If set, [start] throws this instead of recording the call.
  Exception? startError;

  int stopCalls = 0;
  int sendBroadcastEndedCalls = 0;
  final sentToAll = <CaptionWireMessage>[];

  /// If set, [stop] throws this after still recording the call —
  /// simulates a failing unwind step (CodeRabbit PR #34 review).
  Exception? stopError;

  @override
  Future<void> start(BroadcastTransportContext context) async {
    final e = startError;
    if (e != null) throw e;
    startedWith = context;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    final e = stopError;
    if (e != null) throw e;
  }

  @override
  void sendToAll(CaptionWireMessage message) => sentToAll.add(message);

  @override
  void sendTo(String peerId, CaptionWireMessage message) {}

  @override
  Future<void> sendBroadcastEnded() async {
    sendBroadcastEndedCalls++;
  }

  @override
  Stream<List<ViewerConnectionInfo>> get viewers => _viewersController.stream;

  @override
  Stream<String> get viewerJoined => _viewerJoinedController.stream;

  @override
  Stream<String> get viewerLeft => _viewerLeftController.stream;

  /// Emits [viewers] on the [viewers] stream.
  void emitViewers(List<ViewerConnectionInfo> viewers) =>
      _viewersController.add(viewers);

  /// Closes every internal controller. Call once per test, in `tearDown`.
  Future<void> disposeControllers() async {
    await _viewersController.close();
    await _viewerJoinedController.close();
    await _viewerLeftController.close();
  }
}

/// Fake [StatusChannel]: records every call; [publishLive] throws
/// [publishLiveError] if set.
class FakeStatusChannel implements StatusChannel {
  final _statusController = StreamController<BroadcastStatus>.broadcast();

  int publishLiveCalls = 0;
  int publishOfflineCalls = 0;
  int closeCalls = 0;

  /// If set, [publishLive] throws this instead of recording the call.
  Exception? publishLiveError;

  @override
  Future<void> publishLive({
    required String sessionId,
    required String sessionName,
  }) async {
    final e = publishLiveError;
    if (e != null) throw e;
    publishLiveCalls++;
  }

  @override
  Future<void> publishOffline() async {
    publishOfflineCalls++;
  }

  @override
  Stream<BroadcastStatus> watch() => _statusController.stream;

  @override
  Future<void> close() async {
    closeCalls++;
  }
}

/// Fake [SignalingService] for `BroadcastSessionNotifier`'s own tests.
///
/// Only [statusChannel] is exercised by `BroadcastSessionNotifier` itself
/// (it passes the service through to `BroadcastTransportContext`
/// unopened/unused, since this unit's tests substitute a
/// [FakeBroadcastTransport] that never calls back into it) — the other
/// three methods are never reached by anything under test here.
class FakeBroadcastSignalingService implements SignalingService {
  /// Creates a fake whose [statusChannel] always returns [channel].
  FakeBroadcastSignalingService(this.channel);

  /// The channel every [statusChannel] call returns.
  final FakeStatusChannel channel;

  @override
  StatusChannel statusChannel(BroadcastId id) => channel;

  @override
  Future<void> submitJoinRequest(BroadcastId broadcastId, String peerId) =>
      throw UnimplementedError('not used by BroadcastSessionNotifier tests');

  @override
  Stream<JoinRequest> joinRequests(BroadcastId broadcastId) =>
      throw UnimplementedError('not used by BroadcastSessionNotifier tests');

  @override
  SessionSignalingChannel sessionChannel(String sessionId, String peerId) =>
      throw UnimplementedError('not used by BroadcastSessionNotifier tests');
}
