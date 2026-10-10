import 'package:flutter_webrtc/flutter_webrtc.dart';

/// The minimal `flutter_webrtc` surface both `WebRtcBroadcastTransport` and
/// `WebRtcViewerTransport` actually call (fixed shape, domain-entities.md
/// Q4).
///
/// Uses `flutter_webrtc`'s own plain value types (`RTCSessionDescription`,
/// `RTCIceCandidate`, `RTCIceConnectionState`, `RTCDataChannel`) directly —
/// each one is an `abstract class` with a no-arg constructor and no native
/// platform-channel dependency, so a test fake can implement any of them
/// with zero real `flutter_webrtc` object ever constructed (NFR
/// Requirements Q5). This interface's own job is narrower: it's the seam
/// that abstracts away `createPeerConnection()`/the concrete
/// `RTCPeerConnection` itself, which *does* require a real platform
/// channel in production.
abstract interface class PeerConnectionHandle {
  /// Creates an ordered+reliable data channel labeled [label]
  /// (`business-rules.md` Rule 5 — the default `RTCDataChannelInit` is
  /// already ordered+reliable; never `ordered: false`, never
  /// `maxRetransmits`/`maxRetransmitTime`).
  Future<RTCDataChannel> createDataChannel(String label);

  /// Creates a local SDP offer.
  Future<RTCSessionDescription> createOffer();

  /// Creates a local SDP answer.
  Future<RTCSessionDescription> createAnswer();

  /// Applies the local SDP description. **Added during Code Generation
  /// 2026-10-08** — omitted from this unit's own Functional Design
  /// (domain-entities.md Q4), but required by WebRTC after
  /// [createOffer]/[createAnswer] for ICE gathering to proceed on the
  /// correct description; a completeness gap, not a design choice.
  Future<void> setLocalDescription(RTCSessionDescription sdp);

  /// Applies the remote SDP description.
  Future<void> setRemoteDescription(RTCSessionDescription sdp);

  /// Applies a remote ICE candidate.
  Future<void> addIceCandidate(RTCIceCandidate candidate);

  /// This connection's ICE connection state changes.
  Stream<RTCIceConnectionState> get iceConnectionState;

  /// Fires when the remote side creates a data channel (the viewer side:
  /// the broadcaster-created channel arrives here).
  Stream<RTCDataChannel> get onDataChannel;

  /// Closes this connection and releases its native resources.
  Future<void> close();
}
