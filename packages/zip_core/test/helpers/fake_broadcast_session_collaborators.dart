// In-memory fakes for `BroadcastSessionNotifier`'s own test suite (Unit 6,
// NFR Requirements Q1): simple value-returning stubs for
// [BroadcastIdentityRepository]/[IceServerProvider] (no behavior to fake),
// and a controllable [FakeBroadcastTransport] that lets a test drive
// `viewers`/`start`/`stop`/`sendBroadcastEnded` directly without any real
// admission/ack-timeout logic — that's Unit 5's own, already-tested
// concern, not this unit's.

import 'dart:async';

import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/broadcast_resolution.dart';
import 'package:zip_core/src/models/broadcast_status.dart';
import 'package:zip_core/src/models/broadcast_transport_context.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/models/ice_server.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/models/viewer_connection_info.dart';
import 'package:zip_core/src/models/viewer_transport_context.dart';
import 'package:zip_core/src/services/broadcast/broadcast_authorization_exception.dart';
import 'package:zip_core/src/services/broadcast/broadcast_identity_repository.dart';
import 'package:zip_core/src/services/broadcast/broadcast_resolver.dart';
import 'package:zip_core/src/services/signaling/session_signaling_channel.dart';
import 'package:zip_core/src/services/signaling/signaling_service.dart';
import 'package:zip_core/src/services/signaling/status_channel.dart';
import 'package:zip_core/src/services/webrtc/broadcast_transport.dart';
import 'package:zip_core/src/services/webrtc/ice_server_provider.dart';
import 'package:zip_core/src/services/webrtc/viewer_transport.dart';

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

/// Fake [BroadcastResolver] for the viewer's unit/PBT suites (Unit 7, NFR
/// Design Q7): a scripted result queue draining before [defaultResolution],
/// recording every call.
///
/// [error] is never thrown: the shipped resolver is total (it maps every
/// failure to `rateLimited`/`resolutionFailed`), so a fake that threw would
/// let a test assert behaviour the production contract forbids. Setting
/// [error] therefore makes [resolve] return
/// `BroadcastResolution.resolutionFailed()`, documenting that contract.
class FakeBroadcastResolver implements BroadcastResolver {
  /// Creates a fake resolving to [defaultResolution] (offline by default).
  FakeBroadcastResolver({
    BroadcastResolution? defaultResolution,
    List<BroadcastResolution>? queued,
  })  : defaultResolution =
            defaultResolution ?? const BroadcastResolution.offline(),
        queue = [...?queued];

  /// The result once [queue] is empty.
  BroadcastResolution defaultResolution;

  /// Scripted results, consumed in order.
  final List<BroadcastResolution> queue;

  /// If set, [resolve] yields `resolutionFailed` (see the class doc).
  Exception? error;

  int resolveCalls = 0;

  /// The ids passed to [resolve], in call order.
  final resolveIds = <BroadcastId>[];

  /// If set, `resolve` returns [pending]'s future instead of a scripted
  /// result, so a test can hold a join mid-resolution (stale-resume rows).
  Completer<BroadcastResolution>? pending;

  @override
  Future<BroadcastResolution> resolve(BroadcastId id) async {
    resolveCalls++;
    resolveIds.add(id);
    final held = pending;
    if (held != null) return held.future;
    if (error != null) return const BroadcastResolution.resolutionFailed();
    if (queue.isNotEmpty) return queue.removeAt(0);
    return defaultResolution;
  }
}

/// Fake [ViewerTransport] for the viewer's unit/PBT suites (Unit 7, NFR
/// Design Q7): every call is recorded; status/message events are driven
/// manually by a test.
class FakeViewerTransport implements ViewerTransport {
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _messagesController = StreamController<CaptionWireMessage>.broadcast();

  /// The context passed to [connect], once called.
  ViewerTransportContext? startedWith;

  /// If set, [connect] throws this after recording the call.
  Exception? connectError;

  /// If set, [disconnect] throws this after recording the call.
  Exception? disconnectError;

  int connectCalls = 0;
  int restartCalls = 0;
  int disconnectCalls = 0;

  @override
  Future<void> connect(ViewerTransportContext context) async {
    connectCalls++;
    startedWith = context;
    final e = connectError;
    if (e != null) throw e;
  }

  @override
  Future<void> restart() async {
    restartCalls++;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    final e = disconnectError;
    if (e != null) throw e;
  }

  @override
  Stream<CaptionWireMessage> get messages => _messagesController.stream;

  @override
  Stream<ConnectionStatus> get status => _statusController.stream;

  /// Emits [status] on the status stream (synchronously delivered to
  /// listeners on the next microtask).
  void emitStatus(ConnectionStatus status) => _statusController.add(status);

  /// Emits [message] on the messages stream.
  void emitMessage(CaptionWireMessage message) =>
      _messagesController.add(message);

  /// Closes every internal controller. Call once per test, in `tearDown`.
  Future<void> disposeControllers() async {
    await _statusController.close();
    await _messagesController.close();
  }
}
