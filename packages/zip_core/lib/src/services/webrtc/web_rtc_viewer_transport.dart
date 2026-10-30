import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:zip_core/src/models/caption_wire_codec.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/connect_failure.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/models/peer_id.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/models/viewer_transport_context.dart';
import 'package:zip_core/src/services/signaling/session_signaling_channel.dart';
import 'package:zip_core/src/services/webrtc/peer_connection_factory.dart';
import 'package:zip_core/src/services/webrtc/peer_connection_handle.dart';
import 'package:zip_core/src/services/webrtc/selected_candidate_route.dart';
import 'package:zip_core/src/services/webrtc/viewer_transport.dart';
import 'package:zip_core/src/services/webrtc/web_rtc_broadcast_transport.dart'
    show joinAckSentinel;

/// Fixed backoff schedule for reconnection (`business-rules.md` Rule 2):
/// 1s, 2s, 4s, 8s, then 8s repeating.
const _backoffSchedule = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
];

/// Real `flutter_webrtc`-backed [ViewerTransport] (fixed shape,
/// Application Design).
class WebRtcViewerTransport implements ViewerTransport {
  /// Creates a [WebRtcViewerTransport].
  WebRtcViewerTransport({
    PeerConnectionFactory peerConnectionFactory =
        const WebRtcPeerConnectionFactory(),
  }) : _peerConnectionFactory = peerConnectionFactory;

  final PeerConnectionFactory _peerConnectionFactory;
  final _messagesController = StreamController<CaptionWireMessage>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  ViewerTransportContext? _context;
  SessionSignalingChannel? _channel;
  PeerConnectionHandle? _connection;
  RTCDataChannel? _dataChannel;
  final _subs = <StreamSubscription<void>>[];
  String? _peerId;
  Timer? _retryTimer;
  int _retryIndex = 0;
  bool _explicitlyDisconnected = false;

  @override
  Future<void> connect(ViewerTransportContext context) async {
    _context = context;
    _explicitlyDisconnected = false;
    _statusController.add(const Connecting());
    await _attemptConnect();
  }

  Future<void> _attemptConnect() async {
    final context = _context;
    if (context == null) return;
    await _teardownConnectionState();

    final newPeerId = peerId();
    _peerId = newPeerId;

    final channel = context.signalingService.sessionChannel(
      context.sessionId,
      newPeerId,
    );
    _channel = channel;
    await channel.open();

    final connection = await _peerConnectionFactory.create(context.iceServers);
    _connection = connection;

    _subs
      ..add(channel.messages.listen(_handleBroadcasterMessage))
      ..add(connection.iceConnectionState.listen(_handleIceState))
      ..add(connection.onDataChannel.listen(_attachDataChannel))
      ..add(connection.onIceCandidate.listen(_sendLocalIceCandidate));

    await context.signalingService.submitJoinRequest(
      context.broadcastId,
      newPeerId,
    );
  }

  void _sendLocalIceCandidate(RTCIceCandidate candidate) {
    final channel = _channel;
    final peerId = _peerId;
    if (channel == null || peerId == null) return;
    final sdpMid = candidate.sdpMid;
    final sdpMLineIndex = candidate.sdpMLineIndex;
    final candidateLine = candidate.candidate;
    // `null` fields signal end-of-candidates (trickle ICE) — nothing to
    // forward, and `IceCandidate` requires non-null values.
    if (sdpMid == null || sdpMLineIndex == null || candidateLine == null) {
      return;
    }
    unawaited(
      channel.send(
        IceCandidate(
          fromPeerId: peerId,
          toPeerId: 'broadcaster',
          candidate: candidateLine,
          sdpMid: sdpMid,
          sdpMLineIndex: sdpMLineIndex,
        ),
      ),
    );
  }

  void _attachDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    _subs
      ..add(
        channel.stateChangeStream.listen((state) {
          if (state == RTCDataChannelState.RTCDataChannelOpen) {
            unawaited(channel.send(RTCDataChannelMessage(joinAckSentinel)));
          }
        }),
      )
      ..add(
        channel.messageStream.listen((data) {
          if (data.isBinary) return;
          final decoded = CaptionWireCodec.decode(_tryDecodeJson(data.text));
          if (decoded != null) _messagesController.add(decoded);
        }),
      );
  }

  void _handleBroadcasterMessage(SignalingMessage message) {
    final connection = _connection;
    if (connection == null) return;
    switch (message) {
      case JoinAccepted():
        // Application-level ack that admission succeeded; the real
        // connection confirmation is still the data-channel ack
        // (business-rules.md Rule 1) — no status change here yet.
        break;
      case JoinRejected(:final reason):
        _failConnection(
          reason == JoinRejection.full
              ? const BroadcastFull()
              : const SignalingRejected(),
        );
      case SdpOffer(:final sdp):
        unawaited(_handleOffer(sdp));
      case IceCandidate(:final candidate, :final sdpMid, :final sdpMLineIndex):
        unawaited(
          connection.addIceCandidate(
            RTCIceCandidate(candidate, sdpMid, sdpMLineIndex),
          ),
        );
      case BroadcastEnded():
        _messagesController.add(const Ended());
      // Viewer-only-origin types must never arrive from the broadcaster —
      // dropped silently (`business-rules.md` Rule 4).
      case JoinRequest():
      case SdpAnswer():
      case IceRestart():
      case Leave():
        break;
    }
  }

  Future<void> _handleOffer(String sdp) async {
    final connection = _connection;
    final channel = _channel;
    final peerId = _peerId;
    if (connection == null || channel == null || peerId == null) return;
    await connection.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    final answer = await connection.createAnswer();
    await connection.setLocalDescription(answer);
    await channel.send(
      SdpAnswer(
        fromPeerId: peerId,
        toPeerId: 'broadcaster',
        sdp: answer.sdp ?? '',
      ),
    );
  }

  void _handleIceState(RTCIceConnectionState state) {
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        _retryTimer?.cancel();
        _retryIndex = 0;
        // Unit 9 (B4): report the route the connection actually selected,
        // not an assumed one. Emitted as `p2pDirect` only once the stats say
        // so; until then this is `connecting`, which is what the viewer
        // screen already renders while it waits.
        _emitConnectedWithResolvedRoute();
      // `disconnected` and `failed` are treated identically (CodeRabbit PR
      // #31 review): `business-rules.md` Rule 2 says `Failed` is reachable
      // *only* via `disconnect()` or the broadcast ending — "never via
      // retry-count exhaustion alone." The previous `_retryIndex > 0`
      // branch violated that by emitting `Failed(IceFailed())` on the
      // very first retry's own ICE failure, breaking the 1s/2s/4s/8s
      // schedule after a single attempt. `IceFailed` (business-rules.md
      // Rule 3) is therefore not reachable from this retry loop at all —
      // retries continue indefinitely with capped backoff, exactly as
      // Rule 2 requires.
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        _statusController.add(const Interrupted());
        _scheduleRetry();
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
      case RTCIceConnectionState.RTCIceConnectionStateNew:
      case RTCIceConnectionState.RTCIceConnectionStateCount:
        break;
    }
  }

  /// Resolves this connection's real routing and emits [Connected]
  /// (Unit 9, B4). Two emissions on purpose: the first with
  /// [ConnectionType.connecting] so the UI updates the moment ICE
  /// completes, the second with the confirmed route. A failed stats query
  /// leaves the viewer at `connecting` rather than claiming a route —
  /// `ConnectionType.disconnected` would be wrong here, since the
  /// connection is demonstrably up.
  void _emitConnectedWithResolvedRoute() {
    _statusController.add(const Connected(ConnectionType.connecting));
    final connection = _connection;
    if (connection == null) return;
    unawaited(() async {
      CandidatePairRoute route;
      try {
        route = await connection.selectedCandidateRoute();
      } on Object {
        route = CandidatePairRoute.unknown;
      }
      // A newer attempt may have replaced this connection while the query
      // was in flight; only report for the connection it was asked about.
      if (!identical(_connection, connection)) return;
      // Unconfirmed stays `connecting` on the *viewer* side, unlike the
      // broadcaster's list: the viewer knows its connection is up, so
      // `disconnected` would be false. It simply cannot confirm the route.
      _statusController.add(
        Connected(
          route == CandidatePairRoute.unknown
              ? ConnectionType.connecting
              : connectionTypeOfCandidateRoute(route),
        ),
      );
    }());
  }

  void _scheduleRetry() {
    if (_explicitlyDisconnected) return;
    final delayIndex = _retryIndex < _backoffSchedule.length
        ? _retryIndex
        : _backoffSchedule.length - 1;
    final delay = _backoffSchedule[delayIndex];
    _retryIndex++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!_explicitlyDisconnected) unawaited(restart());
    });
  }

  void _failConnection(ConnectFailure failure) {
    _retryTimer?.cancel();
    _statusController.add(Failed(failure));
    // Tear down the live connection/channel/subscriptions (CodeRabbit PR
    // #31 review): otherwise, e.g. after `JoinRejected(full)`, the
    // signaling channel stays subscribed and a later `SdpOffer`/ICE event
    // could still mutate state or start a new retry through
    // `_handleIceState`. Cancelling `_subs` here removes exactly that
    // possibility — there's nothing left listening once this completes.
    unawaited(_teardownConnectionState());
  }

  @override
  Future<void> restart() async {
    if (_explicitlyDisconnected) return;
    await _attemptConnect();
  }

  @override
  Future<void> disconnect() async {
    _explicitlyDisconnected = true;
    _retryTimer?.cancel();
    await _teardownConnectionState();
    // Deliberately no status emission here: the caller just initiated this
    // itself and already knows why — unlike the other `Failed` paths,
    // there's no `ConnectFailure` variant that means "I disconnected
    // myself" (Rule 3's four variants are all connection-attempt
    // failures), so this isn't forced through `Failed`.
  }

  Future<void> _teardownConnectionState() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _dataChannel?.close();
    try {
      await _connection?.close();
    } finally {
      await _channel?.close();
    }
    _dataChannel = null;
    _connection = null;
    _channel = null;
  }

  @override
  Stream<CaptionWireMessage> get messages => _messagesController.stream;

  @override
  Stream<ConnectionStatus> get status => _statusController.stream;
}

Object? _tryDecodeJson(String text) {
  try {
    return jsonDecode(text);
  } on Object {
    return null;
  }
}
