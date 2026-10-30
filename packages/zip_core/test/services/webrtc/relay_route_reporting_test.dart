/// Unit 9 (B4): both transports report the route the connection actually
/// selected, and neither invents one when the connection cannot say.
///
/// Broadcast-side rows reuse the established fake-pair join harness
/// (`fake_peer_connection.dart` + `fake_signaling_service.dart`): the two
/// transports are wired to each other in memory, so a real join handshake —
/// SDP exchange, data channel, join-ack — runs end to end, and only the
/// candidate-pair reading is set by the test.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/broadcast_limits.dart';
import 'package:zip_core/src/models/broadcast_transport_context.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/models/ice_server.dart';
import 'package:zip_core/src/models/viewer_connection_info.dart';
import 'package:zip_core/src/models/viewer_transport_context.dart';
import 'package:zip_core/src/services/webrtc/peer_connection_handle.dart';
import 'package:zip_core/src/services/webrtc/viewer_admission.dart';
import 'package:zip_core/src/services/webrtc/web_rtc_broadcast_transport.dart';
import 'package:zip_core/src/services/webrtc/web_rtc_viewer_transport.dart';

import '../../helpers/fake_peer_connection.dart';
import '../../helpers/fake_signaling_service.dart';

const _broadcastId = 'K7M9X2';
const _sessionId = 'session-1';

/// Records every handle it produced so a test can set the route the next
/// `selectedCandidateRoute()` call will report.
class _TrackingFactory extends FakePeerConnectionFactory {
  final handles = <FakePeerConnectionHandle>[];

  /// Applied to each new handle as it is created. The broadcaster reads the
  /// route the instant the join is confirmed, which happens during the join
  /// handshake itself — so "set the route after the join" is too late.
  void Function(FakePeerConnectionHandle handle)? onCreated;

  @override
  Future<PeerConnectionHandle> create(List<IceServer> iceServers) async {
    final handle = await super.create(iceServers) as FakePeerConnectionHandle;
    handles.add(handle);
    onCreated?.call(handle);
    return handle;
  }

  FakePeerConnectionHandle get last => handles.last;
}

void main() {
  group('WebRtcViewerTransport', () {
    late _TrackingFactory factory;
    late FakeSignalingService signaling;
    late WebRtcViewerTransport transport;

    setUp(() {
      factory = _TrackingFactory();
      signaling = FakeSignalingService();
      transport = WebRtcViewerTransport(peerConnectionFactory: factory);
    });

    tearDown(() async {
      await transport.disconnect();
      await signaling.dispose();
    });

    /// Connects, drives ICE to `connected`, and returns every
    /// `Connected(...)` type emitted.
    Future<List<ConnectionType>> connectAndCollect(
      CandidatePairRoute? route,
    ) async {
      final types = <ConnectionType>[];
      final sub = transport.status.listen((status) {
        if (status is Connected) types.add(status.connectionType);
      });
      final statuses = <ConnectionStatus>[];
      final allSub = transport.status.listen(statuses.add);

      await transport.connect(
        ViewerTransportContext(
          sessionId: _sessionId,
          broadcastId: BroadcastId.parse(_broadcastId),
          signalingService: signaling,
          iceServers: const [],
        ),
      );
      factory.last.route = route ?? CandidatePairRoute.unknown;
      if (route == null) factory.last.routeError = StateError('no stats');
      factory.last.emitIceState(
        RTCIceConnectionState.RTCIceConnectionStateConnected,
      );
      await pumpEventQueue();

      await sub.cancel();
      await allSub.cancel();
      return types;
    }

    test('reports turnRelayed for a relay local candidate', () async {
      expect(
        (await connectAndCollect(CandidatePairRoute.relayed)).last,
        ConnectionType.turnRelayed,
      );
    });

    test('reports p2pDirect for a host local candidate', () async {
      expect(
        (await connectAndCollect(CandidatePairRoute.direct)).last,
        ConnectionType.p2pDirect,
      );
    });

    test(
      'a stats failure leaves the viewer at connecting — never p2pDirect, '
      'and never Failed/Interrupted',
      () async {
        final types = <ConnectionType>[];
        final failures = <ConnectionStatus>[];
        final sub = transport.status.listen((status) {
          if (status is Connected) types.add(status.connectionType);
          if (status is Failed || status is Interrupted) failures.add(status);
        });

        await transport.connect(
          ViewerTransportContext(
            sessionId: _sessionId,
            broadcastId: BroadcastId.parse(_broadcastId),
            signalingService: signaling,
            iceServers: const [],
          ),
        );
        factory.last
          ..routeError = StateError('stats unavailable')
          ..emitIceState(RTCIceConnectionState.RTCIceConnectionStateConnected);
        await pumpEventQueue();
        await sub.cancel();

        expect(types.last, ConnectionType.connecting);
        expect(types, isNot(contains(ConnectionType.p2pDirect)));
        expect(failures, isEmpty);
      },
    );
  });

  group('WebRtcBroadcastTransport', () {
    late _TrackingFactory factory;
    late FakeSignalingService signaling;
    late WebRtcBroadcastTransport transport;
    late WebRtcViewerTransport viewer;

    setUp(() {
      factory = _TrackingFactory();
      signaling = FakeSignalingService();
      transport = WebRtcBroadcastTransport(peerConnectionFactory: factory);
      viewer = WebRtcViewerTransport(peerConnectionFactory: factory);
    });

    tearDown(() async {
      await viewer.disconnect();
      await transport.stop();
      await signaling.dispose();
    });

    /// Runs one full join through the in-memory pair and returns the viewer
    /// list once the join is confirmed.
    Future<ViewerConnectionInfo> joinOneViewer(
      CandidatePairRoute route,
    ) async {
      final viewerLists = <List<ViewerConnectionInfo>>[];
      final sub = transport.viewers.listen(viewerLists.add);
      addTearDown(sub.cancel);

      await transport.start(
        BroadcastTransportContext(
          sessionId: _sessionId,
          broadcastId: BroadcastId.parse(_broadcastId),
          signalingService: signaling,
          iceServers: const [],
          admission: ViewerAdmission(
            const BroadcastLimits(
              maxViewers: 2,
              presenceTimeout: Duration(seconds: 60),
              reconnectWindow: Duration(seconds: 120),
            ),
          ),
        ),
      );
      // `start()` is async — it subscribes to join requests. The join must
      // not begin before that subscription exists.
      await pumpEventQueue();

      // Every handle created from here reports [route], so it is already in
      // place when `_confirmJoin` reads it mid-handshake.
      factory.onCreated = (handle) => handle.route = route;
      unawaited(
        viewer.connect(
          ViewerTransportContext(
            sessionId: _sessionId,
            broadcastId: BroadcastId.parse(_broadcastId),
            signalingService: signaling,
            iceServers: const [
              IceServer(urls: ['stun:localhost:3478']),
            ],
          ),
        ),
      );
      await pumpEventQueue();

      expect(viewerLists, isNotEmpty);
      return viewerLists.last.single;
    }

    test('reports turnRelayed for a relayed pair', () async {
      expect(
        (await joinOneViewer(CandidatePairRoute.relayed)).connectionType,
        ConnectionType.turnRelayed,
      );
    });

    test('reports p2pDirect for a direct pair', () async {
      expect(
        (await joinOneViewer(CandidatePairRoute.direct)).connectionType,
        ConnectionType.p2pDirect,
      );
    });

    test(
      'reports disconnected — never p2pDirect — when the route cannot be '
      'confirmed',
      () async {
        expect(
          (await joinOneViewer(CandidatePairRoute.unknown)).connectionType,
          ConnectionType.disconnected,
        );
      },
    );
  });
}
