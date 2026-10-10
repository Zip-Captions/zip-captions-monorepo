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
      ..add(connection.onDataChannel.listen(_attachDataChannel));

    await context.signalingService.submitJoinRequest(
      context.broadcastId,
      newPeerId,
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
        _statusController.add(const Connected(ConnectionType.p2pDirect));
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        _statusController.add(const Interrupted());
        _scheduleRetry();
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        if (_retryIndex > 0) {
          _failConnection(const IceFailed());
        } else {
          _statusController.add(const Interrupted());
          _scheduleRetry();
        }
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
      case RTCIceConnectionState.RTCIceConnectionStateNew:
      case RTCIceConnectionState.RTCIceConnectionStateCount:
        break;
    }
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
    await _connection?.close();
    await _channel?.close();
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
