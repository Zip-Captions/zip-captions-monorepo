import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:zip_core/src/models/ice_server.dart';
import 'package:zip_core/src/services/webrtc/peer_connection_handle.dart';

/// Creates a [PeerConnectionHandle] configured with a given ICE server list
/// (fixed shape, Application Design).
///
/// Deliberately a single-method interface (not a top-level function) so it
/// has a seam for test doubles, matching this project's other `*Provider`/
/// `*Factory` adapters.
// ignore: one_member_abstracts
abstract interface class PeerConnectionFactory {
  /// Creates a new peer connection using [iceServers].
  Future<PeerConnectionHandle> create(List<IceServer> iceServers);
}

/// Real `flutter_webrtc`-backed [PeerConnectionFactory].
class WebRtcPeerConnectionFactory implements PeerConnectionFactory {
  /// Creates a [WebRtcPeerConnectionFactory].
  const WebRtcPeerConnectionFactory();

  @override
  Future<PeerConnectionHandle> create(List<IceServer> iceServers) async {
    final configuration = <String, dynamic>{
      'iceServers': [
        for (final server in iceServers)
          <String, dynamic>{
            'urls': server.urls,
            if (server.username != null) 'username': server.username,
            if (server.credential != null) 'credential': server.credential,
          },
      ],
    };
    final connection = await createPeerConnection(configuration);
    return _WebRtcPeerConnectionHandle(connection);
  }
}

class _WebRtcPeerConnectionHandle implements PeerConnectionHandle {
  _WebRtcPeerConnectionHandle(this._connection) {
    _connection.onIceConnectionState = _iceStateController.add;
    _connection.onDataChannel = _dataChannelController.add;
  }

  final RTCPeerConnection _connection;
  final _iceStateController =
      StreamController<RTCIceConnectionState>.broadcast();
  final _dataChannelController = StreamController<RTCDataChannel>.broadcast();

  @override
  Future<RTCDataChannel> createDataChannel(String label) =>
      _connection.createDataChannel(label, RTCDataChannelInit());

  @override
  Future<RTCSessionDescription> createOffer() => _connection.createOffer();

  @override
  Future<RTCSessionDescription> createAnswer() => _connection.createAnswer();

  @override
  Future<void> setLocalDescription(RTCSessionDescription sdp) =>
      _connection.setLocalDescription(sdp);

  @override
  Future<void> setRemoteDescription(RTCSessionDescription sdp) =>
      _connection.setRemoteDescription(sdp);

  @override
  Future<void> addIceCandidate(RTCIceCandidate candidate) =>
      _connection.addCandidate(candidate);

  @override
  Stream<RTCIceConnectionState> get iceConnectionState =>
      _iceStateController.stream;

  @override
  Stream<RTCDataChannel> get onDataChannel => _dataChannelController.stream;

  @override
  Future<void> close() async {
    await _connection.close();
    await _iceStateController.close();
    await _dataChannelController.close();
  }
}
