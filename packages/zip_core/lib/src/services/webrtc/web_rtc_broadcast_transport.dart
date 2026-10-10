import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:zip_core/src/models/broadcast_limits.dart';
import 'package:zip_core/src/models/broadcast_transport_context.dart';
import 'package:zip_core/src/models/caption_wire_codec.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/models/viewer_connection_info.dart';
import 'package:zip_core/src/services/signaling/session_signaling_channel.dart';
import 'package:zip_core/src/services/webrtc/broadcast_transport.dart';
import 'package:zip_core/src/services/webrtc/peer_connection_factory.dart';
import 'package:zip_core/src/services/webrtc/peer_connection_handle.dart';

/// Sentinel `fromPeerId` for broadcaster-originated per-viewer-channel
/// messages (SDP/ICE/`Leave` are symmetric fields requiring a sender id,
/// but there is no broadcaster-side peerId concept in this design —
/// matches the existing convention in
/// `signaling_channel_privacy_supabase_test.dart`).
const _broadcasterPeerId = 'broadcaster';

/// A minimal, `CaptionWireMessage`-adjacent signal sent by
/// `WebRtcViewerTransport` the moment its own data channel reports open
/// (`business-rules.md` Rule 1) — not part of `CaptionWireCodec`'s own
/// protocol, since it's the one message that must work before any caption
/// traffic is possible.
const joinAckSentinel = '__join_ack__';

/// Real `flutter_webrtc`-backed [BroadcastTransport] (fixed shape,
/// Application Design).
///
/// **Known simplification (2026-10-08)**: [ViewerConnectionInfo]'s
/// `connectionType` is fixed as [ConnectionType.p2pDirect] for every
/// viewer — this unit's minimal [PeerConnectionHandle] seam has no
/// candidate-pair/stats query method, so deriving the real p2p-vs-relay
/// routing (as domain-entities.md describes) isn't possible without
/// expanding that interface. Flagged explicitly rather than guessed;
/// revisit once a stats-query method is added to [PeerConnectionHandle].
class WebRtcBroadcastTransport implements BroadcastTransport {
  /// Creates a [WebRtcBroadcastTransport].
  WebRtcBroadcastTransport({
    PeerConnectionFactory peerConnectionFactory =
        const WebRtcPeerConnectionFactory(),
  }) : _peerConnectionFactory = peerConnectionFactory;

  final PeerConnectionFactory _peerConnectionFactory;
  final _sessions = <String, _ViewerSession>{};
  BroadcastTransportContext? _context;
  StreamSubscription<JoinRequest>? _joinRequestsSub;

  final _viewersController =
      StreamController<List<ViewerConnectionInfo>>.broadcast();
  final _viewerJoinedController = StreamController<String>.broadcast();
  final _viewerLeftController = StreamController<String>.broadcast();

  @override
  Future<void> start(BroadcastTransportContext context) async {
    _context = context;
    _joinRequestsSub = context.signalingService
        .joinRequests(context.broadcastId)
        .listen((request) => unawaited(_handleJoinRequest(request.fromPeerId)));
  }

  Future<void> _handleJoinRequest(String peerId) async {
    final context = _context;
    if (context == null) return;

    // A duplicate `JoinRequest` for a peer we already have a live session
    // for (CodeRabbit PR #31 review): tear the old one down *before*
    // `tryAdmit`, so `ViewerAdmission` can reclaim the released
    // reservation for the reconnecting peer rather than leaving the
    // replacement session marked as a reconnect reservation that can
    // later expire out from under it.
    final existing = _sessions[peerId];
    if (existing != null) {
      _teardownViewer(peerId, confirmedBefore: existing.connectedAt != null);
    }

    final channel = context.signalingService.sessionChannel(
      context.sessionId,
      peerId,
    );
    await channel.open();

    final decision = context.admission.tryAdmit(peerId);
    if (decision is Full) {
      await channel.send(
        const JoinRejected(
          toPeerId: _broadcasterPeerId,
          reason: JoinRejection.full,
        ),
      );
      await channel.close();
      return;
    }

    try {
      final connection = await _peerConnectionFactory.create(
        context.iceServers,
      );
      final session = _ViewerSession(channel: channel, connection: connection);
      _sessions[peerId] = session;

      session.subs
        ..add(
          channel.messages.listen(
            (message) => _handleViewerMessage(peerId, message),
          ),
        )
        ..add(
          connection.iceConnectionState.listen(
            (state) => _handleIceState(peerId, state),
          ),
        )
        ..add(
          connection.onIceCandidate.listen(
            (candidate) => _sendLocalIceCandidate(peerId, candidate),
          ),
        );

      final dataChannel = await connection.createDataChannel('captions');
      session.dataChannel = dataChannel;
      session.subs
        ..add(
          dataChannel.stateChangeStream.listen((state) {
            if (state == RTCDataChannelState.RTCDataChannelOpen) {
              _startAckTimer(peerId);
            }
          }),
        )
        ..add(
          dataChannel.messageStream.listen((data) {
            if (!data.isBinary && data.text == joinAckSentinel) {
              _confirmJoin(peerId);
            }
          }),
        );

      await channel.send(const JoinAccepted(toPeerId: _broadcasterPeerId));

      final offer = await connection.createOffer();
      await connection.setLocalDescription(offer);
      await channel.send(
        SdpOffer(
          fromPeerId: _broadcasterPeerId,
          toPeerId: peerId,
          sdp: offer.sdp ?? '',
        ),
      );
    } on Object {
      // Join setup failed partway through (CodeRabbit PR #31 review): the
      // admission reservation `tryAdmit` already took must not be left
      // held indefinitely. If a session was installed before the
      // failure, `_teardownViewer` releases it and cleans up whatever
      // was already wired; otherwise release the reservation and close
      // the channel directly, since there's nothing else to tear down.
      if (_sessions.containsKey(peerId)) {
        _teardownViewer(peerId, confirmedBefore: false);
      } else {
        context.admission.release(peerId);
        unawaited(channel.close());
      }
      rethrow;
    }
  }

  void _sendLocalIceCandidate(String peerId, RTCIceCandidate candidate) {
    final session = _sessions[peerId];
    if (session == null) return;
    final sdpMid = candidate.sdpMid;
    final sdpMLineIndex = candidate.sdpMLineIndex;
    final candidateLine = candidate.candidate;
    // `null` fields signal end-of-candidates (trickle ICE) — nothing to
    // forward, and `IceCandidate` requires non-null values.
    if (sdpMid == null || sdpMLineIndex == null || candidateLine == null) {
      return;
    }
    unawaited(
      session.channel.send(
        IceCandidate(
          fromPeerId: _broadcasterPeerId,
          toPeerId: peerId,
          candidate: candidateLine,
          sdpMid: sdpMid,
          sdpMLineIndex: sdpMLineIndex,
        ),
      ),
    );
  }

  void _startAckTimer(String peerId) {
    final session = _sessions[peerId];
    if (session == null || session.ackTimer != null) return;
    session.ackTimer = Timer(const Duration(seconds: 5), () {
      _teardownViewer(peerId, confirmedBefore: false);
    });
  }

  void _handleViewerMessage(String peerId, SignalingMessage message) {
    final session = _sessions[peerId];
    if (session == null) return;
    switch (message) {
      case SdpAnswer(:final sdp):
        unawaited(
          session.connection.setRemoteDescription(
            RTCSessionDescription(sdp, 'answer'),
          ),
        );
      case IceCandidate(:final candidate, :final sdpMid, :final sdpMLineIndex):
        unawaited(
          session.connection.addIceCandidate(
            RTCIceCandidate(candidate, sdpMid, sdpMLineIndex),
          ),
        );
      case IceRestart():
        unawaited(_renegotiate(peerId));
      case Leave():
        _teardownViewer(peerId, confirmedBefore: session.connectedAt != null);
      // Broadcaster-only-origin types must never arrive from a viewer —
      // dropped silently (`business-rules.md` Rule 4).
      case JoinRequest():
      case JoinAccepted():
      case JoinRejected():
      case SdpOffer():
      case BroadcastEnded():
        break;
    }
  }

  Future<void> _renegotiate(String peerId) async {
    final session = _sessions[peerId];
    if (session == null) return;
    final offer = await session.connection.createOffer();
    await session.connection.setLocalDescription(offer);
    await session.channel.send(
      SdpOffer(
        fromPeerId: _broadcasterPeerId,
        toPeerId: peerId,
        sdp: offer.sdp ?? '',
      ),
    );
  }

  void _handleIceState(String peerId, RTCIceConnectionState state) {
    if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
        state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
      final session = _sessions[peerId];
      _teardownViewer(peerId, confirmedBefore: session?.connectedAt != null);
    }
  }

  void _confirmJoin(String peerId) {
    final session = _sessions[peerId];
    if (session == null || session.connectedAt != null) return;
    session.ackTimer?.cancel();
    session
      ..ackTimer = null
      ..connectedAt = DateTime.now();
    _viewerJoinedController.add(peerId);
    _emitViewers();
  }

  void _teardownViewer(String peerId, {required bool confirmedBefore}) {
    final session = _sessions.remove(peerId);
    if (session == null) return;
    session.ackTimer?.cancel();
    _context?.admission.release(peerId);
    for (final sub in session.subs) {
      unawaited(sub.cancel());
    }
    unawaited(session.dataChannel?.close());
    unawaited(session.connection.close());
    unawaited(session.channel.close());
    if (confirmedBefore) {
      _viewerLeftController.add(peerId);
      _emitViewers();
    }
  }

  void _emitViewers() {
    _viewersController.add([
      for (final entry in _sessions.entries)
        if (entry.value.connectedAt != null)
          ViewerConnectionInfo(
            peerId: entry.key,
            connectionType: ConnectionType.p2pDirect,
            connectedAt: entry.value.connectedAt!,
          ),
    ]);
  }

  @override
  void sendToAll(CaptionWireMessage message) {
    final payload = CaptionWireCodec.encode(message);
    for (final session in _sessions.values) {
      if (session.connectedAt == null) continue;
      final channel = session.dataChannel;
      if (channel == null) continue;
      unawaited(
        channel.send(RTCDataChannelMessage(_encodeAsString(payload))),
      );
    }
  }

  @override
  void sendTo(String peerId, CaptionWireMessage message) {
    final session = _sessions[peerId];
    if (session == null || session.connectedAt == null) return;
    final channel = session.dataChannel;
    if (channel == null) return;
    final payload = CaptionWireCodec.encode(message);
    unawaited(
      channel.send(RTCDataChannelMessage(_encodeAsString(payload))),
    );
  }

  @override
  Stream<List<ViewerConnectionInfo>> get viewers => _viewersController.stream;

  @override
  Stream<String> get viewerJoined => _viewerJoinedController.stream;

  @override
  Stream<String> get viewerLeft => _viewerLeftController.stream;

  @override
  Future<void> stop() async {
    await _joinRequestsSub?.cancel();
    for (final entry in _sessions.entries.toList()) {
      _teardownViewer(
        entry.key,
        confirmedBefore: entry.value.connectedAt != null,
      );
    }
    await _viewersController.close();
    await _viewerJoinedController.close();
    await _viewerLeftController.close();
  }
}

String _encodeAsString(Map<String, Object?> payload) => jsonEncode(payload);

class _ViewerSession {
  _ViewerSession({required this.channel, required this.connection});

  final SessionSignalingChannel channel;
  final PeerConnectionHandle connection;
  RTCDataChannel? dataChannel;
  Timer? ackTimer;
  DateTime? connectedAt;
  final subs = <StreamSubscription<void>>[];
}
